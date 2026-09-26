import 'dart:typed_data';
import 'package:flutter_test/flutter_test.dart';
import 'package:starcraft_map_editor/domain/chk/chk.dart';
import 'package:starcraft_map_editor/domain/eud/eud_effective_settings.dart';
import 'package:starcraft_map_editor/domain/eud/eud_project.dart';

RawChkDocument _map({
  int flag = 0,
  bool expanded = true,
  bool duplicate = false,
  bool malformed = false,
}) {
  RawChkSection section(String name, List<int> bytes) => RawChkSection(
    nameBytes: name.codeUnits,
    declaredLength: bytes.length,
    payload: bytes,
    sourceOffset: 0,
  );
  final bytes = Uint8List(expanded ? 4168 : 4048);
  bytes[0] = flag;
  ByteData.sublistView(bytes).setUint16(1140, 77, Endian.little);
  final settings = section(expanded ? 'UNIx' : 'UNIS', malformed ? [0] : bytes);
  return RawChkDocument(
    sourceLength: 0,
    sections: [
      section('VER ', [expanded ? 206 : 63, 0]),
      settings,
      if (duplicate) settings,
      section(expanded ? 'UNIS' : 'UNIx', [255]),
    ],
  );
}

EudProject _project({bool explicit = true, List<EudOverride>? overrides}) =>
    EudProject(
      mapPath: 'test.scx',
      mapSha256: 'a' * 64,
      overrides:
          overrides ??
          [
            EudOverride(
              field: 'unit.maxShield',
              targetId: 0,
              value: 100,
              overrideChk: explicit,
            ),
          ],
    );

void main() {
  test(
    'upgrade and technology baselines honor CHK defaults and malformed data',
    () {
      for (final (key, section, length, count) in [
        ('upgrade.mineralCostBase', 'UPGx', 794, 62),
        ('tech.mineralCost', 'TECx', 396, 44),
      ]) {
        for (final flag in [0, 1, 2]) {
          final bytes = Uint8List(length)..[0] = flag;
          ByteData.sublistView(bytes).setUint16(count, 123, Endian.little);
          final doc = RawChkDocument(
            sourceLength: 0,
            sections: [
              ..._map().sections,
              RawChkSection(
                nameBytes: section.codeUnits,
                declaredLength: length,
                payload: bytes,
                sourceOffset: 0,
              ),
            ],
          );
          final result = EudEffectiveSettings.resolve(
            _project(
              overrides: [
                EudOverride(
                  field: key,
                  targetId: 0,
                  value: 456,
                  overrideChk: true,
                ),
              ],
            ),
            verifiedDocument: doc,
          ).single;
          expect(
            result.baselineSource,
            flag == 0
                ? EudBaselineSource.chk
                : flag == 1
                ? EudBaselineSource.gameDefault
                : EudBaselineSource.unavailable,
          );
          expect(result.baselineValue, flag == 0 ? 123 : null);
          expect(result.plannedValue, flag == 2 ? null : 456);
        }
      }
      for (final key in ['upgrade.maxLevel', 'tech.energyCost']) {
        final result = EudEffectiveSettings.resolve(
          _project(
            overrides: [
              EudOverride(field: key, targetId: 0, value: 1, overrideChk: true),
            ],
          ),
          verifiedDocument: _map(),
        ).single;
        expect(result.baselineSource, EudBaselineSource.unavailable);
        expect(result.plannedValue, isNull);
      }
    },
  );
  test(
    'selects active CHK version, preserves baseline and explicit EUD intent',
    () {
      for (final expanded in [false, true]) {
        final doc = _map(expanded: expanded);
        final result = EudEffectiveSettings.resolve(
          _project(),
          verifiedDocument: doc,
        ).single;
        expect(result.baselineSource, EudBaselineSource.chk);
        expect(result.baselineValue, 77);
        expect(result.baselineDetail, contains(expanded ? 'UNIx' : 'UNIS'));
        expect(result.plannedValue, 100);
        expect(doc.isDirty, isFalse);
      }
    },
  );
  test('default flag never exposes ignored shield bytes as a baseline', () {
    final result = EudEffectiveSettings.resolve(
      _project(),
      verifiedDocument: _map(flag: 1),
    ).single;
    expect(result.baselineSource, EudBaselineSource.gameDefault);
    expect(result.baselineValue, isNull);
    expect(result.plannedValue, 100);
  });
  test('unknown flags, duplicate and malformed sections remain unresolved', () {
    for (final doc in [
      _map(flag: 2),
      _map(duplicate: true),
      _map(malformed: true),
    ]) {
      final result = EudEffectiveSettings.resolve(
        _project(),
        verifiedDocument: doc,
      ).single;
      expect(result.baselineSource, EudBaselineSource.unavailable);
      expect(result.plannedValue, isNull);
    }
    expect(
      EudEffectiveSettings.resolve(_project()).single.baselineSource,
      EudBaselineSource.unverifiedMap,
    );
  });
  test(
    'missing explicit override and cross-field conflict block planned values',
    () {
      final result = EudEffectiveSettings.resolve(
        _project(explicit: false),
        verifiedDocument: _map(),
      ).single;
      expect(result.baselineValue, 77);
      expect(result.plannedValue, isNull);
      final conflict = _project(
        overrides: [
          EudOverride(field: 'weapon.minRange', targetId: 0, value: 100),
          EudOverride(field: 'weapon.maxRange', targetId: 0, value: 50),
        ],
      );
      expect(
        EudEffectiveSettings.resolve(
          conflict,
          verifiedDocument: _map(),
        ).every((s) => s.plannedValue == null),
        isTrue,
      );
      expect(
        () => _project(
          overrides: [conflict.overrides.first, conflict.overrides.first],
        ),
        throwsFormatException,
      );
    },
  );
  test('non CHK fields and unknown imported fields keep distinct sources', () {
    final known = _project(
      overrides: [
        EudOverride(field: 'unit.hasShield', targetId: 0, value: false),
      ],
    );
    final result = EudEffectiveSettings.resolve(
      known,
      verifiedDocument: _map(),
    ).single;
    expect(result.baselineSource, EudBaselineSource.notInChk);
    expect(result.plannedValue, false);
    final unknown = _project(
      overrides: [EudOverride(field: 'unit.future', targetId: 65535, value: 5)],
    );
    expect(
      EudEffectiveSettings.resolve(
        unknown,
        verifiedDocument: _map(),
      ).single.plannedValue,
      isNull,
    );
    expect(unknown.overrides.single.value, 5);
  });
}
