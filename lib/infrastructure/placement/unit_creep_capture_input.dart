import 'dart:convert';
import 'package:crypto/crypto.dart';
import '../../application/ports/unit_creep_capture_gateway.dart';
import '../../application/ports/unit_creep_state_gateway.dart';
import '../../domain/assets/map_sound.dart';
import '../../domain/chk/chk.dart';

/// Explicit operator/adapter configuration, not a bundled compatibility claim.
final class UnitCreepCaptureConfiguration {
  UnitCreepCaptureConfiguration({
    required this.providerId,
    required this.collectorVersion,
    required this.gameSessionId,
    required this.setupSchema,
    required Set<String> supportedGameVersions,
    required List<int> setupBytes,
    this.maximumChkBytes = UnitCreepCaptureInput.maximumChkBytes,
    this.maximumResourceBytes = UnitCreepCaptureInput.maximumResourceBytes,
    this.maximumResourceEntryBytes = MapSound.maximumBytes,
  }) : supportedGameVersions = Set.unmodifiable(supportedGameVersions),
       setupBytes = List.unmodifiable(setupBytes) {
    if ([
          providerId,
          collectorVersion,
          gameSessionId,
          setupSchema,
          ...this.supportedGameVersions,
        ].any((v) => !validCaptureText(v)) ||
        this.supportedGameVersions.isEmpty ||
        this.supportedGameVersions.length > 32 ||
        this.setupBytes.isEmpty ||
        this.setupBytes.length > 65536 ||
        this.setupBytes.any((v) => v < 0 || v > 255)) {
      throw ArgumentError('Invalid explicit creep capture configuration.');
    }
    if (maximumChkBytes < 1 ||
        maximumChkBytes > UnitCreepCaptureInput.maximumChkBytes ||
        maximumResourceBytes < 1 ||
        maximumResourceBytes > UnitCreepCaptureInput.maximumResourceBytes ||
        maximumResourceEntryBytes < 1 ||
        maximumResourceEntryBytes > MapSound.maximumBytes) {
      throw ArgumentError('Invalid capture input budgets.');
    }
  }
  final String providerId, collectorVersion, gameSessionId, setupSchema;
  final Set<String> supportedGameVersions;
  final List<int> setupBytes;
  final int maximumChkBytes, maximumResourceBytes, maximumResourceEntryBytes;
}

bool validCaptureText(String value) =>
    value.trim().isNotEmpty &&
    value.length <= 256 &&
    !value.codeUnits.any((v) => v < 32 || (v >= 127 && v <= 159));

String creepCaptureDigest(Object value) =>
    sha256.convert(utf8.encode(jsonEncode(value))).toString();

abstract final class UnitCreepCaptureInput {
  static const maximumChkBytes = 8 * 1024 * 1024;
  static const maximumResourceBytes = 64 * 1024 * 1024;

  static UnitCreepCaptureRequest prepare(
    UnitCreepStateRequest request,
    UnitCreepCaptureConfiguration configuration,
  ) {
    final session = request.session;
    final dimensions = session.metadataViews.dimensions;
    final source = request.dataIdentity;
    if (request.model != UnitCreepStateModel.initialMap ||
        !validCaptureText(request.operationId) ||
        request.documentRevision < 0 ||
        !validCaptureText(request.installationPath) ||
        !RegExp(
          r'^(?:[a-zA-Z]:[\\/]|\\\\)',
        ).hasMatch(request.installationPath) ||
        !validCaptureText(source.$1) ||
        source.$2 < 0 ||
        source.$2 > 0xffffffff ||
        !validCaptureText(source.$3) ||
        !validCaptureText(source.$4) ||
        session.requiresRestrictedEditing ||
        dimensions.length != 1 ||
        dimensions.single.width < 1 ||
        dimensions.single.width > 256 ||
        dimensions.single.height < 1 ||
        dimensions.single.height > 256 ||
        session.resourceEdits.length > 512) {
      throw const FormatException('Invalid creep capture request.');
    }
    var size = 0;
    for (final section in session.rawDocument.sections) {
      size += 8 + section.declaredLength;
      if (size > configuration.maximumChkBytes ||
          section.isEuddraftProtectionMarker) {
        throw const FormatException('Unsupported creep capture CHK.');
      }
    }
    final resources = <Object>[];
    final names = session.resourceEdits.keys.toList()..sort();
    final aliases = <String>{};
    var resourceSize = 0;
    for (final path in names) {
      // Reuse the editor's existing pending-sound path contract. Do not rename
      // entries, infer MPQ aliases or silently drop tombstones/unknown bytes.
      if (MapSound.path(path) != path || !aliases.add(path.toLowerCase())) {
        throw const FormatException('Ambiguous capture resource path.');
      }
      final bytes = session.resourceEdits[path];
      resourceSize += bytes?.length ?? 0;
      if (resourceSize > configuration.maximumResourceBytes ||
          (bytes != null &&
              (bytes.length > configuration.maximumResourceEntryBytes ||
                  bytes.any((v) => v < 0 || v > 255)))) {
        throw const FormatException('Unsupported capture resource bytes.');
      }
      resources.add([
        path,
        bytes == null ? null : [bytes.length, sha256.convert(bytes).toString()],
      ]);
    }
    final chk = const RawChkEncoder().encode(session.rawDocument);
    final chkHash = sha256.convert(chk).toString();
    final setup =
        'creep-setup-v1:${creepCaptureDigest([configuration.setupSchema, configuration.setupBytes])}';
    final base = session.sourceFingerprint;
    // Content identity excludes file paths, timestamps and lifecycle tokens.
    // This describes an intended overlay on a base archive, not an exported MPQ.
    final revision =
        'creep-input-v1:${creepCaptureDigest([
          chkHash,
          chk.length,
          session.extractedMap.scenarioLocale,
          base == null ? null : [base.sha256Digest, base.sizeBytes],
          resources,
          setup,
          [source.$1, source.$2, source.$3, source.$4],
        ])}';
    return UnitCreepCaptureRequest(
      stateRequest: request,
      inputRevision: revision,
      scenarioChkSha256: chkHash,
      baseArchiveSha256: base?.sha256Digest,
      setupRevision: setup,
      setupSchema: configuration.setupSchema,
      scenarioChkBytes: chk,
      setupBytes: configuration.setupBytes,
      resourceEdits: session.resourceEdits,
    );
  }
}
