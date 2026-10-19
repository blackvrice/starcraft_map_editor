import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import '../../application/ports/eud_source_translation_gateway.dart';
import '../../application/ports/eud_tool_inspector.dart';
import '../../domain/triggers/trigger_script_syntax.dart';
import 'bundled_eud_tool.dart';

final class ProcessEudSourceTranslationGateway
    implements EudSourceTranslationGateway {
  ProcessEudSourceTranslationGateway({
    required this.helperPath,
    required this.bundlePath,
    EudToolInspector? inspector,
    this.timeout = const Duration(seconds: 5),
  }) : inspector = inspector ?? BundledEudTool.inspector();
  factory ProcessEudSourceTranslationGateway.bundled() =>
      ProcessEudSourceTranslationGateway(
        helperPath:
            '${File(Platform.resolvedExecutable).parent.path}/eud_source_translate_helper.exe',
        bundlePath: BundledEudTool.installationPath,
      );
  final String helperPath, bundlePath;
  final EudToolInspector inspector;
  final Duration timeout;
  Process? _process;
  bool _busy = false;
  int _generation = 0;
  @override
  void cancel() {
    _generation++;
    _process?.kill();
  }

  @override
  Future<EudSourceTranslation> toPython(String source) async {
    if (_busy) throw StateError('EUD_TRANSLATE_BUSY');
    if (source.length > TriggerScriptSyntax.maximumCharacters ||
        source.contains('\u0000')) {
      throw const FormatException('EUD_TRANSLATE_SIZE');
    }
    _busy = true;
    final generation = ++_generation;
    Timer? timer;
    Process? process;
    var timedOut = false, exceeded = false;
    try {
      final inspected = await inspector.inspect(
        EudToolInspectionRequest(bundledPath: bundlePath),
      );
      if (!inspected.isReady ||
          inspected.tool?.version.toString() != '0.10.2.5') {
        throw StateError('EUD_TRANSLATE_TOOL_UNVERIFIED');
      }
      if (generation != _generation) {
        throw StateError('EUD_TRANSLATE_CANCELLED');
      }
      final executable = File(helperPath);
      if (!executable.isAbsolute ||
          await FileSystemEntity.type(helperPath, followLinks: false) !=
              FileSystemEntityType.file) {
        throw StateError('EUD_TRANSLATE_HELPER_MISSING');
      }
      // The helper resolves its DLL relative to itself, so inspection must refer
      // to that very bundle, not to another selected tool installation.
      final adjacent = BundledEudTool.pathForExecutable(executable.path);
      String key(String path) => Directory(path).absolute.path
          .replaceAll('\\', '/')
          .replaceAll(RegExp(r'/+$'), '')
          .toLowerCase();
      if (key(adjacent) != key(bundlePath)) {
        throw StateError('EUD_TRANSLATE_BUNDLE_MISMATCH');
      }
      process = await Process.start(
        helperPath,
        const [],
        runInShell: false,
        workingDirectory: executable.parent.path,
        includeParentEnvironment: false,
        environment: {
          for (final k in ['SYSTEMROOT', 'WINDIR', 'TEMP', 'TMP'])
            if (Platform.environment[k] != null) k: Platform.environment[k]!,
        },
      );
      _process = process;
      if (generation != _generation) process.kill();
      final active = process;
      timer = Timer(timeout, () {
        timedOut = true;
        active.kill();
      });
      Future<List<int>> collect(Stream<List<int>> stream, int limit) async {
        final bytes = BytesBuilder(copy: false);
        await for (final chunk in stream) {
          if (bytes.length + chunk.length > limit) {
            exceeded = true;
            active.kill();
          } else if (!exceeded) {
            bytes.add(chunk);
          }
        }
        return bytes.takeBytes();
      }

      final stdout = collect(process.stdout, 8 * 1024 * 1024);
      final stderr = collect(process.stderr, 64 * 1024);
      Object? inputError;
      try {
        process.stdin.add(utf8.encode(jsonEncode({'source': source})));
        await process.stdin.close();
      } on Object catch (e) {
        inputError = e;
      }
      final code = await process.exitCode;
      final output = await stdout, logBytes = await stderr;
      final log = utf8.decode(logBytes, allowMalformed: true);
      if (timedOut) throw StateError('EUD_TRANSLATE_TIMEOUT');
      if (generation != _generation) {
        throw StateError('EUD_TRANSLATE_CANCELLED');
      }
      if (exceeded) throw StateError('EUD_TRANSLATE_OUTPUT_LIMIT');
      if (inputError != null || code != 0) {
        throw StateError('EUD_TRANSLATE_COMPILER_FAILED\n$log');
      }
      final result = jsonDecode(utf8.decode(output)) as Map<String, dynamic>;
      if (result['protocol'] != 1 ||
          result['sourceExecution'] != 0 ||
          result['errors'] != 0 ||
          result['toolVersion'] != 'euddraft-0.10.2.5/epScript') {
        throw const FormatException('EUD_TRANSLATE_PROTOCOL');
      }
      final translated = result['source'] as String;
      if (translated.length > TriggerScriptSyntax.maximumCharacters) {
        throw const FormatException('EUD_TRANSLATE_SIZE');
      }
      return EudSourceTranslation(
        source: translated,
        toolVersion: result['toolVersion'] as String,
        rawLog: log,
      );
    } finally {
      timer?.cancel();
      process?.kill();
      _process = null;
      _busy = false;
    }
  }
}
