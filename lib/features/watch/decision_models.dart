class DecisionInput {
  final String question;
  final String context;
  final List<String> options;

  const DecisionInput({
    required this.question,
    required this.context,
    required this.options,
  });
}

class DecisionResult {
  final String markdown;
  final DateTime simulatedAt;

  const DecisionResult({
    required this.markdown,
    required this.simulatedAt,
  });
}
