import 'package:flutter/material.dart';
import '../../application/placement/placement_catalog_controller.dart';
import '../../domain/eud/eud_dat_snapshot.dart';
import '../../domain/eud/eud_dat_layout.dart';
import '../../domain/chk/typed/chk_settings_defaults.dart';
import '../localization/l10n.dart';

typedef SettingsDefaultRow = ({String label, String? stored, String? baseline});

String? checkedSettingsPreview(
  String? text,
  int Function(String) parse, {
  String Function(int)? display,
}) {
  if (text == null) return null;
  try {
    final value = parse(text);
    return display == null ? '$value' : display(value);
  } on FormatException {
    return null;
  } on RangeError {
    return null;
  }
}

/// Loading is explicit and never writes default numbers back into the map.
class SettingsDefaultsPanel extends StatefulWidget {
  const SettingsDefaultsPanel({
    required this.controller,
    required this.mode,
    required this.rows,
    super.key,
  });
  final PlacementCatalogController? controller;
  final int? mode;
  final List<SettingsDefaultRow> Function(EudDatSnapshot?) rows;
  @override
  State<SettingsDefaultsPanel> createState() => _SettingsDefaultsPanelState();
}

class _SettingsDefaultsPanelState extends State<SettingsDefaultsPanel> {
  bool _loading = false;
  String? _error;
  @override
  Widget build(BuildContext context) => StreamBuilder<PlacementCatalogState>(
    stream: widget.controller?.changes,
    builder: (context, _) => _content(context),
  );

  Widget _content(BuildContext context) {
    final l10n = context.l10n, source = widget.controller?.eudData;
    final rows = widget.rows(source?.snapshot);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Expanded(child: Text(l10n.settingsDatDefaults)),
            TextButton.icon(
              key: const Key('settings-load-defaults'),
              onPressed: _loading || widget.controller == null
                  ? null
                  : () async {
                      setState(() {
                        _loading = true;
                        _error = null;
                      });
                      try {
                        await widget.controller!.loadEudData();
                      } catch (e) {
                        if (mounted) setState(() => _error = e.toString());
                      } finally {
                        if (mounted) setState(() => _loading = false);
                      }
                    },
              icon: const Icon(Icons.refresh, size: 18),
              label: Text(l10n.settingsDatLoad),
            ),
          ],
        ),
        if (source != null)
          SelectableText(
            '${source.label}\n${EudDatLayout.revision}\n${source.hashes.entries.map((e) => '${e.key}: ${e.value}').join('\n')}',
          ),
        if (_loading) const LinearProgressIndicator(),
        if (_error != null) Text(_error!),
        Text(
          widget.mode == 0
              ? l10n.settingsMapOverride
              : widget.mode == 1
              ? l10n.settingsDefaultInherited
              : l10n.settingsValueUnavailable,
        ),
        Table(
          columnWidths: const {
            0: FlexColumnWidth(2),
            1: FlexColumnWidth(),
            2: FlexColumnWidth(),
          },
          children: [
            TableRow(
              children: [
                const SizedBox(),
                Text(l10n.settingsDatDefaults),
                Text(l10n.settingsExpectedValue),
              ],
            ),
            for (final row in rows)
              TableRow(
                children: [
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 4),
                    child: Text(row.label),
                  ),
                  Text(row.baseline ?? l10n.settingsValueUnavailable),
                  Text(
                    ChkSettingsDefaults.expected(
                          mode: widget.mode,
                          stored: row.stored,
                          baseline: row.baseline,
                        ) ??
                        l10n.settingsValueUnavailable,
                  ),
                ],
              ),
          ],
        ),
        Text(l10n.settingsNoRuntimePreview),
      ],
    );
  }
}
