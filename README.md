# StarCraft Map Editor

Windows용 StarCraft: Remastered UMS 맵 에디터를 만드는 오픈 소스 프로젝트입니다. Flutter 기반 데스크톱 UI, 무손실 `scenario.chk` 편집, 일반 트리거 편집, epScript/euddraft 기반 EUD 빌드 환경을 하나의 작업 흐름으로 제공하는 것을 목표로 합니다.

> 현재 상태: M0~M6.1의 당시 범위를 완료했고 M6.2 시각적 배치를 진행 중입니다.
> 안전한 맵 열기·Save As, CHK 보존, 실제 지형·객체 렌더링과 편집,
> 검증형 EUD 빌드 기반을 구현했습니다. EUD 프로젝트 설정 UI와 소스 파일
> 입출력, 기본 맵 설정 화면, EUD 확장 탭과 일반 트리거 편집은 후속 개발 범위입니다.
> 자세한 구현 상태와 다음 작업은 [개발 계획](docs/DEVELOPMENT_PLAN.md)을 따릅니다.

## 목표

- 보호되지 않은 `.scm`/`.scx` 맵 열기와 안전한 Save As
- 지형, 유닛, 로케이션, 플레이어, 세력, 문자열 편집
- 유닛·업그레이드·테크 기본 설정과 검증된 EUD 확장 탭
- 일반 트리거·미션 브리핑 편집과 원시 트리거 확인
- epScript 코드 편집, euddraft 빌드, 진단 메시지 표시
- 알 수 없는 CHK 섹션과 원본 데이터를 가능한 한 그대로 보존
- 자동 백업, 충돌 감지, 검증을 통한 맵 손상 방지

## 기술 방향

- **UI:** Flutter for Windows
- **애플리케이션/도메인:** Dart
- **맵 아카이브:** MPQ 어댑터 뒤의 번들 StormLib helper 프로세스
- **맵 데이터:** 순서와 원시 바이트를 보존하는 `scenario.chk` 모델
- **EUD:** euddraft/eudplib를 별도 프로세스로 실행하는 어댑터

세부 설계와 범위는 [문서 인덱스](docs/README.md)에서 확인할 수 있습니다.

## 개발 시작

Flutter `3.44.8` stable을 기준으로 사용합니다. FVM을 사용하는 경우 저장소의 `.fvmrc`가 같은 버전을 선택하며, CI도 동일한 버전을 설치합니다.

```powershell
flutter pub get
dart format --output=none --set-exit-if-changed lib test tool
flutter analyze
flutter test
flutter run -d windows
```

다음 구현 항목은 [개발 계획](docs/DEVELOPMENT_PLAN.md)의 첫 번째 미완료 체크박스를 기준으로 선택합니다.

## 외부 프로젝트

- [eudplib](https://github.com/armoha/eudplib): StarCraft UMS/EUD 맵 도구 라이브러리
- [euddraft](https://github.com/armoha/euddraft): StarCraft: Remastered 중심의 EUD 빌드 도구
- [StormLib](https://github.com/ladislav-zezula/StormLib): MPQ 아카이브 라이브러리
- [CascLib](https://github.com/ladislav-zezula/CascLib): 로컬 StarCraft CASC 데이터 읽기 라이브러리
- [Chkdraft](https://github.com/TheNitesWhoSay/Chkdraft): 오픈 소스 StarCraft 맵 에디터 참고 구현

외부 프로젝트의 코드를 포함하거나 바이너리를 배포할 때는 각 라이선스와 고지 의무를 별도로 검토합니다.

## 프로젝트 고지

이 프로젝트는 Blizzard Entertainment와 제휴하거나 승인받은 공식 도구가 아닙니다. StarCraft 및 관련 명칭은 해당 권리자의 자산입니다.

## 라이선스

이 프로젝트는 [MIT License](LICENSE)로 배포됩니다. 외부 도구와 바이너리는 각각의 라이선스를 따릅니다.
