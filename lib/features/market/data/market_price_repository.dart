import '../../../core/network/krishi_gateway.dart';
import '../../../core/storage/content_cache.dart';

class MarketPrice {
  final String commodity;
  final String variety;
  final String market;
  final String district;
  final String state;
  final String grade;
  final int minPrice;
  final int maxPrice;
  final int modalPrice;
  final DateTime observationDate;

  const MarketPrice({
    required this.commodity,
    required this.variety,
    required this.market,
    required this.district,
    required this.state,
    required this.grade,
    required this.minPrice,
    required this.maxPrice,
    required this.modalPrice,
    required this.observationDate,
  });

  static MarketPrice? fromRecord(Map<dynamic, dynamic> record) {
    String field(String name) => record[name]?.toString().trim() ?? '';
    int? number(String name) {
      final value = double.tryParse(field(name).replaceAll(',', ''));
      return value != null && value.isFinite && value >= 0
          ? value.round()
          : null;
    }

    final parts = field('arrival_date').split('/');
    DateTime? date;
    if (parts.length == 3) {
      final day = int.tryParse(parts[0]),
          month = int.tryParse(parts[1]),
          year = int.tryParse(parts[2]);
      if (day != null && month != null && year != null) {
        final candidate = DateTime(year, month, day);
        if (candidate.day == day &&
            candidate.month == month &&
            candidate.year == year) {
          date = candidate;
        }
      }
    } else {
      final raw = field('arrival_date');
      final candidate = DateTime.tryParse(raw);
      if (candidate != null &&
          candidate.toIso8601String().startsWith(raw.split('T').first)) {
        date = candidate;
      }
    }
    final minimum = number('min_price'),
        maximum = number('max_price'),
        modal = number('modal_price');
    if (field('commodity').isEmpty ||
        field('market').isEmpty ||
        date == null ||
        minimum == null ||
        maximum == null ||
        modal == null ||
        minimum > maximum ||
        modal < minimum ||
        modal > maximum ||
        date.isAfter(DateTime.now().add(const Duration(days: 1)))) {
      return null;
    }
    return MarketPrice(
      commodity: field('commodity'),
      variety: field('variety'),
      market: field('market'),
      district: field('district'),
      state: field('state'),
      grade: field('grade'),
      minPrice: minimum,
      maxPrice: maximum,
      modalPrice: modal,
      observationDate: date,
    );
  }
}

abstract class MarketPriceRepository {
  Future<List<MarketPrice>> getMarketPrices();
}

class MarketPriceRepositoryImpl implements MarketPriceRepository {
  MarketPriceRepositoryImpl({KrishiGateway? gateway, ContentCache? cache})
    : _gateway = gateway ?? KrishiGateway(),
      _cache = cache ?? ContentCache();
  final KrishiGateway _gateway;
  final ContentCache _cache;
  DateTime? lastFetchedAt;
  bool fromCache = false;
  bool saveFailed = false;
  String? refreshError;
  GatewayException? refreshFailure;

  Future<List<MarketPrice>> getCachedPrices() async {
    final saved = await _cache.read('market_cg');
    if (saved == null) {
      lastFetchedAt = null;
      fromCache = false;
      return [];
    }
    lastFetchedAt = saved.savedAt;
    fromCache = true;
    return _parse(saved.records);
  }

  @override
  Future<List<MarketPrice>> getMarketPrices() async {
    final cached = await getCachedPrices();
    return cached.isNotEmpty ? cached : refreshMarketPrices();
  }

  Future<List<MarketPrice>> refreshMarketPrices() async {
    refreshError = null;
    refreshFailure = null;
    try {
      final data = await _gateway.post('market', {});
      final records = data['records'];
      if (records is! List) {
        throw const FormatException('Missing market records');
      }
      final prices = _parse(records);
      if (prices.isEmpty) {
        throw const GatewayException(
          'No current Chhattisgarh price reports are available.',
        );
      }
      final valid = records
          .whereType<Map>()
          .map((r) => Map<String, dynamic>.from(r))
          .toList();
      saveFailed = !await _cache.write('market_cg', valid);
      lastFetchedAt = saveFailed ? null : DateTime.now();
      fromCache = false;
      return prices;
    } catch (error) {
      refreshError = error.toString();
      refreshFailure = error is GatewayException ? error : null;
      final saved = await getCachedPrices();
      if (saved.isNotEmpty) return saved;
      rethrow;
    }
  }

  List<MarketPrice> _parse(List<dynamic> records) =>
      records
          .whereType<Map>()
          .where((r) => r['state']?.toString().toLowerCase() == 'chhattisgarh')
          .map(MarketPrice.fromRecord)
          .whereType<MarketPrice>()
          .take(100)
          .toList()
        ..sort((a, b) => b.observationDate.compareTo(a.observationDate));

  void dispose() => _gateway.dispose();
}
