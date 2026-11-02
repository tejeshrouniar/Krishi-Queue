import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../core/theme/app_theme.dart';
import '../../../core/settings/app_preferences.dart';
import '../data/farmer_news_api.dart';
import '../domain/news_article.dart';

class NewsScreen extends StatefulWidget {
  final FarmerNewsApi api;

  const NewsScreen({super.key, required this.api});

  @override
  State<NewsScreen> createState() => _NewsScreenState();
}

class _NewsScreenState extends State<NewsScreen> {
  List<NewsArticle> _articles = const [];
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadNews(refresh: false);
  }

  Future<void> _loadNews({bool refresh = true}) async {
    if (_loading && refresh) return;
    if (!_loading) {
      setState(() {
        _loading = true;
        _error = null;
      });
    }

    try {
      final articles = await widget.api.fetchLatest(refresh: refresh);

      if (!mounted) return;

      setState(() {
        _articles = articles;
        _loading = false;
        _error = null;
      });
    } catch (_) {
      if (!mounted) return;

      setState(() {
        _loading = false;
        _error = 'Could not load farmer news right now.';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return RefreshIndicator(
      onRefresh: _loadNews,
      color: AppTheme.primaryGreen,
      child: CustomScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        slivers: [
          SliverToBoxAdapter(child: _buildHeader()),
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 12),
              child: Text(
                _cacheStatus(),
                style: const TextStyle(color: AppTheme.textSecondary),
              ),
            ),
          ),
          if (_loading && _articles.isEmpty)
            const SliverFillRemaining(
              hasScrollBody: false,
              child: Center(child: CircularProgressIndicator()),
            )
          else if (_error != null && _articles.isEmpty)
            SliverFillRemaining(hasScrollBody: false, child: _buildError())
          else if (_articles.isEmpty)
            SliverFillRemaining(hasScrollBody: false, child: _buildEmpty())
          else
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(16, 4, 16, 28),
              sliver: SliverList.separated(
                itemCount: _articles.length,
                separatorBuilder: (_, _) => const SizedBox(height: 14),
                itemBuilder: (_, index) => _NewsCard(article: _articles[index]),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildHeader() {
    final p = AppPreferences.of(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 18),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  p.text('Farmer news', 'किसान समाचार'),
                  style: const TextStyle(
                    fontSize: 26,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  p.text(
                    'Refresh only when you need new reports',
                    'नई रिपोर्ट चाहिए तभी रिफ्रेश करें',
                  ),
                  style: const TextStyle(
                    color: AppTheme.textSecondary,
                    fontSize: 13,
                  ),
                ),
              ],
            ),
          ),
          IconButton(
            onPressed: _loading ? null : _loadNews,
            tooltip: p.text('Refresh news', 'समाचार अपडेट करें'),
            icon: const Icon(Icons.refresh_rounded),
          ),
        ],
      ),
    );
  }

  Widget _buildError() {
    final p = AppPreferences.of(context);
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(30),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.cloud_off_rounded, size: 46),
            const SizedBox(height: 14),
            Text(
              widget.api.refreshFailure?.localizedMessage(hindi: p.hindi) ??
                  p.text(
                    'News is unavailable. Sign in and try again when connected.',
                    'समाचार उपलब्ध नहीं हैं। साइन-इन करके इंटरनेट मिलने पर फिर कोशिश करें।',
                  ),
              textAlign: TextAlign.center,
              style: const TextStyle(fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 14),
            FilledButton.icon(
              onPressed: _loadNews,
              icon: const Icon(Icons.refresh_rounded),
              label: Text(p.text('Try again', 'फिर कोशिश करें')),
            ),
          ],
        ),
      ),
    );
  }

  String _cacheStatus() {
    final p = AppPreferences.of(context);
    final failure = widget.api.refreshFailure;
    final date = widget.api.lastFetchedAt;
    if (widget.api.saveFailed) {
      return p.text(
        'These reports could not be saved on this phone. They may be unavailable after closing the app.',
        'ये रिपोर्ट इस फोन पर सहेजी नहीं जा सकीं। ऐप बंद करने के बाद उपलब्ध न हों।',
      );
    }
    if (date == null) {
      if (failure != null) return failure.localizedMessage(hindi: p.hindi);
      return p.text(
        'No saved news yet. Tap refresh when connected. Articles open outside this app and use mobile data.',
        'अभी समाचार सहेजे नहीं गए। इंटरनेट मिलने पर रिफ्रेश करें। पूरी खबर ऐप के बाहर खुलेगी और डेटा लगेगा।',
      );
    }
    final saved = p.text(
      'Saved ${date.day}/${date.month}/${date.year}. Reports may be old; check the publication date.',
      '${date.day}/${date.month}/${date.year} को सहेजा। रिपोर्ट पुरानी हो सकती है; प्रकाशन तारीख देखें।',
    );
    if (failure != null) {
      return '${failure.localizedMessage(hindi: p.hindi)}\n$saved';
    }
    return widget.api.refreshError == null
        ? saved
        : '${p.text('Could not update. ', 'अपडेट नहीं हुआ। ')}$saved';
  }

  Widget _buildEmpty() {
    final p = AppPreferences.of(context);
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(30),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.newspaper_rounded, size: 46),
            const SizedBox(height: 14),
            Text(
              p.text('No news saved yet', 'अभी समाचार सहेजे नहीं गए'),
              textAlign: TextAlign.center,
              style: const TextStyle(fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 6),
            Text(
              p.text(
                'Use refresh when connected and signed in. Offline help is always available.',
                'साइन-इन और इंटरनेट मिलने पर रिफ्रेश करें। ऑफलाइन मदद हमेशा उपलब्ध है।',
              ),
              textAlign: TextAlign.center,
              style: const TextStyle(color: AppTheme.textSecondary),
            ),
          ],
        ),
      ),
    );
  }
}

class _NewsCard extends StatelessWidget {
  final NewsArticle article;

  const _NewsCard({required this.article});

  Future<void> _openArticle(BuildContext context) async {
    final uri = Uri.tryParse(article.url);
    if (uri == null || uri.scheme != 'https') {
      return;
    }
    try {
      if (await launchUrl(uri, mode: LaunchMode.externalApplication)) return;
    } catch (_) {
      // Keep the saved summary when no browser can open the publisher link.
    }
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          AppPreferences.of(context).text(
            'Could not open the article. Try again when connected.',
            'खबर नहीं खुल सकी। इंटरनेट मिलने पर फिर कोशिश करें।',
          ),
        ),
      ),
    );
  }

  String _timeAgo(AppPreferences p) {
    if (article.publishedAt.millisecondsSinceEpoch == 0) {
      return p.text('Date unavailable', 'तारीख उपलब्ध नहीं');
    }

    final difference = DateTime.now().difference(article.publishedAt);
    if (difference.isNegative) {
      return p.text('Check publication date', 'प्रकाशन तारीख जाँचें');
    }
    if (difference.inMinutes < 1) return p.text('Just now', 'अभी');
    if (difference.inMinutes < 60) {
      return p.text(
        '${difference.inMinutes}m ago',
        '${difference.inMinutes} मिनट पहले',
      );
    }
    if (difference.inHours < 24) {
      return p.text(
        '${difference.inHours}h ago',
        '${difference.inHours} घंटे पहले',
      );
    }
    if (difference.inDays < 7) {
      return p.text(
        '${difference.inDays}d ago',
        '${difference.inDays} दिन पहले',
      );
    }
    return '${article.publishedAt.day}/${article.publishedAt.month}/${article.publishedAt.year}';
  }

  @override
  Widget build(BuildContext context) {
    final p = AppPreferences.of(context);
    return Card(
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () => _openArticle(context),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 15, 16, 12),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 9,
                      vertical: 5,
                    ),
                    decoration: BoxDecoration(
                      color: const Color(0xFFE8F5E9),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      p.text('Agriculture', 'कृषि'),
                      style: const TextStyle(
                        color: AppTheme.darkGreen,
                        fontSize: 12,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ),
                  const Spacer(),
                  Flexible(
                    child: Text(
                      '${article.source} • ${_timeAgo(p)}',
                      overflow: TextOverflow.ellipsis,
                      textAlign: TextAlign.right,
                      style: const TextStyle(
                        color: AppTheme.textSecondary,
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 14),
              child: Text(
                article.title,
                maxLines: 3,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontSize: 18,
                  height: 1.25,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ),
            if (!AppPreferences.of(context).lowData && article.imageUrl != null)
              AspectRatio(
                aspectRatio: 16 / 9,
                child: Image.network(
                  article.imageUrl!,
                  fit: BoxFit.cover,
                  errorBuilder: (_, _, _) => const _ImageFallback(),
                  loadingBuilder: (context, child, progress) {
                    if (progress == null) return child;
                    return const _ImageFallback(showLoading: true);
                  },
                ),
              ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 14, 16, 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    article.summary,
                    maxLines: 3,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: AppTheme.textSecondary,
                      fontSize: 15,
                      height: 1.45,
                    ),
                  ),
                  const SizedBox(height: 13),
                  Wrap(
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [
                      Text(
                        p.text(
                          'Read full article · uses data',
                          'पूरी खबर पढ़ें · डेटा लगेगा',
                        ),
                        style: const TextStyle(
                          color: AppTheme.primaryGreen,
                          fontWeight: FontWeight.w900,
                          fontSize: 13,
                        ),
                      ),
                      const SizedBox(width: 5),
                      const Icon(
                        Icons.arrow_forward_rounded,
                        color: AppTheme.primaryGreen,
                        size: 18,
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ImageFallback extends StatelessWidget {
  final bool showLoading;

  const _ImageFallback({this.showLoading = false});

  @override
  Widget build(BuildContext context) {
    return Container(
      color: const Color(0xFFE8F5E9),
      child: Center(
        child: showLoading
            ? const CircularProgressIndicator(strokeWidth: 2)
            : const Icon(
                Icons.agriculture_rounded,
                size: 48,
                color: AppTheme.primaryGreen,
              ),
      ),
    );
  }
}
