import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:krishi_queue/core/settings/app_preferences.dart';
import 'package:krishi_queue/core/theme/app_theme.dart';
import 'package:krishi_queue/features/issues/data/issue_notebook_store.dart';
import 'package:krishi_queue/features/issues/domain/farmer_issue.dart';
import 'package:krishi_queue/features/issues/presentation/issue_notebook_screen.dart';
import 'package:krishi_queue/features/help/presentation/settings_screen.dart';

import 'issue_notebook_test.dart' show IssueMemoryPreferences, sampleIssue;

Future<void> openNotebook(
  WidgetTester tester,
  IssueMemoryPreferences disk, {
  bool hindi = false,
  double width = 390,
  double scale = 1,
}) async {
  tester.view.physicalSize = Size(width, 850);
  tester.view.devicePixelRatio = 1;
  final p = AppPreferences();
  await p.setHindi(hindi);
  await tester.pumpWidget(
    AppPreferencesScope(
      preferences: p,
      child: MaterialApp(
        theme: AppTheme.lightTheme(),
        locale: Locale(hindi ? 'hi' : 'en'),
        supportedLocales: const [Locale('hi'), Locale('en')],
        localizationsDelegates: GlobalMaterialLocalizations.delegates,
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(context)
              .copyWith(textScaler: TextScaler.linear(scale)),
          child: child!,
        ),
        home: IssueNotebookScreen(store: IssueNotebookStore(preferences: disk)),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

Future<void> reach(WidgetTester tester, Finder target) async {
  await tester.scrollUntilVisible(
    target,
    300,
    scrollable: find.byType(Scrollable).first,
    maxScrolls: 80,
  );
  await tester.pumpAndSettle();
}

Future<void> tapText(WidgetTester tester, String label) async {
  final target = find.text(label);
  await reach(tester, target);
  await tester.tap(target);
  await tester.pumpAndSettle();
}

Future<void> enter(WidgetTester tester, String label, String text) async {
  final target = find.widgetWithText(TextFormField, label);
  await reach(tester, target);
  await tester.enterText(target, text);
  await tester.pumpAndSettle();
}

void main() {
  testWidgets(
    'a full history can still be marked resolved without losing entries',
    (tester) async {
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final disk = IssueMemoryPreferences();
      final json = sampleIssue('full').toJson();
      json['updates'] = List.generate(
        30,
        (index) => {
          'date': DateTime(2026, 11, 1).toIso8601String(),
          'note': 'Follow-up $index',
        },
      );
      final store = IssueNotebookStore(preferences: disk);
      await store.save(FarmerIssue.fromJson(json));
      await openNotebook(tester, disk);
      await tapText(tester, 'Payment follow-up');
      await tapText(tester, 'I consider this problem resolved');
      await tapText(tester, 'Save personal note');
      final saved = (await store.load()).single;
      expect(saved.resolved, isTrue);
      expect(saved.updates.length, 30);
      expect(saved.updates.first.note, 'Follow-up 0');
    },
  );
  testWidgets(
    'record, reopen, update and resolve a problem without claiming submission',
    (tester) async {
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final disk = IssueMemoryPreferences();
      await openNotebook(tester, disk);
      await tapText(tester, 'Record a problem');
      await enter(tester, 'Centre / office', 'Abhanpur society');
      await enter(
        tester,
        'What happened / what needs correction?',
        'Waiting for a payment update',
      );
      await tapText(tester, 'Purchase receipt kept');
      await enter(
        tester,
        'Add a follow-up update (optional)',
        'Asked society for the transfer reference',
      );
      await tapText(tester, 'Save personal note');
      var notes = await IssueNotebookStore(preferences: disk).load();
      expect(notes, hasLength(1));
      expect(notes.single.evidence, contains('purchase'));
      expect(notes.single.updates.single.note, contains('transfer reference'));
      await tapText(tester, 'Payment follow-up');
      await enter(tester, 'Official reference (optional)', 'OFFICE-123');
      await tapText(tester, 'I consider this problem resolved');
      await tapText(tester, 'Save personal note');
      notes = await IssueNotebookStore(preferences: disk).load();
      expect(notes.single.resolved, isTrue);
      expect(notes.single.updates, hasLength(2));
      await tapText(tester, 'Resolved by you');
      expect(find.text('Abhanpur society'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('failed save keeps edits and retry does not duplicate a note', (
    tester,
  ) async {
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final disk = IssueMemoryPreferences()..failWrites = true;
    await openNotebook(tester, disk);
    await tapText(tester, 'Record a problem');
    await enter(tester, 'Centre / office', 'My society');
    await enter(
      tester,
      'What happened / what needs correction?',
      'Weight needs checking',
    );
    await tapText(tester, 'Save personal note');
    expect(find.textContaining('Could not save.'), findsOneWidget);
    disk.failWrites = false;
    await tapText(tester, 'Save personal note');
    expect(
      (await IssueNotebookStore(preferences: disk).load()).single.description,
      'Weight needs checking',
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('a pending write freezes fields so no edit can be discarded', (
    tester,
  ) async {
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final disk = IssueMemoryPreferences();
    await openNotebook(tester, disk);
    await tapText(tester, 'Record a problem');
    await enter(tester, 'Centre / office', 'My society');
    await enter(
      tester,
      'What happened / what needs correction?',
      'Initial detail',
    );
    final pending = Completer<void>();
    disk.pendingWrite = pending;
    await reach(tester, find.text('Save personal note'));
    await tester.tap(find.text('Save personal note'));
    await tester.pump();
    for (final field in tester.widgetList<TextFormField>(
      find.byType(TextFormField),
    )) {
      expect(field.enabled, isFalse);
    }
    pending.complete();
    await tester.pumpAndSettle();
    expect(
      (await IssueNotebookStore(preferences: disk).load()).single.description,
      'Initial detail',
    );
  });

  testWidgets(
    'Hindi forms, history and deletion fit 320px at doubled text size',
    (tester) async {
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final disk = IssueMemoryPreferences();
      await IssueNotebookStore(preferences: disk).save(sampleIssue('one'));
      await openNotebook(tester, disk, hindi: true, width: 320, scale: 2);
      await tapText(tester, 'भुगतान की जानकारी');
      await reach(tester, find.text('व्यक्तिगत नोट सहेजें'));
      expect(tester.takeException(), isNull);
      await tester.tap(find.byTooltip('नोट हटाएँ'));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      await tester.tap(find.text('हटाएँ'));
      await tester.pumpAndSettle();
      expect(await IssueNotebookStore(preferences: disk).load(), isEmpty);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('blocked clipboard is reported while keeping the record intact', (
    tester,
  ) async {
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final disk = IssueMemoryPreferences();
    await IssueNotebookStore(preferences: disk).save(sampleIssue('one'));
    await openNotebook(tester, disk);
    await tapText(tester, 'Payment follow-up');
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
      SystemChannels.platform,
      (call) async {
        if (call.method == 'Clipboard.setData') {
          throw PlatformException(code: 'denied');
        }
        return null;
      },
    );
    addTearDown(
      () => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        SystemChannels.platform,
        null,
      ),
    );
    await tapText(tester, 'Copy a summary');
    expect(find.textContaining('Could not copy.'), findsOneWidget);
    expect(await IssueNotebookStore(preferences: disk).load(), hasLength(1));
  });

  testWidgets(
    'shared-phone clearing requires confirmation and affects only notes',
    (tester) async {
      var cleared = false;
      final p = AppPreferences();
      await p.setHindi(false);
      await tester.pumpWidget(
        AppPreferencesScope(
          preferences: p,
          child: MaterialApp(
            theme: AppTheme.lightTheme(),
            home: SettingsScreen(
              onClearIssueNotes: () async {
                cleared = true;
              },
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tapText(tester, 'Clear my follow-up notes');
      expect(cleared, isFalse);
      await tester.tap(find.text('Keep notes'));
      await tester.pumpAndSettle();
      expect(cleared, isFalse);
      await tapText(tester, 'Clear my follow-up notes');
      await tester.tap(find.text('Clear notes'));
      await tester.pumpAndSettle();
      expect(cleared, isTrue);
    },
  );
}
