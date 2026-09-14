import 'package:flutter/services.dart';
import '../../application/ports/eud_project_picker.dart';

final class MethodChannelEudProjectPicker implements EudProjectPicker {
  const MethodChannelEudProjectPicker();
  static const channel = MethodChannel('starcraft_map_editor/file_dialog');
  @override
  Future<String?> openProject() =>
      channel.invokeMethod<String>('openEudProject');
  @override
  Future<String?> saveProjectAs() => channel.invokeMethod<String>(
    'saveEudProject',
    {'suggestedName': 'settings.eud.json'},
  );
}
