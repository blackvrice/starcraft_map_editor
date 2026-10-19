final class EudSourceTranslation {
  const EudSourceTranslation({
    required this.source,
    required this.toolVersion,
    required this.rawLog,
  });
  final String source, toolVersion, rawLog;
}

abstract interface class EudSourceTranslationGateway {
  Future<EudSourceTranslation> toPython(String source);
  void cancel();
}
