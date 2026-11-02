import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../core/settings/app_preferences.dart';
import '../../../core/theme/app_theme.dart';
import '../../help/presentation/help_screen.dart';
import '../data/issue_notebook_store.dart';
import '../domain/farmer_issue.dart';
import 'issue_labels.dart';

class IssueEditorScreen extends StatefulWidget {
  final IssueNotebookStore store;
  final FarmerIssue? issue;
  const IssueEditorScreen({super.key, required this.store, this.issue});
  @override
  State<IssueEditorScreen> createState() => _IssueEditorScreenState();
}

class _IssueEditorScreenState extends State<IssueEditorScreen> {
  final _form = GlobalKey<FormState>();
  final _centre = TextEditingController();
  final _description = TextEditingController();
  final _reference = TextEditingController();
  final _update = TextEditingController();
  late final String _id;
  late DateTime _occurredOn;
  DateTime? _followUpOn;
  IssueKind _kind = IssueKind.payment;
  final _evidence = <String>{};
  bool _resolved = false;
  bool _dirty = false;
  bool _busy = false;
  bool _allowPop = false;

  @override
  void initState() {
    super.initState();
    final issue = widget.issue;
    _id =
        issue?.id ??
        '${DateTime.now().microsecondsSinceEpoch}-${Random.secure().nextInt(1 << 30)}';
    _occurredOn = issue?.occurredOn ?? localDay(DateTime.now());
    _followUpOn = issue?.followUpOn;
    _kind = issue?.kind ?? IssueKind.payment;
    _resolved = issue?.resolved ?? false;
    _centre.text = issue?.centre ?? '';
    _description.text = issue?.description ?? '';
    _reference.text = issue?.officialReference ?? '';
    _evidence.addAll(issue?.evidence ?? {});
    for (final controller in [_centre, _description, _reference, _update]) {
      controller.addListener(_changed);
    }
  }

  void _changed() {
    if (!_dirty && mounted) setState(() => _dirty = true);
  }

  @override
  void dispose() {
    for (final controller in [_centre, _description, _reference, _update]) {
      controller.dispose();
    }
    super.dispose();
  }

  void _message(String en, String hi) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(AppPreferences.of(context).text(en, hi))),
    );
  }

  FarmerIssue _snapshot() {
    final p = AppPreferences.of(context);
    return FarmerIssue(
      id: _id,
      kind: _kind,
      centre: _centre.text.trim(),
      description: _description.text.trim(),
      occurredOn: _occurredOn,
      updatedAt: DateTime.now(),
      followUpOn: _followUpOn,
      officialReference: _reference.text.trim(),
      resolved: _resolved,
      evidence: _evidence,
      updates: [
        ...?widget.issue?.updates,
        if (_update.text.trim().isNotEmpty)
          IssueUpdate(date: DateTime.now(), note: _update.text.trim()),
        if (widget.issue != null &&
            widget.issue!.resolved != _resolved &&
            widget.issue!.updates.length +
                    (_update.text.trim().isEmpty ? 0 : 1) <
                30)
          IssueUpdate(
            date: DateTime.now(),
            note: _resolved
                ? p.text('Marked resolved by you.', 'आपने हल हुआ चिह्नित किया।')
                : p.text('Reopened by you.', 'आपने फिर खोला।'),
          ),
      ],
    );
  }

  Future<void> _save() async {
    if (_busy || !_form.currentState!.validate()) return;
    FocusScope.of(context).unfocus();
    setState(() => _busy = true);
    try {
      final snapshot = _snapshot();
      snapshot.validate();
      await widget.store.save(snapshot);
      if (!mounted) return;
      _message(
        'Saved on this device. No complaint has been submitted.',
        'इस फ़ोन पर सहेज लिया। शिकायत जमा नहीं हुई है।',
      );
      setState(() {
        _dirty = false;
        _busy = false;
      });
      _leave();
    } catch (_) {
      if (!mounted) return;
      setState(() => _busy = false);
      _message(
        'Could not save. Your edits are still here. Keep up to 30 issues and 30 updates per issue. Copy old notes before removing any you no longer need.',
        'सहेज नहीं सके। आपके बदलाव यहीं हैं। अधिकतम 30 समस्याएँ और हर समस्या के 30 अपडेट रख सकते हैं। गैरज़रूरी नोट हटाने से पहले उनकी कॉपी रखें।',
      );
    }
  }

  Future<void> _leave() async {
    if (_busy) return;
    if (_dirty) {
      final p = AppPreferences.of(context);
      final discard = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          scrollable: true,
          title: Text(p.text('Leave without saving?', 'बिना सहेजे वापस जाएँ?')),
          content: Text(
            p.text(
              'Your latest changes will be lost.',
              'अभी किए बदलाव नहीं बचेंगे।',
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: Text(p.text('Keep editing', 'लिखना जारी रखें')),
            ),
            TextButton(
              onPressed: () => Navigator.pop(context, true),
              child: Text(p.text('Leave', 'वापस जाएँ')),
            ),
          ],
        ),
      );
      if (discard != true || !mounted) return;
    }
    setState(() => _allowPop = true);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) Navigator.pop(context);
    });
  }

  Future<void> _copy() async {
    if (_busy || !_form.currentState!.validate()) return;
    try {
      final snapshot = _snapshot();
      snapshot.validate();
      await Clipboard.setData(
        ClipboardData(text: issueSummary(snapshot, AppPreferences.of(context))),
      );
      _message(
        'Summary copied. Paste it into a message or keep a paper copy. Changes are saved only with Save.',
        'सारांश कॉपी हुआ। संदेश में पेस्ट करें या कागज़ पर लिखें। बदलाव केवल सहेजें दबाने पर बचेंगे।',
      );
    } catch (_) {
      _message(
        'Could not copy. You can save your note and write down the details.',
        'कॉपी नहीं कर सके। नोट सहेजकर जानकारी कागज़ पर लिख सकते हैं।',
      );
    }
  }

  Future<void> _delete() async {
    if (_busy) return;
    final p = AppPreferences.of(context);
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        scrollable: true,
        title: Text(
          p.text('Delete this personal note?', 'यह व्यक्तिगत नोट हटाएँ?'),
        ),
        content: Text(
          p.text(
            'Its history will be removed from this device. It cannot close or cancel a complaint filed with an office.',
            'इस फ़ोन से इसका इतिहास हटेगा। कार्यालय में दर्ज शिकायत बंद या रद्द नहीं होगी।',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(p.text('Keep', 'रखें')),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text(p.text('Delete', 'हटाएँ')),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    setState(() => _busy = true);
    try {
      await widget.store.delete(_id);
      if (!mounted) return;
      setState(() {
        _dirty = false;
        _busy = false;
      });
      _leave();
    } catch (_) {
      if (!mounted) return;
      setState(() => _busy = false);
      _message(
        'Could not delete. Please try again.',
        'हटा नहीं सके। फिर कोशिश करें।',
      );
    }
  }

  Future<void> _pickDay({bool followUp = false}) async {
    if (_busy) return;
    final today = localDay(DateTime.now());
    final first = followUp ? today : DateTime(2000);
    final last = followUp
        ? DateTime(today.year + 2, today.month, today.day)
        : today;
    var initial = followUp ? _followUpOn ?? today : _occurredOn;
    if (initial.isBefore(first)) initial = first;
    if (initial.isAfter(last)) initial = last;
    final date = await showDatePicker(
      context: context,
      firstDate: first,
      lastDate: last,
      initialDate: initial,
    );
    if (date != null && mounted) {
      setState(() {
        if (followUp) {
          _followUpOn = date;
        } else {
          _occurredOn = date;
        }
        _dirty = true;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final p = AppPreferences.of(context);
    return PopScope(
      canPop: _allowPop || (!_dirty && !_busy),
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _leave();
      },
      child: Scaffold(
        appBar: AppBar(
          title: Text(p.text('Personal follow-up', 'व्यक्तिगत फॉलो-अप')),
          actions: [
            if (widget.issue != null)
              IconButton(
                onPressed: _busy ? null : _delete,
                icon: const Icon(Icons.delete_outline),
                tooltip: p.text('Delete note', 'नोट हटाएँ'),
              ),
          ],
        ),
        body: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 720),
            child: Form(
              key: _form,
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Card(
                      color: AppTheme.paleGreen,
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Text(
                          p.text(
                            'Your own record, stored on this device. Contact the responsible office to file a complaint. Do not write Aadhaar, bank numbers, PINs or OTPs here.',
                            'यह आपका रिकॉर्ड है, जो इसी फ़ोन पर रहता है। शिकायत दर्ज करने के लिए संबंधित कार्यालय से संपर्क करें। यहाँ आधार, बैंक नंबर, पिन या OTP न लिखें।',
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 20),
                    DropdownButtonFormField<IssueKind>(
                      initialValue: _kind,
                      isExpanded: true,
                      decoration: InputDecoration(
                        labelText: p.text('Problem type', 'समस्या का प्रकार'),
                      ),
                      items: IssueKind.values
                          .map(
                            (kind) => DropdownMenuItem(
                              value: kind,
                              child: Text(issueKindLabel(kind, p)),
                            ),
                          )
                          .toList(),
                      onChanged: _busy
                          ? null
                          : (kind) {
                              if (kind != null) {
                                setState(() {
                                  _kind = kind;
                                  _dirty = true;
                                });
                              }
                            },
                    ),
                    const SizedBox(height: 18),
                    TextFormField(
                      controller: _centre,
                      enabled: !_busy,
                      maxLength: 120,
                      decoration: InputDecoration(
                        labelText: p.text(
                          'Centre / office',
                          'केंद्र / कार्यालय',
                        ),
                      ),
                      validator: (value) =>
                          value == null || value.trim().isEmpty
                          ? p.text(
                              'Enter the centre or office',
                              'केंद्र या कार्यालय लिखें',
                            )
                          : null,
                    ),
                    OutlinedButton.icon(
                      onPressed: _busy ? null : () => _pickDay(),
                      icon: const Icon(Icons.event_outlined),
                      label: Text(
                        '${p.text('Problem date', 'समस्या की तारीख')}: ${issueDate(_occurredOn)}',
                      ),
                    ),
                    const SizedBox(height: 18),
                    TextFormField(
                      controller: _description,
                      enabled: !_busy,
                      minLines: 3,
                      maxLines: 6,
                      maxLength: 1000,
                      decoration: InputDecoration(
                        labelText: p.text(
                          'What happened / what needs correction?',
                          'क्या हुआ / क्या सुधार चाहिए?',
                        ),
                        helperText: p.text(
                          'Describe the issue without private identity or bank details.',
                          'निजी पहचान या बैंक विवरण के बिना समस्या लिखें।',
                        ),
                        helperMaxLines: 3,
                      ),
                      validator: (value) =>
                          value == null || value.trim().isEmpty
                          ? p.text('Describe the problem', 'समस्या लिखें')
                          : null,
                    ),
                    TextFormField(
                      controller: _reference,
                      enabled: !_busy,
                      maxLength: 80,
                      decoration: InputDecoration(
                        labelText: p.text(
                          'Official reference (optional)',
                          'सरकारी संदर्भ (वैकल्पिक)',
                        ),
                        helperText: p.text(
                          'Enter only a receipt or complaint reference already given by an office. The app cannot verify it.',
                          'केवल कार्यालय से मिला रसीद या शिकायत संदर्भ लिखें। ऐप इसे सत्यापित नहीं कर सकता।',
                        ),
                        helperMaxLines: 4,
                      ),
                    ),
                    const SizedBox(height: 16),
                    Text(
                      p.text(
                        'Evidence to keep with you',
                        'अपने पास रखने वाले प्रमाण',
                      ),
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    Text(
                      p.text(
                        'Tick what you have. No documents are uploaded.',
                        'जो आपके पास है, उसे चुनें। दस्तावेज अपलोड नहीं होते।',
                      ),
                    ),
                    for (final key in issueEvidence)
                      CheckboxListTile(
                        contentPadding: EdgeInsets.zero,
                        controlAffinity: ListTileControlAffinity.leading,
                        title: Text(evidenceLabel(key, p)),
                        value: _evidence.contains(key),
                        onChanged: _busy
                            ? null
                            : (checked) => setState(() {
                                checked == true
                                    ? _evidence.add(key)
                                    : _evidence.remove(key);
                                _dirty = true;
                              }),
                      ),
                    const SizedBox(height: 16),
                    OutlinedButton.icon(
                      onPressed: _busy ? null : () => _pickDay(followUp: true),
                      icon: const Icon(Icons.calendar_today_outlined),
                      label: Text(
                        _followUpOn == null
                            ? p.text(
                                'Set my follow-up date',
                                'अपनी फॉलो-अप तारीख चुनें',
                              )
                            : '${p.text('My follow-up', 'मेरा फॉलो-अप')}: ${issueDate(_followUpOn!)}',
                      ),
                    ),
                    if (_followUpOn != null)
                      TextButton(
                        onPressed: _busy
                            ? null
                            : () => setState(() {
                                _followUpOn = null;
                                _dirty = true;
                              }),
                        child: Text(
                          p.text(
                            'Remove follow-up date',
                            'फॉलो-अप तारीख हटाएँ',
                          ),
                        ),
                      ),
                    Text(
                      p.text(
                        'A personal reminder shown when you open the app. It does not send an alarm or set an official deadline.',
                        'ऐप खोलने पर दिखने वाली आपकी याद रखने की तारीख। इससे अलार्म नहीं बजेगा और सरकारी समय-सीमा तय नहीं होगी।',
                      ),
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                    const SizedBox(height: 20),
                    CheckboxListTile(
                      contentPadding: EdgeInsets.zero,
                      controlAffinity: ListTileControlAffinity.leading,
                      title: Text(
                        p.text(
                          'I consider this problem resolved',
                          'मेरे अनुसार यह समस्या हल हो गई है',
                        ),
                      ),
                      subtitle: Text(
                        p.text(
                          'Your record only; no official status changes.',
                          'केवल आपका रिकॉर्ड; सरकारी स्थिति नहीं बदलेगी।',
                        ),
                      ),
                      value: _resolved,
                      onChanged: _busy
                          ? null
                          : (value) => setState(() {
                              _resolved = value ?? false;
                              _dirty = true;
                            }),
                    ),
                    if (widget.issue?.updates.isNotEmpty ?? false) ...[
                      const SizedBox(height: 16),
                      Text(
                        p.text('Your follow-up history', 'आपका फॉलो-अप इतिहास'),
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                      for (final entry in widget.issue!.updates.reversed)
                        Padding(
                          padding: const EdgeInsets.symmetric(vertical: 8),
                          child: Text(
                            '${issueDate(entry.date)} — ${entry.note}',
                          ),
                        ),
                    ],
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: _update,
                      enabled:
                          !_busy && (widget.issue?.updates.length ?? 0) < 30,
                      minLines: 2,
                      maxLines: 4,
                      maxLength: 500,
                      decoration: InputDecoration(
                        labelText: p.text(
                          'Add a follow-up update (optional)',
                          'फॉलो-अप अपडेट जोड़ें (वैकल्पिक)',
                        ),
                        helperText: p.text(
                          'For example: asked the society; they requested the purchase receipt.',
                          'जैसे: समिति से पूछा; उन्होंने खरीदी रसीद माँगी।',
                        ),
                        helperMaxLines: 3,
                      ),
                    ),
                    if ((widget.issue?.updates.length ?? 0) >= 30)
                      Text(
                        p.text(
                          'This note has 30 history entries. Copy a summary before starting another note. You can still edit the details or mark it resolved.',
                          'इस नोट में 30 पुराने अपडेट हैं। नया नोट बनाने से पहले सारांश कॉपी करें। विवरण बदल सकते हैं या हल हुआ चिह्नित कर सकते हैं।',
                        ),
                      ),
                    const SizedBox(height: 16),
                    FilledButton.icon(
                      onPressed: _busy ? null : _save,
                      icon: const Icon(Icons.save_outlined),
                      label: Text(
                        _busy
                            ? p.text('Saving…', 'सहेज रहे हैं…')
                            : p.text(
                                'Save personal note',
                                'व्यक्तिगत नोट सहेजें',
                              ),
                      ),
                    ),
                    const SizedBox(height: 8),
                    TextButton.icon(
                      onPressed: _busy ? null : _copy,
                      icon: const Icon(Icons.copy_outlined),
                      label: Text(p.text('Copy a summary', 'सारांश कॉपी करें')),
                    ),
                    TextButton.icon(
                      onPressed: _busy
                          ? null
                          : () => Navigator.of(context).push(
                              MaterialPageRoute<void>(
                                builder: (_) => const HelpScreen(),
                              ),
                            ),
                      icon: const Icon(Icons.help_outline),
                      label: Text(
                        p.text(
                          'Read help / official contacts',
                          'सहायता / सरकारी संपर्क देखें',
                        ),
                      ),
                    ),
                    const SizedBox(height: 20),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
