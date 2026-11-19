/// Уровень проверки: ошибка, предупреждение или справка.
enum IssueSeverity { error, warning, info }

/// Результат проверки щита. Текст и уровень приходят из
/// `stop_scenarios.yaml`, логика — из калькулятора.
class CalcIssue {
  final String id;
  final IssueSeverity severity;
  final String message;

  const CalcIssue({
    required this.id,
    required this.severity,
    required this.message,
  });

  bool get isError => severity == IssueSeverity.error;

  @override
  String toString() => '[$id] $message';
}

/// Правило из YAML: что показывать, если проверка сработала.
class ScenarioRule {
  final String id;
  final IssueSeverity severity;
  final String message;

  const ScenarioRule({
    required this.id,
    required this.severity,
    required this.message,
  });

  static IssueSeverity parseSeverity(String raw) {
    switch (raw.toLowerCase()) {
      case 'error':
        return IssueSeverity.error;
      case 'info':
        return IssueSeverity.info;
      default:
        return IssueSeverity.warning;
    }
  }
}
