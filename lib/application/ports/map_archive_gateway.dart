import 'map_archive_models.dart';

export 'map_archive_models.dart';

abstract interface class MapArchiveGateway {
  Future<MapArchiveOpenResult> open(MapArchiveOpenRequest request);

  Future<MapArchiveWriteResult> writeTemporary(MapArchiveWriteRequest request);

  Future<bool> cancel(String operationId);
}
