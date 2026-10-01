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

  /// No description provided for @trigTitle.
  ///
  /// In en, this message translates to:
  /// **'Triggers'**
  String get trigTitle;

  /// No description provided for @trigBriefingTitle.
  ///
  /// In en, this message translates to:
  /// **'Briefing'**
  String get trigBriefingTitle;

  /// No description provided for @trigCount.
  ///
  /// In en, this message translates to:
  /// **'{count} total'**
  String trigCount(int count);

  /// No description provided for @trigAdd.
  ///
  /// In en, this message translates to:
  /// **'Add trigger'**
  String get trigAdd;

  /// No description provided for @trigAddBriefing.
  ///
  /// In en, this message translates to:
  /// **'Add briefing'**
  String get trigAddBriefing;

  /// No description provided for @trigUndo.
  ///
  /// In en, this message translates to:
  /// **'Undo'**
  String get trigUndo;

  /// No description provided for @trigRedo.
  ///
  /// In en, this message translates to:
  /// **'Redo'**
  String get trigRedo;

  /// No description provided for @trigValidate.
  ///
  /// In en, this message translates to:
  /// **'Validate references'**
  String get trigValidate;

  /// No description provided for @trigSelectAll.
  ///
  /// In en, this message translates to:
  /// **'Select all / none'**
  String get trigSelectAll;

  /// No description provided for @trigOwners.
  ///
  /// In en, this message translates to:
  /// **'Owners…'**
  String get trigOwners;

  /// No description provided for @trigEnableSelected.
  ///
  /// In en, this message translates to:
  /// **'Enable selected'**
  String get trigEnableSelected;

  /// No description provided for @trigDisableSelected.
  ///
  /// In en, this message translates to:
  /// **'Disable selected'**
  String get trigDisableSelected;

  /// No description provided for @trigAddText.
  ///
  /// In en, this message translates to:
  /// **'Add text…'**
  String get trigAddText;

  /// No description provided for @trigSwitchNames.
  ///
  /// In en, this message translates to:
  /// **'Switch names…'**
  String get trigSwitchNames;

  /// No description provided for @trigUnitProperties.
  ///
  /// In en, this message translates to:
  /// **'Unit properties…'**
  String get trigUnitProperties;

  /// No description provided for @trigSelectedCount.
  ///
  /// In en, this message translates to:
  /// **'{count} selected'**
  String trigSelectedCount(int count);

  /// No description provided for @trigHelp.
  ///
  /// In en, this message translates to:
  /// **'Each trigger runs its actions when all of its conditions are true. New triggers start with “Never”, so they do nothing until you change the condition. Save As writes applied changes.'**
  String get trigHelp;

  /// No description provided for @trigBriefingHelp.
  ///
  /// In en, this message translates to:
  /// **'Briefing actions play in order before the game starts. Times are in milliseconds and portrait slots are 1–4. Add sounds in Resources.'**
  String get trigBriefingHelp;

  /// No description provided for @trigEmpty.
  ///
  /// In en, this message translates to:
  /// **'No triggers yet. Add one to start.'**
  String get trigEmpty;

  /// No description provided for @trigItemTitle.
  ///
  /// In en, this message translates to:
  /// **'Trigger {count}'**
  String trigItemTitle(int count);

  /// No description provided for @trigBriefingItemTitle.
  ///
  /// In en, this message translates to:
  /// **'Briefing {count}'**
  String trigBriefingItemTitle(int count);

  /// No description provided for @trigOn.
  ///
  /// In en, this message translates to:
  /// **'On'**
  String get trigOn;

  /// No description provided for @trigOff.
  ///
  /// In en, this message translates to:
  /// **'Off'**
  String get trigOff;

  /// No description provided for @trigNoOwner.
  ///
  /// In en, this message translates to:
  /// **'No one runs it'**
  String get trigNoOwner;

  /// No description provided for @trigWhen.
  ///
  /// In en, this message translates to:
  /// **'When'**
  String get trigWhen;

  /// No description provided for @trigThen.
  ///
  /// In en, this message translates to:
  /// **'Then'**
  String get trigThen;

  /// No description provided for @trigNothing.
  ///
  /// In en, this message translates to:
  /// **'Nothing'**
  String get trigNothing;

  /// No description provided for @trigMore.
  ///
  /// In en, this message translates to:
  /// **'+{count} more'**
  String trigMore(int count);

  /// No description provided for @trigMoveUp.
  ///
  /// In en, this message translates to:
  /// **'Move up'**
  String get trigMoveUp;

  /// No description provided for @trigMoveDown.
  ///
  /// In en, this message translates to:
  /// **'Move down'**
  String get trigMoveDown;

  /// No description provided for @trigDuplicate.
  ///
  /// In en, this message translates to:
  /// **'Duplicate trigger'**
  String get trigDuplicate;

  /// No description provided for @trigDuplicateBriefing.
  ///
  /// In en, this message translates to:
  /// **'Duplicate briefing'**
  String get trigDuplicateBriefing;

  /// No description provided for @trigDelete.
  ///
  /// In en, this message translates to:
  /// **'Delete trigger'**
  String get trigDelete;

  /// No description provided for @trigDeleteBriefing.
  ///
  /// In en, this message translates to:
  /// **'Delete briefing'**
  String get trigDeleteBriefing;

  /// No description provided for @trigDeleteTitle.
  ///
  /// In en, this message translates to:
  /// **'Delete {name}?'**
  String trigDeleteTitle(String name);

  /// No description provided for @trigDeleteBody.
  ///
  /// In en, this message translates to:
  /// **'The entire record, including preserved unsupported slots, will be removed. Undo restores it.'**
  String get trigDeleteBody;

  /// No description provided for @trigCancel.
  ///
  /// In en, this message translates to:
  /// **'Cancel'**
  String get trigCancel;

  /// No description provided for @trigDeleteConfirm.
  ///
  /// In en, this message translates to:
  /// **'Delete'**
  String get trigDeleteConfirm;

  /// No description provided for @trigClose.
  ///
  /// In en, this message translates to:
  /// **'Close'**
  String get trigClose;

  /// No description provided for @trigValidationTitle.
  ///
  /// In en, this message translates to:
  /// **'Trigger validation'**
  String get trigValidationTitle;

  /// No description provided for @trigValidationOk.
  ///
  /// In en, this message translates to:
  /// **'Supported slots have valid field values and references. Raw/EUD slots are not interpreted.'**
  String get trigValidationOk;

  /// No description provided for @trigOwnersTitle.
  ///
  /// In en, this message translates to:
  /// **'Who runs the selected triggers?'**
  String get trigOwnersTitle;

  /// No description provided for @trigOwnersBriefingTitle.
  ///
  /// In en, this message translates to:
  /// **'Who sees the selected briefings?'**
  String get trigOwnersBriefingTitle;

  /// No description provided for @trigOwnersHelp.
  ///
  /// In en, this message translates to:
  /// **'“Unchanged” keeps each trigger’s current setting. Choose Add or Remove to change it.'**
  String get trigOwnersHelp;

  /// No description provided for @trigOwnerUnchanged.
  ///
  /// In en, this message translates to:
  /// **'Unchanged'**
  String get trigOwnerUnchanged;

  /// No description provided for @trigOwnerAdd.
  ///
  /// In en, this message translates to:
  /// **'Add'**
  String get trigOwnerAdd;

  /// No description provided for @trigOwnerRemove.
  ///
  /// In en, this message translates to:
  /// **'Remove'**
  String get trigOwnerRemove;

  /// No description provided for @trigApplyOwners.
  ///
  /// In en, this message translates to:
  /// **'Apply owners'**
  String get trigApplyOwners;

  /// No description provided for @trigEditTitle.
  ///
  /// In en, this message translates to:
  /// **'Edit trigger'**
  String get trigEditTitle;

  /// No description provided for @trigEditBriefingTitle.
  ///
  /// In en, this message translates to:
  /// **'Edit briefing'**
  String get trigEditBriefingTitle;

  /// No description provided for @trigDraftNote.
  ///
  /// In en, this message translates to:
  /// **'Changes stay in this draft until you press Apply to map. Unsupported slots and flags are preserved byte for byte.'**
  String get trigDraftNote;

  /// No description provided for @trigWho.
  ///
  /// In en, this message translates to:
  /// **'Who runs it?'**
  String get trigWho;

  /// No description provided for @trigWhoHelp.
  ///
  /// In en, this message translates to:
  /// **'The trigger is checked separately for each selected player. “Current player” in conditions and actions means that player.'**
  String get trigWhoHelp;

  /// No description provided for @trigEnabledChip.
  ///
  /// In en, this message translates to:
  /// **'Trigger enabled'**
  String get trigEnabledChip;

  /// No description provided for @trigBriefingEnabledChip.
  ///
  /// In en, this message translates to:
  /// **'Briefing enabled'**
  String get trigBriefingEnabledChip;

  /// No description provided for @trigWhenAll.
  ///
  /// In en, this message translates to:
  /// **'all of these are true'**
  String get trigWhenAll;

  /// No description provided for @trigThenInOrder.
  ///
  /// In en, this message translates to:
  /// **'run in this order'**
  String get trigThenInOrder;

  /// No description provided for @trigBriefingSteps.
  ///
  /// In en, this message translates to:
  /// **'Steps'**
  String get trigBriefingSteps;

  /// No description provided for @trigSlotCount.
  ///
  /// In en, this message translates to:
  /// **'{current} / {total}'**
  String trigSlotCount(int current, int total);

  /// No description provided for @trigAddSlot.
  ///
  /// In en, this message translates to:
  /// **'Add'**
  String get trigAddSlot;

  /// No description provided for @trigPreserved.
  ///
  /// In en, this message translates to:
  /// **'preserved as raw data'**
  String get trigPreserved;

  /// No description provided for @trigSlotEnabled.
  ///
  /// In en, this message translates to:
  /// **'Enabled'**
  String get trigSlotEnabled;

  /// No description provided for @trigSlotUp.
  ///
  /// In en, this message translates to:
  /// **'Move slot up'**
  String get trigSlotUp;

  /// No description provided for @trigSlotDown.
  ///
  /// In en, this message translates to:
  /// **'Move slot down'**
  String get trigSlotDown;

  /// No description provided for @trigSlotDuplicate.
  ///
  /// In en, this message translates to:
  /// **'Duplicate slot'**
  String get trigSlotDuplicate;

  /// No description provided for @trigSlotRemove.
  ///
  /// In en, this message translates to:
  /// **'Remove slot'**
  String get trigSlotRemove;

  /// No description provided for @trigExplainTitle.
  ///
  /// In en, this message translates to:
  /// **'What it does'**
  String get trigExplainTitle;

  /// No description provided for @trigExplainOwners.
  ///
  /// In en, this message translates to:
  /// **'For {owners}:'**
  String trigExplainOwners(String owners);

  /// No description provided for @trigExplainNoOwner.
  ///
  /// In en, this message translates to:
  /// **'No player runs this trigger yet, so it never runs.'**
  String get trigExplainNoOwner;

  /// No description provided for @trigExplainNever.
  ///
  /// In en, this message translates to:
  /// **'It has a “Never” condition, so it never runs.'**
  String get trigExplainNever;

  /// No description provided for @trigExplainAlways.
  ///
  /// In en, this message translates to:
  /// **'It runs right away because the condition is “Always”.'**
  String get trigExplainAlways;

  /// No description provided for @trigExplainConditions.
  ///
  /// In en, this message translates to:
  /// **'When all {count} conditions are true,'**
  String trigExplainConditions(int count);

  /// No description provided for @trigExplainNoConditions.
  ///
  /// In en, this message translates to:
  /// **'With no conditions,'**
  String get trigExplainNoConditions;

  /// No description provided for @trigExplainActions.
  ///
  /// In en, this message translates to:
  /// **'it runs {count} actions in order.'**
  String trigExplainActions(int count);

  /// No description provided for @trigExplainOnce.
  ///
  /// In en, this message translates to:
  /// **'Without “Preserve trigger” it runs only once per player.'**
  String get trigExplainOnce;

  /// No description provided for @trigExplainPreserve.
  ///
  /// In en, this message translates to:
  /// **'“Preserve trigger” makes it run again every time the conditions are true.'**
  String get trigExplainPreserve;

  /// No description provided for @trigExplainDisabled.
  ///
  /// In en, this message translates to:
  /// **'It is turned off and will not run.'**
  String get trigExplainDisabled;

  /// No description provided for @trigRawRecord.
  ///
  /// In en, this message translates to:
  /// **'Advanced: raw record (read-only)'**
  String get trigRawRecord;

  /// No description provided for @trigApply.
  ///
  /// In en, this message translates to:
  /// **'Apply to map'**
  String get trigApply;

  /// No description provided for @trigSlotAction.
  ///
  /// In en, this message translates to:
  /// **'Action'**
  String get trigSlotAction;

  /// No description provided for @trigSlotCondition.
  ///
  /// In en, this message translates to:
  /// **'Condition'**
  String get trigSlotCondition;

  /// No description provided for @trigSlotReplaceNote.
  ///
  /// In en, this message translates to:
  /// **'Changing the type replaces this slot’s arguments when applied.'**
  String get trigSlotReplaceNote;

  /// No description provided for @trigAlwaysDisplay.
  ///
  /// In en, this message translates to:
  /// **'Always display text'**
  String get trigAlwaysDisplay;

  /// No description provided for @trigUseSlot.
  ///
  /// In en, this message translates to:
  /// **'Use slot'**
  String get trigUseSlot;

  /// No description provided for @eudProjectTitle.
  ///
  /// In en, this message translates to:
  /// **'EUD Project'**
  String get eudProjectTitle;

  /// No description provided for @eudProjectUnsavedSuffix.
  ///
  /// In en, this message translates to:
  /// **' • Unsaved'**
  String get eudProjectUnsavedSuffix;

  /// No description provided for @eudProjectLead.
  ///
  /// In en, this message translates to:
  /// **'Change unit, weapon, upgrade and player settings that ordinary map editing cannot reach. Values live in a separate project file and reach the game only through an EUD build.'**
  String get eudProjectLead;

  /// No description provided for @eudNewFromMap.
  ///
  /// In en, this message translates to:
  /// **'New from current map'**
  String get eudNewFromMap;

  /// No description provided for @eudOpenProject.
  ///
  /// In en, this message translates to:
  /// **'Open Project'**
  String get eudOpenProject;

  /// No description provided for @eudSaveProject.
  ///
  /// In en, this message translates to:
  /// **'Save Project'**
  String get eudSaveProject;

  /// No description provided for @eudSaveProjectAs.
  ///
  /// In en, this message translates to:
  /// **'Save Project As'**
  String get eudSaveProjectAs;

  /// No description provided for @eudUndoProject.
  ///
  /// In en, this message translates to:
  /// **'Undo project'**
  String get eudUndoProject;

  /// No description provided for @eudRedoProject.
  ///
  /// In en, this message translates to:
  /// **'Redo project'**
  String get eudRedoProject;

  /// No description provided for @eudCloseProject.
  ///
  /// In en, this message translates to:
  /// **'Close Project'**
  String get eudCloseProject;

  /// No description provided for @eudGenerationPreview.
  ///
  /// In en, this message translates to:
  /// **'Generation preview'**
  String get eudGenerationPreview;

  /// No description provided for @eudGenerationPreviewTitle.
  ///
  /// In en, this message translates to:
  /// **'EUD generation preview'**
  String get eudGenerationPreviewTitle;

  /// No description provided for @eudGenerationPreviewNote.
  ///
  /// In en, this message translates to:
  /// **'Settings initialize before user initialization. Rules run at their selected before/after trigger hook. Instance rules affect only their guarded bound unit. Game compatibility is unverified.'**
  String get eudGenerationPreviewNote;

  /// No description provided for @eudClose.
  ///
  /// In en, this message translates to:
  /// **'Close'**
  String get eudClose;

  /// No description provided for @eudCancel.
  ///
  /// In en, this message translates to:
  /// **'Cancel'**
  String get eudCancel;

  /// No description provided for @eudDiscard.
  ///
  /// In en, this message translates to:
  /// **'Discard'**
  String get eudDiscard;

  /// No description provided for @eudDiscardTitle.
  ///
  /// In en, this message translates to:
  /// **'Discard EUD project changes?'**
  String get eudDiscardTitle;

  /// No description provided for @eudDiscardBody.
  ///
  /// In en, this message translates to:
  /// **'The EUD project has unsaved changes. Save Project As before continuing to keep them.'**
  String get eudDiscardBody;

  /// No description provided for @eudWelcomeTitle.
  ///
  /// In en, this message translates to:
  /// **'What an EUD project does'**
  String get eudWelcomeTitle;

  /// No description provided for @eudWelcomeChoose.
  ///
  /// In en, this message translates to:
  /// **'Pick new values for units, weapons, upgrades, technologies and players.'**
  String get eudWelcomeChoose;

  /// No description provided for @eudWelcomeSave.
  ///
  /// In en, this message translates to:
  /// **'Save them in a project file. The map file is not touched.'**
  String get eudWelcomeSave;

  /// No description provided for @eudWelcomeBuild.
  ///
  /// In en, this message translates to:
  /// **'Build a new EUD map to try them. The original map stays as it is.'**
  String get eudWelcomeBuild;

  /// No description provided for @eudProjectSaveNote.
  ///
  /// In en, this message translates to:
  /// **'Project saving preserves EUD settings; it does not compile a map. Map Save As saves ordinary map changes.'**
  String get eudProjectSaveNote;

  /// No description provided for @eudAllFieldsNote.
  ///
  /// In en, this message translates to:
  /// **'All EUD field extensions opens unit, weapon, movement, upgrade, technology, player and graphics settings. Prepare EUD Build can include these settings in an unverified test build. Save Project keeps a recovery backup.'**
  String get eudAllFieldsNote;

  /// No description provided for @eudBindingUnchecked.
  ///
  /// In en, this message translates to:
  /// **'Map connection has not been verified. Use Verify current map.'**
  String get eudBindingUnchecked;

  /// No description provided for @eudBindingNoMap.
  ///
  /// In en, this message translates to:
  /// **'Open a map to connect an EUD project.'**
  String get eudBindingNoMap;

  /// No description provided for @eudBindingUnsaved.
  ///
  /// In en, this message translates to:
  /// **'The map has unsaved changes. Save the map before connecting.'**
  String get eudBindingUnsaved;

  /// No description provided for @eudBindingRestricted.
  ///
  /// In en, this message translates to:
  /// **'This map is restricted and cannot be connected for editing.'**
  String get eudBindingRestricted;

  /// No description provided for @eudBindingMatched.
  ///
  /// In en, this message translates to:
  /// **'Current map matches the project (verified snapshot).'**
  String get eudBindingMatched;

  /// No description provided for @eudBindingMismatch.
  ///
  /// In en, this message translates to:
  /// **'Current map differs from the project. Open the linked map or explicitly connect this map.'**
  String get eudBindingMismatch;

  /// No description provided for @eudBindingDiskChanged.
  ///
  /// In en, this message translates to:
  /// **'The map changed on disk. Reopen it before connecting.'**
  String get eudBindingDiskChanged;

  /// No description provided for @eudConnectionTitle.
  ///
  /// In en, this message translates to:
  /// **'Connected map'**
  String get eudConnectionTitle;

  /// No description provided for @eudVerifyMap.
  ///
  /// In en, this message translates to:
  /// **'Verify current map'**
  String get eudVerifyMap;

  /// No description provided for @eudConnectMap.
  ///
  /// In en, this message translates to:
  /// **'Connect current map'**
  String get eudConnectMap;

  /// No description provided for @eudProjectInfo.
  ///
  /// In en, this message translates to:
  /// **'Project: {project}\nMap: {map}\nSHA-256: {sha}'**
  String eudProjectInfo(String project, String map, String sha);

  /// No description provided for @eudNotSaved.
  ///
  /// In en, this message translates to:
  /// **'Not saved'**
  String get eudNotSaved;

  /// No description provided for @eudChangesTitle.
  ///
  /// In en, this message translates to:
  /// **'Changed values'**
  String get eudChangesTitle;

  /// No description provided for @eudChangesCount.
  ///
  /// In en, this message translates to:
  /// **'{count} stored overrides • Runtime unverified'**
  String eudChangesCount(int count);

  /// No description provided for @eudChangesEmpty.
  ///
  /// In en, this message translates to:
  /// **'No values changed yet. Open All EUD field extensions to choose some.'**
  String get eudChangesEmpty;

  /// No description provided for @eudAllFields.
  ///
  /// In en, this message translates to:
  /// **'All EUD field extensions'**
  String get eudAllFields;

  /// No description provided for @eudBaselineLine.
  ///
  /// In en, this message translates to:
  /// **'Baseline: {value}'**
  String eudBaselineLine(String value);

  /// No description provided for @eudPlannedLine.
  ///
  /// In en, this message translates to:
  /// **'Requested EUD: {requested} • Planned EUD value: {planned}'**
  String eudPlannedLine(String requested, String planned);

  /// No description provided for @eudUnresolved.
  ///
  /// In en, this message translates to:
  /// **'Unresolved'**
  String get eudUnresolved;

  /// No description provided for @eudExplicitChk.
  ///
  /// In en, this message translates to:
  /// **'Explicit CHK override'**
  String get eudExplicitChk;

  /// No description provided for @eudPreviewOnlyNote.
  ///
  /// In en, this message translates to:
  /// **'Preview only, not applied in game. Verify current map after changes. Project validation errors block all planned values.'**
  String get eudPreviewOnlyNote;

  /// No description provided for @eudRevert.
  ///
  /// In en, this message translates to:
  /// **'Back to the original value'**
  String get eudRevert;

  /// No description provided for @eudBaselineUnverified.
  ///
  /// In en, this message translates to:
  /// **'Unverified map'**
  String get eudBaselineUnverified;

  /// No description provided for @eudBaselineGameDefault.
  ///
  /// In en, this message translates to:
  /// **'Game default (unknown; {detail})'**
  String eudBaselineGameDefault(String detail);

  /// No description provided for @eudBaselineUnavailable.
  ///
  /// In en, this message translates to:
  /// **'Unavailable ({detail})'**
  String eudBaselineUnavailable(String detail);

  /// No description provided for @eudBaselineNotInChk.
  ///
  /// In en, this message translates to:
  /// **'Not stored in CHK; {detail}'**
  String eudBaselineNotInChk(String detail);

  /// No description provided for @eudStepsTitle.
  ///
  /// In en, this message translates to:
  /// **'Getting it into the game'**
  String get eudStepsTitle;

  /// No description provided for @eudStepChoose.
  ///
  /// In en, this message translates to:
  /// **'Choose values'**
  String get eudStepChoose;

  /// No description provided for @eudStepChooseDone.
  ///
  /// In en, this message translates to:
  /// **'{count} values changed'**
  String eudStepChooseDone(int count);

  /// No description provided for @eudStepChooseNone.
  ///
  /// In en, this message translates to:
  /// **'Nothing changed yet'**
  String get eudStepChooseNone;

  /// No description provided for @eudStepSave.
  ///
  /// In en, this message translates to:
  /// **'Save the project'**
  String get eudStepSave;

  /// No description provided for @eudStepSaveDone.
  ///
  /// In en, this message translates to:
  /// **'Saved · the map file is untouched'**
  String get eudStepSaveDone;

  /// No description provided for @eudStepSaveNeeded.
  ///
  /// In en, this message translates to:
  /// **'Not saved yet · the map file is untouched'**
  String get eudStepSaveNeeded;

  /// No description provided for @eudStepVerify.
  ///
  /// In en, this message translates to:
  /// **'Check the map'**
  String get eudStepVerify;

  /// No description provided for @eudStepBuild.
  ///
  /// In en, this message translates to:
  /// **'EUD build'**
  String get eudStepBuild;

  /// No description provided for @eudStepBuildHint.
  ///
  /// In en, this message translates to:
  /// **'To test these settings, save and verify the map, then use Prepare EUD Build and enable the project settings test build.'**
  String get eudStepBuildHint;

  /// No description provided for @eudStepBuildIdle.
  ///
  /// In en, this message translates to:
  /// **'Builds a new map file. The original stays as it is.'**
  String get eudStepBuildIdle;

  /// No description provided for @eudRecoveryBackup.
  ///
  /// In en, this message translates to:
  /// **'Recovery backup: {path}'**
  String eudRecoveryBackup(String path);

  /// No description provided for @eudSavedPill.
  ///
  /// In en, this message translates to:
  /// **'Saved'**
  String get eudSavedPill;

  /// No description provided for @eudUnsavedPill.
  ///
  /// In en, this message translates to:
  /// **'Unsaved'**
  String get eudUnsavedPill;

  /// No description provided for @eudRuntimeUnverified.
  ///
  /// In en, this message translates to:
  /// **'Runtime unverified'**
  String get eudRuntimeUnverified;

  /// No description provided for @eudTechnical.
  ///
  /// In en, this message translates to:
  /// **'Technical details'**
  String get eudTechnical;

  /// No description provided for @eudProblems.
  ///
  /// In en, this message translates to:
  /// **'Needs attention'**
  String get eudProblems;

  /// No description provided for @eudRulesTitle.
  ///
  /// In en, this message translates to:
  /// **'Execution rules'**
  String get eudRulesTitle;

  /// No description provided for @eudRulesCount.
  ///
  /// In en, this message translates to:
  /// **'{current} / {total}'**
  String eudRulesCount(int current, int total);

  /// No description provided for @eudRulesHelp.
  ///
  /// In en, this message translates to:
  /// **'Rules change player resources and other game state while the map runs. They execute before ordinary triggers, and periods count trigger cycles, not seconds. Save Project, then Prepare EUD Build to test.'**
  String get eudRulesHelp;

  /// No description provided for @eudRulesHelp2.
  ///
  /// In en, this message translates to:
  /// **'One enabled writer per target. Review user code and ordinary triggers separately. Extended rules support variables, player state, locations, guarded units and local display.'**
  String get eudRulesHelp2;

  /// No description provided for @eudRulesEmpty.
  ///
  /// In en, this message translates to:
  /// **'No rules yet.'**
  String get eudRulesEmpty;

  /// No description provided for @eudRuleAdd.
  ///
  /// In en, this message translates to:
  /// **'Add execution rule'**
  String get eudRuleAdd;

  /// No description provided for @eudRuleEditTitle.
  ///
  /// In en, this message translates to:
  /// **'Edit execution rule'**
  String get eudRuleEditTitle;

  /// No description provided for @eudRuleDisabled.
  ///
  /// In en, this message translates to:
  /// **'Off'**
  String get eudRuleDisabled;

  /// No description provided for @eudRuleMoveUp.
  ///
  /// In en, this message translates to:
  /// **'Move rule up'**
  String get eudRuleMoveUp;

  /// No description provided for @eudRuleMoveDown.
  ///
  /// In en, this message translates to:
  /// **'Move rule down'**
  String get eudRuleMoveDown;

  /// No description provided for @eudRuleEdit.
  ///
  /// In en, this message translates to:
  /// **'Edit rule'**
  String get eudRuleEdit;

  /// No description provided for @eudRuleDelete.
  ///
  /// In en, this message translates to:
  /// **'Delete rule'**
  String get eudRuleDelete;

  /// No description provided for @eudRulePlayerN.
  ///
  /// In en, this message translates to:
  /// **'Player {number}'**
  String eudRulePlayerN(String number);

  /// No description provided for @eudRuleWhenThen.
  ///
  /// In en, this message translates to:
  /// **'When {condition} → {action}'**
  String eudRuleWhenThen(String condition, String action);

  /// No description provided for @eudCmpAtLeastSentence.
  ///
  /// In en, this message translates to:
  /// **'{resource} is at least {value}'**
  String eudCmpAtLeastSentence(String resource, String value);

  /// No description provided for @eudCmpAtMostSentence.
  ///
  /// In en, this message translates to:
  /// **'{resource} is at most {value}'**
  String eudCmpAtMostSentence(String resource, String value);

  /// No description provided for @eudCmpExactlySentence.
  ///
  /// In en, this message translates to:
  /// **'{resource} is exactly {value}'**
  String eudCmpExactlySentence(String resource, String value);

  /// No description provided for @eudOpSetToSentence.
  ///
  /// In en, this message translates to:
  /// **'set to {amount}'**
  String eudOpSetToSentence(String amount);

  /// No description provided for @eudOpAddSentence.
  ///
  /// In en, this message translates to:
  /// **'add {amount}'**
  String eudOpAddSentence(String amount);

  /// No description provided for @eudOpSubtractSentence.
  ///
  /// In en, this message translates to:
  /// **'subtract {amount}'**
  String eudOpSubtractSentence(String amount);

  /// No description provided for @eudRuleOnce.
  ///
  /// In en, this message translates to:
  /// **'Once on first match'**
  String get eudRuleOnce;

  /// No description provided for @eudRuleEvery.
  ///
  /// In en, this message translates to:
  /// **'Every {count} cycles'**
  String eudRuleEvery(int count);

  /// No description provided for @eudRulePeriodic.
  ///
  /// In en, this message translates to:
  /// **'Periodic'**
  String get eudRulePeriodic;

  /// No description provided for @eudResMinerals.
  ///
  /// In en, this message translates to:
  /// **'Minerals'**
  String get eudResMinerals;

  /// No description provided for @eudResGas.
  ///
  /// In en, this message translates to:
  /// **'Gas'**
  String get eudResGas;

  /// No description provided for @eudCmpAtLeast.
  ///
  /// In en, this message translates to:
  /// **'At least'**
  String get eudCmpAtLeast;

  /// No description provided for @eudCmpAtMost.
  ///
  /// In en, this message translates to:
  /// **'At most'**
  String get eudCmpAtMost;

  /// No description provided for @eudCmpExactly.
  ///
  /// In en, this message translates to:
  /// **'Exactly'**
  String get eudCmpExactly;

  /// No description provided for @eudOpSetTo.
  ///
  /// In en, this message translates to:
  /// **'Set to'**
  String get eudOpSetTo;

  /// No description provided for @eudOpAdd.
  ///
  /// In en, this message translates to:
  /// **'Add'**
  String get eudOpAdd;

  /// No description provided for @eudOpSubtract.
  ///
  /// In en, this message translates to:
  /// **'Subtract'**
  String get eudOpSubtract;

  /// No description provided for @eudRuleDefaultName.
  ///
  /// In en, this message translates to:
  /// **'Resource rule'**
  String get eudRuleDefaultName;

  /// No description provided for @eudRuleName.
  ///
  /// In en, this message translates to:
  /// **'Rule name'**
  String get eudRuleName;

  /// No description provided for @eudRulePlayer.
  ///
  /// In en, this message translates to:
  /// **'Player'**
  String get eudRulePlayer;

  /// No description provided for @eudRuleResource.
  ///
  /// In en, this message translates to:
  /// **'Resource (condition and action)'**
  String get eudRuleResource;

  /// No description provided for @eudRuleComparison.
  ///
  /// In en, this message translates to:
  /// **'Comparison'**
  String get eudRuleComparison;

  /// No description provided for @eudRuleThreshold.
  ///
  /// In en, this message translates to:
  /// **'Threshold (0–2147483647)'**
  String get eudRuleThreshold;

  /// No description provided for @eudRuleAction.
  ///
  /// In en, this message translates to:
  /// **'Action'**
  String get eudRuleAction;

  /// No description provided for @eudRuleAmount.
  ///
  /// In en, this message translates to:
  /// **'Amount (0–2147483647)'**
  String get eudRuleAmount;

  /// No description provided for @eudRuleSchedule.
  ///
  /// In en, this message translates to:
  /// **'Schedule'**
  String get eudRuleSchedule;

  /// No description provided for @eudRuleInterval.
  ///
  /// In en, this message translates to:
  /// **'Interval (12–86400 trigger cycles)'**
  String get eudRuleInterval;

  /// No description provided for @eudRuleEnabled.
  ///
  /// In en, this message translates to:
  /// **'Enabled'**
  String get eudRuleEnabled;

  /// No description provided for @eudRuleApply.
  ///
  /// In en, this message translates to:
  /// **'Apply rule'**
  String get eudRuleApply;

  /// No description provided for @eudExtTitle.
  ///
  /// In en, this message translates to:
  /// **'Extended execution rule'**
  String get eudExtTitle;

  /// No description provided for @eudExtHelp.
  ///
  /// In en, this message translates to:
  /// **'Values: unsigned 16-bit, clamped to 0–65535. Variables 0–15 start at zero. Formula: source × factor + offset. Non-resource actions set their value.'**
  String get eudExtHelp;

  /// No description provided for @eudExtTargetAction.
  ///
  /// In en, this message translates to:
  /// **'Target action'**
  String get eudExtTargetAction;

  /// No description provided for @eudExtTargetId.
  ///
  /// In en, this message translates to:
  /// **'Target ID: variable 0–15, upgrade 0–60, tech 0–43, location 1–255 (except 64), sound string ID; otherwise 0'**
  String get eudExtTargetId;

  /// No description provided for @eudExtUnitType.
  ///
  /// In en, this message translates to:
  /// **'Unit type ID (0–227; instance/follow actions)'**
  String get eudExtUnitType;

  /// No description provided for @eudExtUnitBindHelp.
  ///
  /// In en, this message translates to:
  /// **'Binds the first living unit of this type owned by the selected player. Death, morph or ownership change invalidates the binding permanently. It never acquires a replacement unit. At most four unit rules.'**
  String get eudExtUnitBindHelp;

  /// No description provided for @eudExtTextPrefix.
  ///
  /// In en, this message translates to:
  /// **'Text prefix (selected player only)'**
  String get eudExtTextPrefix;

  /// No description provided for @eudExtSoundHelp.
  ///
  /// In en, this message translates to:
  /// **'Use a registered WAV string ID from Resources. Only the selected player hears the sound.'**
  String get eudExtSoundHelp;

  /// No description provided for @eudExtTiming.
  ///
  /// In en, this message translates to:
  /// **'Execution timing'**
  String get eudExtTiming;

  /// No description provided for @eudExtLeft.
  ///
  /// In en, this message translates to:
  /// **'Condition left'**
  String get eudExtLeft;

  /// No description provided for @eudExtRight.
  ///
  /// In en, this message translates to:
  /// **'Condition right'**
  String get eudExtRight;

  /// No description provided for @eudExtValue.
  ///
  /// In en, this message translates to:
  /// **'Action value'**
  String get eudExtValue;

  /// No description provided for @eudExtX.
  ///
  /// In en, this message translates to:
  /// **'X'**
  String get eudExtX;

  /// No description provided for @eudExtY.
  ///
  /// In en, this message translates to:
  /// **'Y'**
  String get eudExtY;

  /// No description provided for @eudExtWidth.
  ///
  /// In en, this message translates to:
  /// **'Width'**
  String get eudExtWidth;

  /// No description provided for @eudExtHeight.
  ///
  /// In en, this message translates to:
  /// **'Height'**
  String get eudExtHeight;

  /// No description provided for @eudExtConstantId.
  ///
  /// In en, this message translates to:
  /// **'Constant / ID'**
  String get eudExtConstantId;

  /// No description provided for @eudExtPlayerRange.
  ///
  /// In en, this message translates to:
  /// **'Player 1–8'**
  String get eudExtPlayerRange;

  /// No description provided for @eudExtFactor.
  ///
  /// In en, this message translates to:
  /// **'× (0–255)'**
  String get eudExtFactor;

  /// No description provided for @eudExtOffset.
  ///
  /// In en, this message translates to:
  /// **'+ offset'**
  String get eudExtOffset;

  /// No description provided for @eudActVariable.
  ///
  /// In en, this message translates to:
  /// **'Variable'**
  String get eudActVariable;

  /// No description provided for @eudActMinerals.
  ///
  /// In en, this message translates to:
  /// **'Minerals'**
  String get eudActMinerals;

  /// No description provided for @eudActGas.
  ///
  /// In en, this message translates to:
  /// **'Gas'**
  String get eudActGas;

  /// No description provided for @eudActUpgrade.
  ///
  /// In en, this message translates to:
  /// **'Upgrade level'**
  String get eudActUpgrade;

  /// No description provided for @eudActTechnology.
  ///
  /// In en, this message translates to:
  /// **'Technology'**
  String get eudActTechnology;

  /// No description provided for @eudActLocation.
  ///
  /// In en, this message translates to:
  /// **'Location'**
  String get eudActLocation;

  /// No description provided for @eudActUnitHp.
  ///
  /// In en, this message translates to:
  /// **'Unit hit points'**
  String get eudActUnitHp;

  /// No description provided for @eudActUnitShields.
  ///
  /// In en, this message translates to:
  /// **'Unit shields'**
  String get eudActUnitShields;

  /// No description provided for @eudActUnitEnergy.
  ///
  /// In en, this message translates to:
  /// **'Unit energy'**
  String get eudActUnitEnergy;

  /// No description provided for @eudActFollowUnit.
  ///
  /// In en, this message translates to:
  /// **'Follow unit'**
  String get eudActFollowUnit;

  /// No description provided for @eudActText.
  ///
  /// In en, this message translates to:
  /// **'Show text'**
  String get eudActText;

  /// No description provided for @eudActSound.
  ///
  /// In en, this message translates to:
  /// **'Play sound'**
  String get eudActSound;

  /// No description provided for @eudTimingBefore.
  ///
  /// In en, this message translates to:
  /// **'Before triggers'**
  String get eudTimingBefore;

  /// No description provided for @eudTimingAfter.
  ///
  /// In en, this message translates to:
  /// **'After triggers'**
  String get eudTimingAfter;

  /// No description provided for @eudSrcConstant.
  ///
  /// In en, this message translates to:
  /// **'Constant'**
  String get eudSrcConstant;

  /// No description provided for @eudSrcVariable.
  ///
  /// In en, this message translates to:
  /// **'Variable'**
  String get eudSrcVariable;

  /// No description provided for @eudSrcMinerals.
  ///
  /// In en, this message translates to:
  /// **'Minerals'**
  String get eudSrcMinerals;

  /// No description provided for @eudSrcGas.
  ///
  /// In en, this message translates to:
  /// **'Gas'**
  String get eudSrcGas;

  /// No description provided for @eudSrcUpgrade.
  ///
  /// In en, this message translates to:
  /// **'Upgrade level'**
  String get eudSrcUpgrade;

  /// No description provided for @eudSrcTechnology.
  ///
  /// In en, this message translates to:
  /// **'Technology'**
  String get eudSrcTechnology;

  /// No description provided for @eudApplyToProject.
  ///
  /// In en, this message translates to:
  /// **'Apply to project'**
  String get eudApplyToProject;

  /// No description provided for @eudProjectChanged.
  ///
  /// In en, this message translates to:
  /// **'Project changed. Cancel and reopen this editor.'**
  String get eudProjectChanged;

  /// No description provided for @eudWeaponCardTitle.
  ///
  /// In en, this message translates to:
  /// **'Weapons'**
  String get eudWeaponCardTitle;

  /// No description provided for @eudWeaponCardHelp.
  ///
  /// In en, this message translates to:
  /// **'Range and damage type belong to the weapon, so every unit that uses it changes together.'**
  String get eudWeaponCardHelp;

  /// No description provided for @eudWeaponEdit.
  ///
  /// In en, this message translates to:
  /// **'Edit weapon EUD settings'**
  String get eudWeaponEdit;

  /// No description provided for @eudWeaponSharedHelp.
  ///
  /// In en, this message translates to:
  /// **'Shared weapon ID for ground/air users. Review Static unit / weapon impact after applying. This does not reassign a unit’s weapon.'**
  String get eudWeaponSharedHelp;

  /// No description provided for @eudWeaponRawHelp.
  ///
  /// In en, this message translates to:
  /// **'Distances are raw integers; tile conversion and runtime support are unverified. Blank removes the override; game defaults remain unknown. Applying changes only the project, not the game.'**
  String get eudWeaponRawHelp;

  /// No description provided for @eudWeaponMinRange.
  ///
  /// In en, this message translates to:
  /// **'Minimum range (raw)'**
  String get eudWeaponMinRange;

  /// No description provided for @eudWeaponMaxRange.
  ///
  /// In en, this message translates to:
  /// **'Maximum range (raw)'**
  String get eudWeaponMaxRange;

  /// No description provided for @eudWeaponNoDamage.
  ///
  /// In en, this message translates to:
  /// **'No damage type override'**
  String get eudWeaponNoDamage;

  /// No description provided for @eudWeaponUnsupported.
  ///
  /// In en, this message translates to:
  /// **'Unsupported: {value}'**
  String eudWeaponUnsupported(String value);

  /// No description provided for @eudWeaponReferenceChanged.
  ///
  /// In en, this message translates to:
  /// **'Weapon reference source changed. Cancel and reload references.'**
  String get eudWeaponReferenceChanged;

  /// No description provided for @eudWeaponWholeNumber.
  ///
  /// In en, this message translates to:
  /// **'{field}: enter a whole number from 0 to 4294967295.'**
  String eudWeaponWholeNumber(String field);

  /// No description provided for @eudDamageIndependent.
  ///
  /// In en, this message translates to:
  /// **'Independent'**
  String get eudDamageIndependent;

  /// No description provided for @eudDamageExplosive.
  ///
  /// In en, this message translates to:
  /// **'Explosive'**
  String get eudDamageExplosive;

  /// No description provided for @eudDamageConcussive.
  ///
  /// In en, this message translates to:
  /// **'Concussive'**
  String get eudDamageConcussive;

  /// No description provided for @eudDamageNormal.
  ///
  /// In en, this message translates to:
  /// **'Normal'**
  String get eudDamageNormal;

  /// No description provided for @eudDamageIgnoreArmor.
  ///
  /// In en, this message translates to:
  /// **'IgnoreArmor'**
  String get eudDamageIgnoreArmor;

  /// No description provided for @eudImpactTitle.
  ///
  /// In en, this message translates to:
  /// **'Static unit / weapon impact'**
  String get eudImpactTitle;

  /// No description provided for @eudImpactHelp.
  ///
  /// In en, this message translates to:
  /// **'Base DAT references only; proposed reference changes, spells and actual attack behavior are not resolved. Type settings are global; player fields affect the selected slot.'**
  String get eudImpactHelp;

  /// No description provided for @eudImpactLoad.
  ///
  /// In en, this message translates to:
  /// **'Load weapon impact'**
  String get eudImpactLoad;

  /// No description provided for @eudImpactUnavailable.
  ///
  /// In en, this message translates to:
  /// **'Weapon references unavailable. Load or reload to analyze.'**
  String get eudImpactUnavailable;

  /// No description provided for @eudImpactSource.
  ///
  /// In en, this message translates to:
  /// **'Reference source: {source}'**
  String eudImpactSource(String source);

  /// No description provided for @eudImpactChooseUnit.
  ///
  /// In en, this message translates to:
  /// **'Choose a unit to edit its direct ground / air weapon. Subunit weapons are separate; select that subunit explicitly.'**
  String get eudImpactChooseUnit;

  /// No description provided for @eudImpactEditShields.
  ///
  /// In en, this message translates to:
  /// **'Edit unit EUD shields'**
  String get eudImpactEditShields;

  /// No description provided for @eudImpactGround.
  ///
  /// In en, this message translates to:
  /// **'Ground'**
  String get eudImpactGround;

  /// No description provided for @eudImpactAir.
  ///
  /// In en, this message translates to:
  /// **'Air'**
  String get eudImpactAir;

  /// No description provided for @eudImpactNoWeapon.
  ///
  /// In en, this message translates to:
  /// **'{slot} weapon: None (#130)'**
  String eudImpactNoWeapon(String slot);

  /// No description provided for @eudImpactEditWeapon.
  ///
  /// In en, this message translates to:
  /// **'{slot}: {weapon} — Edit EUD'**
  String eudImpactEditWeapon(String slot, String weapon);

  /// No description provided for @eudImpactSubunits.
  ///
  /// In en, this message translates to:
  /// **'Subunit IDs: {subunit1}, {subunit2} (228 = None)'**
  String eudImpactSubunits(String subunit1, String subunit2);

  /// No description provided for @eudImpactCannotAnalyze.
  ///
  /// In en, this message translates to:
  /// **'Cannot analyze: {reason}'**
  String eudImpactCannotAnalyze(String reason);

  /// No description provided for @eudImpactUnknownWeapon.
  ///
  /// In en, this message translates to:
  /// **'Impact unknown: weapon references unavailable.'**
  String get eudImpactUnknownWeapon;

  /// No description provided for @eudImpactPlayerOnly.
  ///
  /// In en, this message translates to:
  /// **'Player {number} only; runtime behavior unverified.'**
  String eudImpactPlayerOnly(String number);

  /// No description provided for @eudImpactUnknownShared.
  ///
  /// In en, this message translates to:
  /// **'Impact unknown: shared references for this table are unavailable.'**
  String get eudImpactUnknownShared;

  /// No description provided for @eudImpactUnits.
  ///
  /// In en, this message translates to:
  /// **'Direct units: {direct}\nVia subunits: {subunits}'**
  String eudImpactUnits(String direct, String subunits);

  /// No description provided for @eudImpactNone.
  ///
  /// In en, this message translates to:
  /// **'None in static references'**
  String get eudImpactNone;

  /// No description provided for @eudShieldTitle.
  ///
  /// In en, this message translates to:
  /// **'{unit} — Shields'**
  String eudShieldTitle(String unit);

  /// No description provided for @eudShieldHelp.
  ///
  /// In en, this message translates to:
  /// **'Activation and maximum are independent type settings shared by all players. Blank maximum or No override removes that setting; defaults are unknown.'**
  String get eudShieldHelp;

  /// No description provided for @eudShieldNoOverride.
  ///
  /// In en, this message translates to:
  /// **'No activation override'**
  String get eudShieldNoOverride;

  /// No description provided for @eudShieldEnabled.
  ///
  /// In en, this message translates to:
  /// **'Shields enabled'**
  String get eudShieldEnabled;

  /// No description provided for @eudShieldDisabled.
  ///
  /// In en, this message translates to:
  /// **'Shields disabled'**
  String get eudShieldDisabled;

  /// No description provided for @eudShieldUnsupported.
  ///
  /// In en, this message translates to:
  /// **'Unsupported imported activation'**
  String get eudShieldUnsupported;

  /// No description provided for @eudShieldMaximum.
  ///
  /// In en, this message translates to:
  /// **'Maximum shields (0–65535)'**
  String get eudShieldMaximum;

  /// No description provided for @eudShieldOverrideChk.
  ///
  /// In en, this message translates to:
  /// **'Explicitly override CHK maximum shields'**
  String get eudShieldOverrideChk;

  /// No description provided for @eudShieldInitNote.
  ///
  /// In en, this message translates to:
  /// **'Initialization is not implemented: existing placed units keep their CHK shield percentages; no current-shield refill, clamp or recurring write is generated. New-unit initialization requires runtime verification. Applying saves project intent only; EUD build integration is pending.'**
  String get eudShieldInitNote;

  /// No description provided for @eudShieldChooseSupported.
  ///
  /// In en, this message translates to:
  /// **'Choose a supported shield activation value.'**
  String get eudShieldChooseSupported;

  /// No description provided for @eudShieldWholeNumber.
  ///
  /// In en, this message translates to:
  /// **'Maximum shields require a whole number from 0 to 65535.'**
  String get eudShieldWholeNumber;

  /// No description provided for @eudFieldsTitle.
  ///
  /// In en, this message translates to:
  /// **'EUD field extensions'**
  String get eudFieldsTitle;

  /// No description provided for @eudFieldsIntro.
  ///
  /// In en, this message translates to:
  /// **'Candidate settings • Runtime unverified. Add each edit to the draft, then apply the draft to the project. Unsaved input is discarded when changing selection.'**
  String get eudFieldsIntro;

  /// No description provided for @eudFieldsField.
  ///
  /// In en, this message translates to:
  /// **'What to change'**
  String get eudFieldsField;

  /// No description provided for @eudFieldsSearch.
  ///
  /// In en, this message translates to:
  /// **'Find target by name or ID'**
  String get eudFieldsSearch;

  /// No description provided for @eudFieldsTarget.
  ///
  /// In en, this message translates to:
  /// **'Which one'**
  String get eudFieldsTarget;

  /// No description provided for @eudFieldsPlayerNote.
  ///
  /// In en, this message translates to:
  /// **'Selected player slot only. Supply uses half-points (400 = 200 supply).'**
  String get eudFieldsPlayerNote;

  /// No description provided for @eudFieldsGlobalNote.
  ///
  /// In en, this message translates to:
  /// **'Global type setting, shared across players. DAT defaults are not loaded. Shared-reference impact is not resolved for this editor.'**
  String get eudFieldsGlobalNote;

  /// No description provided for @eudFieldsApi.
  ///
  /// In en, this message translates to:
  /// **'Candidate API: {member} • {unit}'**
  String eudFieldsApi(String member, String unit);

  /// No description provided for @eudFieldsStorage.
  ///
  /// In en, this message translates to:
  /// **'Storage input: 0–{maximum}{mask}. Gameplay limits are unverified.'**
  String eudFieldsStorage(String maximum, String mask);

  /// No description provided for @eudFieldsMask.
  ///
  /// In en, this message translates to:
  /// **' • Allowed mask: {mask}'**
  String eudFieldsMask(String mask);

  /// No description provided for @eudFieldsValue.
  ///
  /// In en, this message translates to:
  /// **'Value (decimal integer)'**
  String get eudFieldsValue;

  /// No description provided for @eudFieldsChoose.
  ///
  /// In en, this message translates to:
  /// **'Choose a value'**
  String get eudFieldsChoose;

  /// No description provided for @eudFieldsUnsupported.
  ///
  /// In en, this message translates to:
  /// **'Unsupported stored value: {value}'**
  String eudFieldsUnsupported(String value);

  /// No description provided for @eudFieldsYes.
  ///
  /// In en, this message translates to:
  /// **'Yes (true)'**
  String get eudFieldsYes;

  /// No description provided for @eudFieldsNo.
  ///
  /// In en, this message translates to:
  /// **'No (false)'**
  String get eudFieldsNo;

  /// No description provided for @eudFieldsOverrideChk.
  ///
  /// In en, this message translates to:
  /// **'Explicitly override ordinary CHK settings'**
  String get eudFieldsOverrideChk;

  /// No description provided for @eudFieldsStage.
  ///
  /// In en, this message translates to:
  /// **'Add / update draft'**
  String get eudFieldsStage;

  /// No description provided for @eudFieldsRemove.
  ///
  /// In en, this message translates to:
  /// **'Remove from draft'**
  String get eudFieldsRemove;

  /// No description provided for @eudFieldsDraftSummary.
  ///
  /// In en, this message translates to:
  /// **'{count} draft overrides • Current: {value}'**
  String eudFieldsDraftSummary(int count, String value);

  /// No description provided for @eudFieldsNoOverride.
  ///
  /// In en, this message translates to:
  /// **'No override'**
  String get eudFieldsNoOverride;

  /// No description provided for @eudFieldsApply.
  ///
  /// In en, this message translates to:
  /// **'Apply draft to project'**
  String get eudFieldsApply;

  /// No description provided for @eudFieldsNeedChk.
  ///
  /// In en, this message translates to:
  /// **'This value also changes an ordinary map (CHK) setting. Tick the box above to allow it.'**
  String get eudFieldsNeedChk;

  /// No description provided for @eudFieldsOutOfRange.
  ///
  /// In en, this message translates to:
  /// **'The value is outside the allowed range.'**
  String get eudFieldsOutOfRange;

  /// No description provided for @eudFieldsInvalid.
  ///
  /// In en, this message translates to:
  /// **'This value cannot be used for the selected field.'**
  String get eudFieldsInvalid;

  /// No description provided for @isomFillTitle.
  ///
  /// In en, this message translates to:
  /// **'Fill Isometric Terrain'**
  String get isomFillTitle;

  /// No description provided for @isomFillScope.
  ///
  /// In en, this message translates to:
  /// **'Replace the whole map with one flat terrain type. ISOM, TILE and MTXM are updated together. Undo restores the original terrain. Ramps, transitions and doodads are not supported yet.'**
  String get isomFillScope;

  /// No description provided for @isomTerrainType.
  ///
  /// In en, this message translates to:
  /// **'Flat terrain type'**
  String get isomTerrainType;

  /// No description provided for @isomTerrainId.
  ///
  /// In en, this message translates to:
  /// **'Terrain type #{id}'**
  String isomTerrainId(int id);

  /// No description provided for @isomFillPreview.
  ///
  /// In en, this message translates to:
  /// **'{count} game tiles will change. Editor terrain (ISOM) will also be updated.'**
  String isomFillPreview(int count);

  /// No description provided for @isomFillUnavailable.
  ///
  /// In en, this message translates to:
  /// **'Terrain fill is unavailable. Configure StarCraft data in Settings, and use an even-width map with matching TILE/MTXM and supported ISOM shapes.'**
  String get isomFillUnavailable;

  /// No description provided for @isomFillCancel.
  ///
  /// In en, this message translates to:
  /// **'Cancel'**
  String get isomFillCancel;

  /// No description provided for @isomFillApply.
  ///
  /// In en, this message translates to:
  /// **'Fill whole map'**
  String get isomFillApply;

  /// No description provided for @basicToolsTitle.
  ///
  /// In en, this message translates to:
  /// **'Basic Editing Tools'**
  String get basicToolsTitle;

  /// No description provided for @basicFog.
  ///
  /// In en, this message translates to:
  /// **'Initial fog'**
  String get basicFog;

  /// No description provided for @basicUnits.
  ///
  /// In en, this message translates to:
  /// **'Selected units'**
  String get basicUnits;

  /// No description provided for @basicStarts.
  ///
  /// In en, this message translates to:
  /// **'Start locations'**
  String get basicStarts;

  /// No description provided for @basicLocations.
  ///
  /// In en, this message translates to:
  /// **'Locations'**
  String get basicLocations;

  /// No description provided for @basicOpenMap.
  ///
  /// In en, this message translates to:
  /// **'Open an editable map first.'**
  String get basicOpenMap;

  /// No description provided for @basicFogUnavailable.
  ///
  /// In en, this message translates to:
  /// **'A unique valid MASK/DIM grid is required.'**
  String get basicFogUnavailable;

  /// No description provided for @basicPlayer.
  ///
  /// In en, this message translates to:
  /// **'Player {id}'**
  String basicPlayer(int id);

  /// No description provided for @basicFogHide.
  ///
  /// In en, this message translates to:
  /// **'Hide terrain'**
  String get basicFogHide;

  /// No description provided for @basicBrush.
  ///
  /// In en, this message translates to:
  /// **'Brush'**
  String get basicBrush;

  /// No description provided for @basicRectangle.
  ///
  /// In en, this message translates to:
  /// **'Rectangle'**
  String get basicRectangle;

  /// No description provided for @basicFillAll.
  ///
  /// In en, this message translates to:
  /// **'Fill whole map'**
  String get basicFillAll;

  /// No description provided for @basicFogScope.
  ///
  /// In en, this message translates to:
  /// **'Dark cells are initially hidden. Edits affect this player only.'**
  String get basicFogScope;

  /// No description provided for @basicSelectedUnits.
  ///
  /// In en, this message translates to:
  /// **'{count} selected units'**
  String basicSelectedUnits(int count);

  /// No description provided for @basicKeepBlank.
  ///
  /// In en, this message translates to:
  /// **'Leave numeric fields blank to preserve existing values.'**
  String get basicKeepBlank;

  /// No description provided for @basicOwner.
  ///
  /// In en, this message translates to:
  /// **'Owner (1–12)'**
  String get basicOwner;

  /// No description provided for @basicHitpoints.
  ///
  /// In en, this message translates to:
  /// **'Hitpoints %'**
  String get basicHitpoints;

  /// No description provided for @basicShields.
  ///
  /// In en, this message translates to:
  /// **'Shields %'**
  String get basicShields;

  /// No description provided for @basicEnergy.
  ///
  /// In en, this message translates to:
  /// **'Energy %'**
  String get basicEnergy;

  /// No description provided for @basicResources.
  ///
  /// In en, this message translates to:
  /// **'Resources'**
  String get basicResources;

  /// No description provided for @basicHangar.
  ///
  /// In en, this message translates to:
  /// **'Hangar'**
  String get basicHangar;

  /// No description provided for @basicUnitStates.
  ///
  /// In en, this message translates to:
  /// **'State and inheritance'**
  String get basicUnitStates;

  /// No description provided for @basicCloak.
  ///
  /// In en, this message translates to:
  /// **'Cloaked'**
  String get basicCloak;

  /// No description provided for @basicBurrow.
  ///
  /// In en, this message translates to:
  /// **'Burrowed'**
  String get basicBurrow;

  /// No description provided for @basicLifted.
  ///
  /// In en, this message translates to:
  /// **'Lifted / in transit'**
  String get basicLifted;

  /// No description provided for @basicHallucination.
  ///
  /// In en, this message translates to:
  /// **'Hallucination'**
  String get basicHallucination;

  /// No description provided for @basicInvincible.
  ///
  /// In en, this message translates to:
  /// **'Invincible'**
  String get basicInvincible;

  /// No description provided for @basicKeep.
  ///
  /// In en, this message translates to:
  /// **'Keep'**
  String get basicKeep;

  /// No description provided for @basicOff.
  ///
  /// In en, this message translates to:
  /// **'Off'**
  String get basicOff;

  /// No description provided for @basicOn.
  ///
  /// In en, this message translates to:
  /// **'On'**
  String get basicOn;

  /// No description provided for @basicInherit.
  ///
  /// In en, this message translates to:
  /// **'Use game default'**
  String get basicInherit;

  /// No description provided for @basicValidFields.
  ///
  /// In en, this message translates to:
  /// **'Use stored field values'**
  String get basicValidFields;

  /// No description provided for @basicApplyStored.
  ///
  /// In en, this message translates to:
  /// **'Apply stored value'**
  String get basicApplyStored;

  /// No description provided for @basicApply.
  ///
  /// In en, this message translates to:
  /// **'Apply'**
  String get basicApply;

  /// No description provided for @basicRelationHelp.
  ///
  /// In en, this message translates to:
  /// **'Select two compatible units in the map. Linking updates mutual references; positions are kept. Unlink before changing their owner.'**
  String get basicRelationHelp;

  /// No description provided for @basicLinkAddon.
  ///
  /// In en, this message translates to:
  /// **'Link addon'**
  String get basicLinkAddon;

  /// No description provided for @basicLinkNydus.
  ///
  /// In en, this message translates to:
  /// **'Link Nydus'**
  String get basicLinkNydus;

  /// No description provided for @basicUnlink.
  ///
  /// In en, this message translates to:
  /// **'Unlink'**
  String get basicUnlink;

  /// No description provided for @basicStartsHelp.
  ///
  /// In en, this message translates to:
  /// **'Set or move the selected player’s start location. Duplicate starts are preserved and must be reviewed first.'**
  String get basicStartsHelp;

  /// No description provided for @basicPixelX.
  ///
  /// In en, this message translates to:
  /// **'Pixel X'**
  String get basicPixelX;

  /// No description provided for @basicPixelY.
  ///
  /// In en, this message translates to:
  /// **'Pixel Y'**
  String get basicPixelY;

  /// No description provided for @basicLocationsUnavailable.
  ///
  /// In en, this message translates to:
  /// **'A unique valid location table is required.'**
  String get basicLocationsUnavailable;

  /// No description provided for @basicElevationHelp.
  ///
  /// In en, this message translates to:
  /// **'Select a location and its ground/air elevation conditions. Other flag bits and strings are preserved.'**
  String get basicElevationHelp;

  /// No description provided for @basicLowGround.
  ///
  /// In en, this message translates to:
  /// **'Low ground'**
  String get basicLowGround;

  /// No description provided for @basicMediumGround.
  ///
  /// In en, this message translates to:
  /// **'Medium ground'**
  String get basicMediumGround;

  /// No description provided for @basicHighGround.
  ///
  /// In en, this message translates to:
  /// **'High ground'**
  String get basicHighGround;

  /// No description provided for @basicLowAir.
  ///
  /// In en, this message translates to:
  /// **'Low air'**
  String get basicLowAir;

  /// No description provided for @basicMediumAir.
  ///
  /// In en, this message translates to:
  /// **'Medium air'**
  String get basicMediumAir;

  /// No description provided for @basicHighAir.
  ///
  /// In en, this message translates to:
  /// **'High air'**
  String get basicHighAir;

  /// No description provided for @basicSpritesDoodads.
  ///
  /// In en, this message translates to:
  /// **'Sprites / Doodads'**
  String get basicSpritesDoodads;

  /// No description provided for @basicClipboard.
  ///
  /// In en, this message translates to:
  /// **'Clipboard'**
  String get basicClipboard;

  /// No description provided for @basicCopy.
  ///
  /// In en, this message translates to:
  /// **'Copy selection'**
  String get basicCopy;

  /// No description provided for @basicCut.
  ///
  /// In en, this message translates to:
  /// **'Cut selection'**
  String get basicCut;

  /// No description provided for @basicPaste.
  ///
  /// In en, this message translates to:
  /// **'Paste at pixel position'**
  String get basicPaste;

  /// No description provided for @basicClipboardHelp.
  ///
  /// In en, this message translates to:
  /// **'Document-local units, sprites and locations. Copy both linked units together. Start locations and unverified Doodad overlays are refused.'**
  String get basicClipboardHelp;

  /// No description provided for @basicSpriteDisabled.
  ///
  /// In en, this message translates to:
  /// **'Sprite-unit disabled'**
  String get basicSpriteDisabled;

  /// No description provided for @basicSpriteHelp.
  ///
  /// In en, this message translates to:
  /// **'Disabled applies to sprite-units only. Possible Doodad overlays require the composite tool below. Unknown flags are preserved.'**
  String get basicSpriteHelp;

  /// No description provided for @basicLoadDoodad.
  ///
  /// In en, this message translates to:
  /// **'Load selected Doodad recipe'**
  String get basicLoadDoodad;

  /// No description provided for @basicDoodadEnabled.
  ///
  /// In en, this message translates to:
  /// **'Doodad enabled'**
  String get basicDoodadEnabled;

  /// No description provided for @basicDoodadHelp.
  ///
  /// In en, this message translates to:
  /// **'Select one Doodad and explicitly choose its matching overlay. The footprint and underlying terrain must match local data. Pure-sprite enabled state is editor metadata; sprite-unit disabling also changes THG2.'**
  String get basicDoodadHelp;

  /// No description provided for @basicOverlay.
  ///
  /// In en, this message translates to:
  /// **'Matching overlay'**
  String get basicOverlay;

  /// No description provided for @basicLocationSearch.
  ///
  /// In en, this message translates to:
  /// **'Find by name or ID'**
  String get basicLocationSearch;

  /// No description provided for @basicRawTerrain.
  ///
  /// In en, this message translates to:
  /// **'Raw terrain clipboard'**
  String get basicRawTerrain;

  /// No description provided for @basicRawClipboardHelp.
  ///
  /// In en, this message translates to:
  /// **'Copies raw MTXM tiles only and preserves TILE/ISOM. This does not calculate isometric boundaries. Maps containing Doodads require verified composite editing. Coordinates below are tile coordinates.'**
  String get basicRawClipboardHelp;

  /// No description provided for @basicCutReplacement.
  ///
  /// In en, this message translates to:
  /// **'Cut fill tile value (already in map)'**
  String get basicCutReplacement;

  /// No description provided for @basicTileLeft.
  ///
  /// In en, this message translates to:
  /// **'Left tile'**
  String get basicTileLeft;

  /// No description provided for @basicTileTop.
  ///
  /// In en, this message translates to:
  /// **'Top tile'**
  String get basicTileTop;

  /// No description provided for @basicTileRight.
  ///
  /// In en, this message translates to:
  /// **'Right tile'**
  String get basicTileRight;

  /// No description provided for @basicTileBottom.
  ///
  /// In en, this message translates to:
  /// **'Bottom tile'**
  String get basicTileBottom;

  /// No description provided for @basicTileX.
  ///
  /// In en, this message translates to:
  /// **'Destination tile X'**
  String get basicTileX;

  /// No description provided for @basicTileY.
  ///
  /// In en, this message translates to:
  /// **'Destination tile Y'**
  String get basicTileY;

  /// No description provided for @basicStartMissing.
  ///
  /// In en, this message translates to:
  /// **'Missing start location'**
  String get basicStartMissing;

  /// No description provided for @basicStartDuplicate.
  ///
  /// In en, this message translates to:
  /// **'Duplicate start locations: {count}'**
  String basicStartDuplicate(int count);

  /// No description provided for @basicApplySelectedLocations.
  ///
  /// In en, this message translates to:
  /// **'Apply to selected locations'**
  String get basicApplySelectedLocations;

  /// No description provided for @basicStartCanvasHelp.
  ///
  /// In en, this message translates to:
  /// **'Click the map to fill coordinates; Apply places or moves this player\'s start location.'**
  String get basicStartCanvasHelp;
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
