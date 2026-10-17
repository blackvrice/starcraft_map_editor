import 'dart:typed_data';
import 'chk_basic_editing.dart';
import 'chk_document_transfer.dart';
import 'chk_mixed_clipboard.dart';
import 'raw_chk_document.dart';

final class ChkMixedDocumentTransferPlan {
  ChkMixedDocumentTransferPlan._(
    this.target,
    this.result,
    this.clipboard,
    this.references,
    Map<int, int> units,
  ) : units = Map.unmodifiable(units);
  final RawChkDocument target, result;
  final ChkMixedClipboard clipboard;
  final ChkDocumentTransferPlan? references;
  final Map<int, int> units;

  static ChkMixedDocumentTransferPlan preview(
    ChkMixedClipboard clipboard,
    RawChkDocument target, {
    required int x,
    required int y,
  }) {
    final locations = clipboard.selected['MRGN'] ?? <int>{};
    final references = locations.isEmpty
        ? null
        : ChkDocumentTransfer.capture(
            clipboard.source,
            selected: {'MRGN': locations},
          ).preview(
            target,
            offsetX: (x - clipboard.region.left) * 32,
            offsetY: (y - clipboard.region.top) * 32,
          );
    // References allocate locations first. The mixed engine then owns terrain,
    // complete Doodad overlays and connected UNITs, without duplicating MRGN.
    final result = clipboard.paste(
      references?.result ?? target,
      x: x,
      y: y,
      locationStrings: references?.strings ?? const {},
      includeLocations: false,
    );
    final units = <int, int>{},
        copied = clipboard.objects?.records['UNIT'] ?? <List<int>>[];
    if (copied.isNotEmpty) {
      final bytes = const ChkBasicEditing()
          .section(result, 'UNIT', stride: 36)!
          .payload;
      for (var i = 0; i < copied.length; i++) {
        final old = ByteData.sublistView(
          Uint8List.fromList(copied[i]),
        ).getUint32(0, Endian.little);
        if (old != 0) {
          units[old] = ByteData.sublistView(bytes).getUint32(
            bytes.length - copied.length * 36 + i * 36,
            Endian.little,
          );
        }
      }
    }
    return ChkMixedDocumentTransferPlan._(
      target,
      result,
      clipboard,
      references,
      units,
    );
  }
}
