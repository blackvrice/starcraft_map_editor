import 'package:flutter/material.dart';
import '../../application/eud/eud_build_preparation_controller.dart';

class EudBuildPreparationDialog extends StatefulWidget {
  const EudBuildPreparationDialog({
    required this.controller,
    this.baseMap = '',
    this.entrySource = '',
    super.key,
  });
  final EudBuildPreparationController controller;
  final String baseMap;
  final String entrySource;
  @override
  State<EudBuildPreparationDialog> createState() =>
      _EudBuildPreparationDialogState();
}

class _EudBuildPreparationDialogState extends State<EudBuildPreparationDialog> {
  late final List<TextEditingController> _fields;
  bool _busy = false;
  bool _trusted = false;
  String? _message;
  @override
  void initState() {
    super.initState();
    final previous = widget.controller.builds.state.plan?.configuration;
    _fields = [
      widget.baseMap.isEmpty ? previous?.baseMapPath ?? '' : widget.baseMap,
      previous?.sourceRootPath ?? '',
      widget.entrySource.isEmpty
          ? previous?.entrySourcePath ?? ''
          : widget.entrySource,
      previous?.outputMapPath ?? '',
      previous?.compilerPathOverride ?? '',
    ].map((s) => TextEditingController(text: s)).toList();
  }

  @override
  void dispose() {
    widget.controller.cancel();
    for (final field in _fields) {
      field.dispose();
    }
    super.dispose();
  }

  Future<void> _prepare() async {
    setState(() {
      _busy = true;
      _message = null;
    });
    final error = await widget.controller.prepare(
      baseMap: _fields[0].text,
      sourceRoot: _fields[1].text,
      entrySource: _fields[2].text,
      outputMap: _fields[3].text,
      projectToolPath: _fields[4].text,
      trustSource: _trusted,
    );
    if (!mounted) return;
    setState(() {
      _busy = false;
      _message = error;
    });
    if (error == null) Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: const Text('Prepare EUD Build'),
    content: SizedBox(
      width: 640,
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text(
              'Build saved files on disk. Save map and source edits first. Output must be a new .scx outside the source folder.',
            ),
            for (var i = 0; i < _fields.length; i++)
              Padding(
                padding: const EdgeInsets.only(top: 12),
                child: TextField(
                  controller: _fields[i],
                  enabled: !_busy,
                  decoration: InputDecoration(
                    labelText: const [
                      'Base map path',
                      'Source folder path',
                      'Entry .eps path',
                      'New output .scx path',
                      'Tool override for this build (optional)',
                    ][i],
                  ),
                ),
              ),
            const Text(
              'Blank tool override uses your EUD Tools selection. Prepare checks files; Build runs the compiler separately.',
            ),
            CheckboxListTile(
              value: _trusted,
              onChanged: _busy
                  ? null
                  : (v) => setState(() => _trusted = v ?? false),
              title: const Text(
                'I trust this source and its imports to run code on this computer.',
              ),
            ),
            if (_busy) const LinearProgressIndicator(),
            if (_message != null) SelectableText(_message!),
          ],
        ),
      ),
    ),
    actions: [
      TextButton(
        onPressed: () => Navigator.of(context).pop(),
        child: const Text('Cancel'),
      ),
      FilledButton(
        onPressed: _busy || !_trusted ? null : _prepare,
        child: const Text('Prepare'),
      ),
    ],
  );
}
