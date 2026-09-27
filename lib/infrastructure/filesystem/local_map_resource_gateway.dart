import 'dart:async';
import 'dart:io';
import 'package:flutter/services.dart';
import '../../application/ports/map_resource_gateway.dart';
import '../../domain/assets/map_sound.dart';

class LocalMapResourceGateway implements MapResourceGateway {
  LocalMapResourceGateway(
    this.reader, {
    this.channel = const MethodChannel('starcraft_map_editor/file_dialog'),
  });
  final MapArchiveResourceReader reader;
  final MethodChannel channel;
  Process? _preview;
  Directory? _previewDirectory;
  @override
  Future<({String name, List<int> bytes})?> importSound() async {
    final path = await channel.invokeMethod<String>('openSound');
    if (path == null) return null;
    final picked = File(path);
    if (await picked.length() > MapSound.maximumBytes) {
      throw const FormatException('Sound exceeds 16 MiB.');
    }
    final bytes = await picked.readAsBytes();
    MapSound.validate(bytes);
    return (name: picked.uri.pathSegments.last, bytes: bytes);
  }

  @override
  Future<void> exportSound(String name, List<int> bytes) async {
    final target = await channel.invokeMethod<String>('saveSound', {
      'suggestedName': name.split('\\').last,
    });
    if (target == null) return;
    if (!target.toLowerCase().endsWith('.wav')) {
      throw const FormatException('Export destination must end in .wav.');
    }
    await File(target).writeAsBytes(bytes, flush: true);
  }

  @override
  Future<List<int>?> readSound(String archive, String path) =>
      reader.readResource(archive, path);
  @override
  Future<void> preview(List<int> bytes) async {
    MapSound.validate(bytes);
    await stopPreview();
    final root = await Directory.systemTemp.createTemp('map_sound_preview_');
    _previewDirectory = root;
    final file = File('${root.path}${Platform.pathSeparator}preview.wav');
    await file.writeAsBytes(bytes, flush: true);
    try {
      final process = await Process.start(
        'powershell.exe',
        [
          '-NoLogo',
          '-NoProfile',
          '-NonInteractive',
          '-WindowStyle',
          'Hidden',
          '-Command',
          r'$ErrorActionPreference="Stop"; $player=New-Object System.Media.SoundPlayer($env:MAP_EDITOR_PREVIEW_WAV); try { $player.Load(); $player.PlaySync() } finally { $player.Dispose() }',
        ],
        environment: {'MAP_EDITOR_PREVIEW_WAV': file.path},
        runInShell: false,
      );
      _preview = process;
      unawaited(process.stdout.drain<void>());
      unawaited(process.stderr.drain<void>());
      unawaited(
        process.exitCode.then((_) async {
          if (identical(_preview, process)) await stopPreview();
        }),
      );
    } catch (_) {
      await stopPreview();
      rethrow;
    }
  }

  @override
  Future<void> stopPreview() async {
    final process = _preview, directory = _previewDirectory;
    _preview = null;
    _previewDirectory = null;
    if (process != null) {
      process.kill();
      await process.exitCode;
    }
    if (directory != null && await directory.exists()) {
      await directory.delete(recursive: true);
    }
  }
}
