// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for English (`en`).
class AppLocalizationsEn extends AppLocalizations {
  AppLocalizationsEn([String locale = 'en']) : super(locale);

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
}
