import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../data/demo/test_question_catalog.dart';
import '../../core/theme/app_theme.dart';
import '../../data/services/content_progress_service.dart';
import '../../data/services/reference_data_service.dart';
import '../../data/services/session_service.dart';

class TestPassingScreen extends StatefulWidget {
  const TestPassingScreen({
    super.key,
    required this.testId,
    this.externalTestId = '',
    required this.title,
    required this.description,
    required this.imageAsset,
  });

  final String testId;
  final String externalTestId;
  final String title;
  final String description;
  final String imageAsset;

  @override
  State<TestPassingScreen> createState() => _TestPassingScreenState();
}

class _TestPassingScreenState extends State<TestPassingScreen> {
  final _supabase = Supabase.instance.client;

  late final List<TestQuestionDefinition> _questions;
  final Map<String, int> _answers = <String, int>{};
  bool _showResult = false;
  bool _isCompleting = false;
  double _averageScore = 0;
  String _conclusionText = '';
  late final DateTime _startedAt;

  @override
  void initState() {
    super.initState();
    _startedAt = DateTime.now();
    _questions = TestQuestionCatalog.questionsForTest(
      externalTestId: widget.externalTestId,
      testName: widget.title,
    );
    debugPrint(
      'Local test catalog loaded: test="${widget.title}" '
      'externalTestId=${widget.externalTestId} questions=${_questions.length}',
    );
  }

  Future<void> _completeTest() async {
    if (_isCompleting) {
      return;
    }

    if (_answers.length < _questions.length) {
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
      final totalScore = _questions.fold<int>(
        0,
        (sum, question) => sum + (_answers[question.externalQuestionId] ?? 1),
      );
      final averageScore = _questions.isEmpty
          ? 0.0
          : totalScore / _questions.length;
      final conclusion = _buildConclusion(averageScore);
      await _saveAttemptToSupabase(
        totalScore: totalScore,
        averageScore: averageScore,
        conclusion: conclusion,
      );

      if (!mounted) {
        return;
      }

      setState(() {
        _averageScore = averageScore;
        _conclusionText = conclusion;
        _showResult = true;
      });
    } catch (error, stackTrace) {
      debugPrint('Test completion error: $error');
      debugPrintStack(stackTrace: stackTrace);
      if (!mounted) {
        return;
      }
      setState(() {
        _averageScore = 0;
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

  Future<bool> _saveAttemptToSupabase({
    required int totalScore,
    required double averageScore,
    required String conclusion,
  }) async {
    var phase = 'resolve_patient_id';
    try {
      debugPrint(
        'Test attempt summary: totalScore=$totalScore '
        'averageScore=${averageScore.toStringAsFixed(1)}',
      );
      phase = 'resolve_patient_id';
      debugPrint('Test save phase: $phase');
      final patientId = await _loadCurrentPatientId();
      debugPrint('Resolved patient_id for test save: $patientId');

      final nowIso = DateTime.now().toIso8601String();
      final attemptPayload = <String, dynamic>{
        'patient_id': patientId,
        'test_id': widget.testId,
        'started_at': _startedAt.toIso8601String(),
        'completed_at': nowIso,
        'total_score': totalScore,
        'interpretation': conclusion,
        'conclusion': conclusion,
        'attempt_status_id': await ReferenceDataService.instance.getId(
          table: ReferenceTables.testAttemptStatuses,
          idColumn: 'attempt_status_id',
          systemValue: 'completed',
        ),
        'created_at': nowIso,
        'updated_at': nowIso,
      };

      debugPrint('Test attempt payload: $attemptPayload');
      phase = 'insert_test_attempts';
      debugPrint('Test save phase: $phase');
      final attemptRow = await _supabase
          .from('test_attempts')
          .insert(attemptPayload)
          .select('test_attempt_id')
          .single()
          .timeout(const Duration(seconds: 10));
      debugPrint('Test attempt insert returned row: $attemptRow');

      final normalizedAttemptRow = Map<String, dynamic>.from(attemptRow);
      final attemptId = _extractAttemptId(normalizedAttemptRow);
      if (attemptId.isEmpty) {
        throw StateError('Test attempt row has no id: $normalizedAttemptRow');
      }
      debugPrint('Resolved test_attempt_id for answers insert: $attemptId');

      final answerPayloads = _questions
          .map(
            (question) => <String, dynamic>{
              'test_attempt_id': attemptId,
              'external_question_id': question.externalQuestionId,
              'question_text': question.questionText,
              'answer_value': (_answers[question.externalQuestionId] ?? 1)
                  .toString(),
              'answer_score': _answers[question.externalQuestionId] ?? 1,
              'question_order': question.questionOrder,
              'created_at': nowIso,
              'updated_at': nowIso,
            },
          )
          .toList();

      debugPrint('Test answers payload count=${answerPayloads.length}');
      for (final payload in answerPayloads) {
        debugPrint('Test answer payload: $payload');
      }
      phase = 'insert_patient_answers';
      debugPrint('Test save phase: $phase');
      await _supabase
          .from('patient_answers')
          .insert(answerPayloads)
          .timeout(const Duration(seconds: 10));

      debugPrint('Test attempt save completed successfully.');
      return true;
    } catch (error, stackTrace) {
      debugPrint('Test attempt save failed at phase: $phase');
      if (error is PostgrestException) {
        debugPrint('Test attempt save PostgrestException:');
        debugPrint('message: ${error.message}');
        debugPrint('code: ${error.code}');
        debugPrint('details: ${error.details}');
        debugPrint('hint: ${error.hint}');
      }
      debugPrint('Test attempt save error: $error');
      debugPrintStack(stackTrace: stackTrace);
      return false;
    }
  }

  String _extractAttemptId(Map<String, dynamic> row) {
    final candidate = row['test_attempt_id'] ?? row['id'] ?? row['attempt_id'];
    return candidate?.toString().trim() ?? '';
  }

  Future<String> _loadCurrentPatientId() async {
    final externalId = await SessionService().getCurrentPatientExternalId();
    debugPrint('Resolving patient_id for external_patient_id=$externalId');
    final data = await _supabase
        .from('patients')
        .select('patient_id')
        .eq('external_patient_id', externalId)
        .limit(1)
        .timeout(const Duration(seconds: 10));

    if (data.isEmpty) {
      throw StateError('Patient not found for external id: $externalId');
    }

    final patientId = data.first['patient_id'];
    if (patientId == null) {
      throw StateError('Patient row has no patient_id');
    }

    return patientId.toString();
  }

  String _buildConclusion(double averageScore) {
    if (averageScore <= 2.0) {
      return 'Сейчас признаки напряжения выражены слабо. Можно продолжать мягко отслеживать состояние.';
    }
    if (averageScore <= 3.5) {
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
          child: _questions.isEmpty && !_showResult
              ? _TestEmptyState(
                  title: widget.title,
                  description: widget.description,
                  imageAsset: widget.imageAsset,
                  message: 'Вопросы для теста пока не добавлены',
                  onBack: () => Navigator.of(context).pop(false),
                )
              : _showResult
              ? _TestResultView(
                  title: widget.title,
                  conclusionText: _conclusionText,
                  averageScore: _averageScore,
                  onDone: () => Navigator.of(context).pop(true),
                )
              : _TestQuestionsView(
                  title: widget.title,
                  description: widget.description,
                  imageAsset: widget.imageAsset,
                  questions: _questions,
                  answers: _answers,
                  isCompleting: _isCompleting,
                  onAnswerSelected: (questionId, selectedScore) {
                    setState(() {
                      _answers[questionId] = selectedScore;
                    });
                  },
                  onBack: () => Navigator.of(context).pop(false),
                  onComplete: _completeTest,
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
  final List<TestQuestionDefinition> questions;
  final Map<String, int> answers;
  final bool isCompleting;
  final void Function(String questionId, int selectedScore) onAnswerSelected;
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
              selectedScore: answers[questions[index].externalQuestionId],
              onSelected: (selectedScore) => onAnswerSelected(
                questions[index].externalQuestionId,
                selectedScore,
              ),
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
    required this.averageScore,
    required this.onDone,
  });

  final String title;
  final String conclusionText;
  final double averageScore;
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
                    '${averageScore.toStringAsFixed(1)}/5',
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
    required this.selectedScore,
    required this.onSelected,
  });

  final TestQuestionDefinition question;
  final int? selectedScore;
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
              question.questionText,
              style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                fontSize: 15,
                height: 1.35,
                fontWeight: FontWeight.w500,
              ),
            ),
            const SizedBox(height: 14),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                for (
                  var score = question.minValue;
                  score <= question.maxValue;
                  score++
                )
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 3),
                      child: GestureDetector(
                        onTap: () => onSelected(score),
                        behavior: HitTestBehavior.opaque,
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 150),
                          height: 44,
                          decoration: BoxDecoration(
                            color: selectedScore == score
                                ? AppColors.yellowAccent.withValues(alpha: 0.82)
                                : AppColors.surface,
                            borderRadius: BorderRadius.circular(22),
                            border: Border.all(
                              color: selectedScore == score
                                  ? AppColors.yellowAccent
                                  : Colors.black.withValues(alpha: 0.06),
                            ),
                          ),
                          child: Center(
                            child: Text(
                              '$score',
                              style: Theme.of(context).textTheme.bodyMedium
                                  ?.copyWith(
                                    color: AppColors.textDark,
                                    fontSize: 14,
                                    fontWeight: FontWeight.w600,
                                  ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 10),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Text(
                    question.minLabel,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: const Color(0xFF777777),
                      fontSize: 11,
                      height: 1.15,
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    question.maxLabel,
                    textAlign: TextAlign.right,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: const Color(0xFF777777),
                      fontSize: 11,
                      height: 1.15,
                    ),
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
