import 'package:flutter/material.dart';

import '../../../core/settings/app_preferences.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({
    super.key,
    this.onClearLocalData,
    this.onClearIssueNotes,
  });
  final Future<void> Function()? onClearIssueNotes;

  /// The app owner clears the current account's (or guest's) saved visit plans.
  /// This screen must never clear Firebase credentials or all device storage.
  final Future<void> Function()? onClearLocalData;

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  bool _clearing = false;

  Future<void> _clearIssues() async {
    if (_clearing || widget.onClearIssueNotes == null) return;
    final p = AppPreferences.of(context);
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        scrollable: true,
        title: Text(
          p.text('Clear your follow-up notes?', 'अपने फॉलो-अप नोट हटाएँ?'),
        ),
        content: Text(
          p.text(
            'Remove all personal problem notes and their histories for this account or guest on this device. Keep a copy first. Other accounts and visit plans are kept. Official complaints are not affected.',
            'इस फ़ोन पर मौजूदा खाते या अतिथि की समस्या के नोट और उनका इतिहास हटाएँ। पहले कॉपी रख लें। दूसरे खाते और यात्रा योजनाएँ रहेंगी। सरकारी शिकायतों पर असर नहीं होगा।',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(p.text('Keep notes', 'नोट रखें')),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text(p.text('Clear notes', 'नोट हटाएँ')),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    setState(() => _clearing = true);
    var success = false;
    try {
      await widget.onClearIssueNotes!();
      success = true;
    } catch (_) {
      /* Keep confirmation truthful on storage failure. */
    }
    if (!mounted) return;
    setState(() => _clearing = false);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          success
              ? p.text(
                  'Your personal follow-up notes were cleared.',
                  'आपके व्यक्तिगत फॉलो-अप नोट हट गए।',
                )
              : p.text(
                  'Could not clear notes. Please try again.',
                  'नोट नहीं हटा सके। फिर कोशिश करें।',
                ),
        ),
      ),
    );
  }

  Future<void> _clear() async {
    if (_clearing || widget.onClearLocalData == null) return;
    final p = AppPreferences.of(context);
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        scrollable: true,
        title: Text(
          p.text(
            'Clear your saved visit plans?',
            'अपनी सहेजी यात्रा योजनाएँ हटाएँ?',
          ),
        ),
        content: Text(
          p.text(
            'This removes all visit plans saved for the current account or guest on this phone. Other accounts, app settings and downloaded public information are kept. It does not cancel a government token or delete your account. Keep any details you still need first.',
            'इस फोन पर मौजूदा खाते या अतिथि की सभी यात्रा योजनाएँ हटेंगी। दूसरे खाते, ऐप की सेटिंग और डाउनलोड की गई सार्वजनिक जानकारी बनी रहेगी। सरकारी टोकन रद्द नहीं होगा और खाता नहीं मिटेगा। ज़रूरी जानकारी पहले लिख लें।',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(p.text('Keep data', 'जानकारी रहने दें')),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text(p.text('Clear plans', 'योजनाएँ हटाएँ')),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    setState(() => _clearing = true);
    try {
      await widget.onClearLocalData!();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            p.text(
              'Your saved visit plans were cleared from this phone.',
              'इस फोन से आपकी सहेजी यात्रा योजनाएँ हटा दी गईं।',
            ),
          ),
        ),
      );
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            p.text(
              'Could not clear the visit plans. Please try again.',
              'यात्रा योजनाएँ नहीं हटीं। फिर कोशिश करें।',
            ),
          ),
        ),
      );
    } finally {
      if (mounted) setState(() => _clearing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final p = AppPreferences.of(context);
    return Scaffold(
      appBar: AppBar(
        title: Text(p.text('Language & settings', 'भाषा और सेटिंग')),
      ),
      body: Align(
        alignment: Alignment.topCenter,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 760),
          child: ListView(
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 32),
            children: [
              Text(
                p.text(
                  'Make the app comfortable for you',
                  'ऐप अपनी सुविधा से चलाएँ',
                ),
                style: Theme.of(context).textTheme.titleLarge,
              ),
              const SizedBox(height: 18),
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(18),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Text(
                        p.text('App language', 'ऐप की भाषा'),
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                      const SizedBox(height: 6),
                      Text(
                        p.text(
                          'Core guidance is available without internet.',
                          'मुख्य सहायता बिना इंटरनेट भी उपलब्ध है।',
                        ),
                      ),
                      const SizedBox(height: 14),
                      SegmentedButton<bool>(
                        segments: const [
                          ButtonSegment(value: true, label: Text('हिन्दी')),
                          ButtonSegment(value: false, label: Text('English')),
                        ],
                        selected: {p.hindi},
                        onSelectionChanged: (selection) =>
                            p.setHindi(selection.first),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 14),
              Card(
                child: Column(
                  children: [
                    SwitchListTile.adaptive(
                      value: p.lowData,
                      onChanged: p.setLowData,
                      title: Text(
                        p.text('Use less data', 'कम डेटा इस्तेमाल करें'),
                      ),
                      subtitle: Text(
                        p.text(
                          'Prefer saved information. Load online content only when you ask. Voice and external websites may use more data.',
                          'सहेजी जानकारी पहले दिखेगी। आपके कहने पर ऑनलाइन जानकारी लोड होगी। आवाज़ और बाहरी वेबसाइट में ज़्यादा डेटा लग सकता है।',
                        ),
                      ),
                      contentPadding: const EdgeInsets.all(18),
                    ),
                    const Divider(height: 1),
                    SwitchListTile.adaptive(
                      value: p.largeText,
                      onChanged: p.setLargeText,
                      title: Text(p.text('Larger text', 'बड़े अक्षर')),
                      subtitle: Text(
                        p.text(
                          'Make reading easier. Your phone’s accessibility settings still apply.',
                          'पढ़ना आसान बनाएँ। फोन की सुलभता सेटिंग भी लागू रहेगी।',
                        ),
                      ),
                      contentPadding: const EdgeInsets.all(18),
                    ),
                  ],
                ),
              ),
              if (p.saveFailed) ...[
                const SizedBox(height: 12),
                Text(
                  p.text(
                    'These settings work now, but could not be saved on this device. They may reset when you close the app.',
                    'सेटिंग अभी लागू हैं, लेकिन इस फोन पर सहेजी नहीं गईं। ऐप बंद करने पर बदल सकती हैं।',
                  ),
                  style: TextStyle(color: Theme.of(context).colorScheme.error),
                ),
              ],
              const SizedBox(height: 24),
              Text(
                p.text('Using a shared phone', 'साझा फोन का इस्तेमाल'),
                style: Theme.of(context).textTheme.titleLarge,
              ),
              const SizedBox(height: 10),
              Text(
                p.text(
                  'Saved visit plans can be seen by anyone using this app on the same phone. Keep your official receipts on paper if needed. Sign out when you finish.',
                  'इस फोन पर ऐप चलाने वाला व्यक्ति सहेजी यात्रा योजना देख सकता है। ज़रूरत हो तो सरकारी रसीद कागज़ पर रखें। काम के बाद लॉगआउट करें।',
                ),
              ),
              if (widget.onClearLocalData != null) ...[
                const SizedBox(height: 16),
                OutlinedButton.icon(
                  onPressed: _clearing ? null : _clear,
                  icon: const Icon(Icons.delete_outline),
                  label: Text(
                    p.text(
                      _clearing ? 'Clearing…' : 'Clear my saved visit plans',
                      _clearing
                          ? 'हटाया जा रहा है…'
                          : 'अपनी सहेजी यात्रा योजनाएँ हटाएँ',
                    ),
                  ),
                ),
              ],
              const SizedBox(height: 24),
              Text(
                p.text('Your information', 'आपकी जानकारी'),
                style: Theme.of(context).textTheme.titleMedium,
              ),
              if (widget.onClearIssueNotes != null) ...[
                const SizedBox(height: 12),
                OutlinedButton.icon(
                  onPressed: _clearing ? null : _clearIssues,
                  icon: const Icon(Icons.delete_outline),
                  label: Text(
                    p.text(
                      'Clear my follow-up notes',
                      'अपने फॉलो-अप नोट हटाएँ',
                    ),
                  ),
                ),
              ],
              const SizedBox(height: 8),
              Text(
                p.text(
                  'You can read help and prepare a visit without signing in. Never enter an Aadhaar number, bank account, OTP or UPI PIN into chat. App sign-in does not verify government procurement eligibility.',
                  'बिना लॉगिन सहायता पढ़ें और यात्रा की तैयारी करें। चैट में आधार नंबर, बैंक खाता, OTP या UPI PIN न डालें। ऐप लॉगिन से सरकारी खरीदी की पात्रता प्रमाणित नहीं होती।',
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
