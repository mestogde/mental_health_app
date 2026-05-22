import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../core/theme/app_theme.dart';
import '../../data/services/content_progress_service.dart';

class TestPassingScreen extends StatefulWidget {
  const TestPassingScreen({
    super.key,
    required this.testId,
    required this.title,
    required this.description,
    required this.imageAsset,
  });

  final String testId;
  final String title;
  final String description;
  final String imageAsset;

  @override
  State<TestPassingScreen> createState() => _TestPassingScreenState();
}

class _TestPassingScreenState extends State<TestPassingScreen> {
  final _supabase = Supabase.instance.client;

  late final Future<List<_TestQuestionData>> _questionsFuture;
  final Map<String, int> _answers = <String, int>{};
  bool _showResult = false;
  bool _isCompleting = false;
  double _normalizedScore = 0;
  String _conclusionText = '';

  @override
  void initState() {
    super.initState();
    _questionsFuture = _loadQuestions();
  }

  Future<List<_TestQuestionData>> _loadQuestions() async {
    final tables = <String>['test_questions', 'questions'];
    for (final table in tables) {
      try {
        final data = await _supabase
            .from(table)
            .select()
            .eq('test_id', widget.testId)
            .timeout(const Duration(seconds: 10));

        debugPrint(
          'Test questions query table=$table total rows: ${data.length}',
        );
        if (data.isEmpty) {
          continue;
        }

        final questions =
            data
                .map(
                  (row) => _TestQuestionData.fromJson(
                    Map<String, dynamic>.from(row),
                  ),
                )
                .toList()
              ..sort((a, b) => a.sortIndex.compareTo(b.sortIndex));

        debugPrint('Loaded test questions count=${questions.length}');
        return questions;
      } catch (error, stackTrace) {
        debugPrint('Test questions load error for table=$table: $error');
        debugPrintStack(stackTrace: stackTrace);
      }
    }

    return const [];
  }

  Future<void> _completeTest(List<_TestQuestionData> questions) async {
    if (_isCompleting) {
      return;
    }

    if (_answers.length < questions.length) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Ответьте на все вопросы')));
      return;
    }

    setState(() {
      _isCompleting = true;
    });

    try {
      await ContentProgressService.instance.markTestCompleted(widget.testId);
      final maxScore = questions.fold<int>(
        0,
        (sum, question) => sum + question.maxScore,
      );
      final totalScore = questions.fold<int>(
        0,
        (sum, question) => sum + (_answers[question.id] ?? 1),
      );
      final normalizedScore = maxScore <= 0
          ? 0.0
          : (totalScore / maxScore) * 10;

      if (!mounted) {
        return;
      }

      setState(() {
        _normalizedScore = normalizedScore;
        _conclusionText = _buildConclusion(normalizedScore);
        _showResult = true;
      });
    } catch (error, stackTrace) {
      debugPrint('Test completion error: $error');
      debugPrintStack(stackTrace: stackTrace);
      if (!mounted) {
        return;
      }
      setState(() {
        _normalizedScore = 0;
        _conclusionText = _buildConclusion(0);
        _showResult = true;
      });
    } finally {
      if (mounted) {
        setState(() {
          _isCompleting = false;
        });
      }
    }
  }

  String _buildConclusion(double normalizedScore) {
    if (normalizedScore < 3.5) {
      return 'Сейчас признаки напряжения выражены слабо. Можно продолжать мягко отслеживать состояние.';
    }
    if (normalizedScore < 6.8) {
      return 'Есть умеренное напряжение. Попробуйте возвращаться к рекомендациям и выбирать спокойные форматы общения.';
    }
    return 'Напряжение выражено заметно. Лучше не торопиться и обсудить состояние со специалистом центра.';
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) {
        if (didPop) {
          return;
        }
        Navigator.of(context).pop(_showResult);
      },
      child: Scaffold(
        backgroundColor: AppColors.background,
        body: SafeArea(
          bottom: false,
          child: FutureBuilder<List<_TestQuestionData>>(
            future: _questionsFuture,
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(
                  child: CircularProgressIndicator(color: AppColors.pinkAccent),
                );
              }

              if (snapshot.hasError) {
                return _TestEmptyState(
                  title: widget.title,
                  description: widget.description,
                  imageAsset: widget.imageAsset,
                  message: 'Не удалось загрузить тест.',
                  onBack: () => Navigator.of(context).pop(false),
                );
              }

              final questions = snapshot.data ?? const <_TestQuestionData>[];
              if (questions.isEmpty && !_showResult) {
                return _TestEmptyState(
                  title: widget.title,
                  description: widget.description,
                  imageAsset: widget.imageAsset,
                  message: 'Вопросы для теста пока не добавлены',
                  onBack: () => Navigator.of(context).pop(false),
                );
              }

              if (_showResult) {
                return _TestResultView(
                  title: widget.title,
                  conclusionText: _conclusionText,
                  normalizedScore: _normalizedScore,
                  onDone: () => Navigator.of(context).pop(true),
                );
              }

              return _TestQuestionsView(
                title: widget.title,
                description: widget.description,
                imageAsset: widget.imageAsset,
                questions: questions,
                answers: _answers,
                isCompleting: _isCompleting,
                onAnswerSelected: (questionId, optionIndex) {
                  setState(() {
                    _answers[questionId] = optionIndex + 1;
                  });
                },
                onBack: () => Navigator.of(context).pop(false),
                onComplete: () => _completeTest(questions),
              );
            },
          ),
        ),
      ),
    );
  }
}

class _TestQuestionsView extends StatelessWidget {
  const _TestQuestionsView({
    required this.title,
    required this.description,
    required this.imageAsset,
    required this.questions,
    required this.answers,
    required this.isCompleting,
    required this.onAnswerSelected,
    required this.onBack,
    required this.onComplete,
  });

  final String title;
  final String description;
  final String imageAsset;
  final List<_TestQuestionData> questions;
  final Map<String, int> answers;
  final bool isCompleting;
  final void Function(String questionId, int optionIndex) onAnswerSelected;
  final VoidCallback onBack;
  final VoidCallback onComplete;

  @override
  Widget build(BuildContext context) {
    final allAnswered =
        answers.length == questions.length && questions.isNotEmpty;

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(20, 10, 20, 28),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _BackButton(onTap: onBack),
          const SizedBox(height: 18),
          _HeaderImage(imageAsset: imageAsset),
          const SizedBox(height: 18),
          Text(
            title,
            style: Theme.of(context).textTheme.headlineSmall?.copyWith(
              fontSize: 24,
              fontWeight: FontWeight.w600,
              height: 1.15,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            description,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: const Color(0xFF5F5F5F),
              height: 1.45,
            ),
          ),
          const SizedBox(height: 20),
          for (var index = 0; index < questions.length; index++) ...[
            _QuestionCard(
              question: questions[index],
              selectedIndex: answers[questions[index].id]?.toInt(),
              onSelected: (optionIndex) =>
                  onAnswerSelected(questions[index].id, optionIndex),
            ),
            if (index < questions.length - 1) const SizedBox(height: 16),
          ],
          const SizedBox(height: 24),
          FilledButton(
            onPressed: allAnswered && !isCompleting ? onComplete : null,
            style: FilledButton.styleFrom(
              backgroundColor: AppColors.yellowAccent,
              foregroundColor: AppColors.textDark,
              minimumSize: const Size.fromHeight(56),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(28),
              ),
              textStyle: Theme.of(context).textTheme.titleMedium?.copyWith(
                fontSize: 17,
                fontWeight: FontWeight.w500,
              ),
            ),
            child: isCompleting
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: AppColors.pinkAccent,
                    ),
                  )
                : const Text('Завершить тест'),
          ),
        ],
      ),
    );
  }
}

class _TestResultView extends StatelessWidget {
  const _TestResultView({
    required this.title,
    required this.conclusionText,
    required this.normalizedScore,
    required this.onDone,
  });

  final String title;
  final String conclusionText;
  final double normalizedScore;
  final VoidCallback onDone;

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(20, 10, 20, 28),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _BackButton(onTap: onDone),
          const SizedBox(height: 18),
          Text(
            'Результат теста',
            style: Theme.of(context).textTheme.headlineSmall?.copyWith(
              fontSize: 24,
              fontWeight: FontWeight.w600,
              height: 1.15,
            ),
          ),
          const SizedBox(height: 12),
          Text(
            title,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: const Color(0xFF5F5F5F),
              height: 1.4,
            ),
          ),
          const SizedBox(height: 18),
          DecoratedBox(
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.85),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Padding(
              padding: const EdgeInsets.all(18),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '${normalizedScore.toStringAsFixed(1)}/10',
                    style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                      fontSize: 28,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    conclusionText,
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      height: 1.45,
                      fontSize: 15,
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 20),
          FilledButton(
            onPressed: onDone,
            style: FilledButton.styleFrom(
              backgroundColor: AppColors.yellowAccent,
              foregroundColor: AppColors.textDark,
              minimumSize: const Size.fromHeight(56),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(28),
              ),
              textStyle: Theme.of(context).textTheme.titleMedium?.copyWith(
                fontSize: 17,
                fontWeight: FontWeight.w500,
              ),
            ),
            child: const Text('Готово'),
          ),
        ],
      ),
    );
  }
}

class _TestEmptyState extends StatelessWidget {
  const _TestEmptyState({
    required this.title,
    required this.description,
    required this.imageAsset,
    required this.message,
    required this.onBack,
  });

  final String title;
  final String description;
  final String imageAsset;
  final String message;
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
          _HeaderImage(imageAsset: imageAsset),
          const SizedBox(height: 18),
          Text(
            title,
            style: Theme.of(context).textTheme.headlineSmall?.copyWith(
              fontSize: 24,
              fontWeight: FontWeight.w600,
              height: 1.15,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            description,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: const Color(0xFF5F5F5F),
              height: 1.45,
            ),
          ),
          const SizedBox(height: 24),
          DecoratedBox(
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.85),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Padding(
              padding: const EdgeInsets.all(18),
              child: Text(
                message,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: const Color(0xFF5F5F5F),
                  height: 1.45,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _QuestionCard extends StatelessWidget {
  const _QuestionCard({
    required this.question,
    required this.selectedIndex,
    required this.onSelected,
  });

  final _TestQuestionData question;
  final int? selectedIndex;
  final ValueChanged<int> onSelected;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.84),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              question.text,
              style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                fontSize: 15,
                height: 1.35,
                fontWeight: FontWeight.w500,
              ),
            ),
            const SizedBox(height: 14),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (var index = 0; index < question.options.length; index++)
                  ChoiceChip(
                    label: Text(question.options[index]),
                    selected: selectedIndex == index,
                    onSelected: (_) => onSelected(index),
                    selectedColor: AppColors.yellowAccent.withValues(
                      alpha: 0.78,
                    ),
                    backgroundColor: AppColors.surface,
                    labelStyle: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: AppColors.textDark,
                      fontSize: 12.5,
                      fontWeight: FontWeight.w500,
                    ),
                    side: BorderSide(
                      color: selectedIndex == index
                          ? AppColors.yellowAccent
                          : Colors.black.withValues(alpha: 0.06),
                    ),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _HeaderImage extends StatelessWidget {
  const _HeaderImage({required this.imageAsset});

  final String imageAsset;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(22),
      child: AspectRatio(
        aspectRatio: 1.18,
        child: Image.asset(imageAsset, fit: BoxFit.cover),
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

class _TestQuestionData {
  const _TestQuestionData({
    required this.id,
    required this.text,
    required this.options,
    required this.sortIndex,
  });

  final String id;
  final String text;
  final List<String> options;
  final int sortIndex;

  int get maxScore => options.isEmpty ? 4 : options.length;

  factory _TestQuestionData.fromJson(Map<String, dynamic> json) {
    final options = _asStringList(
      json['answer_options'] ??
          json['options'] ??
          json['variants'] ??
          json['choices'] ??
          json['answers'],
    );
    return _TestQuestionData(
      id: _asString(
        json['question_id'] ?? json['id'] ?? json['test_question_id'],
        fallback: DateTime.now().microsecondsSinceEpoch.toString(),
      ),
      text: _asString(
        json['question_text'] ??
            json['question'] ??
            json['text'] ??
            json['title'] ??
            json['body'] ??
            json['prompt'],
        fallback: 'Вопрос',
      ),
      options: options.isNotEmpty
          ? options
          : const ['Совсем нет', 'Скорее нет', 'Скорее да', 'Да'],
      sortIndex:
          _asInt(
            json['question_order'] ??
                json['order_index'] ??
                json['sort_order'] ??
                json['position'],
          ) ??
          0,
    );
  }
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

List<String> _asStringList(Object? value) {
  if (value == null) {
    return const [];
  }

  if (value is List) {
    return value
        .map((item) => item?.toString().trim() ?? '')
        .where((item) => item.isNotEmpty)
        .toList();
  }

  final text = value.toString().trim();
  if (text.isEmpty) {
    return const [];
  }

  try {
    final decoded = jsonDecode(text);
    if (decoded is List) {
      return decoded
          .map((item) => item?.toString().trim() ?? '')
          .where((item) => item.isNotEmpty)
          .toList();
    }
  } catch (_) {}

  return text
      .split(RegExp(r'[;,|]'))
      .map((item) => item.trim())
      .where((item) => item.isNotEmpty)
      .toList();
}
