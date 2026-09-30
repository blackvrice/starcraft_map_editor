# 등각 지형·경사로와 에디터 지형 데이터

2026-09-30: 첫 단계인 **TILE/ISOM 읽기 전용 구조 검사와 MTXM 비교**를 구현했다.
등각 지형·경사로 브러시, ISOM 생성/복구, ISOM·두다드 맵 resize는 아직 미구현이다.
기존 원시 브러시는 계속 MTXM만 변경한다.

## 화면에서 확인

맵 선택 상태의 우측 정보 패널에서 **에디터 지형 데이터 / Editor terrain data**를
펼치면 다음을 한글·영문으로 확인할 수 있다.

- 각 MTXM/TILE/ISOM 섹션의 문서 인덱스, 실제/예상 바이트 수와 구조 상태.
- ISOM 없음, 일반 ISOM 있음, EUD 보호 마커의 구분.
- 중복 섹션 이름. 여러 사본 중 하나를 활성 사본으로 추측하지 않는다.
- 유일하고 정상 크기인 MTXM/TILE의 서로 다른 셀 수와 두다드 존재 여부.

구조 크기가 맞는다는 사실은 지형 연결·높이·경사로의 의미가 맞다는 보증이 아니다.
MTXM/TILE 차이는 원시 편집이나 두다드에서도 생길 수 있어 손상으로 표시하지 않는다.
이 패널은 검사만 하며 기존 저장 가능 여부나 원시 브러시 활성 정책을 바꾸지 않는다.

## 확인한 포맷과 제품 정책

고정 Chkdraft commit `32d27861b16dda0b0f3d95e34bad894ea4efb2c3`의
[IsomRect와 섹션 선언](https://github.com/TheNitesWhoSay/Chkdraft/blob/32d27861b16dda0b0f3d95e34bad894ea4efb2c3/src/mapping_core/chk.h#L147-L289),
[섹션 크기](https://github.com/TheNitesWhoSay/Chkdraft/blob/32d27861b16dda0b0f3d95e34bad894ea4efb2c3/src/mapping_core/chk.h#L1390-L1407)를 확인했다.
ISOM은 little-endian u16 네 변(left/top/right/bottom)의 8바이트 레코드다.
격자는 `(width ~/ 2 + 1) × (height + 1)`이며 오른쪽·아래쪽 여분 레코드를 포함한다.
TILE과 MTXM의 구조 크기는 각각 `width × height × 2`다.

[변환·크기 변경 구현](https://github.com/TheNitesWhoSay/Chkdraft/blob/32d27861b16dda0b0f3d95e34bad894ea4efb2c3/src/mapping_core/scenario.cpp#L4006-L4069)에서
ISOM 변경 영역을 타일로 변환하는 경로와 resize 경계 처리가 별도임을 확인했다.
따라서 raw 타일 번호나 ISOM 길이만으로 높이·경사로 연결을 생성하지 않는다.
외부 코드를 복사하거나 게임 자산을 포함하지 않았다. 후속 알고리즘의 도입 범위와
라이선스는 별도 결정하고 고정 버전·자체 제작 fixture로 검증해야 한다.

## 구현 계약

`ChkEditorTerrainDecoder`는 원시 문서를 변경하지 않고 다음을 투영한다.

- 유일한 4바이트 DIM 및 양수 가로/세로만 격자 크기의 근거로 사용한다.
  잘린 DIM과 정상 DIM이 함께 있어도 하나를 고르지 않는다.
- 크기 불일치, 알 수 없는 크기, 보호 마커를 별도 상태로 유지한다.
  선언 크기만큼 빈 격자를 할당하거나 누락 데이터를 0으로 채우지 않는다.
- 읽기 전용 `isomAt`은 네 u16 값을 플래그 포함 그대로 돌려준다. 알려지지 않은
  값에 지형 이름을 붙이거나 에디터 비트를 지우지 않는다.
- 비교는 MTXM/TILE 각 하나가 유효할 때만 한다. 비교 불가와 차이 0을 구별한다.
- EUD의 high-bit ISOM 길이 마커는 기존 파서 계약을 유지하며 격자로 읽지 않는다.

`OpenedMapSession.editorTerrain`은 불변 세션마다 지연 생성·캐시한다.
원시 편집·Undo/Redo로 세션이 바뀌면 새 결과를 사용한다. UI는 이 application
투영을 전달받으며 직접 파서나 파일을 호출하지 않는다. 검사 때문에 dirty/Undo
기록을 만들지 않고 모든 원시 섹션과 보호 헤더를 그대로 저장한다.

## 검증

도메인 테스트는 little-endian 네 변·경계 레코드·플래그 보존, 중복/손상/누락 DIM,
홀수 폭·최대 DIM의 크기 검사, 잘린 TILE/ISOM, 보호 마커와 무손실 인코딩을 확인한다.
컨트롤러 회귀는 raw 편집·Undo/Redo에 따라 차이 수가 갱신되는지 확인한다.
한글/영문 위젯은 구조 불일치와 차이 수 표시를 검사한다. 자체 제작 MPQ 테스트는
원시 편집 후 Save As·재열기에서 TILE/ISOM과 입력 fingerprint 보존을 검사한다.

2026-09-30 검증: 관련 도메인/컨트롤러/한영 UI 8개 통과, 최종 전체 Flutter
테스트 808개 통과/30개 환경 선택 skip. 실제 MPQ 보존 테스트 1개 통과.
최종 analyze 무이슈, Windows debug 빌드와 앱 4초 시작 확인 통과.
변경 Dart 12개 format 통과. 전체 format은 기존 infrastructure 테스트 4개
(`local_map_save_file_gateway`, `process_eud_compiler_gateway`,
`process_map_archive_gateway`, `process_starcraft_data_asset_inspector`)의
포맷 차이로 미통과이며 해당 파일은 변경하지 않았다.

검증 SDK는 Flutter 3.47.5/Dart 3.13.4이며 저장소 기준 3.44.8/3.12와 다르다.
기존 CascLib CMake deprecation 경고는 남아 있다. 실제 게임·외부 에디터와
수동 UI 인수는 수행하지 않았다. 구조 검사 통과를 등각 지형 생성 검증으로 간주하지 않는다.

## 비적층 변환 기반 (2026-09-30 후속)

`IsomTerrainConverter`는 검증된 숫자 연결 카탈로그를 주입받아 TILE/MTXM을 함께
생성하는 순수 도메인 코어다. 실제 로컬 데이터 공급자와 UI는 아직 연결하지 않았다.
합성 사례 통과는 실제 StarCraft 지형·보행 가능성·경사로 검증을 의미하지 않는다.

### 포맷 근거와 제한

같은 고정 Chkdraft revision의
[TileGroup/ShapeLinks 선언](https://github.com/TheNitesWhoSay/Chkdraft/blob/32d27861b16dda0b0f3d95e34bad894ea4efb2c3/src/mapping_core/sc.h),
[연결 키 생성](https://github.com/TheNitesWhoSay/Chkdraft/blob/32d27861b16dda0b0f3d95e34bad894ea4efb2c3/src/mapping_core/sc.cpp#L1849-L1871),
[타일 쌍과 적층 처리](https://github.com/TheNitesWhoSay/Chkdraft/blob/32d27861b16dda0b0f3d95e34bad894ea4efb2c3/src/mapping_core/scenario.cpp#L416-L486)를 참고했다.
CV5만으로 ISOM 값의 의미를 추측하지 않는다. 형태 연결표까지 함께 검증해야 한다.
외부 구현 코드는 복사하지 않았다.

- 카탈로그는 tileset·revision, 정규화 ISOM 값별 연결/terrain type, 검증된 짝수
  left group과 다음 right group, 네 방향 연결과 적층 연결, 허용 member를 제공한다.
  공급자는 양쪽 그룹과 실제 렌더 가능한 member를 검증해야 한다.
- 연결 값은 6비트이고 48 이상 연결에는 terrain type을 키에 포함한다.
  조회할 때만 ISOM modified/visited 비트를 제외하며 원시 ISOM은 보존한다.
- 적층 연결이 모두 0인 쌍만 사용한다. 적층/경사로 solver는 구현하지 않았다.
  오른쪽·아래 여분 레코드까지 알려진 값이어야 한다. 이 검사는 인접성 solver가 아니다.
- 짝수 폭, 최대 256×256, 유일하고 정상 크기의 DIM/ERA/ISOM/TILE/MTXM을 요구한다.
  두다드, 보호 마커, 중복 지형 섹션, TILE/MTXM 차이, 알 수 없는 연결은 거부한다.
- 기존 타일 쌍과 member가 카탈로그 후보에 맞으면 유지한다. 새 선택은 정렬된
  후보와 uint32 seed·좌표 혼합으로 결정한다. StarEdit의 난수와 같다는 계약은 아니다.
- 실패하면 입력 전체를 보존한다. 성공하면 TILE/MTXM만 교체하고 ISOM 플래그,
  다른 섹션, 문자열·객체는 그대로 둔다. 변경 0이면 원래 문서를 반환한다.

### 애플리케이션 경계

`IsomTerrainCatalogGateway`는 후속 로컬 자료 공급자의 포트다. 공급자는 동일한
설치 자료 snapshot/fingerprint와 변환 버전을 revision에 결합해야 한다.
현재는 테스트용 합성 공급자만 있으며 제품 공급자를 가장하지 않는다.
`IsomConversionController`는 읽기 전용 미리보기 후 명시적 적용을 제공한다.
문서 교체·취소·후속 요청·활성 작업/편집 transaction에서 오래된 결과를 거부한다.
적용은 리소스 편집을 보존하며 공통 Undo/Redo 한 건으로 기록한다. 파일 저장은
기존 Save As 파이프라인을 사용한다. UI 연결 시 진단과 명령 이름을 현지화해야 한다.

### 후속 검증 기록

도메인/애플리케이션 7개 통과: 독립 예상 바이트, 후보 순서·seed 결정성, 유효 쌍
유지, 상한 타일 값, hard-link 타입, 보호/중복/두다드/원시 덮어쓰기 거부,
미리보기 무변경, 오래된 결과 거부와 Undo/Redo를 검사했다.
실제 MPQ helper 통합 1개도 통과했다. 자체 제작 합성 맵의 적용·Undo/Redo·Save As·
재열기, 전체 CHK 바이트와 입력 fingerprint 보존을 확인했다. 게임 자산은 포함하지 않았다.
최종 analyze 무이슈, 변경 Dart 7개 format 및 문서 링크 검사 통과.
전체 Flutter 테스트 815개 통과/31개 선택 skip. 실제 설치 자료와 게임 검증은
공급자가 미구현이므로 수행하지 않았다. UI/native 변경이 없어 이번 Windows 빌드는 생략했다.
SDK는 Flutter 3.47.5/Dart 3.13.4로 기준 SDK와 다르며 기준 버전 CI 확인은 별도다.
전체 format은 위 기존 테스트 4개의 차이로 미통과이며 사용자 변경을 보존했다.

## 다음 구현 순서

1. 실제 로컬 CV5와 형태 연결표를 읽는 공급자를 구현하고 자료 fingerprint·버전을
   기록한다. 설치 자료와 대조해 검증된 비적층 카탈로그부터 제공한다.
2. 수직 적층·경사로·경계 연결 solver와 보존 범위를 확장하고 독립 사례로 검증한다.
3. 검증된 평지/전환/경사로 브러시·미리보기·공통 Undo와 원자적 섹션 갱신을 연결한다.
4. 실제 설치·외부 에디터·SC:R로 확인한 뒤 ISOM/두다드 resize를 확장한다.
