import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../core/theme/app_theme.dart';

const List<String> _materialImageAssets = [
  'assets/images/materials/material_1.png',
  'assets/images/materials/material_2.png',
  'assets/images/materials/material_3.png',
  'assets/images/materials/material_4.png',
  'assets/images/materials/material_5.png',
  'assets/images/materials/material_6.png',
];

const List<String> _testImageAssets = [
  'assets/images/tests/test_1.png',
  'assets/images/tests/test_2.png',
  'assets/images/tests/test_3.png',
  'assets/images/tests/test_4.png',
  'assets/images/tests/test_5.png',
  'assets/images/tests/test_6.png',
  'assets/images/tests/test_7.png',
  'assets/images/tests/test_8.png',
  'assets/images/tests/test_9.png',
];

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
  List<GuestMaterial> _materials = const [];
  List<GuestTest> _tests = const [];

  @override
  void initState() {
    super.initState();
    _loadGuestContent();
  }

  Future<void> _loadGuestContent() async {
    setState(() {
      _isMaterialsLoading = true;
      _isTestsLoading = true;
      _materialsError = null;
      _testsError = null;
    });

    await Future.wait([_loadMaterialsSection(), _loadTestsSection()]);
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
          .eq('access_level', 'guest')
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
          .eq('access_level', 'guest')
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
        .eq('access_level', 'guest')
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
      bottomNavigationBar: const _GuestBottomNavigation(),
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
          _ArticlesSection(
            materials: _materials,
            isLoading: _isMaterialsLoading,
            errorText: _materialsError,
          ),
          const SizedBox(height: 24),
          _TestsSection(
            tests: _tests.take(3).toList(),
            isLoading: _isTestsLoading,
            errorText: _testsError,
          ),
        ],
      ),
    );
  }
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

class _ArticlesSection extends StatelessWidget {
  const _ArticlesSection({
    required this.materials,
    required this.isLoading,
    required this.errorText,
  });

  final List<GuestMaterial> materials;
  final bool isLoading;
  final String? errorText;

  @override
  Widget build(BuildContext context) {
    return _HomeSection(title: 'Статьи', child: _buildContent());
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
                  imageAsset: _assetByIndex(_materialImageAssets, index),
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
  });

  final List<GuestTest> tests;
  final bool isLoading;
  final String? errorText;

  @override
  Widget build(BuildContext context) {
    return _HomeSection(title: 'Тесты', child: _buildContent());
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
                        imageAsset: _assetByIndex(_testImageAssets, index),
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
  const _HomeSection({required this.title, required this.child});

  final String title;
  final Widget child;

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
                child: Text(
                  'Смотреть все',
                  style: Theme.of(context).textTheme.labelMedium?.copyWith(
                    color: const Color(0xFF777777),
                    fontSize: 12,
                    fontWeight: FontWeight.w400,
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
  const _ArticleCard({required this.material, required this.imageAsset});

  final GuestMaterial material;
  final String imageAsset;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 125,
      height: 168,
      child: ClipRRect(
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
                      color: const Color(0xFF2A2A2A).withValues(alpha: 0.34),
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
                                fontWeight: FontWeight.w600,
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
                                  color: Colors.white.withValues(alpha: 0.86),
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
    );
  }
}

class _TestRow extends StatelessWidget {
  const _TestRow({required this.test, required this.imageAsset});

  final GuestTest test;
  final String imageAsset;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
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
            const Icon(Icons.chevron_right, color: Color(0xFF777777), size: 20),
          ],
        ),
      ),
    );
  }
}

class _GuestBottomNavigation extends StatelessWidget {
  const _GuestBottomNavigation();

  @override
  Widget build(BuildContext context) {
    final bottomPadding = MediaQuery.paddingOf(context).bottom;

    return Padding(
      padding: EdgeInsets.fromLTRB(22, 0, 22, bottomPadding + 40),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 16, sigmaY: 16),
          child: DecoratedBox(
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.72),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: Colors.white.withValues(alpha: 0.7)),
            ),
            child: SizedBox(
              height: 49,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: const [
                  _BottomNavItem(icon: Icons.home_outlined, isSelected: true),
                  _BottomNavItem(icon: Icons.layers_outlined),
                  _BottomNavItem(icon: Icons.add),
                  _BottomNavItem(icon: Icons.person_outline),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _BottomNavItem extends StatelessWidget {
  const _BottomNavItem({required this.icon, this.isSelected = false});

  final IconData icon;
  final bool isSelected;

  @override
  Widget build(BuildContext context) {
    final iconColor = isSelected ? Colors.white : AppColors.textDark;

    return SizedBox(
      width: 49,
      child: Center(
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          width: isSelected ? 46 : 34,
          height: isSelected ? 30 : 34,
          decoration: BoxDecoration(
            color: isSelected ? AppColors.textDark : Colors.transparent,
            borderRadius: BorderRadius.circular(18),
          ),
          child: Icon(icon, size: 21, color: iconColor),
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
    required this.imageUrl,
  });

  final String id;
  final String title;
  final String category;
  final String shortDescription;
  final int? readingTimeMinutes;
  final String? imageUrl;

  factory GuestMaterial.fromJson(Map<String, dynamic> json) {
    return GuestMaterial(
      id: _asString(json['material_id']),
      title: _asString(json['title'], fallback: 'Материал'),
      category: _asString(json['category']),
      shortDescription: _asString(json['short_description']),
      readingTimeMinutes: _asInt(json['reading_time_minutes']),
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
    required this.imageUrl,
  });

  final String id;
  final String name;
  final String type;
  final String description;
  final int? estimatedTimeMinutes;
  final String? imageUrl;

  factory GuestTest.fromJson(Map<String, dynamic> json) {
    return GuestTest(
      id: _asString(json['test_id']),
      name: _asString(json['test_name'], fallback: 'Тест'),
      type: _asString(json['test_type']),
      description: _asString(json['description']),
      estimatedTimeMinutes: _asInt(json['estimated_time_minutes']),
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
    return 'несколько минут на прохождение';
  }

  return '$minutes ${_minuteWord(minutes)} на прохождение';
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

String _assetByIndex(List<String> assets, int index) {
  return assets[index % assets.length];
}
