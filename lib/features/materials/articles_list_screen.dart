import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../core/assets/app_image_assets.dart';
import '../../core/navigation/app_route_observer.dart';
import '../../core/navigation/no_transition_page_route.dart';
import '../../core/widgets/access_lock_badge.dart';
import '../../core/widgets/content_status_badge.dart';
import '../../core/theme/app_theme.dart';
import '../../core/widgets/guest_bottom_navigation.dart';
import '../../data/services/content_progress_service.dart';
import '../../data/services/reference_data_service.dart';
import '../../data/services/session_service.dart';
import '../auth/qr_access_screen.dart';
import '../calendar/activity_calendar_screen.dart';
import '../events/events_screen.dart';
import '../guest/guest_home_screen.dart';
import 'article_detail_screen.dart';
import '../profile/profile_screen.dart';

class ArticlesListScreen extends StatefulWidget {
  const ArticlesListScreen({super.key, this.isExtendedAccess = false});

  final bool isExtendedAccess;

  @override
  State<ArticlesListScreen> createState() => _ArticlesListScreenState();
}

class _ArticlesListScreenState extends State<ArticlesListScreen>
    with RouteAware {
  bool _routeSubscribed = false;
  final _supabase = Supabase.instance.client;

  bool _isLoading = true;
  late bool _isExtendedAccess;
  String? _errorText;
  List<ArticleListItem> _articles = const [];
  Set<String> _readMaterialIds = const {};

  @override
  void initState() {
    super.initState();
    _isExtendedAccess = widget.isExtendedAccess;
    _loadAccessState();
    _loadProgressState();
    _loadArticles();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_routeSubscribed) {
      final route = ModalRoute.of(context);
      if (route is PageRoute<dynamic>) {
        appRouteObserver.subscribe(this, route);
        _routeSubscribed = true;
      }
    }
  }

  @override
  void didPopNext() {
    _loadProgressState();
  }

  @override
  void dispose() {
    if (_routeSubscribed) {
      appRouteObserver.unsubscribe(this);
    }
    super.dispose();
  }

  Future<void> _loadProgressState() async {
    try {
      final readMaterialIds = await ContentProgressService.instance
          .getReadMaterialIds();

      debugPrint(
        'Articles progress load: read=${readMaterialIds.length} '
        'ids=${readMaterialIds.toList()}',
      );

      if (!mounted) {
        return;
      }

      setState(() {
        _readMaterialIds = readMaterialIds;
      });
    } catch (error, stackTrace) {
      debugPrint('Articles progress load error: $error');
      debugPrintStack(stackTrace: stackTrace);
    }
  }

  Future<void> _loadAccessState() async {
    final hasExtendedAccess = await SessionService().hasExtendedAccess();

    if (!mounted) {
      return;
    }

    setState(() {
      _isExtendedAccess = widget.isExtendedAccess || hasExtendedAccess;
    });
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
          .select(materialsSelectFields)
          .order('published_at', ascending: false);

      debugPrint('Articles query total rows: ${data.length}');
      for (final row in data) {
        final map = Map<String, dynamic>.from(row);
        debugPrint(
          'Articles row: title=${map['title']} '
          'access_level=${referenceSystemValue(map, relationKey: 'access_levels', fallback: 'guest')}',
        );
      }
      if (data.isNotEmpty &&
          data.every((row) {
            final access = referenceSystemValue(
              Map<String, dynamic>.from(row),
              relationKey: 'access_levels',
              fallback: 'guest',
            );
            return isGuestAccessLevel(access);
          })) {
        debugPrint(
          'TODO: Articles query returned only guest rows. This likely means a Supabase RLS select policy is filtering patient/extended rows.',
        );
      }

      return _mapArticles(data);
    } catch (error, stackTrace) {
      debugPrint(
        'Articles ordered query error, retrying without published_at: $error',
      );
      debugPrintStack(stackTrace: stackTrace);

      final data = await _supabase
          .from('materials')
          .select(materialsSelectFields);

      debugPrint('Articles fallback query total rows: ${data.length}');
      for (final row in data) {
        final map = Map<String, dynamic>.from(row);
        debugPrint(
          'Articles fallback row: title=${map['title']} '
          'access_level=${referenceSystemValue(map, relationKey: 'access_levels', fallback: 'guest')}',
        );
      }

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
      bottomNavigationBar: GuestBottomNavigation(
        selectedIndex: -1,
        onItemTap: (index) =>
            _handleBottomNavigationTap(context, index, _isExtendedAccess),
      ),
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
                  child: Center(
                    child: CircularProgressIndicator(
                      color: AppColors.pinkAccent,
                    ),
                  ),
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
                      final article = _articles[index];
                      final isRead = _readMaterialIds.contains(article.id);
                      debugPrint(
                        'Article list card: id=${article.id} title=${article.title} '
                        'isRead=$isRead',
                      );
                      return _ArticleGridCard(
                        article: article,
                        imageAsset: assetByIndex(materialImageAssets, index),
                        isExtendedAccess: _isExtendedAccess,
                        isRead: isRead,
                        onStatusChanged: _loadProgressState,
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
  const _ArticleGridCard({
    required this.article,
    required this.imageAsset,
    required this.isExtendedAccess,
    required this.isRead,
    required this.onStatusChanged,
  });

  final ArticleListItem article;
  final String imageAsset;
  final bool isExtendedAccess;
  final bool isRead;
  final Future<void> Function() onStatusChanged;

  @override
  Widget build(BuildContext context) {
    final normalizedAccess = article.accessLevel.toLowerCase().trim();
    final requiresExtended = normalizedAccess != 'guest';
    final shouldShowLock = !isExtendedAccess && requiresExtended;

    return _GridImageCard(
      title: article.title,
      timeText: _minutesText(article.readingTimeMinutes),
      imageAsset: imageAsset,
      isLocked: shouldShowLock,
      isRead: isRead,
      onTap: () async {
        if (shouldShowLock) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text(
                'Этот материал доступен только в полной версии приложения',
              ),
            ),
          );
          return;
        }

        final wasRead = await Navigator.of(context).push<bool>(
          MaterialPageRoute<bool>(
            builder: (context) => ArticleDetailScreen(
              articleId: article.id,
              title: article.title,
              category: article.category,
              summary: article.shortDescription,
              readingTimeMinutes: article.readingTimeMinutes,
              accessLevel: article.accessLevel,
              imageAsset: imageAsset,
            ),
          ),
        );
        if (wasRead == true) {
          await onStatusChanged();
        }
      },
    );
  }
}

class _GridImageCard extends StatelessWidget {
  const _GridImageCard({
    required this.title,
    required this.timeText,
    required this.imageAsset,
    required this.isLocked,
    required this.isRead,
    required this.onTap,
  });

  final String title;
  final String timeText;
  final String imageAsset;
  final bool isLocked;
  final bool isRead;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: ClipRRect(
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
            if (isLocked)
              const Positioned(left: 10, top: 10, child: AccessLockBadge()),
            if (isRead && !isLocked)
              const Positioned(
                right: 10,
                top: 10,
                child: ContentStatusBadge(
                  label: 'Прочитано',
                  backgroundColor: AppColors.greenStatus,
                  foregroundColor: Colors.white,
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
                          style: Theme.of(context).textTheme.labelLarge
                              ?.copyWith(
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
      ),
    );
  }
}

void _handleBottomNavigationTap(
  BuildContext context,
  int index,
  bool isExtendedAccess,
) {
  if (index == 0) {
    Navigator.of(context).pushAndRemoveUntil(
      noTransitionPageRoute<void>(
        builder: (context) => const GuestHomeScreen(),
      ),
      (route) => false,
    );
    return;
  }

  if (!isExtendedAccess) {
    Navigator.of(context).push(
      noTransitionPageRoute<void>(builder: (context) => const QRAccessScreen()),
    );
    return;
  }

  if (index == 1) {
    Navigator.of(context).pushReplacement(
      noTransitionPageRoute<void>(builder: (context) => const EventsScreen()),
    );
    return;
  }

  if (index == 2) {
    Navigator.of(context).pushReplacement(
      noTransitionPageRoute<void>(
        builder: (context) => const ActivityCalendarScreen(),
      ),
    );
    return;
  }

  Navigator.of(context).pushReplacement(
    noTransitionPageRoute<void>(builder: (context) => const ProfileScreen()),
  );
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

  bool isLocked(bool isExtendedAccess) {
    return !isGuestAccessLevel(accessLevel) && !isExtendedAccess;
  }

  factory ArticleListItem.fromJson(Map<String, dynamic> json) {
    return ArticleListItem(
      id: _asString(json['material_id']),
      title: _asString(json['title'], fallback: 'Материал'),
      category: _asString(json['category']),
      shortDescription: _asString(json['short_description']),
      readingTimeMinutes: _asInt(json['reading_time_minutes']),
      accessLevel: normalizeAccessLevel(
        referenceSystemValue(
          json,
          relationKey: 'access_levels',
          fallback: 'guest',
        ),
      ),
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
