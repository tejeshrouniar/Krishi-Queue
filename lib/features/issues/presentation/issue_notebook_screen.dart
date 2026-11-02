import 'package:flutter/material.dart';

import '../../../core/settings/app_preferences.dart';
import '../../../core/theme/app_theme.dart';
import '../data/issue_notebook_store.dart';
import '../domain/farmer_issue.dart';
import 'issue_editor_screen.dart';
import 'issue_labels.dart';

class IssueNotebookScreen extends StatefulWidget {
  final IssueNotebookStore store;
  const IssueNotebookScreen({super.key, required this.store});
  @override
  State<IssueNotebookScreen> createState() => _IssueNotebookScreenState();
}

class _IssueNotebookScreenState extends State<IssueNotebookScreen> {
  List<FarmerIssue>? _issues;
  bool _failed = false;
  bool _showResolved = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final issues = await widget.store.load();
      if (mounted) {
        setState(() {
          _issues = issues;
          _failed = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _failed = true);
    }
  }

  Future<void> _edit([FarmerIssue? issue]) async {
    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => IssueEditorScreen(store: widget.store, issue: issue),
      ),
    );
    await _load();
  }

  @override
  Widget build(BuildContext context) {
    final p = AppPreferences.of(context);
    final issues =
        _issues?.where((issue) => issue.resolved == _showResolved).toList() ??
        [];
    return Scaffold(
      appBar: AppBar(title: Text(p.text('My follow-ups', 'मेरे फॉलो-अप'))),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 720),
          child: RefreshIndicator(
            onRefresh: _load,
            child: ListView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.all(20),
              children: [
                Card(
                  color: AppTheme.paleGreen,
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Text(
                      p.text(
                        'Keep track of a problem and your next visit or call. Notes stay on this device. Saving a note does not submit a complaint or notify any office.',
                        'समस्या और अगली मुलाकात या कॉल की जानकारी रखें। नोट इसी फ़ोन पर रहते हैं। सहेजने से शिकायत दर्ज नहीं होती और कार्यालय को सूचना नहीं जाती।',
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                FilledButton.icon(
                  onPressed: _failed || _issues == null ? null : () => _edit(),
                  icon: const Icon(Icons.add),
                  label: Text(p.text('Record a problem', 'समस्या लिखें')),
                ),
                const SizedBox(height: 16),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    ChoiceChip(
                      label: Text(p.text('Needs follow-up', 'फॉलो-अप चाहिए')),
                      selected: !_showResolved,
                      onSelected: (_) => setState(() => _showResolved = false),
                    ),
                    ChoiceChip(
                      label: Text(
                        p.text('Resolved by you', 'आपके अनुसार हल हुआ'),
                      ),
                      selected: _showResolved,
                      onSelected: (_) => setState(() => _showResolved = true),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                if (_failed) ...[
                  Text(
                    p.text(
                      'Saved notes could not be opened. They have not been overwritten. Try again; do not clear notes you still need.',
                      'सहेजे नोट खुल नहीं सके। उन्हें बदला नहीं गया है। फिर कोशिश करें; ज़रूरी नोट न हटाएँ।',
                    ),
                  ),
                  TextButton(
                    onPressed: _load,
                    child: Text(p.text('Try again', 'फिर कोशिश करें')),
                  ),
                ] else if (_issues == null)
                  const Center(child: CircularProgressIndicator())
                else if (issues.isEmpty)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 24),
                    child: Text(
                      _showResolved
                          ? p.text(
                              'No resolved notes yet.',
                              'अभी कोई हल हुआ नोट नहीं है।',
                            )
                          : p.text(
                              'No follow-ups saved. Record a payment delay, registration correction or other problem here.',
                              'अभी फॉलो-अप सहेजा नहीं है। भुगतान की देरी, पंजीकरण सुधार या अन्य समस्या यहाँ लिखें।',
                            ),
                    ),
                  )
                else
                  for (final issue in issues)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: Card(
                        child: ListTile(
                          contentPadding: const EdgeInsets.all(16),
                          title: Text(
                            issueKindLabel(issue.kind, p),
                            style: const TextStyle(fontWeight: FontWeight.w700),
                          ),
                          subtitle: Padding(
                            padding: const EdgeInsets.only(top: 8),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(issue.centre),
                                if (issue.followUpOn != null)
                                  Text(
                                    '${p.text('Your follow-up', 'आपका फॉलो-अप')}: ${issueDate(issue.followUpOn!)}',
                                    style: TextStyle(
                                      fontWeight:
                                          issue.needsFollowUp(DateTime.now())
                                          ? FontWeight.w700
                                          : FontWeight.normal,
                                    ),
                                  ),
                                if (issue.needsFollowUp(DateTime.now()))
                                  Text(
                                    p.text(
                                      'Due today or earlier · check with the office',
                                      'आज या पहले की तारीख · कार्यालय से जानकारी लें',
                                    ),
                                    style: const TextStyle(
                                      color: AppTheme.darkGreen,
                                    ),
                                  ),
                                Text(
                                  p.text(
                                    'Personal note · not an official case',
                                    'व्यक्तिगत नोट · सरकारी मामला नहीं',
                                  ),
                                  style: Theme.of(context).textTheme.bodySmall,
                                ),
                              ],
                            ),
                          ),
                          trailing: const Icon(Icons.chevron_right),
                          onTap: () => _edit(issue),
                        ),
                      ),
                    ),
                const SizedBox(height: 20),
                Text(
                  p.text(
                    'These are on-screen follow-up dates, not phone alarms. On a shared phone, delete notes you no longer need. Keep original receipts safely; do not enter Aadhaar, bank numbers, PINs or OTPs.',
                    'ये स्क्रीन पर दिखने वाली फॉलो-अप तारीखें हैं, फ़ोन अलार्म नहीं। साझा फ़ोन पर काम के बाद नोट हटा दें। मूल रसीदें सुरक्षित रखें; आधार, बैंक नंबर, पिन या OTP न लिखें।',
                  ),
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
