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
import '../../data/services/home_reminder_service.dart';
import '../../data/services/session_service.dart';
import '../auth/qr_access_screen.dart';
import '../calendar/activity_calendar_screen.dart';
import '../events/events_screen.dart';
import '../events/event_foreign_detail_screen.dart';
import '../events/event_owner_detail_screen.dart';
import '../materials/article_detail_screen.dart';
import '../materials/articles_list_screen.dart';
import '../profile/profile_screen.dart';
import '../tests/test_passing_screen.dart';
import '../tests/tests_list_screen.dart';

class GuestHomeScreen extends StatefulWidget {
  const GuestHomeScreen({super.key});

  @override
  State<GuestHomeScreen> createState() => _GuestHomeScreenState();
}

class _GuestHomeScreenState extends State<GuestHomeScreen> with RouteAware {
  bool _routeSubscribed = false;
  final _supabase = Supabase.instance.client;

  bool _isMaterialsLoading = true;
  bool _isTestsLoading = true;
  String? _materialsError;
  String? _testsError;
  bool _hasExtendedAccess = false;
  List<HomeReminder> _reminders = const [];
  List<GuestMaterial> _materials = const [];
  List<GuestTest> _tests = const [];
  Set<String> _readMaterialIds = const {};
  Set<String> _completedTestIds = const {};

  @override
  void initState() {
    super.initState();
    _loadAccessState();
    _loadProgressState();
    _loadGuestContent();
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
      final completedTestIds = await ContentProgressService.instance
          .getCompletedTestIds();

      debugPrint(
        'Home progress load: read=${readMaterialIds.length} '
        'ids=${readMaterialIds.toList()} completed=${completedTestIds.length} '
        'ids=${completedTestIds.toList()}',
      );

      if (!mounted) {
        return;
      }

      setState(() {
        _readMaterialIds = readMaterialIds;
        _completedTestIds = completedTestIds;
      });
    } catch (error, stackTrace) {
      debugPrint('Guest progress load error: $error');
      debugPrintStack(stackTrace: stackTrace);
    }
  }

  Future<void> _loadAccessState() async {
    final hasExtendedAccess = await SessionService().hasExtendedAccess();

    if (!mounted) {
      return;
    }

    setState(() {
      _hasExtendedAccess = hasExtendedAccess;
    });

    if (hasExtendedAccess) {
      await _loadReminders();
    }
  }

  Future<void> _loadGuestContent() async {
    setState(() {
      _isMaterialsLoading = true;
      _isTestsLoading = true;
      _materialsError = null;
      _testsError = null;
    });

    await Future.wait([
      _loadMaterialsSection(),
      _loadTestsSection(),
      if (_hasExtendedAccess) _loadReminders(),
    ]);
  }

  Future<void> _loadReminders() async {
    try {
      final reminders = await HomeReminderService().loadReminders().timeout(
        const Duration(seconds: 10),
      );

      if (!mounted) {
        return;
      }

      setState(() {
        _reminders = reminders;
      });
    } catch (error, stackTrace) {
      debugPrint('Home reminders load error: $error');
      debugPrintStack(stackTrace: stackTrace);

      if (!mounted) {
        return;
      }

      setState(() {
        _reminders = const [];
      });
    }
  }

  Future<void> _loadMaterialsSection() async {
    try {
      final materials = await _loadMaterials().timeout(
        const Duration(seconds: 10),
      );

      if (!mounted) {
        return;
      }

      setState(() {
        _materials = materials;
        _materialsError = null;
        _isMaterialsLoading = false;
      });
    } catch (error, stackTrace) {
      debugPrint('Guest materials load error: $error');
      debugPrintStack(stackTrace: stackTrace);

      if (!mounted) {
        return;
      }

      setState(() {
        _materials = const [];
        _materialsError = 'Не удалось загрузить статьи.';
        _isMaterialsLoading = false;
      });
    }
  }

  Future<void> _loadTestsSection() async {
    try {
      final tests = await _loadTests().timeout(const Duration(seconds: 10));

      if (!mounted) {
        return;
      }

      setState(() {
        _tests = tests;
        _testsError = null;
        _isTestsLoading = false;
      });
    } catch (error, stackTrace) {
      debugPrint('Guest tests load error: $error');
      debugPrintStack(stackTrace: stackTrace);

      if (!mounted) {
        return;
      }

      setState(() {
        _tests = const [];
        _testsError = 'Не удалось загрузить тесты.';
        _isTestsLoading = false;
      });
    }
  }

  Future<List<GuestMaterial>> _loadMaterials() async {
    try {
      final data = await _supabase
          .from('materials')
          .select(
            'material_id, title, category, short_description, reading_time_minutes, image_url, access_level, publication_status',
          )
          .eq('publication_status', 'active')
          .order('published_at', ascending: false);

      debugPrint('Home materials query total rows: ${data.length}');
      for (final row in data) {
        final map = Map<String, dynamic>.from(row);
        debugPrint(
          'Home materials row: title=${map['title']} access_level=${map['access_level']}',
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
          'TODO: Home materials query returned only guest rows. This likely means a Supabase RLS select policy is filtering patient/extended rows.',
        );
      }

      return _mapMaterials(data);
    } catch (error, stackTrace) {
      debugPrint(
        'Guest materials ordered query error, retrying without published_at: $error',
      );
      debugPrintStack(stackTrace: stackTrace);

      final data = await _supabase
          .from('materials')
          .select(
            'material_id, title, category, short_description, reading_time_minutes, image_url, access_level, publication_status',
          )
          .eq('publication_status', 'active');

      debugPrint('Home materials fallback query total rows: ${data.length}');
      for (final row in data) {
        final map = Map<String, dynamic>.from(row);
        debugPrint(
          'Home materials fallback row: title=${map['title']} access_level=${map['access_level']}',
        );
      }

      return _mapMaterials(data);
    }
  }

  Future<List<GuestTest>> _loadTests() async {
    final data = await _supabase
        .from('tests')
        .select(
          'test_id, test_name, test_type, description, access_level, activity_status, estimated_time_minutes, image_url',
        )
        .eq('activity_status', 'active')
        .order('test_name');

    debugPrint('Home tests query total rows: ${data.length}');
    for (final row in data) {
      final map = Map<String, dynamic>.from(row);
      debugPrint(
        'Home tests row: name=${map['test_name']} access_level=${map['access_level']}',
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
        'TODO: Home tests query returned only guest rows. This likely means a Supabase RLS select policy is filtering patient/extended rows.',
      );
    }

    return _mapTests(data);
  }

  List<GuestMaterial> _mapMaterials(List<dynamic> rows) {
    return rows
        .map((row) => GuestMaterial.fromJson(Map<String, dynamic>.from(row)))
        .toList();
  }

  List<GuestTest> _mapTests(List<dynamic> rows) {
    return rows
        .map((row) => GuestTest.fromJson(Map<String, dynamic>.from(row)))
        .toList();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBody: true,
      backgroundColor: AppColors.background,
      bottomNavigationBar: GuestBottomNavigation(
        onItemTap: (index) =>
            _handleBottomNavigationTap(context, index, _hasExtendedAccess),
      ),
      body: _buildBody(context),
    );
  }

  Widget _buildBody(BuildContext context) {
    return RefreshIndicator(
      onRefresh: _loadGuestContent,
      child: ListView(
        padding: const EdgeInsets.only(bottom: 118),
        children: [
          const _TopBanner(),
          const SizedBox(height: 27),
          if (_hasExtendedAccess && _reminders.isNotEmpty) ...[
            _ReminderSection(
              reminders: _reminders,
              onEventTap: _handleReminderTap,
            ),
            const SizedBox(height: 24),
          ],
          _ArticlesSection(
            materials: _materials,
            isLoading: _isMaterialsLoading,
            errorText: _materialsError,
            isExtendedAccess: _hasExtendedAccess,
            readMaterialIds: _readMaterialIds,
            onStatusChanged: _loadProgressState,
          ),
          const SizedBox(height: 24),
          _TestsSection(
            tests: _tests,
            isLoading: _isTestsLoading,
            errorText: _testsError,
            isExtendedAccess: _hasExtendedAccess,
            completedTestIds: _completedTestIds,
            onStatusChanged: _loadProgressState,
          ),
        ],
      ),
    );
  }

  Future<void> _handleReminderTap(HomeReminder reminder) async {
    if (reminder.type != HomeReminderType.event || reminder.eventId == null) {
      debugPrint('Home reminder tap skipped: missing event data');
      return;
    }

    final route = MaterialPageRoute<bool>(
      builder: (context) => reminder.isOwnEvent
          ? EventOwnerDetailScreen(eventId: reminder.eventId!)
          : EventForeignDetailScreen(eventId: reminder.eventId!),
    );

    final result = await Navigator.of(context).push(route);
    if (result == true && mounted) {
      await _loadReminders();
    }
  }
}

void _handleBottomNavigationTap(
  BuildContext context,
  int index,
  bool hasExtendedAccess,
) {
  if (index == 0) {
    return;
  }

  if (!hasExtendedAccess) {
    Navigator.of(context).push(
      noTransitionPageRoute<void>(builder: (context) => const QRAccessScreen()),
    );
    return;
  }

  if (index == 1) {
    Navigator.of(context).push(
      noTransitionPageRoute<void>(builder: (context) => const EventsScreen()),
    );
    return;
  }

  if (index == 2) {
    Navigator.of(context).push(
      noTransitionPageRoute<void>(
        builder: (context) => const ActivityCalendarScreen(),
      ),
    );
    return;
  }

  Navigator.of(context).push(
    noTransitionPageRoute<void>(builder: (context) => const ProfileScreen()),
  );
}

class _TopBanner extends StatelessWidget {
  const _TopBanner();

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: const BorderRadius.vertical(bottom: Radius.circular(19)),
      child: SizedBox(
        height: 231,
        width: double.infinity,
        child: Stack(
          fit: StackFit.expand,
          children: [
            Image.asset('assets/images/home_banner.png', fit: BoxFit.cover),
            DecoratedBox(
              decoration: BoxDecoration(
                color: const Color(0xFF1F1F1F).withValues(alpha: 0.63),
              ),
            ),
            Positioned(
              left: 21,
              right: 24,
              bottom: 22,
              child: Text(
                'Вы уже проделали большой\nпуть, но впереди ещё\nмного интересного',
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                  color: const Color(0xFFE8E8E8),
                  fontSize: 24,
                  height: 1.32,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ReminderSection extends StatelessWidget {
  const _ReminderSection({required this.reminders, required this.onEventTap});

  final List<HomeReminder> reminders;
  final Future<void> Function(HomeReminder reminder) onEventTap;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 22),
      child: Column(
        children: [
          for (var index = 0; index < reminders.length; index++) ...[
            _ReminderCard(
              reminder: reminders[index],
              onTap: reminders[index].type == HomeReminderType.event
                  ? () => onEventTap(reminders[index])
                  : null,
            ),
            if (index < reminders.length - 1) const SizedBox(height: 10),
          ],
        ],
      ),
    );
  }
}

class _ReminderCard extends StatelessWidget {
  const _ReminderCard({required this.reminder, this.onTap});

  final HomeReminder reminder;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final isEvent = reminder.type == HomeReminderType.event;

    final card = DecoratedBox(
      decoration: BoxDecoration(
        color: AppColors.surface.withValues(alpha: 0.92),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: Colors.white.withValues(alpha: 0.72)),
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(17, 14, 13, 14),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    reminder.title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontSize: 16,
                      fontWeight: FontWeight.w500,
                      height: 1.1,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    reminder.subtitle,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: const Color(0xFF777777),
                      fontSize: 12,
                      height: 1.22,
                    ),
                  ),
                ],
              ),
            ),
            if (isEvent) ...[
              const SizedBox(width: 8),
              const Icon(
                Icons.chevron_right,
                color: Color(0xFF777777),
                size: 20,
              ),
            ],
          ],
        ),
      ),
    );

    if (onTap == null) {
      return card;
    }

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(18),
        child: card,
      ),
    );
  }
}

class _ArticlesSection extends StatelessWidget {
  const _ArticlesSection({
    required this.materials,
    required this.isLoading,
    required this.errorText,
    required this.isExtendedAccess,
    required this.readMaterialIds,
    required this.onStatusChanged,
  });

  final List<GuestMaterial> materials;
  final bool isLoading;
  final String? errorText;
  final bool isExtendedAccess;
  final Set<String> readMaterialIds;
  final Future<void> Function() onStatusChanged;

  @override
  Widget build(BuildContext context) {
    return _HomeSection(
      title: 'Статьи',
      onSeeAll: () {
        Navigator.of(context).push(
          MaterialPageRoute<void>(
            builder: (context) =>
                ArticlesListScreen(isExtendedAccess: isExtendedAccess),
          ),
        );
      },
      child: _buildContent(),
    );
  }

  Widget _buildContent() {
    if (isLoading) {
      return const _ArticleSkeletonList();
    }

    if (errorText != null) {
      return _SectionMessage(text: errorText!);
    }

    return materials.isEmpty
        ? const _EmptySectionText(text: 'Пока нет открытых статей.')
        : SizedBox(
            height: 168,
            child: ListView.separated(
              padding: const EdgeInsets.symmetric(horizontal: 22),
              scrollDirection: Axis.horizontal,
              itemCount: materials.length,
              separatorBuilder: (context, index) => const SizedBox(width: 25),
              itemBuilder: (context, index) {
                final material = materials[index];
                final isRead = readMaterialIds.contains(material.id);
                debugPrint(
                  'Home article card: id=${material.id} title=${material.title} '
                  'isRead=$isRead',
                );
                return _ArticleCard(
                  material: material,
                  imageAsset: assetByIndex(materialImageAssets, index),
                  isExtendedAccess: isExtendedAccess,
                  isRead: isRead,
                  onStatusChanged: onStatusChanged,
                );
              },
            ),
          );
  }
}

class _TestsSection extends StatelessWidget {
  const _TestsSection({
    required this.tests,
    required this.isLoading,
    required this.errorText,
    required this.isExtendedAccess,
    required this.completedTestIds,
    required this.onStatusChanged,
  });

  final List<GuestTest> tests;
  final bool isLoading;
  final String? errorText;
  final bool isExtendedAccess;
  final Set<String> completedTestIds;
  final Future<void> Function() onStatusChanged;

  @override
  Widget build(BuildContext context) {
    return _HomeSection(
      title: 'Тесты',
      onSeeAll: () {
        Navigator.of(context).push(
          MaterialPageRoute<void>(
            builder: (context) =>
                TestsListScreen(isExtendedAccess: isExtendedAccess),
          ),
        );
      },
      child: _buildContent(),
    );
  }

  Widget _buildContent() {
    if (isLoading) {
      return const _TestsSkeletonCard();
    }

    if (errorText != null) {
      return _SectionMessage(text: errorText!);
    }

    final guestTests = tests
        .where((test) => test.accessLevel.toLowerCase().trim() == 'guest')
        .toList();

    final visibleTests = guestTests.take(3).toList();

    return visibleTests.isEmpty
        ? const _EmptySectionText(text: 'Пока нет открытых тестов.')
        : Padding(
            padding: const EdgeInsets.symmetric(horizontal: 22),
            child: DecoratedBox(
              decoration: BoxDecoration(
                color: AppColors.surface.withValues(alpha: 0.9),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: Colors.white.withValues(alpha: 0.65)),
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(16),
                child: Column(
                  children: [
                    for (
                      var index = 0;
                      index < visibleTests.length;
                      index++
                    ) ...[
                      Builder(
                        builder: (context) {
                          final test = visibleTests[index];
                          final isCompleted = completedTestIds.contains(
                            test.id,
                          );
                          debugPrint(
                            'Home test card: id=${test.id} name=${test.name} '
                            'isCompleted=$isCompleted',
                          );
                          return _TestRow(
                            test: test,
                            imageAsset: assetByIndex(testImageAssets, index),
                            isExtendedAccess: isExtendedAccess,
                            isCompleted: isCompleted,
                            onStatusChanged: onStatusChanged,
                          );
                        },
                      ),
                      if (index < visibleTests.length - 1)
                        const Divider(
                          height: 1,
                          thickness: 0.8,
                          indent: 70,
                          endIndent: 23,
                          color: Color(0xFFBFBFBF),
                        ),
                    ],
                  ],
                ),
              ),
            ),
          );
  }
}

class _HomeSection extends StatelessWidget {
  const _HomeSection({required this.title, required this.child, this.onSeeAll});

  final String title;
  final Widget child;
  final VoidCallback? onSeeAll;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 33),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                title,
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                  fontSize: 24,
                  fontWeight: FontWeight.w500,
                ),
              ),
              Padding(
                padding: const EdgeInsets.only(bottom: 3),
                child: GestureDetector(
                  onTap: onSeeAll,
                  behavior: HitTestBehavior.opaque,
                  child: Padding(
                    padding: const EdgeInsets.all(4),
                    child: Text(
                      'Смотреть все',
                      style: Theme.of(context).textTheme.labelMedium?.copyWith(
                        color: const Color(0xFF777777),
                        fontSize: 12,
                        fontWeight: FontWeight.w400,
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 8),
        child,
      ],
    );
  }
}

class _ArticleCard extends StatelessWidget {
  const _ArticleCard({
    required this.material,
    required this.imageAsset,
    required this.isExtendedAccess,
    required this.isRead,
    required this.onStatusChanged,
  });

  final GuestMaterial material;
  final String imageAsset;
  final bool isExtendedAccess;
  final bool isRead;
  final Future<void> Function() onStatusChanged;

  @override
  Widget build(BuildContext context) {
    final normalizedAccess = (material.accessLevel).toLowerCase().trim();
    final requiresExtended = normalizedAccess != 'guest';
    final shouldShowLock = !isExtendedAccess && requiresExtended;

    return GestureDetector(
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
              articleId: material.id,
              title: material.title,
              category: material.category,
              summary: material.shortDescription,
              readingTimeMinutes: material.readingTimeMinutes,
              accessLevel: material.accessLevel,
              imageAsset: imageAsset,
            ),
          ),
        );
        if (wasRead == true) {
          await onStatusChanged();
        }
      },
      behavior: HitTestBehavior.opaque,
      child: SizedBox(
        width: 125,
        height: 168,
        child: Stack(
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(18),
              child: Stack(
                fit: StackFit.expand,
                children: [
                  _AssetImageOrPlaceholder(
                    assetPath: imageAsset,
                    placeholder: const _SoftArticlePlaceholder(),
                  ),
                  Align(
                    alignment: Alignment.bottomCenter,
                    child: ClipRect(
                      child: BackdropFilter(
                        filter: ImageFilter.blur(sigmaX: 9, sigmaY: 9),
                        child: Container(
                          width: double.infinity,
                          padding: const EdgeInsets.fromLTRB(12, 10, 10, 11),
                          decoration: BoxDecoration(
                            color: const Color(
                              0xFF2A2A2A,
                            ).withValues(alpha: 0.34),
                          ),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                material.title,
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                                style: Theme.of(context).textTheme.labelMedium
                                    ?.copyWith(
                                      color: Colors.white,
                                      fontSize: 12,
                                      height: 1.08,
                                      fontWeight: FontWeight.w500,
                                    ),
                              ),
                              if (material.readingTimeMinutes != null) ...[
                                const SizedBox(height: 4),
                                Text(
                                  _shortMinutes(material.readingTimeMinutes),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: Theme.of(context).textTheme.labelSmall
                                      ?.copyWith(
                                        color: Colors.white.withValues(
                                          alpha: 0.86,
                                        ),
                                        fontSize: 10,
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
                  if (isRead && !shouldShowLock)
                    const Positioned(
                      right: 9,
                      top: 9,
                      child: ContentStatusBadge(
                        label: 'Прочитано',
                        backgroundColor: AppColors.greenStatus,
                        foregroundColor: Colors.white,
                      ),
                    ),
                ],
              ),
            ),
            if (shouldShowLock)
              const Positioned(top: 9, left: 9, child: AccessLockBadge()),
          ],
        ),
      ),
    );
  }
}

class _TestRow extends StatelessWidget {
  const _TestRow({
    required this.test,
    required this.imageAsset,
    required this.isExtendedAccess,
    required this.isCompleted,
    required this.onStatusChanged,
  });

  final GuestTest test;
  final String imageAsset;
  final bool isExtendedAccess;
  final bool isCompleted;
  final Future<void> Function() onStatusChanged;

  @override
  Widget build(BuildContext context) {
    final normalizedAccess = (test.accessLevel).toLowerCase().trim();
    final requiresExtended = normalizedAccess != 'guest';
    final shouldShowLock = !isExtendedAccess && requiresExtended;

    return GestureDetector(
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
      behavior: HitTestBehavior.opaque,
      child: SizedBox(
        height: 78,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(15, 8, 10, 8),
          child: Row(
            children: [
              Stack(
                clipBehavior: Clip.none,
                children: [
                  SizedBox.square(
                    dimension: 42,
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(7),
                      child: _AssetImageOrPlaceholder(
                        assetPath: imageAsset,
                        placeholder: const _TestThumbnailPlaceholder(),
                      ),
                    ),
                  ),
                  if (shouldShowLock)
                    const Positioned(left: 2, top: 2, child: AccessLockBadge()),
                ],
              ),
              const SizedBox(width: 13),
              Expanded(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Flexible(
                      child: Text(
                        test.name,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          fontSize: 15,
                          height: 1.12,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                    const SizedBox(height: 5),
                    Text(
                      _testDuration(test.estimatedTimeMinutes),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.labelMedium?.copyWith(
                        color: const Color(0xFF777777),
                        fontSize: 12,
                        fontWeight: FontWeight.w400,
                      ),
                    ),
                    if (isCompleted && !shouldShowLock) ...[
                      const SizedBox(height: 6),
                      const Align(
                        alignment: Alignment.centerLeft,
                        child: ContentStatusBadge(
                          label: 'Пройдено',
                          backgroundColor: AppColors.greenStatus,
                          foregroundColor: Colors.white,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(width: 8),
              const Icon(
                Icons.chevron_right,
                color: Color(0xFF777777),
                size: 20,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _AssetImageOrPlaceholder extends StatelessWidget {
  const _AssetImageOrPlaceholder({
    required this.assetPath,
    required this.placeholder,
  });

  final String assetPath;
  final Widget placeholder;

  @override
  Widget build(BuildContext context) {
    return Image.asset(
      assetPath,
      fit: BoxFit.cover,
      errorBuilder: (context, error, stackTrace) => placeholder,
    );
  }
}

class _SoftArticlePlaceholder extends StatelessWidget {
  const _SoftArticlePlaceholder();

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            AppColors.yellowAccent.withValues(alpha: 0.55),
            AppColors.pinkAccent.withValues(alpha: 0.62),
            AppColors.blueAccent.withValues(alpha: 0.56),
          ],
        ),
      ),
      child: const SizedBox.expand(),
    );
  }
}

class _TestThumbnailPlaceholder extends StatelessWidget {
  const _TestThumbnailPlaceholder();

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            AppColors.greyStatus.withValues(alpha: 0.45),
            AppColors.yellowAccent.withValues(alpha: 0.78),
          ],
        ),
      ),
      child: const Center(
        child: Icon(
          Icons.psychology_alt_outlined,
          color: AppColors.textDark,
          size: 20,
        ),
      ),
    );
  }
}

class _ArticleSkeletonList extends StatelessWidget {
  const _ArticleSkeletonList();

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 168,
      child: ListView.separated(
        padding: const EdgeInsets.symmetric(horizontal: 22),
        scrollDirection: Axis.horizontal,
        itemCount: 3,
        separatorBuilder: (context, index) => const SizedBox(width: 25),
        itemBuilder: (context, index) {
          return const SizedBox(
            width: 125,
            height: 168,
            child: ClipRRect(
              borderRadius: BorderRadius.all(Radius.circular(18)),
              child: _SkeletonBlock(),
            ),
          );
        },
      ),
    );
  }
}

class _TestsSkeletonCard extends StatelessWidget {
  const _TestsSkeletonCard();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 22),
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: AppColors.surface.withValues(alpha: 0.9),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.white.withValues(alpha: 0.65)),
        ),
        child: const Column(
          children: [
            _TestSkeletonRow(),
            Divider(
              height: 1,
              thickness: 0.8,
              indent: 70,
              endIndent: 23,
              color: Color(0xFFBFBFBF),
            ),
            _TestSkeletonRow(),
            Divider(
              height: 1,
              thickness: 0.8,
              indent: 70,
              endIndent: 23,
              color: Color(0xFFBFBFBF),
            ),
            _TestSkeletonRow(),
          ],
        ),
      ),
    );
  }
}

class _TestSkeletonRow extends StatelessWidget {
  const _TestSkeletonRow();

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 78,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(15, 14, 24, 13),
        child: Row(
          children: [
            const SizedBox.square(
              dimension: 42,
              child: ClipRRect(
                borderRadius: BorderRadius.all(Radius.circular(7)),
                child: _SkeletonBlock(),
              ),
            ),
            const SizedBox(width: 13),
            Expanded(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: const [
                  SizedBox(
                    width: double.infinity,
                    height: 13,
                    child: _SkeletonBlock(),
                  ),
                  SizedBox(height: 9),
                  SizedBox(width: 150, height: 10, child: _SkeletonBlock()),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SkeletonBlock extends StatelessWidget {
  const _SkeletonBlock();

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.55)),
    );
  }
}

class _SectionMessage extends StatelessWidget {
  const _SectionMessage({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 33, vertical: 8),
      child: Text(
        text,
        style: Theme.of(
          context,
        ).textTheme.bodyMedium?.copyWith(color: const Color(0xFF777777)),
      ),
    );
  }
}

class _EmptySectionText extends StatelessWidget {
  const _EmptySectionText({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 33, vertical: 8),
      child: Text(
        text,
        style: Theme.of(
          context,
        ).textTheme.bodyMedium?.copyWith(color: const Color(0xFF777777)),
      ),
    );
  }
}

class GuestMaterial {
  const GuestMaterial({
    required this.id,
    required this.title,
    required this.category,
    required this.shortDescription,
    required this.readingTimeMinutes,
    required this.accessLevel,
    required this.imageUrl,
  });

  final String id;
  final String title;
  final String category;
  final String shortDescription;
  final int? readingTimeMinutes;
  final String accessLevel;
  final String? imageUrl;

  factory GuestMaterial.fromJson(Map<String, dynamic> json) {
    return GuestMaterial(
      id: _asString(json['material_id']),
      title: _asString(json['title'], fallback: 'Материал'),
      category: _asString(json['category']),
      shortDescription: _asString(json['short_description']),
      readingTimeMinutes: _asInt(json['reading_time_minutes']),
      accessLevel: _asString(json['access_level'], fallback: 'guest'),
      imageUrl: _asNullableString(json['image_url']),
    );
  }
}

class GuestTest {
  const GuestTest({
    required this.id,
    required this.name,
    required this.type,
    required this.description,
    required this.estimatedTimeMinutes,
    required this.accessLevel,
    required this.imageUrl,
  });

  final String id;
  final String name;
  final String type;
  final String description;
  final int? estimatedTimeMinutes;
  final String accessLevel;
  final String? imageUrl;

  factory GuestTest.fromJson(Map<String, dynamic> json) {
    return GuestTest(
      id: _asString(json['test_id']),
      name: _asString(json['test_name'], fallback: 'Тест'),
      type: _asString(json['test_type']),
      description: _asString(json['description']),
      estimatedTimeMinutes: _asInt(json['estimated_time_minutes']),
      accessLevel: _asString(json['access_level'], fallback: 'guest'),
      imageUrl: _asNullableString(json['image_url']),
    );
  }
}

String _shortMinutes(int? minutes) {
  if (minutes == null || minutes <= 0) {
    return '';
  }

  return '$minutes мин';
}

String _testDuration(int? minutes) {
  if (minutes == null || minutes <= 0) {
    return 'несколько минут';
  }

  return '$minutes ${_minuteWord(minutes)}';
}

String _minuteWord(int minutes) {
  final lastTwo = minutes % 100;
  if (lastTwo >= 11 && lastTwo <= 14) {
    return 'минут';
  }

  return switch (minutes % 10) {
    1 => 'минута',
    2 || 3 || 4 => 'минуты',
    _ => 'минут',
  };
}

String _asString(Object? value, {String fallback = ''}) {
  final text = value?.toString().trim();
  if (text == null || text.isEmpty) {
    return fallback;
  }

  return text;
}

String? _asNullableString(Object? value) {
  final text = value?.toString().trim();
  if (text == null || text.isEmpty) {
    return null;
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
