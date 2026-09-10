import 'package:flutter/material.dart';
import '../../application/editing/settings_id_selection.dart';

class SettingsSelection extends StatefulWidget {
  const SettingsSelection({
    required this.prefix,
    required this.selectorKey,
    required this.count,
    required this.selected,
    required this.label,
    required this.onSelected,
    this.onCopy,
    this.revision,
    this.searchText,
    this.idBase = 0,
    this.copyCount,
    this.includeMapDefault = false,
    required this.scope,
    super.key,
  });
  final String prefix;
  final Key selectorKey;
  final int count;
  final int selected;
  final String Function(int) label;
  final ValueChanged<int> onSelected;
  final int Function(Set<int>)? onCopy;
  final String scope;
  final Object? revision;
  final String Function(int)? searchText;
  final int idBase;
  final int? copyCount;
  final bool includeMapDefault;
  @override
  State<SettingsSelection> createState() => _SettingsSelectionState();
}

class _SettingsSelectionState extends State<SettingsSelection> {
  String _query = '';
  String _range = '';
  String? _message;
  bool _failed = false;
  @override
  void didUpdateWidget(covariant SettingsSelection oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.selected != widget.selected ||
        oldWidget.scope != widget.scope ||
        oldWidget.revision != widget.revision) {
      _message = null;
    }
  }

  void _copy() {
    try {
      final displayed = parseSettingsIds(
        _range,
        (widget.copyCount ?? widget.count) + widget.idBase,
        minimum: widget.idBase,
      );
      final ids = displayed.map((id) => id - widget.idBase).toSet();
      final fields = widget.onCopy!(ids);
      setState(() {
        _failed = false;
        _message = fields == 0
            ? 'No edited fields in the current selection.'
            : '$fields draft field copies prepared for ${ids.length} IDs. Review, then Apply.';
      });
    } catch (e) {
      setState(() {
        _failed = true;
        _message = e.toString();
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final query = _query.trim().toLowerCase();
    final exact = query.startsWith('#')
        ? int.tryParse(query.substring(1))
        : null;
    final filtered = [
      if (widget.includeMapDefault &&
          (query.isEmpty || widget.label(-1).toLowerCase().contains(query)))
        -1,
      for (var id = 0; id < widget.count; id++)
        if (query.isEmpty ||
            (exact != null
                ? id + widget.idBase == exact
                : '${widget.label(id)} ${widget.searchText?.call(id) ?? ""}'
                      .toLowerCase()
                      .contains(query)))
          id,
    ];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        TextField(
          key: Key('${widget.prefix}-search'),
          decoration: const InputDecoration(
            labelText: 'Search name or ID (#12 for exact ID)',
          ),
          onChanged: (v) => setState(() => _query = v),
        ),
        DropdownButton<int>(
          key: widget.selectorKey,
          isExpanded: true,
          value: filtered.contains(widget.selected) ? widget.selected : null,
          hint: Text('Current: ${widget.label(widget.selected)}'),
          items: [
            for (final id in filtered)
              DropdownMenuItem(
                value: id,
                child: Text(widget.label(id), overflow: TextOverflow.ellipsis),
              ),
          ],
          onChanged: filtered.isEmpty ? null : (v) => widget.onSelected(v!),
        ),
        if (filtered.isEmpty)
          const Text(
            'No matching IDs. Current selection and drafts are unchanged.',
          ),
        ExpansionTile(
          key: Key('${widget.prefix}-bulk'),
          title: const Text('Copy edited fields to IDs'),
          tilePadding: EdgeInsets.zero,
          children: [
            Text('Source: ${widget.label(widget.selected)}. ${widget.scope}'),
            const Text(
              'Copies only edited fields, replacing those draft fields at the target IDs. Search does not select targets. The map changes only after Apply.',
            ),
            TextField(
              key: Key('${widget.prefix}-range'),
              decoration: InputDecoration(
                labelText:
                    'Target IDs (${widget.idBase}–${(widget.copyCount ?? widget.count) - 1 + widget.idBase})',
                hintText: widget.idBase == 0 ? '0, 2-5' : '1, 3-5',
              ),
              onChanged: (v) => setState(() {
                _range = v;
                _message = null;
              }),
            ),
            TextButton(
              key: Key('${widget.prefix}-copy'),
              onPressed: widget.onCopy == null ? null : _copy,
              child: const Text('Prepare draft copies'),
            ),
            if (_message != null)
              Text(
                _message!,
                key: Key('${widget.prefix}-copy-result'),
                style: _failed
                    ? TextStyle(color: Theme.of(context).colorScheme.error)
                    : null,
              ),
          ],
        ),
      ],
    );
  }
}
