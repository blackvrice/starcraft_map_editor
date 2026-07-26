import '../eud/eud_build_configuration.dart';
import 'eud_compiler_models.dart';
import 'eud_tool_inspector.dart';

final class EudBuildPlan {
  EudBuildPlan({
    required String buildId,
    required this.configuration,
    required this.tool,
    required this.timeout,
    this.replaceExistingOutput = false,
  }) : buildId = _requireNonBlank(buildId, 'buildId') {
    if (timeout <= Duration.zero) {
      throw ArgumentError.value(
        timeout,
        'timeout',
        'The build timeout must be positive.',
      );
    }
  }

  final String buildId;
  final EudBuildConfiguration configuration;
  final EudToolInfo tool;
  final Duration timeout;
  final bool replaceExistingOutput;
}

abstract interface class EudBuildGateway {
  Stream<EudBuildEvent> build(EudBuildPlan plan);

  Future<bool> cancel(String buildId);
}

String _requireNonBlank(String value, String name) {
  final trimmed = value.trim();
  if (trimmed.isEmpty) {
    throw ArgumentError.value(value, name, 'The value must not be blank.');
  }
  return trimmed;
}
