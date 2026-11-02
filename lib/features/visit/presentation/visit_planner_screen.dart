import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../core/settings/app_preferences.dart';
import '../data/visit_plan_store.dart';
import '../domain/visit_plan.dart';

class VisitPlannerScreen extends StatefulWidget {
  final VisitPlanStore store;
  const VisitPlannerScreen({super.key, required this.store});

  @override
  State<VisitPlannerScreen> createState() => _VisitPlannerScreenState();
}

class _VisitPlannerScreenState extends State<VisitPlannerScreen> {
  List<VisitPlan>? _plans;
  bool _failed = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final plans = await widget.store.load();
      if (mounted) {
        setState(() {
          _plans = plans;
          _failed = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _failed = true);
    }
  }

  Future<void> _edit([VisitPlan? plan]) async {
    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => _VisitEditor(store: widget.store, plan: plan),
      ),
    );
    await _load();
  }

  @override
  Widget build(BuildContext context) {
    final p = AppPreferences.of(context);
    return Scaffold(
      appBar: AppBar(
        title: Text(p.text('My visit plans', 'मेरी यात्रा की तैयारी')),
      ),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 720),
          child: ListView(
            padding: const EdgeInsets.all(20),
            children: [
              _Notice(
                text: p.text(
                  'Saved on this device. A plan does not reserve a slot. Confirm your date and token with your registered society before travelling.',
                  'तैयारी इस फ़ोन में सहेजी जाती है। इससे स्लॉट बुक नहीं होता। निकलने से पहले अपनी पंजीकृत समिति से तारीख और टोकन की पुष्टि करें।',
                ),
              ),
              const SizedBox(height: 20),
              if (_failed) ...[
                Text(
                  p.text(
                    'Saved plans could not be opened. They have not been replaced. Retry, or clear them in Settings if you no longer need them.',
                    'सहेजी गई तैयारी खुल नहीं सकी। उसे बदला नहीं गया है। फिर प्रयास करें, या जरूरत न हो तो सेटिंग में हटाएँ।',
                  ),
                ),
                TextButton(
                  onPressed: _load,
                  child: Text(p.text('Try again', 'फिर कोशिश करें')),
                ),
              ] else if (_plans == null)
                const Center(child: CircularProgressIndicator())
              else ...[
                if (_plans!.isEmpty)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 28),
                    child: Column(
                      children: [
                        const Icon(Icons.assignment_outlined, size: 42),
                        const SizedBox(height: 12),
                        Text(
                          p.text(
                            'Prepare before you leave',
                            'निकलने से पहले तैयारी करें',
                          ),
                          style: Theme.of(context).textTheme.titleLarge,
                        ),
                        const SizedBox(height: 8),
                        Text(
                          p.text(
                            'Keep your centre, crop, date and checklist together. You can open them without internet.',
                            'केंद्र, फसल, तारीख और तैयारी की सूची एक जगह रखें। इन्हें बिना इंटरनेट भी खोल सकते हैं।',
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ],
                    ),
                  ),
                for (final plan in _plans!)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: Card(
                      child: ListTile(
                        contentPadding: const EdgeInsets.all(16),
                        title: Text(
                          plan.centre,
                          style: const TextStyle(fontWeight: FontWeight.w700),
                        ),
                        subtitle: Text(
                          '${_date(plan.date)} · ${plan.crop} · ${plan.quantity} ${p.text('quintals', 'क्विंटल')}\n${p.text('Personal plan · not verified', 'व्यक्तिगत तैयारी · सत्यापित नहीं')}',
                        ),
                        isThreeLine: true,
                        trailing: const Icon(Icons.chevron_right),
                        onTap: () => _edit(plan),
                      ),
                    ),
                  ),
                FilledButton.icon(
                  onPressed: () => _edit(),
                  icon: const Icon(Icons.add),
                  label: Text(
                    p.text('Prepare a visit', 'यात्रा की तैयारी जोड़ें'),
                  ),
                ),
              ],
              const SizedBox(height: 20),
              Text(
                p.text(
                  'Using a shared phone? These notes remain on this device. Delete them when you are done. Do not save Aadhaar, bank numbers, PINs or OTPs.',
                  'साझा फ़ोन इस्तेमाल कर रहे हैं? ये नोट इसी फ़ोन पर रहते हैं। काम होने पर इन्हें हटा दें। आधार, बैंक नंबर, पिन या OTP न लिखें।',
                ),
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

String _date(DateTime date) =>
    '${date.day.toString().padLeft(2, '0')}/${date.month.toString().padLeft(2, '0')}/${date.year}';

double? _parseQuantity(String text) {
  final normalized = String.fromCharCodes(
    text.trim().runes.map(
      (rune) => rune >= 0x0966 && rune <= 0x096f ? rune - 0x0966 + 0x30 : rune,
    ),
  );
  return double.tryParse(normalized);
}

class _VisitEditor extends StatefulWidget {
  final VisitPlanStore store;
  final VisitPlan? plan;
  const _VisitEditor({required this.store, this.plan});
  @override
  State<_VisitEditor> createState() => _VisitEditorState();
}

class _VisitEditorState extends State<_VisitEditor> {
  final _form = GlobalKey<FormState>();
  final _centre = TextEditingController();
  final _village = TextEditingController();
  final _quantity = TextEditingController();
  final _reference = TextEditingController();
  final _notes = TextEditingController();
  late DateTime _day;
  late String _id;
  String _crop = 'Paddy';
  final Set<String> _checks = {};
  bool _busy = false;
  bool _dirty = false;
  bool _allowPop = false;

  static const _items = [
    (
      'registration',
      'Registration and eligibility checked with my society',
      'समिति से पंजीकरण और पात्रता की जानकारी ली',
    ),
    (
      'slot',
      'Official token, centre and date confirmed before travel',
      'निकलने से पहले आधिकारिक टोकन, केंद्र और तारीख पक्की की',
    ),
    (
      'documents',
      'Documents required by my society are ready',
      'समिति द्वारा माँगे गए दस्तावेज तैयार हैं',
    ),
    (
      'crop',
      'Crop quality, moisture and packaging requirements checked',
      'फसल की गुणवत्ता, नमी और पैकिंग के नियम पूछे',
    ),
    (
      'transport',
      'Transport cost and arrival time agreed',
      'परिवहन का खर्च और पहुँचने का समय तय किया',
    ),
    (
      'receipts',
      'I will keep weighing, quality and purchase receipts',
      'तौल, गुणवत्ता और खरीद की रसीदें संभाल कर रखूँगा/रखूँगी',
    ),
  ];

  @override
  void initState() {
    super.initState();
    final plan = widget.plan;
    _id =
        plan?.id ??
        '${DateTime.now().microsecondsSinceEpoch}-${Random.secure().nextInt(1 << 30)}';
    _day = plan?.date ?? DateUtils.dateOnly(DateTime.now());
    _centre.text = plan?.centre ?? '';
    _village.text = plan?.village ?? '';
    _quantity.text = plan?.quantity.toString() ?? '';
    _reference.text = plan?.officialReference ?? '';
    _notes.text = plan?.notes ?? '';
    _crop = plan?.crop ?? 'Paddy';
    _checks.addAll(plan?.checklist ?? {});
    for (final controller in [
      _centre,
      _village,
      _quantity,
      _reference,
      _notes,
    ]) {
      controller.addListener(_changed);
    }
  }

  void _changed() {
    if (!_dirty) setState(() => _dirty = true);
  }

  @override
  void dispose() {
    for (final controller in [
      _centre,
      _village,
      _quantity,
      _reference,
      _notes,
    ]) {
      controller.dispose();
    }
    super.dispose();
  }

  Future<void> _back() async {
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
              'अभी किए गए बदलाव नहीं बचेंगे।',
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

  VisitPlan _plan() => VisitPlan(
    id: _id,
    centre: _centre.text.trim(),
    village: _village.text.trim(),
    crop: _crop,
    quantity: _parseQuantity(_quantity.text)!,
    date: _day,
    officialReference: _reference.text.trim(),
    notes: _notes.text.trim(),
    checklist: Set.unmodifiable(_checks),
    updatedAt: DateTime.now(),
  );

  Future<void> _save() async {
    if (_busy || !_form.currentState!.validate()) return;
    FocusScope.of(context).unfocus();
    setState(() => _busy = true);
    final p = AppPreferences.of(context);
    try {
      await widget.store.save(_plan());
      if (!mounted) return;
      setState(() {
        _dirty = false;
        _busy = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            p.text(
              'Saved on this device. No slot has been booked.',
              'इस फ़ोन पर सहेज लिया। कोई स्लॉट बुक नहीं हुआ है।',
            ),
          ),
        ),
      );
      await _back();
    } catch (_) {
      if (!mounted) return;
      setState(() => _busy = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            p.text(
              'Could not save. Keep this screen open and try again. You can keep up to 20 plans.',
              'सहेज नहीं सके। इस पेज को खुला रखें और फिर कोशिश करें। अधिकतम 20 तैयारी रख सकते हैं।',
            ),
          ),
        ),
      );
    }
  }

  Future<void> _copy() async {
    if (_busy || !_form.currentState!.validate()) return;
    final p = AppPreferences.of(context);
    final plan = _plan();
    final text = [
      p.text(
        'Krishi Queue · personal visit plan, NOT a government token',
        'कृषि क्यू · व्यक्तिगत तैयारी, सरकारी टोकन नहीं',
      ),
      '${p.text('Centre', 'केंद्र')}: ${plan.centre}',
      '${p.text('Village', 'गाँव')}: ${plan.village}',
      '${p.text('Date', 'तारीख')}: ${_date(plan.date)}',
      '${plan.crop} · ${plan.quantity} ${p.text('quintals', 'क्विंटल')}',
      if (plan.officialReference.isNotEmpty)
        '${p.text('Reference entered by you; not verified', 'आपके द्वारा लिखा संदर्भ; सत्यापित नहीं')}: ${plan.officialReference}',
      for (final item in _items)
        '${plan.checklist.contains(item.$1) ? '[x]' : '[ ]'} ${p.text(item.$2, item.$3)}',
      p.text(
        'Confirm with your society before travelling.',
        'निकलने से पहले समिति से पुष्टि करें।',
      ),
    ].join('\n');
    try {
      await Clipboard.setData(ClipboardData(text: text));
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            p.text(
              'Copying is unavailable. Save your plan or write the details on paper.',
              'कॉपी नहीं कर सके। तैयारी सहेजें या विवरण कागज़ पर लिख लें।',
            ),
          ),
        ),
      );
      return;
    }
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          p.text(
            'Copied. Paste into a message or keep a paper copy. This does not save edits.',
            'कॉपी हो गया। संदेश में पेस्ट करें या कागज़ पर रखें। इससे बदलाव सहेजे नहीं गए हैं।',
          ),
        ),
      ),
    );
  }

  Future<void> _delete() async {
    final p = AppPreferences.of(context);
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        scrollable: true,
        title: Text(
          p.text('Delete this personal plan?', 'यह व्यक्तिगत तैयारी हटाएँ?'),
        ),
        content: Text(
          p.text(
            'This only removes your local notes. It cannot cancel an official booking.',
            'केवल इस फ़ोन के नोट हटेंगे। आधिकारिक बुकिंग रद्द नहीं होगी।',
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
        _busy = false;
        _dirty = false;
      });
      await _back();
    } catch (_) {
      if (!mounted) return;
      setState(() => _busy = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            p.text(
              'Could not delete. Try again.',
              'हटा नहीं सके। फिर कोशिश करें।',
            ),
          ),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final p = AppPreferences.of(context);
    return PopScope(
      canPop: _allowPop || (!_dirty && !_busy),
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _back();
      },
      child: Scaffold(
        appBar: AppBar(
          title: Text(p.text('Prepare my visit', 'यात्रा की तैयारी')),
          actions: [
            if (widget.plan != null)
              IconButton(
                onPressed: _busy ? null : _delete,
                icon: const Icon(Icons.delete_outline),
                tooltip: p.text(
                  'Delete personal plan',
                  'व्यक्तिगत तैयारी हटाएँ',
                ),
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
                    _Notice(
                      text: p.text(
                        'Works without internet. Your checklist is a reminder, not official verification.',
                        'बिना इंटरनेट चलता है। यह तैयारी की सूची है, सरकारी सत्यापन नहीं।',
                      ),
                    ),
                    const SizedBox(height: 20),
                    TextFormField(
                      controller: _centre,
                      enabled: !_busy,
                      maxLength: 120,
                      decoration: InputDecoration(
                        labelText: p.text(
                          'Your registered society / centre',
                          'आपकी पंजीकृत समिति / केंद्र',
                        ),
                      ),
                      validator: (value) =>
                          value == null || value.trim().isEmpty
                          ? p.text(
                              'Enter the centre name',
                              'केंद्र का नाम लिखें',
                            )
                          : null,
                      textInputAction: TextInputAction.next,
                    ),
                    TextFormField(
                      controller: _village,
                      enabled: !_busy,
                      maxLength: 100,
                      decoration: InputDecoration(
                        labelText: p.text(
                          'Village / district (optional)',
                          'गाँव / जिला (वैकल्पिक)',
                        ),
                      ),
                      textInputAction: TextInputAction.next,
                    ),
                    DropdownButtonFormField<String>(
                      initialValue: _crop,
                      isExpanded: true,
                      decoration: InputDecoration(
                        labelText: p.text('Crop', 'फसल'),
                      ),
                      items: [
                        if (!const ['Paddy', 'Maize', 'Other'].contains(_crop))
                          DropdownMenuItem(value: _crop, child: Text(_crop)),
                        DropdownMenuItem(
                          value: 'Paddy',
                          child: Text(p.text('Paddy', 'धान')),
                        ),
                        DropdownMenuItem(
                          value: 'Maize',
                          child: Text(p.text('Maize', 'मक्का')),
                        ),
                        DropdownMenuItem(
                          value: 'Other',
                          child: Text(p.text('Other', 'अन्य')),
                        ),
                      ],
                      onChanged: _busy
                          ? null
                          : (value) {
                              if (value != null) {
                                setState(() {
                                  _crop = value;
                                  _dirty = true;
                                });
                              }
                            },
                    ),
                    const SizedBox(height: 18),
                    TextFormField(
                      controller: _quantity,
                      enabled: !_busy,
                      maxLength: 8,
                      keyboardType: const TextInputType.numberWithOptions(
                        decimal: true,
                      ),
                      decoration: InputDecoration(
                        labelText: p.text(
                          'Quantity in quintals',
                          'मात्रा क्विंटल में',
                        ),
                        helperText: p.text(
                          '1 quintal = 100 kg. Eligibility is checked by your society.',
                          '1 क्विंटल = 100 किलो। पात्रता समिति जाँचती है।',
                        ),
                        helperMaxLines: 3,
                        errorMaxLines: 3,
                      ),
                      validator: (value) {
                        final n = _parseQuantity(value ?? '');
                        return n == null || !n.isFinite || n <= 0 || n > 10000
                            ? p.text(
                                'Enter a valid quantity, above 0 and up to 10,000',
                                '0 से अधिक और 10,000 तक सही मात्रा लिखें',
                              )
                            : null;
                      },
                    ),
                    const SizedBox(height: 12),
                    OutlinedButton.icon(
                      onPressed: _busy
                          ? null
                          : () async {
                              final now = DateUtils.dateOnly(DateTime.now());
                              final last = now.add(const Duration(days: 365));
                              final initial = _day.isBefore(now)
                                  ? now
                                  : _day.isAfter(last)
                                  ? last
                                  : _day;
                              final selected = await showDatePicker(
                                context: context,
                                initialDate: initial,
                                firstDate: now,
                                lastDate: last,
                              );
                              if (selected != null && mounted) {
                                setState(() {
                                  _day = selected;
                                  _dirty = true;
                                });
                              }
                            },
                      icon: const Icon(Icons.calendar_today_outlined),
                      label: Text(
                        '${p.text('Planned date', 'सोची गई तारीख')}: ${_date(_day)}',
                      ),
                    ),
                    const SizedBox(height: 18),
                    TextFormField(
                      controller: _reference,
                      enabled: !_busy,
                      maxLength: 80,
                      decoration: InputDecoration(
                        labelText: p.text(
                          'Official token reference (optional)',
                          'आधिकारिक टोकन संदर्भ (वैकल्पिक)',
                        ),
                        helperText: p.text(
                          'Copy from your official slip. We cannot verify it.',
                          'आधिकारिक पर्ची से लिखें। हम इसका सत्यापन नहीं कर सकते।',
                        ),
                        helperMaxLines: 3,
                      ),
                    ),
                    const SizedBox(height: 16),
                    Text(
                      p.text('Before leaving home', 'घर से निकलने से पहले'),
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                    const SizedBox(height: 8),
                    for (final item in _items)
                      CheckboxListTile(
                        contentPadding: EdgeInsets.zero,
                        controlAffinity: ListTileControlAffinity.leading,
                        title: Text(p.text(item.$2, item.$3)),
                        value: _checks.contains(item.$1),
                        onChanged: _busy
                            ? null
                            : (value) => setState(() {
                                value == true
                                    ? _checks.add(item.$1)
                                    : _checks.remove(item.$1);
                                _dirty = true;
                              }),
                      ),
                    const SizedBox(height: 18),
                    TextFormField(
                      controller: _notes,
                      enabled: !_busy,
                      maxLength: 500,
                      minLines: 2,
                      maxLines: 5,
                      decoration: InputDecoration(
                        labelText: p.text('Notes (optional)', 'नोट (वैकल्पिक)'),
                        helperText: p.text(
                          'Do not enter bank details, Aadhaar, PIN or OTP.',
                          'बैंक विवरण, आधार, पिन या OTP न लिखें।',
                        ),
                        helperMaxLines: 2,
                      ),
                    ),
                    const SizedBox(height: 18),
                    FilledButton.icon(
                      onPressed: _busy ? null : _save,
                      icon: const Icon(Icons.save_outlined),
                      label: Text(
                        _busy
                            ? p.text('Saving…', 'सहेज रहे हैं…')
                            : p.text(
                                'Save on this device',
                                'इस फ़ोन पर सहेजें',
                              ),
                      ),
                    ),
                    const SizedBox(height: 8),
                    TextButton.icon(
                      onPressed: _busy ? null : _copy,
                      icon: const Icon(Icons.copy_outlined),
                      label: Text(
                        p.text(
                          'Copy a checklist for sharing / paper',
                          'संदेश / कागज़ के लिए सूची कॉपी करें',
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

class _Notice extends StatelessWidget {
  final String text;
  const _Notice({required this.text});
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(16),
    decoration: BoxDecoration(
      color: const Color(0xffedf4ec),
      borderRadius: BorderRadius.circular(12),
    ),
    child: Text(text, style: const TextStyle(height: 1.5)),
  );
}
