import 'package:flutter/services.dart';

import '../../application/ports/directory_picker.dart';
import 'method_channel_map_file_picker.dart';

final class MethodChannelDirectoryPicker implements DirectoryPicker {
  const MethodChannelDirectoryPicker({
    this.channel = const MethodChannel(MethodChannelMapFilePicker.channelName),
  });

  static const pickStarCraftInstallationDirectoryMethod =
      'pickStarCraftInstallationDirectory';

  final MethodChannel channel;

  @override
  Future<String?> pickStarCraftInstallationDirectory() {
    return channel.invokeMethod<String>(
      pickStarCraftInstallationDirectoryMethod,
    );
  }
}
