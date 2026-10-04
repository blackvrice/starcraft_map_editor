// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for English (`en`).
class AppLocalizationsEn extends AppLocalizations {
  AppLocalizationsEn([String locale = 'en']) : super(locale);

  @override
  String get recoveryTitle => 'Recover Unsaved Work';

  @override
  String get recoveryEmpty => 'No recovery checkpoints.';

  @override
  String get recoveryDamaged => 'Unreadable or damaged checkpoint';

  @override
  String recoveryBaseline(String path) {
    return 'Last saved map: $path';
  }

  @override
  String recoveryProject(String path) {
    return 'EUD project: $path';
  }

  @override
  String recoverySource(String path) {
    return 'epScript: $path';
  }

  @override
  String get recoveryOpen => 'Open recovery copy';

  @override
  String get recoveryDelete => 'Delete checkpoint';

  @override
  String get recoveryDeleteConfirm =>
      'Permanently delete this recovery checkpoint?';

  @override
  String get recoverySourceChanged =>
      'The last saved map changed on disk. Recovery was stopped; the checkpoint is still available.';

  @override
  String get recoveryFailed =>
      'Recovery could not be opened. Save or close unsaved documents and check the last saved map. The checkpoint is still available.';

  @override
  String get autosaveSettings => 'Autosave Settings';

  @override
  String get autosaveEnabled => 'Automatically save recovery checkpoints';

  @override
  String autosaveInterval(int seconds) {
    return 'Interval: $seconds seconds';
  }

  @override
  String autosaveRetention(int count) {
    return 'Checkpoints per workspace: $count';
  }

  @override
  String get autosaveFailed =>
      'Autosave or recovery failed. Check access and free space in the application data folder.';

  @override
  String get recoveryCancel => 'Cancel';

  @override
  String get recoveryClose => 'Close';

  @override
  String get autosaveApply => 'Apply';

  @override
  String get appTitle => 'StarCraft Map Editor';

  @override
  String get menuFile => 'File';

  @override
  String get menuNewMap => 'New Map…';

  @override
  String get menuOpenMap => 'Open Map…';

  @override
  String get menuPrepareEudBuild => 'Prepare EUD Build…';

  @override
  String get menuEudTools => 'EUD Tools…';

  @override
  String get menuSaveAs => 'Save As…';

  @override
  String get menuMapInformation => 'Map Information…';

  @override
  String get menuPlayerSettings => 'Player Settings…';

  @override
  String get menuForceSettings => 'Force Settings…';

  @override
  String get menuUnitSettings => 'Unit Settings…';

  @override
  String get menuUnitAvailability => 'Unit Availability…';

  @override
  String get menuUpgradeSettings => 'Upgrade Settings…';

  @override
  String get menuTechSettings => 'Tech Settings…';

  @override
  String get menuMapSettings => 'Map Settings…';

  @override
  String get menuClose => 'Close';

  @override
  String get menuEdit => 'Edit';

  @override
  String get menuUndo => 'Undo';

  @override
  String get menuRedo => 'Redo';

  @override
  String get menuSettings => 'Settings…';

  @override
  String get menuLanguage => 'Language';

  @override
  String get menuView => 'View';

  @override
  String get menuResetLayout => 'Reset Layout';

  @override
  String get menuEud => 'EUD';

  @override
  String get menuNewEpScript => 'New epScript';

  @override
  String get menuBuildEudMap => 'Build EUD Map';

  @override
  String get menuCancelEudBuild => 'Cancel EUD Build';

  @override
  String get menuHelp => 'Help';

  @override
  String get menuDocumentation => 'Documentation';

  @override
  String get menuAbout => 'About';

  @override
  String languageSystem(String language) {
    return 'System default ($language)';
  }

  @override
  String get languageTooltip => 'Display language';

  @override
  String get languageSaveFailed =>
      'The language applies now but could not be saved for next time.';

  @override
  String get toolbarOpenMap => 'Open Map';

  @override
  String get toolbarSaveAs => 'Save As';

  @override
  String get toolbarNewEpScript => 'New epScript';

  @override
  String get toolbarBuildEud => 'Build EUD';

  @override
  String get toolbarCancelBuild => 'Cancel Build';

  @override
  String get documentUnsaved => 'Unsaved changes';

  @override
  String get documentSaved => 'No unsaved changes';

  @override
  String get assetsChecking => 'Assets checking';

  @override
  String get assetsCheckingShort => 'Checking';

  @override
  String get assetsReady => 'Assets ready';

  @override
  String get assetsReadyShort => 'Ready';

  @override
  String get assetsNotConfigured => 'Assets not configured';

  @override
  String get assetsNotConfiguredShort => 'Setup';

  @override
  String get assetsUnavailable => 'Assets unavailable';

  @override
  String get assetsUnavailableShort => 'Missing';

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
    return 'Open StarCraft data asset settings • $status';
  }

  @override
  String get railLabel => 'Workspaces';

  @override
  String get railMap => 'Map';

  @override
  String get railCatalog => 'Catalog';

  @override
  String get railMapSettings => 'Map Settings';

  @override
  String get railTriggers => 'Triggers';

  @override
  String get railResources => 'Resources';

  @override
  String get railBriefing => 'Briefing';

  @override
  String get railEudProject => 'EUD Project';

  @override
  String railUnsavedTooltip(String name) {
    return '$name • unsaved changes';
  }

  @override
  String get paneProjectSources => 'Project / Sources';

  @override
  String get paneProjectLayers => 'Project / Layers';

  @override
  String get paneLayersPalette => 'Layers / Object Palette';

  @override
  String get paneInspector => 'Inspector';

  @override
  String get emptyLayers => 'Open a map to see its layers here.';

  @override
  String get emptyInspector =>
      'Select something on the map to see and edit its properties.';

  @override
  String get sourceDraft => 'Draft';

  @override
  String get sourceEpScript => 'epScript source';

  @override
  String get inspectorFile => 'File';

  @override
  String get inspectorLocation => 'Location';

  @override
  String get inspectorLines => 'Lines';

  @override
  String get inspectorCharacters => 'Characters';

  @override
  String get inspectorRevision => 'Revision';

  @override
  String get inspectorState => 'State';

  @override
  String get stateModified => 'Modified';

  @override
  String get stateClean => 'Clean';

  @override
  String get inMemoryDraft => 'In-memory draft';

  @override
  String get startTitle => 'Open a map to begin';

  @override
  String get startBody =>
      'Open an unprotected StarCraft: Remastered UMS map (.scm or .scx). Your original file is never overwritten; edits are saved with Save As.';

  @override
  String get startShortcutHint => 'Shortcut: Ctrl+O';

  @override
  String get recentMaps => 'Recent maps';

  @override
  String get recentMapsLoadFailed => 'Recent maps could not be loaded.';

  @override
  String get recentMapsEmpty => 'Maps you open will appear here.';

  @override
  String get recentMapsRemove => 'Remove from recent maps';

  @override
  String get untitledMap => 'Untitled map';

  @override
  String get notSavedYet => 'Not saved yet';

  @override
  String get mapSizeUnavailable => 'Size unavailable';

  @override
  String get mapTilesetUnavailable => 'Tileset unavailable';

  @override
  String mapTilesetRaw(String value) {
    return 'Tileset $value';
  }

  @override
  String get mapGeometryPreview => 'Geometry preview';

  @override
  String mapMtxmTiles(int count) {
    return '$count MTXM tiles';
  }

  @override
  String get mapNavigationHelp => 'Wheel zoom · Space/middle drag';

  @override
  String mapPickPriority(String order) {
    return 'Pick $order';
  }

  @override
  String mapPlacing(String label) {
    return 'Place $label · Esc cancel';
  }

  @override
  String get mapCreatingLocation => 'Drag new location · Esc cancel';

  @override
  String mapProblemCounts(int blocking, int warnings) {
    return '$blocking blocking · $warnings warning';
  }

  @override
  String get mapCanvasUnavailable =>
      'A unique, non-zero DIM section is required for the canvas.';

  @override
  String get sessionRestricted => 'Restricted';

  @override
  String get sessionModified => 'Modified';

  @override
  String get sessionEditable => 'Editable';

  @override
  String get sessionReadOnly => 'Read-only preview';

  @override
  String get sessionRestrictedHelp =>
      'Some map data could not be verified, so only safe edits are allowed.';

  @override
  String get sessionModifiedHelp =>
      'You have edits that are not saved yet. Use Save As to keep them.';

  @override
  String get sessionEditableHelp =>
      'This map can be edited. The original file is not changed until you save a copy.';

  @override
  String get sessionReadOnlyHelp => 'This map is shown for viewing only.';

  @override
  String get objectCancelLocation => 'Cancel location';

  @override
  String get objectNewLocation => 'New location';

  @override
  String get objectDelete => 'Delete';

  @override
  String get objectUndo => 'Undo';

  @override
  String get objectRedo => 'Redo';

  @override
  String get objectSelectHint => 'Click or drag to select objects';

  @override
  String objectSelectedMove(int count) {
    return '$count selected · drag selection to move';
  }

  @override
  String objectUndoAction(String label) {
    return 'Undo $label';
  }

  @override
  String objectRedoAction(String label) {
    return 'Redo $label';
  }

  @override
  String get objectShortcutHint => 'Ctrl/Shift click adds · Delete removes';

  @override
  String get terrainSelectSource => 'Select a source tile';

  @override
  String terrainRawTile(String raw, String group, String member) {
    return 'Raw tile $raw · group $group · member $member';
  }

  @override
  String get terrainUnsupportedSuffix => ' · unsupported';

  @override
  String terrainFromSuffix(String x, String y) {
    return ' from $x,$y';
  }

  @override
  String get terrainToolSelect => 'Select tile';

  @override
  String get terrainToolBrush => 'Brush';

  @override
  String get terrainToolRectangle => 'Rectangle';

  @override
  String get terrainScope => 'MTXM only · TILE/ISOM preserved';

  @override
  String get paletteTitle => 'Object Palette';

  @override
  String get paletteCatalogTooltip => 'Place new Tile, Doodad, Unit or Sprite';

  @override
  String get paletteCancelTooltip => 'Cancel placement (Esc)';

  @override
  String get paletteSearchHint => 'Search type or #id';

  @override
  String paletteClickToPlace(String label) {
    return '$label: click map to place';
  }

  @override
  String get paletteEmpty => 'No map-local object templates.';

  @override
  String get paletteNoMatch => 'No matching templates.';

  @override
  String get layerTerrain => 'Terrain';

  @override
  String get layerLocations => 'Locations';

  @override
  String get layerDoodads => 'Doodads';

  @override
  String get layerSprites => 'Sprites';

  @override
  String get layerUnits => 'Units';

  @override
  String layerItems(int count) {
    return '$count items';
  }

  @override
  String layerHide(String layer) {
    return 'Hide $layer';
  }

  @override
  String layerShow(String layer) {
    return 'Show $layer';
  }

  @override
  String layerLock(String layer) {
    return 'Lock $layer';
  }

  @override
  String layerUnlock(String layer) {
    return 'Unlock $layer';
  }

  @override
  String get layerSelectionHint =>
      'Click the canvas to inspect the first unlocked object.';

  @override
  String layerObjectsSelected(int count) {
    return '$count objects selected';
  }

  @override
  String get inspectorSourcePath => 'Source path';

  @override
  String get inspectorMapSize => 'Map size';

  @override
  String get inspectorTileset => 'Tileset';

  @override
  String get inspectorMapVersion => 'Map version';

  @override
  String get inspectorScenarioType => 'Scenario type';

  @override
  String get inspectorTerrain => 'Terrain';

  @override
  String get inspectorArchiveSize => 'Archive size';

  @override
  String get inspectorEntries => 'Entries';

  @override
  String get inspectorChkSize => 'CHK size';

  @override
  String get inspectorChkSections => 'CHK sections';

  @override
  String get inspectorDiagnostics => 'Diagnostics';

  @override
  String get valueUnavailable => 'Unavailable';

  @override
  String valueUnknown(String value) {
    return 'Unknown ($value)';
  }

  @override
  String inspectorMtxmViews(int count) {
    return '$count MTXM views';
  }

  @override
  String inspectorRawTiles(int count) {
    return '$count raw tiles';
  }

  @override
  String inspectorEntriesListed(int listed, int total) {
    return '$listed listed / $total';
  }

  @override
  String get inspectorCommonLayers => 'Common layers';

  @override
  String get inspectorMultiNotice =>
      'Select one object to edit its properties. Movement and deletion still apply to the full selection.';

  @override
  String get objectKindUnit => 'Unit';

  @override
  String get objectKindDoodad => 'Doodad';

  @override
  String get objectKindSprite => 'Sprite';

  @override
  String get objectKindLocation => 'Location';

  @override
  String get fieldTypeId => 'Type ID';

  @override
  String get objectPlacedOnlyNotice =>
      'Placed object only. Use File → Map Settings for map-wide unit types, players and game settings.';

  @override
  String get fieldX => 'X (px)';

  @override
  String get fieldY => 'Y (px)';

  @override
  String get fieldOwnerRaw => 'Owner (raw 0-255)';

  @override
  String get fieldHitpointPercent => 'HP %';

  @override
  String get fieldShieldPercent => 'Shield %';

  @override
  String get fieldEnergyPercent => 'Energy %';

  @override
  String get fieldResourceAmount => 'Resource amount';

  @override
  String get fieldHangarAmount => 'Hangar amount';

  @override
  String get fieldDoodadEnabledRaw => 'Enabled raw (0=yes, 1=no)';

  @override
  String get applyProperties => 'Apply properties';

  @override
  String get enterWholeNumber => 'Enter a whole number.';

  @override
  String get propertiesApplied => 'Properties applied.';

  @override
  String get propertiesNoChanges => 'No property changes.';

  @override
  String get fixHighlightedFields => 'Fix the highlighted fields.';

  @override
  String get propertiesUnavailable =>
      'Property editing is no longer available.';

  @override
  String get unlockToApply =>
      'Unlock this layer and use an editable map to apply.';

  @override
  String get rawFieldsTitle => 'Advanced: preserved raw fields';

  @override
  String get rawFieldsNotice =>
      'Raw flags and reserved fields are read-only and remain byte-exact.';

  @override
  String get rawClassId => 'Class ID';

  @override
  String get rawRelationFlags => 'Relation flags';

  @override
  String get rawValidStateFlags => 'Valid state flags';

  @override
  String get rawValidFieldFlags => 'Valid field flags';

  @override
  String get rawStateFlags => 'State flags';

  @override
  String get rawUnused => 'Unused';

  @override
  String get rawRelationClassId => 'Relation class ID';

  @override
  String get rawFlags => 'Flags';

  @override
  String locationTitle(String id) {
    return 'Location $id';
  }

  @override
  String get fieldName => 'Name';

  @override
  String get fieldLeft => 'Left';

  @override
  String get fieldTop => 'Top';

  @override
  String get fieldRight => 'Right';

  @override
  String get fieldBottom => 'Bottom';

  @override
  String get applyLocation => 'Apply location';

  @override
  String get locationApplied => 'Location applied.';

  @override
  String get locationNoChanges => 'No location changes.';

  @override
  String get locationUnavailable => 'Location editing is no longer available.';

  @override
  String get inspectorStringId => 'String ID';

  @override
  String get inspectorElevationFlags => 'Elevation flags';

  @override
  String get locationNamingUnavailable =>
      'Location naming is unavailable for this map.';

  @override
  String get locationRenameNotice =>
      'Renaming allocates a new string ID so shared map strings remain unchanged.';

  @override
  String get tabProblems => 'Problems';

  @override
  String get tabOutput => 'Output';

  @override
  String get tabBuildLog => 'Build Log';

  @override
  String tabWithCount(String label, int count) {
    return '$label ($count)';
  }

  @override
  String get noProblems => 'No problems detected';

  @override
  String get noOutput => 'No operation output';

  @override
  String get severityError => 'Error';

  @override
  String get severityWarning => 'Warning';

  @override
  String get severityInfo => 'Info';

  @override
  String problemsSummary(int errors, int warnings, int infos) {
    return '$errors errors · $warnings warnings · $infos info';
  }

  @override
  String get buildNotConfigured => 'Build settings are not ready';

  @override
  String get buildReady => 'Ready to build';

  @override
  String get buildStarting => 'Starting euddraft…';

  @override
  String get buildStopping => 'Stopping euddraft…';

  @override
  String get buildFinalizing => 'Validating and promoting output…';

  @override
  String get buildCompleted => 'Build completed';

  @override
  String get buildFailedNoOutput => 'Build failed without output';

  @override
  String get buildCancelled => 'Build cancelled';

  @override
  String logBuildId(String id) {
    return 'Build: $id';
  }

  @override
  String logTool(String version) {
    return 'Tool: euddraft $version';
  }

  @override
  String logExitCode(String code) {
    return 'exit code $code';
  }

  @override
  String get logExitCodeUnavailable => 'exit code unavailable';

  @override
  String logStarted(String time) {
    return 'Started: $time';
  }

  @override
  String logCompleted(String time) {
    return 'Completed: $time';
  }

  @override
  String get recordRunning => 'Running';

  @override
  String get recordSucceeded => 'Succeeded';

  @override
  String get recordFailed => 'Failed';

  @override
  String get recordCancelled => 'Cancelled';

  @override
  String get statusReady => 'Ready';

  @override
  String get statusNoDocument => 'No document';

  @override
  String statusDocument(String name, String state) {
    return '$name • $state';
  }

  @override
  String get phaseQueued => 'Queued';

  @override
  String get phaseReading => 'Reading';

  @override
  String get phaseParsing => 'Parsing';

  @override
  String get phaseValidating => 'Validating';

  @override
  String get phaseWriting => 'Writing';

  @override
  String get phaseCompiling => 'Compiling';

  @override
  String get phaseVerifying => 'Verifying';

  @override
  String get phaseSucceeded => 'Completed';

  @override
  String get phaseFailed => 'Failed';

  @override
  String get phaseCancelled => 'Cancelled';

  @override
  String get triggersOrdinary => 'Ordinary triggers';

  @override
  String get triggersEudExtensions => 'EUD extensions';

  @override
  String get triggersOpenEudProject =>
      'Open EUD Project to create, save or build rules';

  @override
  String get triggersUndoProject => 'Undo project';

  @override
  String get triggersRedoProject => 'Redo project';

  @override
  String get triggersEudUnavailable => 'EUD project workspace unavailable.';

  @override
  String get terrainDataTitle => 'Editor terrain data';

  @override
  String get terrainDataProtected => 'EUD protection marker; not an ISOM grid';

  @override
  String get terrainDataIsomPresent => 'ISOM present — generation not verified';

  @override
  String get terrainDataNoIsom => 'No ISOM — raw tile editing';

  @override
  String terrainDataBytes(int actual, String expected) {
    return '$actual bytes / expected $expected';
  }

  @override
  String get terrainDataStructureOnly =>
      'Size matches; terrain meaning is not validated';

  @override
  String get terrainDataInvalidSize =>
      'Size mismatch — original bytes preserved';

  @override
  String get terrainDataUnknownDimensions =>
      'A single valid DIM section is required';

  @override
  String terrainDataDuplicates(String names) {
    return 'Duplicate sections: $names. No active copy selected.';
  }

  @override
  String get terrainDataComparisonUnavailable =>
      'MTXM / TILE comparison unavailable';

  @override
  String terrainDataDifference(int count) {
    return 'MTXM / TILE differ in $count cells. Differences alone do not mean corruption.';
  }

  @override
  String get terrainDataDoodads =>
      'Doodads exist; their terrain may differ from editor tiles.';

  @override
  String get terrainDataReadOnly =>
      'Read-only inspection. Raw brushes change MTXM only; TILE/ISOM are preserved. Isometric and ramp generation is not available yet.';

  @override
  String get newMapTitle => 'New Map';

  @override
  String get newMapStepBasics => 'Size and terrain';

  @override
  String get newMapStepPlayers => 'Players';

  @override
  String get newMapStepReview => 'Review and create';

  @override
  String get newMapStepCurrent => 'Current step';

  @override
  String get newMapSideNote =>
      'You can resize the map later from File → Resize Map. A new map is saved for the first time with Save As.';

  @override
  String get newMapName => 'Map title';

  @override
  String get newMapDefaultTitle => 'Untitled Scenario';

  @override
  String get newMapDescription => 'Description (optional)';

  @override
  String get newMapSize => 'Size';

  @override
  String get newMapSizeSmall => 'Small';

  @override
  String get newMapSizeSmallNote => '1 vs 1 practice';

  @override
  String get newMapSizeCompact => 'Compact';

  @override
  String get newMapSizeCompactNote => '2 players';

  @override
  String get newMapSizeMedium => 'Medium';

  @override
  String get newMapSizeMediumNote => 'Recommended for 4';

  @override
  String get newMapSizeLarge => 'Large';

  @override
  String get newMapSizeLargeNote => '6–8 players';

  @override
  String get newMapSizeHuge => 'Huge';

  @override
  String get newMapSizeHugeNote => 'Large UMS';

  @override
  String get newMapSizeCustom => 'Custom';

  @override
  String get newMapSizeCustomNote => 'Up to 256';

  @override
  String get newMapWidth => 'Width (tiles)';

  @override
  String get newMapHeight => 'Height (tiles)';

  @override
  String newMapSizeValue(int width, int height) {
    return '$width × $height';
  }

  @override
  String get newMapTileset => 'Tileset';

  @override
  String get newMapTilesetHint =>
      'The look of the whole map. It cannot be changed after creation.';

  @override
  String get tilesetBadlands => 'Badlands';

  @override
  String get tilesetSpacePlatform => 'Space Platform';

  @override
  String get tilesetInstallation => 'Installation';

  @override
  String get tilesetAshworld => 'Ashworld';

  @override
  String get tilesetJungle => 'Jungle';

  @override
  String get tilesetDesert => 'Desert';

  @override
  String get tilesetIce => 'Ice';

  @override
  String get tilesetTwilight => 'Twilight';

  @override
  String get newMapInitialTile => 'Starting tile';

  @override
  String get newMapInitialTileHint =>
      'The whole map is filled with this raw tile. ISOM terrain is not generated, so walkability is not guaranteed.';

  @override
  String get newMapTileRequired => 'Pick a starting tile to create the map.';

  @override
  String get newMapTilesLoading => 'Loading tiles from StarCraft data…';

  @override
  String newMapTilePage(int first, int last, int total) {
    return '$first–$last of $total';
  }

  @override
  String get newMapPrevious => 'Previous';

  @override
  String get newMapNext => 'Next';

  @override
  String get newMapReload => 'Reload';

  @override
  String get newMapPlayersTitle => 'How many people will play?';

  @override
  String get newMapPlayersHint =>
      'Each human player gets a Terran start location. You can change races and slots later in Player Settings.';

  @override
  String newMapPlayersValue(int players) {
    return '$players players';
  }

  @override
  String get newMapReviewTitle => 'Ready to create';

  @override
  String get newMapReviewFormat => 'Brood War UMS (.scx)';

  @override
  String get newMapReviewNoTriggers =>
      'No victory or resource triggers are added. Add them in Triggers.';

  @override
  String newMapReviewTile(String tile) {
    return 'Starting tile #$tile';
  }

  @override
  String get newMapReviewNoTile => 'No starting tile yet';

  @override
  String get newMapCancel => 'Cancel';

  @override
  String get newMapBack => 'Back';

  @override
  String get newMapContinue => 'Next';

  @override
  String get newMapCreate => 'Create';

  @override
  String get newMapDiscardTitle => 'Discard unsaved map changes?';

  @override
  String get newMapDiscardBody =>
      'Creating a new map replaces the current document. Save it first if you want to keep these changes.';

  @override
  String get newMapKeepCurrent => 'Keep current map';

  @override
  String get newMapDiscardAndCreate => 'Discard and create';

  @override
  String get catalogTitle => 'What to place';

  @override
  String get catalogKindTile => 'Terrain tiles';

  @override
  String get catalogKindDoodad => 'Doodads';

  @override
  String get catalogKindUnit => 'Units';

  @override
  String get catalogKindSprite => 'Sprites';

  @override
  String get catalogKindSpriteUnit => 'Sprite-units';

  @override
  String get catalogCategories => 'Categories';

  @override
  String get catalogCategoryAll => 'All';

  @override
  String catalogTilesetTitle(String tileset) {
    return '$tileset map';
  }

  @override
  String get catalogTilesetHint =>
      'Only entries that match this map\'s tileset are shown.';

  @override
  String get catalogSearchHint =>
      'Search by name, #ID or type (e.g. Bunker, #125)';

  @override
  String get catalogBackToMap => 'Back to map';

  @override
  String get catalogPlaceableOnly => 'Placeable only';

  @override
  String catalogShownCount(int count) {
    return '$count shown';
  }

  @override
  String get catalogEmpty => 'No catalog entry matches this search.';

  @override
  String get catalogDetailEmpty =>
      'Select an entry to see its details and place it.';

  @override
  String catalogFootprint(int width, int height) {
    return 'Footprint $width × $height tiles';
  }

  @override
  String catalogFootprintOverlay(int width, int height) {
    return 'Footprint $width × $height tiles + overlay';
  }

  @override
  String get catalogOwner => 'Who owns it?';

  @override
  String catalogOwnerPlayer(int count) {
    return 'Player $count';
  }

  @override
  String get catalogKeepPlacing => 'Keep placing on each click';

  @override
  String get catalogHowTo => 'How to place';

  @override
  String get catalogHowTo1 => '1. Press the button below to return to the map.';

  @override
  String get catalogHowTo2 =>
      '2. Click where the outline is shown to place it.';

  @override
  String get catalogHowTo3 =>
      '3. A red outline is outside the map. Press Esc to cancel.';

  @override
  String get catalogPlace => 'Place on map';

  @override
  String get catalogCannotPlace => 'This entry cannot be placed.';

  @override
  String get catalogIssueRelation =>
      'Add-ons and similar units need another building, so they cannot be placed on their own.';

  @override
  String get catalogIssueCapability =>
      'The unit data could not be read from the local game files, so placement is locked.';

  @override
  String get catalogIssueGraphic =>
      'The graphic could not be loaded, so the entry is locked to avoid invisible objects.';

  @override
  String get catalogIssueRecipe =>
      'The doodad layout data is incomplete, so it cannot be placed safely.';

  @override
  String catalogIssueCode(String code) {
    return 'Code: $code';
  }

  @override
  String get buildStepsLabel => 'Steps to an EUD map';

  @override
  String get buildStepMap => 'Save the map';

  @override
  String get buildStepMapNone => 'No map is open';

  @override
  String get buildStepMapDirty => 'Unsaved changes · use Save As';

  @override
  String get buildStepMapSaved => 'Saved';

  @override
  String get buildStepSource => 'Save the script';

  @override
  String get buildStepSourceUntitled => 'Save it as a file to build';

  @override
  String get buildStepSourceDirty => 'Not saved yet';

  @override
  String get buildStepSourceSaved => 'Saved';

  @override
  String get buildStepPrepare => 'Prepare the build';

  @override
  String get buildStepPrepareNeeded => 'Choose input and output files';

  @override
  String get buildStepPrepareReady => 'Ready';

  @override
  String get buildStepPrepareAction => 'Prepare…';

  @override
  String get buildStepRun => 'Build';

  @override
  String get buildStepRunReady => 'Ready to run';

  @override
  String get buildStepRunBusy => 'Building…';

  @override
  String get buildStepRunSucceeded => 'Succeeded';

  @override
  String get buildStepRunFailed => 'Failed · see the result below';

  @override
  String get buildStepRunCancelled => 'Cancelled';

  @override
  String get buildStepRunBlocked => 'Finish the earlier steps first';

  @override
  String get buildSafetyNote => 'The original map is never overwritten';

  @override
  String get buildSummarySucceeded => 'The EUD map was built';

  @override
  String get buildSummaryFailed => 'The build did not finish';

  @override
  String get buildSummaryCancelled => 'The build was cancelled';

  @override
  String get buildSummaryRunning => 'Building with euddraft…';

  @override
  String buildSummaryFirstError(String message) {
    return 'First problem: $message';
  }

  @override
  String buildSummaryAt(String location, String message) {
    return '$location: $message';
  }

  @override
  String get buildSummaryUnchanged =>
      'The original map and earlier output were left unchanged.';

  @override
  String get buildSummaryRawLog => 'Raw euddraft log below';

  @override
  String get trigTitle => 'Triggers';

  @override
  String get trigBriefingTitle => 'Briefing';

  @override
  String trigCount(int count) {
    return '$count total';
  }

  @override
  String get trigAdd => 'Add trigger';

  @override
  String get trigAddBriefing => 'Add briefing';

  @override
  String get trigUndo => 'Undo';

  @override
  String get trigRedo => 'Redo';

  @override
  String get trigValidate => 'Validate references';

  @override
  String get trigSelectAll => 'Select all / none';

  @override
  String get trigOwners => 'Owners…';

  @override
  String get trigEnableSelected => 'Enable selected';

  @override
  String get trigDisableSelected => 'Disable selected';

  @override
  String get trigAddText => 'Add text…';

  @override
  String get trigSwitchNames => 'Switch names…';

  @override
  String get trigUnitProperties => 'Unit properties…';

  @override
  String trigSelectedCount(int count) {
    return '$count selected';
  }

  @override
  String get trigHelp =>
      'Each trigger runs its actions when all of its conditions are true. New triggers start with “Never”, so they do nothing until you change the condition. Save As writes applied changes.';

  @override
  String get trigBriefingHelp =>
      'Briefing actions play in order before the game starts. Times are in milliseconds and portrait slots are 1–4. Add sounds in Resources.';

  @override
  String get trigEmpty => 'No triggers yet. Add one to start.';

  @override
  String trigItemTitle(int count) {
    return 'Trigger $count';
  }

  @override
  String trigBriefingItemTitle(int count) {
    return 'Briefing $count';
  }

  @override
  String get trigOn => 'On';

  @override
  String get trigOff => 'Off';

  @override
  String get trigNoOwner => 'No one runs it';

  @override
  String get trigWhen => 'When';

  @override
  String get trigThen => 'Then';

  @override
  String get trigNothing => 'Nothing';

  @override
  String trigMore(int count) {
    return '+$count more';
  }

  @override
  String get trigMoveUp => 'Move up';

  @override
  String get trigMoveDown => 'Move down';

  @override
  String get trigDuplicate => 'Duplicate trigger';

  @override
  String get trigDuplicateBriefing => 'Duplicate briefing';

  @override
  String get trigDelete => 'Delete trigger';

  @override
  String get trigDeleteBriefing => 'Delete briefing';

  @override
  String trigDeleteTitle(String name) {
    return 'Delete $name?';
  }

  @override
  String get trigDeleteBody =>
      'The entire record, including preserved unsupported slots, will be removed. Undo restores it.';

  @override
  String get trigCancel => 'Cancel';

  @override
  String get trigDeleteConfirm => 'Delete';

  @override
  String get trigClose => 'Close';

  @override
  String get trigValidationTitle => 'Trigger validation';

  @override
  String get trigValidationOk =>
      'Supported slots have valid field values and references. Raw/EUD slots are not interpreted.';

  @override
  String get trigOwnersTitle => 'Who runs the selected triggers?';

  @override
  String get trigOwnersBriefingTitle => 'Who sees the selected briefings?';

  @override
  String get trigOwnersHelp =>
      '“Unchanged” keeps each trigger’s current setting. Choose Add or Remove to change it.';

  @override
  String get trigOwnerUnchanged => 'Unchanged';

  @override
  String get trigOwnerAdd => 'Add';

  @override
  String get trigOwnerRemove => 'Remove';

  @override
  String get trigApplyOwners => 'Apply owners';

  @override
  String get trigEditTitle => 'Edit trigger';

  @override
  String get trigEditBriefingTitle => 'Edit briefing';

  @override
  String get trigDraftNote =>
      'Changes stay in this draft until you press Apply to map. Unsupported slots and flags are preserved byte for byte.';

  @override
  String get trigWho => 'Who runs it?';

  @override
  String get trigWhoHelp =>
      'The trigger is checked separately for each selected player. “Current player” in conditions and actions means that player.';

  @override
  String get trigEnabledChip => 'Trigger enabled';

  @override
  String get trigBriefingEnabledChip => 'Briefing enabled';

  @override
  String get trigWhenAll => 'all of these are true';

  @override
  String get trigThenInOrder => 'run in this order';

  @override
  String get trigBriefingSteps => 'Steps';

  @override
  String trigSlotCount(int current, int total) {
    return '$current / $total';
  }

  @override
  String get trigAddSlot => 'Add';

  @override
  String get trigPreserved => 'preserved as raw data';

  @override
  String get trigSlotEnabled => 'Enabled';

  @override
  String get trigSlotUp => 'Move slot up';

  @override
  String get trigSlotDown => 'Move slot down';

  @override
  String get trigSlotDuplicate => 'Duplicate slot';

  @override
  String get trigSlotRemove => 'Remove slot';

  @override
  String get trigExplainTitle => 'What it does';

  @override
  String trigExplainOwners(String owners) {
    return 'For $owners:';
  }

  @override
  String get trigExplainNoOwner =>
      'No player runs this trigger yet, so it never runs.';

  @override
  String get trigExplainNever =>
      'It has a “Never” condition, so it never runs.';

  @override
  String get trigExplainAlways =>
      'It runs right away because the condition is “Always”.';

  @override
  String trigExplainConditions(int count) {
    return 'When all $count conditions are true,';
  }

  @override
  String get trigExplainNoConditions => 'With no conditions,';

  @override
  String trigExplainActions(int count) {
    return 'it runs $count actions in order.';
  }

  @override
  String get trigExplainOnce =>
      'Without “Preserve trigger” it runs only once per player.';

  @override
  String get trigExplainPreserve =>
      '“Preserve trigger” makes it run again every time the conditions are true.';

  @override
  String get trigExplainDisabled => 'It is turned off and will not run.';

  @override
  String get trigRawRecord => 'Advanced: raw record (read-only)';

  @override
  String get trigApply => 'Apply to map';

  @override
  String get trigSlotAction => 'Action';

  @override
  String get trigSlotCondition => 'Condition';

  @override
  String get trigSlotReplaceNote =>
      'Changing the type replaces this slot’s arguments when applied.';

  @override
  String get trigAlwaysDisplay => 'Always display text';

  @override
  String get trigUseSlot => 'Use slot';

  @override
  String get eudProjectTitle => 'EUD Project';

  @override
  String get eudProjectUnsavedSuffix => ' • Unsaved';

  @override
  String get eudProjectLead =>
      'Change unit, weapon, upgrade and player settings that ordinary map editing cannot reach. Values live in a separate project file and reach the game only through an EUD build.';

  @override
  String get eudNewFromMap => 'New from current map';

  @override
  String get eudOpenProject => 'Open Project';

  @override
  String get eudSaveProject => 'Save Project';

  @override
  String get eudSaveProjectAs => 'Save Project As';

  @override
  String get eudUndoProject => 'Undo project';

  @override
  String get eudRedoProject => 'Redo project';

  @override
  String get eudCloseProject => 'Close Project';

  @override
  String get eudGenerationPreview => 'Generation preview';

  @override
  String get eudGenerationPreviewTitle => 'EUD generation preview';

  @override
  String get eudGenerationPreviewNote =>
      'Settings initialize before user initialization. Rules run at their selected before/after trigger hook. Instance rules affect only their guarded bound unit. Game compatibility is unverified.';

  @override
  String get eudClose => 'Close';

  @override
  String get eudCancel => 'Cancel';

  @override
  String get eudDiscard => 'Discard';

  @override
  String get eudDiscardTitle => 'Discard EUD project changes?';

  @override
  String get eudDiscardBody =>
      'The EUD project has unsaved changes. Save Project As before continuing to keep them.';

  @override
  String get eudWelcomeTitle => 'What an EUD project does';

  @override
  String get eudWelcomeChoose =>
      'Pick new values for units, weapons, upgrades, technologies and players.';

  @override
  String get eudWelcomeSave =>
      'Save them in a project file. The map file is not touched.';

  @override
  String get eudWelcomeBuild =>
      'Build a new EUD map to try them. The original map stays as it is.';

  @override
  String get eudProjectSaveNote =>
      'Project saving preserves EUD settings; it does not compile a map. Map Save As saves ordinary map changes.';

  @override
  String get eudAllFieldsNote =>
      'All EUD field extensions opens unit, weapon, movement, upgrade, technology, player and graphics settings. Prepare EUD Build can include these settings in an unverified test build. Save Project keeps a recovery backup.';

  @override
  String get eudBindingUnchecked =>
      'Map connection has not been verified. Use Verify current map.';

  @override
  String get eudBindingNoMap => 'Open a map to connect an EUD project.';

  @override
  String get eudBindingUnsaved =>
      'The map has unsaved changes. Save the map before connecting.';

  @override
  String get eudBindingRestricted =>
      'This map is restricted and cannot be connected for editing.';

  @override
  String get eudBindingMatched =>
      'Current map matches the project (verified snapshot).';

  @override
  String get eudBindingMismatch =>
      'Current map differs from the project. Open the linked map or explicitly connect this map.';

  @override
  String get eudBindingDiskChanged =>
      'The map changed on disk. Reopen it before connecting.';

  @override
  String get eudConnectionTitle => 'Connected map';

  @override
  String get eudVerifyMap => 'Verify current map';

  @override
  String get eudConnectMap => 'Connect current map';

  @override
  String eudProjectInfo(String project, String map, String sha) {
    return 'Project: $project\nMap: $map\nSHA-256: $sha';
  }

  @override
  String get eudNotSaved => 'Not saved';

  @override
  String get eudChangesTitle => 'Changed values';

  @override
  String eudChangesCount(int count) {
    return '$count stored overrides • Runtime unverified';
  }

  @override
  String get eudChangesEmpty =>
      'No values changed yet. Open All EUD field extensions to choose some.';

  @override
  String get eudAllFields => 'All EUD field extensions';

  @override
  String eudBaselineLine(String value) {
    return 'Baseline: $value';
  }

  @override
  String eudPlannedLine(String requested, String planned) {
    return 'Requested EUD: $requested • Planned EUD value: $planned';
  }

  @override
  String get eudUnresolved => 'Unresolved';

  @override
  String get eudExplicitChk => 'Explicit CHK override';

  @override
  String get eudPreviewOnlyNote =>
      'Preview only, not applied in game. Verify current map after changes. Project validation errors block all planned values.';

  @override
  String get eudRevert => 'Back to the original value';

  @override
  String get eudBaselineUnverified => 'Unverified map';

  @override
  String eudBaselineGameDefault(String detail) {
    return 'Game default (unknown; $detail)';
  }

  @override
  String eudBaselineUnavailable(String detail) {
    return 'Unavailable ($detail)';
  }

  @override
  String eudBaselineNotInChk(String detail) {
    return 'Not stored in CHK; $detail';
  }

  @override
  String get eudStepsTitle => 'Getting it into the game';

  @override
  String get eudStepChoose => 'Choose values';

  @override
  String eudStepChooseDone(int count) {
    return '$count values changed';
  }

  @override
  String get eudStepChooseNone => 'Nothing changed yet';

  @override
  String get eudStepSave => 'Save the project';

  @override
  String get eudStepSaveDone => 'Saved · the map file is untouched';

  @override
  String get eudStepSaveNeeded => 'Not saved yet · the map file is untouched';

  @override
  String get eudStepVerify => 'Check the map';

  @override
  String get eudStepBuild => 'EUD build';

  @override
  String get eudStepBuildHint =>
      'To test these settings, save and verify the map, then use Prepare EUD Build and enable the project settings test build.';

  @override
  String get eudStepBuildIdle =>
      'Builds a new map file. The original stays as it is.';

  @override
  String eudRecoveryBackup(String path) {
    return 'Recovery backup: $path';
  }

  @override
  String get eudSavedPill => 'Saved';

  @override
  String get eudUnsavedPill => 'Unsaved';

  @override
  String get eudRuntimeUnverified => 'Runtime unverified';

  @override
  String get eudTechnical => 'Technical details';

  @override
  String get eudProblems => 'Needs attention';

  @override
  String get eudRulesTitle => 'Execution rules';

  @override
  String eudRulesCount(int current, int total) {
    return '$current / $total';
  }

  @override
  String get eudRulesHelp =>
      'Rules change player resources and other game state while the map runs. They execute before ordinary triggers, and periods count trigger cycles, not seconds. Save Project, then Prepare EUD Build to test.';

  @override
  String get eudRulesHelp2 =>
      'One enabled writer per target. Review user code and ordinary triggers separately. Extended rules support variables, player state, locations, guarded units and local display.';

  @override
  String get eudRulesEmpty => 'No rules yet.';

  @override
  String get eudRuleAdd => 'Add execution rule';

  @override
  String get eudRuleEditTitle => 'Edit execution rule';

  @override
  String get eudRuleDisabled => 'Off';

  @override
  String get eudRuleMoveUp => 'Move rule up';

  @override
  String get eudRuleMoveDown => 'Move rule down';

  @override
  String get eudRuleEdit => 'Edit rule';

  @override
  String get eudRuleDelete => 'Delete rule';

  @override
  String eudRulePlayerN(String number) {
    return 'Player $number';
  }

  @override
  String eudRuleWhenThen(String condition, String action) {
    return 'When $condition → $action';
  }

  @override
  String eudCmpAtLeastSentence(String resource, String value) {
    return '$resource is at least $value';
  }

  @override
  String eudCmpAtMostSentence(String resource, String value) {
    return '$resource is at most $value';
  }

  @override
  String eudCmpExactlySentence(String resource, String value) {
    return '$resource is exactly $value';
  }

  @override
  String eudOpSetToSentence(String amount) {
    return 'set to $amount';
  }

  @override
  String eudOpAddSentence(String amount) {
    return 'add $amount';
  }

  @override
  String eudOpSubtractSentence(String amount) {
    return 'subtract $amount';
  }

  @override
  String get eudRuleOnce => 'Once on first match';

  @override
  String eudRuleEvery(int count) {
    return 'Every $count cycles';
  }

  @override
  String get eudRulePeriodic => 'Periodic';

  @override
  String get eudResMinerals => 'Minerals';

  @override
  String get eudResGas => 'Gas';

  @override
  String get eudCmpAtLeast => 'At least';

  @override
  String get eudCmpAtMost => 'At most';

  @override
  String get eudCmpExactly => 'Exactly';

  @override
  String get eudOpSetTo => 'Set to';

  @override
  String get eudOpAdd => 'Add';

  @override
  String get eudOpSubtract => 'Subtract';

  @override
  String get eudRuleDefaultName => 'Resource rule';

  @override
  String get eudRuleName => 'Rule name';

  @override
  String get eudRulePlayer => 'Player';

  @override
  String get eudRuleResource => 'Resource (condition and action)';

  @override
  String get eudRuleComparison => 'Comparison';

  @override
  String get eudRuleThreshold => 'Threshold (0–2147483647)';

  @override
  String get eudRuleAction => 'Action';

  @override
  String get eudRuleAmount => 'Amount (0–2147483647)';

  @override
  String get eudRuleSchedule => 'Schedule';

  @override
  String get eudRuleInterval => 'Interval (12–86400 trigger cycles)';

  @override
  String get eudRuleEnabled => 'Enabled';

  @override
  String get eudRuleApply => 'Apply rule';

  @override
  String get eudExtTitle => 'Extended execution rule';

  @override
  String get eudExtHelp =>
      'Values: unsigned 16-bit, clamped to 0–65535. Variables 0–15 start at zero. Formula: source × factor + offset. Non-resource actions set their value.';

  @override
  String get eudExtTargetAction => 'Target action';

  @override
  String get eudExtTargetId =>
      'Target ID: variable 0–15, upgrade 0–60, tech 0–43, location 1–255 (except 64), sound string ID; otherwise 0';

  @override
  String get eudExtUnitType => 'Unit type ID (0–227; instance/follow actions)';

  @override
  String get eudExtUnitBindHelp =>
      'Binds the first living unit of this type owned by the selected player. Death, morph or ownership change invalidates the binding permanently. It never acquires a replacement unit. At most four unit rules.';

  @override
  String get eudExtTextPrefix => 'Text prefix (selected player only)';

  @override
  String get eudExtSoundHelp =>
      'Use a registered WAV string ID from Resources. Only the selected player hears the sound.';

  @override
  String get eudExtTiming => 'Execution timing';

  @override
  String get eudExtLeft => 'Condition left';

  @override
  String get eudExtRight => 'Condition right';

  @override
  String get eudExtValue => 'Action value';

  @override
  String get eudExtX => 'X';

  @override
  String get eudExtY => 'Y';

  @override
  String get eudExtWidth => 'Width';

  @override
  String get eudExtHeight => 'Height';

  @override
  String get eudExtConstantId => 'Constant / ID';

  @override
  String get eudExtPlayerRange => 'Player 1–8';

  @override
  String get eudExtFactor => '× (0–255)';

  @override
  String get eudExtOffset => '+ offset';

  @override
  String get eudActVariable => 'Variable';

  @override
  String get eudActMinerals => 'Minerals';

  @override
  String get eudActGas => 'Gas';

  @override
  String get eudActUpgrade => 'Upgrade level';

  @override
  String get eudActTechnology => 'Technology';

  @override
  String get eudActLocation => 'Location';

  @override
  String get eudActUnitHp => 'Unit hit points';

  @override
  String get eudActUnitShields => 'Unit shields';

  @override
  String get eudActUnitEnergy => 'Unit energy';

  @override
  String get eudActFollowUnit => 'Follow unit';

  @override
  String get eudActText => 'Show text';

  @override
  String get eudActSound => 'Play sound';

  @override
  String get eudTimingBefore => 'Before triggers';

  @override
  String get eudTimingAfter => 'After triggers';

  @override
  String get eudSrcConstant => 'Constant';

  @override
  String get eudSrcVariable => 'Variable';

  @override
  String get eudSrcMinerals => 'Minerals';

  @override
  String get eudSrcGas => 'Gas';

  @override
  String get eudSrcUpgrade => 'Upgrade level';

  @override
  String get eudSrcTechnology => 'Technology';

  @override
  String get eudApplyToProject => 'Apply to project';

  @override
  String get eudProjectChanged =>
      'Project changed. Cancel and reopen this editor.';

  @override
  String get eudWeaponCardTitle => 'Weapons';

  @override
  String get eudWeaponCardHelp =>
      'Range and damage type belong to the weapon, so every unit that uses it changes together.';

  @override
  String get eudWeaponEdit => 'Edit weapon EUD settings';

  @override
  String get eudWeaponSharedHelp =>
      'Shared weapon ID for ground/air users. Review Static unit / weapon impact after applying. This does not reassign a unit’s weapon.';

  @override
  String get eudWeaponRawHelp =>
      'Distances are raw integers; tile conversion and runtime support are unverified. Blank removes the override; game defaults remain unknown. Applying changes only the project, not the game.';

  @override
  String get eudWeaponMinRange => 'Minimum range (raw)';

  @override
  String get eudWeaponMaxRange => 'Maximum range (raw)';

  @override
  String get eudWeaponNoDamage => 'No damage type override';

  @override
  String eudWeaponUnsupported(String value) {
    return 'Unsupported: $value';
  }

  @override
  String get eudWeaponReferenceChanged =>
      'Weapon reference source changed. Cancel and reload references.';

  @override
  String eudWeaponWholeNumber(String field) {
    return '$field: enter a whole number from 0 to 4294967295.';
  }

  @override
  String get eudDamageIndependent => 'Independent';

  @override
  String get eudDamageExplosive => 'Explosive';

  @override
  String get eudDamageConcussive => 'Concussive';

  @override
  String get eudDamageNormal => 'Normal';

  @override
  String get eudDamageIgnoreArmor => 'IgnoreArmor';

  @override
  String get eudImpactTitle => 'Static unit / weapon impact';

  @override
  String get eudImpactHelp =>
      'Base DAT references only; proposed reference changes, spells and actual attack behavior are not resolved. Type settings are global; player fields affect the selected slot.';

  @override
  String get eudImpactLoad => 'Load weapon impact';

  @override
  String get eudImpactUnavailable =>
      'Weapon references unavailable. Load or reload to analyze.';

  @override
  String eudImpactSource(String source) {
    return 'Reference source: $source';
  }

  @override
  String get eudImpactChooseUnit =>
      'Choose a unit to edit its direct ground / air weapon. Subunit weapons are separate; select that subunit explicitly.';

  @override
  String get eudImpactEditShields => 'Edit unit EUD shields';

  @override
  String get eudImpactGround => 'Ground';

  @override
  String get eudImpactAir => 'Air';

  @override
  String eudImpactNoWeapon(String slot) {
    return '$slot weapon: None (#130)';
  }

  @override
  String eudImpactEditWeapon(String slot, String weapon) {
    return '$slot: $weapon — Edit EUD';
  }

  @override
  String eudImpactSubunits(String subunit1, String subunit2) {
    return 'Subunit IDs: $subunit1, $subunit2 (228 = None)';
  }

  @override
  String eudImpactCannotAnalyze(String reason) {
    return 'Cannot analyze: $reason';
  }

  @override
  String get eudImpactUnknownWeapon =>
      'Impact unknown: weapon references unavailable.';

  @override
  String eudImpactPlayerOnly(String number) {
    return 'Player $number only; runtime behavior unverified.';
  }

  @override
  String get eudImpactUnknownShared =>
      'Impact unknown: shared references for this table are unavailable.';

  @override
  String eudImpactUnits(String direct, String subunits) {
    return 'Direct units: $direct\nVia subunits: $subunits';
  }

  @override
  String get eudImpactNone => 'None in static references';

  @override
  String eudShieldTitle(String unit) {
    return '$unit — Shields';
  }

  @override
  String get eudShieldHelp =>
      'Activation and maximum are independent type settings shared by all players. Blank maximum or No override removes that setting; defaults are unknown.';

  @override
  String get eudShieldNoOverride => 'No activation override';

  @override
  String get eudShieldEnabled => 'Shields enabled';

  @override
  String get eudShieldDisabled => 'Shields disabled';

  @override
  String get eudShieldUnsupported => 'Unsupported imported activation';

  @override
  String get eudShieldMaximum => 'Maximum shields (0–65535)';

  @override
  String get eudShieldOverrideChk => 'Explicitly override CHK maximum shields';

  @override
  String get eudShieldInitNote =>
      'Initialization is not implemented: existing placed units keep their CHK shield percentages; no current-shield refill, clamp or recurring write is generated. New-unit initialization requires runtime verification. Applying saves project intent only; EUD build integration is pending.';

  @override
  String get eudShieldChooseSupported =>
      'Choose a supported shield activation value.';

  @override
  String get eudShieldWholeNumber =>
      'Maximum shields require a whole number from 0 to 65535.';

  @override
  String get eudFieldsTitle => 'EUD field extensions';

  @override
  String get eudFieldsIntro =>
      'Candidate settings • Runtime unverified. Add each edit to the draft, then apply the draft to the project. Unsaved input is discarded when changing selection.';

  @override
  String get eudFieldsField => 'What to change';

  @override
  String get eudFieldsSearch => 'Find target by name or ID';

  @override
  String get eudFieldsTarget => 'Which one';

  @override
  String get eudFieldsPlayerNote =>
      'Selected player slot only. Supply uses half-points (400 = 200 supply).';

  @override
  String get eudFieldsGlobalNote =>
      'Global type setting, shared across players. DAT defaults are not loaded. Shared-reference impact is not resolved for this editor.';

  @override
  String eudFieldsApi(String member, String unit) {
    return 'Candidate API: $member • $unit';
  }

  @override
  String eudFieldsStorage(String maximum, String mask) {
    return 'Storage input: 0–$maximum$mask. Gameplay limits are unverified.';
  }

  @override
  String eudFieldsMask(String mask) {
    return ' • Allowed mask: $mask';
  }

  @override
  String get eudFieldsValue => 'Value (decimal integer)';

  @override
  String get eudFieldsChoose => 'Choose a value';

  @override
  String eudFieldsUnsupported(String value) {
    return 'Unsupported stored value: $value';
  }

  @override
  String get eudFieldsYes => 'Yes (true)';

  @override
  String get eudFieldsNo => 'No (false)';

  @override
  String get eudFieldsOverrideChk =>
      'Explicitly override ordinary CHK settings';

  @override
  String get eudFieldsStage => 'Add / update draft';

  @override
  String get eudFieldsRemove => 'Remove from draft';

  @override
  String eudFieldsDraftSummary(int count, String value) {
    return '$count draft overrides • Current: $value';
  }

  @override
  String get eudFieldsNoOverride => 'No override';

  @override
  String get eudFieldsApply => 'Apply draft to project';

  @override
  String get eudFieldsNeedChk =>
      'This value also changes an ordinary map (CHK) setting. Tick the box above to allow it.';

  @override
  String get eudFieldsOutOfRange => 'The value is outside the allowed range.';

  @override
  String get eudFieldsInvalid =>
      'This value cannot be used for the selected field.';

  @override
  String get isomFillTitle => 'Fill Isometric Terrain';

  @override
  String get isomFillScope =>
      'Fill or recalculate terrain, draw boundaries and heights, or place validated ramps. Preview preserves the map until Apply. Unsupported or damaged terrain is refused.';

  @override
  String get isomTerrainType => 'Flat terrain type';

  @override
  String isomTerrainId(int id) {
    return 'Terrain type #$id';
  }

  @override
  String isomFillPreview(int count) {
    return '$count game tiles will change. Editor terrain (ISOM) will also be updated.';
  }

  @override
  String get isomFillUnavailable =>
      'Terrain fill is unavailable. Configure StarCraft data in Settings, and use an even-width map with matching TILE/MTXM and supported ISOM shapes.';

  @override
  String get isomFillCancel => 'Cancel';

  @override
  String get isomFillApply => 'Fill whole map';

  @override
  String get basicToolsTitle => 'Basic Editing Tools';

  @override
  String get basicFog => 'Initial fog';

  @override
  String get basicUnits => 'Selected units';

  @override
  String get basicStarts => 'Start locations';

  @override
  String get basicLocations => 'Locations';

  @override
  String get basicOpenMap => 'Open an editable map first.';

  @override
  String get basicFogUnavailable => 'A unique valid MASK/DIM grid is required.';

  @override
  String basicPlayer(int id) {
    return 'Player $id';
  }

  @override
  String get basicFogHide => 'Hide terrain';

  @override
  String get basicBrush => 'Brush';

  @override
  String get basicRectangle => 'Rectangle';

  @override
  String get basicFillAll => 'Fill whole map';

  @override
  String get basicFogScope =>
      'Dark cells are initially hidden. Edits affect this player only.';

  @override
  String basicSelectedUnits(int count) {
    return '$count selected units';
  }

  @override
  String get basicKeepBlank =>
      'Leave numeric fields blank to preserve existing values.';

  @override
  String get basicOwner => 'Owner (1–12)';

  @override
  String get basicHitpoints => 'Hitpoints %';

  @override
  String get basicShields => 'Shields %';

  @override
  String get basicEnergy => 'Energy %';

  @override
  String get basicResources => 'Resources';

  @override
  String get basicHangar => 'Hangar';

  @override
  String get basicUnitStates => 'State and inheritance';

  @override
  String get basicCloak => 'Cloaked';

  @override
  String get basicBurrow => 'Burrowed';

  @override
  String get basicLifted => 'Lifted / in transit';

  @override
  String get basicHallucination => 'Hallucination';

  @override
  String get basicInvincible => 'Invincible';

  @override
  String get basicKeep => 'Keep';

  @override
  String get basicOff => 'Off';

  @override
  String get basicOn => 'On';

  @override
  String get basicInherit => 'Use game default';

  @override
  String get basicValidFields => 'Use stored field values';

  @override
  String get basicApplyStored => 'Apply stored value';

  @override
  String get basicApply => 'Apply';

  @override
  String get basicRelationHelp =>
      'Select two compatible units in the map. Linking updates mutual references; positions are kept. Unlink before changing their owner.';

  @override
  String get basicLinkAddon => 'Link addon';

  @override
  String get basicLinkNydus => 'Link Nydus';

  @override
  String get basicUnlink => 'Unlink';

  @override
  String get basicStartsHelp =>
      'Set or move the selected player’s start location. Duplicate starts are preserved and must be reviewed first.';

  @override
  String get basicPixelX => 'Pixel X';

  @override
  String get basicPixelY => 'Pixel Y';

  @override
  String get basicLocationsUnavailable =>
      'A unique valid location table is required.';

  @override
  String get basicElevationHelp =>
      'Select a location and its ground/air elevation conditions. Other flag bits and strings are preserved.';

  @override
  String get basicLowGround => 'Low ground';

  @override
  String get basicMediumGround => 'Medium ground';

  @override
  String get basicHighGround => 'High ground';

  @override
  String get basicLowAir => 'Low air';

  @override
  String get basicMediumAir => 'Medium air';

  @override
  String get basicHighAir => 'High air';

  @override
  String get basicSpritesDoodads => 'Sprites / Doodads';

  @override
  String get basicClipboard => 'Clipboard';

  @override
  String get basicCopy => 'Copy selection';

  @override
  String get basicCut => 'Cut selection';

  @override
  String get basicPaste => 'Paste at pixel position';

  @override
  String get basicClipboardHelp =>
      'Document-local units, sprites and locations. Copy both linked units together. Start locations and unverified Doodad overlays are refused.';

  @override
  String get basicSpriteDisabled => 'Sprite-unit disabled';

  @override
  String get basicSpriteHelp =>
      'Disabled applies to sprite-units only. Possible Doodad overlays require the composite tool below. Unknown flags are preserved.';

  @override
  String get basicLoadDoodad => 'Load selected Doodad recipe';

  @override
  String get basicDoodadEnabled => 'Doodad enabled';

  @override
  String get basicDoodadHelp =>
      'Select one Doodad and explicitly choose its matching overlay. The footprint and underlying terrain must match local data. Pure-sprite enabled state is editor metadata; sprite-unit disabling also changes THG2.';

  @override
  String get basicOverlay => 'Matching overlay';

  @override
  String get basicLocationSearch => 'Find by name or ID';

  @override
  String get basicRawTerrain => 'Raw terrain clipboard';

  @override
  String get basicRawClipboardHelp =>
      'Copies raw MTXM tiles only and preserves TILE/ISOM. This does not calculate isometric boundaries. Maps containing Doodads require verified composite editing. Coordinates below are tile coordinates.';

  @override
  String get basicCutReplacement => 'Cut fill tile value (already in map)';

  @override
  String get basicTileLeft => 'Left tile';

  @override
  String get basicTileTop => 'Top tile';

  @override
  String get basicTileRight => 'Right tile';

  @override
  String get basicTileBottom => 'Bottom tile';

  @override
  String get basicTileX => 'Destination tile X';

  @override
  String get basicTileY => 'Destination tile Y';

  @override
  String get basicStartMissing => 'Missing start location';

  @override
  String basicStartDuplicate(int count) {
    return 'Duplicate start locations: $count';
  }

  @override
  String get basicApplySelectedLocations => 'Apply to selected locations';

  @override
  String get basicStartCanvasHelp =>
      'Click the map to fill coordinates; Apply places or moves this player\'s start location.';

  @override
  String get selectionTitle => 'Selection and navigation';

  @override
  String get selectionSearch => 'Name, #type ID, layer or coordinates';

  @override
  String get selectionAllLayers => 'All object layers';

  @override
  String get selectionAllOwners => 'All owners';

  @override
  String get selectionSelectable => 'Selectable only';

  @override
  String get selectionResults => 'Select search results';

  @override
  String get selectionAll => 'Select all in active layer';

  @override
  String get selectionInvert => 'Invert in active layer';

  @override
  String get selectionSameType => 'Select same type';

  @override
  String get selectionSameOwner => 'Select same owner';

  @override
  String get selectionClear => 'Clear selection';

  @override
  String get selectionFocus => 'Go to selection';

  @override
  String get selectionFit => 'Fit selection';

  @override
  String get selectionFitMap => 'Fit map';

  @override
  String get selectionGoTo => 'Go to coordinates';

  @override
  String get selectionTileCoordinates => 'Tile coordinates';

  @override
  String get selectionEmpty => 'Select an object first.';

  @override
  String get selectionStale =>
      'The map or layer changed. Refresh your selection.';

  @override
  String get selectionNoResults => 'No matching objects';

  @override
  String get selectionUnavailable => 'Hidden or locked';

  @override
  String get selectionOverlap => 'Choose an overlapping object';

  @override
  String selectionCounts(int count, int selected) {
    return '$count results · $selected selected';
  }

  @override
  String get eudDatLoad => 'Load local DAT defaults';

  @override
  String get eudDatUseDefault => 'Use DAT value in input';

  @override
  String get eudDatUnavailable => 'Not loaded / not a DAT field';

  @override
  String eudDatDefault(String value, String source) {
    return 'Local DAT: $value · $source (CHK and runtime may differ)';
  }

  @override
  String eudDatImpact(String before, String after, String direct) {
    return 'Original users: $before\nPlanned users: $after\nDirect planned references: $direct';
  }

  @override
  String eudDatPartial(int count) {
    return 'Unresolved DAT links: $count. Static lists exclude IScript overlays and HD behavior.';
  }

  @override
  String eudConflictTitle(int count) {
    return 'Static conflict analysis · $count overlaps';
  }

  @override
  String get eudConflictHelp =>
      'Current map and open source only. Conditions, groups and dynamic code may change actual behavior; review unresolved items before a test build.';

  @override
  String get isomFillMode => 'Fill flat terrain';

  @override
  String get isomConvertMode => 'Recalculate existing ISOM';

  @override
  String isomConvertPreview(int count) {
    return '$count game tiles will change. Existing ISOM and its flags are preserved.';
  }

  @override
  String get isomConvertApply => 'Apply recalculated tiles';

  @override
  String get isomBrushMode => 'Boundary brush';

  @override
  String get isomRampMode => 'Ramp';

  @override
  String get isomBrushFreehand => 'Freehand';

  @override
  String get isomBrushRectangle => 'Rectangle';

  @override
  String get isomBrushSize => 'Brush size';

  @override
  String get isomBrushHint =>
      'Draw on the preview. Select terrain IDs for height changes; boundaries connect automatically. Apply commits all strokes as one Undo entry.';

  @override
  String get isomBrushApply => 'Apply terrain edits';

  @override
  String get isomBrushReset => 'Reset preview';

  @override
  String get isomRampHint =>
      'Select a local VF4 ramp recipe, then click its top-left tile on a matching cliff. Orientation is fixed by the recipe. Incompatible terrain is refused.';

  @override
  String get isomRampEmpty => 'This tileset has no verified ramp recipes.';

  @override
  String get isomRampRecipe => 'Ramp recipe';

  @override
  String get isomBrushStrokeRejected =>
      'The last stroke was rejected. The previous preview is preserved.';

  @override
  String get resizeTerrainLoading =>
      'Loading verified terrain and doodad data…';

  @override
  String get resizeIsomFillHint =>
      'Choose a flat terrain sample (zero-based tile X/Y) for added ISOM terrain. New fog cells are hidden for all players. Doodad footprints must remain fully inside the map.';

  @override
  String resizeDoodadImpact(int moved, int outside) {
    return 'Doodads moved: $moved; footprints outside: $outside';
  }

  @override
  String resizeTerrainImpact(int count) {
    return 'Terrain cells recalculated: $count. Original diamonds and verified doodad footprints are retained.';
  }

  @override
  String get resizeCoordinateScope =>
      'Trigger and EUD code coordinates are preserved. Review custom coordinates after resizing. Unknown terrain or ambiguous doodads block application.';

  @override
  String get editorPrepareEUDBuild => 'Prepare EUD Build';

  @override
  String get editorBuildSavedFilesOnDiskSaveMapAndSource =>
      'Build saved files on disk. Save map and source edits first. With project settings, leave source folder and entry blank for a settings-only build. Output must be a new .scx.';

  @override
  String get editorBaseMapPath => 'Base map path';

  @override
  String get editorSourceFolderPath => 'Source folder path';

  @override
  String get editorEntryEpsPath => 'Entry .eps path';

  @override
  String get editorNewOutputScxPath => 'New output .scx path';

  @override
  String get editorToolOverrideForThisBuildOptional =>
      'Tool override for this build (optional)';

  @override
  String get editorBlankToolOverrideUsesYourEUDToolsSelectionPrepare =>
      'Blank tool override uses your EUD Tools selection. Prepare checks files; Build runs the compiler separately.';

  @override
  String get editorITrustThisSourceAndItsImportsToRun =>
      'I trust this source and its imports to run code on this computer.';

  @override
  String get editorIncludeProjectSettingsInAnUnverifiedTestBuild =>
      'Include project settings in an unverified test build';

  @override
  String get editorTypeSettingsInitializeOnceRulesUseTheirBeforeAfter =>
      'Type settings initialize once. Rules use their before/after trigger hook; instance rules can change a guarded unit. Game and multiplayer behavior still require testing.';

  @override
  String get editorCancel => 'Cancel';

  @override
  String get editorPrepare => 'Prepare';

  @override
  String get editorEUDTools => 'EUD Tools';

  @override
  String get editorChooseAnExternalEuddraftInstallationOrUseTheApp =>
      'Choose an external euddraft installation or use the app default. Project-specific paths take priority.';

  @override
  String get editorExternalEuddraftPath => 'External euddraft path';

  @override
  String get editorInstallationDirectoryOrEuddraftExeAbsolutePath =>
      'Installation directory or euddraft.exe (absolute path)';

  @override
  String get editorBrowseInstallationFolder => 'Browse installation folder';

  @override
  String get editorSelectionAppDefault => 'Selection: App default';

  @override
  String editorSelectionExternal(String value0) {
    return 'Selection: External\n$value0';
  }

  @override
  String get editorNoBundledToolIsIncludedInThisAppYet =>
      'No bundled tool is included in this app yet. Select an external installation.';

  @override
  String editorBundledEuddraft01025Editor1No(String value0) {
    return 'Bundled euddraft 0.10.2.5 (editor.1)\nNo separate Python installation is required. Updates are managed with the app.\n$value0\nLicenses and modification details: BUNDLE-NOTICE.txt in this folder.';
  }

  @override
  String editorInspectionPassedEuddraft(String value0, String value1) {
    return 'Inspection passed — euddraft $value0\n$value1';
  }

  @override
  String get editorInspectionDoesNotRunTheCompilerSavingThisChoice =>
      'Inspection does not run the compiler. Saving this choice does not prepare a build or change an existing build plan.';

  @override
  String get editorUseAppDefault => 'Use app default';

  @override
  String get editorReinspect => 'Reinspect';

  @override
  String get editorSaveAndInspect => 'Save and inspect';

  @override
  String get editorClose => 'Close';

  @override
  String get editorForceSettings => 'Force Settings';

  @override
  String get editorPlayerAssignment => 'Player assignment';

  @override
  String editorPlayer(String value0) {
    return 'Player $value0';
  }

  @override
  String get editorCopiesOnlyTheEditedForceAssignmentToPlayers1 =>
      'Copies only the edited force assignment to Players 1–8.';

  @override
  String editorAssignToForce(String value0) {
    return 'Assign to Force $value0';
  }

  @override
  String editorStoredIDPreserved(String value0) {
    return 'Stored ID $value0 (preserved)';
  }

  @override
  String editorForce(String value0) {
    return 'Force $value0';
  }

  @override
  String get editorCopiesEditedForceNamesAndOptionsOnlyPlayerAssignments =>
      'Copies edited force names and options only. Player assignments are separate.';

  @override
  String get editorForceName => 'Force name';

  @override
  String get editorRandomizeStartLocations => 'Randomize start locations';

  @override
  String get editorAllies => 'Allies';

  @override
  String get editorAlliedVictory => 'Allied victory';

  @override
  String get editorSharedVision => 'Shared vision';

  @override
  String get editorApplyUpdatesAllEditedPlayersAndForcesSaveAs =>
      'Apply updates all edited players and forces. Save As writes the map.';

  @override
  String editorUndo(String value0) {
    return 'Undo: $value0';
  }

  @override
  String editorRedo(String value0) {
    return 'Redo: $value0';
  }

  @override
  String get editorApply => 'Apply';

  @override
  String get editorTheExistingTextIsNotValidUTF8Its =>
      'The existing text is not valid UTF-8. Its original bytes are preserved; editing is unavailable.';

  @override
  String get editorMapInformation => 'Map Information';

  @override
  String get editorMapTitle => 'Map title';

  @override
  String get editorDescription => 'Description';

  @override
  String get editorApplyUpdatesThisMapOnlySharedNamesRemainUnchanged =>
      'Apply updates this map only. Shared names remain unchanged. Use Save As to write the edited map.';

  @override
  String get editorDiscardUnappliedSettings => 'Discard unapplied settings?';

  @override
  String get editorOneOrMoreTabsHaveUnappliedDraftsAppliedChanges =>
      'One or more tabs have unapplied drafts. Applied changes remain in the map and can be undone.';

  @override
  String get editorKeepEditing => 'Keep editing';

  @override
  String get editorDiscardAndClose => 'Discard and close';

  @override
  String get editorMapSettings => 'Map Settings';

  @override
  String get editorMapWideSettingsTheCanvasInspectorEditsIndividualPlaced =>
      'Map-wide settings. The canvas Inspector edits individual placed objects. Apply affects the current tab; Save As writes the map.';

  @override
  String get editorEUDExecutionRules => 'EUD execution rules';

  @override
  String get editorMap => 'Map';

  @override
  String get editorPlayers => 'Players';

  @override
  String get editorForces => 'Forces';

  @override
  String get editorUnits => 'Units';

  @override
  String get editorAvailability => 'Availability';

  @override
  String get editorUpgrades => 'Upgrades';

  @override
  String get editorTech => 'Tech';

  @override
  String get editorSlotType => 'Slot type';

  @override
  String get editorRace => 'Race';

  @override
  String get editorColor => 'Color';

  @override
  String get editorUnavailable => 'Unavailable';

  @override
  String get editorPlayerSettings => 'Player Settings';

  @override
  String editorPlayer203c6551(String value0, String value1) {
    return 'Player $value0$value1';
  }

  @override
  String get editorReadOnly => ' (read-only)';

  @override
  String get editorSlotTypeRaceAndColorEditsForPlayablePlayers =>
      'Slot type, race and color edits for playable Players 1–8 only.';

  @override
  String get editorOnlyTheEightPlayableSlotsCanBeEditedPlayers =>
      'Only the eight playable slots can be edited. Players 9–12 have no COLR color entry.';

  @override
  String get editorColorSettingsAreSavedToTheMapCanvasPreviews =>
      'Color settings are saved to the map. Canvas previews currently use default player colors.';

  @override
  String editorPendingFieldChangesApplyUpdatesAllEditedPlayersSave(
    String value0,
  ) {
    return '$value0 pending field changes. Apply updates all edited players; Save As writes the map.';
  }

  @override
  String get editorNoEditedFieldsInTheCurrentSelection =>
      'No edited fields in the current selection.';

  @override
  String editorDraftFieldCopiesPreparedForIDsReviewThenApply(
    String value0,
    String value1,
  ) {
    return '$value0 draft field copies prepared for $value1 IDs. Review, then Apply.';
  }

  @override
  String get editorSearchNameOrID12ForExactID =>
      'Search name or ID (#12 for exact ID)';

  @override
  String editorCurrent(String value0) {
    return 'Current: $value0';
  }

  @override
  String get editorNoMatchingIDsCurrentSelectionAndDraftsAreUnchanged =>
      'No matching IDs. Current selection and drafts are unchanged.';

  @override
  String get editorCopyEditedFieldsToIDs => 'Copy edited fields to IDs';

  @override
  String editorSource(String value0, String value1) {
    return 'Source: $value0. $value1';
  }

  @override
  String get editorCopiesOnlyEditedFieldsReplacingThoseDraftFieldsAt =>
      'Copies only edited fields, replacing those draft fields at the target IDs. Search does not select targets. The map changes only after Apply.';

  @override
  String editorTargetIDs(String value0, String value1) {
    return 'Target IDs ($value0–$value1)';
  }

  @override
  String get editorPrepareDraftCopies => 'Prepare draft copies';

  @override
  String get editorUnappliedDraft => 'Unapplied draft';

  @override
  String get editorTheMapChangedInAnotherEditorOrThroughUndo =>
      'The map changed in another editor or through Undo/Redo. Reload before applying this tab.';

  @override
  String get editorReloadAndDiscardThisDraft => 'Reload and discard this draft';

  @override
  String get editorDiscardTabDraft => 'Discard tab draft';

  @override
  String get editorStarCraftDataAssets => 'StarCraft Data Assets';

  @override
  String
  get editorChooseTheInstalledStarCraftRemasteredDirectoryTheEditorReads =>
      'Choose the installed StarCraft: Remastered directory. The editor reads its local CASC storage through the bundled CascLib helper without extracting or copying copyrighted game data.';

  @override
  String get editorClear => 'Clear';

  @override
  String get editorRefresh => 'Refresh';

  @override
  String get editorChooseInstallation => 'Choose Installation…';

  @override
  String editorCASCBuildMiBCheckedCascLibHelper(
    String value0,
    String value1,
    String value2,
    String value3,
    String value4,
  ) {
    return 'CASC $value0 • build $value1 • $value2 MiB checked • CascLib $value3 • helper $value4';
  }

  @override
  String get editorConfiguredPath => 'Configured path';

  @override
  String get editorNotConfigured => 'Not configured';

  @override
  String get editorExpectedTheFolderContainingStarCraftExeBuildInfoAnd =>
      'Expected: the folder containing StarCraft.exe, .build.info, and Data\\.';

  @override
  String get editorLoadingSettings => 'Loading settings…';

  @override
  String get editorInspectingAssets => 'Inspecting assets…';

  @override
  String editorRequiredAssetsReady(String value0, String value1) {
    return '$value0/$value1 required assets ready';
  }

  @override
  String get editorStarCraftInstallationIsNotConfigured =>
      'StarCraft installation is not configured';

  @override
  String get editorStarCraftCASCDataIsUnavailable =>
      'StarCraft CASC data is unavailable';

  @override
  String editorRequiredAssetsFound(String value0, String value1) {
    return '$value0/$value1 required assets found';
  }

  @override
  String get editorMissing => 'Missing';

  @override
  String get editorInvalid => 'Invalid';

  @override
  String get editorUnavailableAssetFiles => 'Unavailable asset files';

  @override
  String editorAndMore(String value0) {
    return '…and $value0 more';
  }

  @override
  String editorStoredFlagPreserved(String value0) {
    return 'Stored flag $value0 (preserved)';
  }

  @override
  String editorTechd52bce90(String value0, String value1, String value2) {
    return 'Tech #$value0, $value1: $value2';
  }

  @override
  String get editorEffectiveStateUnknownStoredFlagPreserved =>
      'Effective state: unknown (stored flag preserved)';

  @override
  String editorEffectiveStateAvailableResearched(String value0, String value1) {
    return 'Effective state: available $value0, researched $value1';
  }

  @override
  String get editorTechSettings => 'Tech Settings';

  @override
  String editorEditing(String value0, String value1, String value2) {
    return 'Editing $value0 / $value1$value2.';
  }

  @override
  String get editorAlternateSectionsPreserved =>
      '; alternate sections preserved';

  @override
  String editorMapCostsAndOnlyInheritanceFlagsChangeOnlyIf(String value0) {
    return 'Map costs and $value0 only. Inheritance flags change only if edited.';
  }

  @override
  String get editorMapDefaults => 'map defaults';

  @override
  String get editorUseCustomCosts => 'Use custom costs';

  @override
  String get editorUseGameDefaults => 'Use game defaults';

  @override
  String get editorGameDefaultsPreserveStoredCustomCostsDefaultGameValues =>
      'Game defaults preserve stored custom costs. Default game values are not loaded here.';

  @override
  String get editorMapDefaultSettings => 'Map default settings';

  @override
  String editorCopiesOnlyCurrentTechPlayerEditsToPlayers1(String value0) {
    return 'Copies only current tech #$value0 player edits to Players 1–8. Map costs and defaults are excluded.';
  }

  @override
  String get editorUsePlayerSettings => 'Use player settings';

  @override
  String get editorInheritMapSettings => 'Inherit map settings';

  @override
  String get editorAvailable => 'Available';

  @override
  String get editorNotResearched => 'Not researched';

  @override
  String get editorAlreadyResearched => 'Already researched';

  @override
  String
  get editorMapSettingsAffectInheritingPlayersInheritancePreservesStoredPlayer =>
      'Map settings affect inheriting players. Inheritance preserves stored player flags. Availability and research status are independent.';

  @override
  String editorPendingChangesAcrossTechsAndPlayersApplyUpdatesThe(
    String value0,
  ) {
    return '$value0 pending changes across techs and players. Apply updates the document; Save As writes the map.';
  }

  @override
  String get editorUnitAvailability => 'Unit Availability';

  @override
  String get editorMapWideUnitProductionSettingsSeparateFromPlacedUnit =>
      'Map-wide unit production settings, separate from placed-unit Inspector properties.';

  @override
  String get editorUnit => 'Unit';

  @override
  String editorMapDefaultsAndPlayerOnlyInheritanceChangesOnlyIf(String value0) {
    return 'Map defaults and Player $value0 only. Inheritance changes only if edited.';
  }

  @override
  String get editorMapDefaultAffectsAllInheritingPlayers =>
      'Map default — affects all inheriting players';

  @override
  String get editorDefaultProhibited => 'Default: prohibited';

  @override
  String get editorDefaultAllowed => 'Default: allowed';

  @override
  String editorCopiesOnlyCurrentUnitPlayerEditsToPlayers1(String value0) {
    return 'Copies only current Unit #$value0 player edits to Players 1–8. Map defaults are excluded.';
  }

  @override
  String get editorPlayerSettingSource => 'Player setting source';

  @override
  String get editorUsePlayerOverride => 'Use player override';

  @override
  String get editorInheritMapDefault => 'Inherit map default';

  @override
  String get editorStoredPlayerOverride => 'Stored player override';

  @override
  String get editorPlayerProhibited => 'Player: prohibited';

  @override
  String get editorPlayerAllowed => 'Player: allowed';

  @override
  String editorEffectiveAvailability(String value0) {
    return 'Effective availability: $value0';
  }

  @override
  String get editorUnknownStoredFlagsPreserved =>
      'unknown (stored flags preserved)';

  @override
  String
  get editorInheritancePreservesTheStoredOverrideAvailabilityDoesNotBypass =>
      'Inheritance preserves the stored override. Availability does not bypass game prerequisites or create placed units.';

  @override
  String editorPendingChangesApplyUpdatesAllEditedUnitsAndPlayers(
    String value0,
  ) {
    return '$value0 pending changes. Apply updates all edited units and players; Save As writes the map.';
  }

  @override
  String
  get editorLocalWeaponReferencesUnavailableConfigureStarCraftAssetsAndRetry =>
      'Local weapon references unavailable. Configure StarCraft assets and retry.';

  @override
  String editorUnit88a3c859(String value0, String value1) {
    return '$value0\nUnit #$value1';
  }

  @override
  String get editorUnitPreviewRequiresLocalStarCraftGraphics =>
      'Unit preview requires local StarCraft graphics.';

  @override
  String get editorConfigureStarCraftAssetsToLoadUnitLinks =>
      'Configure StarCraft assets to load unit links.';

  @override
  String get editorGround => 'Ground';

  @override
  String get editorAir => 'Air';

  @override
  String editorNone(String value0) {
    return '$value0: None';
  }

  @override
  String editorSubunit(String value0, String value1) {
    return 'Subunit: $value0 (#$value1)';
  }

  @override
  String get editorSubunitWeaponsKeepsTheSelectedUnit =>
      'Subunit weapons — keeps the selected unit';

  @override
  String get editorNoLinkedWeaponSelectAWeaponManually =>
      'No linked weapon. Select a weapon manually.';

  @override
  String editorAutoSelectedFromWeaponChangesAffectAllUnitsSharing(
    String value0,
    String value1,
    String value2,
  ) {
    return 'Auto-selected: $value0 (#$value1) from $value2. Weapon changes affect all units sharing it.';
  }

  @override
  String get editorRetryUnitLinks => 'Retry unit links';

  @override
  String editorUnit24496eb9(String value0, String value1) {
    return 'Unit #$value0: $value1';
  }

  @override
  String editorWeaponDamageMustBeAnIntegerFrom0To(String value0) {
    return 'Weapon #$value0: damage must be an integer from 0 to 65535.';
  }

  @override
  String get editorUnitSettings => 'Unit Settings';

  @override
  String get editorMapWideUnitTypesSeparateFromPlacedUnitProperties =>
      'Map-wide unit types, separate from placed-unit properties.';

  @override
  String editorEditing4dc9e6e6(String value0, String value1) {
    return 'Editing $value0$value1.';
  }

  @override
  String get editorAlternateSectionPreservedWithoutSynchronization =>
      '; alternate section preserved without synchronization';

  @override
  String editorUnit38894196(String value0, String value1) {
    return '$value0 (Unit #$value1)';
  }

  @override
  String get editorUnitValuesNamesAndDefaultFlagsOnlySharedWeapon =>
      'Unit values, names and default flags only. Shared weapon damage uses its own selection below.';

  @override
  String get editorUseCustomValues => 'Use custom values';

  @override
  String editorStoredDefaultFlagPreserved(String value0) {
    return 'Stored default flag $value0 (preserved)';
  }

  @override
  String get editorFieldsShowStoredCustomValuesGameDefaultNumbersAre =>
      'Fields show stored custom values. Game default numbers are not loaded.';

  @override
  String get editorRestoreSelectedUnitDefaults =>
      'Restore selected unit defaults';

  @override
  String get editorUnitNameEmptyGameName => 'Unit name (empty = game name)';

  @override
  String get editorSharedWeaponDamage => 'Shared weapon damage';

  @override
  String get editorAWeaponChangeAffectsEveryUnitUsingThatWeapon =>
      'A weapon change affects every unit using that weapon. Restoring a unit does not reset shared weapon damage.';

  @override
  String get editorWeapon => 'Weapon';

  @override
  String get editorSharedWeaponDamageOnlyAllUnitsReferencingTargetWeapons =>
      'Shared weapon damage only. All units referencing target weapons may be affected.';

  @override
  String get editorDamagePerUpgrade => 'Damage per upgrade';

  @override
  String get editorBaseDamage => 'Base damage';

  @override
  String get editorApplyUpdatesAllEditedUnitTypesAndWeaponsSave =>
      'Apply updates all edited unit types and weapons. Save As writes the map.';

  @override
  String editorUpgrade(String value0, String value1, String value2) {
    return 'Upgrade #$value0, $value1: $value2';
  }

  @override
  String get editorEffectiveLevelsUnknownStoredFlagPreserved =>
      'Effective levels: unknown (stored flag preserved)';

  @override
  String editorEffectiveLevelsStartMaximum(String value0, String value1) {
    return 'Effective levels: $value0 / $value1 (start / maximum)';
  }

  @override
  String get editorUpgradeSettings => 'Upgrade Settings';

  @override
  String get editorUpgraded423b17 => 'Upgrade';

  @override
  String get editorMapDefaultLevels => 'Map default levels';

  @override
  String editorCopiesOnlyCurrentUpgradePlayerEditsToPlayers1(String value0) {
    return 'Copies only current upgrade #$value0 player edits to Players 1–8. Map costs and defaults are excluded.';
  }

  @override
  String get editorUsePlayerLevels => 'Use player levels';

  @override
  String get editorInheritMapLevels => 'Inherit map levels';

  @override
  String
  get editorMapLevelsAffectInheritingPlayersInheritancePreservesStoredPlayer =>
      'Map levels affect inheriting players. Inheritance preserves stored player levels. Starting level must not exceed maximum.';

  @override
  String editorPendingChangesAcrossUpgradesAndPlayersApplyUpdatesThe(
    String value0,
  ) {
    return '$value0 pending changes across upgrades and players. Apply updates the document; Save As writes the map.';
  }

  @override
  String get editorLoadingLocalWeaponReferences =>
      'Loading local weapon references…';

  @override
  String editorWeaponReferenceListUnavailable(String value0) {
    return 'Weapon reference list unavailable: $value0';
  }

  @override
  String get editorSourceChanged => 'source changed';

  @override
  String get editorReloadWeaponReferences => 'Reload weapon references';

  @override
  String get editorNoneInThisDATSnapshot => 'None in this DAT snapshot';

  @override
  String editorWeaponDirectGroundAirReferences(String value0, String value1) {
    return 'Weapon #$value0 — direct ground/air references: $value1';
  }

  @override
  String editorUnitsReferencingThoseSubunits(String value0) {
    return 'Units referencing those subunits: $value0';
  }

  @override
  String editorSource854c792f(String value0) {
    return 'Source: $value0';
  }

  @override
  String get editorDATReferencesOnlySpellsSpawnedProjectilesUnitsAndEUD =>
      'DAT references only. Spells, spawned projectiles/units and EUD runtime changes may have additional effects.';

  @override
  String get editorOpenAMapToManageResources =>
      'Open a map to manage resources.';

  @override
  String get editorResources => 'Resources';

  @override
  String get editorUndo71fd4acf => 'Undo';

  @override
  String get editorRedo7412e5e9 => 'Redo';

  @override
  String get editorAddString => 'Add string';

  @override
  String get editorImportPCMWAV => 'Import PCM WAV';

  @override
  String get editorStopPreview => 'Stop preview';

  @override
  String editorStringsBytesOffsetLimitSaveAsWritesPendingResource(
    String value0,
    String value1,
    String value2,
  ) {
    return '$value0 strings • $value1 bytes • offset limit $value2 • Save As writes pending resource changes.';
  }

  @override
  String get editorReferenceCoverageIncompleteDeletionRestricted =>
      'Reference coverage incomplete — deletion restricted';

  @override
  String
  get editorArchiveListingIncompleteUnlistedSoundsMayExistImportsDeletions =>
      'Archive listing incomplete. Unlisted sounds may exist; imports/deletions are restricted.';

  @override
  String get editorSearchTextStringIDOrSoundPath =>
      'Search text, string ID or sound path';

  @override
  String get editorWorking => 'Working…';

  @override
  String get editorStrings => 'Strings';

  @override
  String get editorSounds => 'Sounds';

  @override
  String get editorInvalidUTF8RawBytesPreserved =>
      'Invalid UTF-8 — raw bytes preserved';

  @override
  String editorBytesKnownUseS(String value0, String value1, String value2) {
    return '$value0 bytes • $value1 known use(s)$value2';
  }

  @override
  String get editorExplicitReplacementRequired =>
      ' • explicit replacement required';

  @override
  String get editorClearUnreferencedString => 'Clear unreferenced string';

  @override
  String editorBytesPendingImport(String value0) {
    return '$value0 bytes • pending import';
  }

  @override
  String get editorReferencedPathNotListedInThisMap =>
      'Referenced path; not listed in this map';

  @override
  String editorBytesLocale(String value0, String value1) {
    return '$value0 bytes • locale $value1';
  }

  @override
  String get editorPreviewSound => 'Preview sound';

  @override
  String get editorExportSound => 'Export sound';

  @override
  String get editorDeleteSound => 'Delete sound';

  @override
  String get editorDeleteSoundf1d564e6 => 'Delete sound?';

  @override
  String editorRemovalAppliesOnSaveAsUndoRestoresThisEdit(String value0) {
    return '$value0\nRemoval applies on Save As. Undo restores this edit.';
  }

  @override
  String get editorDelete => 'Delete';

  @override
  String get editorMapChanged => 'Map changed.';

  @override
  String editorResourcesAreReadOnly(String value0) {
    return 'Resources are read-only: $value0';
  }

  @override
  String get editorInvalidUTF8EnterExplicitReplacementTextOriginalBytes =>
      'Invalid UTF-8. Enter explicit replacement text; original bytes remain until Apply.';

  @override
  String editorString(String value0) {
    return 'String #$value0';
  }

  @override
  String get editorEditSharedIDAffectsAllReferences =>
      'Edit shared ID — affects all references';

  @override
  String editorSeparate(String value0) {
    return 'Separate: $value0';
  }

  @override
  String get editorAdditionalUnknownUsesMayExistNoAutomaticCleanupIs =>
      'Additional unknown uses may exist. No automatic cleanup is performed.';

  @override
  String get editorUTF8Text => 'UTF-8 text';

  @override
  String editorKnownReferences(String value0) {
    return '$value0 known references';
  }

  @override
  String get editorWriteEpScriptHere => '// Write epScript here';

  @override
  String get editorModified => 'Modified';

  @override
  String get editorClean => 'Clean';

  @override
  String get editorInMemoryDraft => 'In-memory draft';

  @override
  String editorLnCol(String value0, String value1) {
    return 'Ln $value0, Col $value1';
  }

  @override
  String editorActionSReferenceThisSlotApplyingChangesAffectsAll(
    String value0,
  ) {
    return '$value0 action(s) reference this slot. Applying changes affects all of them.';
  }

  @override
  String editorNewStringIDUseThisIDInATrigger(String value0) {
    return 'New string ID: $value0. Use this ID in a trigger action.';
  }

  @override
  String get editorAddTriggerText => 'Add trigger text';

  @override
  String get editorSwitchNames => 'Switch names';

  @override
  String get editorUnitPropertySlots => 'Unit property slots';

  @override
  String editorID(String value0, String value1) {
    return '$value0 ID $value1';
  }

  @override
  String get editorProperty => 'Property';

  @override
  String get editorSwitch => 'Switch';

  @override
  String get editorText => 'Text';

  @override
  String get editorUncheckedValuesInheritTheGameDefaultSpecialStatesCan =>
      'Unchecked values inherit the game default. Special states can inherit, enable or disable.';

  @override
  String get editorInherit => 'Inherit';

  @override
  String get editorEnabled => 'Enabled';

  @override
  String get editorDisabled => 'Disabled';

  @override
  String get editorPrepareChanges => 'Prepare changes';

  @override
  String get editorApplyToMap => 'Apply to map';

  @override
  String get editorYes => 'yes';

  @override
  String get editorNo => 'no';

  @override
  String get editorUnknown => 'unknown';

  @override
  String get editorAllowed => 'allowed';

  @override
  String get editorProhibited => 'prohibited';

  @override
  String get editorMapdfa2efb1 => 'map';

  @override
  String editorTheCHKSectionHeaderIsTruncatedAtByteOffset(String value0) {
    return 'The CHK section header is truncated at byte offset $value0.';
  }

  @override
  String get editorUseAnIntactScenarioChkOrOpenTheMap =>
      'Use an intact scenario.chk or open the map as read-only.';

  @override
  String editorSectionDeclaresBytesButOnlyBytesRemain(
    String value0,
    String value1,
    String value2,
  ) {
    return 'Section \"$value0\" declares $value1 bytes, but only $value2 bytes remain.';
  }

  @override
  String editorSectionMustContainExactlyPayloadBytesButContains(
    String value0,
    String value1,
    String value2,
  ) {
    return 'Section \"$value0\" must contain exactly $value1 payload bytes, but contains $value2.';
  }

  @override
  String get editorKeepThisSectionUnchangedAndTreatTheMapAs =>
      'Keep this section unchanged and treat the map as read-only.';

  @override
  String editorIsOutsideTheMapPixelBounds(String value0, String value1) {
    return '$value0 $value1 is outside the map pixel bounds.';
  }

  @override
  String editorMoveTheObjectInside0By0OrKeep(String value0, String value1) {
    return 'Move the object inside 0..$value0 by 0..$value1, or keep the raw record unchanged if the value is intentional EUD data.';
  }

  @override
  String editorRefersToPlayerValueOutsideTheSupported011(
    String value0,
    String value1,
    String value2,
  ) {
    return '$value0 $value1 refers to player value $value2, outside the supported 0..11 range.';
  }

  @override
  String get editorChoosePlayer1ThroughPlayer12OrKeepThe =>
      'Choose Player 1 through Player 12, or keep the raw value unchanged if it is intentional EUD data.';

  @override
  String editorLocationDoesNotFormAValidRectangleInsideThe(String value0) {
    return 'Location $value0 does not form a valid rectangle inside the map.';
  }

  @override
  String editorUseLeftRightAndTopBottomInside0By(String value0, String value1) {
    return 'Use left < right and top < bottom inside 0..$value0 by 0..$value1, or preserve the raw value if intentional.';
  }

  @override
  String editorUsesStringIDButMultipleSTRSTRxTablesMake(
    String value0,
    String value1,
  ) {
    return '$value0 uses string ID $value1, but multiple STR/STRx tables make the reference ambiguous.';
  }

  @override
  String get editorInspectTheRawStringSectionsTheEditorWillNot =>
      'Inspect the raw string sections; the editor will not guess an active table.';

  @override
  String editorUsesStringIDButNoReadableSTRSTRxTable(
    String value0,
    String value1,
  ) {
    return '$value0 uses string ID $value1, but no readable STR/STRx table is available.';
  }

  @override
  String get editorInspectTheRawStringTableBeforeChangingThisReference =>
      'Inspect the raw string table before changing this reference.';

  @override
  String editorUsesStringIDButTheTableContainsOnlyEntries(
    String value0,
    String value1,
    String value2,
  ) {
    return '$value0 uses string ID $value1, but the table contains only $value2 entries.';
  }

  @override
  String get editorChooseAnExistingStringIDOrClearTheReference =>
      'Choose an existing string ID or clear the reference to ID 0.';

  @override
  String editorUsesStringIDWhoseRawEntryCannotBeResolved(
    String value0,
    String value1,
  ) {
    return '$value0 uses string ID $value1, whose raw entry cannot be resolved safely.';
  }

  @override
  String get editorInspectTheStringTableStructuralDiagnosticsAndPreserveThe =>
      'Inspect the string table structural diagnostics and preserve the raw reference until the source is understood.';

  @override
  String editorSectionEndsWithAnIncompleteByteRecord(
    String value0,
    String value1,
    String value2,
  ) {
    return 'Section \"$value0\" ends with an incomplete $value1-byte $value2 record.';
  }

  @override
  String get editorKeepThisObjectSectionUnchangedAndReadOnly =>
      'Keep this object section unchanged and read-only.';

  @override
  String editorSectionMustContainEither64Or255CompleteLocation(String value0) {
    return 'Section \"$value0\" must contain either 64 or 255 complete location records.';
  }

  @override
  String get editorKeepThisLocationSectionUnchangedAndReadOnly =>
      'Keep this location section unchanged and read-only.';

  @override
  String editorSectionDoesNotContainItsCompleteByteStringCount(
    String value0,
    String value1,
  ) {
    return 'Section \"$value0\" does not contain its complete $value1-byte string count.';
  }

  @override
  String get editorKeepThisStringTableUnchangedAndReadOnly =>
      'Keep this string table unchanged and read-only.';

  @override
  String editorSectionDeclaresStringsButItsOffsetTableExceedsThe(
    String value0,
    String value1,
  ) {
    return 'Section \"$value0\" declares $value1 strings, but its offset table exceeds the payload.';
  }

  @override
  String editorStringInSectionPointsOutsideThePayload(
    String value0,
    String value1,
  ) {
    return 'String $value0 in section \"$value1\" points outside the payload.';
  }

  @override
  String editorStringInSectionPointsIntoTheCountOrOffset(
    String value0,
    String value1,
  ) {
    return 'String $value0 in section \"$value1\" points into the count or offset table.';
  }

  @override
  String editorStringInSectionHasNoNullTerminatorBeforeThe(
    String value0,
    String value1,
  ) {
    return 'String $value0 in section \"$value1\" has no null terminator before the payload ends.';
  }

  @override
  String editorSectionEndsWithAnIncomplete2ByteTileRecord(String value0) {
    return 'Section \"$value0\" ends with an incomplete 2-byte tile record.';
  }

  @override
  String get editorKeepThisTerrainSectionUnchangedAndReadOnly =>
      'Keep this terrain section unchanged and read-only.';

  @override
  String editorSectionContainsTilesButXMapDimensionsRequire(
    String value0,
    String value1,
    String value2,
    String value3,
    String value4,
  ) {
    return 'Section \"$value0\" contains $value1 tiles, but ${value2}x$value3 map dimensions require $value4.';
  }

  @override
  String get editorRecoveryOpened => 'Recovery opened';

  @override
  String get editorOnlyScmAndScxMapFilesCanBeOpened =>
      'Only .scm and .scx map files can be opened.';

  @override
  String get editorChooseAStarCraftMapWithAScmOrScx =>
      'Choose a StarCraft map with a .scm or .scx extension.';

  @override
  String get editorAnotherEditorOperationIsAlreadyRunning =>
      'Another editor operation is already running.';

  @override
  String get editorWaitForTheCurrentOperationToFinishAndTry =>
      'Wait for the current operation to finish and try again.';

  @override
  String get editorReadingMapArchive => 'Reading map archive';

  @override
  String get editorFingerprintingSourceMap => 'Fingerprinting source map';

  @override
  String get editorParsingScenarioChk => 'Parsing scenario.chk';

  @override
  String get editorValidatingMapMetadata => 'Validating map metadata';

  @override
  String get editorTheSourceMapChangedWhileItWasBeingOpened =>
      'The source map changed while it was being opened.';

  @override
  String get editorCloseTheOtherProgramThatIsEditingTheMap =>
      'Close the other program that is editing the map and open it again.';

  @override
  String get editorTheMapOpenedButTheRecentMapsListWas =>
      'The map opened, but the recent maps list was not updated.';

  @override
  String get editorCheckAccessToTheApplicationSettingsFolderAndReopen =>
      'Check access to the application settings folder and reopen the map.';

  @override
  String get editorMapOpenedInRestrictedReadOnlyMode =>
      'Map opened in restricted read-only mode';

  @override
  String get editorMapOpened => 'Map opened';

  @override
  String get editorTheMapCouldNotBeOpenedBecauseOfAn =>
      'The map could not be opened because of an unexpected error.';

  @override
  String get editorRetryTheOperationIfItFailsAgainInspectThe =>
      'Retry the operation. If it fails again, inspect the application log.';

  @override
  String get editorTheMapWasSavedButTheRecentMapsList =>
      'The map was saved, but the recent maps list was not updated.';

  @override
  String get editorCheckAccessToTheApplicationSettingsFolderAndReopen915aeaa0 =>
      'Check access to the application settings folder and reopen the saved map.';

  @override
  String get editorTheMapFileDialogCouldNotBeOpened =>
      'The map file dialog could not be opened.';

  @override
  String get editorRetryTheOperationOrRestartTheApplication =>
      'Retry the operation or restart the application.';

  @override
  String get editorTheSourceMapFingerprintCouldNotBeVerified =>
      'The source map fingerprint could not be verified.';

  @override
  String get editorCheckThatTheMapStillExistsIsReadableAnd =>
      'Check that the map still exists, is readable, and is not being changed by another program.';

  @override
  String get editorOpenAMapBeforeUsingSaveAs =>
      'Open a map before using Save As.';

  @override
  String get editorOpenAScmOrScxMapAndTryAgain =>
      'Open a .scm or .scx map and try again.';

  @override
  String editorEditedContainInvalidFieldValuesOrReferences(String value0) {
    return 'Edited $value0 contain invalid field values or references.';
  }

  @override
  String editorOpenValidateReferencesAndCorrectTheReportedSlots(String value0) {
    return 'Open $value0 → Validate references and correct the reported slots.';
  }

  @override
  String get editorBriefing => 'Briefing';

  @override
  String get editorTriggers => 'Triggers';

  @override
  String get editorTheSaveAsDestinationMustBeAnAbsoluteWindows =>
      'The Save As destination must be an absolute Windows path.';

  @override
  String get editorChooseTheDestinationUsingTheSaveAsDialog =>
      'Choose the destination using the Save As dialog.';

  @override
  String get editorNewBroodWarMapsMustBeSavedAsScx =>
      'New Brood War maps must be saved as .scx.';

  @override
  String get editorSaveAsSupportsOnlyScmAndScxMapFiles =>
      'Save As supports only .scm and .scx map files.';

  @override
  String get editorChooseADestinationEndingInScx =>
      'Choose a destination ending in .scx.';

  @override
  String get editorChooseADestinationEndingInScmOrScx =>
      'Choose a destination ending in .scm or .scx.';

  @override
  String get editorSaveAsCannotOverwriteTheCurrentlyOpenSourceMap =>
      'Save As cannot overwrite the currently open source map.';

  @override
  String get editorChooseADifferentOutputFileName =>
      'Choose a different output file name.';

  @override
  String get editorTheSaveAsDestinationAlreadyExists =>
      'The Save As destination already exists.';

  @override
  String get editorChooseANewFileNameOrExplicitlyConfirmReplacement =>
      'Choose a new file name or explicitly confirm replacement in the Save As dialog.';

  @override
  String get editorPreparingNewMap => 'Preparing new map';

  @override
  String get editorCheckingSourceMap => 'Checking source map';

  @override
  String get editorValidatingNewMap => 'Validating new map';

  @override
  String get editorCheckingSourceMapFingerprint =>
      'Checking source map fingerprint';

  @override
  String get editorTheSourceMapChangedAfterItWasOpenedSo =>
      'The source map changed after it was opened, so Save As was stopped.';

  @override
  String get editorReopenTheSourceMapToReviewTheExternalChanges =>
      'Reopen the source map to review the external changes before saving.';

  @override
  String get editorCheckingExistingDestinationFingerprint =>
      'Checking existing destination fingerprint';

  @override
  String get editorATemporarySaveAsWorkspaceCouldNotBeCreated =>
      'A temporary Save As workspace could not be created.';

  @override
  String get editorCheckDestinationFolderPermissionsAndFreeDiskSpace =>
      'Check destination folder permissions and free disk space.';

  @override
  String get editorWritingTemporaryMapArchive =>
      'Writing temporary map archive';

  @override
  String get editorReopeningAndVerifyingTemporaryMap =>
      'Reopening and verifying temporary map';

  @override
  String get editorTheReopenedTemporaryMapDoesNotContainTheExpected =>
      'The reopened temporary map does not contain the expected scenario.chk bytes.';

  @override
  String get editorKeepTheSourceMapUnchangedAndReportTheArchive =>
      'Keep the source map unchanged and report the archive writer failure.';

  @override
  String get editorTheReopenedTemporaryMapFailedCHKValidation =>
      'The reopened temporary map failed CHK validation.';

  @override
  String get editorKeepTheSourceMapUnchangedAndInspectParserDiagnostics =>
      'Keep the source map unchanged and inspect parser diagnostics.';

  @override
  String get editorFingerprintingVerifiedOutput =>
      'Fingerprinting verified output';

  @override
  String get editorTheVerifiedTemporaryMapFingerprintCouldNotBeCalculated =>
      'The verified temporary map fingerprint could not be calculated.';

  @override
  String get editorRecheckingSourceMapFingerprint =>
      'Rechecking source map fingerprint';

  @override
  String get editorTheSourceMapChangedDuringSaveAsSoThe =>
      'The source map changed during Save As, so the verified output was not promoted.';

  @override
  String get editorReopenTheSourceMapToReviewTheExternalChangesf53fd806 =>
      'Reopen the source map to review the external changes and retry with a new output name.';

  @override
  String get editorRecheckingSaveAsDestination =>
      'Rechecking Save As destination';

  @override
  String get editorPromotingVerifiedMapToFinalDestination =>
      'Promoting verified map to final destination';

  @override
  String get editorTheExistingDestinationIsSafeInABackupBut =>
      'The existing destination is safe in a backup, but automatic restoration failed.';

  @override
  String editorRestoreTheBackupToBeforeRetryingSaveAs(String value0) {
    return 'Restore the backup to $value0 before retrying Save As.';
  }

  @override
  String get editorTheVerifiedMapCouldNotBePromotedToIts =>
      'The verified map could not be promoted to its destination.';

  @override
  String get editorCheckDestinationFolderPermissionsAndChooseANewName =>
      'Check destination folder permissions and choose a new name.';

  @override
  String get editorThePreviousDestinationWasPreservedAsARecoveryBackup =>
      'The previous destination was preserved as a recovery backup.';

  @override
  String get editorKeepTheBackupUntilTheReplacementMapHasBeen =>
      'Keep the backup until the replacement map has been verified.';

  @override
  String get editorMapSavedAndVerified => 'Map saved and verified';

  @override
  String get editorMapSavedVerifiedAndBackedUp =>
      'Map saved, verified, and backed up';

  @override
  String get editorSaveAsFailedBecauseOfAnUnexpectedError =>
      'Save As failed because of an unexpected error.';

  @override
  String get editorRetryWithANewOutputNameTheSourceMap =>
      'Retry with a new output name. The source map was not modified.';

  @override
  String get editorTheSaveAsDialogCouldNotBeOpened =>
      'The Save As dialog could not be opened.';

  @override
  String get editorCheckThatTheSourceMapStillExistsIsReadable =>
      'Check that the source map still exists, is readable, and is not being changed by another program.';

  @override
  String get editorTheExistingSaveAsDestinationCouldNotBeVerified =>
      'The existing Save As destination could not be verified.';

  @override
  String get editorCheckThatTheDestinationIsAReadableRegularFile =>
      'Check that the destination is a readable regular file and retry.';

  @override
  String get editorTheSaveAsDestinationChangedWhileTheMapWas =>
      'The Save As destination changed while the map was being prepared.';

  @override
  String get editorReviewTheDestinationInAnotherProgramThenRetryAnd =>
      'Review the destination in another program, then retry and confirm replacement again.';

  @override
  String get editorWaitingForEuddraftToStart => 'Waiting for euddraft to start';

  @override
  String get editorTheEuddraftEventStreamFailedUnexpectedly =>
      'The euddraft event stream failed unexpectedly.';

  @override
  String get editorTheEuddraftBuildCouldNotBeStarted =>
      'The euddraft build could not be started.';

  @override
  String get editorStoppingEuddraft => 'Stopping euddraft';

  @override
  String get editorTheEUDBuildCancellationRequestFailed =>
      'The EUD build cancellation request failed.';

  @override
  String get editorEuddraftIsStillRunning => 'euddraft is still running';

  @override
  String get editorEuddraftReturnedAnEventForADifferentBuild =>
      'euddraft returned an event for a different build.';

  @override
  String editorEuddraftIsRunning(String value0) {
    return 'euddraft $value0 is running';
  }

  @override
  String get editorValidatingAndPromotingTheGeneratedEUDMap =>
      'Validating and promoting the generated EUD map';

  @override
  String get editorEUDBuildWasCancelled => 'EUD build was cancelled';

  @override
  String get editorEUDBuildFailed => 'EUD build failed';

  @override
  String get editorEUDMapBuiltVerifiedAndPromoted =>
      'EUD map built, verified, and promoted';

  @override
  String get editorTheEuddraftEventStreamEndedWithoutAResult =>
      'The euddraft event stream ended without a result.';

  @override
  String get editorInspectTheBuildLogAndRetry =>
      'Inspect the build log and retry.';

  @override
  String get editorABuildWithThisIDIsAlreadyActive =>
      'A build with this ID is already active.';

  @override
  String get editorWaitForTheActiveBuildToFinishAndRetry =>
      'Wait for the active build to finish and retry.';

  @override
  String get editorTheEUDBuildInputsAreNotSafeRegularFiles =>
      'The EUD build inputs are not safe regular files.';

  @override
  String get editorCheckTheBaseMapSourceRootEntrySourceAnd =>
      'Check the base map, source root, entry source, and output folder.';

  @override
  String get editorTheEUDOutputResolvesToTheBaseMap =>
      'The EUD output resolves to the base map.';

  @override
  String get editorChooseASeparateOutputFile =>
      'Choose a separate output file.';

  @override
  String get editorTheEUDBaseMapFingerprintCouldNotBeCalculated =>
      'The EUD base map fingerprint could not be calculated.';

  @override
  String get editorTheBaseMapDoesNotMatchTheEUDProject =>
      'The base map does not match the EUD project binding.';

  @override
  String get editorOpenAndVerifyTheBoundMapThenPrepareAgain =>
      'Open and verify the bound map, then prepare again.';

  @override
  String get editorTheEpScriptEntrySourceFingerprintCouldNotBeCalculated =>
      'The epScript entry source fingerprint could not be calculated.';

  @override
  String get editorTheEUDOutputAlreadyExists =>
      'The EUD output already exists.';

  @override
  String get editorChooseANewOutputOrExplicitlyConfirmReplacement =>
      'Choose a new output or explicitly confirm replacement.';

  @override
  String get editorTheExistingEUDOutputFingerprintCouldNotBeCalculated =>
      'The existing EUD output fingerprint could not be calculated.';

  @override
  String get editorTheTemporaryEUDBuildWorkspaceCouldNotBeCreated =>
      'The temporary EUD build workspace could not be created.';

  @override
  String get editorCheckOutputFolderPermissionsAndAvailableDiskSpace =>
      'Check output folder permissions and available disk space.';

  @override
  String get editorEuddraftExitedSuccessfullyButDidNotCreateAReadable =>
      'euddraft exited successfully but did not create a readable temporary map.';

  @override
  String get editorEuddraftExitedSuccessfullyButCreatedAnEmptyTemporaryMap =>
      'euddraft exited successfully but created an empty temporary map.';

  @override
  String get editorInspectTheEuddraftOutputAndEpScriptSource =>
      'Inspect the euddraft output and epScript source.';

  @override
  String get editorTheTemporaryEUDOutputIsNotAReadableMap =>
      'The temporary EUD output is not a readable map archive.';

  @override
  String get editorInspectTheEuddraftLogAndKeepTheBaseMap =>
      'Inspect the euddraft log and keep the base map unchanged.';

  @override
  String get editorTheTemporaryEUDOutputContainsAnInvalidCHK =>
      'The temporary EUD output contains an invalid CHK.';

  @override
  String get editorTheTemporaryEUDOutputFailedCHKMetadataValidation =>
      'The temporary EUD output failed CHK metadata validation.';

  @override
  String get editorInspectTheMapValidationDiagnosticsAndEuddraftLog =>
      'Inspect the map validation diagnostics and euddraft log.';

  @override
  String get editorTheTemporaryEUDOutputIsMissingRequiredVERDIM =>
      'The temporary EUD output is missing required VER, DIM, or ERA map metadata.';

  @override
  String get editorUseAnIntactStarCraftMapAsTheEUDBase =>
      'Use an intact StarCraft map as the EUD base map.';

  @override
  String get editorTheEUDBaseMapFingerprintCouldNotBeRechecked =>
      'The EUD base map fingerprint could not be rechecked.';

  @override
  String get editorTheBaseMapChangedDuringTheEUDBuildSo =>
      'The base map changed during the EUD build, so the output was not promoted.';

  @override
  String get editorReviewTheBaseMapChangesAndRebuild =>
      'Review the base map changes and rebuild.';

  @override
  String get editorTheEpScriptEntryFingerprintCouldNotBeRechecked =>
      'The epScript entry fingerprint could not be rechecked.';

  @override
  String get editorTheEpScriptEntryChangedDuringTheEUDBuildSo =>
      'The epScript entry changed during the EUD build, so the output was not promoted.';

  @override
  String get editorSaveTheSourceChangesAndRebuild =>
      'Save the source changes and rebuild.';

  @override
  String get editorThePreviousEUDOutputIsSafeInABackup =>
      'The previous EUD output is safe in a backup, but automatic restoration failed.';

  @override
  String editorRestoreTheBackupToBeforeBuildingAgain(String value0) {
    return 'Restore the backup to $value0 before building again.';
  }

  @override
  String get editorTheVerifiedEUDMapCouldNotBePromotedTo =>
      'The verified EUD map could not be promoted to its output.';

  @override
  String get editorCheckOutputFolderPermissionsAndChooseANewName =>
      'Check output folder permissions and choose a new name.';

  @override
  String get editorThePreviousEUDOutputWasPreservedAsARecovery =>
      'The previous EUD output was preserved as a recovery backup.';

  @override
  String get editorKeepTheBackupUntilTheGeneratedMapHasBeen =>
      'Keep the backup until the generated map has been tested.';

  @override
  String get editorTheSafeEUDBuildPipelineFailedUnexpectedly =>
      'The safe EUD build pipeline failed unexpectedly.';

  @override
  String get editorTheTemporaryEUDBuildWorkspaceWasNotRemoved =>
      'The temporary EUD build workspace was not removed.';

  @override
  String get editorCloseProcessesUsingTheFolderThenRemoveItManually =>
      'Close processes using the folder, then remove it manually.';

  @override
  String get editorMapSourceOrEUDProjectChangedPrepareTheBuild =>
      'Map, source or EUD project changed. Prepare the build again.';

  @override
  String get editorSaveAndVerifyTheCurrentInputsThenPrepareAgain =>
      'Save and verify the current inputs, then prepare again.';

  @override
  String get editorTheSelectedEuddraftInstallationCouldNotBeRechecked =>
      'The selected euddraft installation could not be rechecked.';

  @override
  String get editorInspectTheToolAndPrepareANewBuild =>
      'Inspect the tool and prepare a new build.';

  @override
  String get editorTheSelectedEuddraftInstallationChangedOrIsNotReady =>
      'The selected euddraft installation changed or is not ready.';

  @override
  String get editorCheckThatTheFileIsReadableAndIsNot =>
      'Check that the file is readable and is not changing.';

  @override
  String get editorTheExistingEUDOutputCouldNotBeRechecked =>
      'The existing EUD output could not be rechecked.';

  @override
  String get editorTheEUDOutputChangedWhileTheMapWasBeing =>
      'The EUD output changed while the map was being built, so the temporary output was not promoted.';

  @override
  String get editorReviewTheOtherProgramUsingTheOutputAndRebuild =>
      'Review the other program using the output and rebuild.';

  @override
  String get editorTheObjectCatalogRequestFailedUnexpectedly =>
      'The object catalog request failed unexpectedly.';

  @override
  String get editorRetryOrRepairTheApplicationInstallation =>
      'Retry or repair the application installation.';

  @override
  String get editorTheObjectThumbnailRequestFailedUnexpectedly =>
      'The object thumbnail request failed unexpectedly.';

  @override
  String get editorTheObjectCatalogRequestIsNoLongerCurrent =>
      'The object catalog request is no longer current.';

  @override
  String get editorLoadTheCurrentlySelectedCatalog =>
      'Load the currently selected catalog.';

  @override
  String get editorTheObjectCatalogAndThumbnailResultsDidNotMatch =>
      'The object catalog and thumbnail results did not match.';

  @override
  String get editorRepairTheApplicationOrReportTheHelperError =>
      'Repair the application or report the helper error.';

  @override
  String get editorTheStarCraftObjectAtlasRequestFailedUnexpectedly =>
      'The StarCraft object atlas request failed unexpectedly.';

  @override
  String get editorTheStarCraftObjectAtlasResultDidNotMatchIts =>
      'The StarCraft object atlas result did not match its batch.';

  @override
  String get editorOpenAMapBeforeBrowsingThePlacementCatalog =>
      'Open a map before browsing the placement catalog.';

  @override
  String get editorSetTheStarCraftRemasteredDataFolderInSettingsFirst =>
      'Set the StarCraft: Remastered data folder in settings first.';

  @override
  String get editorTheMapNeedsExactlyOneERASectionWithA =>
      'The map needs exactly one ERA section with a known tileset.';

  @override
  String get editorTheCatalogChangedOrReturnedOverlappingPagesSelectThe =>
      'The catalog changed or returned overlapping pages. Select the catalog kind again to reload.';

  @override
  String get editorThePlacementCatalogIsUnavailableInThisBuild =>
      'The placement catalog is unavailable in this build.';

  @override
  String get editorStarCraftDataAssetSettingsCouldNotBeLoaded =>
      'StarCraft data asset settings could not be loaded.';

  @override
  String get editorCheckAccessToTheApplicationSettingsFolderAndRetry =>
      'Check access to the application settings folder and retry.';

  @override
  String get editorTheStarCraftInstallationFolderPickerCouldNotBeOpened =>
      'The StarCraft installation folder picker could not be opened.';

  @override
  String get editorRetryOrCheckWindowsDialogPermissions =>
      'Retry or check Windows dialog permissions.';

  @override
  String get editorTheStarCraftInstallationPathCouldNotBeSaved =>
      'The StarCraft installation path could not be saved.';

  @override
  String get editorTheStarCraftInstallationPathCouldNotBeCleared =>
      'The StarCraft installation path could not be cleared.';

  @override
  String get editorTheStarCraftCASCStorageCouldNotBeInspected =>
      'The StarCraft CASC storage could not be inspected.';

  @override
  String get editorCheckDirectoryAccessAndRetry =>
      'Check directory access and retry.';

  @override
  String get editorTheStarCraftInstallationIsNotConfigured =>
      'The StarCraft installation is not configured.';

  @override
  String get editorOpenSettingsAndChooseTheStarCraftInstallationDirectory =>
      'Open Settings and choose the StarCraft installation directory.';

  @override
  String get editorTheStarCraftTileAtlasRequestFailedUnexpectedly =>
      'The StarCraft tile atlas request failed unexpectedly.';

  @override
  String get editorTheStarCraftTileAtlasResultDidNotMatchIts =>
      'The StarCraft tile atlas result did not match its batch.';

  @override
  String get editorTheTileCatalogRequestFailedUnexpectedly =>
      'The Tile catalog request failed unexpectedly.';

  @override
  String get editorTheTileThumbnailRequestFailedUnexpectedly =>
      'The Tile thumbnail request failed unexpectedly.';

  @override
  String get editorTheTileCatalogRequestIsNoLongerCurrent =>
      'The Tile catalog request is no longer current.';

  @override
  String get editorTheTileCatalogAndThumbnailResultsDidNotMatch =>
      'The Tile catalog and thumbnail results did not match.';

  @override
  String get editorTheMapPathMustBeAnAbsoluteWindowsPath =>
      'The map path must be an absolute Windows path.';

  @override
  String get editorChooseTheMapAgainUsingTheOpenMapDialog =>
      'Choose the map again using the Open Map dialog.';

  @override
  String get editorAnArchiveOperationWithTheSameIDIsAlready =>
      'An archive operation with the same ID is already active.';

  @override
  String get editorWaitForTheActiveOperationOrCancelItFirst =>
      'Wait for the active operation or cancel it first.';

  @override
  String get editorTheBundledMapArchiveHelperIsMissing =>
      'The bundled map archive helper is missing.';

  @override
  String get editorRepairOrReinstallTheApplication =>
      'Repair or reinstall the application.';

  @override
  String get editorATemporaryArchiveWorkspaceCouldNotBeCreated =>
      'A temporary archive workspace could not be created.';

  @override
  String get editorCheckFreeDiskSpaceAndTemporaryFolderPermissions =>
      'Check free disk space and temporary folder permissions.';

  @override
  String get editorTheMapArchiveHelperTimedOut =>
      'The map archive helper timed out.';

  @override
  String get editorRetryTheOperationOrInspectTheMapForCorruption =>
      'Retry the operation or inspect the map for corruption.';

  @override
  String get editorTheMapArchiveOperationWasCancelled =>
      'The map archive operation was cancelled.';

  @override
  String get editorOpenTheMapAgainWhenReady => 'Open the map again when ready.';

  @override
  String get editorTheMapArchiveHelperProducedTooMuchOutput =>
      'The map archive helper produced too much output.';

  @override
  String get editorRepairTheApplicationOrReportTheHelperFailure =>
      'Repair the application or report the helper failure.';

  @override
  String get editorScenarioChkExceedsTheConfiguredExtractionSizeLimit =>
      'scenario.chk exceeds the configured extraction size limit.';

  @override
  String get editorRaiseTheReviewedSizeLimitOnlyForATrusted =>
      'Raise the reviewed size limit only for a trusted map.';

  @override
  String get editorTheExtractedScenarioChkCouldNotBeRead =>
      'The extracted scenario.chk could not be read.';

  @override
  String get editorRetryTheOperationAndCheckTemporaryDiskAccess =>
      'Retry the operation and check temporary disk access.';

  @override
  String get editorTheExtractedScenarioChkDoesNotMatchHelperMetadata =>
      'The extracted scenario.chk does not match helper metadata.';

  @override
  String get editorTheMapArchiveHelperCouldNotBeStarted =>
      'The map archive helper could not be started.';

  @override
  String get editorTheMapArchiveHelperReturnedAnInvalidResponse =>
      'The map archive helper returned an invalid response.';

  @override
  String get editorTheSourceMapPathMustBeAnAbsoluteWindows =>
      'The source map path must be an absolute Windows path.';

  @override
  String get editorOpenTheSourceMapAgainUsingTheOpenMap =>
      'Open the source map again using the Open Map dialog.';

  @override
  String get editorTheTemporaryOutputPathMustBeAnAbsoluteWindows =>
      'The temporary output path must be an absolute Windows path.';

  @override
  String get editorCreateTheSaveAsWorkspaceAgain =>
      'Create the Save As workspace again.';

  @override
  String get editorTheSourceMapCannotBeUsedAsTemporaryOutput =>
      'The source map cannot be used as temporary output.';

  @override
  String get editorChooseADifferentSaveAsDestination =>
      'Choose a different Save As destination.';

  @override
  String get editorTheTemporaryArchiveOutputAlreadyExists =>
      'The temporary archive output already exists.';

  @override
  String get editorCreateAFreshSaveAsWorkspaceAndRetry =>
      'Create a fresh Save As workspace and retry.';

  @override
  String get editorTheTemporarySaveAsWorkspaceDoesNotExist =>
      'The temporary Save As workspace does not exist.';

  @override
  String get editorTheTemporarySaveAsWorkspaceCouldNotBeInspected =>
      'The temporary Save As workspace could not be inspected.';

  @override
  String get editorCheckDestinationFolderPermissionsAndRetry =>
      'Check destination folder permissions and retry.';

  @override
  String get editorTheTemporaryScenarioInputPathAlreadyExists =>
      'The temporary scenario input path already exists.';

  @override
  String get editorTheTemporaryArchiveWriterTimedOut =>
      'The temporary archive writer timed out.';

  @override
  String get editorTheMapArchiveWriteWasCancelled =>
      'The map archive write was cancelled.';

  @override
  String get editorRunSaveAsAgainWhenReady => 'Run Save As again when ready.';

  @override
  String get editorTheHelperReportedAnUnexpectedScenarioChkSize =>
      'The helper reported an unexpected scenario.chk size.';

  @override
  String get editorTheHelperDidNotCreateTheTemporaryMapArchive =>
      'The helper did not create the temporary map archive.';

  @override
  String get editorRetrySaveAsOrRepairTheApplication =>
      'Retry Save As or repair the application.';

  @override
  String get editorTheTemporaryMapArchiveCouldNotBeInspected =>
      'The temporary map archive could not be inspected.';

  @override
  String get editorTheTemporaryMapSizeDoesNotMatchHelperMetadata =>
      'The temporary map size does not match helper metadata.';

  @override
  String get editorTheTemporaryScenarioInputCouldNotBeWritten =>
      'The temporary scenario input could not be written.';

  @override
  String get editorTheArchiveEntryListingIsIncomplete =>
      'The archive entry listing is incomplete.';

  @override
  String get editorEditingCanContinueButVerifyProtectedOrUnnamedEntries =>
      'Editing can continue, but verify protected or unnamed entries before saving.';

  @override
  String get editorSomeArchiveEntryNamesWereRecoveredSynthetically =>
      'Some archive entry names were recovered synthetically.';

  @override
  String get editorTreatSyntheticNamesAsDiagnosticLabelsNotOriginalPaths =>
      'Treat synthetic names as diagnostic labels, not original paths.';

  @override
  String get editorTheArchiveContainsDuplicateEntryPaths =>
      'The archive contains duplicate entry paths.';

  @override
  String get editorReviewLocaleVariantsAndDuplicateEntriesBeforeSaving =>
      'Review locale variants and duplicate entries before saving.';

  @override
  String get editorTheMapUsesAnUnexpectedMPQFormatVersion =>
      'The map uses an unexpected MPQ format version.';

  @override
  String get editorUseSaveAsAndReOpenTheOutputBefore =>
      'Use Save As and re-open the output before replacing any map.';

  @override
  String get editorTheArchiveContainsEncryptedEntries =>
      'The archive contains encrypted entries.';

  @override
  String get editorEncryptedEntriesAreReportedWithoutAttemptingRecovery =>
      'Encrypted entries are reported without attempting recovery.';

  @override
  String get editorTheStarCraftInstallationPathMustBeAnAbsoluteWindows =>
      'The StarCraft installation path must be an absolute Windows drive or UNC directory.';

  @override
  String get editorChooseTheStarCraftInstallationUsingTheSettingsDialog =>
      'Choose the StarCraft installation using the Settings dialog.';

  @override
  String get editorTheBundledStarCraftCASCHelperIsMissing =>
      'The bundled StarCraft CASC helper is missing.';

  @override
  String get editorTheStarCraftCASCInspectionTimedOut =>
      'The StarCraft CASC inspection timed out.';

  @override
  String get editorRetryAfterRepairingTheStarCraftInstallationInBattleNet =>
      'Retry after repairing the StarCraft installation in Battle.net.';

  @override
  String get editorTheStarCraftCASCHelperProducedTooMuchOutput =>
      'The StarCraft CASC helper produced too much output.';

  @override
  String get editorTheStarCraftCASCHelperCouldNotBeStarted =>
      'The StarCraft CASC helper could not be started.';

  @override
  String get editorTheStarCraftInstallationCouldNotBeInspected =>
      'The StarCraft installation could not be inspected.';

  @override
  String get editorCheckDirectoryPermissionsAndRetry =>
      'Check directory permissions and retry.';

  @override
  String editorRequiredStarCraftCASCTilesetMissing(
    String value0,
    String value1,
  ) {
    return '$value0 required StarCraft CASC tileset $value1 missing.';
  }

  @override
  String get editorAssetIs => 'asset is';

  @override
  String get editorAssetsAre => 'assets are';

  @override
  String get editorRepairTheStarCraftInstallationInBattleNetAndRetry =>
      'Repair the StarCraft installation in Battle.net and retry.';

  @override
  String editorRequiredStarCraftCASCTilesetUnreadable(
    String value0,
    String value1,
  ) {
    return '$value0 required StarCraft CASC tileset $value1 unreadable.';
  }

  @override
  String get editorTheStarCraftCASCHelperReturnedAnInvalidResponse =>
      'The StarCraft CASC helper returned an invalid response.';

  @override
  String get editorTheStarCraftInstallationPathIsInvalid =>
      'The StarCraft installation path is invalid.';

  @override
  String get editorChooseTheStarCraftInstallationFolderAgain =>
      'Choose the StarCraft installation folder again.';

  @override
  String get editorAnObjectRenderingOperationWithThisIDIsActive =>
      'An object rendering operation with this ID is active.';

  @override
  String get editorWaitForTheCurrentMapRenderingOperationToFinish =>
      'Wait for the current map rendering operation to finish.';

  @override
  String get editorTheStarCraftObjectRenderingHelperTimedOut =>
      'The StarCraft object rendering helper timed out.';

  @override
  String get editorRepairTheStarCraftInstallationAndRetry =>
      'Repair the StarCraft installation and retry.';

  @override
  String get editorTheStarCraftObjectHelperProducedTooMuchOutput =>
      'The StarCraft object helper produced too much output.';

  @override
  String get editorTheStarCraftObjectHelperCouldNotBeStarted =>
      'The StarCraft object helper could not be started.';

  @override
  String get editorTheStarCraftObjectAtlasCouldNotBeReadSafely =>
      'The StarCraft object atlas could not be read safely.';

  @override
  String get editorTheStarCraftObjectHelperReturnedAnInvalidResponse =>
      'The StarCraft object helper returned an invalid response.';

  @override
  String get editorTheStarCraftObjectRenderingOperationWasCancelled =>
      'The StarCraft object rendering operation was cancelled.';

  @override
  String get editorRetryAfterTheVisibleMapStateBecomesStable =>
      'Retry after the visible map state becomes stable.';

  @override
  String get editorThisHelperVersionDoesNotSupportThatCatalogKind =>
      'This helper version does not support that catalog kind.';

  @override
  String get editorChooseTheTileDoodadUnitOrPureSpriteCatalog =>
      'Choose the Tile, Doodad, Unit, or pure Sprite catalog.';

  @override
  String get editorACatalogOperationWithThisIDIsAlreadyActive =>
      'A catalog operation with this ID is already active.';

  @override
  String get editorWaitForTheActiveCatalogOperationToFinish =>
      'Wait for the active catalog operation to finish.';

  @override
  String get editorTheStarCraftCatalogHelperTimedOut =>
      'The StarCraft catalog helper timed out.';

  @override
  String get editorTheStarCraftCatalogHelperProducedTooMuchOutput =>
      'The StarCraft catalog helper produced too much output.';

  @override
  String get editorTheStarCraftCatalogHelperCouldNotBeStarted =>
      'The StarCraft catalog helper could not be started.';

  @override
  String get editorTheStarCraftCatalogCouldNotBeListedSafely =>
      'The StarCraft catalog could not be listed safely.';

  @override
  String get editorTheLocalDoodadRecipeIsInvalid =>
      'The local Doodad recipe is invalid.';

  @override
  String get editorTheLocalObjectPreviewIsUnavailable =>
      'The local object preview is unavailable.';

  @override
  String get editorVerifiedUnitCapabilityDataIsUnavailable =>
      'Verified unit capability data is unavailable.';

  @override
  String get editorThisUnitNeedsAnAddonOrNydusRelation =>
      'This unit needs an addon or Nydus relation.';

  @override
  String get editorTheStarCraftCatalogHelperReturnedAnInvalidResponse =>
      'The StarCraft catalog helper returned an invalid response.';

  @override
  String get editorRepairTheApplicationOrReportTheCatalogHelperError =>
      'Repair the application or report the catalog helper error.';

  @override
  String get editorTheStarCraftCatalogOperationWasCancelled =>
      'The StarCraft catalog operation was cancelled.';

  @override
  String get editorRetryTheCatalogOperationWhenReady =>
      'Retry the catalog operation when ready.';

  @override
  String get editorTheStarCraftTileRenderingHelperTimedOut =>
      'The StarCraft tile rendering helper timed out.';

  @override
  String get editorTheStarCraftTileHelperProducedTooMuchOutput =>
      'The StarCraft tile helper produced too much output.';

  @override
  String get editorTheStarCraftTileHelperCouldNotBeStarted =>
      'The StarCraft tile helper could not be started.';

  @override
  String get editorTheStarCraftTileAtlasCouldNotBeReadSafely =>
      'The StarCraft tile atlas could not be read safely.';

  @override
  String get editorTheStarCraftTileHelperReturnedAnInvalidResponse =>
      'The StarCraft tile helper returned an invalid response.';

  @override
  String get editorOpenTheReportedEpScriptModuleAndFixThisLine =>
      'Open the reported epScript module and fix this line.';

  @override
  String get editorEuddraftInspectionIsSupportedOnlyOnWindows =>
      'euddraft inspection is supported only on Windows.';

  @override
  String get editorRunTheEditorOnWindows10OrWindows11 =>
      'Run the editor on Windows 10 or Windows 11.';

  @override
  String get editorAnEuddraftInstallationPathHasNotBeenConfigured =>
      'An euddraft installation path has not been configured.';

  @override
  String get editorSelectTheExtractedEuddraftDirectoryOrEuddraftExe =>
      'Select the extracted euddraft directory or euddraft.exe.';

  @override
  String get editorTheEuddraftInstallationCouldNotBeInspected =>
      'The euddraft installation could not be inspected.';

  @override
  String get editorCheckPathPermissionsAndRetry =>
      'Check path permissions and retry.';

  @override
  String get editorTheEuddraftPathMustBeAnAbsoluteWindowsPath =>
      'The euddraft path must be an absolute Windows path.';

  @override
  String get editorSelectThePathUsingTheEditorSettings =>
      'Select the path using the editor settings.';

  @override
  String get editorTheConfiguredFileIsNotEuddraftExe =>
      'The configured file is not euddraft.exe.';

  @override
  String get editorSelectTheOfficialEuddraftExeOrItsInstallationFolder =>
      'Select the official euddraft.exe or its installation folder.';

  @override
  String get editorTheConfiguredEuddraftPathDoesNotExist =>
      'The configured euddraft path does not exist.';

  @override
  String get editorExtractTheOfficialEuddraftReleaseAndRetry =>
      'Extract the official euddraft release and retry.';

  @override
  String get editorTheConfiguredEuddraftPathIsNotARegularFile =>
      'The configured euddraft path is not a regular file or folder.';

  @override
  String get editorSelectALocalExtractedEuddraftInstallation =>
      'Select a local extracted euddraft installation.';

  @override
  String get editorTheInstallationDoesNotContainAUsableEuddraftExe =>
      'The installation does not contain a usable euddraft.exe.';

  @override
  String get editorReExtractTheOfficialEuddraftRelease =>
      'Re-extract the official euddraft release.';

  @override
  String get editorTheEuddraftVERSIONFileIsMissing =>
      'The euddraft VERSION file is missing.';

  @override
  String get editorUseACompleteOfficialEuddraftReleaseArchive =>
      'Use a complete official euddraft release archive.';

  @override
  String get editorTheEuddraftVERSIONFileHasAnInvalidSize =>
      'The euddraft VERSION file has an invalid size.';

  @override
  String get editorTheEuddraftVERSIONValueIsNotRecognized =>
      'The euddraft VERSION value is not recognized.';

  @override
  String get editorUseAnOfficialFourComponentEuddraftRelease =>
      'Use an official four-component euddraft release.';

  @override
  String editorEuddraftIsNotSupportedByThisEditor(String value0) {
    return 'euddraft $value0 is not supported by this editor.';
  }

  @override
  String editorInstallASupportedRelease(String value0) {
    return 'Install a supported release: $value0.';
  }

  @override
  String get editorTheEuddraftInstallationIsIncomplete =>
      'The euddraft installation is incomplete.';

  @override
  String get editorReExtractTheCompleteOfficialEuddraftRelease =>
      'Re-extract the complete official euddraft release.';

  @override
  String get editorTheAppHasNoTrustedInventoryForThisBundled =>
      'The app has no trusted inventory for this bundled tool.';

  @override
  String get editorUseAVerifiedAppPackageOrExplicitlySelectAn =>
      'Use a verified app package or explicitly select an external installation.';

  @override
  String get editorBundledToolIntegrityVerificationFailed =>
      'Bundled tool integrity verification failed.';

  @override
  String get editorRepairTheBundledInstallationOrExplicitlySelectAnExternal =>
      'Repair the bundled installation or explicitly select an external tool.';

  @override
  String get editorAnEUDBuildWithTheSameIDIsAlready =>
      'An EUD build with the same ID is already active.';

  @override
  String get editorWaitForTheActiveBuildOrCancelItFirst =>
      'Wait for the active build or cancel it first.';

  @override
  String get editorEuddraftCouldNotBeStarted =>
      'euddraft could not be started.';

  @override
  String get editorReinspectTheEuddraftInstallationAndRetry =>
      'Reinspect the euddraft installation and retry.';

  @override
  String get editorTheEuddraftBuildTimedOut => 'The euddraft build timed out.';

  @override
  String get editorInspectTheBuildLogThenRetryOrCancel =>
      'Inspect the build log, then retry or cancel.';

  @override
  String get editorEuddraftProducedMoreOutputThanTheSafetyLimit =>
      'euddraft produced more output than the safety limit.';

  @override
  String get editorInspectTheSourceForRunawayLoggingBeforeRetrying =>
      'Inspect the source for runaway logging before retrying.';

  @override
  String get editorEuddraftExitedWithAFailureCode =>
      'euddraft exited with a failure code.';

  @override
  String get editorReviewStdoutAndStderrForTheCompilerError =>
      'Review stdout and stderr for the compiler error.';

  @override
  String get editorTheEUDBuildCouldNotAccessARequiredFile =>
      'The EUD build could not access a required file.';

  @override
  String get editorCheckFilePermissionsAndRetry =>
      'Check file permissions and retry.';

  @override
  String get editorTheEUDBuildFailedUnexpectedly =>
      'The EUD build failed unexpectedly.';

  @override
  String get editorRetryTheBuildOrReportTheFailure =>
      'Retry the build or report the failure.';

  @override
  String get editorEuddraftBuildsAreSupportedOnlyOnWindows =>
      'euddraft builds are supported only on Windows.';

  @override
  String get editorTheEuddraftExecutablePathMustBeAbsolute =>
      'The euddraft executable path must be absolute.';

  @override
  String get editorInspectAndSelectTheEuddraftInstallationAgain =>
      'Inspect and select the euddraft installation again.';

  @override
  String get editorTheInspectedEuddraftExecutableIsNoLongerAvailable =>
      'The inspected euddraft executable is no longer available.';

  @override
  String get editorInspectTheEuddraftInstallationAgain =>
      'Inspect the euddraft installation again.';

  @override
  String get editorTheEuddraftSettingsPathMustBeAnAbsoluteEds =>
      'The euddraft settings path must be an absolute .eds path.';

  @override
  String get editorChooseAGeneratedOneShotEdsSettingsFile =>
      'Choose a generated one-shot .eds settings file.';

  @override
  String get editorTheEuddraftSettingsFileIsMissingOrEmpty =>
      'The euddraft settings file is missing or empty.';

  @override
  String get editorGenerateTheBuildSettingsAgainAndRetry =>
      'Generate the build settings again and retry.';

  @override
  String get editorTheEUDBuildWasCancelled => 'The EUD build was cancelled.';

  @override
  String get editorStartTheBuildAgainWhenReady =>
      'Start the build again when ready.';

  @override
  String get editorInactive => 'Inactive';

  @override
  String get editorRescuePassive => 'Rescue passive';

  @override
  String get editorComputer => 'Computer';

  @override
  String get editorHuman => 'Human';

  @override
  String get editorNeutral => 'Neutral';

  @override
  String get editorZerg => 'Zerg';

  @override
  String get editorTerran => 'Terran';

  @override
  String get editorProtoss => 'Protoss';

  @override
  String get editorIndependent => 'Independent';

  @override
  String get editorUserSelectable => 'User selectable';

  @override
  String get editorRandom => 'Random';

  @override
  String get editorRed => 'Red';

  @override
  String get editorBlue => 'Blue';

  @override
  String get editorTeal => 'Teal';

  @override
  String get editorPurple => 'Purple';

  @override
  String get editorOrange => 'Orange';

  @override
  String get editorBrown => 'Brown';

  @override
  String get editorWhite => 'White';

  @override
  String get editorYellow => 'Yellow';

  @override
  String get editorGreen => 'Green';

  @override
  String get editorPaleYellow => 'Pale yellow';

  @override
  String get editorTan => 'Tan';

  @override
  String get editorAzure => 'Azure';

  @override
  String editorExpectedOneSectionFound(String value0, String value1) {
    return '$value0: expected one section; found $value1.';
  }

  @override
  String editorExpectedBytesFound(String value0, String value1, String value2) {
    return '$value0: expected $value1 bytes; found $value2.';
  }

  @override
  String get editorASingleKnownVERSectionIsRequired =>
      'A single known VER section is required.';

  @override
  String get editorCRGBColorSettingsArePresentCOLREditingIsUnavailable =>
      'CRGB color settings are present. COLR editing is unavailable until their interaction is supported.';

  @override
  String get editorAPlayerFieldMayBeUpdatedOnlyOnce =>
      'A player field may be updated only once.';

  @override
  String editorUnsupportedID(String value0, String value1) {
    return 'Unsupported $value0 ID: $value1.';
  }

  @override
  String get editorStartLocationsCannotBeCheckedAUNITSectionIs =>
      'Start locations cannot be checked: a UNIT section is malformed.';

  @override
  String editorStartLocationHasNonPlayableOwnerID(String value0) {
    return 'Start location has non-playable owner ID $value0.';
  }

  @override
  String editorPlayerHasStartLocations(String value0, String value1) {
    return 'Player $value0 has $value1 start locations.';
  }

  @override
  String editorPlayerHasNoStartLocationCheckTheIntendedUMS(String value0) {
    return 'Player $value0 has no start location; check the intended UMS setup.';
  }

  @override
  String editorInactivePlayerOwnsAStartLocation(String value0) {
    return 'Inactive player $value0 owns a start location.';
  }

  @override
  String get editorForceNamesRequireOneSafeSTROrSTRxTable =>
      'Force names require one safe STR or STRx table.';

  @override
  String get editorForceSettingsRequireOneKnownVERAndOne20 =>
      'Force settings require one known VER and one 20-byte FORC section.';

  @override
  String editorInvalidForceNameStringID(String value0) {
    return 'Invalid force name string ID $value0.';
  }

  @override
  String get editorForceNamesCannotContainNUL =>
      'Force names cannot contain NUL.';

  @override
  String get editorFORCStringIDsCannotExceed65535 =>
      'FORC string IDs cannot exceed 65535.';

  @override
  String get editorUseDefaults => 'Use defaults';

  @override
  String get editorHitPoints => 'Hit points';

  @override
  String get editorShields => 'Shields';

  @override
  String get editorArmor => 'Armor';

  @override
  String get editorBuildTime160S => 'Build time (1/60 s)';

  @override
  String get editorMineralCost => 'Mineral cost';

  @override
  String get editorGasCost => 'Gas cost';

  @override
  String get editorHitPointsRequireANonnegativeDecimalInStepsOf =>
      'Hit points require a nonnegative decimal in steps of 1/256.';

  @override
  String get editorHitPointsMustBeAMultipleOf1256 =>
      'Hit points must be a multiple of 1/256.';

  @override
  String editorRequiresANonnegativeInteger(String value0) {
    return '$value0 requires a nonnegative integer.';
  }

  @override
  String editorInvalidUnitNameStringID(String value0) {
    return 'Invalid unit name string ID $value0.';
  }

  @override
  String get editorUnitSettingsRequireOneKnownVERSection =>
      'Unit settings require one known VER section.';

  @override
  String get editorUnitNamesRequireOneSafeSTROrSTRxTable =>
      'Unit names require one safe STR or STRx table.';

  @override
  String get editorUnitNamesCannotContainNUL =>
      'Unit names cannot contain NUL.';

  @override
  String get editorUnitNameIDsCannotExceed65535 =>
      'Unit name IDs cannot exceed 65535.';

  @override
  String get editorGlobalAvailabilityHasNoPlayer =>
      'Global availability has no player.';

  @override
  String get editorAPlayerIsRequired => 'A player is required.';

  @override
  String get editorUnitAvailabilityRequiresOneKnownVERSection =>
      'Unit availability requires one known VER section.';

  @override
  String editorPUNIExpectedOneSectionFound(String value0) {
    return 'PUNI: expected one section; found $value0.';
  }

  @override
  String editorPUNIExpected5700BytesFound(String value0) {
    return 'PUNI: expected 5700 bytes; found $value0.';
  }

  @override
  String get editorResearchTime160S => 'Research time (1/60 s)';

  @override
  String get editorEnergyCost => 'Energy cost';

  @override
  String get editorCostsHaveNoPlayer => 'Costs have no player.';

  @override
  String get editorInheritanceRequiresAPlayer =>
      'Inheritance requires a player.';

  @override
  String get editorTechSettingsRequireOneKnownVERSection =>
      'Tech settings require one known VER section.';

  @override
  String get editorBaseMineralCost => 'Base mineral cost';

  @override
  String get editorMineralCostPerLevel => 'Mineral cost per level';

  @override
  String get editorBaseGasCost => 'Base gas cost';

  @override
  String get editorGasCostPerLevel => 'Gas cost per level';

  @override
  String get editorBaseResearchTime160S => 'Base research time (1/60 s)';

  @override
  String get editorResearchTimePerLevel160S =>
      'Research time per level (1/60 s)';

  @override
  String get editorMaximumLevel => 'Maximum level';

  @override
  String get editorStartingLevel => 'Starting level';

  @override
  String get editorUpgradeSettingsRequireOneKnownVERSection =>
      'Upgrade settings require one known VER section.';

  @override
  String editorUpgradeStartingLevelMustNotExceedMaximumLevel(
    String value0,
    String value1,
  ) {
    return 'Upgrade #$value0 $value1: starting level must not exceed maximum level.';
  }

  @override
  String get editorEnterIDsSuchAs025 => 'Enter IDs such as 0, 2-5.';

  @override
  String get editorUseCommaSeparatedIDsOrAscendingRanges =>
      'Use comma-separated IDs or ascending ranges.';

  @override
  String editorIDsMustBeBetweenAndInAscendingRanges(
    String value0,
    String value1,
  ) {
    return 'IDs must be between $value0 and $value1, in ascending ranges.';
  }

  @override
  String get editorOneStructurallySafeSTRSTRxTableIsRequiredFor =>
      'One structurally safe STR/STRx table is required for editing.';

  @override
  String editorTruncated(String value0) {
    return 'Truncated $value0';
  }

  @override
  String get editorMalformedSPRP => 'Malformed SPRP';

  @override
  String get editorMalformedFORC => 'Malformed FORC';

  @override
  String editorForcef1368d9(String value0) {
    return 'force $value0';
  }

  @override
  String get editorMalformedMRGN => 'Malformed MRGN';

  @override
  String editorLocation(String value0) {
    return 'location $value0';
  }

  @override
  String get editorMalformedSWNM => 'Malformed SWNM';

  @override
  String editorSwitchffe3c882(String value0) {
    return 'switch $value0';
  }

  @override
  String get editorMalformedWAV => 'Malformed WAV';

  @override
  String editorSoundSlot(String value0) {
    return 'sound slot $value0';
  }

  @override
  String editorMalformed(String value0) {
    return 'Malformed $value0';
  }

  @override
  String editorUnitc6ee345c(String value0) {
    return 'unit $value0';
  }

  @override
  String editorRawConditionInTrigger(String value0) {
    return 'Raw condition in trigger $value0';
  }

  @override
  String editorRawActionInTrigger(String value0) {
    return 'Raw action in trigger $value0';
  }

  @override
  String editorTriggerAction(String value0, String value1, String value2) {
    return 'trigger $value0 action $value1 $value2';
  }

  @override
  String get editorRawBriefingAction => 'Raw briefing action';

  @override
  String editorBriefingActionText(String value0, String value1) {
    return 'briefing $value0 action $value1 text';
  }

  @override
  String editorBriefingActionSound(String value0, String value1) {
    return 'briefing $value0 action $value1 sound';
  }

  @override
  String editorUninterpretedSection(String value0) {
    return 'Uninterpreted $value0 section';
  }

  @override
  String get editorDuplicateCHKSections => 'Duplicate CHK sections';

  @override
  String get editorInvalidStringID => 'Invalid string ID.';

  @override
  String get editorSoundPathReferencesAreManagedThroughSoundImportDelete =>
      'Sound path references are managed through sound import/delete. Separate a text reference to edit its text.';

  @override
  String get editorReferencedOrIncompletelyTracedStringsCannotBeCleared =>
      'Referenced or incompletely traced strings cannot be cleared.';

  @override
  String get editorNULIsNotAllowed => 'NUL is not allowed.';

  @override
  String get editorTheSelectedReferenceChanged =>
      'The selected reference changed.';

  @override
  String get editorThisReferenceRequiresA16BitStringID =>
      'This reference requires a 16-bit string ID.';

  @override
  String get editorOneValidWAVTableIsRequired =>
      'One valid WAV table is required.';

  @override
  String get editorAll512SoundSlotsAreOccupied =>
      'All 512 sound slots are occupied.';

  @override
  String get editorSoundIsReferencedOrReferenceCoverageIsIncomplete =>
      'Sound is referenced, or reference coverage is incomplete.';

  @override
  String editorAmbiguousOrMalformedSection(String value0) {
    return 'Ambiguous or malformed $value0 section.';
  }

  @override
  String get editorTextCannotContainNUL => 'Text cannot contain NUL.';

  @override
  String get editorOneSafeStringTableIsRequired =>
      'One safe string table is required.';

  @override
  String editorSwitch8e2b60a2(String value0) {
    return 'Switch $value0';
  }

  @override
  String get editorHitpoints => 'Hitpoints %';

  @override
  String get editorShields83e6a3a => 'Shields %';

  @override
  String get editorEnergy => 'Energy %';

  @override
  String get editorResourceAmount => 'Resource amount';

  @override
  String get editorHangarCount => 'Hangar count';

  @override
  String get editorCloaked => 'Cloaked';

  @override
  String get editorBurrowed => 'Burrowed';

  @override
  String get editorLifted => 'Lifted';

  @override
  String get editorHallucinated => 'Hallucinated';

  @override
  String get editorInvincible => 'Invincible';

  @override
  String editorInvalid8650455(String value0) {
    return 'Invalid $value0';
  }

  @override
  String get editorFiveSpecialPropertyStatesRequired =>
      'Five special property states required.';

  @override
  String get editorOpenAMapFirst => 'Open a map first.';

  @override
  String get editorMapChangedDuringImport => 'Map changed during import.';

  @override
  String get editorThisPathAlreadyHasASoundReferenceChooseA =>
      'This path already has a sound reference. Choose a different file name.';

  @override
  String get editorASoundAlreadyUsesThisPathChooseADifferent =>
      'A sound already uses this path. Choose a different file name.';

  @override
  String get editorIncompleteArchiveListingNameCollisionsCannotBeRuledOut =>
      'Incomplete archive listing: name collisions cannot be ruled out.';

  @override
  String get editorAmbiguousArchiveEntryDeletionIsBlocked =>
      'Ambiguous archive entry: deletion is blocked.';

  @override
  String get editorSoundIsDeleted => 'Sound is deleted.';

  @override
  String get editorTheSoundIsNotStoredInThisNewMap =>
      'The sound is not stored in this new map.';

  @override
  String get editorSoundGatewayUnavailable => 'Sound gateway unavailable.';

  @override
  String get editorSourceMapChangedOnDisk => 'Source map changed on disk.';

  @override
  String get editorMapChangedDuringSoundRead =>
      'Map changed during sound read.';

  @override
  String get editorTheSoundIsNotStoredInThisMap =>
      'The sound is not stored in this map.';

  @override
  String get editorOpenAnEditableMap => 'Open an editable map.';

  @override
  String get editorMapChangedReopenTriggerResources =>
      'Map changed. Reopen trigger resources.';

  @override
  String get editorPendingSoundEditsExceed64EntriesOr64MiB =>
      'Pending sound edits exceed 64 entries or 64 MiB. Save first.';

  @override
  String get editorResourceEditsCannotRemoveSections =>
      'Resource edits cannot remove sections.';

  @override
  String get editorUnsupportedAppendedResource =>
      'Unsupported appended resource.';

  @override
  String get editorUnsupportedResourceChange => 'Unsupported resource change.';

  @override
  String get editorEditTriggerResources => 'Edit trigger resources';

  @override
  String get editorMapChangedReopenTheTriggerEditor =>
      'Map changed. Reopen the trigger editor.';

  @override
  String get editorTRIGAndMBRFRecordsCannotBeMixed =>
      'TRIG and MBRF records cannot be mixed.';

  @override
  String get editorCreateBriefing => 'Create briefing';

  @override
  String get editorEditBriefing => 'Edit briefing';

  @override
  String get editorEditTriggers => 'Edit triggers';

  @override
  String get editorOpenAnEditableMapBeforeChangingTechs =>
      'Open an editable map before changing techs.';

  @override
  String get editorTheMapChangedReopenTechSettingsBeforeApplying =>
      'The map changed. Reopen Tech Settings before applying.';

  @override
  String get editorEditTechSettings => 'Edit tech settings';

  @override
  String get editorOpenAnEditableMapBeforeChangingUpgrades =>
      'Open an editable map before changing upgrades.';

  @override
  String get editorTheMapChangedReopenUpgradeSettingsBeforeApplying =>
      'The map changed. Reopen Upgrade Settings before applying.';

  @override
  String get editorEditUpgradeSettings => 'Edit upgrade settings';

  @override
  String get editorOpenAnEditableMapBeforeChangingAvailability =>
      'Open an editable map before changing availability.';

  @override
  String get editorTheMapChangedReopenUnitAvailabilityBeforeApplying =>
      'The map changed. Reopen Unit Availability before applying.';

  @override
  String get editorEditUnitAvailability => 'Edit unit availability';

  @override
  String get editorOpenAnEditableMapBeforeChangingUnitSettings =>
      'Open an editable map before changing unit settings.';

  @override
  String get editorTheMapChangedReopenUnitSettingsBeforeApplying =>
      'The map changed. Reopen Unit Settings before applying.';

  @override
  String get editorEditUnitSettings => 'Edit unit settings';

  @override
  String get editorOpenAnEditableMapBeforeChangingForceSettings =>
      'Open an editable map before changing force settings.';

  @override
  String get editorTheMapChangedReopenForceSettingsBeforeApplying =>
      'The map changed. Reopen Force Settings before applying.';

  @override
  String get editorEditForceSettings => 'Edit force settings';

  @override
  String get editorOpenAnEditableMapBeforeChangingPlayerSettings =>
      'Open an editable map before changing player settings.';

  @override
  String get editorTheMapChangedReopenPlayerSettingsBeforeApplying =>
      'The map changed. Reopen Player Settings before applying.';

  @override
  String get editorEditPlayerSettings => 'Edit player settings';

  @override
  String get editorOpenAnEditableMapBeforeChangingMapInformation =>
      'Open an editable map before changing map information.';

  @override
  String get editorTheMapChangedReopenMapInformationBeforeApplying =>
      'The map changed. Reopen Map Information before applying.';

  @override
  String get editorEditMapInformation => 'Edit map information';

  @override
  String get editorABuildOrPreparationIsAlreadyRunning =>
      'A build or preparation is already running.';

  @override
  String get editorConfirmThatYouTrustTheEpScriptSourceAndIts =>
      'Confirm that you trust the epScript source and its imports.';

  @override
  String get editorEnableTheUnverifiedSettingsTestBuildToCompileProject =>
      'Enable the unverified settings test build to compile project settings.';

  @override
  String get editorVerifyTheSavedMapAndEUDProjectBindingBefore =>
      'Verify the saved map and EUD project binding before building.';

  @override
  String get editorTheBuildBaseMustBeTheMapBoundTo =>
      'The build base must be the map bound to this EUD project.';

  @override
  String get editorFinishOrRetryEUDToolsSettingsFirst =>
      'Finish or retry EUD Tools settings first.';

  @override
  String get editorChooseAnOutputSeparateFromTheBaseMap =>
      'Choose an output separate from the base map.';

  @override
  String get editorOutputAlreadyExistsChooseANewScxPath =>
      'Output already exists. Choose a new .scx path.';

  @override
  String get editorPreparationCancelled => 'Preparation cancelled.';

  @override
  String get editorToolSelectionChangedPrepareAgain =>
      'Tool selection changed. Prepare again.';

  @override
  String get editorProjectOrMapChangedPrepareAgain =>
      'Project or map changed. Prepare again.';

  @override
  String editorBuildPreparationFailed(String value0) {
    return 'Build preparation failed: $value0';
  }

  @override
  String editorTheToolDirectoryCouldNotBeSelected(String value0) {
    return 'The tool directory could not be selected: $value0';
  }

  @override
  String get editorEnterAnAbsoluteEuddraftInstallationPath =>
      'Enter an absolute euddraft installation path.';

  @override
  String editorToolSettingsCouldNotBeUpdated(String value0) {
    return 'Tool settings could not be updated: $value0';
  }

  @override
  String editorRangeErrorInvalidValueNotInInclusiveRange(
    String value0,
    String value1,
    String value2,
    String value3,
  ) {
    return 'RangeError ($value0): Invalid value: Not in inclusive range $value1..$value2: $value3';
  }

  @override
  String get editorRecovery => 'Recovery';

  @override
  String get editorSaveAs => 'Save As';

  @override
  String get editorOpenMap => 'Open Map';

  @override
  String get editorEUDBuild => 'EUD Build';

  @override
  String get editorTheMapCouldNotBeSaved => 'The map could not be saved.';

  @override
  String get editorRepairTheApplicationOrReportTheObjectRenderingError =>
      'Repair the application or report the object rendering error.';

  @override
  String get editorRepairTheApplicationOrReportTheStarCraftTileHelper =>
      'Repair the application or report the StarCraft tile helper error.';

  @override
  String get editorTheEUDOutputMustBeAbsentOrARegular =>
      'The EUD output must be absent or a regular file.';

  @override
  String get editorTheCanonicalEUDEntrySourceIsOutsideTheSource =>
      'The canonical EUD entry source is outside the source root.';

  @override
  String get editorTheCanonicalEUDOutputDirectoryIsInsideTheSource =>
      'The canonical EUD output directory is inside the source root.';

  @override
  String get editorSavedSnapshotNewerEditsRemain =>
      'The saved snapshot was verified. Newer edits remain open and unsaved.';

  @override
  String get editorSaveCurrentDocumentAgain =>
      'Finish editing and use Save As again to save the current document.';

  @override
  String get terrainModeNatural => 'Terrain';

  @override
  String get terrainModeTile => 'Single Tile';

  @override
  String get terrainVariationSeed => 'Variation Seed';

  @override
  String get catalogShowComponents => 'Show turret components';

  @override
  String get catalogIssueSubunit =>
      'This turret is generated with its parent unit.';

  @override
  String get terrainSeedInvalid => 'Enter an integer from 0 to 4294967295.';

  @override
  String get visualSelection => 'Graphic selection';

  @override
  String get epScriptHelpTitle => 'epScript / EUD';

  @override
  String get epScriptHelpBody =>
      'epScript (.eps) defines custom game logic such as conditions, actions and repeating rules. It is separate from ordinary map object placement and becomes EUD triggers only when compiled with euddraft.\n\nSave the map and script, prepare the EUD build, then build a separate output map. Editing a script does not execute it or change the original map. Only build trusted code.';

  @override
  String get epScriptInsertExample => 'Insert starter script';

  @override
  String get epScriptComplete => 'Complete symbol';

  @override
  String get epScriptExample => 'Starter script';

  @override
  String get placementTerrainMismatch =>
      'The ground does not match this doodad\'s required terrain. Place it on matching terrain. The map was not changed.';

  @override
  String get placementLayerLocked =>
      'A required layer is hidden or locked. Show the layer and unlock it before placing.';

  @override
  String get placementOutsideMap =>
      'Choose a position where the entire object fits inside the map. The map was not changed.';
}
