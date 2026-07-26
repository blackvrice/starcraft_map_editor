import 'dart:typed_data';

import '../../domain/diagnostics/editor_diagnostic.dart';

abstract final class MapArchiveEntryPaths {
  static const scenarioChk = r'staredit\scenario.chk';
  static const listFile = '(listfile)';
  static const attributes = '(attributes)';
  static const signature = '(signature)';

  static bool isScenarioChk(String path) =>
      path.replaceAll('/', r'\').toLowerCase() == scenarioChk;

  static bool isInternal(String path) {
    return switch (path.toLowerCase()) {
      listFile || attributes || signature => true,
      _ => false,
    };
  }
}

class MapArchiveOpenRequest {
  MapArchiveOpenRequest({
    required this.operationId,
    required this.sourcePath,
    required this.timeout,
  }) {
    _requireNonBlank(operationId, 'operationId');
    _requireNonBlank(sourcePath, 'sourcePath');
    _requirePositiveTimeout(timeout);
  }

  final String operationId;
  final String sourcePath;
  final Duration timeout;
}

class MapArchiveWriteRequest {
  MapArchiveWriteRequest({
    required this.operationId,
    required this.sourcePath,
    required this.temporaryOutputPath,
    required List<int> scenarioChkBytes,
    required this.timeout,
  }) : scenarioChkBytes = _copyBytes(scenarioChkBytes) {
    _requireNonBlank(operationId, 'operationId');
    _requireNonBlank(sourcePath, 'sourcePath');
    _requireNonBlank(temporaryOutputPath, 'temporaryOutputPath');
    _requirePositiveTimeout(timeout);

    if (sourcePath == temporaryOutputPath) {
      throw ArgumentError.value(
        temporaryOutputPath,
        'temporaryOutputPath',
        'The temporary output path must differ from the source path.',
      );
    }
  }

  final String operationId;
  final String sourcePath;
  final String temporaryOutputPath;
  final Uint8List scenarioChkBytes;
  final Duration timeout;
}

class MapArchiveEntryMetadata {
  MapArchiveEntryMetadata({
    required this.path,
    required this.uncompressedSizeBytes,
    required this.compressedSizeBytes,
    required this.flags,
    required this.locale,
    required this.nameIsSynthetic,
  }) {
    _requireNonBlank(path, 'path');
    _requireUint32(uncompressedSizeBytes, 'uncompressedSizeBytes');
    _requireUint32(compressedSizeBytes, 'compressedSizeBytes');
    _requireUint32(flags, 'flags');
    _requireUint32(locale, 'locale');
  }

  final String path;
  final int uncompressedSizeBytes;
  final int compressedSizeBytes;
  final int flags;
  final int locale;
  final bool nameIsSynthetic;

  bool get isEncrypted => flags & 0x00010000 != 0;

  bool get isInternal => MapArchiveEntryPaths.isInternal(path);
}

class MapArchiveMetadata {
  MapArchiveMetadata({
    required this.archiveSizeBytes,
    required this.formatVersion,
    required this.totalEntryCount,
    required Iterable<MapArchiveEntryMetadata> entries,
    required this.listingComplete,
    this.listingNativeError,
  }) : entries = List.unmodifiable(entries) {
    _requireNonNegative(archiveSizeBytes, 'archiveSizeBytes');
    if (formatVersion <= 0 || formatVersion > 0xffffffff) {
      throw RangeError.value(
        formatVersion,
        'formatVersion',
        'The MPQ format version must be a positive uint32 value.',
      );
    }
    _requireUint32(totalEntryCount, 'totalEntryCount');
    if (totalEntryCount < this.entries.length) {
      throw ArgumentError.value(
        totalEntryCount,
        'totalEntryCount',
        'The total entry count cannot be smaller than the listed entries.',
      );
    }
    if (listingComplete && totalEntryCount != this.entries.length) {
      throw ArgumentError.value(
        listingComplete,
        'listingComplete',
        'A complete listing must contain every reported archive entry.',
      );
    }
    final listingNativeError = this.listingNativeError;
    if (listingNativeError != null) {
      _requireUint32(listingNativeError, 'listingNativeError');
      if (listingNativeError == 0) {
        throw RangeError.value(
          listingNativeError,
          'listingNativeError',
          'A listing error must use a nonzero native error code.',
        );
      }
      if (listingComplete) {
        throw ArgumentError.value(
          listingNativeError,
          'listingNativeError',
          'A complete listing cannot contain a native listing error.',
        );
      }
    }
  }

  final int archiveSizeBytes;
  final int formatVersion;
  final int totalEntryCount;
  final List<MapArchiveEntryMetadata> entries;
  final bool listingComplete;
  final int? listingNativeError;
}

class ExtractedMap {
  ExtractedMap({
    required this.sourcePath,
    required List<int> scenarioChkBytes,
    required this.metadata,
  }) : scenarioChkBytes = _copyBytes(scenarioChkBytes) {
    _requireNonBlank(sourcePath, 'sourcePath');

    final scenarioEntries = metadata.entries.where(
      (entry) => MapArchiveEntryPaths.isScenarioChk(entry.path),
    );
    if (scenarioEntries.length != 1) {
      throw ArgumentError.value(
        metadata.entries,
        'metadata',
        'Metadata must contain exactly one scenario.chk entry.',
      );
    }

    final scenarioEntry = scenarioEntries.single;
    if (scenarioEntry.uncompressedSizeBytes != this.scenarioChkBytes.length) {
      throw ArgumentError.value(
        scenarioEntry.uncompressedSizeBytes,
        'metadata',
        'The scenario.chk entry size must match the extracted bytes.',
      );
    }
  }

  final String sourcePath;
  final Uint8List scenarioChkBytes;
  final MapArchiveMetadata metadata;
}

class MapArchiveOpenResult {
  MapArchiveOpenResult.success({
    required ExtractedMap map,
    Iterable<EditorDiagnostic> diagnostics = const [],
  }) : extractedMap = map,
       diagnostics = List.unmodifiable(diagnostics) {
    _requireNoBlockingDiagnostics(this.diagnostics);
  }

  MapArchiveOpenResult.failure({
    required Iterable<EditorDiagnostic> diagnostics,
  }) : extractedMap = null,
       diagnostics = List.unmodifiable(diagnostics) {
    _requireBlockingDiagnostic(this.diagnostics);
  }

  final ExtractedMap? extractedMap;
  final List<EditorDiagnostic> diagnostics;

  bool get hasBlockingDiagnostics =>
      diagnostics.any((diagnostic) => diagnostic.blocksOperation);

  bool get isSuccess => extractedMap != null && !hasBlockingDiagnostics;
}

class MapArchiveWriteResult {
  MapArchiveWriteResult.success({
    required String temporaryOutputPath,
    Iterable<EditorDiagnostic> diagnostics = const [],
  }) : temporaryOutputPath = temporaryOutputPath,
       diagnostics = List.unmodifiable(diagnostics) {
    _requireNonBlank(temporaryOutputPath, 'temporaryOutputPath');
    _requireNoBlockingDiagnostics(this.diagnostics);
  }

  MapArchiveWriteResult.failure({
    required Iterable<EditorDiagnostic> diagnostics,
  }) : temporaryOutputPath = null,
       diagnostics = List.unmodifiable(diagnostics) {
    _requireBlockingDiagnostic(this.diagnostics);
  }

  final String? temporaryOutputPath;
  final List<EditorDiagnostic> diagnostics;

  bool get hasBlockingDiagnostics =>
      diagnostics.any((diagnostic) => diagnostic.blocksOperation);

  bool get isSuccess => temporaryOutputPath != null && !hasBlockingDiagnostics;
}

void _requireNonBlank(String value, String name) {
  if (value.trim().isEmpty) {
    throw ArgumentError.value(value, name, 'The value must not be blank.');
  }
}

Uint8List _copyBytes(List<int> values) {
  for (var index = 0; index < values.length; index++) {
    final value = values[index];
    if (value < 0 || value > 0xff) {
      throw RangeError.value(
        value,
        'scenarioChkBytes[$index]',
        'A byte must be between 0 and 255.',
      );
    }
  }

  return Uint8List.fromList(values).asUnmodifiableView();
}

void _requirePositiveTimeout(Duration timeout) {
  if (timeout <= Duration.zero) {
    throw ArgumentError.value(
      timeout,
      'timeout',
      'The timeout must be greater than zero.',
    );
  }
}

void _requireNonNegative(int value, String name) {
  if (value < 0) {
    throw RangeError.value(value, name, 'The value cannot be negative.');
  }
}

void _requireUint32(int value, String name) {
  if (value < 0 || value > 0xffffffff) {
    throw RangeError.range(value, 0, 0xffffffff, name);
  }
}

void _requireNoBlockingDiagnostics(List<EditorDiagnostic> diagnostics) {
  if (diagnostics.any((diagnostic) => diagnostic.blocksOperation)) {
    throw ArgumentError.value(
      diagnostics,
      'diagnostics',
      'A successful result cannot contain blocking diagnostics.',
    );
  }
}

void _requireBlockingDiagnostic(List<EditorDiagnostic> diagnostics) {
  if (!diagnostics.any((diagnostic) => diagnostic.blocksOperation)) {
    throw ArgumentError.value(
      diagnostics,
      'diagnostics',
      'A failed result must contain a blocking diagnostic.',
    );
  }
}
