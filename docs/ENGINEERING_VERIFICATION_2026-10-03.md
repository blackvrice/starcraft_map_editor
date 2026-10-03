# 프로그램 요구사항·소스·실행 검증

## 실행 계획

사용자 지시(2026-10-03): 소스와 요구사항을 분석하고 프로그램을 실행해 오류를
검출한다. 이해하기 어려운 로직에는 필요한 주석을 추가하고 최적화 여부를 판단한다.
계획 → 실행 → 결과 → 분석을 이 문서에 순서대로 남긴다.

기준 커밋은 `b7228e8`, Windows 로컬 작업 트리다. 기존 사용자 변경은 보존하며
별도 Git 인덱스로 이번 검증/수정만 커밋한다. 로컬 결과는 미커밋 사용자 코드도
포함하므로 깨끗한 기준 커밋의 CI 결과와 동일하다고 간주하지 않는다.

1. 제품 FR/NFR 각각을 구현·테스트·실제 게임/배포 인수로 나눠 대조한다.
2. 데이터 손실 위험이 높은 CHK 파서, 저장/문서 교체, 복구, EUD 프로세스/안전 빌드,
   공통 Undo/Redo와 번역 경계를 집중 검토한다. 전체 파일의 행별 전수 감사는 아니다.
3. 발견한 결함을 테스트로 재현하고 범위를 좁혀 수정한다. 복잡한 안전성 판단은
   코드 주석으로 설명하며 성능 개선은 동작 보존과 측정 근거를 기준으로 판단한다.
4. format/analyze/전체 test, Windows debug 빌드·실행, native CTest를 실행한다.
5. 자체 제작 맵의 실제 MPQ 왕복과 복구, 검토된 동봉 euddraft, 로컬 SC:R 자산
   검사, 한국어 실제 Windows 렌더링과 성능 스모크를 실행한다.
6. 실패/skip/환경 차이와 해결 결과를 기록한다. 게임 실행·멀티플레이·외부 에디터·
   깨끗한 PC 배포와 profile FPS는 별도 인수로 남긴다. 무결함을 보증하지 않는다.

## 실행 일지

| 순서 | 행위 | 결과 / 분석 |
| --- | --- | --- |
| 1 | AGENTS, AI 가이드, 문서 인덱스, 개발 계획, 제품 요구사항, 아키텍처, 품질·기능 대조표 확인 | 데이터 보존과 원본 보호를 우선. 게임 관찰과 구현 완료를 분리 |
| 2 | Git 상태 확인 | 기존 설정/플랫폼/CHK 조사·문서 변경 및 staged local.properties 보존 대상 식별 |
| 3 | domain/application/presentation의 import·I/O·프로세스 경계 검색 | domain의 Flutter/IO/FFI, UI의 IO/프로세스 직접 사용을 이 검색 범위에서 발견하지 않음 |
| 4 | 파서·저장·문서 채택·복구·프로젝트/소스·Undo·번역 코드 검토 | 승격/최근 파일 기록 중 최신 편집 교체 가능성 발견 |
| 5 | 저장 회귀 테스트 4개 추가, 수정 전 실행 | 기존 24개 통과/새 4개 실패. 쓰기 단계 1개는 성공을 기대한 테스트가 잘못됨: 기존 코드가 이미 승격 전 변경을 차단. 실제 결함은 승격·최근 파일 기록·활성 브러시 3경로 |
| 6 | 문서 identity 재검사와 활성 transaction 저장 차단, en/ko 경고 추가 | 저장된 스냅샷과 현재 편집을 구분. 현재 문서·dirty·Undo 유지. 관련 테스트 31개 통과 |
| 7 | 중간 전체 테스트 | 949 통과/45 skip/1 실패: 명시적 문서 교체로 기존 브러시를 종료하는 테스트 계약과 새 guard 충돌. Save As가 expectedSession을 제공할 때 transaction guard를 적용하도록 수정 |
| 8 | 최적화 전 합성 1/16/64 MiB CHK 측정 | 64 MiB parse 122,945µs, encode 38,188µs. Open/Save의 parse가 동기 호출되어 큰 파일 UI 지연 위험 확인 |
| 9 | 모델 내부 사본을 유지하며 parser 임시 복사·Uint8List 범위 반복 검사 제거 | 64 MiB parse 21,596µs, encode 27,164µs. 3개 크기 byte-exact 검사 통과. offset view/입력 변경 격리 테스트 추가, 집중 테스트 49개 통과 |
| 10 | 정적 분석 재실행 | 측정 도구의 relative-lib-import/print 린트 3개를 package import/stdout으로 정정 |
| 11 | 포맷 게이트 승인 검토 | 자동 검토가 실제 파일 변경 가능성을 이유로 최초 거부. 공식 help의 output=none(Discard output)와 기존 3개 파일 SHA-256 전후 동일로 읽기 전용임을 입증 후 실행. exit 1은 기존 포맷 차이이며 파일은 무변경 |
| 12 | 최종 analyze·전체 test | 정적 분석 오류 0. 951 통과/45 환경 조건부 skip/실패 0. 새 회귀 8개(저장 4/파서 1/계층 3) 포함 |
| 13 | 실제 도구 통합 시나리오 | 36 통과/skip 0/실패 0, 7분49초. 실제 MPQ·복구·EUD 생성/반복 빌드/취소/timeout·8 tileset ISOM/CASC 검증 |
| 14 | 동봉 패키징 검사 | 첫 ZIP 경로는 없어서 2 통과/1 skip. 기존 build/euddraft-audit-0.10.2.5 ZIP을 찾아 재실행: 3 통과/skip 0. 재현 생성·변조/추가 파일 거부 확인 |
| 15 | Windows 렌더링·일반 앱 | 11화면×2폭 PNG 22개 생성, render_errors.txt 0 bytes. players/tools/resources/source의 600px 실제 폰트 화면 육안 확인. lib/main.dart debug 빌드와 4초 기동 확인; 이번 PID 36348만 종료 |
| 16 | native CTest·문서 정합 | 7/7 통과. 55개 요구사항 ID 중복/누락 0과 보고서 파일 링크 확인. 문서 인덱스·안전/형식/워크플로·기본 기능 대조표 갱신 |
| 17 | 최종 빌드 후 CTest·포맷 재검사 | CTest 다시 7/7 통과(0.40초). 421 Dart 파일 포맷 읽기 전용 검사에서 같은 기존 3개만 차이, SHA-256 전후 동일. diff --check 통과 |

## 소스 분석과 수정

| 판정 | 파일 / 로직 | 조치와 근거 |
| --- | --- | --- |
| Major 수정 | `SaveMapController` → `OpenMapController.adoptSavedSession` | 승격 후/최근 목록 I/O 동안 편집하면 옛 저장본이 최신 편집과 Undo를 지움. 예상 세션 identity를 I/O 뒤 비교해 현재 문서를 유지하고 `SAVE_MAP_NEWER_EDITS_PRESERVED` 경고를 반환. 쓰기 도중 변경은 기존 승격 전 검사 유지 |
| Major 수정 | 저장 중 brush transaction | 적용 전 브러시를 저장하면 임시 편집·기록이 교체될 수 있음. 작업 공간 생성 전에 `operationBusy`로 거부. 직접적인 명시적 문서 교체가 이전 history/stroke를 초기화하는 계약은 유지 |
| 최적화 적용 | `RawChkParser`, `RawChkSection` | sublistView는 입력 임시 복사만 제거. 생성자 내부 사본·외부 getter 사본은 유지. Uint8List에만 중복 범위 검사를 생략, 일반 List의 범위 오류 검증은 유지. 입력 byte-exact/불변성은 기존·새 테스트로 확인 |
| 주석 보강 | 문서 채택 guard, parser 복사 경계, typed byte 검사 | 왜 I/O 뒤 identity 비교가 필요한지, 어디서 사본을 소유하는지, 검사를 생략해도 안전한 조건을 코드에 설명 |
| 최적화 보류 | 전체 parse/typed-view를 isolate로 이동 | NFR-002를 모든 크기/typed 섹션에서 보장하지 못함. decoder 주입·identity/history 계약을 포함하는 별도 설계와 profile 측정 필요 |
| 최적화 보류 | `RecoveryMap.fromJson`의 dirty 섹션 반복 교체, 복구본 전체 목록 읽기 | 섹션 수/복구본 수에 따라 복사와 메모리가 증가할 여지. 현재 제한·보존 계약을 바꾸지 않고 추후 큰 checkpoint 프로파일링 대상으로 기록 |
| 대규모 분리 보류 | `editor_shell.dart`, `object_editing_controller.dart` | 파일 크기가 커 유지보수 부담. 감사 중 전면 분리는 회귀 위험이 커 수행하지 않음. 신규 변경은 영역별 분리와 명시적 책임을 우선 |
| 경계 검사 추가 | [계층 테스트](../test/architecture/layer_boundaries_test.dart) | domain/application의 Flutter·I/O·역방향 의존, UI의 IO/FFI/infrastructure/직접 raw codec import를 검사. 텍스트 directive 검사이며 동적 호출·모든 우회 import의 형식적 증명은 아님 |

## 요구사항 체크리스트

55개 FR/NFR를 각각 대조했다. **자동 확인**은 아래 시나리오의 제한된 테스트 범위에서
구현/회귀가 확인됐다는 뜻이며 게임 전체 호환성이나 릴리스 인수 완료를 뜻하지 않는다.
**부분**은 구현/자동 검증이 있어도 요구사항의 전체 인수 조건이 남은 상태다.
테스트/소스 범위는 시나리오 및 아래 경로를 함께 해석한다.

| ID | 판정 | 구현 근거 / 검사 시나리오 / 남은 조건 |
| --- | --- | --- |
| FR-001 | 자동 확인 | OpenMapController·셸, S03/S04/S10 |
| FR-002 | 자동 확인 | OpenedMapSession·빌드 기록·셸 상태, S04/S08/S10 |
| FR-003 | 자동 확인 | 셸 교체/닫기 확인·소스 dirty, S10; OS 강제 종료는 S07 복구 |
| FR-004 | 자동 확인 | MapEditHistory·편집/EUD controller, S02/S04/S05/S08 |
| FR-101 | 자동 확인 | ProcessMapArchiveGateway·native helper, S03 |
| FR-102 | 자동 확인 | RawChkParser/Encoder, S02/S03/S04 |
| FR-103 | 자동 확인 | 길이·잘린 헤더·보호 마커 진단, S02 |
| FR-104 | 자동 확인 | SaveMapController·gateway·신규 동시성 guard, S04 |
| FR-105 | 자동 확인 | 제한 편집·보호 마커·저장 불허, S02/S04/S10 |
| FR-106 | 부분 | NewMapFactory·NewMapController·새 MPQ 왕복 S05; SC:R/외부 에디터 인수 대기 |
| FR-201 | 자동 확인 | MapCanvas·layer controller·camera, S10/S12 |
| FR-202 | 자동 확인 | ObjectEditingController·Inspector, S04/S10 |
| FR-203 | 자동 확인 | 다중 선택/삭제 controller·UI 표시, S06/S10 |
| FR-204 | 자동 확인 | 좌표/참조 validator·편집 거부·저장 진단, S02/S04; 원본의 비차단 warning은 자동 정정하지 않음 |
| FR-205 | 자동 확인 | 자산 inspector·settings·CASC helper, S09; 설치/빌드별 게임 호환성 보증은 아님 |
| FR-206 | 부분 | 맵·플레이어·세력 CHK editor와 설정 UI, S04/S11; 실제 게임 표시/인코딩 인수 대기 |
| FR-207 | 부분 | unit settings·공유 weapon editor, S04/S11; 실제 무기/클로킹 사례 대기 |
| FR-208 | 부분 | PUNI 상속·허용 editor, S04/S11; 게임 생산 검증 대기 |
| FR-209 | 부분 | upgrade editor·지원 크기/원시 보존, S04/S11; 게임 연구/레벨 검증 대기 |
| FR-210 | 부분 | tech editor·비용/상속/연구, S04/S11; 게임 검증 대기 |
| FR-211 | 부분 | basic editing·객체 관계·시작 위치, S06; 상태/Addon/Nydus/Doodad 게임/외부 왕복 대기 |
| FR-212 | 부분 | ISOM 변환/brush·MASK editor, S06/S09; 게임 통행/안개·외부 에디터 대기 |
| FR-213 | 자동 확인 | 문서 내 clipboard·공통 기록, S06; 문서 간/혼합 다수 Doodad는 명시적 범위 밖 |
| FR-214 | 부분 | resize preview·원자적 적용·Undo·MPQ, S05/S09; 외부 에디터/게임 인수 대기 |
| FR-215 | 자동 확인 | 선택/탐색·location·minimap·겹침, S06/S10 |
| FR-216 | 부분 | Resources·PCM WAV·참조 보호·MPQ, S04/S06; 실제 오디오/게임 재생 대기 |
| FR-401 | 부분 | 일반 조건22/액션57·트리거 editor, S04/S10; 실제 실행 검증 대기 |
| FR-402 | 자동 확인 | trigger resources·UPRP·switch·reference validator, S02/S04 |
| FR-403 | 부분 | MBRF 액션9·별도 UI·저장, S04/S11; 게임 텍스트/초상화/소리/시간 대기 |
| FR-404 | 자동 확인 | 미지원/EUD records raw 보존·편집 제한, S02/S04 |
| FR-301 | 자동 확인 | EudToolSettings·Local/Bundled inspector, S08/S11 |
| FR-302 | 자동 확인 | ProcessEudCompilerGateway 인자 배열/runInShell=false, S08 |
| FR-303 | 자동 확인 | EudBuildRecord·UTC/종료 코드/로그, S08/S10 |
| FR-304 | 자동 확인 | project decode/open과 prepare는 실행하지 않음, 명시적 build만 compiler 호출, S07/S08 |
| FR-305 | 자동 확인 | SafeEudBuildPipeline 경로/fingerprint 검증·별도 승격, S08 |
| FR-306 | 자동 확인 | diagnostic parser·BuildLog·raw 채널/출력 상한, S08/S11; 무제한 로그 저장은 아님 |
| FR-307 | 부분 | CHK/EUD 구분·manifest·field UI, S08/S11; 모든 게임 필드 인수 대기 |
| FR-308 | 부분 | field manifest·미검증 테스트 빌드 명시 확인, S08; 후보 전체 게임 승인 미완료 |
| FR-309 | 부분 | EudConflictAnalysis·참조 그래프·type/instance UI, S08/S09/S11; 동적 코드/HD 전체 분석은 제한 |
| FR-310 | 자동 확인 | project/controller/workspace·JSON·Undo/hash/최신 여부, S07/S08/S10 |
| FR-311 | 자동 확인 | 결정적 생성·user entry 보존·원본 해시·반복 빌드, S08; 임의 보호 맵 재작성 불가 |
| FR-312 | 자동 확인 | 공통 category 필드와 단일 프로젝트 override, S08/S11 |
| FR-313 | 부분 | upgrade/tech/player 후보 필드·manifest, S08; 게임 인구수·연구 실효 검증 대기 |
| FR-314 | 부분 | sprite/image 후보·공유 영향·classic/HD 경고, S08/S09; 실제 HD 표시 인수 대기 |
| FR-315 | 부분 | manifest·validation·중복 차단·evidence, S08; 전체 필드의 게임 증거 대기 |
| FR-316 | 부분 | 타입 있는 실행 규칙·expr·target·cadence·원본 우선, S08; 게임 순서/주기 대기 |
| FR-317 | 부분 | 수명/참조/비용 정적 제한·schema 보존·컴파일, S08; 슬롯 재사용/성능 실제 실행 대기 |
| FR-318 | 미완료 인수 | 표시/동기화 영역 validation은 S08; SC:R 실제 실행/2클라이언트 검증 미실행 |
| NFR-001 | 부분 | 256×256 canvas/object/catalog 스모크 S12; profile 60/30 FPS 판정 미실행 |
| NFR-002 | 부분 | I/O/프로세스 async·복구 Isolate·파서 복사 최적화 S12; 전체 typed parse UI 비차단 보장은 없음 |
| NFR-003 | 부분 | 생성 코드/hash 결정성과 반복 빌드 S08; 모든 외부 도구/MPQ 출력 byte 재현성 보장 아님 |
| NFR-004 | 자동 확인 | parser code·offset·section·rawDetails S02/S11; 잘린 헤더는 완전한 section명을 추정하지 않음 |
| NFR-005 | 미완료 | 원시 로그/경로는 사용자 진단용으로 남음. 크래시 로그 개인정보 제거·배포 정책은 M8 대기 |
| NFR-006 | 자동 확인 | 환경변수 없는 필수 전체 테스트 S01; 선택 실제 설치 검사는 별도 |
| NFR-007 | 자동 확인(이번 범위) | 신규 의존성 없음. pinned helper/동봉 고지 S08/S09; 최종 배포물 라이선스 검사는 별도 |

## 테스트 시나리오

각 시나리오는 정상·실패·경계 경로를 가진 기존 테스트와 새 회귀 테스트로 수행한다.
상세 assertion은 링크된 테스트가 실행 가능한 명세다. 최종 결과는 아래에 기록한다.

| 시나리오 | 절차 / 기대 결과 | 테스트 근거 |
| --- | --- | --- |
| S01 기본 게이트 | 포맷 읽기 전용 검사 → analyze → 환경변수 없는 전체 test. 오류·skip 개별 구분 | [품질 계약](TESTING_AND_QUALITY.md) |
| S02 CHK 보존/손상 | 임의·중복·알 수 없는 섹션 왕복, 잘린 헤더/길이·보호 마커·offset view 검사. 입력 무변경·위치 진단 | [파서](../test/domain/chk/raw_chk_parser_test.dart), [리소스](../test/domain/chk/chk_resource_editor_test.dart), [트리거](../test/domain/chk/chk_trigger_editor_test.dart) |
| S03 실제 MPQ | 자체 제작 맵 열기 → 복사본 쓰기 → 재열기. 원본 SHA/비대상 entries/CHK 유지 | [실제 helper](../test/infrastructure/bundled_map_archive_helper_test.dart), native CTest |
| S04 설정/저장 | 7종 설정·객체·트리거/브리핑/리소스 편집 → Undo/Redo → Save As → 재열기. 실패/외부 변경/동시 편집은 무손실 | [저장 실패/동시성](../test/application/save_map_controller_test.dart), [실제 설정 왕복](../test/integration/object_editing_roundtrip_test.dart) |
| S05 생성/크기 | New Map·raw/ISOM/Doodad resize → 영향 확인 → Undo/Redo → 신규 MPQ 재열기 | [새 맵](../test/integration/new_map_roundtrip_test.dart), [크기](../test/integration/map_resize_roundtrip_test.dart) |
| S06 기본 편집/지형 | 안개·시작 위치·상태/관계·clipboard·탐색·ISOM brush/변환. 경계 거부·한 명령 복구·MPQ 보존 | [기본 도구](../test/integration/basic_editing_tools_roundtrip_test.dart), [brush](../test/integration/isom_brush_roundtrip_test.dart), [탐색](../test/application/selection_navigation_controller_test.dart) |
| S07 자동 저장/복구 | 체크포인트 → 재실행 복원 → Save As. checksum 손상·외부 원본 변경·동시 문서 변경은 복구 거부 | [controller](../test/application/autosave_controller_test.dart), [실제 왕복](../test/integration/autosave_roundtrip_test.dart) |
| S08 EUD | 가짜 success/fail/timeout/cancel → 동봉 도구 실제 build/종료 → 생성 필드 컴파일. 원본/entry/도구 해시 보존·별도 출력 | [safe pipeline](../test/application/safe_eud_build_pipeline_test.dart), [실제 빌드](../test/integration/real_euddraft_build_smoke_test.dart), [취소/timeout](../test/integration/bundled_euddraft_process_control_test.dart), [필드 컴파일](../test/integration/eud_expanded_fields_compile_test.dart) |
| S09 로컬 자산 | 로컬 SC:R 저장소 검사·8 tileset/카탈로그·DAT·CV5/VF4/ISOM 경계·resize. 자산은 메모리/임시 자료만 | [CASC](../test/infrastructure/bundled_starcraft_data_helper_test.dart), [DAT](../test/integration/eud_dat_local_smoke_test.dart), [ISOM](../test/integration/isom_brush_local_data_test.dart) |
| S10 셸/입력 | 실제 controller로 메뉴·탭·닫기·canvas·Inspector·로그·언어·저장 상태 조작, 예외 없이 기대 상태 확인 | [셸](../test/widget/editor_shell_test.dart), [캔버스](../test/widget/map_canvas_test.dart) |
| S11 한영 표시 | 언어 전환·초안/Undo 보존·긴 경로·원시 로그, Windows 엔진 11화면×2폭 실제 폰트 렌더링 | [번역 테스트](../test/widget/editor_translation_test.dart), [Windows harness](../tool/localization_windows_smoke.dart) |
| S12 성능 | 256×256 fit/zoom/pan·4096객체·catalog; 합성 1/16/64 MiB parser/encoder byte-exact와 시간 측정 | [지형 성능](../test/performance/map_canvas_performance_test.dart), [객체 성능](../test/performance/object_sprite_performance_test.dart), [측정 도구](../tool/source_audit_benchmark.dart) |
| S13 계층 | 모든 lib/domain/application/presentation의 import/export 검사, 금지 의존성 0 | [계층 게이트](../test/architecture/layer_boundaries_test.dart) |
| S14 일반 앱 | `lib/main.dart` Windows debug 빌드·프로세스 정상 기동, 검증용으로 시작한 PID만 종료 | 자동 OS 클릭이 아닌 정상 기동 스모크 |
| S15 별도 인수 | SC:R 맵 실행/외부 에디터/멀티플레이/깨끗한 Windows 설치/실제 오디오/profile FPS | 미실행; S01~S14 통과로 대체하지 않음 |

## 최종 실행 결과

### 결과 요약

| 검사 | 결과 | 해석 |
| --- | --- | --- |
| S01 analyze | No issues found | 현재 작업 트리 기준 |
| S01 전체 test | 951 통과 / 45 skip / 실패 0, 1분56초 | 실제 설치/동봉 ZIP 환경이 필요한 검사는 기본 실행에서 skip. 아래 별도 검사로 보완 |
| S01 전체 format | exit 1, 기존 infrastructure 테스트 3개만 차이 | output=none이므로 파일 변경 없음. 관련 없는 사용자 파일을 포맷하지 않음 |
| S02~S10 실제 통합 | 36 통과 / skip 0 / 실패 0 | 자체 제작 맵과 현재 로컬 설치·검토된 도구만 사용 |
| S08 패키징 | 3 통과 / skip 0 | 기존 ZIP 재사용. 외부 다운로드/업그레이드 없음 |
| S03/S09 native CTest | 7/7 통과, 최종 0.40초 | MPQ·SC data·object reference/graphics·doodad·terrain·EUD DAT |
| S11 Windows 렌더링 | 22 PNG / Flutter render exception 0 | 테스트 harness 렌더링. 22개 전체 육안 전수 확인이나 OS 클릭 인수는 아님 |
| S13 계층 검사 | 3 통과 | 전체 lib 계층 directive 검사; 형식적 안전성 증명 아님 |
| S14 일반 Windows 앱 | debug 빌드 성공, 시작 후 4초 생존 확인 | 창 닫기 요청으로 종료되지 않아 이번 PID만 강제 종료(exit -1). 정상 종료/복구 인수는 별도 |
| S15 게임/배포 인수 | 미실행 | 아래 잔여 위험 참조 |

실행 도구 체인은 **Flutter 3.47.5 stable / Dart 3.13.4**, Windows x64이다.
저장소 기준 **3.44.8 / 3.12**는 이 세션에서 실행하지 못했다. 전체 포맷 차이는
`local_map_save_file_gateway_test.dart`, `process_eud_compiler_gateway_test.dart`,
`process_map_archive_gateway_test.dart`에 한정된다. CMake의 CascLib 최소 버전
호환성 폐기 예고는 빌드를 실패시키지 않았으며 외부 의존성 메타데이터는 수정하지 않았다.

### 성능 결과와 분석

아래 parser 시간은 동일 로컬 Dart JIT에서 각각 한 번 관찰한 값이며 반복 통계,
release/profile FPS 또는 메모리 절감량의 증명이 아니다. 합성 TEST 섹션만 사용했다.
각 입력에는 8-byte 헤더가 추가되며 encode 결과를 전체 byte 비교했다.

| payload | 변경 전 parse/encode (µs) | 변경 후 parse/encode (µs) |
| --- | --- | --- |
| 1 MiB | 5,044 / 2,616 | 3,408 / 2,156 |
| 16 MiB | 23,840 / 10,144 | 5,632 / 7,053 |
| 64 MiB | 122,945 / 38,188 | 21,596 / 27,164 |

전체 테스트 엔진의 Windows debug 800×600, 256×256 스모크도 통과했다.
지형 fit/zoom/pan은 74,085/42,378/34,036µs, 4,096개 객체는
46,800/13,563/9,213µs였다. 객체 texture 240개/fallback 16개, cache 983,040 bytes,
RSS delta 26,460,160 bytes를 기록했다. catalog 첫 페이지 2,062ms/검색 1,086ms/
12회 scroll 3,593ms, loaded entries 2,000/built tiles 19였다. 이는 테스트 경계 안의
결과이며 실제 UI의 60/30 FPS나 모든 맵의 비차단 parsing을 보장하지 않는다.
CPU 환경 문자열은 Intel64 Family 6 Model 183 Stepping 1, GenuineIntel이다.
Win32_Processor 조회는 접근 제한으로 상세 모델을 확인하지 못했다.

### 재현 명령과 증거

저장소 루트의 PowerShell에서 실행한다. 실제 도구 검사는 현재 build/설치가
존재해야 한다. 기본 테스트와 별도 테스트의 환경변수를 혼합하지 않는다.

```powershell
dart format --output=none --set-exit-if-changed lib test tool
flutter analyze
flutter test
dart run tool/source_audit_benchmark.dart
flutter build windows --debug --target tool/localization_windows_smoke.dart
& build/windows/x64/runner/Debug/starcraft_map_editor.exe
flutter build windows --debug --target lib/main.dart
& 'C:/Program Files/Microsoft Visual Studio/2022/Community/Common7/IDE/CommonExtensions/Microsoft/CMake/CMake/bin/ctest.exe' --test-dir build/windows/x64 -C Debug --output-on-failure
```

렌더링 harness 종료 뒤 일반 앱 target을 다시 빌드한다. 실제 통합 검사는 별도
PowerShell에서 다음과 같이 실행한다.

```powershell
$env:MAP_ARCHIVE_HELPER_PATH = (Resolve-Path build/windows/x64/runner/Debug/map_archive_helper.exe).Path
$env:MAP_ARCHIVE_TEST_MAP = (Resolve-Path test/fixtures/maps/generated/minimal-self-authored.scx).Path
$env:EUDDRAFT_TEST_INSTALLATION = (Resolve-Path build/windows/x64/runner/Debug/tools/euddraft/0.10.2.5-editor.1).Path
$env:EUDDRAFT_TEST_BUNDLED = '1'
$env:STARCRAFT_DATA_HELPER_PATH = (Resolve-Path build/windows/x64/runner/Debug/starcraft_data_helper.exe).Path
$env:STARCRAFT_TEST_INSTALLATION = 'C:/Program Files (x86)/StarCraft'
flutter test test/integration test/infrastructure/bundled_map_archive_helper_test.dart test/infrastructure/bundled_starcraft_data_helper_test.dart --concurrency=1 --reporter expanded
$env:EUDDRAFT_AUDIT_ZIP = (Resolve-Path build/euddraft-audit-0.10.2.5/euddraft0.10.2.5.zip).Path
flutter test test/infrastructure/bundled_eud_tool_test.dart --reporter expanded
```

로컬 상세 증거는 Git에서 제외되는 `.dart_tool/audit_save_before.log`,
`audit_save_after.log`, `audit_focused_test.log`, `audit_full_test.log`,
`audit_full_test_final.log`, `audit_real_integration.log`, `audit_bundle_test.log`,
`audit_bundle_test_final.log`, `audit_chk_benchmark_before.log`,
`audit_chk_benchmark_after.log`, `audit_windows_render_build.log`,
`audit_windows_build.log`, `audit_format_final.log`, `audit_ctest_final.log`,
`localization_windows_smoke/`에 있다.
임시 출력·추출된 원시 SC:R 자산은 fixture나 커밋에 포함하지 않는다.

### 잔여 위험과 판정

- 기준 SDK 및 깨끗한 커밋/PC에서의 재실행 필요. 기존 사용자 변경을 포함한 로컬 검증이다.
- 실제 SC:R 게임, 외부 에디터 왕복, EUD 동작/멀티플레이 동기화, 오디오 재생,
  접근성/고대비, 깨끗한 Windows 설치·제거와 최종 배포물 라이선스 인수는 미실행이다.
- NFR-001 profile FPS, NFR-002 전체 typed parse 비차단, NFR-005 크래시 로그
  개인정보 제거는 완료로 판정하지 않는다. 다른 부분 요구사항은 위 체크리스트를 따른다.
- 자동 테스트 통과는 무결함 보증이나 릴리스 승인으로 간주하지 않는다. 이번에 확인한
  저장 데이터 손실 경로는 수정했고, 원본/바이트 보존·회귀 테스트 범위에서 검증했다.
