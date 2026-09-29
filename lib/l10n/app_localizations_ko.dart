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
}
