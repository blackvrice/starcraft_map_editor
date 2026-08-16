# SC:R 객체 그래픽 자산 조사

조사일: 2026-08-08

## 목적과 결론

`UNIT`와 `THG2` 레코드의 숫자 ID를 사용자가 설치한 StarCraft: Remastered의
실제 객체 이미지로 연결하기 위한 근거와 첫 구현 범위를 정리한다.

첫 구현은 로컬 CASC에서 클래식 메타데이터와 `unit/*.grp`를 읽어 정적인 대표
프레임을 RGBA로 변환한다. Remastered의 `.anim`은 다중 해상도·다중 레이어를 함께
처리해야 하므로 이 경로가 안정화된 뒤 별도 단계에서 지원한다. 어느 경로에서도
게임 자산을 애플리케이션이나 저장소에 포함하지 않는다.

## 로컬 설치에서 확인한 자산

제품 `s1`, 빌드 `13515`인 `C:\Program Files (x86)\StarCraft`를 기존 CascLib
helper와 일회성 읽기 전용 열거기로 검사했다. 빌드 번호와 파일 크기는 설치 또는
패치에 따라 달라질 수 있으며 구현 상수로 사용하지 않는다.

| 역할 | CASC 경로 | 확인 결과 |
| --- | --- | --- |
| 유닛에서 flingy 참조 | `arr/units.dat` | 19,876 bytes |
| flingy에서 sprite 참조 | `arr/flingy.dat` | 3,135 bytes |
| sprite에서 image 참조 | `arr/sprites.dat` | 3,229 bytes |
| image 속성과 GRP 문자열 번호 | `arr/images.dat` | 37,962 bytes |
| 클래식 그래픽 경로 문자열 | `arr/images.tbl` | 24,009 bytes |
| 애니메이션 명령 | `scripts/iscript.bin` | 40,482 bytes |
| 클래식 그래픽 | `unit/*.grp` | 925개 확인 |
| Remastered 기본 그래픽 | `anim/main_*.anim` | 868개 확인 |
| Remastered 절반 해상도 그래픽 | `HD2/anim/main_*.anim` | 868개 확인 |
| SD 통합 그래픽 | `SD/mainSD.anim` | 38,402,144 bytes |
| `.anim` 이미지 연결 데이터 | `images.rel`, `SD/images.rel` | 각각 7,992 bytes |

경로 구분자는 문서에서는 `/`로 표기하지만 CascLib 요청에는 저장소의 Windows식
경로인 `\\`를 사용한다. 목록에 있는 파일의 존재만 신뢰하며, 파일 수나 크기를
고정값으로 검증하지 않는다.

## 객체 ID에서 그래픽까지의 참조

PyMS의 DAT 정의와 편집기 연결 코드는 다음 참조 관계를 보여 준다.

```text
UNIT.type
  -> units.dat graphics
  -> flingy.dat sprite
  -> sprites.dat image
  -> images.dat GRP string index
  -> images.tbl path
  -> unit/*.grp

THG2.spriteType + Draw as sprite flag
  -> sprites.dat image
  -> images.dat ...

THG2.spriteType without Draw as sprite flag
  -> UNIT과 같은 unit -> flingy -> sprite -> image 경로
```

Chkdraft 구현에서도 객체 종류는 `Draw as sprite` 비트의 유무로 구분한다. 비트가
있으면 `spriteType`은 sprite ID이고, 없으면 unit ID이다. `Unit` 비트는 StarEdit이
기록하지만 게임의 종류 판정 기준으로 사용되지 않으므로 도메인 모델의
`hasUnitFlag`만 보고 참조 경로를 선택하지 않는다. `isSpriteUnitDisabled`도 표시
상태 진단에만 사용한다. 참조 해석기는 원시 레코드를 바꾸지 않고 `object kind`,
원본 ID, 해석된 sprite/image ID, 그래픽 경로 또는 구조화된 실패 사유만 반환해야
한다.

첫 대표 프레임은 `images.dat`가 가리키는 GRP의 프레임 0으로 정의한다. 프레임 0이
편집기 식별에 부적절한 객체와 방향·iscript 기반 프레임 선택은 별도 정책 항목에서
확장한다. 알 수 없는 ID, 범위를 벗어난 참조, 빈 경로와 누락 파일은 모두 현재 위치
마커로 대체한다.

참조 근거:

- [PyMS](https://github.com/poiuyqwert/PyMS)의 `UnitsDAT`, `FlingyDAT`,
  `SpritesDAT`, `ImagesDAT` 정의와 `PyICE` 연결 코드
- [Chkdraft](https://github.com/TheNitesWhoSay/Chkdraft)의 `Chk::Sprite::isUnit`과
  객체 렌더 참조 해석 코드
- [Animosity](https://github.com/neivv/animosity)의 `.anim`/GRP 연결 및 해상도
  설명

## 포맷과 단계별 지원 범위

### 1단계: 클래식 GRP

- CascLib로 필요한 DAT/TBL/GRP만 메모리에 읽는다.
- DAT/TBL 참조와 모든 오프셋·길이를 읽기 전에 검증한다.
- GRP 헤더와 프레임 오프셋을 검증한 뒤 픽셀 인덱스를 디코딩한다.
- 팔레트 및 player color 정책을 적용해 RGBA 대표 프레임을 만든다.
- GRP의 폭·높이와 프레임 오프셋을 이용해 맵 좌표 중심에 배치한다.

GRP는 첫 화면 표시를 구현하기에 범위가 작고, Remastered에서도 SD 프레임의
크기·중심 및 클릭 가능 영역을 정하는 데 사용되는 것으로 Animosity 문서에서
확인된다.

### 2단계: Remastered ANIM

`anim/main_NNN.anim`, `HD2/anim/main_NNN.anim`, `SD/mainSD.anim`과
`images.rel`의 연결을 지원한다. ANIM은 diffuse와 team color를 포함해 최대 7개
레이어가 존재할 수 있고 HD와 HD2의 대응 관계도 유지해야 한다. 따라서 클래식
경로의 fallback·cache·취소 동작을 검증한 뒤 별도 decoder로 추가한다.

Carbot 같은 대체 스킨과 완전한 iscript 애니메이션 재생은 M6.1의 초기 범위에서
제외한다.

## 버전 대응과 실패 정책

- 설치 검사는 제품 코드 `s1`과 helper가 얻은 빌드 번호를 진단 정보로 기록한다.
- 빌드 번호에 따라 파일 경로나 테이블 길이를 추측하지 않는다.
- 요청 시 필수 파일의 존재, DAT 엔트리 범위, TBL 문자열 종료, 그래픽 오프셋과
  압축 행 길이를 각각 검증한다.
- 알려진 경로가 없거나 새 포맷이면 `unsupportedAssetVersion` 또는 더 구체적인
  비차단 오류를 반환하고 위치 마커를 유지한다.
- 캐시는 설치 경로, 빌드 번호, 렌더 정책 및 그래픽 ID를 키에 포함한다. 설치가
  바뀌면 이전 결과를 재사용하지 않는다.
- 객체 자산 실패는 맵 열기·편집·Save As를 막거나 CHK 원시 바이트를 변경하지
  않는다.

## 라이선스와 배포 경계

이 절은 법률 자문이 아니라 프로젝트의 보수적인 배포 정책이다.

- [CascLib](https://github.com/ladislav-zezula/CascLib)는 MIT이고 현재 helper는
  고정 revision과 고지문을 함께 관리한다.
- 조사에 참고한 [PyMS](https://github.com/poiuyqwert/PyMS)는 MIT,
  [Animosity](https://github.com/neivv/animosity)는 Apache-2.0이다. 소스 또는
  실질적인 구현을 가져올 경우 해당 저작권·라이선스·NOTICE 의무를 별도로 검토하고
  third-party notices에 추가한다.
- StarCraft 데이터는 사용자가 보유한 로컬 설치에서 표시 목적으로 런타임에만
  읽는다. 원본 또는 디코딩된 게임 자산을 저장소, 설치 패키지, 테스트 픽스처,
  원격 서비스에 포함하지 않는다.
- 기본 cache는 프로세스 수명 안의 메모리 cache로 제한한다. 영구 cache나 이미지
  내보내기는 별도 법률·제품 검토 전에는 제공하지 않는다.
- 애플리케이션 삭제나 cache 정리 작업이 StarCraft 설치 파일을 수정·삭제해서는
  안 된다.
- 공개 배포 전에는 최신 [Blizzard EULA](https://www.blizzard.com/legal)를 다시
  검토한다.

## 다음 구현 입력

[ADR-0007](../decisions/0007-object-sprite-atlas-protocol.md)은 이 조사 결과를
protocol 3의 `renderObjectAtlas`, 가변 RGBA envelope와 구조화된 부분 fallback
계약으로 확정했다. native `ObjectSpriteReference`는 `THG2`에서 변환된
unit/sprite 종류와 ID를 받아 classic DAT의 참조 열, 1-based `images.tbl` ID와
정규화된 `unit\\*.grp` 경로를 해석한다. 다음 M6.1 구현은 이 경로의 GRP frame
0을 RGBA로 변환하고 envelope를 검증한다. 파일 경로와 원시 게임 바이트는
Flutter 계층에 노출하지 않는다.
