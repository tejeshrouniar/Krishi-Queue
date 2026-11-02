import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../core/settings/app_preferences.dart';
import '../../../core/theme/app_theme.dart';
import '../data/farmer_guides.dart';

class HelpScreen extends StatefulWidget {
  final VoidCallback? onOpenIssues;
  const HelpScreen({super.key, this.onOpenIssues});

  @override
  State<HelpScreen> createState() => _HelpScreenState();
}

class _HelpScreenState extends State<HelpScreen> {
  String _query = '';

  Future<void> _open(String address) async {
    final prefs = AppPreferences.of(context);
    try {
      if (await launchUrl(
        Uri.parse(address),
        mode: LaunchMode.externalApplication,
      )) {
        return;
      }
    } catch (_) {
      // A tablet or desktop may have no dialler or browser registered.
    }
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          prefs.text(
            'Could not open this service. Use the number or address shown below.',
            'सेवा नहीं खुली। नीचे दिया नंबर या पता इस्तेमाल करें।',
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final p = AppPreferences.of(context);
    final guides = farmerGuides
        .where((guide) => guide.matches(_query))
        .toList();
    return Scaffold(
      appBar: AppBar(title: Text(p.text('Help for farmers', 'किसान सहायता'))),
      body: Align(
        alignment: Alignment.topCenter,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 760),
          child: ListView(
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 32),
            children: [
              _Notice(
                icon: Icons.offline_pin_outlined,
                title: p.text(
                  'Read this guide without internet',
                  'बिना इंटरनेट भी पढ़ें',
                ),
                body: p.text(
                  'Saved inside the app. Calls need mobile signal; official websites need internet.',
                  'यह गाइड ऐप में सहेजी है। कॉल के लिए मोबाइल सिग्नल और वेबसाइट के लिए इंटरनेट चाहिए।',
                ),
              ),
              const SizedBox(height: 20),
              if (widget.onOpenIssues != null) ...[
                OutlinedButton.icon(onPressed: widget.onOpenIssues, icon: const Icon(Icons.assignment_outlined), label: Text(p.text('Open my personal follow-ups', 'मेरे व्यक्तिगत फॉलो-अप खोलें'))),
                const SizedBox(height: 16),
              ],
              TextField(
                onChanged: (value) => setState(() => _query = value),
                decoration: InputDecoration(
                  labelText: p.text('Search help', 'मदद खोजें'),
                  hintText: p.text(
                    'Payment, token, documents…',
                    'भुगतान, टोकन, कागज़…',
                  ),
                  prefixIcon: const Icon(Icons.search),
                ),
              ),
              const SizedBox(height: 18),
              if (guides.isEmpty)
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: Text(
                    p.text(
                      'No guide found. Try “payment”, “token” or “network”, or call a helpline below.',
                      'गाइड नहीं मिली। “भुगतान”, “टोकन” या “नेटवर्क” खोजें, या नीचे हेल्पलाइन पर कॉल करें।',
                    ),
                  ),
                ),
              for (final guide in guides) ...[
                Card(
                  child: ExpansionTile(
                    key: PageStorageKey(guide.id),
                    tilePadding: const EdgeInsets.symmetric(
                      horizontal: 18,
                      vertical: 7,
                    ),
                    childrenPadding: const EdgeInsets.fromLTRB(18, 0, 18, 18),
                    title: Text(
                      p.text(guide.title, guide.titleHindi),
                      style: const TextStyle(fontWeight: FontWeight.w700),
                    ),
                    subtitle: Padding(
                      padding: const EdgeInsets.only(top: 6),
                      child: Text(p.text(guide.summary, guide.summaryHindi)),
                    ),
                    children: [
                      for (final (index, step)
                          in (p.hindi ? guide.stepsHindi : guide.steps).indexed)
                        Padding(
                          padding: const EdgeInsets.only(top: 14),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                '${index + 1}.',
                                style: const TextStyle(
                                  color: AppTheme.primaryGreen,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: SelectableText(
                                  step,
                                  key: PageStorageKey(
                                    '${guide.id}-step-$index',
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                    ],
                  ),
                ),
                const SizedBox(height: 10),
              ],
              const SizedBox(height: 16),
              Text(
                p.text('Speak to someone', 'किसी से बात करें'),
                style: Theme.of(context).textTheme.titleLarge,
              ),
              const SizedBox(height: 12),
              _ContactCard(
                title: p.text('Kisan Call Centre', 'किसान कॉल सेंटर'),
                number: '1800 180 1551',
                detail: p.text(
                  'Free farming advice in local languages. Every day, 6 am–10 pm.',
                  'स्थानीय भाषाओं में नि:शुल्क खेती की सलाह। रोज़ सुबह 6 से रात 10 बजे।',
                ),
                source: kisanCallCentreSource,
                onCall: () => _open('tel:$kisanCallCentreNumber'),
                onSource: () => _open(kisanCallCentreSource),
              ),
              const SizedBox(height: 12),
              _ContactCard(
                title: p.text(
                  'Chhattisgarh Food Department',
                  'छत्तीसगढ़ खाद्य विभाग',
                ),
                number: '1800 233 3663',
                detail: p.text(
                  'Official toll-free line for Food Department complaints. Ask which office handles your matter.',
                  'खाद्य विभाग की शिकायतों के लिए सरकारी नि:शुल्क नंबर। अपने मामले का संबंधित कार्यालय पूछें।',
                ),
                source: foodComplaintSource,
                onCall: () => _open('tel:$foodDepartmentNumber'),
                onSource: () => _open(foodComplaintSource),
              ),
              const SizedBox(height: 24),
              Text(
                p.text('Official services', 'सरकारी सेवाएँ'),
                style: Theme.of(context).textTheme.titleLarge,
              ),
              const SizedBox(height: 8),
              Text(
                p.text(
                  'These links open outside Krishi Queue and need internet. Check the organisation before sharing details.',
                  'ये लिंक Krishi Queue से बाहर खुलते हैं और इंटरनेट चाहिए। जानकारी देने से पहले संस्था जाँचें।',
                ),
                style: Theme.of(context).textTheme.bodyMedium,
              ),
              const SizedBox(height: 12),
              _OfficialLink(
                title: p.text('Token Tuhar · NIC', 'Token Tuhar · NIC'),
                detail: p.text(
                  'Official paddy token app on Google Play',
                  'Google Play पर सरकारी धान टोकन ऐप',
                ),
                address: officialTokenUrl,
                onTap: () => _open(officialTokenUrl),
              ),
              _OfficialLink(
                title: p.text(
                  'Chhattisgarh Food Department',
                  'छत्तीसगढ़ खाद्य विभाग',
                ),
                detail: p.text(
                  'Orders, services and notices',
                  'आदेश, सेवाएँ और सूचनाएँ',
                ),
                address: officialFoodUrl,
                onTap: () => _open(officialFoodUrl),
              ),
              _OfficialLink(
                title: p.text(
                  'India Meteorological Department',
                  'भारत मौसम विज्ञान विभाग',
                ),
                detail: p.text(
                  'Official weather forecasts and warnings',
                  'सरकारी मौसम पूर्वानुमान और चेतावनी',
                ),
                address: officialWeatherUrl,
                onTap: () => _open(officialWeatherUrl),
              ),
              _OfficialLink(
                title: p.text(
                  'Agriculture and Farmers Welfare',
                  'कृषि एवं किसान कल्याण',
                ),
                detail: p.text(
                  'Official scheme and farming information',
                  'सरकारी योजना और खेती की जानकारी',
                ),
                address: officialAgricultureUrl,
                onTap: () => _open(officialAgricultureUrl),
              ),
              const SizedBox(height: 20),
              Text(
                p.text(
                  'Contact sources checked: 31 October 2026. Numbers and hours may change; the official source is linked on each card.',
                  'संपर्क स्रोत जाँचे: 31 अक्टूबर 2026। नंबर और समय बदल सकते हैं; हर कार्ड में सरकारी स्रोत दिया है।',
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

class _Notice extends StatelessWidget {
  const _Notice({required this.icon, required this.title, required this.body});
  final IconData icon;
  final String title;
  final String body;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(18),
    decoration: BoxDecoration(
      color: AppTheme.paleGreen,
      borderRadius: BorderRadius.circular(16),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, color: AppTheme.primaryGreen),
        const SizedBox(height: 10),
        Text(title, style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: 6),
        Text(body),
      ],
    ),
  );
}

class _ContactCard extends StatelessWidget {
  const _ContactCard({
    required this.title,
    required this.number,
    required this.detail,
    required this.source,
    required this.onCall,
    required this.onSource,
  });
  final String title;
  final String number;
  final String detail;
  final String source;
  final VoidCallback onCall;
  final VoidCallback onSource;

  @override
  Widget build(BuildContext context) {
    final p = AppPreferences.of(context);
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(title, style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 8),
            SelectableText(
              number,
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                color: AppTheme.primaryGreen,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 8),
            Text(detail),
            const SizedBox(height: 14),
            FilledButton.icon(
              onPressed: onCall,
              icon: const Icon(Icons.call_outlined),
              label: Text(p.text('Call helpline', 'हेल्पलाइन पर कॉल करें')),
            ),
            TextButton.icon(
              onPressed: onSource,
              icon: const Icon(Icons.open_in_new, size: 18),
              label: Text(p.text('Official source', 'सरकारी स्रोत')),
            ),
            SelectableText(
              Uri.parse(source).host,
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ],
        ),
      ),
    );
  }
}

class _OfficialLink extends StatelessWidget {
  const _OfficialLink({
    required this.title,
    required this.detail,
    required this.address,
    required this.onTap,
  });
  final String title;
  final String detail;
  final String address;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Card(
    margin: const EdgeInsets.only(bottom: 10),
    child: ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 18, vertical: 8),
      title: Text(title),
      subtitle: Text('$detail\n${Uri.parse(address).host}'),
      trailing: const Icon(Icons.open_in_new, size: 20),
      onTap: onTap,
    ),
  );
}
