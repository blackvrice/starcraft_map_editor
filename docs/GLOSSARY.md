# 용어집

## 게임과 맵

**StarCraft: Remastered (SC:R)**

이 프로젝트가 우선 대상으로 삼는 StarCraft 리마스터 버전.

**UMS (Use Map Settings)**

맵에 저장된 플레이어, 트리거, 게임 설정을 사용하는 게임 유형.

**`.scm` / `.scx`**

StarCraft 맵 파일 확장자. 내부 맵 데이터와 자원을 담는 아카이브로 취급한다.

**MPQ**

StarCraft 맵 컨테이너에 사용되는 아카이브 형식. 이 프로젝트에서는 구체 구현을 `MapArchiveGateway` 뒤에 둔다.

**`scenario.chk` / CHK**

맵의 지형, 객체, 플레이어, 문자열, 트리거 등을 섹션 단위로 저장하는 핵심 데이터.

**CHK 섹션**

4바이트 이름, 길이, 페이로드로 구성되는 CHK 데이터 단위.

**보호된 맵 / 잠긴 맵**

일반 편집기가 읽거나 수정하기 어렵게 의도적으로 변형된 맵. 초기 지원 대상이 아니다.

## EUD

**EUD (Extended Unit Deaths)**

StarCraft 트리거의 deaths 기반 메모리 접근을 확장해 고급 로직을 구현하는 제작 기법.

**eudplib**

StarCraft UMS/EUD 트리거 생성과 epScript를 제공하는 Python 도구 라이브러리.

**euddraft**

eudplib 코드와 플러그인을 기준 맵에 적용해 EUD 맵을 생성하는 빌드 도구.

**epScript**

eudplib에서 제공하는 JavaScript와 유사한 EUD 트리거 스크립트 언어.

**기준 맵 (base map)**

EUD 빌드가 입력으로 사용하는 원본 맵. 빌드 과정에서 불변으로 취급한다.

**빌드 프로필**

게임 대상, 컴파일러 종류와 버전, 옵션을 묶은 설정.

## 에디터

**Raw CHK 모델**

섹션 순서, 중복, 이름, 페이로드 바이트를 의미 해석과 별개로 보존하는 모델.

**Typed view**

특정 CHK 섹션을 지형, 유닛, 문자열 같은 도메인 값으로 해석한 편집용 투영.

**무손실 왕복 (lossless round-trip)**

파일을 읽고 변경 없이 다시 썼을 때 원본 데이터가 바뀌지 않는 성질.

**Byte-exact round-trip**

무손실 왕복 중에서도 출력 바이트가 입력과 정확히 같은 경우.

**Save As**

원본과 다른 출력 경로에 새 맵을 저장하는 기본 저장 방식.

**문서 세션**

열린 맵, 원본 경로, 변경 상태, Undo/Redo, 마지막 저장과 빌드 정보를 묶은 실행 중 상태.

**Fingerprint**

외부 변경과 원본 불변을 확인하기 위해 파일 크기, 수정 시각, 해시 등을 조합한 식별 정보.

**진단 (Diagnostic)**

단계, 심각도, 오류 코드, 파일/바이트/소스 위치와 해결 정보를 가진 구조화된 메시지.

**픽스처 (Fixture)**

파서, 저장, 빌드 테스트를 반복 가능하게 만드는 고정 입력 데이터.

**수직 기능 (vertical slice)**

UI부터 파일/도구 연동과 실제 결과까지 이어지는 작은 완성 흐름.

**ADR (Architecture Decision Record)**

중요한 기술 결정의 배경, 선택, 대안, 결과를 기록하는 문서.
