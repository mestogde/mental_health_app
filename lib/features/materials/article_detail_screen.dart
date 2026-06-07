import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../core/theme/app_theme.dart';
import '../../data/services/content_progress_service.dart';
import '../../data/services/reference_data_service.dart';

class ArticleDetailScreen extends StatefulWidget {
  const ArticleDetailScreen({
    super.key,
    required this.articleId,
    required this.title,
    required this.category,
    required this.summary,
    required this.readingTimeMinutes,
    required this.accessLevel,
    required this.imageAsset,
  });

  final String articleId;
  final String title;
  final String category;
  final String summary;
  final int? readingTimeMinutes;
  final String accessLevel;
  final String imageAsset;

  @override
  State<ArticleDetailScreen> createState() => _ArticleDetailScreenState();
}

class _ArticleDetailScreenState extends State<ArticleDetailScreen> {
  final _supabase = Supabase.instance.client;

  late final Future<_ArticleDetailData> _detailFuture;
  bool _didRecordRead = false;

  @override
  void initState() {
    super.initState();
    _detailFuture = _loadArticleDetail();
    _recordRead();
  }

  Future<void> _recordRead() async {
    try {
      await ContentProgressService.instance.markMaterialRead(widget.articleId);
    } catch (error, stackTrace) {
      debugPrint('Article read record error: $error');
      debugPrintStack(stackTrace: stackTrace);
    }

    if (!mounted) {
      return;
    }

    setState(() {
      _didRecordRead = true;
    });
  }

  Future<_ArticleDetailData> _loadArticleDetail() async {
    const baseSelect = materialsSelectFields;
    final contentFields = <String>[
      'description',
      'content',
      'body',
      'material_text',
      'full_text',
    ];

    for (final field in contentFields) {
      try {
        final row = await _supabase
            .from('materials')
            .select('$baseSelect, $field')
            .eq('material_id', widget.articleId)
            .maybeSingle();

        if (row == null) {
          continue;
        }

        final map = Map<String, dynamic>.from(row);
        final bodyText = _resolveBodyText(map, field);

        return _ArticleDetailData(
          id: _asString(map['material_id'], fallback: widget.articleId),
          title: _asString(map['title'], fallback: widget.title),
          category: _asString(map['category'], fallback: widget.category),
          summary: _asString(
            map['short_description'],
            fallback: widget.summary,
          ),
          readingTimeMinutes:
              _asInt(map['reading_time_minutes']) ?? widget.readingTimeMinutes,
          imageUrl: _asNullableString(map['image_url']),
          bodyText: bodyText.isNotEmpty
              ? bodyText
              : _asString(map['short_description'], fallback: widget.summary),
        );
      } catch (error, stackTrace) {
        debugPrint('Article detail query error for $field: $error');
        debugPrintStack(stackTrace: stackTrace);
      }
    }

    try {
      final row = await _supabase
          .from('materials')
          .select(baseSelect)
          .eq('material_id', widget.articleId)
          .maybeSingle();

      if (row != null) {
        final map = Map<String, dynamic>.from(row);
        return _ArticleDetailData(
          id: _asString(map['material_id'], fallback: widget.articleId),
          title: _asString(map['title'], fallback: widget.title),
          category: _asString(map['category'], fallback: widget.category),
          summary: _asString(
            map['short_description'],
            fallback: widget.summary,
          ),
          readingTimeMinutes:
              _asInt(map['reading_time_minutes']) ?? widget.readingTimeMinutes,
          imageUrl: _asNullableString(map['image_url']),
          bodyText: _asString(
            map['short_description'],
            fallback: widget.summary,
          ),
        );
      }
    } catch (error, stackTrace) {
      debugPrint('Article detail fallback query error: $error');
      debugPrintStack(stackTrace: stackTrace);
    }

    return _ArticleDetailData(
      id: widget.articleId,
      title: widget.title,
      category: widget.category,
      summary: widget.summary,
      readingTimeMinutes: widget.readingTimeMinutes,
      imageUrl: null,
      bodyText: widget.summary,
    );
  }

  String _resolveBodyText(Map<String, dynamic> map, String field) {
    final candidate = _asString(map[field]);
    if (candidate.isNotEmpty) {
      return candidate;
    }

    final shortDescription = _asString(map['short_description']);
    if (shortDescription.isNotEmpty) {
      return shortDescription;
    }

    return widget.summary;
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) {
        if (didPop) {
          return;
        }
        Navigator.of(context).pop(_didRecordRead);
      },
      child: Scaffold(
        backgroundColor: AppColors.background,
        body: SafeArea(
          bottom: false,
          child: FutureBuilder<_ArticleDetailData>(
            future: _detailFuture,
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(
                  child: CircularProgressIndicator(color: AppColors.pinkAccent),
                );
              }

              if (snapshot.hasError) {
                return _ArticleDetailFallback(
                  title: widget.title,
                  category: widget.category,
                  readingTimeMinutes: widget.readingTimeMinutes,
                  imageAsset: widget.imageAsset,
                  bodyText: widget.summary,
                  errorText: 'Не удалось загрузить статью.',
                  onBack: () => Navigator.of(context).pop(_didRecordRead),
                );
              }

              final detail = snapshot.data;
              if (detail == null) {
                return _ArticleDetailFallback(
                  title: widget.title,
                  category: widget.category,
                  readingTimeMinutes: widget.readingTimeMinutes,
                  imageAsset: widget.imageAsset,
                  bodyText: widget.summary,
                  onBack: () => Navigator.of(context).pop(_didRecordRead),
                );
              }

              return _ArticleDetailContent(
                detail: detail,
                imageAsset: widget.imageAsset,
                onBack: () => Navigator.of(context).pop(_didRecordRead),
              );
            },
          ),
        ),
      ),
    );
  }
}

class _ArticleDetailContent extends StatelessWidget {
  const _ArticleDetailContent({
    required this.detail,
    required this.imageAsset,
    required this.onBack,
  });

  final _ArticleDetailData detail;
  final String imageAsset;
  final VoidCallback onBack;

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(20, 10, 20, 28),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _BackButton(onTap: onBack),
          const SizedBox(height: 18),
          _HeroImage(detail: detail, imageAsset: imageAsset),
          const SizedBox(height: 18),
          if (detail.category.isNotEmpty) ...[
            _CategoryPill(text: detail.category),
            const SizedBox(height: 12),
          ],
          Text(
            detail.title,
            style: Theme.of(context).textTheme.headlineSmall?.copyWith(
              fontSize: 24,
              fontWeight: FontWeight.w600,
              height: 1.15,
            ),
          ),
          if (detail.readingTimeMinutes != null) ...[
            const SizedBox(height: 8),
            Text(
              _minutesText(detail.readingTimeMinutes),
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: const Color(0xFF777777),
                fontSize: 13,
              ),
            ),
          ],
          const SizedBox(height: 18),
          Text(
            detail.bodyText,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              height: 1.55,
              fontSize: 15,
              color: const Color(0xFF2B2B2B),
            ),
          ),
        ],
      ),
    );
  }
}

class _ArticleDetailFallback extends StatelessWidget {
  const _ArticleDetailFallback({
    required this.title,
    required this.category,
    required this.readingTimeMinutes,
    required this.imageAsset,
    required this.bodyText,
    required this.onBack,
    this.errorText,
  });

  final String title;
  final String category;
  final int? readingTimeMinutes;
  final String imageAsset;
  final String bodyText;
  final VoidCallback onBack;
  final String? errorText;

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(20, 10, 20, 28),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _BackButton(onTap: onBack),
          const SizedBox(height: 18),
          _HeroImage(
            detail: _ArticleDetailData(
              id: '',
              title: title,
              category: category,
              summary: bodyText,
              readingTimeMinutes: readingTimeMinutes,
              imageUrl: null,
              bodyText: bodyText,
            ),
            imageAsset: imageAsset,
          ),
          const SizedBox(height: 18),
          if (category.isNotEmpty) ...[
            _CategoryPill(text: category),
            const SizedBox(height: 12),
          ],
          Text(
            title,
            style: Theme.of(context).textTheme.headlineSmall?.copyWith(
              fontSize: 24,
              fontWeight: FontWeight.w600,
              height: 1.15,
            ),
          ),
          if (readingTimeMinutes != null) ...[
            const SizedBox(height: 8),
            Text(
              _minutesText(readingTimeMinutes),
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: const Color(0xFF777777),
                fontSize: 13,
              ),
            ),
          ],
          if (errorText != null) ...[
            const SizedBox(height: 18),
            Text(
              errorText!,
              style: Theme.of(
                context,
              ).textTheme.bodyMedium?.copyWith(color: const Color(0xFF777777)),
            ),
          ],
          const SizedBox(height: 18),
          Text(
            bodyText,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              height: 1.55,
              fontSize: 15,
              color: const Color(0xFF2B2B2B),
            ),
          ),
        ],
      ),
    );
  }
}

class _HeroImage extends StatelessWidget {
  const _HeroImage({required this.detail, required this.imageAsset});

  final _ArticleDetailData detail;
  final String imageAsset;

  @override
  Widget build(BuildContext context) {
    final imageUrl = detail.imageUrl?.trim() ?? '';

    return ClipRRect(
      borderRadius: BorderRadius.circular(22),
      child: AspectRatio(
        aspectRatio: 1.18,
        child: Stack(
          fit: StackFit.expand,
          children: [
            if (imageUrl.isNotEmpty)
              Image.network(
                imageUrl,
                fit: BoxFit.cover,
                errorBuilder: (context, error, stackTrace) {
                  return Image.asset(
                    imageAsset,
                    fit: BoxFit.cover,
                    errorBuilder: (context, error, stackTrace) =>
                        const _HeroPlaceholder(),
                  );
                },
              )
            else
              Image.asset(
                imageAsset,
                fit: BoxFit.cover,
                errorBuilder: (context, error, stackTrace) =>
                    const _HeroPlaceholder(),
              ),
            Align(
              alignment: Alignment.bottomCenter,
              child: Container(
                height: 84,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      Colors.transparent,
                      const Color(0xFF000000).withValues(alpha: 0.42),
                    ],
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

class _HeroPlaceholder extends StatelessWidget {
  const _HeroPlaceholder();

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            AppColors.yellowAccent.withValues(alpha: 0.62),
            AppColors.pinkAccent.withValues(alpha: 0.58),
            AppColors.blueAccent.withValues(alpha: 0.52),
          ],
        ),
      ),
    );
  }
}

class _BackButton extends StatelessWidget {
  const _BackButton({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
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
    );
  }
}

class _CategoryPill extends StatelessWidget {
  const _CategoryPill({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.82),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        child: Text(
          text,
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
            color: const Color(0xFF5F5F5F),
            fontSize: 12,
          ),
        ),
      ),
    );
  }
}

class _ArticleDetailData {
  const _ArticleDetailData({
    required this.id,
    required this.title,
    required this.category,
    required this.summary,
    required this.readingTimeMinutes,
    required this.imageUrl,
    required this.bodyText,
  });

  final String id;
  final String title;
  final String category;
  final String summary;
  final int? readingTimeMinutes;
  final String? imageUrl;
  final String bodyText;
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
