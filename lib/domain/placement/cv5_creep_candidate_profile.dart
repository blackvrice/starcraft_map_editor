/// Static CV5 group metadata only, never observed map/runtime creep coverage.
/// Bit numbers are retained independently; group headers are not tile state.
final class Cv5CreepCandidateProfile {
  Cv5CreepCandidateProfile({required List<int> groupFlags})
    : groupFlags = List.unmodifiable(groupFlags) {
    if (this.groupFlags.isEmpty ||
        this.groupFlags.length > 4096 ||
        this.groupFlags.any((flags) => flags < 0 || (flags & ~mask) != 0)) {
      throw ArgumentError('Invalid CV5 creep candidate flags.');
    }
  }

  static const version = 1;
  static const bit6 = 0x0040;
  static const bit12 = 0x1000;
  static const bit14 = 0x4000;
  static const mask = bit6 | bit12 | bit14;

  /// Zero means these source bits are off, not that a map tile has no creep.
  final List<int> groupFlags;

  /// Group index, not raw MTXM or megatile ID. Missing groups stay unknown.
  int? flagsForGroup(int group) =>
      group < 0 || group >= groupFlags.length ? null : groupFlags[group];
}
