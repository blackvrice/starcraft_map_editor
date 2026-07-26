import 'eud_compiler_models.dart';

export 'eud_compiler_models.dart';

abstract interface class EudCompilerGateway {
  Stream<EudBuildEvent> build(EudBuildRequest request);

  Future<bool> cancel(String buildId);
}
