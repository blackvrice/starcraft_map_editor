import 'package:flutter/services.dart';

import '../../application/ports/directory_picker.dart';
import 'method_channel_map_file_picker.dart';

final class MethodChannelDirectoryPicker implements DirectoryPicker {
  const MethodChannelDirectoryPicker({
    this.channel = const MethodChannel(MethodChannelMapFilePicker.channelName),
  });

  static const pickStarCraftDataDirectoryMethod = 'pickStarCraftDataDirectory';

  final MethodChannel channel;

  @override
  Future<String?> pickStarCraftDataDirectory() {
    return channel.invokeMethod<String>(pickStarCraftDataDirectoryMethod);
  }
}
