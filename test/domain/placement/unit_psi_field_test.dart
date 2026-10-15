import 'package:flutter_test/flutter_test.dart';
import 'package:starcraft_map_editor/domain/placement/unit_psi_field.dart';

void main() {
  test(
    'every nearby pixel matches all 160 cells and strict outer boundaries',
    () {
      const cells = [
        '0000011111100000',
        '0011111111111100',
        '0111111111111110',
        '1111111111111111',
        '1111111111111111',
        '1111111111111111',
        '1111111111111111',
        '0111111111111110',
        '0011111111111100',
        '0000011111100000',
      ];
      var covered = 0;
      for (var dy = -161; dy <= 161; dy++) {
        for (var dx = -257; dx <= 257; dx++) {
          final expected =
              dx.abs() < 256 &&
              dy.abs() < 160 &&
              cells[(dy + 160) ~/ 32][(dx + 256) ~/ 32] == '1';
          final result = UnitPsiField.containsPoint(
            x: 1024 + dx,
            y: 1024 + dy,
            providerX: 1024,
            providerY: 1024,
          );
          if (result != expected) fail('Mask mismatch dx=$dx dy=$dy');
          if (result) covered++;
        }
      }
      expect(covered, 130752);
    },
  );
  test(
    'translation and off-lattice centers preserve relative mask coordinates',
    () {
      for (final origin in [300, 517, 2000]) {
        expect(
          UnitPsiField.containsPoint(
            x: origin + 95,
            y: origin - 159,
            providerX: origin,
            providerY: origin,
          ),
          isTrue,
        );
        expect(
          UnitPsiField.containsPoint(
            x: origin + 96,
            y: origin - 159,
            providerX: origin,
            providerY: origin,
          ),
          isFalse,
        );
      }
    },
  );
  test('invalid absolute coordinates cannot overflow into a covered point', () {
    for (final value in [-1, 65536, 0x7fffffffffffffff, -0x8000000000000000]) {
      expect(
        UnitPsiField.containsPoint(
          x: value,
          y: 64,
          providerX: 64,
          providerY: 64,
        ),
        isFalse,
      );
      expect(
        UnitPsiField.containsPoint(
          x: 64,
          y: value,
          providerX: 64,
          providerY: 64,
        ),
        isFalse,
      );
      expect(
        UnitPsiField.containsPoint(
          x: 64,
          y: 64,
          providerX: value,
          providerY: 64,
        ),
        isFalse,
      );
      expect(
        UnitPsiField.containsPoint(
          x: 64,
          y: 64,
          providerX: 64,
          providerY: value,
        ),
        isFalse,
      );
    }
  });
}
