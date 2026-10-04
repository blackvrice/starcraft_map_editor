// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Korean (`ko`).
class AppLocalizationsKo extends AppLocalizations {
  AppLocalizationsKo([String locale = 'ko']) : super(locale);

  @override
  String get recoveryTitle => '미저장 작업 복구';

  @override
  String get recoveryEmpty => '복구본이 없습니다.';

  @override
  String get recoveryDamaged => '읽을 수 없거나 손상된 복구본';

  @override
  String recoveryBaseline(String path) {
    return '마지막 저장 맵: $path';
  }

  @override
  String recoveryProject(String path) {
    return 'EUD 프로젝트: $path';
  }

  @override
  String recoverySource(String path) {
    return 'epScript: $path';
  }

  @override
  String get recoveryOpen => '복구본 열기';

  @override
  String get recoveryDelete => '복구본 삭제';

  @override
  String get recoveryDeleteConfirm => '이 복구본을 영구 삭제할까요?';

  @override
  String get recoverySourceChanged =>
      '마지막 저장 맵이 외부에서 변경되었습니다. 복구를 중단했으며 복구본은 유지됩니다.';

  @override
  String get recoveryFailed =>
      '복구본을 열 수 없습니다. 미저장 문서를 저장하거나 닫고 마지막 저장 맵을 확인하세요. 복구본은 유지됩니다.';

  @override
  String get autosaveSettings => '자동 저장 설정';

  @override
  String get autosaveEnabled => '복구본 자동 저장';

  @override
  String autosaveInterval(int seconds) {
    return '저장 간격: $seconds초';
  }

  @override
  String autosaveRetention(int count) {
    return '작업 공간별 보관 수: $count개';
  }

  @override
  String get autosaveFailed =>
      '자동 저장 또는 복구에 실패했습니다. 앱 데이터 폴더 접근 권한과 남은 공간을 확인하세요.';

  @override
  String get recoveryCancel => '취소';

  @override
  String get recoveryClose => '닫기';

  @override
  String get autosaveApply => '적용';

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
      '평지 채우기·재계산, 경계·높이 그리기와 확인된 경사로 배치를 제공합니다. 적용 전까지 맵은 바뀌지 않습니다. 미지원·손상 지형은 거부합니다.';

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

  @override
  String get basicToolsTitle => '기본 편집 도구';

  @override
  String get basicFog => '초기 안개';

  @override
  String get basicUnits => '선택 유닛';

  @override
  String get basicStarts => '시작 위치';

  @override
  String get basicLocations => '로케이션';

  @override
  String get basicOpenMap => '편집 가능한 맵을 먼저 여세요.';

  @override
  String get basicFogUnavailable => '정상 MASK/DIM 격자가 필요합니다.';

  @override
  String basicPlayer(int id) {
    return '플레이어 $id';
  }

  @override
  String get basicFogHide => '지형 숨김';

  @override
  String get basicBrush => '브러시';

  @override
  String get basicRectangle => '사각형';

  @override
  String get basicFillAll => '맵 전체 채우기';

  @override
  String get basicFogScope => '어두운 칸은 초기에 숨겨집니다. 선택 플레이어에게만 적용합니다.';

  @override
  String basicSelectedUnits(int count) {
    return '선택 유닛 $count개';
  }

  @override
  String get basicKeepBlank => '비워 둔 숫자 항목은 기존 값을 유지합니다.';

  @override
  String get basicOwner => '소유자 (1–12)';

  @override
  String get basicHitpoints => '체력 %';

  @override
  String get basicShields => '실드 %';

  @override
  String get basicEnergy => '에너지 %';

  @override
  String get basicResources => '자원량';

  @override
  String get basicHangar => '격납 수';

  @override
  String get basicUnitStates => '상태와 상속';

  @override
  String get basicCloak => '클로킹';

  @override
  String get basicBurrow => '버로우';

  @override
  String get basicLifted => '공중 이동 상태';

  @override
  String get basicHallucination => '환상';

  @override
  String get basicInvincible => '무적';

  @override
  String get basicKeep => '유지';

  @override
  String get basicOff => '끔';

  @override
  String get basicOn => '켬';

  @override
  String get basicInherit => '게임 기본값 사용';

  @override
  String get basicValidFields => '저장된 필드 값 적용';

  @override
  String get basicApplyStored => '저장 값 적용';

  @override
  String get basicApply => '적용';

  @override
  String get basicRelationHelp =>
      '맵에서 호환되는 유닛 두 개를 선택하세요. 연결은 양쪽 참조를 갱신하며 위치를 유지합니다. 소유자 변경 전에는 연결을 해제하세요.';

  @override
  String get basicLinkAddon => '애드온 연결';

  @override
  String get basicLinkNydus => '나이더스 연결';

  @override
  String get basicUnlink => '연결 해제';

  @override
  String get basicStartsHelp =>
      '선택 플레이어의 시작 위치를 생성하거나 이동합니다. 중복 시작 위치는 보존하며 먼저 검토해야 합니다.';

  @override
  String get basicPixelX => '픽셀 X';

  @override
  String get basicPixelY => '픽셀 Y';

  @override
  String get basicLocationsUnavailable => '정상 로케이션 표 하나가 필요합니다.';

  @override
  String get basicElevationHelp =>
      '로케이션을 선택하고 지상·공중 고도 조건을 지정하세요. 다른 플래그 비트와 문자열은 보존합니다.';

  @override
  String get basicLowGround => '낮은 지형';

  @override
  String get basicMediumGround => '중간 지형';

  @override
  String get basicHighGround => '높은 지형';

  @override
  String get basicLowAir => '낮은 공중';

  @override
  String get basicMediumAir => '중간 공중';

  @override
  String get basicHighAir => '높은 공중';

  @override
  String get basicSpritesDoodads => 'Sprite / Doodad';

  @override
  String get basicClipboard => '복사·붙여넣기';

  @override
  String get basicCopy => '선택 객체 복사';

  @override
  String get basicCut => '선택 객체 자르기';

  @override
  String get basicPaste => '픽셀 위치에 붙여넣기';

  @override
  String get basicClipboardHelp =>
      '현재 문서의 유닛·Sprite·로케이션을 복사합니다. 연결된 유닛은 함께 선택하세요. 시작 위치와 검증되지 않은 Doodad overlay 복사는 거부합니다.';

  @override
  String get basicSpriteDisabled => 'Sprite-unit 비활성';

  @override
  String get basicSpriteHelp =>
      '비활성은 Sprite-unit에만 적용합니다. Doodad overlay 가능성이 있으면 아래 복합 도구를 사용하세요. 알 수 없는 flags는 보존합니다.';

  @override
  String get basicLoadDoodad => '선택 Doodad 연결 자료 불러오기';

  @override
  String get basicDoodadEnabled => 'Doodad 활성';

  @override
  String get basicDoodadHelp =>
      'Doodad 하나를 선택하고 해당 overlay를 명시적으로 지정하세요. 로컬 자료와 footprint·아래 지형이 일치해야 합니다. Pure Sprite의 활성값은 편집기 메타데이터이며 Sprite-unit의 비활성은 THG2에도 반영됩니다.';

  @override
  String get basicOverlay => '일치하는 overlay';

  @override
  String get basicLocationSearch => '이름 또는 ID 검색';

  @override
  String get basicRawTerrain => 'Raw 지형 복사';

  @override
  String get basicRawClipboardHelp =>
      'Raw MTXM 타일만 복사하고 TILE/ISOM을 보존합니다. 등각 지형 경계는 계산하지 않습니다. Doodad 맵에는 검증된 복합 편집이 필요합니다. 아래 좌표는 타일 기준입니다.';

  @override
  String get basicCutReplacement => '자른 영역 채움값 (현재 맵에 있는 타일)';

  @override
  String get basicTileLeft => '왼쪽 타일';

  @override
  String get basicTileTop => '위쪽 타일';

  @override
  String get basicTileRight => '오른쪽 타일';

  @override
  String get basicTileBottom => '아래쪽 타일';

  @override
  String get basicTileX => '대상 타일 X';

  @override
  String get basicTileY => '대상 타일 Y';

  @override
  String get basicStartMissing => '시작 위치 없음';

  @override
  String basicStartDuplicate(int count) {
    return '시작 위치 중복: $count개';
  }

  @override
  String get basicApplySelectedLocations => '선택한 로케이션 모두에 적용';

  @override
  String get basicStartCanvasHelp =>
      '맵을 클릭하면 좌표를 입력합니다. 적용하면 선택한 플레이어의 시작 위치를 배치하거나 이동합니다.';

  @override
  String get selectionTitle => '선택·탐색';

  @override
  String get selectionSearch => '이름, #종류 ID, 레이어 또는 좌표';

  @override
  String get selectionAllLayers => '모든 객체 레이어';

  @override
  String get selectionAllOwners => '모든 소유자';

  @override
  String get selectionSelectable => '선택 가능한 객체만';

  @override
  String get selectionResults => '검색 결과 선택';

  @override
  String get selectionAll => '활성 레이어 전체 선택';

  @override
  String get selectionInvert => '활성 레이어 선택 반전';

  @override
  String get selectionSameType => '같은 종류 선택';

  @override
  String get selectionSameOwner => '같은 소유자 선택';

  @override
  String get selectionClear => '선택 해제';

  @override
  String get selectionFocus => '선택으로 이동';

  @override
  String get selectionFit => '선택 영역 맞춤';

  @override
  String get selectionFitMap => '맵 전체 맞춤';

  @override
  String get selectionGoTo => '좌표로 이동';

  @override
  String get selectionTileCoordinates => '타일 좌표';

  @override
  String get selectionEmpty => '객체를 먼저 선택하세요.';

  @override
  String get selectionStale => '맵 또는 레이어가 변경되었습니다. 선택을 다시 확인하세요.';

  @override
  String get selectionNoResults => '검색 결과 없음';

  @override
  String get selectionUnavailable => '숨김 또는 잠김';

  @override
  String get selectionOverlap => '겹친 객체 선택';

  @override
  String selectionCounts(int count, int selected) {
    return '검색 $count개 · 선택 $selected개';
  }

  @override
  String get eudDatLoad => '로컬 DAT 기본값 조회';

  @override
  String get eudDatUseDefault => 'DAT 값을 입력에 사용';

  @override
  String get eudDatUnavailable => '미조회 / DAT 필드 아님';

  @override
  String eudDatDefault(String value, String source) {
    return '로컬 DAT: $value · $source (CHK·런타임 값은 다를 수 있음)';
  }

  @override
  String eudDatImpact(String before, String after, String direct) {
    return '원본 참조: $before\n변경 예정 참조: $after\n변경 예정 직접 참조: $direct';
  }

  @override
  String eudDatPartial(int count) {
    return '미확인 DAT 연결: $count개. 정적 목록은 IScript 오버레이·HD 동작을 포함하지 않습니다.';
  }

  @override
  String eudConflictTitle(int count) {
    return '정적 충돌 분석 · 겹침 $count개';
  }

  @override
  String get eudConflictHelp =>
      '현재 맵과 열린 소스만 검사합니다. 조건·그룹·동적 코드에 따라 실제 동작이 달라지므로 테스트 빌드 전 미확인 항목을 검토하세요.';

  @override
  String get isomFillMode => '평지 채우기';

  @override
  String get isomConvertMode => '기존 ISOM 재계산';

  @override
  String isomConvertPreview(int count) {
    return '게임 타일 $count개가 변경됩니다. 기존 ISOM과 플래그는 보존됩니다.';
  }

  @override
  String get isomConvertApply => '재계산한 타일 적용';

  @override
  String get isomBrushMode => '경계 브러시';

  @override
  String get isomRampMode => '경사로';

  @override
  String get isomBrushFreehand => '자유 브러시';

  @override
  String get isomBrushRectangle => '선택 영역';

  @override
  String get isomBrushSize => '브러시 크기';

  @override
  String get isomBrushHint =>
      '미리보기에 그리세요. 높이를 바꾸려면 지형 ID를 선택하세요. 경계는 자동 연결되며 적용 시 모든 획이 Undo 한 건으로 기록됩니다.';

  @override
  String get isomBrushApply => '지형 편집 적용';

  @override
  String get isomBrushReset => '미리보기 초기화';

  @override
  String get isomRampHint =>
      '로컬 VF4에서 확인한 경사로를 선택한 뒤 맞는 절벽의 왼쪽 위 타일을 클릭하세요. 방향은 선택한 배치 자료로 결정됩니다. 지형이 맞지 않으면 적용을 거부합니다.';

  @override
  String get isomRampEmpty => '이 타일셋에 확인된 경사로 배치 자료가 없습니다.';

  @override
  String get isomRampRecipe => '경사로 배치 자료';

  @override
  String get isomBrushStrokeRejected => '마지막 획은 적용되지 않았습니다. 이전 미리보기는 유지됩니다.';

  @override
  String get resizeTerrainLoading => '검증된 지형·두다드 자료를 불러오는 중…';

  @override
  String get resizeIsomFillHint =>
      '추가할 등각 지형의 평지 표본을 타일 X/Y로 선택하세요(0부터 시작). 새 안개 셀은 모든 플레이어에게 숨겨집니다. 두다드의 전체 footprint가 맵 안에 남아야 합니다.';

  @override
  String resizeDoodadImpact(int moved, int outside) {
    return '이동할 두다드: $moved; 맵 밖 footprint: $outside';
  }

  @override
  String resizeTerrainImpact(int count) {
    return '재계산한 지형 셀: $count. 기존 다이아몬드와 검증된 두다드 footprint를 보존합니다.';
  }

  @override
  String get resizeCoordinateScope =>
      '트리거·EUD 코드 좌표는 그대로 유지됩니다. 크기 변경 후 직접 지정한 좌표를 확인하세요. 미확인 지형이나 모호한 두다드는 적용을 차단합니다.';

  @override
  String get editorPrepareEUDBuild => 'EUD 빌드 준비';

  @override
  String get editorBuildSavedFilesOnDiskSaveMapAndSource =>
      '디스크에 저장된 파일로 빌드합니다. 맵과 소스 변경사항을 먼저 저장하세요. 프로젝트 설정만 빌드하려면 소스 폴더와 진입 파일을 비워 두세요. 출력은 새로운 .scx 파일이어야 합니다.';

  @override
  String get editorBaseMapPath => '기본 맵 경로';

  @override
  String get editorSourceFolderPath => '소스 폴더 경로';

  @override
  String get editorEntryEpsPath => '진입 .eps 파일 경로';

  @override
  String get editorNewOutputScxPath => '새 출력 .scx 경로';

  @override
  String get editorToolOverrideForThisBuildOptional => '이 빌드에 사용할 도구 경로 (선택)';

  @override
  String get editorBlankToolOverrideUsesYourEUDToolsSelectionPrepare =>
      '도구 경로를 비워 두면 EUD 도구 설정을 사용합니다. 준비 단계는 파일을 검사하고, 빌드는 별도로 컴파일러를 실행합니다.';

  @override
  String get editorITrustThisSourceAndItsImportsToRun =>
      '이 소스와 가져오는 코드가 이 컴퓨터에서 실행되는 것을 신뢰합니다.';

  @override
  String get editorIncludeProjectSettingsInAnUnverifiedTestBuild =>
      '미검증 테스트 빌드에 프로젝트 설정 포함';

  @override
  String get editorTypeSettingsInitializeOnceRulesUseTheirBeforeAfter =>
      '종류 설정은 한 번 초기화됩니다. 규칙은 트리거 실행 전후에 적용되며, 인스턴스 규칙은 조건으로 보호된 유닛을 변경할 수 있습니다. 실제 게임과 멀티플레이 동작은 별도 테스트가 필요합니다.';

  @override
  String get editorCancel => '취소';

  @override
  String get editorPrepare => '준비';

  @override
  String get editorEUDTools => 'EUD 도구';

  @override
  String get editorChooseAnExternalEuddraftInstallationOrUseTheApp =>
      '외부 euddraft 설치를 선택하거나 앱 기본값을 사용하세요. 프로젝트별 경로가 우선합니다.';

  @override
  String get editorExternalEuddraftPath => '외부 euddraft 경로';

  @override
  String get editorInstallationDirectoryOrEuddraftExeAbsolutePath =>
      '설치 폴더 또는 euddraft.exe의 절대 경로';

  @override
  String get editorBrowseInstallationFolder => '설치 폴더 찾아보기';

  @override
  String get editorSelectionAppDefault => '선택: 앱 기본값';

  @override
  String editorSelectionExternal(String value0) {
    return '선택: 외부 도구\n$value0';
  }

  @override
  String get editorNoBundledToolIsIncludedInThisAppYet =>
      '이 앱에는 아직 도구가 포함되어 있지 않습니다. 외부 설치를 선택하세요.';

  @override
  String editorBundledEuddraft01025Editor1No(String value0) {
    return '포함된 euddraft 0.10.2.5 (editor.1)\n별도 Python 설치가 필요하지 않습니다. 앱과 함께 업데이트됩니다.\n$value0\n라이선스 및 수정 내역: 이 폴더의 BUNDLE-NOTICE.txt';
  }

  @override
  String editorInspectionPassedEuddraft(String value0, String value1) {
    return '검사 통과: euddraft $value0\n$value1';
  }

  @override
  String get editorInspectionDoesNotRunTheCompilerSavingThisChoice =>
      '검사는 컴파일러를 실행하지 않습니다. 이 선택을 저장해도 빌드를 준비하거나 기존 빌드 계획을 변경하지 않습니다.';

  @override
  String get editorUseAppDefault => '앱 기본값 사용';

  @override
  String get editorReinspect => '다시 검사';

  @override
  String get editorSaveAndInspect => '저장 후 검사';

  @override
  String get editorClose => '닫기';

  @override
  String get editorForceSettings => '세력 설정';

  @override
  String get editorPlayerAssignment => '플레이어 배정';

  @override
  String editorPlayer(String value0) {
    return '플레이어 $value0';
  }

  @override
  String get editorCopiesOnlyTheEditedForceAssignmentToPlayers1 =>
      '변경한 세력 배정만 플레이어 1~8에 복사합니다.';

  @override
  String editorAssignToForce(String value0) {
    return '세력 $value0에 배정';
  }

  @override
  String editorStoredIDPreserved(String value0) {
    return '저장된 ID $value0 (유지)';
  }

  @override
  String editorForce(String value0) {
    return '세력 $value0';
  }

  @override
  String get editorCopiesEditedForceNamesAndOptionsOnlyPlayerAssignments =>
      '변경한 세력 이름과 옵션만 복사합니다. 플레이어 배정은 별도입니다.';

  @override
  String get editorForceName => '세력 이름';

  @override
  String get editorRandomizeStartLocations => '시작 위치 무작위 배정';

  @override
  String get editorAllies => '동맹';

  @override
  String get editorAlliedVictory => '동맹 승리';

  @override
  String get editorSharedVision => '시야 공유';

  @override
  String get editorApplyUpdatesAllEditedPlayersAndForcesSaveAs =>
      '적용하면 변경한 모든 플레이어와 세력이 반영됩니다. 다른 이름으로 저장하면 맵 파일에 기록합니다.';

  @override
  String editorUndo(String value0) {
    return '실행 취소: $value0';
  }

  @override
  String editorRedo(String value0) {
    return '다시 실행: $value0';
  }

  @override
  String get editorApply => '적용';

  @override
  String get editorTheExistingTextIsNotValidUTF8Its =>
      '기존 텍스트는 올바른 UTF-8이 아닙니다. 원본 바이트를 유지하며 편집할 수 없습니다.';

  @override
  String get editorMapInformation => '맵 정보';

  @override
  String get editorMapTitle => '맵 제목';

  @override
  String get editorDescription => '설명';

  @override
  String get editorApplyUpdatesThisMapOnlySharedNamesRemainUnchanged =>
      '적용은 이 맵에만 반영됩니다. 공유 이름은 변경하지 않습니다. 편집한 맵은 다른 이름으로 저장하세요.';

  @override
  String get editorDiscardUnappliedSettings => '적용하지 않은 설정을 버릴까요?';

  @override
  String get editorOneOrMoreTabsHaveUnappliedDraftsAppliedChanges =>
      '적용하지 않은 변경사항이 있는 탭이 있습니다. 이미 적용한 변경사항은 맵에 남으며 실행 취소할 수 있습니다.';

  @override
  String get editorKeepEditing => '계속 편집';

  @override
  String get editorDiscardAndClose => '버리고 닫기';

  @override
  String get editorMapSettings => '맵 설정';

  @override
  String get editorMapWideSettingsTheCanvasInspectorEditsIndividualPlaced =>
      '맵 전체 설정입니다. 캔버스 속성 패널은 배치된 개별 객체를 편집합니다. 적용은 현재 탭에 반영하며, 다른 이름으로 저장하면 맵 파일에 기록합니다.';

  @override
  String get editorEUDExecutionRules => 'EUD 실행 규칙';

  @override
  String get editorMap => '맵';

  @override
  String get editorPlayers => '플레이어';

  @override
  String get editorForces => '세력';

  @override
  String get editorUnits => '유닛';

  @override
  String get editorAvailability => '사용 가능 여부';

  @override
  String get editorUpgrades => '업그레이드';

  @override
  String get editorTech => '기술';

  @override
  String get editorSlotType => '슬롯 종류';

  @override
  String get editorRace => '종족';

  @override
  String get editorColor => '색상';

  @override
  String get editorUnavailable => '사용 불가';

  @override
  String get editorPlayerSettings => '플레이어 설정';

  @override
  String editorPlayer203c6551(String value0, String value1) {
    return '플레이어 $value0$value1';
  }

  @override
  String get editorReadOnly => ' (읽기 전용)';

  @override
  String get editorSlotTypeRaceAndColorEditsForPlayablePlayers =>
      '플레이 가능한 플레이어 1~8의 슬롯 종류, 종족, 색상만 편집합니다.';

  @override
  String get editorOnlyTheEightPlayableSlotsCanBeEditedPlayers =>
      '플레이 가능한 8개 슬롯만 편집할 수 있습니다. 플레이어 9~12에는 COLR 색상 항목이 없습니다.';

  @override
  String get editorColorSettingsAreSavedToTheMapCanvasPreviews =>
      '색상 설정은 맵에 저장됩니다. 현재 캔버스 미리보기는 기본 플레이어 색상을 사용합니다.';

  @override
  String editorPendingFieldChangesApplyUpdatesAllEditedPlayersSave(
    String value0,
  ) {
    return '대기 중인 필드 변경 $value0개. 적용은 변경한 모든 플레이어에 반영하며, 다른 이름으로 저장하면 맵 파일에 기록합니다.';
  }

  @override
  String get editorNoEditedFieldsInTheCurrentSelection =>
      '현재 선택에는 변경한 필드가 없습니다.';

  @override
  String editorDraftFieldCopiesPreparedForIDsReviewThenApply(
    String value0,
    String value1,
  ) {
    return 'ID $value1개에 필드 초안 $value0개를 복사했습니다. 확인 후 적용하세요.';
  }

  @override
  String get editorSearchNameOrID12ForExactID => '이름 또는 ID 검색 (정확한 ID는 #12)';

  @override
  String editorCurrent(String value0) {
    return '현재: $value0';
  }

  @override
  String get editorNoMatchingIDsCurrentSelectionAndDraftsAreUnchanged =>
      '일치하는 ID가 없습니다. 현재 선택과 초안은 유지됩니다.';

  @override
  String get editorCopyEditedFieldsToIDs => '변경한 필드를 ID에 복사';

  @override
  String editorSource(String value0, String value1) {
    return '원본: $value0. $value1';
  }

  @override
  String get editorCopiesOnlyEditedFieldsReplacingThoseDraftFieldsAt =>
      '변경한 필드만 복사하며 대상 ID의 해당 초안 필드를 교체합니다. 검색으로 대상이 선택되지는 않습니다. 적용해야 맵이 변경됩니다.';

  @override
  String editorTargetIDs(String value0, String value1) {
    return '대상 ID ($value0~$value1)';
  }

  @override
  String get editorPrepareDraftCopies => '초안 복사 준비';

  @override
  String get editorUnappliedDraft => '미적용 초안';

  @override
  String get editorTheMapChangedInAnotherEditorOrThroughUndo =>
      '다른 편집기 또는 실행 취소·다시 실행으로 맵이 변경되었습니다. 이 탭을 적용하기 전에 다시 불러오세요.';

  @override
  String get editorReloadAndDiscardThisDraft => '초안을 버리고 다시 불러오기';

  @override
  String get editorDiscardTabDraft => '탭 초안 버리기';

  @override
  String get editorStarCraftDataAssets => 'StarCraft 데이터 자산';

  @override
  String
  get editorChooseTheInstalledStarCraftRemasteredDirectoryTheEditorReads =>
      '설치된 StarCraft: Remastered 폴더를 선택하세요. 편집기는 포함된 CascLib 도우미로 로컬 CASC 저장소를 읽으며, 저작권이 있는 게임 데이터를 추출하거나 복사하지 않습니다.';

  @override
  String get editorClear => '지우기';

  @override
  String get editorRefresh => '새로고침';

  @override
  String get editorChooseInstallation => '설치 폴더 선택…';

  @override
  String editorCASCBuildMiBCheckedCascLibHelper(
    String value0,
    String value1,
    String value2,
    String value3,
    String value4,
  ) {
    return 'CASC $value0 • 빌드 $value1 • 검사 $value2 MiB • CascLib $value3 • 도우미 $value4';
  }

  @override
  String get editorConfiguredPath => '설정된 경로';

  @override
  String get editorNotConfigured => '미설정';

  @override
  String get editorExpectedTheFolderContainingStarCraftExeBuildInfoAnd =>
      'StarCraft.exe, .build.info, Data\\가 있는 폴더를 선택하세요.';

  @override
  String get editorLoadingSettings => '설정 불러오는 중…';

  @override
  String get editorInspectingAssets => '자산 검사 중…';

  @override
  String editorRequiredAssetsReady(String value0, String value1) {
    return '필수 자산 $value0/$value1개 준비 완료';
  }

  @override
  String get editorStarCraftInstallationIsNotConfigured =>
      'StarCraft 설치가 설정되지 않았습니다';

  @override
  String get editorStarCraftCASCDataIsUnavailable =>
      'StarCraft CASC 데이터를 사용할 수 없습니다';

  @override
  String editorRequiredAssetsFound(String value0, String value1) {
    return '필수 자산 $value0/$value1개 발견';
  }

  @override
  String get editorMissing => '누락';

  @override
  String get editorInvalid => '유효하지 않음';

  @override
  String get editorUnavailableAssetFiles => '사용할 수 없는 자산 파일';

  @override
  String editorAndMore(String value0) {
    return '…외 $value0개';
  }

  @override
  String editorStoredFlagPreserved(String value0) {
    return '저장된 플래그 $value0 (유지)';
  }

  @override
  String editorTechd52bce90(String value0, String value1, String value2) {
    return '기술 #$value0, $value1: $value2';
  }

  @override
  String get editorEffectiveStateUnknownStoredFlagPreserved =>
      '실제 적용 상태: 알 수 없음 (저장된 플래그 유지)';

  @override
  String editorEffectiveStateAvailableResearched(String value0, String value1) {
    return '실제 적용 상태: 사용 가능 $value0, 연구 완료 $value1';
  }

  @override
  String get editorTechSettings => '기술 설정';

  @override
  String editorEditing(String value0, String value1, String value2) {
    return '편집 중: $value0 / $value1$value2.';
  }

  @override
  String get editorAlternateSectionsPreserved => '; 다른 섹션 유지';

  @override
  String editorMapCostsAndOnlyInheritanceFlagsChangeOnlyIf(String value0) {
    return '맵 비용과 $value0만 편집합니다. 상속 플래그는 편집한 경우에만 변경됩니다.';
  }

  @override
  String get editorMapDefaults => '맵 기본값';

  @override
  String get editorUseCustomCosts => '사용자 지정 비용 사용';

  @override
  String get editorUseGameDefaults => '게임 기본값 사용';

  @override
  String get editorGameDefaultsPreserveStoredCustomCostsDefaultGameValues =>
      '게임 기본값을 사용해도 저장된 사용자 지정 비용은 유지됩니다. 이 화면은 게임 기본 수치를 불러오지 않습니다.';

  @override
  String get editorMapDefaultSettings => '맵 기본 설정';

  @override
  String editorCopiesOnlyCurrentTechPlayerEditsToPlayers1(String value0) {
    return '현재 기술 #$value0의 플레이어 변경사항만 플레이어 1~8에 복사합니다. 맵 비용과 기본값은 제외합니다.';
  }

  @override
  String get editorUsePlayerSettings => '플레이어 설정 사용';

  @override
  String get editorInheritMapSettings => '맵 설정 상속';

  @override
  String get editorAvailable => '사용 가능';

  @override
  String get editorNotResearched => '미연구';

  @override
  String get editorAlreadyResearched => '연구 완료';

  @override
  String
  get editorMapSettingsAffectInheritingPlayersInheritancePreservesStoredPlayer =>
      '맵 설정은 이를 상속하는 플레이어에 적용됩니다. 상속해도 저장된 플레이어 플래그는 유지됩니다. 사용 가능 여부와 연구 상태는 독립적입니다.';

  @override
  String editorPendingChangesAcrossTechsAndPlayersApplyUpdatesThe(
    String value0,
  ) {
    return '기술과 플레이어에 대기 중인 변경 $value0개. 적용은 문서에 반영하며, 다른 이름으로 저장하면 맵 파일에 기록합니다.';
  }

  @override
  String get editorUnitAvailability => '유닛 사용 가능 여부';

  @override
  String get editorMapWideUnitProductionSettingsSeparateFromPlacedUnit =>
      '맵 전체의 유닛 생산 설정입니다. 배치된 유닛의 속성 패널과는 별도입니다.';

  @override
  String get editorUnit => '유닛';

  @override
  String editorMapDefaultsAndPlayerOnlyInheritanceChangesOnlyIf(String value0) {
    return '맵 기본값과 플레이어 $value0만 편집합니다. 상속은 편집한 경우에만 변경됩니다.';
  }

  @override
  String get editorMapDefaultAffectsAllInheritingPlayers =>
      '맵 기본값: 상속하는 모든 플레이어에 적용';

  @override
  String get editorDefaultProhibited => '기본값: 금지';

  @override
  String get editorDefaultAllowed => '기본값: 허용';

  @override
  String editorCopiesOnlyCurrentUnitPlayerEditsToPlayers1(String value0) {
    return '현재 유닛 #$value0의 플레이어 변경사항만 플레이어 1~8에 복사합니다. 맵 기본값은 제외합니다.';
  }

  @override
  String get editorPlayerSettingSource => '플레이어 설정 원본';

  @override
  String get editorUsePlayerOverride => '플레이어 개별 설정 사용';

  @override
  String get editorInheritMapDefault => '맵 기본값 상속';

  @override
  String get editorStoredPlayerOverride => '저장된 플레이어 개별 설정';

  @override
  String get editorPlayerProhibited => '플레이어: 금지';

  @override
  String get editorPlayerAllowed => '플레이어: 허용';

  @override
  String editorEffectiveAvailability(String value0) {
    return '실제 사용 가능 여부: $value0';
  }

  @override
  String get editorUnknownStoredFlagsPreserved => '알 수 없음 (저장된 플래그 유지)';

  @override
  String
  get editorInheritancePreservesTheStoredOverrideAvailabilityDoesNotBypass =>
      '상속해도 저장된 개별 설정은 유지됩니다. 사용 가능 설정은 게임 선행 조건을 무시하거나 유닛을 배치하지 않습니다.';

  @override
  String editorPendingChangesApplyUpdatesAllEditedUnitsAndPlayers(
    String value0,
  ) {
    return '대기 중인 변경 $value0개. 적용은 변경한 모든 유닛과 플레이어에 반영하며, 다른 이름으로 저장하면 맵 파일에 기록합니다.';
  }

  @override
  String
  get editorLocalWeaponReferencesUnavailableConfigureStarCraftAssetsAndRetry =>
      '로컬 무기 참조를 사용할 수 없습니다. StarCraft 자산을 설정한 후 다시 시도하세요.';

  @override
  String editorUnit88a3c859(String value0, String value1) {
    return '$value0\n유닛 #$value1';
  }

  @override
  String get editorUnitPreviewRequiresLocalStarCraftGraphics =>
      '유닛 미리보기에는 로컬 StarCraft 그래픽이 필요합니다.';

  @override
  String get editorConfigureStarCraftAssetsToLoadUnitLinks =>
      '유닛 연결을 불러오려면 StarCraft 자산을 설정하세요.';

  @override
  String get editorGround => '지상';

  @override
  String get editorAir => '공중';

  @override
  String editorNone(String value0) {
    return '$value0: 없음';
  }

  @override
  String editorSubunit(String value0, String value1) {
    return '하위 유닛: $value0 (#$value1)';
  }

  @override
  String get editorSubunitWeaponsKeepsTheSelectedUnit => '하위 유닛 무기: 선택한 유닛 유지';

  @override
  String get editorNoLinkedWeaponSelectAWeaponManually =>
      '연결된 무기가 없습니다. 무기를 직접 선택하세요.';

  @override
  String editorAutoSelectedFromWeaponChangesAffectAllUnitsSharing(
    String value0,
    String value1,
    String value2,
  ) {
    return '자동 선택: $value2의 $value0 (#$value1). 무기 변경은 이를 공유하는 모든 유닛에 적용됩니다.';
  }

  @override
  String get editorRetryUnitLinks => '유닛 연결 다시 불러오기';

  @override
  String editorUnit24496eb9(String value0, String value1) {
    return '유닛 #$value0: $value1';
  }

  @override
  String editorWeaponDamageMustBeAnIntegerFrom0To(String value0) {
    return '무기 #$value0: 피해량은 0~65535의 정수여야 합니다.';
  }

  @override
  String get editorUnitSettings => '유닛 설정';

  @override
  String get editorMapWideUnitTypesSeparateFromPlacedUnitProperties =>
      '맵 전체의 유닛 종류 설정입니다. 배치된 유닛의 속성과는 별도입니다.';

  @override
  String editorEditing4dc9e6e6(String value0, String value1) {
    return '편집 중: $value0$value1.';
  }

  @override
  String get editorAlternateSectionPreservedWithoutSynchronization =>
      '; 다른 섹션은 동기화하지 않고 유지';

  @override
  String editorUnit38894196(String value0, String value1) {
    return '$value0 (유닛 #$value1)';
  }

  @override
  String get editorUnitValuesNamesAndDefaultFlagsOnlySharedWeapon =>
      '유닛 수치, 이름, 기본값 플래그만 편집합니다. 공유 무기 피해량은 아래에서 별도로 선택합니다.';

  @override
  String get editorUseCustomValues => '사용자 지정 수치 사용';

  @override
  String editorStoredDefaultFlagPreserved(String value0) {
    return '저장된 기본값 플래그 $value0 (유지)';
  }

  @override
  String get editorFieldsShowStoredCustomValuesGameDefaultNumbersAre =>
      '필드는 저장된 사용자 지정 수치를 표시합니다. 게임 기본 수치는 불러오지 않습니다.';

  @override
  String get editorRestoreSelectedUnitDefaults => '선택한 유닛 기본값 복원';

  @override
  String get editorUnitNameEmptyGameName => '유닛 이름 (비워 두면 게임 이름)';

  @override
  String get editorSharedWeaponDamage => '공유 무기 피해량';

  @override
  String get editorAWeaponChangeAffectsEveryUnitUsingThatWeapon =>
      '무기 변경은 해당 무기를 사용하는 모든 유닛에 적용됩니다. 유닛 복원은 공유 무기 피해량을 초기화하지 않습니다.';

  @override
  String get editorWeapon => '무기';

  @override
  String get editorSharedWeaponDamageOnlyAllUnitsReferencingTargetWeapons =>
      '공유 무기 피해량만 편집합니다. 대상 무기를 참조하는 모든 유닛에 영향을 줄 수 있습니다.';

  @override
  String get editorDamagePerUpgrade => '업그레이드당 피해량';

  @override
  String get editorBaseDamage => '기본 피해량';

  @override
  String get editorApplyUpdatesAllEditedUnitTypesAndWeaponsSave =>
      '적용은 변경한 모든 유닛 종류와 무기에 반영합니다. 다른 이름으로 저장하면 맵 파일에 기록합니다.';

  @override
  String editorUpgrade(String value0, String value1, String value2) {
    return '업그레이드 #$value0, $value1: $value2';
  }

  @override
  String get editorEffectiveLevelsUnknownStoredFlagPreserved =>
      '실제 적용 레벨: 알 수 없음 (저장된 플래그 유지)';

  @override
  String editorEffectiveLevelsStartMaximum(String value0, String value1) {
    return '실제 적용 레벨: $value0 / $value1 (시작 / 최대)';
  }

  @override
  String get editorUpgradeSettings => '업그레이드 설정';

  @override
  String get editorUpgraded423b17 => '업그레이드';

  @override
  String get editorMapDefaultLevels => '맵 기본 레벨';

  @override
  String editorCopiesOnlyCurrentUpgradePlayerEditsToPlayers1(String value0) {
    return '현재 업그레이드 #$value0의 플레이어 변경사항만 플레이어 1~8에 복사합니다. 맵 비용과 기본값은 제외합니다.';
  }

  @override
  String get editorUsePlayerLevels => '플레이어 레벨 사용';

  @override
  String get editorInheritMapLevels => '맵 레벨 상속';

  @override
  String
  get editorMapLevelsAffectInheritingPlayersInheritancePreservesStoredPlayer =>
      '맵 레벨은 이를 상속하는 플레이어에 적용됩니다. 상속해도 저장된 플레이어 레벨은 유지됩니다. 시작 레벨은 최대 레벨을 넘을 수 없습니다.';

  @override
  String editorPendingChangesAcrossUpgradesAndPlayersApplyUpdatesThe(
    String value0,
  ) {
    return '업그레이드와 플레이어에 대기 중인 변경 $value0개. 적용은 문서에 반영하며, 다른 이름으로 저장하면 맵 파일에 기록합니다.';
  }

  @override
  String get editorLoadingLocalWeaponReferences => '로컬 무기 참조 불러오는 중…';

  @override
  String editorWeaponReferenceListUnavailable(String value0) {
    return '무기 참조 목록을 사용할 수 없음: $value0';
  }

  @override
  String get editorSourceChanged => '원본 변경';

  @override
  String get editorReloadWeaponReferences => '무기 참조 다시 불러오기';

  @override
  String get editorNoneInThisDATSnapshot => '이 DAT 스냅샷에는 없음';

  @override
  String editorWeaponDirectGroundAirReferences(String value0, String value1) {
    return '무기 #$value0: 직접 지상·공중 참조: $value1';
  }

  @override
  String editorUnitsReferencingThoseSubunits(String value0) {
    return '해당 하위 유닛을 참조하는 유닛: $value0';
  }

  @override
  String editorSource854c792f(String value0) {
    return '원본: $value0';
  }

  @override
  String get editorDATReferencesOnlySpellsSpawnedProjectilesUnitsAndEUD =>
      'DAT 참조만 표시합니다. 주문, 생성되는 투사체·유닛, EUD 실행 중 변경에는 추가 영향이 있을 수 있습니다.';

  @override
  String get editorOpenAMapToManageResources => '리소스를 관리하려면 맵을 여세요.';

  @override
  String get editorResources => '리소스';

  @override
  String get editorUndo71fd4acf => '실행 취소';

  @override
  String get editorRedo7412e5e9 => '다시 실행';

  @override
  String get editorAddString => '문자열 추가';

  @override
  String get editorImportPCMWAV => 'PCM WAV 가져오기';

  @override
  String get editorStopPreview => '미리보기 중지';

  @override
  String editorStringsBytesOffsetLimitSaveAsWritesPendingResource(
    String value0,
    String value1,
    String value2,
  ) {
    return '문자열 $value0개 • $value1바이트 • 오프셋 한도 $value2 • 다른 이름으로 저장하면 대기 중인 리소스 변경을 기록합니다.';
  }

  @override
  String get editorReferenceCoverageIncompleteDeletionRestricted =>
      '참조 검사 범위 불완전: 삭제 제한';

  @override
  String
  get editorArchiveListingIncompleteUnlistedSoundsMayExistImportsDeletions =>
      '아카이브 목록이 불완전합니다. 목록에 없는 사운드가 있을 수 있어 가져오기와 삭제를 제한합니다.';

  @override
  String get editorSearchTextStringIDOrSoundPath => '텍스트, 문자열 ID 또는 사운드 경로 검색';

  @override
  String get editorWorking => '작업 중…';

  @override
  String get editorStrings => '문자열';

  @override
  String get editorSounds => '사운드';

  @override
  String get editorInvalidUTF8RawBytesPreserved => '잘못된 UTF-8: 원본 바이트 유지';

  @override
  String editorBytesKnownUseS(String value0, String value1, String value2) {
    return '$value0바이트 • 확인된 사용 $value1곳$value2';
  }

  @override
  String get editorExplicitReplacementRequired => ' • 명시적 교체 필요';

  @override
  String get editorClearUnreferencedString => '미참조 문자열 비우기';

  @override
  String editorBytesPendingImport(String value0) {
    return '$value0바이트 • 가져오기 대기';
  }

  @override
  String get editorReferencedPathNotListedInThisMap => '참조된 경로: 이 맵의 목록에는 없음';

  @override
  String editorBytesLocale(String value0, String value1) {
    return '$value0바이트 • 로캘 $value1';
  }

  @override
  String get editorPreviewSound => '사운드 미리보기';

  @override
  String get editorExportSound => '사운드 내보내기';

  @override
  String get editorDeleteSound => '사운드 삭제';

  @override
  String get editorDeleteSoundf1d564e6 => '사운드를 삭제할까요?';

  @override
  String editorRemovalAppliesOnSaveAsUndoRestoresThisEdit(String value0) {
    return '$value0\n다른 이름으로 저장하면 삭제가 반영됩니다. 실행 취소로 복원할 수 있습니다.';
  }

  @override
  String get editorDelete => '삭제';

  @override
  String get editorMapChanged => '맵이 변경되었습니다.';

  @override
  String editorResourcesAreReadOnly(String value0) {
    return '리소스는 읽기 전용입니다: $value0';
  }

  @override
  String get editorInvalidUTF8EnterExplicitReplacementTextOriginalBytes =>
      '잘못된 UTF-8입니다. 교체할 텍스트를 직접 입력하세요. 적용 전까지 원본 바이트는 유지됩니다.';

  @override
  String editorString(String value0) {
    return '문자열 #$value0';
  }

  @override
  String get editorEditSharedIDAffectsAllReferences => '공유 ID 편집: 모든 참조에 적용';

  @override
  String editorSeparate(String value0) {
    return '분리: $value0';
  }

  @override
  String get editorAdditionalUnknownUsesMayExistNoAutomaticCleanupIs =>
      '확인되지 않은 사용처가 더 있을 수 있습니다. 자동 정리는 수행하지 않습니다.';

  @override
  String get editorUTF8Text => 'UTF-8 텍스트';

  @override
  String editorKnownReferences(String value0) {
    return '확인된 참조 $value0개';
  }

  @override
  String get editorWriteEpScriptHere => '// 여기에 epScript를 작성하세요';

  @override
  String get editorModified => '수정됨';

  @override
  String get editorClean => '변경 없음';

  @override
  String get editorInMemoryDraft => '메모리 초안';

  @override
  String editorLnCol(String value0, String value1) {
    return '$value0행, $value1열';
  }

  @override
  String editorActionSReferenceThisSlotApplyingChangesAffectsAll(
    String value0,
  ) {
    return '액션 $value0개가 이 슬롯을 참조합니다. 적용하면 모두에 영향을 줍니다.';
  }

  @override
  String editorNewStringIDUseThisIDInATrigger(String value0) {
    return '새 문자열 ID: $value0. 트리거 액션에서 이 ID를 사용하세요.';
  }

  @override
  String get editorAddTriggerText => '트리거 텍스트 추가';

  @override
  String get editorSwitchNames => '스위치 이름';

  @override
  String get editorUnitPropertySlots => '유닛 속성 슬롯';

  @override
  String editorID(String value0, String value1) {
    return '$value0 ID $value1';
  }

  @override
  String get editorProperty => '속성';

  @override
  String get editorSwitch => '스위치';

  @override
  String get editorText => '텍스트';

  @override
  String get editorUncheckedValuesInheritTheGameDefaultSpecialStatesCan =>
      '선택하지 않은 값은 게임 기본값을 상속합니다. 특수 상태는 상속, 활성화, 비활성화를 선택할 수 있습니다.';

  @override
  String get editorInherit => '상속';

  @override
  String get editorEnabled => '활성화';

  @override
  String get editorDisabled => '비활성화';

  @override
  String get editorPrepareChanges => '변경 준비';

  @override
  String get editorApplyToMap => '맵에 적용';

  @override
  String get editorYes => '예';

  @override
  String get editorNo => '아니요';

  @override
  String get editorUnknown => '알 수 없음';

  @override
  String get editorAllowed => '허용';

  @override
  String get editorProhibited => '금지';

  @override
  String get editorMapdfa2efb1 => '맵';

  @override
  String editorTheCHKSectionHeaderIsTruncatedAtByteOffset(String value0) {
    return '바이트 오프셋 $value0에서 CHK 섹션 헤더가 잘렸습니다.';
  }

  @override
  String get editorUseAnIntactScenarioChkOrOpenTheMap =>
      '정상적인 scenario.chk를 사용하거나 맵을 읽기 전용으로 여세요.';

  @override
  String editorSectionDeclaresBytesButOnlyBytesRemain(
    String value0,
    String value1,
    String value2,
  ) {
    return '섹션 \"$value0\"은 $value1바이트를 선언했지만 $value2바이트만 남았습니다.';
  }

  @override
  String editorSectionMustContainExactlyPayloadBytesButContains(
    String value0,
    String value1,
    String value2,
  ) {
    return '섹션 \"$value0\"의 데이터는 정확히 $value1바이트여야 하지만 $value2바이트입니다.';
  }

  @override
  String get editorKeepThisSectionUnchangedAndTreatTheMapAs =>
      '이 섹션은 변경하지 말고 맵을 읽기 전용으로 취급하세요.';

  @override
  String editorIsOutsideTheMapPixelBounds(String value0, String value1) {
    return '$value0 $value1의 위치가 맵 픽셀 경계를 벗어났습니다.';
  }

  @override
  String editorMoveTheObjectInside0By0OrKeep(String value0, String value1) {
    return '객체를 0~$value0, 0~$value1 범위 안으로 옮기세요. 의도적인 EUD 값이라면 원본 레코드를 유지하세요.';
  }

  @override
  String editorRefersToPlayerValueOutsideTheSupported011(
    String value0,
    String value1,
    String value2,
  ) {
    return '$value0 $value1이 지원 범위 0~11 밖의 플레이어 값 $value2를 참조합니다.';
  }

  @override
  String get editorChoosePlayer1ThroughPlayer12OrKeepThe =>
      '플레이어 1~12를 선택하세요. 의도적인 EUD 데이터라면 원본 값을 유지하세요.';

  @override
  String editorLocationDoesNotFormAValidRectangleInsideThe(String value0) {
    return '위치 $value0이 맵 내부의 유효한 직사각형이 아닙니다.';
  }

  @override
  String editorUseLeftRightAndTopBottomInside0By(String value0, String value1) {
    return '0~$value0, 0~$value1 범위에서 왼쪽 < 오른쪽, 위 < 아래가 되도록 설정하세요. 의도적인 값이라면 원본을 유지하세요.';
  }

  @override
  String editorUsesStringIDButMultipleSTRSTRxTablesMake(
    String value0,
    String value1,
  ) {
    return '$value0이 문자열 ID $value1을 사용하지만 STR/STRx 테이블이 여러 개여서 참조가 모호합니다.';
  }

  @override
  String get editorInspectTheRawStringSectionsTheEditorWillNot =>
      '원본 문자열 섹션을 검사하세요. 편집기는 활성 테이블을 추측하지 않습니다.';

  @override
  String editorUsesStringIDButNoReadableSTRSTRxTable(
    String value0,
    String value1,
  ) {
    return '$value0이 문자열 ID $value1을 사용하지만 읽을 수 있는 STR/STRx 테이블이 없습니다.';
  }

  @override
  String get editorInspectTheRawStringTableBeforeChangingThisReference =>
      '이 참조를 변경하기 전에 원본 문자열 테이블을 검사하세요.';

  @override
  String editorUsesStringIDButTheTableContainsOnlyEntries(
    String value0,
    String value1,
    String value2,
  ) {
    return '$value0이 문자열 ID $value1을 사용하지만 테이블에는 항목이 $value2개뿐입니다.';
  }

  @override
  String get editorChooseAnExistingStringIDOrClearTheReference =>
      '기존 문자열 ID를 선택하거나 ID 0으로 참조를 해제하세요.';

  @override
  String editorUsesStringIDWhoseRawEntryCannotBeResolved(
    String value0,
    String value1,
  ) {
    return '$value0이 사용하는 문자열 ID $value1의 원본 항목을 안전하게 해석할 수 없습니다.';
  }

  @override
  String get editorInspectTheStringTableStructuralDiagnosticsAndPreserveThe =>
      '문자열 테이블 구조 진단을 검사하세요. 원인을 파악할 때까지 원본 참조를 유지하세요.';

  @override
  String editorSectionEndsWithAnIncompleteByteRecord(
    String value0,
    String value1,
    String value2,
  ) {
    return '섹션 \"$value0\"이 불완전한 $value1바이트 $value2 레코드로 끝납니다.';
  }

  @override
  String get editorKeepThisObjectSectionUnchangedAndReadOnly =>
      '이 객체 섹션을 변경하지 말고 읽기 전용으로 유지하세요.';

  @override
  String editorSectionMustContainEither64Or255CompleteLocation(String value0) {
    return '섹션 \"$value0\"에는 완전한 위치 레코드가 64개 또는 255개 있어야 합니다.';
  }

  @override
  String get editorKeepThisLocationSectionUnchangedAndReadOnly =>
      '이 위치 섹션을 변경하지 말고 읽기 전용으로 유지하세요.';

  @override
  String editorSectionDoesNotContainItsCompleteByteStringCount(
    String value0,
    String value1,
  ) {
    return '섹션 \"$value0\"의 $value1바이트 문자열 개수 필드가 불완전합니다.';
  }

  @override
  String get editorKeepThisStringTableUnchangedAndReadOnly =>
      '이 문자열 테이블을 변경하지 말고 읽기 전용으로 유지하세요.';

  @override
  String editorSectionDeclaresStringsButItsOffsetTableExceedsThe(
    String value0,
    String value1,
  ) {
    return '섹션 \"$value0\"이 문자열 $value1개를 선언했지만 오프셋 테이블이 데이터 범위를 넘습니다.';
  }

  @override
  String editorStringInSectionPointsOutsideThePayload(
    String value0,
    String value1,
  ) {
    return '섹션 \"$value1\"의 문자열 $value0이 데이터 범위 밖을 가리킵니다.';
  }

  @override
  String editorStringInSectionPointsIntoTheCountOrOffset(
    String value0,
    String value1,
  ) {
    return '섹션 \"$value1\"의 문자열 $value0이 개수 또는 오프셋 테이블 내부를 가리킵니다.';
  }

  @override
  String editorStringInSectionHasNoNullTerminatorBeforeThe(
    String value0,
    String value1,
  ) {
    return '섹션 \"$value1\"의 문자열 $value0이 데이터 끝까지 널 종료자를 갖고 있지 않습니다.';
  }

  @override
  String editorSectionEndsWithAnIncomplete2ByteTileRecord(String value0) {
    return '섹션 \"$value0\"이 불완전한 2바이트 타일 레코드로 끝납니다.';
  }

  @override
  String get editorKeepThisTerrainSectionUnchangedAndReadOnly =>
      '이 지형 섹션을 변경하지 말고 읽기 전용으로 유지하세요.';

  @override
  String editorSectionContainsTilesButXMapDimensionsRequire(
    String value0,
    String value1,
    String value2,
    String value3,
    String value4,
  ) {
    return '섹션 \"$value0\"에는 타일이 $value1개지만 ${value2}x$value3 맵 크기에는 $value4개가 필요합니다.';
  }

  @override
  String get editorRecoveryOpened => '복구본을 열었습니다';

  @override
  String get editorOnlyScmAndScxMapFilesCanBeOpened =>
      '.scm 및 .scx 맵 파일만 열 수 있습니다.';

  @override
  String get editorChooseAStarCraftMapWithAScmOrScx =>
      '확장자가 .scm 또는 .scx인 StarCraft 맵을 선택하세요.';

  @override
  String get editorAnotherEditorOperationIsAlreadyRunning =>
      '다른 편집 작업이 이미 실행 중입니다.';

  @override
  String get editorWaitForTheCurrentOperationToFinishAndTry =>
      '현재 작업이 끝날 때까지 기다린 후 다시 시도하세요.';

  @override
  String get editorReadingMapArchive => '맵 아카이브 읽는 중';

  @override
  String get editorFingerprintingSourceMap => '원본 맵 지문 계산 중';

  @override
  String get editorParsingScenarioChk => 'scenario.chk 분석 중';

  @override
  String get editorValidatingMapMetadata => '맵 메타데이터 검증 중';

  @override
  String get editorTheSourceMapChangedWhileItWasBeingOpened =>
      '맵을 여는 동안 원본 맵이 변경되었습니다.';

  @override
  String get editorCloseTheOtherProgramThatIsEditingTheMap =>
      '맵을 편집하는 다른 프로그램을 닫고 다시 여세요.';

  @override
  String get editorTheMapOpenedButTheRecentMapsListWas =>
      '맵을 열었지만 최근 맵 목록은 갱신하지 못했습니다.';

  @override
  String get editorCheckAccessToTheApplicationSettingsFolderAndReopen =>
      '앱 설정 폴더 접근 권한을 확인한 후 맵을 다시 여세요.';

  @override
  String get editorMapOpenedInRestrictedReadOnlyMode =>
      '제한된 읽기 전용 모드로 맵을 열었습니다';

  @override
  String get editorMapOpened => '맵을 열었습니다';

  @override
  String get editorTheMapCouldNotBeOpenedBecauseOfAn =>
      '예기치 않은 오류로 맵을 열지 못했습니다.';

  @override
  String get editorRetryTheOperationIfItFailsAgainInspectThe =>
      '다시 시도하세요. 계속 실패하면 앱 로그를 검사하세요.';

  @override
  String get editorTheMapWasSavedButTheRecentMapsList =>
      '맵을 저장했지만 최근 맵 목록은 갱신하지 못했습니다.';

  @override
  String get editorCheckAccessToTheApplicationSettingsFolderAndReopen915aeaa0 =>
      '앱 설정 폴더 접근 권한을 확인한 후 저장된 맵을 다시 여세요.';

  @override
  String get editorTheMapFileDialogCouldNotBeOpened => '맵 파일 대화상자를 열지 못했습니다.';

  @override
  String get editorRetryTheOperationOrRestartTheApplication =>
      '다시 시도하거나 앱을 다시 시작하세요.';

  @override
  String get editorTheSourceMapFingerprintCouldNotBeVerified =>
      '원본 맵 지문을 검증하지 못했습니다.';

  @override
  String get editorCheckThatTheMapStillExistsIsReadableAnd =>
      '맵이 존재하고 읽을 수 있으며 다른 프로그램이 변경 중이 아닌지 확인하세요.';

  @override
  String get editorOpenAMapBeforeUsingSaveAs => '다른 이름으로 저장하기 전에 맵을 여세요.';

  @override
  String get editorOpenAScmOrScxMapAndTryAgain =>
      '.scm 또는 .scx 맵을 열고 다시 시도하세요.';

  @override
  String editorEditedContainInvalidFieldValuesOrReferences(String value0) {
    return '편집한 $value0에 유효하지 않은 필드 값 또는 참조가 있습니다.';
  }

  @override
  String editorOpenValidateReferencesAndCorrectTheReportedSlots(String value0) {
    return '$value0 → 참조 검증을 열고 보고된 슬롯을 수정하세요.';
  }

  @override
  String get editorBriefing => '브리핑';

  @override
  String get editorTriggers => '트리거';

  @override
  String get editorTheSaveAsDestinationMustBeAnAbsoluteWindows =>
      '저장 대상은 Windows 절대 경로여야 합니다.';

  @override
  String get editorChooseTheDestinationUsingTheSaveAsDialog =>
      '다른 이름으로 저장 대화상자에서 대상을 선택하세요.';

  @override
  String get editorNewBroodWarMapsMustBeSavedAsScx =>
      '새 Brood War 맵은 .scx로 저장해야 합니다.';

  @override
  String get editorSaveAsSupportsOnlyScmAndScxMapFiles =>
      '다른 이름으로 저장은 .scm 및 .scx 맵 파일만 지원합니다.';

  @override
  String get editorChooseADestinationEndingInScx => '.scx로 끝나는 대상을 선택하세요.';

  @override
  String get editorChooseADestinationEndingInScmOrScx =>
      '.scm 또는 .scx로 끝나는 대상을 선택하세요.';

  @override
  String get editorSaveAsCannotOverwriteTheCurrentlyOpenSourceMap =>
      '현재 열려 있는 원본 맵을 덮어쓸 수 없습니다.';

  @override
  String get editorChooseADifferentOutputFileName => '다른 출력 파일 이름을 선택하세요.';

  @override
  String get editorTheSaveAsDestinationAlreadyExists => '저장 대상이 이미 존재합니다.';

  @override
  String get editorChooseANewFileNameOrExplicitlyConfirmReplacement =>
      '새 파일 이름을 선택하거나 다른 이름으로 저장 대화상자에서 교체를 명시적으로 확인하세요.';

  @override
  String get editorPreparingNewMap => '새 맵 준비 중';

  @override
  String get editorCheckingSourceMap => '원본 맵 검사 중';

  @override
  String get editorValidatingNewMap => '새 맵 검증 중';

  @override
  String get editorCheckingSourceMapFingerprint => '원본 맵 지문 검사 중';

  @override
  String get editorTheSourceMapChangedAfterItWasOpenedSo =>
      '맵을 연 뒤 원본이 변경되어 저장을 중단했습니다.';

  @override
  String get editorReopenTheSourceMapToReviewTheExternalChanges =>
      '저장 전에 원본 맵을 다시 열어 외부 변경사항을 검토하세요.';

  @override
  String get editorCheckingExistingDestinationFingerprint => '기존 대상 지문 검사 중';

  @override
  String get editorATemporarySaveAsWorkspaceCouldNotBeCreated =>
      '임시 저장 작업 폴더를 만들지 못했습니다.';

  @override
  String get editorCheckDestinationFolderPermissionsAndFreeDiskSpace =>
      '대상 폴더 권한과 디스크 여유 공간을 확인하세요.';

  @override
  String get editorWritingTemporaryMapArchive => '임시 맵 아카이브 기록 중';

  @override
  String get editorReopeningAndVerifyingTemporaryMap => '임시 맵 다시 열어 검증 중';

  @override
  String get editorTheReopenedTemporaryMapDoesNotContainTheExpected =>
      '다시 연 임시 맵의 scenario.chk 바이트가 예상 값과 다릅니다.';

  @override
  String get editorKeepTheSourceMapUnchangedAndReportTheArchive =>
      '원본 맵을 유지하고 아카이브 기록 실패를 보고하세요.';

  @override
  String get editorTheReopenedTemporaryMapFailedCHKValidation =>
      '다시 연 임시 맵이 CHK 검증에 실패했습니다.';

  @override
  String get editorKeepTheSourceMapUnchangedAndInspectParserDiagnostics =>
      '원본 맵을 유지하고 파서 진단을 검사하세요.';

  @override
  String get editorFingerprintingVerifiedOutput => '검증된 출력 지문 계산 중';

  @override
  String get editorTheVerifiedTemporaryMapFingerprintCouldNotBeCalculated =>
      '검증된 임시 맵의 지문을 계산하지 못했습니다.';

  @override
  String get editorRecheckingSourceMapFingerprint => '원본 맵 지문 재검사 중';

  @override
  String get editorTheSourceMapChangedDuringSaveAsSoThe =>
      '저장 중 원본 맵이 변경되어 검증된 출력을 최종 대상으로 옮기지 않았습니다.';

  @override
  String get editorReopenTheSourceMapToReviewTheExternalChangesf53fd806 =>
      '원본 맵을 다시 열어 외부 변경사항을 검토하고 새 출력 이름으로 재시도하세요.';

  @override
  String get editorRecheckingSaveAsDestination => '저장 대상 재검사 중';

  @override
  String get editorPromotingVerifiedMapToFinalDestination =>
      '검증된 맵을 최종 대상으로 이동 중';

  @override
  String get editorTheExistingDestinationIsSafeInABackupBut =>
      '기존 대상은 백업에 안전하게 보관되었지만 자동 복원에 실패했습니다.';

  @override
  String editorRestoreTheBackupToBeforeRetryingSaveAs(String value0) {
    return '저장을 재시도하기 전에 백업을 $value0에 복원하세요.';
  }

  @override
  String get editorTheVerifiedMapCouldNotBePromotedToIts =>
      '검증된 맵을 최종 대상으로 옮기지 못했습니다.';

  @override
  String get editorCheckDestinationFolderPermissionsAndChooseANewName =>
      '대상 폴더 권한을 확인하고 새 이름을 선택하세요.';

  @override
  String get editorThePreviousDestinationWasPreservedAsARecoveryBackup =>
      '이전 대상은 복구 백업으로 보관되었습니다.';

  @override
  String get editorKeepTheBackupUntilTheReplacementMapHasBeen =>
      '교체한 맵을 검증할 때까지 백업을 유지하세요.';

  @override
  String get editorMapSavedAndVerified => '맵 저장 및 검증 완료';

  @override
  String get editorMapSavedVerifiedAndBackedUp => '맵 저장, 검증 및 백업 완료';

  @override
  String get editorSaveAsFailedBecauseOfAnUnexpectedError =>
      '예기치 않은 오류로 저장에 실패했습니다.';

  @override
  String get editorRetryWithANewOutputNameTheSourceMap =>
      '새 출력 이름으로 다시 시도하세요. 원본 맵은 수정하지 않았습니다.';

  @override
  String get editorTheSaveAsDialogCouldNotBeOpened =>
      '다른 이름으로 저장 대화상자를 열지 못했습니다.';

  @override
  String get editorCheckThatTheSourceMapStillExistsIsReadable =>
      '원본 맵이 존재하고 읽을 수 있으며 다른 프로그램이 변경 중이 아닌지 확인하세요.';

  @override
  String get editorTheExistingSaveAsDestinationCouldNotBeVerified =>
      '기존 저장 대상을 검증하지 못했습니다.';

  @override
  String get editorCheckThatTheDestinationIsAReadableRegularFile =>
      '대상이 읽을 수 있는 일반 파일인지 확인하고 다시 시도하세요.';

  @override
  String get editorTheSaveAsDestinationChangedWhileTheMapWas =>
      '맵을 준비하는 동안 저장 대상이 변경되었습니다.';

  @override
  String get editorReviewTheDestinationInAnotherProgramThenRetryAnd =>
      '다른 프로그램에서 대상을 검토한 후 재시도하고 교체를 다시 확인하세요.';

  @override
  String get editorWaitingForEuddraftToStart => 'euddraft 시작 대기 중';

  @override
  String get editorTheEuddraftEventStreamFailedUnexpectedly =>
      'euddraft 이벤트 스트림에 예기치 않은 오류가 발생했습니다.';

  @override
  String get editorTheEuddraftBuildCouldNotBeStarted =>
      'euddraft 빌드를 시작하지 못했습니다.';

  @override
  String get editorStoppingEuddraft => 'euddraft 중지 중';

  @override
  String get editorTheEUDBuildCancellationRequestFailed =>
      'EUD 빌드 취소 요청에 실패했습니다.';

  @override
  String get editorEuddraftIsStillRunning => 'euddraft가 아직 실행 중입니다';

  @override
  String get editorEuddraftReturnedAnEventForADifferentBuild =>
      'euddraft가 다른 빌드의 이벤트를 반환했습니다.';

  @override
  String editorEuddraftIsRunning(String value0) {
    return 'euddraft $value0 실행 중';
  }

  @override
  String get editorValidatingAndPromotingTheGeneratedEUDMap =>
      '생성된 EUD 맵 검증 및 이동 중';

  @override
  String get editorEUDBuildWasCancelled => 'EUD 빌드가 취소되었습니다';

  @override
  String get editorEUDBuildFailed => 'EUD 빌드 실패';

  @override
  String get editorEUDMapBuiltVerifiedAndPromoted => 'EUD 맵 빌드, 검증 및 이동 완료';

  @override
  String get editorTheEuddraftEventStreamEndedWithoutAResult =>
      'euddraft 이벤트 스트림이 결과 없이 종료되었습니다.';

  @override
  String get editorInspectTheBuildLogAndRetry => '빌드 로그를 검사하고 다시 시도하세요.';

  @override
  String get editorABuildWithThisIDIsAlreadyActive => '이 ID의 빌드가 이미 실행 중입니다.';

  @override
  String get editorWaitForTheActiveBuildToFinishAndRetry =>
      '실행 중인 빌드가 끝나면 다시 시도하세요.';

  @override
  String get editorTheEUDBuildInputsAreNotSafeRegularFiles =>
      'EUD 빌드 입력이 안전한 일반 파일이 아닙니다.';

  @override
  String get editorCheckTheBaseMapSourceRootEntrySourceAnd =>
      '기본 맵, 소스 루트, 진입 소스 및 출력 폴더를 확인하세요.';

  @override
  String get editorTheEUDOutputResolvesToTheBaseMap =>
      'EUD 출력이 기본 맵과 같은 파일을 가리킵니다.';

  @override
  String get editorChooseASeparateOutputFile => '별도의 출력 파일을 선택하세요.';

  @override
  String get editorTheEUDBaseMapFingerprintCouldNotBeCalculated =>
      'EUD 기본 맵 지문을 계산하지 못했습니다.';

  @override
  String get editorTheBaseMapDoesNotMatchTheEUDProject =>
      '기본 맵이 EUD 프로젝트 연결 정보와 일치하지 않습니다.';

  @override
  String get editorOpenAndVerifyTheBoundMapThenPrepareAgain =>
      '연결된 맵을 열어 검증한 후 다시 준비하세요.';

  @override
  String get editorTheEpScriptEntrySourceFingerprintCouldNotBeCalculated =>
      'epScript 진입 소스 지문을 계산하지 못했습니다.';

  @override
  String get editorTheEUDOutputAlreadyExists => 'EUD 출력이 이미 존재합니다.';

  @override
  String get editorChooseANewOutputOrExplicitlyConfirmReplacement =>
      '새 출력을 선택하거나 교체를 명시적으로 확인하세요.';

  @override
  String get editorTheExistingEUDOutputFingerprintCouldNotBeCalculated =>
      '기존 EUD 출력 지문을 계산하지 못했습니다.';

  @override
  String get editorTheTemporaryEUDBuildWorkspaceCouldNotBeCreated =>
      '임시 EUD 빌드 작업 폴더를 만들지 못했습니다.';

  @override
  String get editorCheckOutputFolderPermissionsAndAvailableDiskSpace =>
      '출력 폴더 권한과 디스크 여유 공간을 확인하세요.';

  @override
  String get editorEuddraftExitedSuccessfullyButDidNotCreateAReadable =>
      'euddraft가 정상 종료했지만 읽을 수 있는 임시 맵을 생성하지 않았습니다.';

  @override
  String get editorEuddraftExitedSuccessfullyButCreatedAnEmptyTemporaryMap =>
      'euddraft가 정상 종료했지만 빈 임시 맵을 생성했습니다.';

  @override
  String get editorInspectTheEuddraftOutputAndEpScriptSource =>
      'euddraft 출력과 epScript 소스를 검사하세요.';

  @override
  String get editorTheTemporaryEUDOutputIsNotAReadableMap =>
      '임시 EUD 출력은 읽을 수 있는 맵 아카이브가 아닙니다.';

  @override
  String get editorInspectTheEuddraftLogAndKeepTheBaseMap =>
      'euddraft 로그를 검사하고 기본 맵을 유지하세요.';

  @override
  String get editorTheTemporaryEUDOutputContainsAnInvalidCHK =>
      '임시 EUD 출력에 유효하지 않은 CHK가 있습니다.';

  @override
  String get editorTheTemporaryEUDOutputFailedCHKMetadataValidation =>
      '임시 EUD 출력이 CHK 메타데이터 검증에 실패했습니다.';

  @override
  String get editorInspectTheMapValidationDiagnosticsAndEuddraftLog =>
      '맵 검증 진단과 euddraft 로그를 검사하세요.';

  @override
  String get editorTheTemporaryEUDOutputIsMissingRequiredVERDIM =>
      '임시 EUD 출력에 필수 VER, DIM 또는 ERA 맵 메타데이터가 없습니다.';

  @override
  String get editorUseAnIntactStarCraftMapAsTheEUDBase =>
      '정상적인 StarCraft 맵을 EUD 기본 맵으로 사용하세요.';

  @override
  String get editorTheEUDBaseMapFingerprintCouldNotBeRechecked =>
      'EUD 기본 맵 지문을 재검사하지 못했습니다.';

  @override
  String get editorTheBaseMapChangedDuringTheEUDBuildSo =>
      'EUD 빌드 중 기본 맵이 변경되어 출력을 최종 대상으로 옮기지 않았습니다.';

  @override
  String get editorReviewTheBaseMapChangesAndRebuild =>
      '기본 맵 변경사항을 검토하고 다시 빌드하세요.';

  @override
  String get editorTheEpScriptEntryFingerprintCouldNotBeRechecked =>
      'epScript 진입 파일 지문을 재검사하지 못했습니다.';

  @override
  String get editorTheEpScriptEntryChangedDuringTheEUDBuildSo =>
      'EUD 빌드 중 epScript 진입 파일이 변경되어 출력을 최종 대상으로 옮기지 않았습니다.';

  @override
  String get editorSaveTheSourceChangesAndRebuild => '소스 변경사항을 저장하고 다시 빌드하세요.';

  @override
  String get editorThePreviousEUDOutputIsSafeInABackup =>
      '이전 EUD 출력은 백업에 안전하게 보관되었지만 자동 복원에 실패했습니다.';

  @override
  String editorRestoreTheBackupToBeforeBuildingAgain(String value0) {
    return '다시 빌드하기 전에 백업을 $value0에 복원하세요.';
  }

  @override
  String get editorTheVerifiedEUDMapCouldNotBePromotedTo =>
      '검증된 EUD 맵을 출력 대상으로 옮기지 못했습니다.';

  @override
  String get editorCheckOutputFolderPermissionsAndChooseANewName =>
      '출력 폴더 권한을 확인하고 새 이름을 선택하세요.';

  @override
  String get editorThePreviousEUDOutputWasPreservedAsARecovery =>
      '이전 EUD 출력은 복구 백업으로 보관되었습니다.';

  @override
  String get editorKeepTheBackupUntilTheGeneratedMapHasBeen =>
      '생성된 맵을 테스트할 때까지 백업을 유지하세요.';

  @override
  String get editorTheSafeEUDBuildPipelineFailedUnexpectedly =>
      '안전한 EUD 빌드 파이프라인에 예기치 않은 오류가 발생했습니다.';

  @override
  String get editorTheTemporaryEUDBuildWorkspaceWasNotRemoved =>
      '임시 EUD 빌드 작업 폴더를 삭제하지 못했습니다.';

  @override
  String get editorCloseProcessesUsingTheFolderThenRemoveItManually =>
      '이 폴더를 사용하는 프로세스를 닫고 직접 삭제하세요.';

  @override
  String get editorMapSourceOrEUDProjectChangedPrepareTheBuild =>
      '맵, 소스 또는 EUD 프로젝트가 변경되었습니다. 빌드를 다시 준비하세요.';

  @override
  String get editorSaveAndVerifyTheCurrentInputsThenPrepareAgain =>
      '현재 입력을 저장하고 검증한 후 다시 준비하세요.';

  @override
  String get editorTheSelectedEuddraftInstallationCouldNotBeRechecked =>
      '선택한 euddraft 설치를 재검사하지 못했습니다.';

  @override
  String get editorInspectTheToolAndPrepareANewBuild => '도구를 검사하고 새 빌드를 준비하세요.';

  @override
  String get editorTheSelectedEuddraftInstallationChangedOrIsNotReady =>
      '선택한 euddraft 설치가 변경되었거나 준비되지 않았습니다.';

  @override
  String get editorCheckThatTheFileIsReadableAndIsNot =>
      '파일을 읽을 수 있고 변경 중이 아닌지 확인하세요.';

  @override
  String get editorTheExistingEUDOutputCouldNotBeRechecked =>
      '기존 EUD 출력을 재검사하지 못했습니다.';

  @override
  String get editorTheEUDOutputChangedWhileTheMapWasBeing =>
      '맵 빌드 중 EUD 출력이 변경되어 임시 출력을 최종 대상으로 옮기지 않았습니다.';

  @override
  String get editorReviewTheOtherProgramUsingTheOutputAndRebuild =>
      '출력을 사용하는 다른 프로그램을 확인하고 다시 빌드하세요.';

  @override
  String get editorTheObjectCatalogRequestFailedUnexpectedly =>
      '객체 카탈로그 요청에 예기치 않은 오류가 발생했습니다.';

  @override
  String get editorRetryOrRepairTheApplicationInstallation =>
      '다시 시도하거나 앱 설치를 복구하세요.';

  @override
  String get editorTheObjectThumbnailRequestFailedUnexpectedly =>
      '객체 미리보기 이미지 요청에 예기치 않은 오류가 발생했습니다.';

  @override
  String get editorTheObjectCatalogRequestIsNoLongerCurrent =>
      '객체 카탈로그 요청이 더 이상 최신 상태가 아닙니다.';

  @override
  String get editorLoadTheCurrentlySelectedCatalog => '현재 선택한 카탈로그를 불러오세요.';

  @override
  String get editorTheObjectCatalogAndThumbnailResultsDidNotMatch =>
      '객체 카탈로그와 미리보기 이미지 결과가 일치하지 않습니다.';

  @override
  String get editorRepairTheApplicationOrReportTheHelperError =>
      '앱을 복구하거나 도우미 오류를 보고하세요.';

  @override
  String get editorTheStarCraftObjectAtlasRequestFailedUnexpectedly =>
      'StarCraft 객체 아틀라스 요청에 예기치 않은 오류가 발생했습니다.';

  @override
  String get editorTheStarCraftObjectAtlasResultDidNotMatchIts =>
      'StarCraft 객체 아틀라스 결과가 요청 묶음과 일치하지 않습니다.';

  @override
  String get editorOpenAMapBeforeBrowsingThePlacementCatalog =>
      '배치 카탈로그를 탐색하기 전에 맵을 여세요.';

  @override
  String get editorSetTheStarCraftRemasteredDataFolderInSettingsFirst =>
      '설정에서 StarCraft: Remastered 데이터 폴더를 먼저 지정하세요.';

  @override
  String get editorTheMapNeedsExactlyOneERASectionWithA =>
      '맵에 알려진 타일셋을 가진 ERA 섹션이 정확히 하나 있어야 합니다.';

  @override
  String get editorTheCatalogChangedOrReturnedOverlappingPagesSelectThe =>
      '카탈로그가 변경되었거나 중복된 페이지가 반환되었습니다. 종류를 다시 선택하여 불러오세요.';

  @override
  String get editorThePlacementCatalogIsUnavailableInThisBuild =>
      '이 빌드에서는 배치 카탈로그를 사용할 수 없습니다.';

  @override
  String get editorStarCraftDataAssetSettingsCouldNotBeLoaded =>
      'StarCraft 데이터 자산 설정을 불러오지 못했습니다.';

  @override
  String get editorCheckAccessToTheApplicationSettingsFolderAndRetry =>
      '앱 설정 폴더 접근 권한을 확인하고 다시 시도하세요.';

  @override
  String get editorTheStarCraftInstallationFolderPickerCouldNotBeOpened =>
      'StarCraft 설치 폴더 선택창을 열지 못했습니다.';

  @override
  String get editorRetryOrCheckWindowsDialogPermissions =>
      '다시 시도하거나 Windows 대화상자 권한을 확인하세요.';

  @override
  String get editorTheStarCraftInstallationPathCouldNotBeSaved =>
      'StarCraft 설치 경로를 저장하지 못했습니다.';

  @override
  String get editorTheStarCraftInstallationPathCouldNotBeCleared =>
      'StarCraft 설치 경로를 지우지 못했습니다.';

  @override
  String get editorTheStarCraftCASCStorageCouldNotBeInspected =>
      'StarCraft CASC 저장소를 검사하지 못했습니다.';

  @override
  String get editorCheckDirectoryAccessAndRetry => '폴더 접근 권한을 확인하고 다시 시도하세요.';

  @override
  String get editorTheStarCraftInstallationIsNotConfigured =>
      'StarCraft 설치가 설정되지 않았습니다.';

  @override
  String get editorOpenSettingsAndChooseTheStarCraftInstallationDirectory =>
      '설정을 열어 StarCraft 설치 폴더를 선택하세요.';

  @override
  String get editorTheStarCraftTileAtlasRequestFailedUnexpectedly =>
      'StarCraft 타일 아틀라스 요청에 예기치 않은 오류가 발생했습니다.';

  @override
  String get editorTheStarCraftTileAtlasResultDidNotMatchIts =>
      'StarCraft 타일 아틀라스 결과가 요청 묶음과 일치하지 않습니다.';

  @override
  String get editorTheTileCatalogRequestFailedUnexpectedly =>
      '타일 카탈로그 요청에 예기치 않은 오류가 발생했습니다.';

  @override
  String get editorTheTileThumbnailRequestFailedUnexpectedly =>
      '타일 미리보기 이미지 요청에 예기치 않은 오류가 발생했습니다.';

  @override
  String get editorTheTileCatalogRequestIsNoLongerCurrent =>
      '타일 카탈로그 요청이 더 이상 최신 상태가 아닙니다.';

  @override
  String get editorTheTileCatalogAndThumbnailResultsDidNotMatch =>
      '타일 카탈로그와 미리보기 이미지 결과가 일치하지 않습니다.';

  @override
  String get editorTheMapPathMustBeAnAbsoluteWindowsPath =>
      '맵 경로는 Windows 절대 경로여야 합니다.';

  @override
  String get editorChooseTheMapAgainUsingTheOpenMapDialog =>
      '맵 열기 대화상자에서 맵을 다시 선택하세요.';

  @override
  String get editorAnArchiveOperationWithTheSameIDIsAlready =>
      '같은 ID의 아카이브 작업이 이미 실행 중입니다.';

  @override
  String get editorWaitForTheActiveOperationOrCancelItFirst =>
      '실행 중인 작업을 기다리거나 먼저 취소하세요.';

  @override
  String get editorTheBundledMapArchiveHelperIsMissing =>
      '포함된 맵 아카이브 도우미가 없습니다.';

  @override
  String get editorRepairOrReinstallTheApplication => '앱을 복구하거나 다시 설치하세요.';

  @override
  String get editorATemporaryArchiveWorkspaceCouldNotBeCreated =>
      '임시 아카이브 작업 폴더를 만들지 못했습니다.';

  @override
  String get editorCheckFreeDiskSpaceAndTemporaryFolderPermissions =>
      '디스크 여유 공간과 임시 폴더 권한을 확인하세요.';

  @override
  String get editorTheMapArchiveHelperTimedOut => '맵 아카이브 도우미의 제한 시간이 초과되었습니다.';

  @override
  String get editorRetryTheOperationOrInspectTheMapForCorruption =>
      '작업을 다시 시도하거나 맵 손상 여부를 검사하세요.';

  @override
  String get editorTheMapArchiveOperationWasCancelled => '맵 아카이브 작업이 취소되었습니다.';

  @override
  String get editorOpenTheMapAgainWhenReady => '준비되면 맵을 다시 여세요.';

  @override
  String get editorTheMapArchiveHelperProducedTooMuchOutput =>
      '맵 아카이브 도우미의 출력량이 한도를 넘었습니다.';

  @override
  String get editorRepairTheApplicationOrReportTheHelperFailure =>
      '앱을 복구하거나 도우미 실패를 보고하세요.';

  @override
  String get editorScenarioChkExceedsTheConfiguredExtractionSizeLimit =>
      'scenario.chk가 설정된 추출 크기 한도를 넘었습니다.';

  @override
  String get editorRaiseTheReviewedSizeLimitOnlyForATrusted =>
      '신뢰할 수 있는 맵에만 검토 후 크기 한도를 높이세요.';

  @override
  String get editorTheExtractedScenarioChkCouldNotBeRead =>
      '추출한 scenario.chk를 읽지 못했습니다.';

  @override
  String get editorRetryTheOperationAndCheckTemporaryDiskAccess =>
      '작업을 다시 시도하고 임시 디스크 접근 권한을 확인하세요.';

  @override
  String get editorTheExtractedScenarioChkDoesNotMatchHelperMetadata =>
      '추출한 scenario.chk가 도우미 메타데이터와 일치하지 않습니다.';

  @override
  String get editorTheMapArchiveHelperCouldNotBeStarted =>
      '맵 아카이브 도우미를 시작하지 못했습니다.';

  @override
  String get editorTheMapArchiveHelperReturnedAnInvalidResponse =>
      '맵 아카이브 도우미가 유효하지 않은 응답을 반환했습니다.';

  @override
  String get editorTheSourceMapPathMustBeAnAbsoluteWindows =>
      '원본 맵 경로는 Windows 절대 경로여야 합니다.';

  @override
  String get editorOpenTheSourceMapAgainUsingTheOpenMap =>
      '맵 열기 대화상자에서 원본 맵을 다시 여세요.';

  @override
  String get editorTheTemporaryOutputPathMustBeAnAbsoluteWindows =>
      '임시 출력 경로는 Windows 절대 경로여야 합니다.';

  @override
  String get editorCreateTheSaveAsWorkspaceAgain => '임시 저장 작업 폴더를 다시 만드세요.';

  @override
  String get editorTheSourceMapCannotBeUsedAsTemporaryOutput =>
      '원본 맵을 임시 출력으로 사용할 수 없습니다.';

  @override
  String get editorChooseADifferentSaveAsDestination => '다른 저장 대상을 선택하세요.';

  @override
  String get editorTheTemporaryArchiveOutputAlreadyExists =>
      '임시 아카이브 출력이 이미 존재합니다.';

  @override
  String get editorCreateAFreshSaveAsWorkspaceAndRetry =>
      '새 임시 저장 작업 폴더를 만들고 다시 시도하세요.';

  @override
  String get editorTheTemporarySaveAsWorkspaceDoesNotExist =>
      '임시 저장 작업 폴더가 없습니다.';

  @override
  String get editorTheTemporarySaveAsWorkspaceCouldNotBeInspected =>
      '임시 저장 작업 폴더를 검사하지 못했습니다.';

  @override
  String get editorCheckDestinationFolderPermissionsAndRetry =>
      '대상 폴더 권한을 확인하고 다시 시도하세요.';

  @override
  String get editorTheTemporaryScenarioInputPathAlreadyExists =>
      '임시 시나리오 입력 경로가 이미 존재합니다.';

  @override
  String get editorTheTemporaryArchiveWriterTimedOut =>
      '임시 아카이브 기록의 제한 시간이 초과되었습니다.';

  @override
  String get editorTheMapArchiveWriteWasCancelled => '맵 아카이브 기록이 취소되었습니다.';

  @override
  String get editorRunSaveAsAgainWhenReady => '준비되면 다른 이름으로 저장을 다시 실행하세요.';

  @override
  String get editorTheHelperReportedAnUnexpectedScenarioChkSize =>
      '도우미가 예상과 다른 scenario.chk 크기를 보고했습니다.';

  @override
  String get editorTheHelperDidNotCreateTheTemporaryMapArchive =>
      '도우미가 임시 맵 아카이브를 생성하지 않았습니다.';

  @override
  String get editorRetrySaveAsOrRepairTheApplication =>
      '저장을 다시 시도하거나 앱을 복구하세요.';

  @override
  String get editorTheTemporaryMapArchiveCouldNotBeInspected =>
      '임시 맵 아카이브를 검사하지 못했습니다.';

  @override
  String get editorTheTemporaryMapSizeDoesNotMatchHelperMetadata =>
      '임시 맵 크기가 도우미 메타데이터와 일치하지 않습니다.';

  @override
  String get editorTheTemporaryScenarioInputCouldNotBeWritten =>
      '임시 시나리오 입력을 기록하지 못했습니다.';

  @override
  String get editorTheArchiveEntryListingIsIncomplete => '아카이브 항목 목록이 불완전합니다.';

  @override
  String get editorEditingCanContinueButVerifyProtectedOrUnnamedEntries =>
      '편집은 계속할 수 있지만 저장 전에 보호되거나 이름이 없는 항목을 검증하세요.';

  @override
  String get editorSomeArchiveEntryNamesWereRecoveredSynthetically =>
      '일부 아카이브 항목에는 합성된 이름을 사용했습니다.';

  @override
  String get editorTreatSyntheticNamesAsDiagnosticLabelsNotOriginalPaths =>
      '합성 이름은 원본 경로가 아니라 진단용 표시로 취급하세요.';

  @override
  String get editorTheArchiveContainsDuplicateEntryPaths =>
      '아카이브에 중복 항목 경로가 있습니다.';

  @override
  String get editorReviewLocaleVariantsAndDuplicateEntriesBeforeSaving =>
      '저장 전에 로캘 변형과 중복 항목을 검토하세요.';

  @override
  String get editorTheMapUsesAnUnexpectedMPQFormatVersion =>
      '맵이 예상하지 않은 MPQ 형식 버전을 사용합니다.';

  @override
  String get editorUseSaveAsAndReOpenTheOutputBefore =>
      '다른 이름으로 저장한 뒤 출력을 다시 열어 확인하고 맵을 교체하세요.';

  @override
  String get editorTheArchiveContainsEncryptedEntries => '아카이브에 암호화된 항목이 있습니다.';

  @override
  String get editorEncryptedEntriesAreReportedWithoutAttemptingRecovery =>
      '암호화된 항목은 복구를 시도하지 않고 보고합니다.';

  @override
  String get editorTheStarCraftInstallationPathMustBeAnAbsoluteWindows =>
      'StarCraft 설치 경로는 Windows 드라이브 또는 UNC 폴더의 절대 경로여야 합니다.';

  @override
  String get editorChooseTheStarCraftInstallationUsingTheSettingsDialog =>
      '설정 대화상자에서 StarCraft 설치를 선택하세요.';

  @override
  String get editorTheBundledStarCraftCASCHelperIsMissing =>
      '포함된 StarCraft CASC 도우미가 없습니다.';

  @override
  String get editorTheStarCraftCASCInspectionTimedOut =>
      'StarCraft CASC 검사의 제한 시간이 초과되었습니다.';

  @override
  String get editorRetryAfterRepairingTheStarCraftInstallationInBattleNet =>
      'Battle.net에서 StarCraft 설치를 복구한 후 다시 시도하세요.';

  @override
  String get editorTheStarCraftCASCHelperProducedTooMuchOutput =>
      'StarCraft CASC 도우미의 출력량이 한도를 넘었습니다.';

  @override
  String get editorTheStarCraftCASCHelperCouldNotBeStarted =>
      'StarCraft CASC 도우미를 시작하지 못했습니다.';

  @override
  String get editorTheStarCraftInstallationCouldNotBeInspected =>
      'StarCraft 설치를 검사하지 못했습니다.';

  @override
  String get editorCheckDirectoryPermissionsAndRetry => '폴더 권한을 확인하고 다시 시도하세요.';

  @override
  String editorRequiredStarCraftCASCTilesetMissing(
    String value0,
    String value1,
  ) {
    return '필수 StarCraft CASC 타일셋 자산 $value0개가 누락되었습니다.';
  }

  @override
  String get editorAssetIs => '자산이';

  @override
  String get editorAssetsAre => '자산이';

  @override
  String get editorRepairTheStarCraftInstallationInBattleNetAndRetry =>
      'Battle.net에서 StarCraft 설치를 복구하고 다시 시도하세요.';

  @override
  String editorRequiredStarCraftCASCTilesetUnreadable(
    String value0,
    String value1,
  ) {
    return '필수 StarCraft CASC 타일셋 자산 $value0개를 읽을 수 없습니다.';
  }

  @override
  String get editorTheStarCraftCASCHelperReturnedAnInvalidResponse =>
      'StarCraft CASC 도우미가 유효하지 않은 응답을 반환했습니다.';

  @override
  String get editorTheStarCraftInstallationPathIsInvalid =>
      'StarCraft 설치 경로가 유효하지 않습니다.';

  @override
  String get editorChooseTheStarCraftInstallationFolderAgain =>
      'StarCraft 설치 폴더를 다시 선택하세요.';

  @override
  String get editorAnObjectRenderingOperationWithThisIDIsActive =>
      '이 ID의 객체 렌더링 작업이 실행 중입니다.';

  @override
  String get editorWaitForTheCurrentMapRenderingOperationToFinish =>
      '현재 맵 렌더링 작업이 끝날 때까지 기다리세요.';

  @override
  String get editorTheStarCraftObjectRenderingHelperTimedOut =>
      'StarCraft 객체 렌더링 도우미의 제한 시간이 초과되었습니다.';

  @override
  String get editorRepairTheStarCraftInstallationAndRetry =>
      'StarCraft 설치를 복구하고 다시 시도하세요.';

  @override
  String get editorTheStarCraftObjectHelperProducedTooMuchOutput =>
      'StarCraft 객체 도우미의 출력량이 한도를 넘었습니다.';

  @override
  String get editorTheStarCraftObjectHelperCouldNotBeStarted =>
      'StarCraft 객체 도우미를 시작하지 못했습니다.';

  @override
  String get editorTheStarCraftObjectAtlasCouldNotBeReadSafely =>
      'StarCraft 객체 아틀라스를 안전하게 읽지 못했습니다.';

  @override
  String get editorTheStarCraftObjectHelperReturnedAnInvalidResponse =>
      'StarCraft 객체 도우미가 유효하지 않은 응답을 반환했습니다.';

  @override
  String get editorTheStarCraftObjectRenderingOperationWasCancelled =>
      'StarCraft 객체 렌더링 작업이 취소되었습니다.';

  @override
  String get editorRetryAfterTheVisibleMapStateBecomesStable =>
      '표시되는 맵 상태가 안정되면 다시 시도하세요.';

  @override
  String get editorThisHelperVersionDoesNotSupportThatCatalogKind =>
      '이 도우미 버전은 해당 카탈로그 종류를 지원하지 않습니다.';

  @override
  String get editorChooseTheTileDoodadUnitOrPureSpriteCatalog =>
      '타일, 두대드, 유닛 또는 순수 스프라이트 카탈로그를 선택하세요.';

  @override
  String get editorACatalogOperationWithThisIDIsAlreadyActive =>
      '이 ID의 카탈로그 작업이 이미 실행 중입니다.';

  @override
  String get editorWaitForTheActiveCatalogOperationToFinish =>
      '실행 중인 카탈로그 작업이 끝날 때까지 기다리세요.';

  @override
  String get editorTheStarCraftCatalogHelperTimedOut =>
      'StarCraft 카탈로그 도우미의 제한 시간이 초과되었습니다.';

  @override
  String get editorTheStarCraftCatalogHelperProducedTooMuchOutput =>
      'StarCraft 카탈로그 도우미의 출력량이 한도를 넘었습니다.';

  @override
  String get editorTheStarCraftCatalogHelperCouldNotBeStarted =>
      'StarCraft 카탈로그 도우미를 시작하지 못했습니다.';

  @override
  String get editorTheStarCraftCatalogCouldNotBeListedSafely =>
      'StarCraft 카탈로그 목록을 안전하게 읽지 못했습니다.';

  @override
  String get editorTheLocalDoodadRecipeIsInvalid => '로컬 두대드 레시피가 유효하지 않습니다.';

  @override
  String get editorTheLocalObjectPreviewIsUnavailable =>
      '로컬 객체 미리보기를 사용할 수 없습니다.';

  @override
  String get editorVerifiedUnitCapabilityDataIsUnavailable =>
      '검증된 유닛 기능 데이터를 사용할 수 없습니다.';

  @override
  String get editorThisUnitNeedsAnAddonOrNydusRelation =>
      '이 유닛에는 애드온 또는 나이더스 연결이 필요합니다.';

  @override
  String get editorTheStarCraftCatalogHelperReturnedAnInvalidResponse =>
      'StarCraft 카탈로그 도우미가 유효하지 않은 응답을 반환했습니다.';

  @override
  String get editorRepairTheApplicationOrReportTheCatalogHelperError =>
      '앱을 복구하거나 카탈로그 도우미 오류를 보고하세요.';

  @override
  String get editorTheStarCraftCatalogOperationWasCancelled =>
      'StarCraft 카탈로그 작업이 취소되었습니다.';

  @override
  String get editorRetryTheCatalogOperationWhenReady =>
      '준비되면 카탈로그 작업을 다시 시도하세요.';

  @override
  String get editorTheStarCraftTileRenderingHelperTimedOut =>
      'StarCraft 타일 렌더링 도우미의 제한 시간이 초과되었습니다.';

  @override
  String get editorTheStarCraftTileHelperProducedTooMuchOutput =>
      'StarCraft 타일 도우미의 출력량이 한도를 넘었습니다.';

  @override
  String get editorTheStarCraftTileHelperCouldNotBeStarted =>
      'StarCraft 타일 도우미를 시작하지 못했습니다.';

  @override
  String get editorTheStarCraftTileAtlasCouldNotBeReadSafely =>
      'StarCraft 타일 아틀라스를 안전하게 읽지 못했습니다.';

  @override
  String get editorTheStarCraftTileHelperReturnedAnInvalidResponse =>
      'StarCraft 타일 도우미가 유효하지 않은 응답을 반환했습니다.';

  @override
  String get editorOpenTheReportedEpScriptModuleAndFixThisLine =>
      '보고된 epScript 모듈을 열어 이 줄을 수정하세요.';

  @override
  String get editorEuddraftInspectionIsSupportedOnlyOnWindows =>
      'euddraft 검사는 Windows에서만 지원됩니다.';

  @override
  String get editorRunTheEditorOnWindows10OrWindows11 =>
      'Windows 10 또는 Windows 11에서 편집기를 실행하세요.';

  @override
  String get editorAnEuddraftInstallationPathHasNotBeenConfigured =>
      'euddraft 설치 경로가 설정되지 않았습니다.';

  @override
  String get editorSelectTheExtractedEuddraftDirectoryOrEuddraftExe =>
      '압축을 푼 euddraft 폴더 또는 euddraft.exe를 선택하세요.';

  @override
  String get editorTheEuddraftInstallationCouldNotBeInspected =>
      'euddraft 설치를 검사하지 못했습니다.';

  @override
  String get editorCheckPathPermissionsAndRetry => '경로 권한을 확인하고 다시 시도하세요.';

  @override
  String get editorTheEuddraftPathMustBeAnAbsoluteWindowsPath =>
      'euddraft 경로는 Windows 절대 경로여야 합니다.';

  @override
  String get editorSelectThePathUsingTheEditorSettings => '편집기 설정에서 경로를 선택하세요.';

  @override
  String get editorTheConfiguredFileIsNotEuddraftExe =>
      '설정된 파일은 euddraft.exe가 아닙니다.';

  @override
  String get editorSelectTheOfficialEuddraftExeOrItsInstallationFolder =>
      '공식 euddraft.exe 또는 설치 폴더를 선택하세요.';

  @override
  String get editorTheConfiguredEuddraftPathDoesNotExist =>
      '설정된 euddraft 경로가 없습니다.';

  @override
  String get editorExtractTheOfficialEuddraftReleaseAndRetry =>
      '공식 euddraft 릴리스의 압축을 풀고 다시 시도하세요.';

  @override
  String get editorTheConfiguredEuddraftPathIsNotARegularFile =>
      '설정된 euddraft 경로는 일반 파일 또는 폴더가 아닙니다.';

  @override
  String get editorSelectALocalExtractedEuddraftInstallation =>
      '로컬에 압축을 푼 euddraft 설치를 선택하세요.';

  @override
  String get editorTheInstallationDoesNotContainAUsableEuddraftExe =>
      '설치에 사용할 수 있는 euddraft.exe가 없습니다.';

  @override
  String get editorReExtractTheOfficialEuddraftRelease =>
      '공식 euddraft 릴리스의 압축을 다시 푸세요.';

  @override
  String get editorTheEuddraftVERSIONFileIsMissing =>
      'euddraft VERSION 파일이 없습니다.';

  @override
  String get editorUseACompleteOfficialEuddraftReleaseArchive =>
      '완전한 공식 euddraft 릴리스 아카이브를 사용하세요.';

  @override
  String get editorTheEuddraftVERSIONFileHasAnInvalidSize =>
      'euddraft VERSION 파일 크기가 유효하지 않습니다.';

  @override
  String get editorTheEuddraftVERSIONValueIsNotRecognized =>
      'euddraft VERSION 값을 인식할 수 없습니다.';

  @override
  String get editorUseAnOfficialFourComponentEuddraftRelease =>
      '네 부분 버전 번호를 사용하는 공식 euddraft 릴리스를 사용하세요.';

  @override
  String editorEuddraftIsNotSupportedByThisEditor(String value0) {
    return '이 편집기는 euddraft $value0을 지원하지 않습니다.';
  }

  @override
  String editorInstallASupportedRelease(String value0) {
    return '지원되는 릴리스를 설치하세요: $value0.';
  }

  @override
  String get editorTheEuddraftInstallationIsIncomplete =>
      'euddraft 설치가 불완전합니다.';

  @override
  String get editorReExtractTheCompleteOfficialEuddraftRelease =>
      '완전한 공식 euddraft 릴리스의 압축을 다시 푸세요.';

  @override
  String get editorTheAppHasNoTrustedInventoryForThisBundled =>
      '앱에 이 포함 도구의 신뢰할 수 있는 파일 목록이 없습니다.';

  @override
  String get editorUseAVerifiedAppPackageOrExplicitlySelectAn =>
      '검증된 앱 패키지를 사용하거나 외부 설치를 명시적으로 선택하세요.';

  @override
  String get editorBundledToolIntegrityVerificationFailed =>
      '포함 도구의 무결성 검증에 실패했습니다.';

  @override
  String get editorRepairTheBundledInstallationOrExplicitlySelectAnExternal =>
      '포함 설치를 복구하거나 외부 도구를 명시적으로 선택하세요.';

  @override
  String get editorAnEUDBuildWithTheSameIDIsAlready =>
      '같은 ID의 EUD 빌드가 이미 실행 중입니다.';

  @override
  String get editorWaitForTheActiveBuildOrCancelItFirst =>
      '실행 중인 빌드를 기다리거나 먼저 취소하세요.';

  @override
  String get editorEuddraftCouldNotBeStarted => 'euddraft를 시작하지 못했습니다.';

  @override
  String get editorReinspectTheEuddraftInstallationAndRetry =>
      'euddraft 설치를 다시 검사하고 재시도하세요.';

  @override
  String get editorTheEuddraftBuildTimedOut => 'euddraft 빌드의 제한 시간이 초과되었습니다.';

  @override
  String get editorInspectTheBuildLogThenRetryOrCancel =>
      '빌드 로그를 검사한 후 재시도하거나 취소하세요.';

  @override
  String get editorEuddraftProducedMoreOutputThanTheSafetyLimit =>
      'euddraft 출력량이 안전 한도를 넘었습니다.';

  @override
  String get editorInspectTheSourceForRunawayLoggingBeforeRetrying =>
      '재시도하기 전에 소스에서 과도한 로그 출력을 확인하세요.';

  @override
  String get editorEuddraftExitedWithAFailureCode =>
      'euddraft가 실패 코드로 종료되었습니다.';

  @override
  String get editorReviewStdoutAndStderrForTheCompilerError =>
      'stdout과 stderr에서 컴파일러 오류를 검토하세요.';

  @override
  String get editorTheEUDBuildCouldNotAccessARequiredFile =>
      'EUD 빌드가 필수 파일에 접근하지 못했습니다.';

  @override
  String get editorCheckFilePermissionsAndRetry => '파일 권한을 확인하고 다시 시도하세요.';

  @override
  String get editorTheEUDBuildFailedUnexpectedly =>
      'EUD 빌드에 예기치 않은 오류가 발생했습니다.';

  @override
  String get editorRetryTheBuildOrReportTheFailure => '빌드를 다시 시도하거나 실패를 보고하세요.';

  @override
  String get editorEuddraftBuildsAreSupportedOnlyOnWindows =>
      'euddraft 빌드는 Windows에서만 지원됩니다.';

  @override
  String get editorTheEuddraftExecutablePathMustBeAbsolute =>
      'euddraft 실행 파일 경로는 절대 경로여야 합니다.';

  @override
  String get editorInspectAndSelectTheEuddraftInstallationAgain =>
      'euddraft 설치를 검사하고 다시 선택하세요.';

  @override
  String get editorTheInspectedEuddraftExecutableIsNoLongerAvailable =>
      '검사한 euddraft 실행 파일을 더 이상 사용할 수 없습니다.';

  @override
  String get editorInspectTheEuddraftInstallationAgain =>
      'euddraft 설치를 다시 검사하세요.';

  @override
  String get editorTheEuddraftSettingsPathMustBeAnAbsoluteEds =>
      'euddraft 설정 경로는 .eds 파일의 절대 경로여야 합니다.';

  @override
  String get editorChooseAGeneratedOneShotEdsSettingsFile =>
      '생성된 일회성 .eds 설정 파일을 선택하세요.';

  @override
  String get editorTheEuddraftSettingsFileIsMissingOrEmpty =>
      'euddraft 설정 파일이 없거나 비어 있습니다.';

  @override
  String get editorGenerateTheBuildSettingsAgainAndRetry =>
      '빌드 설정을 다시 생성하고 재시도하세요.';

  @override
  String get editorTheEUDBuildWasCancelled => 'EUD 빌드가 취소되었습니다.';

  @override
  String get editorStartTheBuildAgainWhenReady => '준비되면 빌드를 다시 시작하세요.';

  @override
  String get editorInactive => '비활성';

  @override
  String get editorRescuePassive => '구조 대상 (수동)';

  @override
  String get editorComputer => '컴퓨터';

  @override
  String get editorHuman => '사용자';

  @override
  String get editorNeutral => '중립';

  @override
  String get editorZerg => '저그';

  @override
  String get editorTerran => '테란';

  @override
  String get editorProtoss => '프로토스';

  @override
  String get editorIndependent => '독립';

  @override
  String get editorUserSelectable => '사용자 선택';

  @override
  String get editorRandom => '무작위';

  @override
  String get editorRed => '빨강';

  @override
  String get editorBlue => '파랑';

  @override
  String get editorTeal => '청록';

  @override
  String get editorPurple => '보라';

  @override
  String get editorOrange => '주황';

  @override
  String get editorBrown => '갈색';

  @override
  String get editorWhite => '흰색';

  @override
  String get editorYellow => '노랑';

  @override
  String get editorGreen => '초록';

  @override
  String get editorPaleYellow => '연노랑';

  @override
  String get editorTan => '황갈색';

  @override
  String get editorAzure => '하늘색';

  @override
  String editorExpectedOneSectionFound(String value0, String value1) {
    return '$value0: 섹션이 하나여야 하지만 $value1개 있습니다.';
  }

  @override
  String editorExpectedBytesFound(String value0, String value1, String value2) {
    return '$value0: $value1바이트여야 하지만 $value2바이트입니다.';
  }

  @override
  String get editorASingleKnownVERSectionIsRequired =>
      '알려진 VER 섹션이 정확히 하나 필요합니다.';

  @override
  String get editorCRGBColorSettingsArePresentCOLREditingIsUnavailable =>
      'CRGB 색상 설정이 있습니다. 두 설정의 상호작용을 지원할 때까지 COLR를 편집할 수 없습니다.';

  @override
  String get editorAPlayerFieldMayBeUpdatedOnlyOnce =>
      '플레이어 필드는 한 번만 변경할 수 있습니다.';

  @override
  String editorUnsupportedID(String value0, String value1) {
    return '지원하지 않는 $value0 ID: $value1.';
  }

  @override
  String get editorStartLocationsCannotBeCheckedAUNITSectionIs =>
      '시작 위치를 검사할 수 없습니다: UNIT 섹션의 형식이 잘못되었습니다.';

  @override
  String editorStartLocationHasNonPlayableOwnerID(String value0) {
    return '시작 위치의 소유자 ID $value0은 플레이 가능하지 않습니다.';
  }

  @override
  String editorPlayerHasStartLocations(String value0, String value1) {
    return '플레이어 $value0의 시작 위치가 $value1개 있습니다.';
  }

  @override
  String editorPlayerHasNoStartLocationCheckTheIntendedUMS(String value0) {
    return '플레이어 $value0의 시작 위치가 없습니다. 의도한 UMS 설정인지 확인하세요.';
  }

  @override
  String editorInactivePlayerOwnsAStartLocation(String value0) {
    return '비활성 플레이어 $value0에 시작 위치가 있습니다.';
  }

  @override
  String get editorForceNamesRequireOneSafeSTROrSTRxTable =>
      '세력 이름에는 안전한 STR 또는 STRx 테이블이 하나 필요합니다.';

  @override
  String get editorForceSettingsRequireOneKnownVERAndOne20 =>
      '세력 설정에는 알려진 VER 섹션 하나와 20바이트 FORC 섹션 하나가 필요합니다.';

  @override
  String editorInvalidForceNameStringID(String value0) {
    return '세력 이름 문자열 ID $value0이 유효하지 않습니다.';
  }

  @override
  String get editorForceNamesCannotContainNUL => '세력 이름에는 NUL을 포함할 수 없습니다.';

  @override
  String get editorFORCStringIDsCannotExceed65535 =>
      'FORC 문자열 ID는 65535를 넘을 수 없습니다.';

  @override
  String get editorUseDefaults => '기본값 사용';

  @override
  String get editorHitPoints => '체력';

  @override
  String get editorShields => '보호막';

  @override
  String get editorArmor => '방어력';

  @override
  String get editorBuildTime160S => '생산 시간 (1/60초)';

  @override
  String get editorMineralCost => '미네랄 비용';

  @override
  String get editorGasCost => '가스 비용';

  @override
  String get editorHitPointsRequireANonnegativeDecimalInStepsOf =>
      '체력은 1/256 단위의 음수가 아닌 소수여야 합니다.';

  @override
  String get editorHitPointsMustBeAMultipleOf1256 => '체력은 1/256의 배수여야 합니다.';

  @override
  String editorRequiresANonnegativeInteger(String value0) {
    return '$value0에는 음수가 아닌 정수가 필요합니다.';
  }

  @override
  String editorInvalidUnitNameStringID(String value0) {
    return '유닛 이름 문자열 ID $value0이 유효하지 않습니다.';
  }

  @override
  String get editorUnitSettingsRequireOneKnownVERSection =>
      '유닛 설정에는 알려진 VER 섹션이 하나 필요합니다.';

  @override
  String get editorUnitNamesRequireOneSafeSTROrSTRxTable =>
      '유닛 이름에는 안전한 STR 또는 STRx 테이블이 하나 필요합니다.';

  @override
  String get editorUnitNamesCannotContainNUL => '유닛 이름에는 NUL을 포함할 수 없습니다.';

  @override
  String get editorUnitNameIDsCannotExceed65535 =>
      '유닛 이름 ID는 65535를 넘을 수 없습니다.';

  @override
  String get editorGlobalAvailabilityHasNoPlayer => '전체 사용 가능 여부에는 플레이어가 없습니다.';

  @override
  String get editorAPlayerIsRequired => '플레이어가 필요합니다.';

  @override
  String get editorUnitAvailabilityRequiresOneKnownVERSection =>
      '유닛 사용 가능 여부에는 알려진 VER 섹션이 하나 필요합니다.';

  @override
  String editorPUNIExpectedOneSectionFound(String value0) {
    return 'PUNI: 섹션이 하나여야 하지만 $value0개 있습니다.';
  }

  @override
  String editorPUNIExpected5700BytesFound(String value0) {
    return 'PUNI: 5700바이트여야 하지만 $value0바이트입니다.';
  }

  @override
  String get editorResearchTime160S => '연구 시간 (1/60초)';

  @override
  String get editorEnergyCost => '에너지 비용';

  @override
  String get editorCostsHaveNoPlayer => '비용에는 플레이어가 없습니다.';

  @override
  String get editorInheritanceRequiresAPlayer => '상속에는 플레이어가 필요합니다.';

  @override
  String get editorTechSettingsRequireOneKnownVERSection =>
      '기술 설정에는 알려진 VER 섹션이 하나 필요합니다.';

  @override
  String get editorBaseMineralCost => '기본 미네랄 비용';

  @override
  String get editorMineralCostPerLevel => '레벨당 미네랄 비용';

  @override
  String get editorBaseGasCost => '기본 가스 비용';

  @override
  String get editorGasCostPerLevel => '레벨당 가스 비용';

  @override
  String get editorBaseResearchTime160S => '기본 연구 시간 (1/60초)';

  @override
  String get editorResearchTimePerLevel160S => '레벨당 연구 시간 (1/60초)';

  @override
  String get editorMaximumLevel => '최대 레벨';

  @override
  String get editorStartingLevel => '시작 레벨';

  @override
  String get editorUpgradeSettingsRequireOneKnownVERSection =>
      '업그레이드 설정에는 알려진 VER 섹션이 하나 필요합니다.';

  @override
  String editorUpgradeStartingLevelMustNotExceedMaximumLevel(
    String value0,
    String value1,
  ) {
    return '업그레이드 #$value0 $value1: 시작 레벨은 최대 레벨을 넘을 수 없습니다.';
  }

  @override
  String get editorEnterIDsSuchAs025 => '0, 2-5 형식으로 ID를 입력하세요.';

  @override
  String get editorUseCommaSeparatedIDsOrAscendingRanges =>
      '쉼표로 구분한 ID 또는 오름차순 범위를 사용하세요.';

  @override
  String editorIDsMustBeBetweenAndInAscendingRanges(
    String value0,
    String value1,
  ) {
    return 'ID는 $value0~$value1 범위에 있어야 하며 범위는 오름차순이어야 합니다.';
  }

  @override
  String get editorOneStructurallySafeSTRSTRxTableIsRequiredFor =>
      '편집하려면 구조적으로 안전한 STR/STRx 테이블이 하나 필요합니다.';

  @override
  String editorTruncated(String value0) {
    return '잘린 $value0';
  }

  @override
  String get editorMalformedSPRP => 'SPRP 형식 오류';

  @override
  String get editorMalformedFORC => 'FORC 형식 오류';

  @override
  String editorForcef1368d9(String value0) {
    return '세력 $value0';
  }

  @override
  String get editorMalformedMRGN => 'MRGN 형식 오류';

  @override
  String editorLocation(String value0) {
    return '위치 $value0';
  }

  @override
  String get editorMalformedSWNM => 'SWNM 형식 오류';

  @override
  String editorSwitchffe3c882(String value0) {
    return '스위치 $value0';
  }

  @override
  String get editorMalformedWAV => 'WAV 형식 오류';

  @override
  String editorSoundSlot(String value0) {
    return '사운드 슬롯 $value0';
  }

  @override
  String editorMalformed(String value0) {
    return '$value0 형식 오류';
  }

  @override
  String editorUnitc6ee345c(String value0) {
    return '유닛 $value0';
  }

  @override
  String editorRawConditionInTrigger(String value0) {
    return '트리거 $value0의 원시 조건';
  }

  @override
  String editorRawActionInTrigger(String value0) {
    return '트리거 $value0의 원시 액션';
  }

  @override
  String editorTriggerAction(String value0, String value1, String value2) {
    return '트리거 $value0 액션 $value1 $value2';
  }

  @override
  String get editorRawBriefingAction => '원시 브리핑 액션';

  @override
  String editorBriefingActionText(String value0, String value1) {
    return '브리핑 $value0 액션 $value1 텍스트';
  }

  @override
  String editorBriefingActionSound(String value0, String value1) {
    return '브리핑 $value0 액션 $value1 사운드';
  }

  @override
  String editorUninterpretedSection(String value0) {
    return '해석하지 않은 $value0 섹션';
  }

  @override
  String get editorDuplicateCHKSections => '중복 CHK 섹션';

  @override
  String get editorInvalidStringID => '유효하지 않은 문자열 ID입니다.';

  @override
  String get editorSoundPathReferencesAreManagedThroughSoundImportDelete =>
      '사운드 경로 참조는 사운드 가져오기·삭제로 관리합니다. 텍스트를 편집하려면 텍스트 참조를 분리하세요.';

  @override
  String get editorReferencedOrIncompletelyTracedStringsCannotBeCleared =>
      '참조되거나 참조 검사가 불완전한 문자열은 비울 수 없습니다.';

  @override
  String get editorNULIsNotAllowed => 'NUL은 허용되지 않습니다.';

  @override
  String get editorTheSelectedReferenceChanged => '선택한 참조가 변경되었습니다.';

  @override
  String get editorThisReferenceRequiresA16BitStringID =>
      '이 참조에는 16비트 문자열 ID가 필요합니다.';

  @override
  String get editorOneValidWAVTableIsRequired => '유효한 WAV 테이블이 하나 필요합니다.';

  @override
  String get editorAll512SoundSlotsAreOccupied => '사운드 슬롯 512개가 모두 사용 중입니다.';

  @override
  String get editorSoundIsReferencedOrReferenceCoverageIsIncomplete =>
      '사운드가 참조되거나 참조 검사 범위가 불완전합니다.';

  @override
  String editorAmbiguousOrMalformedSection(String value0) {
    return '$value0 섹션이 모호하거나 형식이 잘못되었습니다.';
  }

  @override
  String get editorTextCannotContainNUL => '텍스트에는 NUL을 포함할 수 없습니다.';

  @override
  String get editorOneSafeStringTableIsRequired => '안전한 문자열 테이블이 하나 필요합니다.';

  @override
  String editorSwitch8e2b60a2(String value0) {
    return '스위치 $value0';
  }

  @override
  String get editorHitpoints => '체력 %';

  @override
  String get editorShields83e6a3a => '보호막 %';

  @override
  String get editorEnergy => '에너지 %';

  @override
  String get editorResourceAmount => '자원량';

  @override
  String get editorHangarCount => '격납고 수';

  @override
  String get editorCloaked => '은폐';

  @override
  String get editorBurrowed => '잠복';

  @override
  String get editorLifted => '이륙';

  @override
  String get editorHallucinated => '환상';

  @override
  String get editorInvincible => '무적';

  @override
  String editorInvalid8650455(String value0) {
    return '유효하지 않은 $value0';
  }

  @override
  String get editorFiveSpecialPropertyStatesRequired => '특수 속성 상태가 5개 필요합니다.';

  @override
  String get editorOpenAMapFirst => '먼저 맵을 여세요.';

  @override
  String get editorMapChangedDuringImport => '가져오는 동안 맵이 변경되었습니다.';

  @override
  String get editorThisPathAlreadyHasASoundReferenceChooseA =>
      '이 경로에 이미 사운드 참조가 있습니다. 다른 파일 이름을 선택하세요.';

  @override
  String get editorASoundAlreadyUsesThisPathChooseADifferent =>
      '사운드가 이미 이 경로를 사용합니다. 다른 파일 이름을 선택하세요.';

  @override
  String get editorIncompleteArchiveListingNameCollisionsCannotBeRuledOut =>
      '불완전한 아카이브 목록: 이름 충돌 가능성을 배제할 수 없습니다.';

  @override
  String get editorAmbiguousArchiveEntryDeletionIsBlocked =>
      '모호한 아카이브 항목: 삭제를 차단했습니다.';

  @override
  String get editorSoundIsDeleted => '삭제된 사운드입니다.';

  @override
  String get editorTheSoundIsNotStoredInThisNewMap =>
      '이 새 맵에 사운드가 저장되어 있지 않습니다.';

  @override
  String get editorSoundGatewayUnavailable => '사운드 인터페이스를 사용할 수 없습니다.';

  @override
  String get editorSourceMapChangedOnDisk => '디스크의 원본 맵이 변경되었습니다.';

  @override
  String get editorMapChangedDuringSoundRead => '사운드를 읽는 동안 맵이 변경되었습니다.';

  @override
  String get editorTheSoundIsNotStoredInThisMap => '이 맵에 사운드가 저장되어 있지 않습니다.';

  @override
  String get editorOpenAnEditableMap => '편집 가능한 맵을 여세요.';

  @override
  String get editorMapChangedReopenTriggerResources =>
      '맵이 변경되었습니다. 트리거 리소스를 다시 여세요.';

  @override
  String get editorPendingSoundEditsExceed64EntriesOr64MiB =>
      '대기 중인 사운드 변경이 64개 또는 64 MiB를 넘었습니다. 먼저 저장하세요.';

  @override
  String get editorResourceEditsCannotRemoveSections =>
      '리소스 편집으로 섹션을 삭제할 수 없습니다.';

  @override
  String get editorUnsupportedAppendedResource => '지원하지 않는 추가 리소스입니다.';

  @override
  String get editorUnsupportedResourceChange => '지원하지 않는 리소스 변경입니다.';

  @override
  String get editorEditTriggerResources => '트리거 리소스 편집';

  @override
  String get editorMapChangedReopenTheTriggerEditor =>
      '맵이 변경되었습니다. 트리거 편집기를 다시 여세요.';

  @override
  String get editorTRIGAndMBRFRecordsCannotBeMixed =>
      'TRIG와 MBRF 레코드를 섞을 수 없습니다.';

  @override
  String get editorCreateBriefing => '브리핑 생성';

  @override
  String get editorEditBriefing => '브리핑 편집';

  @override
  String get editorEditTriggers => '트리거 편집';

  @override
  String get editorOpenAnEditableMapBeforeChangingTechs =>
      '기술을 변경하기 전에 편집 가능한 맵을 여세요.';

  @override
  String get editorTheMapChangedReopenTechSettingsBeforeApplying =>
      '맵이 변경되었습니다. 적용하기 전에 기술 설정을 다시 여세요.';

  @override
  String get editorEditTechSettings => '기술 설정 편집';

  @override
  String get editorOpenAnEditableMapBeforeChangingUpgrades =>
      '업그레이드를 변경하기 전에 편집 가능한 맵을 여세요.';

  @override
  String get editorTheMapChangedReopenUpgradeSettingsBeforeApplying =>
      '맵이 변경되었습니다. 적용하기 전에 업그레이드 설정을 다시 여세요.';

  @override
  String get editorEditUpgradeSettings => '업그레이드 설정 편집';

  @override
  String get editorOpenAnEditableMapBeforeChangingAvailability =>
      '사용 가능 여부를 변경하기 전에 편집 가능한 맵을 여세요.';

  @override
  String get editorTheMapChangedReopenUnitAvailabilityBeforeApplying =>
      '맵이 변경되었습니다. 적용하기 전에 유닛 사용 가능 여부를 다시 여세요.';

  @override
  String get editorEditUnitAvailability => '유닛 사용 가능 여부 편집';

  @override
  String get editorOpenAnEditableMapBeforeChangingUnitSettings =>
      '유닛 설정을 변경하기 전에 편집 가능한 맵을 여세요.';

  @override
  String get editorTheMapChangedReopenUnitSettingsBeforeApplying =>
      '맵이 변경되었습니다. 적용하기 전에 유닛 설정을 다시 여세요.';

  @override
  String get editorEditUnitSettings => '유닛 설정 편집';

  @override
  String get editorOpenAnEditableMapBeforeChangingForceSettings =>
      '세력 설정을 변경하기 전에 편집 가능한 맵을 여세요.';

  @override
  String get editorTheMapChangedReopenForceSettingsBeforeApplying =>
      '맵이 변경되었습니다. 적용하기 전에 세력 설정을 다시 여세요.';

  @override
  String get editorEditForceSettings => '세력 설정 편집';

  @override
  String get editorOpenAnEditableMapBeforeChangingPlayerSettings =>
      '플레이어 설정을 변경하기 전에 편집 가능한 맵을 여세요.';

  @override
  String get editorTheMapChangedReopenPlayerSettingsBeforeApplying =>
      '맵이 변경되었습니다. 적용하기 전에 플레이어 설정을 다시 여세요.';

  @override
  String get editorEditPlayerSettings => '플레이어 설정 편집';

  @override
  String get editorOpenAnEditableMapBeforeChangingMapInformation =>
      '맵 정보를 변경하기 전에 편집 가능한 맵을 여세요.';

  @override
  String get editorTheMapChangedReopenMapInformationBeforeApplying =>
      '맵이 변경되었습니다. 적용하기 전에 맵 정보를 다시 여세요.';

  @override
  String get editorEditMapInformation => '맵 정보 편집';

  @override
  String get editorABuildOrPreparationIsAlreadyRunning =>
      '빌드 또는 준비 작업이 이미 실행 중입니다.';

  @override
  String get editorConfirmThatYouTrustTheEpScriptSourceAndIts =>
      'epScript 소스와 가져오는 코드를 신뢰하는지 확인하세요.';

  @override
  String get editorEnableTheUnverifiedSettingsTestBuildToCompileProject =>
      '프로젝트 설정을 컴파일하려면 미검증 설정 테스트 빌드를 활성화하세요.';

  @override
  String get editorVerifyTheSavedMapAndEUDProjectBindingBefore =>
      '빌드 전에 저장된 맵과 EUD 프로젝트 연결을 검증하세요.';

  @override
  String get editorTheBuildBaseMustBeTheMapBoundTo =>
      '빌드 기본 맵은 이 EUD 프로젝트에 연결된 맵이어야 합니다.';

  @override
  String get editorFinishOrRetryEUDToolsSettingsFirst =>
      'EUD 도구 설정을 먼저 완료하거나 다시 시도하세요.';

  @override
  String get editorChooseAnOutputSeparateFromTheBaseMap =>
      '기본 맵과 별도의 출력을 선택하세요.';

  @override
  String get editorOutputAlreadyExistsChooseANewScxPath =>
      '출력이 이미 존재합니다. 새 .scx 경로를 선택하세요.';

  @override
  String get editorPreparationCancelled => '준비가 취소되었습니다.';

  @override
  String get editorToolSelectionChangedPrepareAgain =>
      '도구 선택이 변경되었습니다. 다시 준비하세요.';

  @override
  String get editorProjectOrMapChangedPrepareAgain =>
      '프로젝트 또는 맵이 변경되었습니다. 다시 준비하세요.';

  @override
  String editorBuildPreparationFailed(String value0) {
    return '빌드 준비 실패: $value0';
  }

  @override
  String editorTheToolDirectoryCouldNotBeSelected(String value0) {
    return '도구 폴더를 선택하지 못했습니다: $value0';
  }

  @override
  String get editorEnterAnAbsoluteEuddraftInstallationPath =>
      'euddraft 설치의 절대 경로를 입력하세요.';

  @override
  String editorToolSettingsCouldNotBeUpdated(String value0) {
    return '도구 설정을 갱신하지 못했습니다: $value0';
  }

  @override
  String editorRangeErrorInvalidValueNotInInclusiveRange(
    String value0,
    String value1,
    String value2,
    String value3,
  ) {
    return '$value0: $value3은 허용 범위 $value1~$value2 밖의 값입니다.';
  }

  @override
  String get editorRecovery => '복구';

  @override
  String get editorSaveAs => '다른 이름으로 저장';

  @override
  String get editorOpenMap => '맵 열기';

  @override
  String get editorEUDBuild => 'EUD 빌드';

  @override
  String get editorTheMapCouldNotBeSaved => '맵을 저장하지 못했습니다.';

  @override
  String get editorRepairTheApplicationOrReportTheObjectRenderingError =>
      '앱을 복구하거나 객체 렌더링 오류를 보고하세요.';

  @override
  String get editorRepairTheApplicationOrReportTheStarCraftTileHelper =>
      '앱을 복구하거나 StarCraft 타일 도우미 오류를 보고하세요.';

  @override
  String get editorTheEUDOutputMustBeAbsentOrARegular =>
      'EUD 출력은 존재하지 않거나 일반 파일이어야 합니다.';

  @override
  String get editorTheCanonicalEUDEntrySourceIsOutsideTheSource =>
      '실제 EUD 진입 소스 경로가 소스 루트 밖에 있습니다.';

  @override
  String get editorTheCanonicalEUDOutputDirectoryIsInsideTheSource =>
      '실제 EUD 출력 폴더 경로가 소스 루트 안에 있습니다.';

  @override
  String get editorSavedSnapshotNewerEditsRemain =>
      '저장한 스냅샷을 검증했습니다. 이후 편집은 열린 문서에 유지되며 아직 저장되지 않았습니다.';

  @override
  String get editorSaveCurrentDocumentAgain =>
      '편집을 마친 뒤 다른 이름으로 저장을 다시 실행해 현재 문서를 저장하세요.';

  @override
  String get terrainModeNatural => '지형';

  @override
  String get terrainModeTile => '단일 타일';

  @override
  String get terrainVariationSeed => '타일 변형 시드';

  @override
  String get catalogShowComponents => '터렛 구성요소 표시';

  @override
  String get catalogIssueSubunit => '이 터렛은 본체 유닛과 함께 생성됩니다.';

  @override
  String get terrainSeedInvalid => '0부터 4294967295까지의 정수를 입력하세요.';

  @override
  String get visualSelection => '그래픽으로 선택';

  @override
  String get epScriptHelpTitle => 'epScript / EUD';

  @override
  String get epScriptHelpBody =>
      'epScript(.eps)는 조건·액션·반복 규칙 같은 사용자 게임 로직을 작성하는 코드입니다. 일반 맵 객체 배치와는 별개이며 euddraft로 컴파일할 때 EUD 트리거로 변환됩니다.\n\n맵과 스크립트를 저장하고 EUD 빌드를 준비한 뒤 별도 출력 맵을 빌드합니다. 코드 편집만으로 실행되거나 원본 맵이 바뀌지 않습니다. 신뢰할 수 있는 코드만 빌드하세요.';

  @override
  String get epScriptInsertExample => '시작 예제 삽입';

  @override
  String get epScriptComplete => '기호 자동 완성';

  @override
  String get epScriptExample => '시작 예제';

  @override
  String get placementTerrainMismatch =>
      '이 두다드에 필요한 바닥 지형과 맞지 않습니다. 같은 종류의 지형 위에 배치하세요. 맵은 변경되지 않았습니다.';

  @override
  String get placementLayerLocked =>
      '배치에 필요한 레이어가 숨겨져 있거나 잠겨 있습니다. 레이어를 표시하고 잠금을 해제하세요.';

  @override
  String get placementOutsideMap =>
      '오브젝트 전체가 맵 안에 들어오도록 위치를 선택하세요. 맵은 변경되지 않았습니다.';
}
