abstract final class EudEnvironmentRules {
  static Map<String, String> copyAndValidate(
    Map<String, String> environmentOverrides,
  ) {
    final copied = Map<String, String>.of(environmentOverrides);
    final normalizedNames = <String>{};
    for (final entry in copied.entries) {
      if (entry.key.trim().isEmpty ||
          entry.key != entry.key.trim() ||
          entry.key.contains('=') ||
          entry.key.codeUnits.any(
            (codeUnit) => codeUnit < 0x20 || codeUnit == 0x7f,
          )) {
        throw ArgumentError.value(
          entry.key,
          'environmentOverrides',
          'Environment variable names must not have surrounding whitespace '
              'or contain "=" or control characters.',
        );
      }
      if (!normalizedNames.add(entry.key.toUpperCase())) {
        throw ArgumentError.value(
          entry.key,
          'environmentOverrides',
          'Environment variable names must be unique case-insensitively.',
        );
      }
      if (entry.value.contains('\u0000')) {
        throw ArgumentError.value(
          entry.value,
          'environmentOverrides',
          'Environment variable values cannot contain NUL.',
        );
      }
    }
    return Map.unmodifiable(copied);
  }
}
