import '../../domain/eud/eud_dat_snapshot.dart';

abstract interface class EudDatGateway {
  Future<EudDatReadResult> read({
    required String operationId,
    required String installationPath,
  });
  void cancel(String operationId);
}

final class EudDatSource {
  EudDatSource({
    required this.snapshot,
    required this.helperVersion,
    required this.product,
    required this.build,
    required Map<String, String> hashes,
  }) : hashes = Map.unmodifiable(hashes);
  final EudDatSnapshot snapshot;
  final String helperVersion, product;
  final int build;
  final Map<String, String> hashes;
  String get label => '$product build $build; helper $helperVersion';
}

final class EudDatReadResult {
  const EudDatReadResult({
    this.source,
    this.errorCode,
    this.exitCode,
    this.stdout = '',
    this.stderr = '',
  });
  final EudDatSource? source;
  final String? errorCode;
  final int? exitCode;
  final String stdout, stderr;
  bool get isSuccess => source != null && errorCode == null;
}
