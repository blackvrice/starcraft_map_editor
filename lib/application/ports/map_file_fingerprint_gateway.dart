final class MapFileFingerprint {
  MapFileFingerprint({
    required this.sizeBytes,
    required DateTime modifiedAt,
    required String sha256Digest,
  }) : modifiedAtUtc = modifiedAt.toUtc(),
       sha256Digest = sha256Digest.toLowerCase() {
    if (sizeBytes < 0) {
      throw ArgumentError.value(
        sizeBytes,
        'sizeBytes',
        'The file size must not be negative.',
      );
    }
    if (!RegExp(r'^[0-9a-fA-F]{64}$').hasMatch(sha256Digest)) {
      throw ArgumentError.value(
        sha256Digest,
        'sha256Digest',
        'The SHA-256 digest must contain exactly 64 hexadecimal characters.',
      );
    }
  }

  final int sizeBytes;
  final DateTime modifiedAtUtc;
  final String sha256Digest;

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        other is MapFileFingerprint &&
            sizeBytes == other.sizeBytes &&
            modifiedAtUtc == other.modifiedAtUtc &&
            sha256Digest == other.sha256Digest;
  }

  @override
  int get hashCode => Object.hash(sizeBytes, modifiedAtUtc, sha256Digest);

  @override
  String toString() {
    return 'MapFileFingerprint('
        'sizeBytes: $sizeBytes, '
        'modifiedAtUtc: ${modifiedAtUtc.toIso8601String()}, '
        'sha256Digest: $sha256Digest'
        ')';
  }
}

abstract interface class MapFileFingerprintGateway {
  Future<MapFileFingerprint> fingerprint(String path);
}

final class MapFileChangedDuringFingerprintingException implements Exception {
  const MapFileChangedDuringFingerprintingException(this.path);

  final String path;

  @override
  String toString() {
    return 'The file changed while its fingerprint was being calculated: '
        '$path';
  }
}
