# CV5 크립 후보 플래그 자료

2026-10-15. FR-218/219, EP1의 읽기 전용 정적 자료 단위다.
[출처 조사](research/INITIAL_CREEP_SOURCE_FEASIBILITY.md)와
[ADR-0016](decisions/0016-creep-source-boundaries.md)의 후속이다.
**실제 initialMap/live 크립 수집·coverage·UI·배치 차단 구현이 아니다.**

## 1. 실행 계획과 소스 분석

1. 기존 CV5/VF4 snapshot과 프로세스·출처·revision 경계를 확인한다.
2. 고정 primary source와 기존 CV5 decoder의 flags word를 대조한다.
3. 선택적 version1 숫자 profile을 같은 읽기 경로에 추가한다.
4. 누락/잘못된 자료·비트 독립성·기존 배치/실제 상태 경계 회귀를 작성한다.
5. native 합성·가짜 프로세스·실제 로컬8타일셋·전체 게이트를 실행하고 기록한다.

근거는 Chkdraft commit `32d27861b16dda0b0f3d95e34bad894ea4efb2c3`의
[TileGroup flags](https://github.com/TheNitesWhoSay/Chkdraft/blob/32d27861b16dda0b0f3d95e34bad894ea4efb2c3/src/mapping_core/sc.h#L2876-L2896)다.
52byte CV5 그룹의 offset2 u16에서 bit6/12/14를 각각 유지한다.
참고 소스의 이름은 Creep/RecedingCreep/TemporaryCreep이지만 이 응답은
`flags & 0x5040`이라는 **정적 숫자 투영**만 제공한다. 두다드 등 그룹 header의
맥락이나 생성/확장·실제 관찰을 확인하지 않고 `hasCreep`으로 합치지 않는다.
raw MTXM의 group/member 해석이나 고위 비트·원본 CHK bytes도 바꾸지 않는다.

## 2. 구현·호환 계약

`readTerrainPlacement` protocol3/helper0.13.0/snapshotVersion1에 additive 필드를
추가했다. 기존 helperVersion은 유지하고 **필드 존재와 profile.version으로 지원을
확인**한다. 이전 0.13.0 응답에 이 필드가 없더라도 건설/이동 자료는 계속 유효하다.
모든 0.13.0 바이너리가 이 기능을 제공한다고 간주하지 않는다.

```json
"creepCandidateProfile": {
  "version": 1,
  "groupFlags": [0, 64, 4096, 4160, 16384, 16448, 20480, 20544]
}
```

예시 숫자는 합성값이다. 배열은 CV5 **그룹 순서**이며 MTXM grid나 megatile 배열이 아니다.

| 항목 | 계약 |
| --- | --- |
| optional | missing/null은 profile 미확인. 0 배열을 만들지 않음 |
| 버전 | 정확한 int1만 허용. 미래 버전/부동소수/누락은 전체 응답 거절 |
| 배열 | int만, CV5 byteLength/52와 정확히 같은 1~4096개 |
| 값 | u16 범위와 `(value & ~0x5040)==0` 모두 검사. 다른 비트는 자동 마스킹하지 않음 |
| 0 | 해당 CV5 bits가 꺼졌다는 뜻. 맵 크립 부재가 아님 |
| domain | 불변 `Cv5CreepCandidateProfile`, `TerrainPlacementSnapshot.creepCandidateProfile` |
| 조회 | `flagsForGroup(group)`은 group index, 범위 밖 null. VF4 renderability와 별개 |
| 부모 결합 | profile 그룹 수와 snapshot 그룹 수가 다르면 생성 거절 |
| 출처 | 기존 부모의 tileset·helper/CascLib·product/build·CV5/VF4 path/bytes/SHA-256 공유 |
| revision | profile version/모든 flags를 canonical identity에 포함. missing/null은 기존 identity 유지 |
| 기존 판정 | `tile()`·footprint·지형 정책은 변화 없음. 미지 VF4 참조를 profile로 보완하지 않음 |
| 실제 상태 | collector가 없으면 initialMap/live는 계속 unavailable. profile을 coverage로 전달하지 않음 |
| I/O | 같은 CASC CV5/VF4만 읽음. UI/Domain의 FS/FFI/프로세스 의존 추가 없음 |

hash는 로컬 helper가 제공하는 provenance이며 외부 서명/독립 진위 증명은 아니다.
출처 없는 단독 profile을 실제 크립 상태로 재사용하지 않는다. 원시 게임 자산·이미지·맵
파일·외부 엔진 코드는 fixture나 배포물에 추가하지 않았다.

## 3. 요구사항·테스트 체크리스트

| 요구/시나리오 | 검사 |
| --- | --- |
| bit6/12/14의 독립 조합8종·다른 비트 분리 | domain/decoder/native 합성 |
| 최대4096그룹·마지막 값·범위 밖 unknown | domain/native/가짜 프로세스 |
| 기존 helper missing/null과 0의 구분 | decoder·가짜 프로세스·revision |
| 잘못된 profile 형식/버전/coverage/값 | decoder18종·가짜 프로세스 마지막 그룹 오류 |
| 입력 변경/반환 리스트 변경·immutable | domain/decoder/native 원본 불변 |
| source SHA·값 변경과 transport 위치 독립 | decoder revision·로컬 반복 조회 |
| 기존 VF4 missing ref/raw index 규칙 | domain의 미지 자료 유지·전체 기존 지형 회귀 |
| 정적 flags로 실제 크립 성공/부재 추정 금지 | controller8종·CHK bytes/session/선택/history 무변경 |
| 실제 로컬8타일셋 모든 그룹 | 기존 연결 snapshot의 CV5 SHA·flags word와 투영값 대조 |
| 큰 응답 제한 | 최대 profile 포함 JSON, 기존256KiB 초과/2MiB capture·오류 경계 유지 |
| 실제 SC:R coverage 일치·외부 에디터 | 미실행, 별도 인수 |

## 4. 최적화·주석

이미 읽는 CV5 flags word를 한 번만 읽어 buildability와 후보 비트를 함께 투영한다.
추가 자산/bitmap/프로세스/파일 I/O 없이 최대4096개 숫자만 추가하며 O(CV5 groups)다.
기존 request/source 수명과 2MiB capture를 재사용한다. 실제 FPS/메모리 개선을
측정한 것은 아니다. 정적 bit와 실제 coverage·group index·missing/0·legacy revision의
차이에 필요한 짧은 주석만 추가했다.

## 5. 실행·결과 분석

ignored `.dart_tool/cv5_creep_*.log`에 원시 실행 로그를 남긴다.
실행 SDK Flutter3.47.5 stable/Dart3.13.4이며 기준3.44.8/3.12와 다르다.

| 실행 | 결과 |
| --- | --- |
| 집중 domain/decoder/process/controller·기존 지형 | 424통과·10skip·exit0, skip은 기존 로컬 설치 선택 테스트 |
| 로컬 설치+새 helper의8타일셋/controller | 316통과·skip 없음·exit0 |
| 전체 그룹 수 일치 assert 추가 후8타일셋 재실행 | 1통과·skip 없음·exit0, 총14,886그룹 대조 |
| `flutter analyze` | No issues·exit0 |
| 전체 `flutter test` | 1,919통과·59skip·exit0, 새50개 포함 |
| 변경 Dart8파일 format | 0변경·exit0 |
| 전체 format | 477파일 중 기존3파일 차이·exit1 |
| Windows Debug build | 성공·exit0, 기존 CascLib CMake deprecation 경고는 비치명적 |
| native CTest | 7/7통과·exit0 |
| `git diff --check` | 통과 |

전체 format 차이는 기존 `test/infrastructure/local_map_save_file_gateway_test.dart`,
`process_eud_compiler_gateway_test.dart`, `process_map_archive_gateway_test.dart`이며
이번 범위에서 수정하지 않았다. 기준 SDK/전체 format/실제 게임 인수는 남는다.
문서 patch의 마지막 context 오타는 적용 전에 거절되어 올바른 context로 다시 적용했다.
소스/테스트 결함으로 수정한 내역은 없었다. 59skip을 통과로 계산하지 않는다.
사용자 지시에 따라 자동 테스트·빌드·로컬 자료 읽기만 진행했고 실제 앱·게임·외부
에디터를 조작하지 않았다. 원본 맵·unknown CHK·기존 사용자 변경은 보존했다.

로컬 `s1` build13515에서 같은 helper를 직접 읽기 전용 호출해 집계한 **그룹 header
비트 수**는 다음과 같다. bit14가 있는 install/ice/twilight나 bit6이 없는 install을
실제 크립 유무/호환성 판정으로 승격하지 않는다. 두다드 등 header 맥락은 미해석이다.

| 타일셋 | 그룹 | bit6 on | bit12 on | bit14 on | 응답 UTF-8 bytes |
| --- | ---: | ---: | ---: | ---: | ---: |
| badlands | 1979 | 1 | 169 | 0 | 130125 |
| platform | 2046 | 1 | 109 | 0 | 132866 |
| install | 1265 | 0 | 18 | 19 | 64988 |
| ashworld | 1418 | 1 | 64 | 0 | 89506 |
| jungle | 2046 | 1 | 134 | 0 | 138528 |
| desert | 2046 | 1 | 68 | 0 | 152375 |
| ice | 2039 | 1 | 56 | 3 | 140080 |
| twilight | 2047 | 1 | 42 | 4 | 150130 |

응답 크기는 실제 설치 자료의 관찰값이며 최악 응답 상한이나 성능 보증이 아니다.
최대4096그룹/65536mask는 별도 가짜 프로세스로 검증했다. 직접 집계의 첫 제한 환경
호출은 `SC_CASC_STORAGE_OPEN_FAILED`로 실패했고 동일 명령의 권한 확장 재실행은
8종 모두 성공했다. 환경 경계 차이로 기록하며 실제 게임 실행 오류로 계산하지 않는다.

## 6. 완료 범위와 다음

완료 대상은 출처가 묶인 **정적 후보 숫자 자료의 조회·검증**이다.
생성/확장 시뮬레이션·설계 coverage·actual collector·배치 차단·새 UI는 포함하지 않는다.
다음 단계는 실제 초기/live collector의 관찰 phase/frame·권한·지원 버전을 확정하고,
현재 unavailable 계약과 구분된 자료를 검증하는 것이다. 별도 게임/외부 인수 없이
정상 크립 정책이나 전체 EP1 완료로 표시하지 않는다.
