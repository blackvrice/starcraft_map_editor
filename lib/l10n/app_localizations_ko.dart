// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Korean (`ko`).
class AppLocalizationsKo extends AppLocalizations {
  AppLocalizationsKo([String locale = 'ko']) : super(locale);

  @override
  String get appTitle => 'StarCraft 맵 에디터';

  @override
  String get menuFile => '파일';

  @override
  String get menuNewMap => '새 맵…';

  @override
  String get menuOpenMap => '맵 열기…';

  @override
  String get menuPrepareEudBuild => 'EUD 빌드 준비…';

  @override
  String get menuEudTools => 'EUD 도구…';

  @override
  String get menuSaveAs => '다른 이름으로 저장…';

  @override
  String get menuMapInformation => '맵 정보…';

  @override
  String get menuPlayerSettings => '플레이어 설정…';

  @override
  String get menuForceSettings => '세력 설정…';

  @override
  String get menuUnitSettings => '유닛 설정…';

  @override
  String get menuUnitAvailability => '유닛 생산 허용…';

  @override
  String get menuUpgradeSettings => '업그레이드 설정…';

  @override
  String get menuTechSettings => '테크 설정…';

  @override
  String get menuMapSettings => '맵 설정…';

  @override
  String get menuClose => '닫기';

  @override
  String get menuEdit => '편집';

  @override
  String get menuUndo => '실행 취소';

  @override
  String get menuRedo => '다시 실행';

  @override
  String get menuSettings => '설정…';

  @override
  String get menuLanguage => '언어';

  @override
  String get menuView => '보기';

  @override
  String get menuResetLayout => '레이아웃 초기화';

  @override
  String get menuEud => 'EUD';

  @override
  String get menuNewEpScript => '새 epScript';

  @override
  String get menuBuildEudMap => 'EUD 맵 빌드';

  @override
  String get menuCancelEudBuild => 'EUD 빌드 취소';

  @override
  String get menuHelp => '도움말';

  @override
  String get menuDocumentation => '문서';

  @override
  String get menuAbout => '정보';

  @override
  String languageSystem(String language) {
    return '시스템 언어 따르기 ($language)';
  }

  @override
  String get languageTooltip => '표시 언어';

  @override
  String get languageSaveFailed => '언어는 바로 적용됐지만 다음 실행을 위해 저장하지 못했어요.';

  @override
  String get toolbarOpenMap => '맵 열기';

  @override
  String get toolbarSaveAs => '다른 이름으로 저장';

  @override
  String get toolbarNewEpScript => '새 epScript';

  @override
  String get toolbarBuildEud => 'EUD 빌드';

  @override
  String get toolbarCancelBuild => '빌드 취소';

  @override
  String get documentUnsaved => '저장 안 된 변경 있음';

  @override
  String get documentSaved => '저장할 변경 없음';

  @override
  String get assetsChecking => '데이터 확인 중';

  @override
  String get assetsCheckingShort => '확인 중';

  @override
  String get assetsReady => '데이터 준비됨';

  @override
  String get assetsReadyShort => '준비됨';

  @override
  String get assetsNotConfigured => '데이터 설정 필요';

  @override
  String get assetsNotConfiguredShort => '설정 필요';

  @override
  String get assetsUnavailable => '데이터 없음';

  @override
  String get assetsUnavailableShort => '없음';

  @override
  String environmentBadge(String status) {
    return 'Windows • SC:R • $status';
  }

  @override
  String environmentBadgeCompact(String status) {
    return 'SC:R • $status';
  }

  @override
  String environmentBadgeTooltip(String status) {
    return 'StarCraft 데이터 설정 열기 • $status';
  }

  @override
  String get railLabel => '작업 공간';

  @override
  String get railMap => '맵';

  @override
  String get railCatalog => '카탈로그';

  @override
  String get railMapSettings => '맵 설정';

  @override
  String get railTriggers => '트리거';

  @override
  String get railResources => '리소스';

  @override
  String get railBriefing => '브리핑';

  @override
  String get railEudProject => 'EUD 프로젝트';

  @override
  String railUnsavedTooltip(String name) {
    return '$name • 저장 안 된 변경 있음';
  }

  @override
  String get paneProjectSources => '프로젝트 / 소스';

  @override
  String get paneProjectLayers => '프로젝트 / 레이어';

  @override
  String get paneLayersPalette => '레이어 / 오브젝트 팔레트';

  @override
  String get paneInspector => '속성';

  @override
  String get emptyLayers => '맵을 열면 레이어가 여기에 표시돼요.';

  @override
  String get emptyInspector => '맵에서 오브젝트를 선택하면 속성을 보고 고칠 수 있어요.';

  @override
  String get sourceDraft => '초안';

  @override
  String get sourceEpScript => 'epScript 소스';

  @override
  String get inspectorFile => '파일';

  @override
  String get inspectorLocation => '위치';

  @override
  String get inspectorLines => '줄 수';

  @override
  String get inspectorCharacters => '글자 수';

  @override
  String get inspectorRevision => '리비전';

  @override
  String get inspectorState => '상태';

  @override
  String get stateModified => '수정됨';

  @override
  String get stateClean => '저장됨';

  @override
  String get inMemoryDraft => '저장 전 초안';

  @override
  String get startTitle => '맵을 열어 시작하세요';

  @override
  String get startBody =>
      '보호되지 않은 StarCraft: Remastered UMS 맵(.scm, .scx)을 열 수 있어요. 원본 파일은 덮어쓰지 않고, 편집 내용은 \'다른 이름으로 저장\'으로 저장해요.';

  @override
  String get startShortcutHint => '단축키: Ctrl+O';

  @override
  String get recentMaps => '최근 맵';

  @override
  String get recentMapsLoadFailed => '최근 맵 목록을 불러오지 못했어요.';

  @override
  String get recentMapsEmpty => '연 맵이 여기에 표시돼요.';

  @override
  String get recentMapsRemove => '최근 목록에서 제거';

  @override
  String get untitledMap => '제목 없는 맵';

  @override
  String get notSavedYet => '아직 저장 안 됨';

  @override
  String get mapSizeUnavailable => '크기 정보 없음';

  @override
  String get mapTilesetUnavailable => '타일셋 정보 없음';

  @override
  String mapTilesetRaw(String value) {
    return '타일셋 $value';
  }

  @override
  String get mapGeometryPreview => '경계만 미리보기';

  @override
  String mapMtxmTiles(int count) {
    return 'MTXM 타일 $count개';
  }

  @override
  String get mapNavigationHelp => '휠: 확대/축소 · Space/가운데 버튼 드래그: 이동';

  @override
  String mapPickPriority(String order) {
    return '선택 순서 $order';
  }

  @override
  String mapPlacing(String label) {
    return '$label 배치 중 · Esc 취소';
  }

  @override
  String get mapCreatingLocation => '드래그해서 새 로케이션 만들기 · Esc 취소';

  @override
  String mapProblemCounts(int blocking, int warnings) {
    return '차단 $blocking · 경고 $warnings';
  }

  @override
  String get mapCanvasUnavailable => '캔버스를 표시하려면 크기가 0이 아닌 DIM 섹션이 하나만 있어야 해요.';

  @override
  String get sessionRestricted => '제한 편집';

  @override
  String get sessionModified => '수정됨';

  @override
  String get sessionEditable => '편집 가능';

  @override
  String get sessionReadOnly => '읽기 전용 미리보기';

  @override
  String get sessionRestrictedHelp => '일부 맵 데이터를 확인할 수 없어 안전한 편집만 허용해요.';

  @override
  String get sessionModifiedHelp =>
      '아직 저장하지 않은 편집이 있어요. \'다른 이름으로 저장\'으로 보관하세요.';

  @override
  String get sessionEditableHelp => '이 맵은 편집할 수 있어요. 사본을 저장하기 전에는 원본이 바뀌지 않아요.';

  @override
  String get sessionReadOnlyHelp => '이 맵은 보기 전용으로 열렸어요.';

  @override
  String get objectCancelLocation => '로케이션 취소';

  @override
  String get objectNewLocation => '새 로케이션';

  @override
  String get objectDelete => '삭제';

  @override
  String get objectUndo => '실행 취소';

  @override
  String get objectRedo => '다시 실행';

  @override
  String get objectSelectHint => '클릭하거나 드래그해서 오브젝트 선택';

  @override
  String objectSelectedMove(int count) {
    return '$count개 선택됨 · 드래그해서 이동';
  }

  @override
  String objectUndoAction(String label) {
    return '실행 취소: $label';
  }

  @override
  String objectRedoAction(String label) {
    return '다시 실행: $label';
  }

  @override
  String get objectShortcutHint => 'Ctrl/Shift 클릭: 선택 추가 · Delete: 삭제';

  @override
  String get terrainSelectSource => '칠할 원본 타일을 먼저 고르세요';

  @override
  String terrainRawTile(String raw, String group, String member) {
    return '원시 타일 $raw · 그룹 $group · 멤버 $member';
  }

  @override
  String get terrainUnsupportedSuffix => ' · 미지원';

  @override
  String terrainFromSuffix(String x, String y) {
    return ' · 위치 $x,$y';
  }

  @override
  String get terrainToolSelect => '타일 선택';

  @override
  String get terrainToolBrush => '브러시';

  @override
  String get terrainToolRectangle => '사각형';

  @override
  String get terrainScope => 'MTXM만 편집 · TILE/ISOM 보존';

  @override
  String get paletteTitle => '오브젝트 팔레트';

  @override
  String get paletteCatalogTooltip => '새 타일·두다드·유닛·스프라이트 배치';

  @override
  String get paletteCancelTooltip => '배치 취소 (Esc)';

  @override
  String get paletteSearchHint => '종류 또는 #ID 검색';

  @override
  String paletteClickToPlace(String label) {
    return '$label: 맵을 클릭해 배치';
  }

  @override
  String get paletteEmpty => '이 맵에 복제할 오브젝트가 없어요. + 버튼으로 카탈로그를 여세요.';

  @override
  String get paletteNoMatch => '검색과 일치하는 항목이 없어요.';

  @override
  String get layerTerrain => '지형';

  @override
  String get layerLocations => '로케이션';

  @override
  String get layerDoodads => '두다드';

  @override
  String get layerSprites => '스프라이트';

  @override
  String get layerUnits => '유닛';

  @override
  String layerItems(int count) {
    return '$count개';
  }

  @override
  String layerHide(String layer) {
    return '$layer 숨기기';
  }

  @override
  String layerShow(String layer) {
    return '$layer 보이기';
  }

  @override
  String layerLock(String layer) {
    return '$layer 잠그기';
  }

  @override
  String layerUnlock(String layer) {
    return '$layer 잠금 풀기';
  }

  @override
  String get layerSelectionHint => '캔버스를 클릭하면 잠기지 않은 가장 위 오브젝트를 볼 수 있어요.';

  @override
  String layerObjectsSelected(int count) {
    return '오브젝트 $count개 선택됨';
  }

  @override
  String get inspectorSourcePath => '원본 경로';

  @override
  String get inspectorMapSize => '맵 크기';

  @override
  String get inspectorTileset => '타일셋';

  @override
  String get inspectorMapVersion => '맵 버전';

  @override
  String get inspectorScenarioType => '시나리오 유형';

  @override
  String get inspectorTerrain => '지형';

  @override
  String get inspectorArchiveSize => '아카이브 크기';

  @override
  String get inspectorEntries => '파일 항목';

  @override
  String get inspectorChkSize => 'CHK 크기';

  @override
  String get inspectorChkSections => 'CHK 섹션';

  @override
  String get inspectorDiagnostics => '진단';

  @override
  String get valueUnavailable => '정보 없음';

  @override
  String valueUnknown(String value) {
    return '알 수 없음 ($value)';
  }

  @override
  String inspectorMtxmViews(int count) {
    return 'MTXM 뷰 $count개';
  }

  @override
  String inspectorRawTiles(int count) {
    return '원시 타일 $count개';
  }

  @override
  String inspectorEntriesListed(int listed, int total) {
    return '$listed개 표시 / 전체 $total개';
  }

  @override
  String get inspectorCommonLayers => '공통 레이어';

  @override
  String get inspectorMultiNotice =>
      '속성을 편집하려면 오브젝트 하나만 선택하세요. 이동과 삭제는 선택 전체에 적용돼요.';

  @override
  String get objectKindUnit => '유닛';

  @override
  String get objectKindDoodad => '두다드';

  @override
  String get objectKindSprite => '스프라이트';

  @override
  String get objectKindLocation => '로케이션';

  @override
  String get fieldTypeId => '종류 ID';

  @override
  String get objectPlacedOnlyNotice =>
      '배치된 이 오브젝트에만 적용돼요. 맵 전체의 유닛 종류·플레이어·게임 설정은 파일 → 맵 설정에서 바꾸세요.';

  @override
  String get fieldX => 'X (px)';

  @override
  String get fieldY => 'Y (px)';

  @override
  String get fieldOwnerRaw => '소유자 (원시값 0-255)';

  @override
  String get fieldHitpointPercent => '체력 %';

  @override
  String get fieldShieldPercent => '실드 %';

  @override
  String get fieldEnergyPercent => '에너지 %';

  @override
  String get fieldResourceAmount => '자원량';

  @override
  String get fieldHangarAmount => '격납 수';

  @override
  String get fieldDoodadEnabledRaw => '활성 원시값 (0=예, 1=아니오)';

  @override
  String get applyProperties => '속성 적용';

  @override
  String get enterWholeNumber => '정수를 입력하세요.';

  @override
  String get propertiesApplied => '속성을 적용했어요.';

  @override
  String get propertiesNoChanges => '바뀐 속성이 없어요.';

  @override
  String get fixHighlightedFields => '표시된 칸을 고쳐 주세요.';

  @override
  String get propertiesUnavailable => '지금은 속성을 편집할 수 없어요.';

  @override
  String get unlockToApply => '적용하려면 레이어 잠금을 풀고 편집 가능한 맵을 사용하세요.';

  @override
  String get rawFieldsTitle => '고급: 보존된 원시 필드';

  @override
  String get rawFieldsNotice => '원시 플래그와 예약 필드는 읽기 전용이며 바이트 그대로 보존돼요.';

  @override
  String get rawClassId => '클래스 ID';

  @override
  String get rawRelationFlags => '관계 플래그';

  @override
  String get rawValidStateFlags => '유효 상태 플래그';

  @override
  String get rawValidFieldFlags => '유효 필드 플래그';

  @override
  String get rawStateFlags => '상태 플래그';

  @override
  String get rawUnused => '미사용';

  @override
  String get rawRelationClassId => '관계 클래스 ID';

  @override
  String get rawFlags => '플래그';

  @override
  String locationTitle(String id) {
    return '로케이션 $id';
  }

  @override
  String get fieldName => '이름';

  @override
  String get fieldLeft => '왼쪽';

  @override
  String get fieldTop => '위';

  @override
  String get fieldRight => '오른쪽';

  @override
  String get fieldBottom => '아래';

  @override
  String get applyLocation => '로케이션 적용';

  @override
  String get locationApplied => '로케이션을 적용했어요.';

  @override
  String get locationNoChanges => '바뀐 내용이 없어요.';

  @override
  String get locationUnavailable => '지금은 로케이션을 편집할 수 없어요.';

  @override
  String get inspectorStringId => '문자열 ID';

  @override
  String get inspectorElevationFlags => '고도 플래그';

  @override
  String get locationNamingUnavailable => '이 맵에서는 로케이션 이름을 바꿀 수 없어요.';

  @override
  String get locationRenameNotice =>
      '이름을 바꾸면 새 문자열 ID를 쓰므로 다른 곳에서 공유하는 문자열은 바뀌지 않아요.';

  @override
  String get tabProblems => '문제';

  @override
  String get tabOutput => '출력';

  @override
  String get tabBuildLog => '빌드 로그';

  @override
  String tabWithCount(String label, int count) {
    return '$label ($count)';
  }

  @override
  String get noProblems => '발견된 문제가 없어요';

  @override
  String get noOutput => '아직 작업 기록이 없어요';

  @override
  String get severityError => '오류';

  @override
  String get severityWarning => '경고';

  @override
  String get severityInfo => '정보';

  @override
  String problemsSummary(int errors, int warnings, int infos) {
    return '오류 $errors · 경고 $warnings · 정보 $infos';
  }

  @override
  String get buildNotConfigured => '빌드 설정이 아직 준비되지 않았어요';

  @override
  String get buildReady => '빌드할 준비가 됐어요';

  @override
  String get buildStarting => 'euddraft 시작 중…';

  @override
  String get buildStopping => 'euddraft 중지 중…';

  @override
  String get buildFinalizing => '출력 파일 검증·반영 중…';

  @override
  String get buildCompleted => '빌드 완료';

  @override
  String get buildFailedNoOutput => '출력 없이 빌드가 실패했어요';

  @override
  String get buildCancelled => '빌드 취소됨';

  @override
  String logBuildId(String id) {
    return '빌드: $id';
  }

  @override
  String logTool(String version) {
    return '도구: euddraft $version';
  }

  @override
  String logExitCode(String code) {
    return '종료 코드 $code';
  }

  @override
  String get logExitCodeUnavailable => '종료 코드 없음';

  @override
  String logStarted(String time) {
    return '시작: $time';
  }

  @override
  String logCompleted(String time) {
    return '완료: $time';
  }

  @override
  String get recordRunning => '실행 중';

  @override
  String get recordSucceeded => '성공';

  @override
  String get recordFailed => '실패';

  @override
  String get recordCancelled => '취소됨';

  @override
  String get statusReady => '준비';

  @override
  String get statusNoDocument => '열린 문서 없음';

  @override
  String statusDocument(String name, String state) {
    return '$name • $state';
  }

  @override
  String get phaseQueued => '대기 중';

  @override
  String get phaseReading => '읽는 중';

  @override
  String get phaseParsing => '분석 중';

  @override
  String get phaseValidating => '검증 중';

  @override
  String get phaseWriting => '쓰는 중';

  @override
  String get phaseCompiling => '컴파일 중';

  @override
  String get phaseVerifying => '확인 중';

  @override
  String get phaseSucceeded => '완료';

  @override
  String get phaseFailed => '실패';

  @override
  String get phaseCancelled => '취소됨';

  @override
  String get triggersOrdinary => '일반 트리거';

  @override
  String get triggersEudExtensions => 'EUD 확장';

  @override
  String get triggersOpenEudProject => '규칙을 만들고 저장·빌드하려면 EUD 프로젝트를 여세요';

  @override
  String get triggersUndoProject => '프로젝트 실행 취소';

  @override
  String get triggersRedoProject => '프로젝트 다시 실행';

  @override
  String get triggersEudUnavailable => 'EUD 프로젝트 작업 공간을 사용할 수 없어요.';

  @override
  String get terrainDataTitle => '에디터 지형 데이터';

  @override
  String get terrainDataProtected => 'EUD 보호 마커 — ISOM 격자가 아님';

  @override
  String get terrainDataIsomPresent => 'ISOM 있음 — 지형 생성 검증 전';

  @override
  String get terrainDataNoIsom => 'ISOM 없음 — 원시 타일 편집';

  @override
  String terrainDataBytes(int actual, String expected) {
    return '$actual바이트 / 예상 $expected';
  }

  @override
  String get terrainDataStructureOnly => '크기 일치 — 지형 의미는 검증하지 않음';

  @override
  String get terrainDataInvalidSize => '크기 불일치 — 원본 바이트 보존';

  @override
  String get terrainDataUnknownDimensions => '유일하고 유효한 DIM 섹션이 필요함';

  @override
  String terrainDataDuplicates(String names) {
    return '중복 섹션: $names. 사용할 사본을 임의로 선택하지 않음.';
  }

  @override
  String get terrainDataComparisonUnavailable => 'MTXM / TILE 비교 불가';

  @override
  String terrainDataDifference(int count) {
    return 'MTXM / TILE 차이: $count칸. 차이가 있다고 손상된 것은 아닙니다.';
  }

  @override
  String get terrainDataDoodads => '두다드가 있어 게임 지형과 에디터 타일이 다를 수 있습니다.';

  @override
  String get terrainDataReadOnly =>
      '읽기 전용 검사입니다. 원시 브러시는 MTXM만 변경하고 TILE/ISOM은 보존합니다. 등각 지형·경사로 생성은 아직 지원하지 않습니다.';

  @override
  String get newMapTitle => '새 맵 만들기';

  @override
  String get newMapStepBasics => '크기와 지형';

  @override
  String get newMapStepPlayers => '플레이어';

  @override
  String get newMapStepReview => '확인하고 만들기';

  @override
  String get newMapStepCurrent => '지금 단계';

  @override
  String get newMapSideNote =>
      '크기는 나중에 파일 → 맵 크기 변경에서 바꿀 수 있어요. 새 맵은 “다른 이름으로 저장”으로 처음 저장해요.';

  @override
  String get newMapName => '맵 이름';

  @override
  String get newMapDefaultTitle => '제목 없는 시나리오';

  @override
  String get newMapDescription => '설명 (선택)';

  @override
  String get newMapSize => '크기';

  @override
  String get newMapSizeSmall => '작게';

  @override
  String get newMapSizeSmallNote => '1:1 연습';

  @override
  String get newMapSizeCompact => '조금 작게';

  @override
  String get newMapSizeCompactNote => '2인';

  @override
  String get newMapSizeMedium => '보통';

  @override
  String get newMapSizeMediumNote => '4인 추천';

  @override
  String get newMapSizeLarge => '크게';

  @override
  String get newMapSizeLargeNote => '6~8인';

  @override
  String get newMapSizeHuge => '아주 크게';

  @override
  String get newMapSizeHugeNote => '대형 UMS';

  @override
  String get newMapSizeCustom => '직접 입력';

  @override
  String get newMapSizeCustomNote => '최대 256';

  @override
  String get newMapWidth => '가로 (타일)';

  @override
  String get newMapHeight => '세로 (타일)';

  @override
  String newMapSizeValue(int width, int height) {
    return '$width × $height';
  }

  @override
  String get newMapTileset => '타일셋';

  @override
  String get newMapTilesetHint => '맵 전체의 분위기예요. 만든 뒤에는 바꿀 수 없어요.';

  @override
  String get tilesetBadlands => '배드랜드';

  @override
  String get tilesetSpacePlatform => '우주 정거장';

  @override
  String get tilesetInstallation => '설치 기지';

  @override
  String get tilesetAshworld => '잿빛 세계';

  @override
  String get tilesetJungle => '정글';

  @override
  String get tilesetDesert => '사막';

  @override
  String get tilesetIce => '얼음';

  @override
  String get tilesetTwilight => '황혼';

  @override
  String get newMapInitialTile => '처음 깔 타일';

  @override
  String get newMapInitialTileHint =>
      '맵 전체를 이 원시 타일로 채워요. ISOM 지형은 만들지 않으므로 이동 가능 여부는 보장되지 않아요.';

  @override
  String get newMapTileRequired => '맵을 만들려면 처음 깔 타일을 골라 주세요.';

  @override
  String get newMapTilesLoading => 'StarCraft 데이터에서 타일을 불러오는 중…';

  @override
  String newMapTilePage(int first, int last, int total) {
    return '$total개 중 $first–$last';
  }

  @override
  String get newMapPrevious => '이전';

  @override
  String get newMapNext => '다음';

  @override
  String get newMapReload => '다시 불러오기';

  @override
  String get newMapPlayersTitle => '몇 명이 플레이하나요?';

  @override
  String get newMapPlayersHint =>
      '사람 플레이어마다 테란 시작 위치를 만들어요. 종족과 슬롯은 나중에 플레이어 설정에서 바꿀 수 있어요.';

  @override
  String newMapPlayersValue(int players) {
    return '$players명';
  }

  @override
  String get newMapReviewTitle => '이렇게 만들어요';

  @override
  String get newMapReviewFormat => '브루드 워 UMS (.scx)';

  @override
  String get newMapReviewNoTriggers => '승리·자원 트리거는 넣지 않아요. 트리거 화면에서 추가하세요.';

  @override
  String newMapReviewTile(String tile) {
    return '처음 타일 #$tile';
  }

  @override
  String get newMapReviewNoTile => '처음 타일을 아직 고르지 않았어요';

  @override
  String get newMapCancel => '취소';

  @override
  String get newMapBack => '이전';

  @override
  String get newMapContinue => '다음';

  @override
  String get newMapCreate => '만들기';

  @override
  String get newMapDiscardTitle => '저장 안 된 맵 변경을 버릴까요?';

  @override
  String get newMapDiscardBody => '새 맵을 만들면 지금 문서가 바뀌어요. 변경을 남기려면 먼저 저장하세요.';

  @override
  String get newMapKeepCurrent => '지금 맵 유지';

  @override
  String get newMapDiscardAndCreate => '버리고 만들기';

  @override
  String get catalogTitle => '배치할 항목';

  @override
  String get catalogKindTile => '지형 타일';

  @override
  String get catalogKindDoodad => '두다드';

  @override
  String get catalogKindUnit => '유닛';

  @override
  String get catalogKindSprite => '스프라이트';

  @override
  String get catalogKindSpriteUnit => '스프라이트 유닛';

  @override
  String get catalogCategories => '분류';

  @override
  String get catalogCategoryAll => '전체';

  @override
  String catalogTilesetTitle(String tileset) {
    return '$tileset 맵';
  }

  @override
  String get catalogTilesetHint => '이 맵의 타일셋에 맞는 항목만 보여줘요.';

  @override
  String get catalogSearchHint => '이름, #ID, 종류로 찾기 (예: 벙커, #125)';

  @override
  String get catalogBackToMap => '맵으로 돌아가기';

  @override
  String get catalogPlaceableOnly => '배치 가능한 것만';

  @override
  String catalogShownCount(int count) {
    return '$count개 표시';
  }

  @override
  String get catalogEmpty => '검색과 맞는 항목이 없어요.';

  @override
  String get catalogDetailEmpty => '항목을 고르면 자세한 정보와 배치 버튼이 보여요.';

  @override
  String catalogFootprint(int width, int height) {
    return '크기 $width × $height 타일';
  }

  @override
  String catalogFootprintOverlay(int width, int height) {
    return '크기 $width × $height 타일 + 오버레이';
  }

  @override
  String get catalogOwner => '누구의 것인가요?';

  @override
  String catalogOwnerPlayer(int count) {
    return '플레이어 $count';
  }

  @override
  String get catalogKeepPlacing => '클릭할 때마다 계속 배치';

  @override
  String get catalogHowTo => '배치 방법';

  @override
  String get catalogHowTo1 => '① 아래 버튼을 누르면 맵으로 돌아가요.';

  @override
  String get catalogHowTo2 => '② 윤곽이 보이는 곳을 클릭해 놓아요.';

  @override
  String get catalogHowTo3 => '③ 빨간 윤곽은 맵 밖이라 놓을 수 없어요. Esc로 취소해요.';

  @override
  String get catalogPlace => '맵에 배치하기';

  @override
  String get catalogCannotPlace => '이 항목은 배치할 수 없어요.';

  @override
  String get catalogIssueRelation => '애드온처럼 다른 건물이 필요한 유닛은 단독으로 배치할 수 없어요.';

  @override
  String get catalogIssueCapability => '로컬 게임 파일에서 유닛 정보를 읽지 못해 배치를 막아 두었어요.';

  @override
  String get catalogIssueGraphic =>
      '그래픽을 불러오지 못해, 보이지 않는 오브젝트가 생기지 않도록 막아 두었어요.';

  @override
  String get catalogIssueRecipe => '두다드 배치 정보가 불완전해 안전하게 놓을 수 없어요.';

  @override
  String catalogIssueCode(String code) {
    return '코드: $code';
  }

  @override
  String get buildStepsLabel => 'EUD 맵을 만드는 단계';

  @override
  String get buildStepMap => '맵 저장';

  @override
  String get buildStepMapNone => '열린 맵이 없어요';

  @override
  String get buildStepMapDirty => '저장 안 된 변경 · 다른 이름으로 저장';

  @override
  String get buildStepMapSaved => '저장됨';

  @override
  String get buildStepSource => '스크립트 저장';

  @override
  String get buildStepSourceUntitled => '파일로 저장해야 빌드할 수 있어요';

  @override
  String get buildStepSourceDirty => '아직 저장 안 됨';

  @override
  String get buildStepSourceSaved => '저장됨';

  @override
  String get buildStepPrepare => '빌드 준비';

  @override
  String get buildStepPrepareNeeded => '입력·출력 파일을 골라 주세요';

  @override
  String get buildStepPrepareReady => '준비됨';

  @override
  String get buildStepPrepareAction => '준비…';

  @override
  String get buildStepRun => '빌드';

  @override
  String get buildStepRunReady => '실행할 수 있어요';

  @override
  String get buildStepRunBusy => '빌드 중…';

  @override
  String get buildStepRunSucceeded => '성공';

  @override
  String get buildStepRunFailed => '실패 · 아래 결과를 확인하세요';

  @override
  String get buildStepRunCancelled => '취소됨';

  @override
  String get buildStepRunBlocked => '앞 단계를 먼저 마쳐 주세요';

  @override
  String get buildSafetyNote => '원본 맵은 절대 덮어쓰지 않아요';

  @override
  String get buildSummarySucceeded => 'EUD 맵을 만들었어요';

  @override
  String get buildSummaryFailed => '빌드하지 못했어요';

  @override
  String get buildSummaryCancelled => '빌드를 취소했어요';

  @override
  String get buildSummaryRunning => 'euddraft로 빌드하는 중…';

  @override
  String buildSummaryFirstError(String message) {
    return '첫 번째 문제: $message';
  }

  @override
  String buildSummaryAt(String location, String message) {
    return '$location: $message';
  }

  @override
  String get buildSummaryUnchanged => '원본 맵과 이전 출력 파일은 그대로예요.';

  @override
  String get buildSummaryRawLog => '아래는 euddraft 원문 로그예요';

  @override
  String get trigTitle => '트리거';

  @override
  String get trigBriefingTitle => '브리핑';

  @override
  String trigCount(int count) {
    return '$count개';
  }

  @override
  String get trigAdd => '새 트리거';

  @override
  String get trigAddBriefing => '새 브리핑';

  @override
  String get trigUndo => '실행 취소';

  @override
  String get trigRedo => '다시 실행';

  @override
  String get trigValidate => '참조 검사';

  @override
  String get trigSelectAll => '전체 선택 / 해제';

  @override
  String get trigOwners => '실행 대상…';

  @override
  String get trigEnableSelected => '선택 항목 켜기';

  @override
  String get trigDisableSelected => '선택 항목 끄기';

  @override
  String get trigAddText => '문구 추가…';

  @override
  String get trigSwitchNames => '스위치 이름…';

  @override
  String get trigUnitProperties => '유닛 속성…';

  @override
  String trigSelectedCount(int count) {
    return '$count개 선택됨';
  }

  @override
  String get trigHelp =>
      '트리거는 조건이 모두 맞을 때 액션을 실행해요. 새 트리거는 “실행 안 함” 조건으로 시작하므로 조건을 바꾸기 전에는 동작하지 않아요. 적용한 변경은 “다른 이름으로 저장”으로 저장돼요.';

  @override
  String get trigBriefingHelp =>
      '브리핑 액션은 게임 시작 전에 순서대로 실행돼요. 시간은 밀리초, 초상화 칸은 1~4예요. 소리는 리소스에서 추가하세요.';

  @override
  String get trigEmpty => '아직 트리거가 없어요. 새로 만들어 시작하세요.';

  @override
  String trigItemTitle(int count) {
    return '트리거 $count';
  }

  @override
  String trigBriefingItemTitle(int count) {
    return '브리핑 $count';
  }

  @override
  String get trigOn => '켜짐';

  @override
  String get trigOff => '꺼짐';

  @override
  String get trigNoOwner => '실행 대상 없음';

  @override
  String get trigWhen => '언제';

  @override
  String get trigThen => '그러면';

  @override
  String get trigNothing => '없음';

  @override
  String trigMore(int count) {
    return '외 $count개';
  }

  @override
  String get trigMoveUp => '위로';

  @override
  String get trigMoveDown => '아래로';

  @override
  String get trigDuplicate => '트리거 복제';

  @override
  String get trigDuplicateBriefing => '브리핑 복제';

  @override
  String get trigDelete => '트리거 삭제';

  @override
  String get trigDeleteBriefing => '브리핑 삭제';

  @override
  String trigDeleteTitle(String name) {
    return '$name을(를) 삭제할까요?';
  }

  @override
  String get trigDeleteBody =>
      '지원하지 않아 보존하던 칸까지 레코드 전체가 지워져요. 실행 취소로 되돌릴 수 있어요.';

  @override
  String get trigCancel => '취소';

  @override
  String get trigDeleteConfirm => '삭제';

  @override
  String get trigClose => '닫기';

  @override
  String get trigValidationTitle => '트리거 검사';

  @override
  String get trigValidationOk => '지원하는 칸의 값과 참조가 모두 올바라요. 원시/EUD 칸은 해석하지 않아요.';

  @override
  String get trigOwnersTitle => '선택한 트리거를 누가 실행할까요?';

  @override
  String get trigOwnersBriefingTitle => '선택한 브리핑을 누가 볼까요?';

  @override
  String get trigOwnersHelp =>
      '“그대로”는 각 트리거의 현재 설정을 유지해요. 바꾸려면 추가 또는 제거를 고르세요.';

  @override
  String get trigOwnerUnchanged => '그대로';

  @override
  String get trigOwnerAdd => '추가';

  @override
  String get trigOwnerRemove => '제거';

  @override
  String get trigApplyOwners => '실행 대상 적용';

  @override
  String get trigEditTitle => '트리거 편집';

  @override
  String get trigEditBriefingTitle => '브리핑 편집';

  @override
  String get trigDraftNote =>
      '“맵에 적용”을 누르기 전까지는 이 초안에만 남아요. 지원하지 않는 칸과 플래그는 바이트 그대로 보존돼요.';

  @override
  String get trigWho => '누구에게 실행할까요?';

  @override
  String get trigWhoHelp =>
      '선택한 플레이어마다 따로 검사해요. 조건과 액션의 “현재 플레이어”는 그 플레이어를 뜻해요.';

  @override
  String get trigEnabledChip => '트리거 사용';

  @override
  String get trigBriefingEnabledChip => '브리핑 사용';

  @override
  String get trigWhenAll => '아래 조건이 모두 맞으면';

  @override
  String get trigThenInOrder => '순서대로 실행해요';

  @override
  String get trigBriefingSteps => '진행 순서';

  @override
  String trigSlotCount(int current, int total) {
    return '$current / $total';
  }

  @override
  String get trigAddSlot => '추가';

  @override
  String get trigPreserved => '원시 데이터로 보존';

  @override
  String get trigSlotEnabled => '사용';

  @override
  String get trigSlotUp => '위로';

  @override
  String get trigSlotDown => '아래로';

  @override
  String get trigSlotDuplicate => '복제';

  @override
  String get trigSlotRemove => '제거';

  @override
  String get trigExplainTitle => '이렇게 동작해요';

  @override
  String trigExplainOwners(String owners) {
    return '$owners에게:';
  }

  @override
  String get trigExplainNoOwner => '아직 실행 대상이 없어서 이 트리거는 실행되지 않아요.';

  @override
  String get trigExplainNever => '“실행 안 함” 조건이 있어서 실행되지 않아요.';

  @override
  String get trigExplainAlways => '조건이 “항상”이라 바로 실행돼요.';

  @override
  String trigExplainConditions(int count) {
    return '조건 $count개가 모두 맞으면';
  }

  @override
  String get trigExplainNoConditions => '조건이 없으므로';

  @override
  String trigExplainActions(int count) {
    return '액션 $count개를 순서대로 실행해요.';
  }

  @override
  String get trigExplainOnce => '“트리거 유지”가 없으면 플레이어마다 한 번만 실행돼요.';

  @override
  String get trigExplainPreserve => '“트리거 유지”가 있어서 조건이 맞을 때마다 다시 실행돼요.';

  @override
  String get trigExplainDisabled => '꺼져 있어서 실행되지 않아요.';

  @override
  String get trigRawRecord => '고급: 원시 레코드 (읽기 전용)';

  @override
  String get trigApply => '맵에 적용';

  @override
  String get trigSlotAction => '액션';

  @override
  String get trigSlotCondition => '조건';

  @override
  String get trigSlotReplaceNote => '종류를 바꾸면 적용할 때 이 칸의 값이 새로 바뀌어요.';

  @override
  String get trigAlwaysDisplay => '항상 문구 표시';

  @override
  String get trigUseSlot => '이 칸 사용';

  @override
  String get eudProjectTitle => 'EUD 확장 프로젝트';

  @override
  String get eudProjectUnsavedSuffix => ' • 저장 안 됨';

  @override
  String get eudProjectLead =>
      '일반 맵 편집으로는 바꿀 수 없는 유닛·무기·업그레이드·플레이어 설정을 바꿔요. 값은 별도 프로젝트 파일에 저장되고 EUD 빌드를 거쳐야 게임에 들어가요.';

  @override
  String get eudNewFromMap => '현재 맵으로 새로 만들기';

  @override
  String get eudOpenProject => '프로젝트 열기';

  @override
  String get eudSaveProject => '프로젝트 저장';

  @override
  String get eudSaveProjectAs => '다른 이름으로 저장';

  @override
  String get eudUndoProject => '실행 취소';

  @override
  String get eudRedoProject => '다시 실행';

  @override
  String get eudCloseProject => '프로젝트 닫기';

  @override
  String get eudGenerationPreview => '생성 코드 미리보기';

  @override
  String get eudGenerationPreviewTitle => 'EUD 생성 코드 미리보기';

  @override
  String get eudGenerationPreviewNote =>
      '설정은 사용자 초기화보다 먼저 적용돼요. 규칙은 고른 트리거 전/후 시점에 실행되고, 개별 유닛 규칙은 지정한 유닛에만 적용돼요. 실제 게임 호환성은 아직 확인되지 않았어요.';

  @override
  String get eudClose => '닫기';

  @override
  String get eudCancel => '취소';

  @override
  String get eudDiscard => '버리기';

  @override
  String get eudDiscardTitle => 'EUD 프로젝트 변경을 버릴까요?';

  @override
  String get eudDiscardBody =>
      'EUD 프로젝트에 저장하지 않은 변경이 있어요. 남기려면 먼저 “다른 이름으로 저장”을 하세요.';

  @override
  String get eudWelcomeTitle => 'EUD 프로젝트로 할 수 있는 일';

  @override
  String get eudWelcomeChoose => '유닛·무기·업그레이드·테크·플레이어 값을 새로 골라요.';

  @override
  String get eudWelcomeSave => '프로젝트 파일에 저장해요. 맵 파일은 건드리지 않아요.';

  @override
  String get eudWelcomeBuild => 'EUD 맵을 새로 빌드해서 확인해요. 원본 맵은 그대로예요.';

  @override
  String get eudProjectSaveNote =>
      '프로젝트 저장은 EUD 설정만 보관하고 맵을 만들지 않아요. 일반 맵 변경은 맵의 “다른 이름으로 저장”으로 저장해요.';

  @override
  String get eudAllFieldsNote =>
      '“모든 EUD 필드 편집”에서 유닛·무기·이동·업그레이드·테크·플레이어·그래픽 설정을 열 수 있어요. EUD 빌드 준비에서 이 설정을 검증 전 테스트 빌드에 넣을 수 있고, 프로젝트를 저장하면 복구용 백업도 남아요.';

  @override
  String get eudBindingUnchecked => '맵 연결을 아직 확인하지 않았어요. “현재 맵 확인”을 눌러 주세요.';

  @override
  String get eudBindingNoMap => 'EUD 프로젝트를 연결하려면 맵을 여세요.';

  @override
  String get eudBindingUnsaved => '맵에 저장하지 않은 변경이 있어요. 연결하기 전에 맵을 저장하세요.';

  @override
  String get eudBindingRestricted => '편집이 제한된 맵이라 연결할 수 없어요.';

  @override
  String get eudBindingMatched => '현재 맵이 프로젝트와 일치해요 (확인된 스냅샷).';

  @override
  String get eudBindingMismatch => '현재 맵이 프로젝트와 달라요. 연결된 맵을 열거나 이 맵을 직접 연결하세요.';

  @override
  String get eudBindingDiskChanged => '디스크의 맵 파일이 바뀌었어요. 다시 연 다음 연결하세요.';

  @override
  String get eudConnectionTitle => '연결된 맵';

  @override
  String get eudVerifyMap => '현재 맵 확인';

  @override
  String get eudConnectMap => '현재 맵 연결';

  @override
  String eudProjectInfo(String project, String map, String sha) {
    return '프로젝트: $project\n맵: $map\nSHA-256: $sha';
  }

  @override
  String get eudNotSaved => '저장 안 됨';

  @override
  String get eudChangesTitle => '바꾼 값';

  @override
  String eudChangesCount(int count) {
    return '저장된 변경 $count개 • 게임 동작 미검증';
  }

  @override
  String get eudChangesEmpty => '아직 바꾼 값이 없어요. “모든 EUD 필드 편집”에서 골라 보세요.';

  @override
  String get eudAllFields => '모든 EUD 필드 편집';

  @override
  String eudBaselineLine(String value) {
    return '원래 값: $value';
  }

  @override
  String eudPlannedLine(String requested, String planned) {
    return '요청한 값: $requested • 적용 예정 값: $planned';
  }

  @override
  String get eudUnresolved => '확인 전';

  @override
  String get eudExplicitChk => 'CHK 값도 직접 변경';

  @override
  String get eudPreviewOnlyNote =>
      '미리보기일 뿐 게임에는 아직 적용되지 않아요. 바꾼 뒤에는 현재 맵을 다시 확인하세요. 프로젝트 검사 오류가 있으면 적용 예정 값이 모두 막혀요.';

  @override
  String get eudRevert => '원래 값으로';

  @override
  String get eudBaselineUnverified => '확인 안 된 맵';

  @override
  String eudBaselineGameDefault(String detail) {
    return '게임 기본값 (알 수 없음; $detail)';
  }

  @override
  String eudBaselineUnavailable(String detail) {
    return '사용할 수 없음 ($detail)';
  }

  @override
  String eudBaselineNotInChk(String detail) {
    return 'CHK에 저장되지 않음; $detail';
  }

  @override
  String get eudStepsTitle => '게임에 넣기까지';

  @override
  String get eudStepChoose => '값 고르기';

  @override
  String eudStepChooseDone(int count) {
    return '$count개를 바꿨어요';
  }

  @override
  String get eudStepChooseNone => '아직 바꾼 값이 없어요';

  @override
  String get eudStepSave => '프로젝트 저장';

  @override
  String get eudStepSaveDone => '저장됨 · 맵 파일은 건드리지 않아요';

  @override
  String get eudStepSaveNeeded => '아직 저장 안 됨 · 맵 파일은 건드리지 않아요';

  @override
  String get eudStepVerify => '맵 확인';

  @override
  String get eudStepBuild => 'EUD 빌드';

  @override
  String get eudStepBuildHint =>
      '이 설정을 시험하려면 맵을 저장하고 확인한 뒤, EUD 빌드 준비에서 “프로젝트 설정 테스트 빌드”를 켜세요.';

  @override
  String get eudStepBuildIdle => '새 맵 파일을 만들어요. 원본은 그대로예요.';

  @override
  String eudRecoveryBackup(String path) {
    return '복구용 백업: $path';
  }

  @override
  String get eudSavedPill => '저장됨';

  @override
  String get eudUnsavedPill => '저장 안 됨';

  @override
  String get eudRuntimeUnverified => '게임 동작 미검증';

  @override
  String get eudTechnical => '기술 정보';

  @override
  String get eudProblems => '확인이 필요해요';

  @override
  String get eudRulesTitle => '실행 규칙';

  @override
  String eudRulesCount(int current, int total) {
    return '$current / $total';
  }

  @override
  String get eudRulesHelp =>
      '규칙은 게임이 진행되는 동안 자원 같은 값을 바꿔요. 일반 트리거보다 먼저 실행되고, 주기는 초가 아니라 트리거 주기 단위예요. 프로젝트를 저장한 뒤 EUD 빌드 준비에서 시험하세요.';

  @override
  String get eudRulesHelp2 =>
      '같은 대상을 쓰는 규칙은 하나만 켤 수 있어요. 직접 작성한 코드와 일반 트리거는 따로 확인하세요. 확장 규칙은 변수, 플레이어 상태, 로케이션, 지정 유닛, 개인 표시를 지원해요.';

  @override
  String get eudRulesEmpty => '아직 규칙이 없어요.';

  @override
  String get eudRuleAdd => '실행 규칙 추가';

  @override
  String get eudRuleEditTitle => '실행 규칙 편집';

  @override
  String get eudRuleDisabled => '꺼짐';

  @override
  String get eudRuleMoveUp => '위로';

  @override
  String get eudRuleMoveDown => '아래로';

  @override
  String get eudRuleEdit => '규칙 편집';

  @override
  String get eudRuleDelete => '규칙 삭제';

  @override
  String eudRulePlayerN(String number) {
    return '플레이어 $number';
  }

  @override
  String eudRuleWhenThen(String condition, String action) {
    return '$condition이면 → $action';
  }

  @override
  String eudCmpAtLeastSentence(String resource, String value) {
    return '$resource $value 이상';
  }

  @override
  String eudCmpAtMostSentence(String resource, String value) {
    return '$resource $value 이하';
  }

  @override
  String eudCmpExactlySentence(String resource, String value) {
    return '$resource 정확히 $value';
  }

  @override
  String eudOpSetToSentence(String amount) {
    return '$amount(으)로 설정';
  }

  @override
  String eudOpAddSentence(String amount) {
    return '$amount 더하기';
  }

  @override
  String eudOpSubtractSentence(String amount) {
    return '$amount 빼기';
  }

  @override
  String get eudRuleOnce => '처음 맞을 때 한 번';

  @override
  String eudRuleEvery(int count) {
    return '$count주기마다';
  }

  @override
  String get eudRulePeriodic => '주기적으로';

  @override
  String get eudResMinerals => '미네랄';

  @override
  String get eudResGas => '가스';

  @override
  String get eudCmpAtLeast => '이상';

  @override
  String get eudCmpAtMost => '이하';

  @override
  String get eudCmpExactly => '정확히';

  @override
  String get eudOpSetTo => '값으로 설정';

  @override
  String get eudOpAdd => '더하기';

  @override
  String get eudOpSubtract => '빼기';

  @override
  String get eudRuleDefaultName => '자원 규칙';

  @override
  String get eudRuleName => '규칙 이름';

  @override
  String get eudRulePlayer => '플레이어';

  @override
  String get eudRuleResource => '자원 (조건과 액션 공통)';

  @override
  String get eudRuleComparison => '비교';

  @override
  String get eudRuleThreshold => '기준 값 (0–2147483647)';

  @override
  String get eudRuleAction => '액션';

  @override
  String get eudRuleAmount => '양 (0–2147483647)';

  @override
  String get eudRuleSchedule => '실행 방식';

  @override
  String get eudRuleInterval => '주기 (12–86400 트리거 주기)';

  @override
  String get eudRuleEnabled => '사용';

  @override
  String get eudRuleApply => '규칙 적용';

  @override
  String get eudExtTitle => '확장 실행 규칙';

  @override
  String get eudExtHelp =>
      '값은 부호 없는 16비트이며 0–65535로 제한돼요. 변수 0–15는 0에서 시작해요. 계산식: 원본 × 배수 + 더할 값. 자원이 아닌 액션은 값을 그대로 설정해요.';

  @override
  String get eudExtTargetAction => '대상 액션';

  @override
  String get eudExtTargetId =>
      '대상 ID: 변수 0–15, 업그레이드 0–60, 테크 0–43, 로케이션 1–255 (64 제외), 소리 문자열 ID, 그 밖에는 0';

  @override
  String get eudExtUnitType => '유닛 종류 ID (0–227, 개별 유닛/따라가기 액션)';

  @override
  String get eudExtUnitBindHelp =>
      '선택한 플레이어가 가진 이 종류의 첫 번째 살아 있는 유닛에 연결돼요. 유닛이 죽거나 변태하거나 소유자가 바뀌면 연결이 영구히 끊기고, 다른 유닛으로 바꾸지 않아요. 유닛 규칙은 최대 4개예요.';

  @override
  String get eudExtTextPrefix => '앞에 붙일 문구 (선택한 플레이어에게만)';

  @override
  String get eudExtSoundHelp => '리소스에 등록한 WAV 문자열 ID를 쓰세요. 선택한 플레이어만 소리를 들어요.';

  @override
  String get eudExtTiming => '실행 시점';

  @override
  String get eudExtLeft => '조건 왼쪽 값';

  @override
  String get eudExtRight => '조건 오른쪽 값';

  @override
  String get eudExtValue => '액션 값';

  @override
  String get eudExtX => 'X';

  @override
  String get eudExtY => 'Y';

  @override
  String get eudExtWidth => '너비';

  @override
  String get eudExtHeight => '높이';

  @override
  String get eudExtConstantId => '상수 / ID';

  @override
  String get eudExtPlayerRange => '플레이어 1–8';

  @override
  String get eudExtFactor => '× (0–255)';

  @override
  String get eudExtOffset => '+ 더할 값';

  @override
  String get eudActVariable => '변수';

  @override
  String get eudActMinerals => '미네랄';

  @override
  String get eudActGas => '가스';

  @override
  String get eudActUpgrade => '업그레이드 레벨';

  @override
  String get eudActTechnology => '테크';

  @override
  String get eudActLocation => '로케이션';

  @override
  String get eudActUnitHp => '유닛 체력';

  @override
  String get eudActUnitShields => '유닛 실드';

  @override
  String get eudActUnitEnergy => '유닛 에너지';

  @override
  String get eudActFollowUnit => '유닛 따라가기';

  @override
  String get eudActText => '문구 표시';

  @override
  String get eudActSound => '소리 재생';

  @override
  String get eudTimingBefore => '트리거 전';

  @override
  String get eudTimingAfter => '트리거 후';

  @override
  String get eudSrcConstant => '상수';

  @override
  String get eudSrcVariable => '변수';

  @override
  String get eudSrcMinerals => '미네랄';

  @override
  String get eudSrcGas => '가스';

  @override
  String get eudSrcUpgrade => '업그레이드 레벨';

  @override
  String get eudSrcTechnology => '테크';

  @override
  String get eudApplyToProject => '프로젝트에 적용';

  @override
  String get eudProjectChanged => '프로젝트가 바뀌었어요. 취소하고 이 창을 다시 여세요.';

  @override
  String get eudWeaponCardTitle => '무기';

  @override
  String get eudWeaponCardHelp =>
      '사거리와 피해 유형은 무기에 속해서, 그 무기를 쓰는 유닛이 모두 함께 바뀌어요.';

  @override
  String get eudWeaponEdit => '무기 EUD 설정 편집';

  @override
  String get eudWeaponSharedHelp =>
      '지상·공중 무기로 이 무기를 쓰는 유닛이 함께 바뀌어요. 적용한 뒤 “유닛 / 무기 영향”을 확인하세요. 유닛의 무기를 다른 무기로 바꾸지는 않아요.';

  @override
  String get eudWeaponRawHelp =>
      '거리는 원시 정수 값이에요 (32 = 타일 1칸, 실제 동작은 미검증). 비워 두면 변경이 지워져요. 적용해도 프로젝트만 바뀌고 게임은 바뀌지 않아요.';

  @override
  String get eudWeaponMinRange => '최소 사거리 (원시 값)';

  @override
  String get eudWeaponMaxRange => '최대 사거리 (원시 값)';

  @override
  String get eudWeaponNoDamage => '피해 유형 그대로';

  @override
  String eudWeaponUnsupported(String value) {
    return '지원하지 않음: $value';
  }

  @override
  String get eudWeaponReferenceChanged => '무기 참조 정보가 바뀌었어요. 취소하고 다시 불러오세요.';

  @override
  String eudWeaponWholeNumber(String field) {
    return '$field: 0부터 4294967295 사이의 정수를 입력하세요.';
  }

  @override
  String get eudDamageIndependent => '독립형';

  @override
  String get eudDamageExplosive => '폭발형';

  @override
  String get eudDamageConcussive => '진동형';

  @override
  String get eudDamageNormal => '일반형';

  @override
  String get eudDamageIgnoreArmor => '방어 무시';

  @override
  String get eudImpactTitle => '유닛 / 무기 영향';

  @override
  String get eudImpactHelp =>
      '기본 DAT 참조만 봐요. 바꾸려는 참조, 마법, 실제 공격 동작은 반영하지 않아요. 종류 설정은 모든 플레이어에 적용되고, 플레이어 값은 해당 슬롯에만 적용돼요.';

  @override
  String get eudImpactLoad => '무기 영향 불러오기';

  @override
  String get eudImpactUnavailable => '무기 참조가 없어요. 불러오면 분석할 수 있어요.';

  @override
  String eudImpactSource(String source) {
    return '참조 출처: $source';
  }

  @override
  String get eudImpactChooseUnit =>
      '유닛을 고르면 그 유닛의 지상 / 공중 무기를 바로 편집할 수 있어요. 서브유닛의 무기는 따로 있으니 서브유닛을 직접 고르세요.';

  @override
  String get eudImpactEditShields => '유닛 실드 EUD 편집';

  @override
  String get eudImpactGround => '지상';

  @override
  String get eudImpactAir => '공중';

  @override
  String eudImpactNoWeapon(String slot) {
    return '$slot 무기: 없음 (#130)';
  }

  @override
  String eudImpactEditWeapon(String slot, String weapon) {
    return '$slot: $weapon — EUD 편집';
  }

  @override
  String eudImpactSubunits(String subunit1, String subunit2) {
    return '서브유닛 ID: $subunit1, $subunit2 (228 = 없음)';
  }

  @override
  String eudImpactCannotAnalyze(String reason) {
    return '분석할 수 없음: $reason';
  }

  @override
  String get eudImpactUnknownWeapon => '영향 알 수 없음: 무기 참조가 없어요.';

  @override
  String eudImpactPlayerOnly(String number) {
    return '플레이어 $number에게만 적용 · 실제 동작 미검증.';
  }

  @override
  String get eudImpactUnknownShared => '영향 알 수 없음: 이 표의 공유 참조가 없어요.';

  @override
  String eudImpactUnits(String direct, String subunits) {
    return '직접 사용 유닛: $direct\n서브유닛을 통해: $subunits';
  }

  @override
  String get eudImpactNone => '정적 참조에는 없음';

  @override
  String eudShieldTitle(String unit) {
    return '$unit — 실드';
  }

  @override
  String get eudShieldHelp =>
      '실드 사용 여부와 최대 실드는 따로 설정되고 모든 플레이어에게 똑같이 적용돼요. 최대값을 비우거나 “그대로”를 고르면 그 설정이 지워져요.';

  @override
  String get eudShieldNoOverride => '실드 사용 그대로';

  @override
  String get eudShieldEnabled => '실드 켜기';

  @override
  String get eudShieldDisabled => '실드 끄기';

  @override
  String get eudShieldUnsupported => '지원하지 않는 가져온 값';

  @override
  String get eudShieldMaximum => '최대 실드 (0–65535)';

  @override
  String get eudShieldOverrideChk => '맵(CHK)의 최대 실드 값도 직접 바꾸기';

  @override
  String get eudShieldInitNote =>
      '이미 배치된 유닛은 맵(CHK)의 실드 비율을 그대로 유지해요. 현재 실드를 채우거나 제한하는 코드는 만들지 않고, 새 유닛에 대한 적용은 실제 게임 확인이 필요해요. 적용하면 프로젝트에만 저장돼요.';

  @override
  String get eudShieldChooseSupported => '지원하는 실드 사용 값을 고르세요.';

  @override
  String get eudShieldWholeNumber => '최대 실드는 0부터 65535 사이의 정수여야 해요.';

  @override
  String get eudFieldsTitle => 'EUD 필드 편집';

  @override
  String get eudFieldsIntro =>
      '검증 전 설정이에요. 값을 고를 때마다 “초안에 추가”를 누르고, 마지막에 “초안을 프로젝트에 적용”을 누르세요. 추가하지 않은 입력은 다른 항목을 고르면 사라져요.';

  @override
  String get eudFieldsField => '바꿀 항목';

  @override
  String get eudFieldsSearch => '이름 또는 ID로 대상 찾기';

  @override
  String get eudFieldsTarget => '대상';

  @override
  String get eudFieldsPlayerNote =>
      '선택한 플레이어 슬롯에만 적용돼요. 인구수는 절반 단위예요 (400 = 인구 200).';

  @override
  String get eudFieldsGlobalNote =>
      '모든 플레이어에게 똑같이 적용되는 종류 설정이에요. DAT 기본값은 불러오지 않고, 같은 값을 쓰는 다른 대상에 대한 영향은 여기서 분석하지 않아요.';

  @override
  String eudFieldsApi(String member, String unit) {
    return '후보 API: $member • $unit';
  }

  @override
  String eudFieldsStorage(String maximum, String mask) {
    return '입력 범위: 0–$maximum$mask. 게임 안에서의 한계는 확인되지 않았어요.';
  }

  @override
  String eudFieldsMask(String mask) {
    return ' • 허용 비트: $mask';
  }

  @override
  String get eudFieldsValue => '값 (10진 정수)';

  @override
  String get eudFieldsChoose => '값을 고르세요';

  @override
  String eudFieldsUnsupported(String value) {
    return '지원하지 않는 저장 값: $value';
  }

  @override
  String get eudFieldsYes => '예 (true)';

  @override
  String get eudFieldsNo => '아니요 (false)';

  @override
  String get eudFieldsOverrideChk => '일반 맵(CHK) 설정도 직접 바꾸기';

  @override
  String get eudFieldsStage => '초안에 추가 / 갱신';

  @override
  String get eudFieldsRemove => '초안에서 빼기';

  @override
  String eudFieldsDraftSummary(int count, String value) {
    return '초안 변경 $count개 • 현재: $value';
  }

  @override
  String get eudFieldsNoOverride => '변경 없음';

  @override
  String get eudFieldsApply => '초안을 프로젝트에 적용';

  @override
  String get eudFieldsNeedChk => '이 값은 일반 맵(CHK) 설정도 바꿔요. 허용하려면 위 확인란을 체크하세요.';

  @override
  String get eudFieldsOutOfRange => '허용 범위를 벗어난 값이에요.';

  @override
  String get eudFieldsInvalid => '선택한 항목에 쓸 수 없는 값이에요.';

  @override
  String get isomFillTitle => '등각 지형 채우기';

  @override
  String get isomFillScope =>
      '맵 전체를 한 종류의 평지로 바꿉니다. ISOM, TILE, MTXM이 함께 갱신되며 Undo로 원래 지형을 복원할 수 있습니다. 경사로·지형 경계·두다드는 아직 지원하지 않습니다.';

  @override
  String get isomTerrainType => '평지 종류';

  @override
  String isomTerrainId(int id) {
    return '지형 종류 #$id';
  }

  @override
  String isomFillPreview(int count) {
    return '게임 타일 $count개가 변경됩니다. 에디터 지형(ISOM)도 함께 갱신됩니다.';
  }

  @override
  String get isomFillUnavailable =>
      '지형 채우기를 사용할 수 없습니다. 설정에서 스타크래프트 데이터를 지정하고, TILE/MTXM이 일치하며 지원되는 ISOM 형태를 가진 짝수 너비 맵을 사용하세요.';

  @override
  String get isomFillCancel => '취소';

  @override
  String get isomFillApply => '맵 전체 채우기';
}
