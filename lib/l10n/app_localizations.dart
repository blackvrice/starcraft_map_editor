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
