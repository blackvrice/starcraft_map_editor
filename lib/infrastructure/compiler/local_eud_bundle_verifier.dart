import 'dart:io';
import 'package:crypto/crypto.dart';
import '../../domain/eud/eud_tool_manifest.dart';

/// Does not execute code or accept the expected manifest from the bundle itself.
final class LocalEudBundleVerifier {
  const LocalEudBundleVerifier();
  Future<void> verify(Directory root, EudToolManifest manifest) async {
    if (await FileSystemEntity.type(root.path, followLinks: false) !=
        FileSystemEntityType.directory) {
      throw const FormatException('Bundle root must be a regular directory.');
    }
    final canonical = Directory(await root.resolveSymbolicLinks());
    final found = <String>{};
    var directories = 0;
    await for (final entry in canonical.list(
      recursive: true,
      followLinks: false,
    )) {
      final relative = entry.path
          .substring(canonical.path.length + 1)
          .replaceAll('\\', '/');
      EudToolManifest.validatePath(relative);
      if (entry is Directory) {
        if (++directories > 4096) {
          throw const FormatException('Too many bundle directories.');
        }
        continue;
      }
      if (entry is! File) {
        throw FormatException('Bundle links are not allowed: $relative');
      }
      final expected = manifest.files[relative];
      if (expected == null) {
        throw FormatException('Unexpected bundle file: $relative');
      }
      if (!found.add(relative)) {
        throw FormatException('Duplicate bundle file: $relative');
      }
      final before = await entry.stat();
      if (before.size != expected.size) {
        throw FormatException('Bundle size mismatch: $relative');
      }
      final digest = await sha256
          .bind(entry.openRead(0, expected.size + 1))
          .single;
      final after = await entry.stat();
      if (digest.toString() != expected.sha256 ||
          before.size != after.size ||
          before.modified != after.modified) {
        throw FormatException(
          'Bundle hash mismatch or changed file: $relative',
        );
      }
    }
    if (found.length != manifest.files.length) {
      throw const FormatException('Bundle files are missing.');
    }
  }
}
