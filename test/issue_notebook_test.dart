import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:krishi_queue/core/settings/app_preferences.dart';
import 'package:krishi_queue/features/issues/data/issue_notebook_store.dart';
import 'package:krishi_queue/features/issues/domain/farmer_issue.dart';
import 'package:krishi_queue/features/issues/presentation/issue_labels.dart';

// Mutable fake models disk failure and pending writes without a device plugin.
// ignore: must_be_immutable
class IssueMemoryPreferences extends Fake implements SharedPreferencesAsync {
  final values = <String, String>{};
  bool failWrites = false;
  Completer<void>? pendingWrite;
  @override
  Future<String?> getString(String key) async => values[key];
  @override
  Future<void> setString(String key, String value) async {
    if (failWrites) throw StateError('Disk full');
    await pendingWrite?.future;
    values[key] = value;
  }

  @override
  Future<void> remove(String key) async {
    values.remove(key);
  }
}

FarmerIssue sampleIssue(
  String id, {
  DateTime? followUp,
  bool resolved = false,
}) => FarmerIssue(
  id: id,
  kind: IssueKind.payment,
  centre: 'My society',
  description: 'Asked for payment status',
  occurredOn: DateTime(2026, 10, 20),
  updatedAt: DateTime(2026, 11, 2),
  followUpOn: followUp,
  resolved: resolved,
  evidence: {'purchase'},
  updates: [
    IssueUpdate(date: DateTime(2026, 11, 1), note: 'Society asked for receipt'),
  ],
);

void main() {
  test(
    'notes and history persist for one owner without exposing another owner',
    () async {
      final disk = IssueMemoryPreferences();
      await IssueNotebookStore(
        owner: 'one',
        preferences: disk,
      ).save(sampleIssue('1'));
      final restored = (await IssueNotebookStore(
        owner: 'one',
        preferences: disk,
      ).load()).single;
      expect(restored.updates.single.note, 'Society asked for receipt');
      expect(restored.evidence, {'purchase'});
      expect(
        await IssueNotebookStore(owner: 'two', preferences: disk).load(),
        isEmpty,
      );
    },
  );
  test(
    'racing writes and repeated save do not drop or duplicate notes',
    () async {
      final store = IssueNotebookStore(preferences: IssueMemoryPreferences());
      await Future.wait([
        store.save(sampleIssue('1')),
        store.save(sampleIssue('2')),
      ]);
      await store.save(sampleIssue('1'));
      expect((await store.load()).map((issue) => issue.id).toSet(), {'1', '2'});
    },
  );
  test(
    'a failed write can retry; corrupt data cannot silently be replaced',
    () async {
      final disk = IssueMemoryPreferences()..failWrites = true;
      final store = IssueNotebookStore(preferences: disk);
      await expectLater(store.save(sampleIssue('1')), throwsStateError);
      disk.failWrites = false;
      await store.save(sampleIssue('1'));
      disk.values['krishi.issues.v1.guest'] = '{broken';
      await expectLater(store.save(sampleIssue('2')), throwsFormatException);
      expect(disk.values['krishi.issues.v1.guest'], '{broken');
    },
  );
  test(
    'follow-up is due through the whole chosen day and excludes resolved notes',
    () {
      final today = DateTime(2026, 11, 2, 23, 59);
      expect(
        sampleIssue('1', followUp: DateTime(2026, 11, 2)).needsFollowUp(today),
        isTrue,
      );
      expect(
        sampleIssue('1', followUp: DateTime(2026, 11, 3)).needsFollowUp(today),
        isFalse,
      );
      expect(
        sampleIssue(
          '1',
          followUp: DateTime(2026, 11, 1),
          resolved: true,
        ).needsFollowUp(today),
        isFalse,
      );
      expect(sampleIssue('1').needsFollowUp(today), isFalse);
    },
  );
  test('open notes sort by follow-up date before resolved notes', () async {
    final store = IssueNotebookStore(preferences: IssueMemoryPreferences());
    await store.save(
      sampleIssue('resolved', followUp: DateTime(2026, 10, 1), resolved: true),
    );
    await store.save(sampleIssue('later', followUp: DateTime(2026, 11, 5)));
    await store.save(sampleIssue('earlier', followUp: DateTime(2026, 11, 2)));
    expect((await store.load()).map((issue) => issue.id), [
      'earlier',
      'later',
      'resolved',
    ]);
  });
  test(
    'clear removes only current owner notes and leaves visit plans intact',
    () async {
      final disk = IssueMemoryPreferences();
      final a = IssueNotebookStore(owner: 'a', preferences: disk);
      final b = IssueNotebookStore(owner: 'b', preferences: disk);
      await a.save(sampleIssue('1'));
      await b.save(sampleIssue('2'));
      disk.values['krishi.visitPlans.v1.a'] = 'untouched';
      await a.clear();
      expect(await a.load(), isEmpty);
      expect(await b.load(), hasLength(1));
      expect(disk.values['krishi.visitPlans.v1.a'], 'untouched');
    },
  );
  test('evidence and history cannot be altered after creating a snapshot', () {
    final issue = sampleIssue('1');
    expect(() => issue.evidence.clear(), throwsUnsupportedError);
    expect(() => issue.updates.clear(), throwsUnsupportedError);
  });
  test(
    'copy summary explains local status and includes history in both languages',
    () async {
      final p = AppPreferences();
      await p.setHindi(false);
      expect(
        issueSummary(sampleIssue('1'), p),
        contains('has not been submitted'),
      );
      await p.setHindi(true);
      expect(issueSummary(sampleIssue('1'), p), contains('जमा नहीं किया'));
      expect(
        issueSummary(sampleIssue('1'), p),
        contains('Society asked for receipt'),
      );
    },
  );
  test('capacity is bounded without erasing existing notes', () async {
    final store = IssueNotebookStore(preferences: IssueMemoryPreferences());
    for (var i = 0; i < 30; i++) {
      await store.save(sampleIssue('$i'));
    }
    await expectLater(store.save(sampleIssue('31')), throwsStateError);
    await store.save(sampleIssue('0'));
    expect(await store.load(), hasLength(30));
  });
}
