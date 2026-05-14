import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../core/assets/app_image_assets.dart';
import '../../core/theme/app_theme.dart';
import '../../core/widgets/guest_bottom_navigation.dart';

class ArticlesListScreen extends StatefulWidget {
  const ArticlesListScreen({super.key});

  @override
  State<ArticlesListScreen> createState() => _ArticlesListScreenState();
}

class _ArticlesListScreenState extends State<ArticlesListScreen> {
  final _supabase = Supabase.instance.client;

  bool _isLoading = true;
  String? _errorText;
  List<ArticleListItem> _articles = const [];

  @override
  void initState() {
    super.initState();
    _loadArticles();
  }

  Future<void> _loadArticles() async {
    setState(() {
      _isLoading = true;
      _errorText = null;
    });

    try {
      final articles = await _fetchArticles().timeout(
        const Duration(seconds: 10),
      );

      if (!mounted) {
        return;
      }

      setState(() {
        _articles = articles;
        _isLoading = false;
      });
    } catch (error, stackTrace) {
      debugPrint('Articles list load error: $error');
      debugPrintStack(stackTrace: stackTrace);

      if (!mounted) {
        return;
      }

      setState(() {
        _articles = const [];
        _errorText = 'Не удалось загрузить статьи. Попробуйте ещё раз.';
        _isLoading = false;
      });
    }
  }

  Future<List<ArticleListItem>> _fetchArticles() async {
    try {
      final data = await _supabase
          .from('materials')
          .select(
            'material_id, title, category, short_description, reading_time_minutes, access_level, publication_status, published_at',
          )
          .eq('publication_status', 'active')
          .order('published_at', ascending: false);

      return _mapArticles(data);
    } catch (error, stackTrace) {
      debugPrint(
        'Articles ordered query error, retrying without published_at: $error',
      );
      debugPrintStack(stackTrace: stackTrace);

      final data = await _supabase
          .from('materials')
          .select(
            'material_id, title, category, short_description, reading_time_minutes, access_level, publication_status, published_at',
          )
          .eq('publication_status', 'active');

      return _mapArticles(data);
    }
  }

  List<ArticleListItem> _mapArticles(List<dynamic> rows) {
    return rows
        .map((row) => ArticleListItem.fromJson(Map<String, dynamic>.from(row)))
        .toList();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBody: true,
      backgroundColor: AppColors.background,
      bottomNavigationBar: const GuestBottomNavigation(selectedIndex: 1),
      body: SafeArea(
        bottom: false,
        child: RefreshIndicator(
          onRefresh: _loadArticles,
          child: CustomScrollView(
            slivers: [
              const SliverToBoxAdapter(child: _ListHeader(title: 'Статьи')),
              if (_isLoading)
                const SliverFillRemaining(
                  hasScrollBody: false,
                  child: Center(child: CircularProgressIndicator()),
                )
              else if (_errorText != null)
                SliverFillRemaining(
                  hasScrollBody: false,
                  child: _MessageState(text: _errorText!),
                )
              else if (_articles.isEmpty)
                const SliverFillRemaining(
                  hasScrollBody: false,
                  child: _MessageState(text: 'Пока нет активных статей.'),
                )
              else
                SliverPadding(
                  padding: const EdgeInsets.fromLTRB(25, 28, 28, 128),
                  sliver: SliverGrid(
                    delegate: SliverChildBuilderDelegate((context, index) {
                      return _ArticleGridCard(
                        article: _articles[index],
                        imageAsset: assetByIndex(materialImageAssets, index),
                      );
                    }, childCount: _articles.length),
                    gridDelegate:
                        const SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: 2,
                          crossAxisSpacing: 19,
                          mainAxisSpacing: 19,
                          childAspectRatio: 0.75,
                        ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ListHeader extends StatelessWidget {
  const _ListHeader({required this.title});

  final String title;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(14, 8, 24, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          GestureDetector(
            onTap: () => Navigator.of(context).pop(),
            behavior: HitTestBehavior.opaque,
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: Text(
                '← Назад',
                style: Theme.of(context).textTheme.labelLarge?.copyWith(
                  color: const Color(0xFF777777),
                  fontSize: 13,
                  fontWeight: FontWeight.w400,
                ),
              ),
            ),
          ),
          const SizedBox(height: 22),
          Padding(
            padding: const EdgeInsets.only(left: 10),
            child: Text(
              title,
              style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                fontSize: 24,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ArticleGridCard extends StatelessWidget {
  const _ArticleGridCard({required this.article, required this.imageAsset});

  final ArticleListItem article;
  final String imageAsset;

  @override
  Widget build(BuildContext context) {
    return _GridImageCard(
      title: article.title,
      timeText: _minutesText(article.readingTimeMinutes),
      imageAsset: imageAsset,
      isLocked: article.isLocked,
    );
  }
}

class _GridImageCard extends StatelessWidget {
  const _GridImageCard({
    required this.title,
    required this.timeText,
    required this.imageAsset,
    required this.isLocked,
  });

  final String title;
  final String timeText;
  final String imageAsset;
  final bool isLocked;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(18),
      child: Stack(
        fit: StackFit.expand,
        children: [
          Image.asset(
            imageAsset,
            fit: BoxFit.cover,
            errorBuilder: (context, error, stackTrace) {
              return const _SoftImagePlaceholder();
            },
          ),
          if (isLocked) ColoredBox(color: Colors.white.withValues(alpha: 0.22)),
          Positioned(
            left: 10,
            top: 10,
            child: AnimatedOpacity(
              opacity: isLocked ? 1 : 0,
              duration: const Duration(milliseconds: 150),
              child: const _LockChip(),
            ),
          ),
          Align(
            alignment: Alignment.bottomCenter,
            child: ClipRect(
              child: BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 9, sigmaY: 9),
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.fromLTRB(14, 14, 12, 13),
                  decoration: BoxDecoration(
                    color: const Color(0xFF1F1F1F).withValues(alpha: 0.38),
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        maxLines: 3,
                        overflow: TextOverflow.ellipsis,
                        style: Theme.of(context).textTheme.labelLarge?.copyWith(
                          color: Colors.white,
                          fontSize: 13,
                          height: 1.07,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      if (timeText.isNotEmpty) ...[
                        const SizedBox(height: 7),
                        Text(
                          timeText,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: Theme.of(context).textTheme.labelSmall
                              ?.copyWith(
                                color: Colors.white.withValues(alpha: 0.9),
                                fontSize: 11,
                                height: 1,
                              ),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _LockChip extends StatelessWidget {
  const _LockChip();

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: const Color(0xFF777777).withValues(alpha: 0.82),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
        child: Icon(Icons.lock_outline, color: Colors.white, size: 13),
      ),
    );
  }
}

class _SoftImagePlaceholder extends StatelessWidget {
  const _SoftImagePlaceholder();

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            AppColors.greyStatus.withValues(alpha: 0.42),
            AppColors.yellowAccent.withValues(alpha: 0.68),
          ],
        ),
      ),
    );
  }
}

class _MessageState extends StatelessWidget {
  const _MessageState({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Text(
          text,
          textAlign: TextAlign.center,
          style: Theme.of(context).textTheme.bodyLarge?.copyWith(
            color: const Color(0xFF777777),
            height: 1.35,
          ),
        ),
      ),
    );
  }
}

class ArticleListItem {
  const ArticleListItem({
    required this.id,
    required this.title,
    required this.category,
    required this.shortDescription,
    required this.readingTimeMinutes,
    required this.accessLevel,
  });

  final String id;
  final String title;
  final String category;
  final String shortDescription;
  final int? readingTimeMinutes;
  final String accessLevel;

  bool get isLocked => accessLevel != 'guest';

  factory ArticleListItem.fromJson(Map<String, dynamic> json) {
    return ArticleListItem(
      id: _asString(json['material_id']),
      title: _asString(json['title'], fallback: 'Материал'),
      category: _asString(json['category']),
      shortDescription: _asString(json['short_description']),
      readingTimeMinutes: _asInt(json['reading_time_minutes']),
      accessLevel: _asString(json['access_level'], fallback: 'patient'),
    );
  }
}

String _minutesText(int? minutes) {
  if (minutes == null || minutes <= 0) {
    return '';
  }

  return '$minutes мин';
}

String _asString(Object? value, {String fallback = ''}) {
  final text = value?.toString().trim();
  if (text == null || text.isEmpty) {
    return fallback;
  }

  return text;
}

int? _asInt(Object? value) {
  if (value == null) {
    return null;
  }

  if (value is int) {
    return value;
  }

  return int.tryParse(value.toString());
}
