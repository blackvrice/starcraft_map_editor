/// Classic DAT ResourceDepot/ResourceContainer flags, not runtime EUD state.
final class UnitResourceProfile {
  const UnitResourceProfile({required this.isDepot, required this.isResource});

  static const version = 1;
  final bool isDepot;
  final bool isResource;
}
