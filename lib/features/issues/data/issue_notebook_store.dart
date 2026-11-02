import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../domain/farmer_issue.dart';

class IssueNotebookStore {
  final SharedPreferencesAsync? _providedPreferences;
  late final _preferences = _providedPreferences ?? SharedPreferencesAsync();
  final String _key;
  Future<void> _pending = Future.value();

  IssueNotebookStore({
    String owner = 'guest',
    SharedPreferencesAsync? preferences,
  }) : _providedPreferences = preferences,
       _key = 'krishi.issues.v1.${Uri.encodeComponent(owner)}';

  Future<List<FarmerIssue>> load() async {
    final raw = await _preferences.getString(_key);
    if (raw == null) return [];
    try {
      final data = jsonDecode(raw) as Map<String, dynamic>;
      if (data['version'] != 1 || (data['issues'] as List).length > 30) {
        throw const FormatException();
      }
      final issues = (data['issues'] as List)
          .map(
            (entry) =>
                FarmerIssue.fromJson(Map<String, dynamic>.from(entry as Map)),
          )
          .toList();
      issues.sort((a, b) {
        if (a.resolved != b.resolved) return a.resolved ? 1 : -1;
        if (a.followUpOn != null && b.followUpOn != null) {
          return a.followUpOn!.compareTo(b.followUpOn!);
        }
        if (a.followUpOn != b.followUpOn) return a.followUpOn == null ? 1 : -1;
        return b.updatedAt.compareTo(a.updatedAt);
      });
      return issues;
    } catch (_) {
      throw const FormatException(
        'Saved follow-up notes could not be read. The original data was kept.',
      );
    }
  }

  Future<void> save(FarmerIssue issue) {
    issue.validate();
    return _serialize(() async {
      final issues = await load();
      issues.removeWhere((entry) => entry.id == issue.id);
      if (issues.length >= 30) {
        throw StateError(
          'Keep up to 30 personal issues. Delete an old note first.',
        );
      }
      issues.add(issue);
      await _write(issues);
    });
  }

  Future<void> delete(String id) => _serialize(() async {
    final issues = await load();
    issues.removeWhere((entry) => entry.id == id);
    await _write(issues);
  });
  Future<void> clear() => _serialize(() => _preferences.remove(_key));

  Future<void> _write(List<FarmerIssue> issues) => _preferences.setString(
    _key,
    jsonEncode({
      'version': 1,
      'issues': issues.map((entry) => entry.toJson()).toList(),
    }),
  );

  Future<void> _serialize(Future<void> Function() work) {
    final result = _pending.then((_) => work());
    _pending = result.catchError((Object _) {});
    return result;
  }
}
