import '../../../core/network/krishi_gateway.dart';
import '../../../core/storage/content_cache.dart';
import '../domain/news_article.dart';

class FarmerNewsApi {
  FarmerNewsApi({KrishiGateway? gateway, ContentCache? cache})
    : _gateway = gateway ?? KrishiGateway(),
      _cache = cache ?? ContentCache();
  final KrishiGateway _gateway;
  final ContentCache _cache;
  DateTime? lastFetchedAt;
  bool fromCache = false;
  bool saveFailed = false;
  String? refreshError;
  GatewayException? refreshFailure;

  Future<List<NewsArticle>> fetchLatest({bool refresh = false}) async {
    final saved = await _cache.read('farmer_news');
    if (saved != null && !refresh) {
      lastFetchedAt = saved.savedAt;
      fromCache = true;
      return _parse(saved.records);
    }
    if (!refresh) {
      lastFetchedAt = null;
      fromCache = false;
      return [];
    }
    refreshError = null;
    refreshFailure = null;
    try {
      final data = await _gateway.post('news', {});
      final records = data['results'];
      if (records is! List) throw const FormatException();
      final articles = _parse(records);
      if (articles.isEmpty) {
        throw const GatewayException('No farmer news is available right now.');
      }
      saveFailed = !await _cache.write(
        'farmer_news',
        records
            .whereType<Map>()
            .map((r) => Map<String, dynamic>.from(r))
            .toList(),
      );
      lastFetchedAt = saveFailed ? null : DateTime.now();
      fromCache = false;
      return articles;
    } catch (error) {
      refreshError = error.toString();
      refreshFailure = error is GatewayException ? error : null;
      if (saved != null) {
        lastFetchedAt = saved.savedAt;
        fromCache = true;
        return _parse(saved.records);
      }
      rethrow;
    }
  }

  List<NewsArticle> _parse(List<dynamic> records) {
    final articles = <String, NewsArticle>{};
    for (final r in records.whereType<Map>()) {
      String value(String key) => r[key]?.toString().trim() ?? '';
      final title = value('title');
      final url = Uri.tryParse(value('link'));
      if (title.isEmpty ||
          url == null ||
          url.scheme != 'https' ||
          url.host.isEmpty) {
        continue;
      }
      final description = value('description')
          .replaceAll(RegExp(r'<[^>]*>'), ' ');
      final image = Uri.tryParse(value('image_url'));
      articles[title.toLowerCase()] = NewsArticle(
        title: title,
        summary: description.length > 250
            ? '${description.substring(0, 247)}…'
            : description,
        source: value('source_name').isEmpty ? url.host : value('source_name'),
        category: 'Agriculture',
        publishedAt:
            DateTime.tryParse(value('pubDate')) ??
            DateTime.fromMillisecondsSinceEpoch(0),
        url: url.toString(),
        imageUrl: image?.scheme == 'https' ? image.toString() : null,
      );
    }
    return articles.values.take(10).toList()
      ..sort((a, b) => b.publishedAt.compareTo(a.publishedAt));
  }

  void dispose() => _gateway.dispose();
}
