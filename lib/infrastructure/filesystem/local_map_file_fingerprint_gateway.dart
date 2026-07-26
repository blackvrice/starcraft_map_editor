import 'dart:io';

import 'package:crypto/crypto.dart';

import '../../application/ports/map_file_fingerprint_gateway.dart';

final class LocalMapFileFingerprintGateway
    implements MapFileFingerprintGateway {
  @override
  Future<MapFileFingerprint> fingerprint(String path) async {
    final file = File(path);
    final before = await file.stat();
    if (before.type != FileSystemEntityType.file) {
      throw FileSystemException(
        'The fingerprint target is not a regular file.',
        path,
      );
    }

    final digest = await sha256.bind(file.openRead()).single;
    final after = await file.stat();
    if (after.type != FileSystemEntityType.file ||
        before.size != after.size ||
        before.modified.toUtc() != after.modified.toUtc()) {
      throw MapFileChangedDuringFingerprintingException(path);
    }

    return MapFileFingerprint(
      sizeBytes: after.size,
      modifiedAt: after.modified,
      sha256Digest: digest.toString(),
    );
  }
}
