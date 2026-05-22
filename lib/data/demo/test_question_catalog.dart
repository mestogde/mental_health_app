class TestQuestionDefinition {
  const TestQuestionDefinition({
    required this.externalQuestionId,
    required this.questionText,
    required this.questionOrder,
    required this.minValue,
    required this.maxValue,
    required this.minLabel,
    required this.maxLabel,
  });

  final String externalQuestionId;
  final String questionText;
  final int questionOrder;
  final int minValue;
  final int maxValue;
  final String minLabel;
  final String maxLabel;
}

class TestQuestionCatalog {
  const TestQuestionCatalog._();

  static List<TestQuestionDefinition> questionsForTest({
    String? externalTestId,
    required String testName,
  }) {
    final normalizedKey = _normalize(
      (externalTestId != null && externalTestId.trim().isNotEmpty)
          ? externalTestId
          : testName,
    );

    for (final entry in _catalogEntries) {
      if (entry.matches(normalizedKey)) {
        return entry.questions;
      }
    }

    return const [];
  }
}

class _CatalogEntry {
  const _CatalogEntry({required this.matchKeys, required this.questions});

  final List<String> matchKeys;
  final List<TestQuestionDefinition> questions;

  bool matches(String normalizedKey) {
    return matchKeys.any((key) => _normalize(key) == normalizedKey);
  }
}

const _catalogEntries = <_CatalogEntry>[
  _CatalogEntry(
    matchKeys: ['Шкала социальной тревожности'],
    questions: [
      TestQuestionDefinition(
        externalQuestionId: 'social_anxiety_1',
        questionText: 'Мне легко начать разговор с новым человеком.',
        questionOrder: 1,
        minValue: 1,
        maxValue: 5,
        minLabel: 'Совсем не про меня',
        maxLabel: 'Полностью про меня',
      ),
      TestQuestionDefinition(
        externalQuestionId: 'social_anxiety_2',
        questionText: 'Я спокойно чувствую себя в небольшой группе.',
        questionOrder: 2,
        minValue: 1,
        maxValue: 5,
        minLabel: 'Совсем не про меня',
        maxLabel: 'Полностью про меня',
      ),
      TestQuestionDefinition(
        externalQuestionId: 'social_anxiety_3',
        questionText: 'Мне несложно задать вопрос незнакомому человеку.',
        questionOrder: 3,
        minValue: 1,
        maxValue: 5,
        minLabel: 'Совсем не про меня',
        maxLabel: 'Полностью про меня',
      ),
      TestQuestionDefinition(
        externalQuestionId: 'social_anxiety_4',
        questionText: 'Я могу высказывать своё мнение без сильного волнения.',
        questionOrder: 4,
        minValue: 1,
        maxValue: 5,
        minLabel: 'Совсем не про меня',
        maxLabel: 'Полностью про меня',
      ),
      TestQuestionDefinition(
        externalQuestionId: 'social_anxiety_5',
        questionText:
            'После общения я быстро возвращаюсь в спокойное состояние.',
        questionOrder: 5,
        minValue: 1,
        maxValue: 5,
        minLabel: 'Совсем не про меня',
        maxLabel: 'Полностью про меня',
      ),
    ],
  ),
  _CatalogEntry(
    matchKeys: ['Уровень тревоги перед встречей'],
    questions: [
      TestQuestionDefinition(
        externalQuestionId: 'meeting_anxiety_1',
        questionText: 'Перед встречей я легко сохраняю спокойствие.',
        questionOrder: 1,
        minValue: 1,
        maxValue: 5,
        minLabel: 'Совсем не про меня',
        maxLabel: 'Полностью про меня',
      ),
      TestQuestionDefinition(
        externalQuestionId: 'meeting_anxiety_2',
        questionText: 'Я могу подготовиться к встрече без лишнего напряжения.',
        questionOrder: 2,
        minValue: 1,
        maxValue: 5,
        minLabel: 'Совсем не про меня',
        maxLabel: 'Полностью про меня',
      ),
      TestQuestionDefinition(
        externalQuestionId: 'meeting_anxiety_3',
        questionText: 'Мысли о встрече не мешают мне заниматься делами.',
        questionOrder: 3,
        minValue: 1,
        maxValue: 5,
        minLabel: 'Совсем не про меня',
        maxLabel: 'Полностью про меня',
      ),
      TestQuestionDefinition(
        externalQuestionId: 'meeting_anxiety_4',
        questionText: 'Я уверенно чувствую себя, когда нужно прийти вовремя.',
        questionOrder: 4,
        minValue: 1,
        maxValue: 5,
        minLabel: 'Совсем не про меня',
        maxLabel: 'Полностью про меня',
      ),
      TestQuestionDefinition(
        externalQuestionId: 'meeting_anxiety_5',
        questionText:
            'Ожидание встречи вызывает у меня только лёгкое волнение.',
        questionOrder: 5,
        minValue: 1,
        maxValue: 5,
        minLabel: 'Совсем не про меня',
        maxLabel: 'Полностью про меня',
      ),
    ],
  ),
  _CatalogEntry(
    matchKeys: ['Самооценка уверенности в общении'],
    questions: [
      TestQuestionDefinition(
        externalQuestionId: 'confidence_1',
        questionText: 'Я могу спокойно поддержать разговор.',
        questionOrder: 1,
        minValue: 1,
        maxValue: 5,
        minLabel: 'Совсем не про меня',
        maxLabel: 'Полностью про меня',
      ),
      TestQuestionDefinition(
        externalQuestionId: 'confidence_2',
        questionText:
            'Мне легко выразить свою мысль понятно для другого человека.',
        questionOrder: 2,
        minValue: 1,
        maxValue: 5,
        minLabel: 'Совсем не про меня',
        maxLabel: 'Полностью про меня',
      ),
      TestQuestionDefinition(
        externalQuestionId: 'confidence_3',
        questionText: 'Я не теряюсь, если нужно задать уточняющий вопрос.',
        questionOrder: 3,
        minValue: 1,
        maxValue: 5,
        minLabel: 'Совсем не про меня',
        maxLabel: 'Полностью про меня',
      ),
      TestQuestionDefinition(
        externalQuestionId: 'confidence_4',
        questionText: 'Мне комфортно говорить о простых повседневных вещах.',
        questionOrder: 4,
        minValue: 1,
        maxValue: 5,
        minLabel: 'Совсем не про меня',
        maxLabel: 'Полностью про меня',
      ),
      TestQuestionDefinition(
        externalQuestionId: 'confidence_5',
        questionText: 'В общении я ощущаю себя достаточно уверенно.',
        questionOrder: 5,
        minValue: 1,
        maxValue: 5,
        minLabel: 'Совсем не про меня',
        maxLabel: 'Полностью про меня',
      ),
    ],
  ),
  _CatalogEntry(
    matchKeys: ['Комфорт в общении'],
    questions: [
      TestQuestionDefinition(
        externalQuestionId: 'comfort_1',
        questionText: 'Мне комфортно поддерживать короткий разговор.',
        questionOrder: 1,
        minValue: 1,
        maxValue: 5,
        minLabel: 'Совсем некомфортно',
        maxLabel: 'Очень комфортно',
      ),
      TestQuestionDefinition(
        externalQuestionId: 'comfort_2',
        questionText: 'Я легко нахожу общий тон с новым собеседником.',
        questionOrder: 2,
        minValue: 1,
        maxValue: 5,
        minLabel: 'Совсем некомфортно',
        maxLabel: 'Очень комфортно',
      ),
      TestQuestionDefinition(
        externalQuestionId: 'comfort_3',
        questionText: 'Мне приятно участвовать в спокойной беседе.',
        questionOrder: 3,
        minValue: 1,
        maxValue: 5,
        minLabel: 'Совсем некомфортно',
        maxLabel: 'Очень комфортно',
      ),
      TestQuestionDefinition(
        externalQuestionId: 'comfort_4',
        questionText:
            'Я чувствую себя свободно, когда общение идёт без спешки.',
        questionOrder: 4,
        minValue: 1,
        maxValue: 5,
        minLabel: 'Совсем некомфортно',
        maxLabel: 'Очень комфортно',
      ),
      TestQuestionDefinition(
        externalQuestionId: 'comfort_5',
        questionText: 'Мне легко оставаться собой в общении с другими.',
        questionOrder: 5,
        minValue: 1,
        maxValue: 5,
        minLabel: 'Совсем некомфортно',
        maxLabel: 'Очень комфортно',
      ),
    ],
  ),
  _CatalogEntry(
    matchKeys: ['Первый шаг к общению'],
    questions: [
      TestQuestionDefinition(
        externalQuestionId: 'first_step_1',
        questionText: 'Мне несложно первым написать или поздороваться.',
        questionOrder: 1,
        minValue: 1,
        maxValue: 5,
        minLabel: 'Совсем не про меня',
        maxLabel: 'Полностью про меня',
      ),
      TestQuestionDefinition(
        externalQuestionId: 'first_step_2',
        questionText: 'Я могу сделать небольшой шаг навстречу разговору.',
        questionOrder: 2,
        minValue: 1,
        maxValue: 5,
        minLabel: 'Совсем не про меня',
        maxLabel: 'Полностью про меня',
      ),
      TestQuestionDefinition(
        externalQuestionId: 'first_step_3',
        questionText: 'Даже короткое общение кажется мне посильным.',
        questionOrder: 3,
        minValue: 1,
        maxValue: 5,
        minLabel: 'Совсем не про меня',
        maxLabel: 'Полностью про меня',
      ),
      TestQuestionDefinition(
        externalQuestionId: 'first_step_4',
        questionText:
            'Я готов(а) к небольшому контакту без сильного напряжения.',
        questionOrder: 4,
        minValue: 1,
        maxValue: 5,
        minLabel: 'Совсем не про меня',
        maxLabel: 'Полностью про меня',
      ),
      TestQuestionDefinition(
        externalQuestionId: 'first_step_5',
        questionText: 'Мне понятны первые действия для начала общения.',
        questionOrder: 5,
        minValue: 1,
        maxValue: 5,
        minLabel: 'Совсем не про меня',
        maxLabel: 'Полностью про меня',
      ),
    ],
  ),
];

String _normalize(String value) {
  return value.trim().toLowerCase();
}
