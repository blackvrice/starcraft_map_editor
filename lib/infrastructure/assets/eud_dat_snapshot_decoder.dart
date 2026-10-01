import '../../domain/eud/eud_dat_layout.dart';
import '../../domain/eud/eud_dat_snapshot.dart';
import '../../application/ports/eud_dat_gateway.dart';
import 'starcraft_data_helper_protocol.dart';

EudDatSource decodeEudDat(
  Map<String, dynamic> json,
  String requestId,
  String path,
) {
  Never invalid() => throw const FormatException('Invalid EUD DAT response.');
  if (json['protocolVersion'] != StarCraftDataHelperProtocol.version ||
      json['requestId'] != requestId ||
      json['operation'] != 'readEudDat' ||
      json['status'] != 'success' ||
      json['snapshotVersion'] != 1 ||
      json['revision'] != EudDatLayout.revision ||
      json['helperVersion'] is! String ||
      (json['helperVersion'] as String).isEmpty ||
      json['cascLibRevision'] != '4971d363e665551ac4142f541e5f2d71f1cda653') {
    invalid();
  }
  final installation = json['installation'];
  if (installation is! Map ||
      installation['path'] != path ||
      installation['storageProduct'] is! String ||
      (installation['storageProduct'] as String).isEmpty ||
      installation['storageBuildNumber'] is! int ||
      installation['storageBuildNumber'] <= 0) {
    invalid();
  }
  final hashes = <String, String>{};
  final assets = json['assets'];
  if (assets is! List || assets.length != EudDatLayout.assets.length) invalid();
  for (final item in assets) {
    if (item is! Map ||
        item['path'] is! String ||
        !EudDatLayout.assets.containsKey(item['path']) ||
        item['bytes'] != EudDatLayout.assets[item['path']] ||
        hashes.containsKey(item['path']) ||
        item['sha256'] is! String ||
        !RegExp(r'^[a-f0-9]{64}$').hasMatch(item['sha256'])) {
      invalid();
    }
    hashes[item['path']] = item['sha256'];
  }
  final columns = json['columns'];
  if (columns is! Map || columns.length != EudDatLayout.counts.length) {
    invalid();
  }
  final values = <String, List<int>>{};
  for (final column in EudDatLayout.counts.entries) {
    final data = columns[column.key];
    if (data is! List ||
        data.length != column.value ||
        data.any((v) => v is! int)) {
      invalid();
    }
    values[column.key] = data.cast<int>();
  }
  return EudDatSource(
    snapshot: EudDatSnapshot(values),
    helperVersion: json['helperVersion'],
    product: installation['storageProduct'],
    build: installation['storageBuildNumber'],
    hashes: hashes,
  );
}
