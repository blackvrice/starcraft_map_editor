import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/intl.dart' as intl;

import 'app_localizations_en.dart';
import 'app_localizations_ko.dart';

// ignore_for_file: type=lint

/// Callers can lookup localized strings with an instance of AppLocalizations
/// returned by `AppLocalizations.of(context)`.
///
/// Applications need to include `AppLocalizations.delegate()` in their app's
/// `localizationDelegates` list, and the locales they support in the app's
/// `supportedLocales` list. For example:
///
/// ```dart
/// import 'l10n/app_localizations.dart';
///
/// return MaterialApp(
///   localizationsDelegates: AppLocalizations.localizationsDelegates,
///   supportedLocales: AppLocalizations.supportedLocales,
///   home: MyApplicationHome(),
/// );
/// ```
///
/// ## Update pubspec.yaml
///
/// Please make sure to update your pubspec.yaml to include the following
/// packages:
///
/// ```yaml
/// dependencies:
///   # Internationalization support.
///   flutter_localizations:
///     sdk: flutter
///   intl: any # Use the pinned version from flutter_localizations
///
///   # Rest of dependencies
/// ```
///
/// ## iOS Applications
///
/// iOS applications define key application metadata, including supported
/// locales, in an Info.plist file that is built into the application bundle.
/// To configure the locales supported by your app, you’ll need to edit this
/// file.
///
/// First, open your project’s ios/Runner.xcworkspace Xcode workspace file.
/// Then, in the Project Navigator, open the Info.plist file under the Runner
/// project’s Runner folder.
///
/// Next, select the Information Property List item, select Add Item from the
/// Editor menu, then select Localizations from the pop-up menu.
///
/// Select and expand the newly-created Localizations item then, for each
/// locale your application supports, add a new item and select the locale
/// you wish to add from the pop-up menu in the Value field. This list should
/// be consistent with the languages listed in the AppLocalizations.supportedLocales
/// property.
abstract class AppLocalizations {
  AppLocalizations(String locale)
    : localeName = intl.Intl.canonicalizedLocale(locale.toString());

  final String localeName;

  static AppLocalizations? of(BuildContext context) {
    return Localizations.of<AppLocalizations>(context, AppLocalizations);
  }

  static const LocalizationsDelegate<AppLocalizations> delegate =
      _AppLocalizationsDelegate();

  /// A list of this localizations delegate along with the default localizations
  /// delegates.
  ///
  /// Returns a list of localizations delegates containing this delegate along with
  /// GlobalMaterialLocalizations.delegate, GlobalCupertinoLocalizations.delegate,
  /// and GlobalWidgetsLocalizations.delegate.
  ///
  /// Additional delegates can be added by appending to this list in
  /// MaterialApp. This list does not have to be used at all if a custom list
  /// of delegates is preferred or required.
  static const List<LocalizationsDelegate<dynamic>> localizationsDelegates =
      <LocalizationsDelegate<dynamic>>[
        delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
      ];

  /// A list of this localizations delegate's supported locales.
  static const List<Locale> supportedLocales = <Locale>[
    Locale('en'),
    Locale('ko'),
  ];

  /// No description provided for @appTitle.
  ///
  /// In en, this message translates to:
  /// **'StarCraft Map Editor'**
  String get appTitle;

  /// No description provided for @menuFile.
  ///
  /// In en, this message translates to:
  /// **'File'**
  String get menuFile;

  /// No description provided for @menuNewMap.
  ///
  /// In en, this message translates to:
  /// **'New Map…'**
  String get menuNewMap;

  /// No description provided for @menuOpenMap.
  ///
  /// In en, this message translates to:
  /// **'Open Map…'**
  String get menuOpenMap;

  /// No description provided for @menuPrepareEudBuild.
  ///
  /// In en, this message translates to:
  /// **'Prepare EUD Build…'**
  String get menuPrepareEudBuild;

  /// No description provided for @menuEudTools.
  ///
  /// In en, this message translates to:
  /// **'EUD Tools…'**
  String get menuEudTools;

  /// No description provided for @menuSaveAs.
  ///
  /// In en, this message translates to:
  /// **'Save As…'**
  String get menuSaveAs;

  /// No description provided for @menuMapInformation.
  ///
  /// In en, this message translates to:
  /// **'Map Information…'**
  String get menuMapInformation;

  /// No description provided for @menuPlayerSettings.
  ///
  /// In en, this message translates to:
  /// **'Player Settings…'**
  String get menuPlayerSettings;

  /// No description provided for @menuForceSettings.
  ///
  /// In en, this message translates to:
  /// **'Force Settings…'**
  String get menuForceSettings;

  /// No description provided for @menuUnitSettings.
  ///
  /// In en, this message translates to:
  /// **'Unit Settings…'**
  String get menuUnitSettings;

  /// No description provided for @menuUnitAvailability.
  ///
  /// In en, this message translates to:
  /// **'Unit Availability…'**
  String get menuUnitAvailability;

  /// No description provided for @menuUpgradeSettings.
  ///
  /// In en, this message translates to:
  /// **'Upgrade Settings…'**
  String get menuUpgradeSettings;

  /// No description provided for @menuTechSettings.
  ///
  /// In en, this message translates to:
  /// **'Tech Settings…'**
  String get menuTechSettings;

  /// No description provided for @menuMapSettings.
  ///
  /// In en, this message translates to:
  /// **'Map Settings…'**
  String get menuMapSettings;

  /// No description provided for @menuClose.
  ///
  /// In en, this message translates to:
  /// **'Close'**
  String get menuClose;

  /// No description provided for @menuEdit.
  ///
  /// In en, this message translates to:
  /// **'Edit'**
  String get menuEdit;

  /// No description provided for @menuUndo.
  ///
  /// In en, this message translates to:
  /// **'Undo'**
  String get menuUndo;

  /// No description provided for @menuRedo.
  ///
  /// In en, this message translates to:
  /// **'Redo'**
  String get menuRedo;

  /// No description provided for @menuSettings.
  ///
  /// In en, this message translates to:
  /// **'Settings…'**
  String get menuSettings;

  /// No description provided for @menuLanguage.
  ///
  /// In en, this message translates to:
  /// **'Language'**
  String get menuLanguage;

  /// No description provided for @menuView.
  ///
  /// In en, this message translates to:
  /// **'View'**
  String get menuView;

  /// No description provided for @menuResetLayout.
  ///
  /// In en, this message translates to:
  /// **'Reset Layout'**
  String get menuResetLayout;

  /// No description provided for @menuEud.
  ///
  /// In en, this message translates to:
  /// **'EUD'**
  String get menuEud;

  /// No description provided for @menuNewEpScript.
  ///
  /// In en, this message translates to:
  /// **'New epScript'**
  String get menuNewEpScript;

  /// No description provided for @menuBuildEudMap.
  ///
  /// In en, this message translates to:
  /// **'Build EUD Map'**
  String get menuBuildEudMap;

  /// No description provided for @menuCancelEudBuild.
  ///
  /// In en, this message translates to:
  /// **'Cancel EUD Build'**
  String get menuCancelEudBuild;

  /// No description provided for @menuHelp.
  ///
  /// In en, this message translates to:
  /// **'Help'**
  String get menuHelp;

  /// No description provided for @menuDocumentation.
  ///
  /// In en, this message translates to:
  /// **'Documentation'**
  String get menuDocumentation;

  /// No description provided for @menuAbout.
  ///
  /// In en, this message translates to:
  /// **'About'**
  String get menuAbout;

  /// No description provided for @languageSystem.
  ///
  /// In en, this message translates to:
  /// **'System default ({language})'**
  String languageSystem(String language);

  /// No description provided for @languageTooltip.
  ///
  /// In en, this message translates to:
  /// **'Display language'**
  String get languageTooltip;

  /// No description provided for @languageSaveFailed.
  ///
  /// In en, this message translates to:
  /// **'The language applies now but could not be saved for next time.'**
  String get languageSaveFailed;

  /// No description provided for @toolbarOpenMap.
  ///
  /// In en, this message translates to:
  /// **'Open Map'**
  String get toolbarOpenMap;

  /// No description provided for @toolbarSaveAs.
  ///
  /// In en, this message translates to:
  /// **'Save As'**
  String get toolbarSaveAs;

  /// No description provided for @toolbarNewEpScript.
  ///
  /// In en, this message translates to:
  /// **'New epScript'**
  String get toolbarNewEpScript;

  /// No description provided for @toolbarBuildEud.
  ///
  /// In en, this message translates to:
  /// **'Build EUD'**
  String get toolbarBuildEud;

  /// No description provided for @toolbarCancelBuild.
  ///
  /// In en, this message translates to:
  /// **'Cancel Build'**
  String get toolbarCancelBuild;

  /// No description provided for @documentUnsaved.
  ///
  /// In en, this message translates to:
  /// **'Unsaved changes'**
  String get documentUnsaved;

  /// No description provided for @documentSaved.
  ///
  /// In en, this message translates to:
  /// **'No unsaved changes'**
  String get documentSaved;

  /// No description provided for @assetsChecking.
  ///
  /// In en, this message translates to:
  /// **'Assets checking'**
  String get assetsChecking;

  /// No description provided for @assetsCheckingShort.
  ///
  /// In en, this message translates to:
  /// **'Checking'**
  String get assetsCheckingShort;

  /// No description provided for @assetsReady.
  ///
  /// In en, this message translates to:
  /// **'Assets ready'**
  String get assetsReady;

  /// No description provided for @assetsReadyShort.
  ///
  /// In en, this message translates to:
  /// **'Ready'**
  String get assetsReadyShort;

  /// No description provided for @assetsNotConfigured.
  ///
  /// In en, this message translates to:
  /// **'Assets not configured'**
  String get assetsNotConfigured;

  /// No description provided for @assetsNotConfiguredShort.
  ///
  /// In en, this message translates to:
  /// **'Setup'**
  String get assetsNotConfiguredShort;

  /// No description provided for @assetsUnavailable.
  ///
  /// In en, this message translates to:
  /// **'Assets unavailable'**
  String get assetsUnavailable;

  /// No description provided for @assetsUnavailableShort.
  ///
  /// In en, this message translates to:
  /// **'Missing'**
  String get assetsUnavailableShort;

  /// No description provided for @environmentBadge.
  ///
  /// In en, this message translates to:
  /// **'Windows • SC:R • {status}'**
  String environmentBadge(String status);

  /// No description provided for @environmentBadgeCompact.
  ///
  /// In en, this message translates to:
  /// **'SC:R • {status}'**
  String environmentBadgeCompact(String status);

  /// No description provided for @environmentBadgeTooltip.
  ///
  /// In en, this message translates to:
  /// **'Open StarCraft data asset settings • {status}'**
  String environmentBadgeTooltip(String status);

  /// No description provided for @railLabel.
  ///
  /// In en, this message translates to:
  /// **'Workspaces'**
  String get railLabel;

  /// No description provided for @railMap.
  ///
  /// In en, this message translates to:
  /// **'Map'**
  String get railMap;

  /// No description provided for @railCatalog.
  ///
  /// In en, this message translates to:
  /// **'Catalog'**
  String get railCatalog;

  /// No description provided for @railMapSettings.
  ///
  /// In en, this message translates to:
  /// **'Map Settings'**
  String get railMapSettings;

  /// No description provided for @railTriggers.
  ///
  /// In en, this message translates to:
  /// **'Triggers'**
  String get railTriggers;

  /// No description provided for @railResources.
  ///
  /// In en, this message translates to:
  /// **'Resources'**
  String get railResources;

  /// No description provided for @railBriefing.
  ///
  /// In en, this message translates to:
  /// **'Briefing'**
  String get railBriefing;

  /// No description provided for @railEudProject.
  ///
  /// In en, this message translates to:
  /// **'EUD Project'**
  String get railEudProject;

  /// No description provided for @railUnsavedTooltip.
  ///
  /// In en, this message translates to:
  /// **'{name} • unsaved changes'**
  String railUnsavedTooltip(String name);

  /// No description provided for @paneProjectSources.
  ///
  /// In en, this message translates to:
  /// **'Project / Sources'**
  String get paneProjectSources;

  /// No description provided for @paneProjectLayers.
  ///
  /// In en, this message translates to:
  /// **'Project / Layers'**
  String get paneProjectLayers;

  /// No description provided for @paneLayersPalette.
  ///
  /// In en, this message translates to:
  /// **'Layers / Object Palette'**
  String get paneLayersPalette;

  /// No description provided for @paneInspector.
  ///
  /// In en, this message translates to:
  /// **'Inspector'**
  String get paneInspector;

  /// No description provided for @emptyLayers.
  ///
  /// In en, this message translates to:
  /// **'Open a map to see its layers here.'**
  String get emptyLayers;

  /// No description provided for @emptyInspector.
  ///
  /// In en, this message translates to:
  /// **'Select something on the map to see and edit its properties.'**
  String get emptyInspector;

  /// No description provided for @sourceDraft.
  ///
  /// In en, this message translates to:
  /// **'Draft'**
  String get sourceDraft;

  /// No description provided for @sourceEpScript.
  ///
  /// In en, this message translates to:
  /// **'epScript source'**
  String get sourceEpScript;

  /// No description provided for @inspectorFile.
  ///
  /// In en, this message translates to:
  /// **'File'**
  String get inspectorFile;

  /// No description provided for @inspectorLocation.
  ///
  /// In en, this message translates to:
  /// **'Location'**
  String get inspectorLocation;

  /// No description provided for @inspectorLines.
  ///
  /// In en, this message translates to:
  /// **'Lines'**
  String get inspectorLines;

  /// No description provided for @inspectorCharacters.
  ///
  /// In en, this message translates to:
  /// **'Characters'**
  String get inspectorCharacters;

  /// No description provided for @inspectorRevision.
  ///
  /// In en, this message translates to:
  /// **'Revision'**
  String get inspectorRevision;

  /// No description provided for @inspectorState.
  ///
  /// In en, this message translates to:
  /// **'State'**
  String get inspectorState;

  /// No description provided for @stateModified.
  ///
  /// In en, this message translates to:
  /// **'Modified'**
  String get stateModified;

  /// No description provided for @stateClean.
  ///
  /// In en, this message translates to:
  /// **'Clean'**
  String get stateClean;

  /// No description provided for @inMemoryDraft.
  ///
  /// In en, this message translates to:
  /// **'In-memory draft'**
  String get inMemoryDraft;

  /// No description provided for @startTitle.
  ///
  /// In en, this message translates to:
  /// **'Open a map to begin'**
  String get startTitle;

  /// No description provided for @startBody.
  ///
  /// In en, this message translates to:
  /// **'Open an unprotected StarCraft: Remastered UMS map (.scm or .scx). Your original file is never overwritten; edits are saved with Save As.'**
  String get startBody;

  /// No description provided for @startShortcutHint.
  ///
  /// In en, this message translates to:
  /// **'Shortcut: Ctrl+O'**
  String get startShortcutHint;

  /// No description provided for @recentMaps.
  ///
  /// In en, this message translates to:
  /// **'Recent maps'**
  String get recentMaps;

  /// No description provided for @recentMapsLoadFailed.
  ///
  /// In en, this message translates to:
  /// **'Recent maps could not be loaded.'**
  String get recentMapsLoadFailed;

  /// No description provided for @recentMapsEmpty.
  ///
  /// In en, this message translates to:
  /// **'Maps you open will appear here.'**
  String get recentMapsEmpty;

  /// No description provided for @recentMapsRemove.
  ///
  /// In en, this message translates to:
  /// **'Remove from recent maps'**
  String get recentMapsRemove;

  /// No description provided for @untitledMap.
  ///
  /// In en, this message translates to:
  /// **'Untitled map'**
  String get untitledMap;

  /// No description provided for @notSavedYet.
  ///
  /// In en, this message translates to:
  /// **'Not saved yet'**
  String get notSavedYet;

  /// No description provided for @mapSizeUnavailable.
  ///
  /// In en, this message translates to:
  /// **'Size unavailable'**
  String get mapSizeUnavailable;

  /// No description provided for @mapTilesetUnavailable.
  ///
  /// In en, this message translates to:
  /// **'Tileset unavailable'**
  String get mapTilesetUnavailable;

  /// No description provided for @mapTilesetRaw.
  ///
  /// In en, this message translates to:
  /// **'Tileset {value}'**
  String mapTilesetRaw(String value);

  /// No description provided for @mapGeometryPreview.
  ///
  /// In en, this message translates to:
  /// **'Geometry preview'**
  String get mapGeometryPreview;

  /// No description provided for @mapMtxmTiles.
  ///
  /// In en, this message translates to:
  /// **'{count} MTXM tiles'**
  String mapMtxmTiles(int count);

  /// No description provided for @mapNavigationHelp.
  ///
  /// In en, this message translates to:
  /// **'Wheel zoom · Space/middle drag'**
  String get mapNavigationHelp;

  /// No description provided for @mapPickPriority.
  ///
  /// In en, this message translates to:
  /// **'Pick {order}'**
  String mapPickPriority(String order);

  /// No description provided for @mapPlacing.
  ///
  /// In en, this message translates to:
  /// **'Place {label} · Esc cancel'**
  String mapPlacing(String label);

  /// No description provided for @mapCreatingLocation.
  ///
  /// In en, this message translates to:
  /// **'Drag new location · Esc cancel'**
  String get mapCreatingLocation;

  /// No description provided for @mapProblemCounts.
  ///
  /// In en, this message translates to:
  /// **'{blocking} blocking · {warnings} warning'**
  String mapProblemCounts(int blocking, int warnings);

  /// No description provided for @mapCanvasUnavailable.
  ///
  /// In en, this message translates to:
  /// **'A unique, non-zero DIM section is required for the canvas.'**
  String get mapCanvasUnavailable;

  /// No description provided for @sessionRestricted.
  ///
  /// In en, this message translates to:
  /// **'Restricted'**
  String get sessionRestricted;

  /// No description provided for @sessionModified.
  ///
  /// In en, this message translates to:
  /// **'Modified'**
  String get sessionModified;

  /// No description provided for @sessionEditable.
  ///
  /// In en, this message translates to:
  /// **'Editable'**
  String get sessionEditable;

  /// No description provided for @sessionReadOnly.
  ///
  /// In en, this message translates to:
  /// **'Read-only preview'**
  String get sessionReadOnly;

  /// No description provided for @sessionRestrictedHelp.
  ///
  /// In en, this message translates to:
  /// **'Some map data could not be verified, so only safe edits are allowed.'**
  String get sessionRestrictedHelp;

  /// No description provided for @sessionModifiedHelp.
  ///
  /// In en, this message translates to:
  /// **'You have edits that are not saved yet. Use Save As to keep them.'**
  String get sessionModifiedHelp;

  /// No description provided for @sessionEditableHelp.
  ///
  /// In en, this message translates to:
  /// **'This map can be edited. The original file is not changed until you save a copy.'**
  String get sessionEditableHelp;

  /// No description provided for @sessionReadOnlyHelp.
  ///
  /// In en, this message translates to:
  /// **'This map is shown for viewing only.'**
  String get sessionReadOnlyHelp;

  /// No description provided for @objectCancelLocation.
  ///
  /// In en, this message translates to:
  /// **'Cancel location'**
  String get objectCancelLocation;

  /// No description provided for @objectNewLocation.
  ///
  /// In en, this message translates to:
  /// **'New location'**
  String get objectNewLocation;

  /// No description provided for @objectDelete.
  ///
  /// In en, this message translates to:
  /// **'Delete'**
  String get objectDelete;

  /// No description provided for @objectUndo.
  ///
  /// In en, this message translates to:
  /// **'Undo'**
  String get objectUndo;

  /// No description provided for @objectRedo.
  ///
  /// In en, this message translates to:
  /// **'Redo'**
  String get objectRedo;

  /// No description provided for @objectSelectHint.
  ///
  /// In en, this message translates to:
  /// **'Click or drag to select objects'**
  String get objectSelectHint;

  /// No description provided for @objectSelectedMove.
  ///
  /// In en, this message translates to:
  /// **'{count} selected · drag selection to move'**
  String objectSelectedMove(int count);

  /// No description provided for @objectUndoAction.
  ///
  /// In en, this message translates to:
  /// **'Undo {label}'**
  String objectUndoAction(String label);

  /// No description provided for @objectRedoAction.
  ///
  /// In en, this message translates to:
  /// **'Redo {label}'**
  String objectRedoAction(String label);

  /// No description provided for @objectShortcutHint.
  ///
  /// In en, this message translates to:
  /// **'Ctrl/Shift click adds · Delete removes'**
  String get objectShortcutHint;

  /// No description provided for @terrainSelectSource.
  ///
  /// In en, this message translates to:
  /// **'Select a source tile'**
  String get terrainSelectSource;

  /// No description provided for @terrainRawTile.
  ///
  /// In en, this message translates to:
  /// **'Raw tile {raw} · group {group} · member {member}'**
  String terrainRawTile(String raw, String group, String member);

  /// No description provided for @terrainUnsupportedSuffix.
  ///
  /// In en, this message translates to:
  /// **' · unsupported'**
  String get terrainUnsupportedSuffix;

  /// No description provided for @terrainFromSuffix.
  ///
  /// In en, this message translates to:
  /// **' from {x},{y}'**
  String terrainFromSuffix(String x, String y);

  /// No description provided for @terrainToolSelect.
  ///
  /// In en, this message translates to:
  /// **'Select tile'**
  String get terrainToolSelect;

  /// No description provided for @terrainToolBrush.
  ///
  /// In en, this message translates to:
  /// **'Brush'**
  String get terrainToolBrush;

  /// No description provided for @terrainToolRectangle.
  ///
  /// In en, this message translates to:
  /// **'Rectangle'**
  String get terrainToolRectangle;

  /// No description provided for @terrainScope.
  ///
  /// In en, this message translates to:
  /// **'MTXM only · TILE/ISOM preserved'**
  String get terrainScope;

  /// No description provided for @paletteTitle.
  ///
  /// In en, this message translates to:
  /// **'Object Palette'**
  String get paletteTitle;

  /// No description provided for @paletteCatalogTooltip.
  ///
  /// In en, this message translates to:
  /// **'Place new Tile, Doodad, Unit or Sprite'**
  String get paletteCatalogTooltip;

  /// No description provided for @paletteCancelTooltip.
  ///
  /// In en, this message translates to:
  /// **'Cancel placement (Esc)'**
  String get paletteCancelTooltip;

  /// No description provided for @paletteSearchHint.
  ///
  /// In en, this message translates to:
  /// **'Search type or #id'**
  String get paletteSearchHint;

  /// No description provided for @paletteClickToPlace.
  ///
  /// In en, this message translates to:
  /// **'{label}: click map to place'**
  String paletteClickToPlace(String label);

  /// No description provided for @paletteEmpty.
  ///
  /// In en, this message translates to:
  /// **'No map-local object templates.'**
  String get paletteEmpty;

  /// No description provided for @paletteNoMatch.
  ///
  /// In en, this message translates to:
  /// **'No matching templates.'**
  String get paletteNoMatch;

  /// No description provided for @layerTerrain.
  ///
  /// In en, this message translates to:
  /// **'Terrain'**
  String get layerTerrain;

  /// No description provided for @layerLocations.
  ///
  /// In en, this message translates to:
  /// **'Locations'**
  String get layerLocations;

  /// No description provided for @layerDoodads.
  ///
  /// In en, this message translates to:
  /// **'Doodads'**
  String get layerDoodads;

  /// No description provided for @layerSprites.
  ///
  /// In en, this message translates to:
  /// **'Sprites'**
  String get layerSprites;

  /// No description provided for @layerUnits.
  ///
  /// In en, this message translates to:
  /// **'Units'**
  String get layerUnits;

  /// No description provided for @layerItems.
  ///
  /// In en, this message translates to:
  /// **'{count} items'**
  String layerItems(int count);

  /// No description provided for @layerHide.
  ///
  /// In en, this message translates to:
  /// **'Hide {layer}'**
  String layerHide(String layer);

  /// No description provided for @layerShow.
  ///
  /// In en, this message translates to:
  /// **'Show {layer}'**
  String layerShow(String layer);

  /// No description provided for @layerLock.
  ///
  /// In en, this message translates to:
  /// **'Lock {layer}'**
  String layerLock(String layer);

  /// No description provided for @layerUnlock.
  ///
  /// In en, this message translates to:
  /// **'Unlock {layer}'**
  String layerUnlock(String layer);

  /// No description provided for @layerSelectionHint.
  ///
  /// In en, this message translates to:
  /// **'Click the canvas to inspect the first unlocked object.'**
  String get layerSelectionHint;

  /// No description provided for @layerObjectsSelected.
  ///
  /// In en, this message translates to:
  /// **'{count} objects selected'**
  String layerObjectsSelected(int count);

  /// No description provided for @inspectorSourcePath.
  ///
  /// In en, this message translates to:
  /// **'Source path'**
  String get inspectorSourcePath;

  /// No description provided for @inspectorMapSize.
  ///
  /// In en, this message translates to:
  /// **'Map size'**
  String get inspectorMapSize;

  /// No description provided for @inspectorTileset.
  ///
  /// In en, this message translates to:
  /// **'Tileset'**
  String get inspectorTileset;

  /// No description provided for @inspectorMapVersion.
  ///
  /// In en, this message translates to:
  /// **'Map version'**
  String get inspectorMapVersion;

  /// No description provided for @inspectorScenarioType.
  ///
  /// In en, this message translates to:
  /// **'Scenario type'**
  String get inspectorScenarioType;

  /// No description provided for @inspectorTerrain.
  ///
  /// In en, this message translates to:
  /// **'Terrain'**
  String get inspectorTerrain;

  /// No description provided for @inspectorArchiveSize.
  ///
  /// In en, this message translates to:
  /// **'Archive size'**
  String get inspectorArchiveSize;

  /// No description provided for @inspectorEntries.
  ///
  /// In en, this message translates to:
  /// **'Entries'**
  String get inspectorEntries;

  /// No description provided for @inspectorChkSize.
  ///
  /// In en, this message translates to:
  /// **'CHK size'**
  String get inspectorChkSize;

  /// No description provided for @inspectorChkSections.
  ///
  /// In en, this message translates to:
  /// **'CHK sections'**
  String get inspectorChkSections;

  /// No description provided for @inspectorDiagnostics.
  ///
  /// In en, this message translates to:
  /// **'Diagnostics'**
  String get inspectorDiagnostics;

  /// No description provided for @valueUnavailable.
  ///
  /// In en, this message translates to:
  /// **'Unavailable'**
  String get valueUnavailable;

  /// No description provided for @valueUnknown.
  ///
  /// In en, this message translates to:
  /// **'Unknown ({value})'**
  String valueUnknown(String value);

  /// No description provided for @inspectorMtxmViews.
  ///
  /// In en, this message translates to:
  /// **'{count} MTXM views'**
  String inspectorMtxmViews(int count);

  /// No description provided for @inspectorRawTiles.
  ///
  /// In en, this message translates to:
  /// **'{count} raw tiles'**
  String inspectorRawTiles(int count);

  /// No description provided for @inspectorEntriesListed.
  ///
  /// In en, this message translates to:
  /// **'{listed} listed / {total}'**
  String inspectorEntriesListed(int listed, int total);

  /// No description provided for @inspectorCommonLayers.
  ///
  /// In en, this message translates to:
  /// **'Common layers'**
  String get inspectorCommonLayers;

  /// No description provided for @inspectorMultiNotice.
  ///
  /// In en, this message translates to:
  /// **'Select one object to edit its properties. Movement and deletion still apply to the full selection.'**
  String get inspectorMultiNotice;

  /// No description provided for @objectKindUnit.
  ///
  /// In en, this message translates to:
  /// **'Unit'**
  String get objectKindUnit;

  /// No description provided for @objectKindDoodad.
  ///
  /// In en, this message translates to:
  /// **'Doodad'**
  String get objectKindDoodad;

  /// No description provided for @objectKindSprite.
  ///
  /// In en, this message translates to:
  /// **'Sprite'**
  String get objectKindSprite;

  /// No description provided for @objectKindLocation.
  ///
  /// In en, this message translates to:
  /// **'Location'**
  String get objectKindLocation;

  /// No description provided for @fieldTypeId.
  ///
  /// In en, this message translates to:
  /// **'Type ID'**
  String get fieldTypeId;

  /// No description provided for @objectPlacedOnlyNotice.
  ///
  /// In en, this message translates to:
  /// **'Placed object only. Use File → Map Settings for map-wide unit types, players and game settings.'**
  String get objectPlacedOnlyNotice;

  /// No description provided for @fieldX.
  ///
  /// In en, this message translates to:
  /// **'X (px)'**
  String get fieldX;

  /// No description provided for @fieldY.
  ///
  /// In en, this message translates to:
  /// **'Y (px)'**
  String get fieldY;

  /// No description provided for @fieldOwnerRaw.
  ///
  /// In en, this message translates to:
  /// **'Owner (raw 0-255)'**
  String get fieldOwnerRaw;

  /// No description provided for @fieldHitpointPercent.
  ///
  /// In en, this message translates to:
  /// **'HP %'**
  String get fieldHitpointPercent;

  /// No description provided for @fieldShieldPercent.
  ///
  /// In en, this message translates to:
  /// **'Shield %'**
  String get fieldShieldPercent;

  /// No description provided for @fieldEnergyPercent.
  ///
  /// In en, this message translates to:
  /// **'Energy %'**
  String get fieldEnergyPercent;

  /// No description provided for @fieldResourceAmount.
  ///
  /// In en, this message translates to:
  /// **'Resource amount'**
  String get fieldResourceAmount;

  /// No description provided for @fieldHangarAmount.
  ///
  /// In en, this message translates to:
  /// **'Hangar amount'**
  String get fieldHangarAmount;

  /// No description provided for @fieldDoodadEnabledRaw.
  ///
  /// In en, this message translates to:
  /// **'Enabled raw (0=yes, 1=no)'**
  String get fieldDoodadEnabledRaw;

  /// No description provided for @applyProperties.
  ///
  /// In en, this message translates to:
  /// **'Apply properties'**
  String get applyProperties;

  /// No description provided for @enterWholeNumber.
  ///
  /// In en, this message translates to:
  /// **'Enter a whole number.'**
  String get enterWholeNumber;

  /// No description provided for @propertiesApplied.
  ///
  /// In en, this message translates to:
  /// **'Properties applied.'**
  String get propertiesApplied;

  /// No description provided for @propertiesNoChanges.
  ///
  /// In en, this message translates to:
  /// **'No property changes.'**
  String get propertiesNoChanges;

  /// No description provided for @fixHighlightedFields.
  ///
  /// In en, this message translates to:
  /// **'Fix the highlighted fields.'**
  String get fixHighlightedFields;

  /// No description provided for @propertiesUnavailable.
  ///
  /// In en, this message translates to:
  /// **'Property editing is no longer available.'**
  String get propertiesUnavailable;

  /// No description provided for @unlockToApply.
  ///
  /// In en, this message translates to:
  /// **'Unlock this layer and use an editable map to apply.'**
  String get unlockToApply;

  /// No description provided for @rawFieldsTitle.
  ///
  /// In en, this message translates to:
  /// **'Advanced: preserved raw fields'**
  String get rawFieldsTitle;

  /// No description provided for @rawFieldsNotice.
  ///
  /// In en, this message translates to:
  /// **'Raw flags and reserved fields are read-only and remain byte-exact.'**
  String get rawFieldsNotice;

  /// No description provided for @rawClassId.
  ///
  /// In en, this message translates to:
  /// **'Class ID'**
  String get rawClassId;

  /// No description provided for @rawRelationFlags.
  ///
  /// In en, this message translates to:
  /// **'Relation flags'**
  String get rawRelationFlags;

  /// No description provided for @rawValidStateFlags.
  ///
  /// In en, this message translates to:
  /// **'Valid state flags'**
  String get rawValidStateFlags;

  /// No description provided for @rawValidFieldFlags.
  ///
  /// In en, this message translates to:
  /// **'Valid field flags'**
  String get rawValidFieldFlags;

  /// No description provided for @rawStateFlags.
  ///
  /// In en, this message translates to:
  /// **'State flags'**
  String get rawStateFlags;

  /// No description provided for @rawUnused.
  ///
  /// In en, this message translates to:
  /// **'Unused'**
  String get rawUnused;

  /// No description provided for @rawRelationClassId.
  ///
  /// In en, this message translates to:
  /// **'Relation class ID'**
  String get rawRelationClassId;

  /// No description provided for @rawFlags.
  ///
  /// In en, this message translates to:
  /// **'Flags'**
  String get rawFlags;

  /// No description provided for @locationTitle.
  ///
  /// In en, this message translates to:
  /// **'Location {id}'**
  String locationTitle(String id);

  /// No description provided for @fieldName.
  ///
  /// In en, this message translates to:
  /// **'Name'**
  String get fieldName;

  /// No description provided for @fieldLeft.
  ///
  /// In en, this message translates to:
  /// **'Left'**
  String get fieldLeft;

  /// No description provided for @fieldTop.
  ///
  /// In en, this message translates to:
  /// **'Top'**
  String get fieldTop;

  /// No description provided for @fieldRight.
  ///
  /// In en, this message translates to:
  /// **'Right'**
  String get fieldRight;

  /// No description provided for @fieldBottom.
  ///
  /// In en, this message translates to:
  /// **'Bottom'**
  String get fieldBottom;

  /// No description provided for @applyLocation.
  ///
  /// In en, this message translates to:
  /// **'Apply location'**
  String get applyLocation;

  /// No description provided for @locationApplied.
  ///
  /// In en, this message translates to:
  /// **'Location applied.'**
  String get locationApplied;

  /// No description provided for @locationNoChanges.
  ///
  /// In en, this message translates to:
  /// **'No location changes.'**
  String get locationNoChanges;

  /// No description provided for @locationUnavailable.
  ///
  /// In en, this message translates to:
  /// **'Location editing is no longer available.'**
  String get locationUnavailable;

  /// No description provided for @inspectorStringId.
  ///
  /// In en, this message translates to:
  /// **'String ID'**
  String get inspectorStringId;

  /// No description provided for @inspectorElevationFlags.
  ///
  /// In en, this message translates to:
  /// **'Elevation flags'**
  String get inspectorElevationFlags;

  /// No description provided for @locationNamingUnavailable.
  ///
  /// In en, this message translates to:
  /// **'Location naming is unavailable for this map.'**
  String get locationNamingUnavailable;

  /// No description provided for @locationRenameNotice.
  ///
  /// In en, this message translates to:
  /// **'Renaming allocates a new string ID so shared map strings remain unchanged.'**
  String get locationRenameNotice;

  /// No description provided for @tabProblems.
  ///
  /// In en, this message translates to:
  /// **'Problems'**
  String get tabProblems;

  /// No description provided for @tabOutput.
  ///
  /// In en, this message translates to:
  /// **'Output'**
  String get tabOutput;

  /// No description provided for @tabBuildLog.
  ///
  /// In en, this message translates to:
  /// **'Build Log'**
  String get tabBuildLog;

  /// No description provided for @tabWithCount.
  ///
  /// In en, this message translates to:
  /// **'{label} ({count})'**
  String tabWithCount(String label, int count);

  /// No description provided for @noProblems.
  ///
  /// In en, this message translates to:
  /// **'No problems detected'**
  String get noProblems;

  /// No description provided for @noOutput.
  ///
  /// In en, this message translates to:
  /// **'No operation output'**
  String get noOutput;

  /// No description provided for @severityError.
  ///
  /// In en, this message translates to:
  /// **'Error'**
  String get severityError;

  /// No description provided for @severityWarning.
  ///
  /// In en, this message translates to:
  /// **'Warning'**
  String get severityWarning;

  /// No description provided for @severityInfo.
  ///
  /// In en, this message translates to:
  /// **'Info'**
  String get severityInfo;

  /// No description provided for @problemsSummary.
  ///
  /// In en, this message translates to:
  /// **'{errors} errors · {warnings} warnings · {infos} info'**
  String problemsSummary(int errors, int warnings, int infos);

  /// No description provided for @buildNotConfigured.
  ///
  /// In en, this message translates to:
  /// **'Build settings are not ready'**
  String get buildNotConfigured;

  /// No description provided for @buildReady.
  ///
  /// In en, this message translates to:
  /// **'Ready to build'**
  String get buildReady;

  /// No description provided for @buildStarting.
  ///
  /// In en, this message translates to:
  /// **'Starting euddraft…'**
  String get buildStarting;

  /// No description provided for @buildStopping.
  ///
  /// In en, this message translates to:
  /// **'Stopping euddraft…'**
  String get buildStopping;

  /// No description provided for @buildFinalizing.
  ///
  /// In en, this message translates to:
  /// **'Validating and promoting output…'**
  String get buildFinalizing;

  /// No description provided for @buildCompleted.
  ///
  /// In en, this message translates to:
  /// **'Build completed'**
  String get buildCompleted;

  /// No description provided for @buildFailedNoOutput.
  ///
  /// In en, this message translates to:
  /// **'Build failed without output'**
  String get buildFailedNoOutput;

  /// No description provided for @buildCancelled.
  ///
  /// In en, this message translates to:
  /// **'Build cancelled'**
  String get buildCancelled;

  /// No description provided for @logBuildId.
  ///
  /// In en, this message translates to:
  /// **'Build: {id}'**
  String logBuildId(String id);

  /// No description provided for @logTool.
  ///
  /// In en, this message translates to:
  /// **'Tool: euddraft {version}'**
  String logTool(String version);

  /// No description provided for @logExitCode.
  ///
  /// In en, this message translates to:
  /// **'exit code {code}'**
  String logExitCode(String code);

  /// No description provided for @logExitCodeUnavailable.
  ///
  /// In en, this message translates to:
  /// **'exit code unavailable'**
  String get logExitCodeUnavailable;

  /// No description provided for @logStarted.
  ///
  /// In en, this message translates to:
  /// **'Started: {time}'**
  String logStarted(String time);

  /// No description provided for @logCompleted.
  ///
  /// In en, this message translates to:
  /// **'Completed: {time}'**
  String logCompleted(String time);

  /// No description provided for @recordRunning.
  ///
  /// In en, this message translates to:
  /// **'Running'**
  String get recordRunning;

  /// No description provided for @recordSucceeded.
  ///
  /// In en, this message translates to:
  /// **'Succeeded'**
  String get recordSucceeded;

  /// No description provided for @recordFailed.
  ///
  /// In en, this message translates to:
  /// **'Failed'**
  String get recordFailed;

  /// No description provided for @recordCancelled.
  ///
  /// In en, this message translates to:
  /// **'Cancelled'**
  String get recordCancelled;

  /// No description provided for @statusReady.
  ///
  /// In en, this message translates to:
  /// **'Ready'**
  String get statusReady;

  /// No description provided for @statusNoDocument.
  ///
  /// In en, this message translates to:
  /// **'No document'**
  String get statusNoDocument;

  /// No description provided for @statusDocument.
  ///
  /// In en, this message translates to:
  /// **'{name} • {state}'**
  String statusDocument(String name, String state);

  /// No description provided for @phaseQueued.
  ///
  /// In en, this message translates to:
  /// **'Queued'**
  String get phaseQueued;

  /// No description provided for @phaseReading.
  ///
  /// In en, this message translates to:
  /// **'Reading'**
  String get phaseReading;

  /// No description provided for @phaseParsing.
  ///
  /// In en, this message translates to:
  /// **'Parsing'**
  String get phaseParsing;

  /// No description provided for @phaseValidating.
  ///
  /// In en, this message translates to:
  /// **'Validating'**
  String get phaseValidating;

  /// No description provided for @phaseWriting.
  ///
  /// In en, this message translates to:
  /// **'Writing'**
  String get phaseWriting;

  /// No description provided for @phaseCompiling.
  ///
  /// In en, this message translates to:
  /// **'Compiling'**
  String get phaseCompiling;

  /// No description provided for @phaseVerifying.
  ///
  /// In en, this message translates to:
  /// **'Verifying'**
  String get phaseVerifying;

  /// No description provided for @phaseSucceeded.
  ///
  /// In en, this message translates to:
  /// **'Completed'**
  String get phaseSucceeded;

  /// No description provided for @phaseFailed.
  ///
  /// In en, this message translates to:
  /// **'Failed'**
  String get phaseFailed;

  /// No description provided for @phaseCancelled.
  ///
  /// In en, this message translates to:
  /// **'Cancelled'**
  String get phaseCancelled;

  /// No description provided for @triggersOrdinary.
  ///
  /// In en, this message translates to:
  /// **'Ordinary triggers'**
  String get triggersOrdinary;

  /// No description provided for @triggersEudExtensions.
  ///
  /// In en, this message translates to:
  /// **'EUD extensions'**
  String get triggersEudExtensions;

  /// No description provided for @triggersOpenEudProject.
  ///
  /// In en, this message translates to:
  /// **'Open EUD Project to create, save or build rules'**
  String get triggersOpenEudProject;

  /// No description provided for @triggersUndoProject.
  ///
  /// In en, this message translates to:
  /// **'Undo project'**
  String get triggersUndoProject;

  /// No description provided for @triggersRedoProject.
  ///
  /// In en, this message translates to:
  /// **'Redo project'**
  String get triggersRedoProject;

  /// No description provided for @triggersEudUnavailable.
  ///
  /// In en, this message translates to:
  /// **'EUD project workspace unavailable.'**
  String get triggersEudUnavailable;

  /// No description provided for @terrainDataTitle.
  ///
  /// In en, this message translates to:
  /// **'Editor terrain data'**
  String get terrainDataTitle;

  /// No description provided for @terrainDataProtected.
  ///
  /// In en, this message translates to:
  /// **'EUD protection marker; not an ISOM grid'**
  String get terrainDataProtected;

  /// No description provided for @terrainDataIsomPresent.
  ///
  /// In en, this message translates to:
  /// **'ISOM present — generation not verified'**
  String get terrainDataIsomPresent;

  /// No description provided for @terrainDataNoIsom.
  ///
  /// In en, this message translates to:
  /// **'No ISOM — raw tile editing'**
  String get terrainDataNoIsom;

  /// No description provided for @terrainDataBytes.
  ///
  /// In en, this message translates to:
  /// **'{actual} bytes / expected {expected}'**
  String terrainDataBytes(int actual, String expected);

  /// No description provided for @terrainDataStructureOnly.
  ///
  /// In en, this message translates to:
  /// **'Size matches; terrain meaning is not validated'**
  String get terrainDataStructureOnly;

  /// No description provided for @terrainDataInvalidSize.
  ///
  /// In en, this message translates to:
  /// **'Size mismatch — original bytes preserved'**
  String get terrainDataInvalidSize;

  /// No description provided for @terrainDataUnknownDimensions.
  ///
  /// In en, this message translates to:
  /// **'A single valid DIM section is required'**
  String get terrainDataUnknownDimensions;

  /// No description provided for @terrainDataDuplicates.
  ///
  /// In en, this message translates to:
  /// **'Duplicate sections: {names}. No active copy selected.'**
  String terrainDataDuplicates(String names);

  /// No description provided for @terrainDataComparisonUnavailable.
  ///
  /// In en, this message translates to:
  /// **'MTXM / TILE comparison unavailable'**
  String get terrainDataComparisonUnavailable;

  /// No description provided for @terrainDataDifference.
  ///
  /// In en, this message translates to:
  /// **'MTXM / TILE differ in {count} cells. Differences alone do not mean corruption.'**
  String terrainDataDifference(int count);

  /// No description provided for @terrainDataDoodads.
  ///
  /// In en, this message translates to:
  /// **'Doodads exist; their terrain may differ from editor tiles.'**
  String get terrainDataDoodads;

  /// No description provided for @terrainDataReadOnly.
  ///
  /// In en, this message translates to:
  /// **'Read-only inspection. Raw brushes change MTXM only; TILE/ISOM are preserved. Isometric and ramp generation is not available yet.'**
  String get terrainDataReadOnly;

  /// No description provided for @newMapTitle.
  ///
  /// In en, this message translates to:
  /// **'New Map'**
  String get newMapTitle;

  /// No description provided for @newMapStepBasics.
  ///
  /// In en, this message translates to:
  /// **'Size and terrain'**
  String get newMapStepBasics;

  /// No description provided for @newMapStepPlayers.
  ///
  /// In en, this message translates to:
  /// **'Players'**
  String get newMapStepPlayers;

  /// No description provided for @newMapStepReview.
  ///
  /// In en, this message translates to:
  /// **'Review and create'**
  String get newMapStepReview;

  /// No description provided for @newMapStepCurrent.
  ///
  /// In en, this message translates to:
  /// **'Current step'**
  String get newMapStepCurrent;

  /// No description provided for @newMapSideNote.
  ///
  /// In en, this message translates to:
  /// **'You can resize the map later from File → Resize Map. A new map is saved for the first time with Save As.'**
  String get newMapSideNote;

  /// No description provided for @newMapName.
  ///
  /// In en, this message translates to:
  /// **'Map title'**
  String get newMapName;

  /// No description provided for @newMapDefaultTitle.
  ///
  /// In en, this message translates to:
  /// **'Untitled Scenario'**
  String get newMapDefaultTitle;

  /// No description provided for @newMapDescription.
  ///
  /// In en, this message translates to:
  /// **'Description (optional)'**
  String get newMapDescription;

  /// No description provided for @newMapSize.
  ///
  /// In en, this message translates to:
  /// **'Size'**
  String get newMapSize;

  /// No description provided for @newMapSizeSmall.
  ///
  /// In en, this message translates to:
  /// **'Small'**
  String get newMapSizeSmall;

  /// No description provided for @newMapSizeSmallNote.
  ///
  /// In en, this message translates to:
  /// **'1 vs 1 practice'**
  String get newMapSizeSmallNote;

  /// No description provided for @newMapSizeCompact.
  ///
  /// In en, this message translates to:
  /// **'Compact'**
  String get newMapSizeCompact;

  /// No description provided for @newMapSizeCompactNote.
  ///
  /// In en, this message translates to:
  /// **'2 players'**
  String get newMapSizeCompactNote;

  /// No description provided for @newMapSizeMedium.
  ///
  /// In en, this message translates to:
  /// **'Medium'**
  String get newMapSizeMedium;

  /// No description provided for @newMapSizeMediumNote.
  ///
  /// In en, this message translates to:
  /// **'Recommended for 4'**
  String get newMapSizeMediumNote;

  /// No description provided for @newMapSizeLarge.
  ///
  /// In en, this message translates to:
  /// **'Large'**
  String get newMapSizeLarge;

  /// No description provided for @newMapSizeLargeNote.
  ///
  /// In en, this message translates to:
  /// **'6–8 players'**
  String get newMapSizeLargeNote;

  /// No description provided for @newMapSizeHuge.
  ///
  /// In en, this message translates to:
  /// **'Huge'**
  String get newMapSizeHuge;

  /// No description provided for @newMapSizeHugeNote.
  ///
  /// In en, this message translates to:
  /// **'Large UMS'**
  String get newMapSizeHugeNote;

  /// No description provided for @newMapSizeCustom.
  ///
  /// In en, this message translates to:
  /// **'Custom'**
  String get newMapSizeCustom;

  /// No description provided for @newMapSizeCustomNote.
  ///
  /// In en, this message translates to:
  /// **'Up to 256'**
  String get newMapSizeCustomNote;

  /// No description provided for @newMapWidth.
  ///
  /// In en, this message translates to:
  /// **'Width (tiles)'**
  String get newMapWidth;

  /// No description provided for @newMapHeight.
  ///
  /// In en, this message translates to:
  /// **'Height (tiles)'**
  String get newMapHeight;

  /// No description provided for @newMapSizeValue.
  ///
  /// In en, this message translates to:
  /// **'{width} × {height}'**
  String newMapSizeValue(int width, int height);

  /// No description provided for @newMapTileset.
  ///
  /// In en, this message translates to:
  /// **'Tileset'**
  String get newMapTileset;

  /// No description provided for @newMapTilesetHint.
  ///
  /// In en, this message translates to:
  /// **'The look of the whole map. It cannot be changed after creation.'**
  String get newMapTilesetHint;

  /// No description provided for @tilesetBadlands.
  ///
  /// In en, this message translates to:
  /// **'Badlands'**
  String get tilesetBadlands;

  /// No description provided for @tilesetSpacePlatform.
  ///
  /// In en, this message translates to:
  /// **'Space Platform'**
  String get tilesetSpacePlatform;

  /// No description provided for @tilesetInstallation.
  ///
  /// In en, this message translates to:
  /// **'Installation'**
  String get tilesetInstallation;

  /// No description provided for @tilesetAshworld.
  ///
  /// In en, this message translates to:
  /// **'Ashworld'**
  String get tilesetAshworld;

  /// No description provided for @tilesetJungle.
  ///
  /// In en, this message translates to:
  /// **'Jungle'**
  String get tilesetJungle;

  /// No description provided for @tilesetDesert.
  ///
  /// In en, this message translates to:
  /// **'Desert'**
  String get tilesetDesert;

  /// No description provided for @tilesetIce.
  ///
  /// In en, this message translates to:
  /// **'Ice'**
  String get tilesetIce;

  /// No description provided for @tilesetTwilight.
  ///
  /// In en, this message translates to:
  /// **'Twilight'**
  String get tilesetTwilight;

  /// No description provided for @newMapInitialTile.
  ///
  /// In en, this message translates to:
  /// **'Starting tile'**
  String get newMapInitialTile;

  /// No description provided for @newMapInitialTileHint.
  ///
  /// In en, this message translates to:
  /// **'The whole map is filled with this raw tile. ISOM terrain is not generated, so walkability is not guaranteed.'**
  String get newMapInitialTileHint;

  /// No description provided for @newMapTileRequired.
  ///
  /// In en, this message translates to:
  /// **'Pick a starting tile to create the map.'**
  String get newMapTileRequired;

  /// No description provided for @newMapTilesLoading.
  ///
  /// In en, this message translates to:
  /// **'Loading tiles from StarCraft data…'**
  String get newMapTilesLoading;

  /// No description provided for @newMapTilePage.
  ///
  /// In en, this message translates to:
  /// **'{first}–{last} of {total}'**
  String newMapTilePage(int first, int last, int total);

  /// No description provided for @newMapPrevious.
  ///
  /// In en, this message translates to:
  /// **'Previous'**
  String get newMapPrevious;

  /// No description provided for @newMapNext.
  ///
  /// In en, this message translates to:
  /// **'Next'**
  String get newMapNext;

  /// No description provided for @newMapReload.
  ///
  /// In en, this message translates to:
  /// **'Reload'**
  String get newMapReload;

  /// No description provided for @newMapPlayersTitle.
  ///
  /// In en, this message translates to:
  /// **'How many people will play?'**
  String get newMapPlayersTitle;

  /// No description provided for @newMapPlayersHint.
  ///
  /// In en, this message translates to:
  /// **'Each human player gets a Terran start location. You can change races and slots later in Player Settings.'**
  String get newMapPlayersHint;

  /// No description provided for @newMapPlayersValue.
  ///
  /// In en, this message translates to:
  /// **'{players} players'**
  String newMapPlayersValue(int players);

  /// No description provided for @newMapReviewTitle.
  ///
  /// In en, this message translates to:
  /// **'Ready to create'**
  String get newMapReviewTitle;

  /// No description provided for @newMapReviewFormat.
  ///
  /// In en, this message translates to:
  /// **'Brood War UMS (.scx)'**
  String get newMapReviewFormat;

  /// No description provided for @newMapReviewNoTriggers.
  ///
  /// In en, this message translates to:
  /// **'No victory or resource triggers are added. Add them in Triggers.'**
  String get newMapReviewNoTriggers;

  /// No description provided for @newMapReviewTile.
  ///
  /// In en, this message translates to:
  /// **'Starting tile #{tile}'**
  String newMapReviewTile(String tile);

  /// No description provided for @newMapReviewNoTile.
  ///
  /// In en, this message translates to:
  /// **'No starting tile yet'**
  String get newMapReviewNoTile;

  /// No description provided for @newMapCancel.
  ///
  /// In en, this message translates to:
  /// **'Cancel'**
  String get newMapCancel;

  /// No description provided for @newMapBack.
  ///
  /// In en, this message translates to:
  /// **'Back'**
  String get newMapBack;

  /// No description provided for @newMapContinue.
  ///
  /// In en, this message translates to:
  /// **'Next'**
  String get newMapContinue;

  /// No description provided for @newMapCreate.
  ///
  /// In en, this message translates to:
  /// **'Create'**
  String get newMapCreate;

  /// No description provided for @newMapDiscardTitle.
  ///
  /// In en, this message translates to:
  /// **'Discard unsaved map changes?'**
  String get newMapDiscardTitle;

  /// No description provided for @newMapDiscardBody.
  ///
  /// In en, this message translates to:
  /// **'Creating a new map replaces the current document. Save it first if you want to keep these changes.'**
  String get newMapDiscardBody;

  /// No description provided for @newMapKeepCurrent.
  ///
  /// In en, this message translates to:
  /// **'Keep current map'**
  String get newMapKeepCurrent;

  /// No description provided for @newMapDiscardAndCreate.
  ///
  /// In en, this message translates to:
  /// **'Discard and create'**
  String get newMapDiscardAndCreate;

  /// No description provided for @catalogTitle.
  ///
  /// In en, this message translates to:
  /// **'What to place'**
  String get catalogTitle;

  /// No description provided for @catalogKindTile.
  ///
  /// In en, this message translates to:
  /// **'Terrain tiles'**
  String get catalogKindTile;

  /// No description provided for @catalogKindDoodad.
  ///
  /// In en, this message translates to:
  /// **'Doodads'**
  String get catalogKindDoodad;

  /// No description provided for @catalogKindUnit.
  ///
  /// In en, this message translates to:
  /// **'Units'**
  String get catalogKindUnit;

  /// No description provided for @catalogKindSprite.
  ///
  /// In en, this message translates to:
  /// **'Sprites'**
  String get catalogKindSprite;

  /// No description provided for @catalogKindSpriteUnit.
  ///
  /// In en, this message translates to:
  /// **'Sprite-units'**
  String get catalogKindSpriteUnit;

  /// No description provided for @catalogCategories.
  ///
  /// In en, this message translates to:
  /// **'Categories'**
  String get catalogCategories;

  /// No description provided for @catalogCategoryAll.
  ///
  /// In en, this message translates to:
  /// **'All'**
  String get catalogCategoryAll;

  /// No description provided for @catalogTilesetTitle.
  ///
  /// In en, this message translates to:
  /// **'{tileset} map'**
  String catalogTilesetTitle(String tileset);

  /// No description provided for @catalogTilesetHint.
  ///
  /// In en, this message translates to:
  /// **'Only entries that match this map\'s tileset are shown.'**
  String get catalogTilesetHint;

  /// No description provided for @catalogSearchHint.
  ///
  /// In en, this message translates to:
  /// **'Search by name, #ID or type (e.g. Bunker, #125)'**
  String get catalogSearchHint;

  /// No description provided for @catalogBackToMap.
  ///
  /// In en, this message translates to:
  /// **'Back to map'**
  String get catalogBackToMap;

  /// No description provided for @catalogPlaceableOnly.
  ///
  /// In en, this message translates to:
  /// **'Placeable only'**
  String get catalogPlaceableOnly;

  /// No description provided for @catalogShownCount.
  ///
  /// In en, this message translates to:
  /// **'{count} shown'**
  String catalogShownCount(int count);

  /// No description provided for @catalogEmpty.
  ///
  /// In en, this message translates to:
  /// **'No catalog entry matches this search.'**
  String get catalogEmpty;

  /// No description provided for @catalogDetailEmpty.
  ///
  /// In en, this message translates to:
  /// **'Select an entry to see its details and place it.'**
  String get catalogDetailEmpty;

  /// No description provided for @catalogFootprint.
  ///
  /// In en, this message translates to:
  /// **'Footprint {width} × {height} tiles'**
  String catalogFootprint(int width, int height);

  /// No description provided for @catalogFootprintOverlay.
  ///
  /// In en, this message translates to:
  /// **'Footprint {width} × {height} tiles + overlay'**
  String catalogFootprintOverlay(int width, int height);

  /// No description provided for @catalogOwner.
  ///
  /// In en, this message translates to:
  /// **'Who owns it?'**
  String get catalogOwner;

  /// No description provided for @catalogOwnerPlayer.
  ///
  /// In en, this message translates to:
  /// **'Player {count}'**
  String catalogOwnerPlayer(int count);

  /// No description provided for @catalogKeepPlacing.
  ///
  /// In en, this message translates to:
  /// **'Keep placing on each click'**
  String get catalogKeepPlacing;

  /// No description provided for @catalogHowTo.
  ///
  /// In en, this message translates to:
  /// **'How to place'**
  String get catalogHowTo;

  /// No description provided for @catalogHowTo1.
  ///
  /// In en, this message translates to:
  /// **'1. Press the button below to return to the map.'**
  String get catalogHowTo1;

  /// No description provided for @catalogHowTo2.
  ///
  /// In en, this message translates to:
  /// **'2. Click where the outline is shown to place it.'**
  String get catalogHowTo2;

  /// No description provided for @catalogHowTo3.
  ///
  /// In en, this message translates to:
  /// **'3. A red outline is outside the map. Press Esc to cancel.'**
  String get catalogHowTo3;

  /// No description provided for @catalogPlace.
  ///
  /// In en, this message translates to:
  /// **'Place on map'**
  String get catalogPlace;

  /// No description provided for @catalogCannotPlace.
  ///
  /// In en, this message translates to:
  /// **'This entry cannot be placed.'**
  String get catalogCannotPlace;

  /// No description provided for @catalogIssueRelation.
  ///
  /// In en, this message translates to:
  /// **'Add-ons and similar units need another building, so they cannot be placed on their own.'**
  String get catalogIssueRelation;

  /// No description provided for @catalogIssueCapability.
  ///
  /// In en, this message translates to:
  /// **'The unit data could not be read from the local game files, so placement is locked.'**
  String get catalogIssueCapability;

  /// No description provided for @catalogIssueGraphic.
  ///
  /// In en, this message translates to:
  /// **'The graphic could not be loaded, so the entry is locked to avoid invisible objects.'**
  String get catalogIssueGraphic;

  /// No description provided for @catalogIssueRecipe.
  ///
  /// In en, this message translates to:
  /// **'The doodad layout data is incomplete, so it cannot be placed safely.'**
  String get catalogIssueRecipe;

  /// No description provided for @catalogIssueCode.
  ///
  /// In en, this message translates to:
  /// **'Code: {code}'**
  String catalogIssueCode(String code);

  /// No description provided for @buildStepsLabel.
  ///
  /// In en, this message translates to:
  /// **'Steps to an EUD map'**
  String get buildStepsLabel;

  /// No description provided for @buildStepMap.
  ///
  /// In en, this message translates to:
  /// **'Save the map'**
  String get buildStepMap;

  /// No description provided for @buildStepMapNone.
  ///
  /// In en, this message translates to:
  /// **'No map is open'**
  String get buildStepMapNone;

  /// No description provided for @buildStepMapDirty.
  ///
  /// In en, this message translates to:
  /// **'Unsaved changes · use Save As'**
  String get buildStepMapDirty;

  /// No description provided for @buildStepMapSaved.
  ///
  /// In en, this message translates to:
  /// **'Saved'**
  String get buildStepMapSaved;

  /// No description provided for @buildStepSource.
  ///
  /// In en, this message translates to:
  /// **'Save the script'**
  String get buildStepSource;

  /// No description provided for @buildStepSourceUntitled.
  ///
  /// In en, this message translates to:
  /// **'Save it as a file to build'**
  String get buildStepSourceUntitled;

  /// No description provided for @buildStepSourceDirty.
  ///
  /// In en, this message translates to:
  /// **'Not saved yet'**
  String get buildStepSourceDirty;

  /// No description provided for @buildStepSourceSaved.
  ///
  /// In en, this message translates to:
  /// **'Saved'**
  String get buildStepSourceSaved;

  /// No description provided for @buildStepPrepare.
  ///
  /// In en, this message translates to:
  /// **'Prepare the build'**
  String get buildStepPrepare;

  /// No description provided for @buildStepPrepareNeeded.
  ///
  /// In en, this message translates to:
  /// **'Choose input and output files'**
  String get buildStepPrepareNeeded;

  /// No description provided for @buildStepPrepareReady.
  ///
  /// In en, this message translates to:
  /// **'Ready'**
  String get buildStepPrepareReady;

  /// No description provided for @buildStepPrepareAction.
  ///
  /// In en, this message translates to:
  /// **'Prepare…'**
  String get buildStepPrepareAction;

  /// No description provided for @buildStepRun.
  ///
  /// In en, this message translates to:
  /// **'Build'**
  String get buildStepRun;

  /// No description provided for @buildStepRunReady.
  ///
  /// In en, this message translates to:
  /// **'Ready to run'**
  String get buildStepRunReady;

  /// No description provided for @buildStepRunBusy.
  ///
  /// In en, this message translates to:
  /// **'Building…'**
  String get buildStepRunBusy;

  /// No description provided for @buildStepRunSucceeded.
  ///
  /// In en, this message translates to:
  /// **'Succeeded'**
  String get buildStepRunSucceeded;

  /// No description provided for @buildStepRunFailed.
  ///
  /// In en, this message translates to:
  /// **'Failed · see the result below'**
  String get buildStepRunFailed;

  /// No description provided for @buildStepRunCancelled.
  ///
  /// In en, this message translates to:
  /// **'Cancelled'**
  String get buildStepRunCancelled;

  /// No description provided for @buildStepRunBlocked.
  ///
  /// In en, this message translates to:
  /// **'Finish the earlier steps first'**
  String get buildStepRunBlocked;

  /// No description provided for @buildSafetyNote.
  ///
  /// In en, this message translates to:
  /// **'The original map is never overwritten'**
  String get buildSafetyNote;

  /// No description provided for @buildSummarySucceeded.
  ///
  /// In en, this message translates to:
  /// **'The EUD map was built'**
  String get buildSummarySucceeded;

  /// No description provided for @buildSummaryFailed.
  ///
  /// In en, this message translates to:
  /// **'The build did not finish'**
  String get buildSummaryFailed;

  /// No description provided for @buildSummaryCancelled.
  ///
  /// In en, this message translates to:
  /// **'The build was cancelled'**
  String get buildSummaryCancelled;

  /// No description provided for @buildSummaryRunning.
  ///
  /// In en, this message translates to:
  /// **'Building with euddraft…'**
  String get buildSummaryRunning;

  /// No description provided for @buildSummaryFirstError.
  ///
  /// In en, this message translates to:
  /// **'First problem: {message}'**
  String buildSummaryFirstError(String message);

  /// No description provided for @buildSummaryAt.
  ///
  /// In en, this message translates to:
  /// **'{location}: {message}'**
  String buildSummaryAt(String location, String message);

  /// No description provided for @buildSummaryUnchanged.
  ///
  /// In en, this message translates to:
  /// **'The original map and earlier output were left unchanged.'**
  String get buildSummaryUnchanged;

  /// No description provided for @buildSummaryRawLog.
  ///
  /// In en, this message translates to:
  /// **'Raw euddraft log below'**
  String get buildSummaryRawLog;
}

class _AppLocalizationsDelegate
    extends LocalizationsDelegate<AppLocalizations> {
  const _AppLocalizationsDelegate();

  @override
  Future<AppLocalizations> load(Locale locale) {
    return SynchronousFuture<AppLocalizations>(lookupAppLocalizations(locale));
  }

  @override
  bool isSupported(Locale locale) =>
      <String>['en', 'ko'].contains(locale.languageCode);

  @override
  bool shouldReload(_AppLocalizationsDelegate old) => false;
}

AppLocalizations lookupAppLocalizations(Locale locale) {
  // Lookup logic when only language code is specified.
  switch (locale.languageCode) {
    case 'en':
      return AppLocalizationsEn();
    case 'ko':
      return AppLocalizationsKo();
  }

  throw FlutterError(
    'AppLocalizations.delegate failed to load unsupported locale "$locale". This is likely '
    'an issue with the localizations generation tool. Please file an issue '
    'on GitHub with a reproducible sample app and the gen-l10n configuration '
    'that was used.',
  );
}
