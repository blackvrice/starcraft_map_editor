import 'package:flutter/services.dart';

import '../../application/ports/map_file_picker.dart';

class MethodChannelMapFilePicker implements MapFilePicker {
  const MethodChannelMapFilePicker({
    this.channel = const MethodChannel(channelName),
  });

  static const channelName = 'starcraft_map_editor/file_dialog';
  static const openMapMethod = 'openMap';

  final MethodChannel channel;

  @override
  Future<String?> pickMapPath() {
    return channel.invokeMethod<String>(openMapMethod);
  }
}
