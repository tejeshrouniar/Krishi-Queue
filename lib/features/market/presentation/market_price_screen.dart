import 'package:flutter/material.dart';

import '../../../core/settings/app_preferences.dart';
import '../../../core/theme/app_theme.dart';
import '../data/market_price_repository.dart';

class MarketPriceScreen extends StatefulWidget {
  final MarketPriceRepository repository;
  const MarketPriceScreen({super.key, required this.repository});
  @override
  State<MarketPriceScreen> createState() => _MarketPriceScreenState();
}

class _MarketPriceScreenState extends State<MarketPriceScreen> {
  final _search = TextEditingController();
  List<MarketPrice> _prices = [];
  bool _loading = true;
  bool _failed = false;
  String? _crop;
  String? _market;

  @override
  void initState() {
    super.initState();
    _load(refresh: false);
    _search.addListener(_rebuild);
  }

  void _rebuild() => setState(() {});
  @override
  void dispose() {
    _search.removeListener(_rebuild);
    _search.dispose();
    super.dispose();
  }

  Future<void> _load({bool refresh = true}) async {
    if (_loading && refresh) return;
    setState(() {
      _loading = true;
      _failed = false;
    });
    try {
      final repository = widget.repository;
      final prices = repository is MarketPriceRepositoryImpl
          ? await (refresh
                ? repository.refreshMarketPrices()
                : repository.getCachedPrices())
          : await repository.getMarketPrices();
      if (!mounted) return;
      setState(() {
        _prices = prices;
        if (!_prices.any((p) => p.commodity == _crop)) _crop = null;
        if (!_prices.any((p) => p.market == _market)) _market = null;
        _loading = false;
        _failed =
            repository is MarketPriceRepositoryImpl &&
            repository.refreshError != null;
      });
    } catch (_) {
      if (mounted) {
        setState(() {
          _loading = false;
          _failed = true;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final p = AppPreferences.of(context);
    final repository = widget.repository;
    final savedAt = repository is MarketPriceRepositoryImpl
        ? repository.lastFetchedAt
        : null;
    final query = _search.text.trim().toLowerCase();
    final filtered = _prices
        .where(
          (r) =>
              (_crop == null || r.commodity == _crop) &&
              (_market == null || r.market == _market) &&
              '${r.commodity} ${r.variety} ${r.market} ${r.district}'
                  .toLowerCase()
                  .contains(query),
        )
        .toList();
    return Scaffold(
      appBar: AppBar(
        title: Text(p.text('Mandi prices', 'मंडी भाव')),
        actions: [
          IconButton(
            onPressed: _loading ? null : _load,
            tooltip: p.text('Get latest reports', 'नई रिपोर्ट लें'),
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _load,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 30),
          physics: const AlwaysScrollableScrollPhysics(),
          children: [
            Text(
              p.text('Chhattisgarh', 'छत्तीसगढ़'),
              style: Theme.of(context).textTheme.headlineSmall
                  ?.copyWith(fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 8),
            Text(
              p.text(
                'Dated trading reports, not guaranteed MSP or procurement rates. Confirm the season, crop and grade with your society.',
                'तारीख सहित व्यापार रिपोर्ट, MSP या खरीदी दर की गारंटी नहीं। सीजन, फसल और ग्रेड की समिति से पुष्टि करें।',
              ),
            ),
            const SizedBox(height: 12),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      savedAt == null
                          ? p.text(
                              'No reports saved yet',
                              'अभी रिपोर्ट सहेजी नहीं गई',
                            )
                          : p.text(
                              'Saved ${_date(savedAt)} at ${savedAt.hour.toString().padLeft(2, '0')}:${savedAt.minute.toString().padLeft(2, '0')}',
                              '${_date(savedAt)} को ${savedAt.hour.toString().padLeft(2, '0')}:${savedAt.minute.toString().padLeft(2, '0')} बजे सहेजा',
                            ),
                      style: const TextStyle(fontWeight: FontWeight.w700),
                    ),
                    const SizedBox(height: 6),
                    if (repository is MarketPriceRepositoryImpl &&
                        repository.saveFailed)
                      Text(
                        p.text(
                          'These reports could not be saved on this phone. They may be unavailable after closing the app.',
                          'ये रिपोर्ट इस फोन पर सहेजी नहीं जा सकीं। ऐप बंद करने के बाद उपलब्ध न हों।',
                        ),
                      ),
                    Text(
                      p.text(
                        'Reading saved reports uses no data. Tap refresh for new reports when connected and signed in. Check the observation date on each report.',
                        'सहेजी रिपोर्ट पढ़ने में डेटा नहीं लगता। इंटरनेट और साइन-इन के बाद नई रिपोर्ट के लिए रिफ्रेश करें। हर रिपोर्ट की तारीख देखें।',
                      ),
                    ),
                    if (_failed)
                      Padding(
                        padding: const EdgeInsets.only(top: 8),
                        child: Semantics(
                          liveRegion: true,
                          child: Text(
                            (repository is MarketPriceRepositoryImpl
                                    ? repository.refreshFailure
                                          ?.localizedMessage(hindi: p.hindi)
                                    : null) ??
                                p.text(
                                  'Update unavailable. Saved reports may be old. Try again later.',
                                  'नई जानकारी नहीं मिली। सहेजी रिपोर्ट पुरानी हो सकती है। बाद में कोशिश करें।',
                                ),
                            style: const TextStyle(
                              color: AppTheme.darkGreen,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _search,
              decoration: InputDecoration(
                labelText: p.text(
                  'Search crop, district or mandi',
                  'फसल, जिला या मंडी खोजें',
                ),
                prefixIcon: const Icon(Icons.search),
                suffixIcon: _search.text.isEmpty
                    ? null
                    : IconButton(
                        tooltip: p.text('Clear search', 'खोज साफ करें'),
                        onPressed: _search.clear,
                        icon: const Icon(Icons.close),
                      ),
              ),
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                FilterChip(
                  label: Text(_crop ?? p.text('All crops', 'सभी फसलें')),
                  selected: _crop != null,
                  onSelected: (_) => _choose(crop: true),
                ),
                FilterChip(
                  label: Text(_market ?? p.text('All mandis', 'सभी मंडियाँ')),
                  selected: _market != null,
                  onSelected: (_) => _choose(crop: false),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Text(
              p.text(
                'Source: data.gov.in mandi reports · up to 100 records',
                'स्रोत: data.gov.in मंडी रिपोर्ट · अधिकतम 100 रिकॉर्ड',
              ),
              style: const TextStyle(color: AppTheme.textSecondary),
            ),
            if (_loading)
              const Padding(
                padding: EdgeInsets.all(24),
                child: Center(child: CircularProgressIndicator()),
              ),
            if (!_loading && filtered.isEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 24),
                child: Text(
                  _prices.isEmpty
                      ? p.text(
                          'No saved reports to show. You can still prepare your visit and use offline help.',
                          'दिखाने के लिए रिपोर्ट सहेजी नहीं है। यात्रा की तैयारी और ऑफलाइन मदद उपलब्ध है।',
                        )
                      : p.text(
                          'No reports match these filters.',
                          'इन फ़िल्टर से कोई रिपोर्ट नहीं मिली।',
                        ),
                ),
              ),
            const SizedBox(height: 12),
            ...filtered.map((price) => _PriceCard(price: price)),
          ],
        ),
      ),
    );
  }

  Future<void> _choose({required bool crop}) async {
    final p = AppPreferences.of(context);
    final values =
        _prices.map((r) => crop ? r.commodity : r.market).toSet().toList()
          ..sort();
    await showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (sheetContext) => SafeArea(
        child: ListView(
          shrinkWrap: true,
          children: [
            ListTile(
              title: Text(p.text('Show all', 'सभी दिखाएँ')),
              onTap: () {
                setState(() {
                  if (crop) {
                    _crop = null;
                  } else {
                    _market = null;
                  }
                });
                Navigator.pop(sheetContext);
              },
            ),
            ...values.map(
              (value) => ListTile(
                title: Text(value),
                selected: value == (crop ? _crop : _market),
                onTap: () {
                  setState(() {
                    if (crop) {
                      _crop = value;
                    } else {
                      _market = value;
                    }
                  });
                  Navigator.pop(sheetContext);
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

String _date(DateTime date) => '${date.day}/${date.month}/${date.year}';

class _PriceCard extends StatelessWidget {
  final MarketPrice price;
  const _PriceCard({required this.price});
  @override
  Widget build(BuildContext context) {
    final p = AppPreferences.of(context);
    final stale = DateTime.now().difference(price.observationDate).inDays > 2;
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Card(
        child: Padding(
          padding: const EdgeInsets.all(18),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '${price.commodity} · ${price.variety}',
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 4),
              Text('${price.market}, ${price.district}'),
              const SizedBox(height: 12),
              Text(
                '₹${price.modalPrice} / ${p.text('quintal', 'क्विंटल')}',
                style: const TextStyle(
                  fontSize: 24,
                  color: AppTheme.darkGreen,
                  fontWeight: FontWeight.w800,
                ),
              ),
              Text(p.text('Reported modal price', 'रिपोर्ट का प्रचलित भाव')),
              const SizedBox(height: 8),
              Text(
                p.text(
                  'Range ₹${price.minPrice}–₹${price.maxPrice} · Grade: ${price.grade.isEmpty ? 'not reported' : price.grade}',
                  'सीमा ₹${price.minPrice}–₹${price.maxPrice} · ग्रेड: ${price.grade.isEmpty ? 'नहीं बताया गया' : price.grade}',
                ),
              ),
              const SizedBox(height: 8),
              Text(
                '${p.text('Observed', 'रिपोर्ट की तारीख')}: ${_date(price.observationDate)}${stale ? p.text(' · older report', ' · पुरानी रिपोर्ट') : ''}',
                style: const TextStyle(fontWeight: FontWeight.w700),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
