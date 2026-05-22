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
import '../../data/services/session_service.dart';
import '../auth/qr_access_screen.dart';
import '../calendar/activity_calendar_screen.dart';
import '../guest/guest_home_screen.dart';
import '../events/events_screen.dart';
import 'test_passing_screen.dart';
import '../profile/profile_screen.dart';

class TestsListScreen extends StatefulWidget {
  const TestsListScreen({super.key, this.isExtendedAccess = false});

  final bool isExtendedAccess;

  @override
  State<TestsListScreen> createState() => _TestsListScreenState();
}

class _TestsListScreenState extends State<TestsListScreen> with RouteAware {
  bool _routeSubscribed = false;
  final _supabase = Supabase.instance.client;

  bool _isLoading = true;
  late bool _isExtendedAccess;
  String? _errorText;
  List<TestListItem> _tests = const [];
  Set<String> _completedTestIds = const {};

  @override
  void initState() {
    super.initState();
    _isExtendedAccess = widget.isExtendedAccess;
    _loadAccessState();
    _loadProgressState();
    _loadTests();
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
      final completedTestIds = await ContentProgressService.instance
          .getCompletedTestIds();

      debugPrint(
        'Tests progress load: completed=${completedTestIds.length} '
        'ids=${completedTestIds.toList()}',
      );

      if (!mounted) {
        return;
      }

      setState(() {
        _completedTestIds = completedTestIds;
      });
    } catch (error, stackTrace) {
      debugPrint('Tests progress load error: $error');
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

  Future<void> _loadTests() async {
    setState(() {
      _isLoading = true;
      _errorText = null;
    });

    try {
      final tests = await _fetchTests().timeout(const Duration(seconds: 10));

      if (!mounted) {
        return;
      }

      setState(() {
        _tests = tests;
        _isLoading = false;
      });
    } catch (error, stackTrace) {
      debugPrint('Tests list load error: $error');
      debugPrintStack(stackTrace: stackTrace);

      if (!mounted) {
        return;
      }

      setState(() {
        _tests = const [];
        _errorText = 'Не удалось загрузить тесты. Попробуйте ещё раз.';
        _isLoading = false;
      });
    }
  }

  Future<List<TestListItem>> _fetchTests() async {
    try {
      final data = await _supabase
          .from('tests')
          .select(
            'test_id, test_name, test_type, description, access_level, activity_status, estimated_time_minutes',
          )
          .eq('activity_status', 'active')
          .order('test_name');

      debugPrint('Tests query total rows: ${data.length}');
      for (final row in data) {
        final map = Map<String, dynamic>.from(row);
        debugPrint(
          'Tests row: name=${map['test_name']} access_level=${map['access_level']}',
        );
      }
      if (data.isNotEmpty &&
          data.every((row) {
            final access = Map<String, dynamic>.from(
              row,
            )['access_level']?.toString().toLowerCase().trim();
            return access == 'guest';
          })) {
        debugPrint(
          'TODO: Tests query returned only guest rows. This likely means a Supabase RLS select policy is filtering patient/extended rows.',
        );
      }

      return _mapTests(data);
    } catch (error, stackTrace) {
      debugPrint('Tests ordered query error, retrying without order: $error');
      debugPrintStack(stackTrace: stackTrace);

      final data = await _supabase
          .from('tests')
          .select(
            'test_id, test_name, test_type, description, access_level, activity_status, estimated_time_minutes',
          )
          .eq('activity_status', 'active');

      debugPrint('Tests fallback query total rows: ${data.length}');
      for (final row in data) {
        final map = Map<String, dynamic>.from(row);
        debugPrint(
          'Tests fallback row: name=${map['test_name']} access_level=${map['access_level']}',
        );
      }

      return _mapTests(data);
    }
  }

  List<TestListItem> _mapTests(List<dynamic> rows) {
    return rows
        .map((row) => TestListItem.fromJson(Map<String, dynamic>.from(row)))
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
          onRefresh: _loadTests,
          child: CustomScrollView(
            slivers: [
              const SliverToBoxAdapter(child: _ListHeader(title: 'Тесты')),
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
              else if (_tests.isEmpty)
                const SliverFillRemaining(
                  hasScrollBody: false,
                  child: _MessageState(text: 'Пока нет активных тестов.'),
                )
              else
                SliverPadding(
                  padding: const EdgeInsets.fromLTRB(25, 28, 28, 128),
                  sliver: SliverGrid(
                    delegate: SliverChildBuilderDelegate((context, index) {
                      final test = _tests[index];
                      final isCompleted = _completedTestIds.contains(test.id);
                      debugPrint(
                        'Tests list card: id=${test.id} name=${test.name} '
                        'isCompleted=$isCompleted',
                      );
                      return _TestGridCard(
                        test: test,
                        imageAsset: assetByIndex(testImageAssets, index),
                        isExtendedAccess: _isExtendedAccess,
                        isCompleted: isCompleted,
                        onStatusChanged: _loadProgressState,
                      );
                    }, childCount: _tests.length),
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

class _TestGridCard extends StatelessWidget {
  const _TestGridCard({
    required this.test,
    required this.imageAsset,
    required this.isExtendedAccess,
    required this.isCompleted,
    required this.onStatusChanged,
  });

  final TestListItem test;
  final String imageAsset;
  final bool isExtendedAccess;
  final bool isCompleted;
  final Future<void> Function() onStatusChanged;

  @override
  Widget build(BuildContext context) {
    final normalizedAccess = test.accessLevel.toLowerCase().trim();
    final requiresExtended = normalizedAccess != 'guest';
    final shouldShowLock = !isExtendedAccess && requiresExtended;

    return _GridImageCard(
      title: test.name,
      timeText: _minutesText(test.estimatedTimeMinutes),
      imageAsset: imageAsset,
      isLocked: shouldShowLock,
      isCompleted: isCompleted,
      onTap: () async {
        if (shouldShowLock) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text(
                'Этот тест доступен только в полной версии приложения',
              ),
            ),
          );
          return;
        }

        final wasCompleted = await Navigator.of(context).push<bool>(
          MaterialPageRoute<bool>(
            builder: (context) => TestPassingScreen(
              testId: test.id,
              title: test.name,
              description: test.description,
              imageAsset: imageAsset,
            ),
          ),
        );
        if (wasCompleted == true) {
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
    required this.isCompleted,
    required this.onTap,
  });

  final String title;
  final String timeText;
  final String imageAsset;
  final bool isLocked;
  final bool isCompleted;
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
            if (isCompleted && !isLocked)
              const Positioned(
                right: 10,
                top: 10,
                child: ContentStatusBadge(
                  label: 'Пройдено',
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

class TestListItem {
  const TestListItem({
    required this.id,
    required this.name,
    required this.type,
    required this.description,
    required this.accessLevel,
    required this.estimatedTimeMinutes,
  });

  final String id;
  final String name;
  final String type;
  final String description;
  final String accessLevel;
  final int? estimatedTimeMinutes;

  bool isLocked(bool isExtendedAccess) {
    return accessLevel.toLowerCase().trim() != 'guest' && !isExtendedAccess;
  }

  factory TestListItem.fromJson(Map<String, dynamic> json) {
    return TestListItem(
      id: _asString(json['test_id']),
      name: _asString(json['test_name'], fallback: 'Тест'),
      type: _asString(json['test_type']),
      description: _asString(json['description']),
      accessLevel: _asString(json['access_level'], fallback: 'guest'),
      estimatedTimeMinutes: _asInt(json['estimated_time_minutes']),
    );
  }
}

String _minutesText(int? minutes) {
  if (minutes == null || minutes <= 0) {
    return 'несколько минут';
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
