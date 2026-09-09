# 로컬 유닛–무기 참조 목록

Unit Settings에서 무기를 선택하면 로컬 게임 데이터의 지상·공중 무기 참조를
가진 유닛 ID 목록을 표시한다. 해당 유닛을 서브유닛으로 참조하는 유닛은 별도
목록으로 표시한다. 양쪽 무기가 같아도 유닛을 중복 표시하지 않으며 서브유닛
연결을 따라갈 때 순환 참조가 있어도 탐색을 종료한다.

이 목록은 DAT의 정적 참조 관계다. 주문, 생성되는 투사체·별도 유닛, EUD의
런타임 변경이나 실제 공격 가능 여부까지 모두 설명하는 목록은 아니다. 참조가
없으면 현재 DAT 스냅샷에서 없다고 표시한다. 데이터가 없거나 불완전한 경우는
빈 목록과 구분하여 사유와 다시 읽기 버튼을 표시한다. 오류가 설정 입력을
자동으로 바꾸거나 기존 무기 값을 초기화하지 않는다.

## 읽기 계약

기존 catalog port와 제한된 helper 프로세스 실행을 사용한다.
listPlacementCatalog의 kind=unit 요청에 unitMetadataOnly=true를 추가하면
그래픽 메타데이터·팔레트·GRP 대신 arr/units.dat 하나만 읽는다. 응답은 같은
플래그로 기능 지원을 확인하며 assets.readCount=1, totalBytes=19876이다.
228개 항목의 capability.weaponReferences에 ground, air, subunit1, subunit2를
반환한다. protocol 3/helper 0.8.0에 추가한 선택 기능이며 플래그 확인이 없는
구버전 helper의 응답은 목록에 사용하지 않는다. 일반 배치 요청은 기존 동작을
유지하고 추가 참조 필드가 없어도 기존 capability를 사용할 수 있다.

원본 DAT는 저장소나 Dart 응답에 포함하지 않는다. 정확히 19876바이트인 classic
배열에서 groundWeapon 오프셋 5892, airWeapon 6348, subunit1 228, subunit2 684를
읽는다. 무기는 u8, 서브유닛은 little-endian u16이다. 무기 ID 130과 유닛 ID 228은
참조 없음으로 처리한다. 그보다 큰 값은 유효한 연결로 추측하지 않는다.
배치 capability의 다른 플래그는 참조 오류와 독립적으로 유지한다.

Application은 한 요청으로 228개 항목과 helper·게임 빌드 정보를 받고 전체
커버리지를 확인한다. 누락·잘못된 ID·오류 응답은 전체 목록을 사용 불가로
표시한다. 설치 경로 변경, 같은 맵 재열기, controller 종료는 이전 요청을
취소하고 응답을 폐기한다. 화면도 설치·맵 변경을 구독해 이전 목록을 제거한다.
프로세스 timeout·취소·출력 상한·최소 환경과 실패 원시 로그 정책은 catalog
gateway를 그대로 따른다. 목록에는 게임 product/build와 helper 버전을 표시한다.

## 확인한 동작

- 네이티브 합성 바이트: 마지막 유닛의 참조 오프셋·경계·sentinel과 잘못된 ID.
- 도메인: 직접·간접 참조, 중복 제거, 순환 탐색, 불완전한 커버리지 거부.
- Application/UI: 전체 목록, 미지원 응답, 설치 변경·종료 뒤 응답 폐기,
  무기 선택 변경과 설치 해제 후 오래된 목록 제거.
- 가짜 helper: 228개 응답, 잘못된 참조와 구버전 기능 확인 응답 거부.
- 2026-09-09 Windows 실제 설치 스모크: s1 build 13515, helper 0.8.0에서
  한 파일 19876바이트를 읽고 228/228개 참조 확인. Unit #0은 지상·공중 무기 0,
  두 서브유닛은 228이었다. 실제 게임 전투·EUD 동작은 실행하지 않았다.

구조의 근거는 [Chkdraft 고정 revision의 Unit::DatFile](https://github.com/TheNitesWhoSay/Chkdraft/blob/32d27861b16dda0b0f3d95e34bad894ea4efb2c3/src/mapping_core/sc.h)이다.
