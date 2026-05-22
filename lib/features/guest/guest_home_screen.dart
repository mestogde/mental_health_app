import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../core/assets/app_image_assets.dart';
import '../../core/theme/app_theme.dart';
import '../../core/widgets/guest_bottom_navigation.dart';
import '../../core/utils/access_level.dart';
import '../../data/services/home_reminder_service.dart';
import '../../data/services/session_service.dart';
import '../auth/qr_access_screen.dart';
import '../calendar/activity_calendar_screen.dart';
import '../events/events_screen.dart';
import '../events/event_foreign_detail_screen.dart';
import '../events/event_owner_detail_screen.dart';
import '../materials/articles_list_screen.dart';
import '../profile/profile_screen.dart';
import '../tests/tests_list_screen.dart';

class GuestHomeScreen extends StatefulWidget {
  const GuestHomeScreen({super.key});

  @override
  State<GuestHomeScreen> createState() => _GuestHomeScreenState();
}

class _GuestHomeScreenState extends State<GuestHomeScreen> {
  final _supabase = Supabase.instance.client;

  bool _isMaterialsLoading = true;
  bool _isTestsLoading = true;
  String? _materialsError;
  String? _testsError;
  bool _hasExtendedAccess = false;
  List<HomeReminder> _reminders = const [];
  List<GuestMaterial> _materials = const [];
  List<GuestTest> _tests = const [];

  @override
  void initState() {
    super.initState();
    _loadAccessState();
    _loadGuestContent();
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
          ),
          const SizedBox(height: 24),
          _TestsSection(
            tests: _tests.take(3).toList(),
            isLoading: _isTestsLoading,
            errorText: _testsError,
            isExtendedAccess: _hasExtendedAccess,
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
      MaterialPageRoute<void>(builder: (context) => const QRAccessScreen()),
    );
    return;
  }

  if (index == 1) {
    Navigator.of(
      context,
    ).push(MaterialPageRoute<void>(builder: (context) => const EventsScreen()));
    return;
  }

  if (index == 2) {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (context) => const ActivityCalendarScreen(),
      ),
    );
    return;
  }

  Navigator.of(
    context,
  ).push(MaterialPageRoute<void>(builder: (context) => const ProfileScreen()));
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
  });

  final List<GuestMaterial> materials;
  final bool isLoading;
  final String? errorText;
  final bool isExtendedAccess;

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
                return _ArticleCard(
                  material: materials[index],
                  imageAsset: assetByIndex(materialImageAssets, index),
                  isExtendedAccess: isExtendedAccess,
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
  });

  final List<GuestTest> tests;
  final bool isLoading;
  final String? errorText;
  final bool isExtendedAccess;

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

    return tests.isEmpty
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
                    for (var index = 0; index < tests.length; index++) ...[
                      _TestRow(
                        test: tests[index],
                        imageAsset: assetByIndex(testImageAssets, index),
                        isExtendedAccess: isExtendedAccess,
                      ),
                      if (index < tests.length - 1)
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
  });

  final GuestMaterial material;
  final String imageAsset;
  final bool isExtendedAccess;

  @override
  Widget build(BuildContext context) {
    final shouldShowLock =
        requiresExtendedAccess(material.accessLevel) && !isExtendedAccess;
    debugPrint(
      'Home article card build: title=${material.title}, '
      'access_level=${material.accessLevel}, hasExtendedAccess=$isExtendedAccess, '
      'shouldShowLock=$shouldShowLock',
    );

    return GestureDetector(
      onTap: shouldShowLock
          ? () {
              Navigator.of(context).push(
                MaterialPageRoute<void>(
                  builder: (context) => const QRAccessScreen(),
                ),
              );
            }
          : null,
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
                ],
              ),
            ),
            if (shouldShowLock)
              const Positioned(top: 9, right: 9, child: _LockBadge()),
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
  });

  final GuestTest test;
  final String imageAsset;
  final bool isExtendedAccess;

  @override
  Widget build(BuildContext context) {
    final shouldShowLock =
        requiresExtendedAccess(test.accessLevel) && !isExtendedAccess;
    debugPrint(
      'Home test card build: title=${test.name}, '
      'access_level=${test.accessLevel}, hasExtendedAccess=$isExtendedAccess, '
      'shouldShowLock=$shouldShowLock',
    );

    return GestureDetector(
      onTap: shouldShowLock
          ? () {
              Navigator.of(context).push(
                MaterialPageRoute<void>(
                  builder: (context) => const QRAccessScreen(),
                ),
              );
            }
          : null,
      behavior: HitTestBehavior.opaque,
      child: SizedBox(
        height: 78,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(15, 8, 10, 8),
          child: Row(
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
                  ],
                ),
              ),
              const SizedBox(width: 8),
              if (shouldShowLock) ...[
                const _LockBadge(),
                const SizedBox(width: 8),
              ],
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

class _LockBadge extends StatelessWidget {
  const _LockBadge();

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.78),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: Colors.black.withValues(alpha: 0.08)),
      ),
      child: const Padding(
        padding: EdgeInsets.symmetric(horizontal: 7, vertical: 4),
        child: Icon(Icons.lock_outline, color: Color(0xFF777777), size: 12),
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
