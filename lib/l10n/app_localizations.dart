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

  /// No description provided for @recoveryTitle.
  ///
  /// In en, this message translates to:
  /// **'Recover Unsaved Work'**
  String get recoveryTitle;

  /// No description provided for @recoveryEmpty.
  ///
  /// In en, this message translates to:
  /// **'No recovery checkpoints.'**
  String get recoveryEmpty;

  /// No description provided for @recoveryDamaged.
  ///
  /// In en, this message translates to:
  /// **'Unreadable or damaged checkpoint'**
  String get recoveryDamaged;

  /// No description provided for @recoveryBaseline.
  ///
  /// In en, this message translates to:
  /// **'Last saved map: {path}'**
  String recoveryBaseline(String path);

  /// No description provided for @recoveryProject.
  ///
  /// In en, this message translates to:
  /// **'EUD project: {path}'**
  String recoveryProject(String path);

  /// No description provided for @recoverySource.
  ///
  /// In en, this message translates to:
  /// **'epScript: {path}'**
  String recoverySource(String path);

  /// No description provided for @recoveryOpen.
  ///
  /// In en, this message translates to:
  /// **'Open recovery copy'**
  String get recoveryOpen;

  /// No description provided for @recoveryDelete.
  ///
  /// In en, this message translates to:
  /// **'Delete checkpoint'**
  String get recoveryDelete;

  /// No description provided for @recoveryDeleteConfirm.
  ///
  /// In en, this message translates to:
  /// **'Permanently delete this recovery checkpoint?'**
  String get recoveryDeleteConfirm;

  /// No description provided for @recoverySourceChanged.
  ///
  /// In en, this message translates to:
  /// **'The last saved map changed on disk. Recovery was stopped; the checkpoint is still available.'**
  String get recoverySourceChanged;

  /// No description provided for @recoveryFailed.
  ///
  /// In en, this message translates to:
  /// **'Recovery could not be opened. Save or close unsaved documents and check the last saved map. The checkpoint is still available.'**
  String get recoveryFailed;

  /// No description provided for @autosaveSettings.
  ///
  /// In en, this message translates to:
  /// **'Autosave Settings'**
  String get autosaveSettings;

  /// No description provided for @autosaveEnabled.
  ///
  /// In en, this message translates to:
  /// **'Automatically save recovery checkpoints'**
  String get autosaveEnabled;

  /// No description provided for @autosaveInterval.
  ///
  /// In en, this message translates to:
  /// **'Interval: {seconds} seconds'**
  String autosaveInterval(int seconds);

  /// No description provided for @autosaveRetention.
  ///
  /// In en, this message translates to:
  /// **'Checkpoints per workspace: {count}'**
  String autosaveRetention(int count);

  /// No description provided for @autosaveFailed.
  ///
  /// In en, this message translates to:
  /// **'Autosave or recovery failed. Check access and free space in the application data folder.'**
  String get autosaveFailed;

  /// No description provided for @recoveryCancel.
  ///
  /// In en, this message translates to:
  /// **'Cancel'**
  String get recoveryCancel;

  /// No description provided for @recoveryClose.
  ///
  /// In en, this message translates to:
  /// **'Close'**
  String get recoveryClose;

  /// No description provided for @autosaveApply.
  ///
  /// In en, this message translates to:
  /// **'Apply'**
  String get autosaveApply;

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
  /// **'Fill or recalculate terrain, draw boundaries and heights, or place validated ramps. Preview preserves the map until Apply. Unsupported or damaged terrain is refused.'**
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

  /// No description provided for @selectionTitle.
  ///
  /// In en, this message translates to:
  /// **'Selection and navigation'**
  String get selectionTitle;

  /// No description provided for @selectionSearch.
  ///
  /// In en, this message translates to:
  /// **'Name, #type ID, layer or coordinates'**
  String get selectionSearch;

  /// No description provided for @selectionAllLayers.
  ///
  /// In en, this message translates to:
  /// **'All object layers'**
  String get selectionAllLayers;

  /// No description provided for @selectionAllOwners.
  ///
  /// In en, this message translates to:
  /// **'All owners'**
  String get selectionAllOwners;

  /// No description provided for @selectionSelectable.
  ///
  /// In en, this message translates to:
  /// **'Selectable only'**
  String get selectionSelectable;

  /// No description provided for @selectionResults.
  ///
  /// In en, this message translates to:
  /// **'Select search results'**
  String get selectionResults;

  /// No description provided for @selectionAll.
  ///
  /// In en, this message translates to:
  /// **'Select all in active layer'**
  String get selectionAll;

  /// No description provided for @selectionInvert.
  ///
  /// In en, this message translates to:
  /// **'Invert in active layer'**
  String get selectionInvert;

  /// No description provided for @selectionSameType.
  ///
  /// In en, this message translates to:
  /// **'Select same type'**
  String get selectionSameType;

  /// No description provided for @selectionSameOwner.
  ///
  /// In en, this message translates to:
  /// **'Select same owner'**
  String get selectionSameOwner;

  /// No description provided for @selectionClear.
  ///
  /// In en, this message translates to:
  /// **'Clear selection'**
  String get selectionClear;

  /// No description provided for @selectionFocus.
  ///
  /// In en, this message translates to:
  /// **'Go to selection'**
  String get selectionFocus;

  /// No description provided for @selectionFit.
  ///
  /// In en, this message translates to:
  /// **'Fit selection'**
  String get selectionFit;

  /// No description provided for @selectionFitMap.
  ///
  /// In en, this message translates to:
  /// **'Fit map'**
  String get selectionFitMap;

  /// No description provided for @selectionGoTo.
  ///
  /// In en, this message translates to:
  /// **'Go to coordinates'**
  String get selectionGoTo;

  /// No description provided for @selectionTileCoordinates.
  ///
  /// In en, this message translates to:
  /// **'Tile coordinates'**
  String get selectionTileCoordinates;

  /// No description provided for @selectionEmpty.
  ///
  /// In en, this message translates to:
  /// **'Select an object first.'**
  String get selectionEmpty;

  /// No description provided for @selectionStale.
  ///
  /// In en, this message translates to:
  /// **'The map or layer changed. Refresh your selection.'**
  String get selectionStale;

  /// No description provided for @selectionNoResults.
  ///
  /// In en, this message translates to:
  /// **'No matching objects'**
  String get selectionNoResults;

  /// No description provided for @selectionUnavailable.
  ///
  /// In en, this message translates to:
  /// **'Hidden or locked'**
  String get selectionUnavailable;

  /// No description provided for @selectionOverlap.
  ///
  /// In en, this message translates to:
  /// **'Choose an overlapping object'**
  String get selectionOverlap;

  /// No description provided for @selectionCounts.
  ///
  /// In en, this message translates to:
  /// **'{count} results · {selected} selected'**
  String selectionCounts(int count, int selected);

  /// No description provided for @eudDatLoad.
  ///
  /// In en, this message translates to:
  /// **'Load local DAT defaults'**
  String get eudDatLoad;

  /// No description provided for @eudDatUseDefault.
  ///
  /// In en, this message translates to:
  /// **'Use DAT value in input'**
  String get eudDatUseDefault;

  /// No description provided for @eudDatUnavailable.
  ///
  /// In en, this message translates to:
  /// **'Not loaded / not a DAT field'**
  String get eudDatUnavailable;

  /// No description provided for @eudDatDefault.
  ///
  /// In en, this message translates to:
  /// **'Local DAT: {value} · {source} (CHK and runtime may differ)'**
  String eudDatDefault(String value, String source);

  /// No description provided for @eudDatImpact.
  ///
  /// In en, this message translates to:
  /// **'Original users: {before}\nPlanned users: {after}\nDirect planned references: {direct}'**
  String eudDatImpact(String before, String after, String direct);

  /// No description provided for @eudDatPartial.
  ///
  /// In en, this message translates to:
  /// **'Unresolved DAT links: {count}. Static lists exclude IScript overlays and HD behavior.'**
  String eudDatPartial(int count);

  /// No description provided for @eudConflictTitle.
  ///
  /// In en, this message translates to:
  /// **'Static conflict analysis · {count} overlaps'**
  String eudConflictTitle(int count);

  /// No description provided for @eudConflictHelp.
  ///
  /// In en, this message translates to:
  /// **'Current map and open source only. Conditions, groups and dynamic code may change actual behavior; review unresolved items before a test build.'**
  String get eudConflictHelp;

  /// No description provided for @isomFillMode.
  ///
  /// In en, this message translates to:
  /// **'Fill flat terrain'**
  String get isomFillMode;

  /// No description provided for @isomConvertMode.
  ///
  /// In en, this message translates to:
  /// **'Recalculate existing ISOM'**
  String get isomConvertMode;

  /// No description provided for @isomConvertPreview.
  ///
  /// In en, this message translates to:
  /// **'{count} game tiles will change. Existing ISOM and its flags are preserved.'**
  String isomConvertPreview(int count);

  /// No description provided for @isomConvertApply.
  ///
  /// In en, this message translates to:
  /// **'Apply recalculated tiles'**
  String get isomConvertApply;

  /// No description provided for @isomBrushMode.
  ///
  /// In en, this message translates to:
  /// **'Boundary brush'**
  String get isomBrushMode;

  /// No description provided for @isomRampMode.
  ///
  /// In en, this message translates to:
  /// **'Ramp'**
  String get isomRampMode;

  /// No description provided for @isomBrushFreehand.
  ///
  /// In en, this message translates to:
  /// **'Freehand'**
  String get isomBrushFreehand;

  /// No description provided for @isomBrushRectangle.
  ///
  /// In en, this message translates to:
  /// **'Rectangle'**
  String get isomBrushRectangle;

  /// No description provided for @isomBrushSize.
  ///
  /// In en, this message translates to:
  /// **'Brush size'**
  String get isomBrushSize;

  /// No description provided for @isomBrushHint.
  ///
  /// In en, this message translates to:
  /// **'Draw on the preview. Select terrain IDs for height changes; boundaries connect automatically. Apply commits all strokes as one Undo entry.'**
  String get isomBrushHint;

  /// No description provided for @isomBrushApply.
  ///
  /// In en, this message translates to:
  /// **'Apply terrain edits'**
  String get isomBrushApply;

  /// No description provided for @isomBrushReset.
  ///
  /// In en, this message translates to:
  /// **'Reset preview'**
  String get isomBrushReset;

  /// No description provided for @isomRampHint.
  ///
  /// In en, this message translates to:
  /// **'Select a local VF4 ramp recipe, then click its top-left tile on a matching cliff. Orientation is fixed by the recipe. Incompatible terrain is refused.'**
  String get isomRampHint;

  /// No description provided for @isomRampEmpty.
  ///
  /// In en, this message translates to:
  /// **'This tileset has no verified ramp recipes.'**
  String get isomRampEmpty;

  /// No description provided for @isomRampRecipe.
  ///
  /// In en, this message translates to:
  /// **'Ramp recipe'**
  String get isomRampRecipe;

  /// No description provided for @isomBrushStrokeRejected.
  ///
  /// In en, this message translates to:
  /// **'The last stroke was rejected. The previous preview is preserved.'**
  String get isomBrushStrokeRejected;

  /// No description provided for @resizeTerrainLoading.
  ///
  /// In en, this message translates to:
  /// **'Loading verified terrain and doodad data…'**
  String get resizeTerrainLoading;

  /// No description provided for @resizeIsomFillHint.
  ///
  /// In en, this message translates to:
  /// **'Choose a flat terrain sample (zero-based tile X/Y) for added ISOM terrain. New fog cells are hidden for all players. Doodad footprints must remain fully inside the map.'**
  String get resizeIsomFillHint;

  /// No description provided for @resizeDoodadImpact.
  ///
  /// In en, this message translates to:
  /// **'Doodads moved: {moved}; footprints outside: {outside}'**
  String resizeDoodadImpact(int moved, int outside);

  /// No description provided for @resizeTerrainImpact.
  ///
  /// In en, this message translates to:
  /// **'Terrain cells recalculated: {count}. Original diamonds and verified doodad footprints are retained.'**
  String resizeTerrainImpact(int count);

  /// No description provided for @resizeCoordinateScope.
  ///
  /// In en, this message translates to:
  /// **'Trigger and EUD code coordinates are preserved. Review custom coordinates after resizing. Unknown terrain or ambiguous doodads block application.'**
  String get resizeCoordinateScope;

  /// No description provided for @editorPrepareEUDBuild.
  ///
  /// In en, this message translates to:
  /// **'Prepare EUD Build'**
  String get editorPrepareEUDBuild;

  /// No description provided for @editorBuildSavedFilesOnDiskSaveMapAndSource.
  ///
  /// In en, this message translates to:
  /// **'Build saved files on disk. Save map and source edits first. With project settings, leave source folder and entry blank for a settings-only build. Output must be a new .scx.'**
  String get editorBuildSavedFilesOnDiskSaveMapAndSource;

  /// No description provided for @editorBaseMapPath.
  ///
  /// In en, this message translates to:
  /// **'Base map path'**
  String get editorBaseMapPath;

  /// No description provided for @editorSourceFolderPath.
  ///
  /// In en, this message translates to:
  /// **'Source folder path'**
  String get editorSourceFolderPath;

  /// No description provided for @editorEntryEpsPath.
  ///
  /// In en, this message translates to:
  /// **'Entry .eps path'**
  String get editorEntryEpsPath;

  /// No description provided for @editorNewOutputScxPath.
  ///
  /// In en, this message translates to:
  /// **'New output .scx path'**
  String get editorNewOutputScxPath;

  /// No description provided for @editorToolOverrideForThisBuildOptional.
  ///
  /// In en, this message translates to:
  /// **'Tool override for this build (optional)'**
  String get editorToolOverrideForThisBuildOptional;

  /// No description provided for @editorBlankToolOverrideUsesYourEUDToolsSelectionPrepare.
  ///
  /// In en, this message translates to:
  /// **'Blank tool override uses your EUD Tools selection. Prepare checks files; Build runs the compiler separately.'**
  String get editorBlankToolOverrideUsesYourEUDToolsSelectionPrepare;

  /// No description provided for @editorITrustThisSourceAndItsImportsToRun.
  ///
  /// In en, this message translates to:
  /// **'I trust this source and its imports to run code on this computer.'**
  String get editorITrustThisSourceAndItsImportsToRun;

  /// No description provided for @editorIncludeProjectSettingsInAnUnverifiedTestBuild.
  ///
  /// In en, this message translates to:
  /// **'Include project settings in an unverified test build'**
  String get editorIncludeProjectSettingsInAnUnverifiedTestBuild;

  /// No description provided for @editorTypeSettingsInitializeOnceRulesUseTheirBeforeAfter.
  ///
  /// In en, this message translates to:
  /// **'Type settings initialize once. Rules use their before/after trigger hook; instance rules can change a guarded unit. Game and multiplayer behavior still require testing.'**
  String get editorTypeSettingsInitializeOnceRulesUseTheirBeforeAfter;

  /// No description provided for @editorCancel.
  ///
  /// In en, this message translates to:
  /// **'Cancel'**
  String get editorCancel;

  /// No description provided for @editorPrepare.
  ///
  /// In en, this message translates to:
  /// **'Prepare'**
  String get editorPrepare;

  /// No description provided for @editorEUDTools.
  ///
  /// In en, this message translates to:
  /// **'EUD Tools'**
  String get editorEUDTools;

  /// No description provided for @editorChooseAnExternalEuddraftInstallationOrUseTheApp.
  ///
  /// In en, this message translates to:
  /// **'Choose an external euddraft installation or use the app default. Project-specific paths take priority.'**
  String get editorChooseAnExternalEuddraftInstallationOrUseTheApp;

  /// No description provided for @editorExternalEuddraftPath.
  ///
  /// In en, this message translates to:
  /// **'External euddraft path'**
  String get editorExternalEuddraftPath;

  /// No description provided for @editorInstallationDirectoryOrEuddraftExeAbsolutePath.
  ///
  /// In en, this message translates to:
  /// **'Installation directory or euddraft.exe (absolute path)'**
  String get editorInstallationDirectoryOrEuddraftExeAbsolutePath;

  /// No description provided for @editorBrowseInstallationFolder.
  ///
  /// In en, this message translates to:
  /// **'Browse installation folder'**
  String get editorBrowseInstallationFolder;

  /// No description provided for @editorSelectionAppDefault.
  ///
  /// In en, this message translates to:
  /// **'Selection: App default'**
  String get editorSelectionAppDefault;

  /// No description provided for @editorSelectionExternal.
  ///
  /// In en, this message translates to:
  /// **'Selection: External\n{value0}'**
  String editorSelectionExternal(String value0);

  /// No description provided for @editorNoBundledToolIsIncludedInThisAppYet.
  ///
  /// In en, this message translates to:
  /// **'No bundled tool is included in this app yet. Select an external installation.'**
  String get editorNoBundledToolIsIncludedInThisAppYet;

  /// No description provided for @editorBundledEuddraft01025Editor1No.
  ///
  /// In en, this message translates to:
  /// **'Bundled euddraft 0.10.2.5 (editor.1)\nNo separate Python installation is required. Updates are managed with the app.\n{value0}\nLicenses and modification details: BUNDLE-NOTICE.txt in this folder.'**
  String editorBundledEuddraft01025Editor1No(String value0);

  /// No description provided for @editorInspectionPassedEuddraft.
  ///
  /// In en, this message translates to:
  /// **'Inspection passed — euddraft {value0}\n{value1}'**
  String editorInspectionPassedEuddraft(String value0, String value1);

  /// No description provided for @editorInspectionDoesNotRunTheCompilerSavingThisChoice.
  ///
  /// In en, this message translates to:
  /// **'Inspection does not run the compiler. Saving this choice does not prepare a build or change an existing build plan.'**
  String get editorInspectionDoesNotRunTheCompilerSavingThisChoice;

  /// No description provided for @editorUseAppDefault.
  ///
  /// In en, this message translates to:
  /// **'Use app default'**
  String get editorUseAppDefault;

  /// No description provided for @editorReinspect.
  ///
  /// In en, this message translates to:
  /// **'Reinspect'**
  String get editorReinspect;

  /// No description provided for @editorSaveAndInspect.
  ///
  /// In en, this message translates to:
  /// **'Save and inspect'**
  String get editorSaveAndInspect;

  /// No description provided for @editorClose.
  ///
  /// In en, this message translates to:
  /// **'Close'**
  String get editorClose;

  /// No description provided for @editorForceSettings.
  ///
  /// In en, this message translates to:
  /// **'Force Settings'**
  String get editorForceSettings;

  /// No description provided for @editorPlayerAssignment.
  ///
  /// In en, this message translates to:
  /// **'Player assignment'**
  String get editorPlayerAssignment;

  /// No description provided for @editorPlayer.
  ///
  /// In en, this message translates to:
  /// **'Player {value0}'**
  String editorPlayer(String value0);

  /// No description provided for @editorCopiesOnlyTheEditedForceAssignmentToPlayers1.
  ///
  /// In en, this message translates to:
  /// **'Copies only the edited force assignment to Players 1–8.'**
  String get editorCopiesOnlyTheEditedForceAssignmentToPlayers1;

  /// No description provided for @editorAssignToForce.
  ///
  /// In en, this message translates to:
  /// **'Assign to Force {value0}'**
  String editorAssignToForce(String value0);

  /// No description provided for @editorStoredIDPreserved.
  ///
  /// In en, this message translates to:
  /// **'Stored ID {value0} (preserved)'**
  String editorStoredIDPreserved(String value0);

  /// No description provided for @editorForce.
  ///
  /// In en, this message translates to:
  /// **'Force {value0}'**
  String editorForce(String value0);

  /// No description provided for @editorCopiesEditedForceNamesAndOptionsOnlyPlayerAssignments.
  ///
  /// In en, this message translates to:
  /// **'Copies edited force names and options only. Player assignments are separate.'**
  String get editorCopiesEditedForceNamesAndOptionsOnlyPlayerAssignments;

  /// No description provided for @editorForceName.
  ///
  /// In en, this message translates to:
  /// **'Force name'**
  String get editorForceName;

  /// No description provided for @editorRandomizeStartLocations.
  ///
  /// In en, this message translates to:
  /// **'Randomize start locations'**
  String get editorRandomizeStartLocations;

  /// No description provided for @editorAllies.
  ///
  /// In en, this message translates to:
  /// **'Allies'**
  String get editorAllies;

  /// No description provided for @editorAlliedVictory.
  ///
  /// In en, this message translates to:
  /// **'Allied victory'**
  String get editorAlliedVictory;

  /// No description provided for @editorSharedVision.
  ///
  /// In en, this message translates to:
  /// **'Shared vision'**
  String get editorSharedVision;

  /// No description provided for @editorApplyUpdatesAllEditedPlayersAndForcesSaveAs.
  ///
  /// In en, this message translates to:
  /// **'Apply updates all edited players and forces. Save As writes the map.'**
  String get editorApplyUpdatesAllEditedPlayersAndForcesSaveAs;

  /// No description provided for @editorUndo.
  ///
  /// In en, this message translates to:
  /// **'Undo: {value0}'**
  String editorUndo(String value0);

  /// No description provided for @editorRedo.
  ///
  /// In en, this message translates to:
  /// **'Redo: {value0}'**
  String editorRedo(String value0);

  /// No description provided for @editorApply.
  ///
  /// In en, this message translates to:
  /// **'Apply'**
  String get editorApply;

  /// No description provided for @editorTheExistingTextIsNotValidUTF8Its.
  ///
  /// In en, this message translates to:
  /// **'The existing text is not valid UTF-8. Its original bytes are preserved; editing is unavailable.'**
  String get editorTheExistingTextIsNotValidUTF8Its;

  /// No description provided for @editorMapInformation.
  ///
  /// In en, this message translates to:
  /// **'Map Information'**
  String get editorMapInformation;

  /// No description provided for @editorMapTitle.
  ///
  /// In en, this message translates to:
  /// **'Map title'**
  String get editorMapTitle;

  /// No description provided for @editorDescription.
  ///
  /// In en, this message translates to:
  /// **'Description'**
  String get editorDescription;

  /// No description provided for @editorApplyUpdatesThisMapOnlySharedNamesRemainUnchanged.
  ///
  /// In en, this message translates to:
  /// **'Apply updates this map only. Shared names remain unchanged. Use Save As to write the edited map.'**
  String get editorApplyUpdatesThisMapOnlySharedNamesRemainUnchanged;

  /// No description provided for @editorDiscardUnappliedSettings.
  ///
  /// In en, this message translates to:
  /// **'Discard unapplied settings?'**
  String get editorDiscardUnappliedSettings;

  /// No description provided for @editorOneOrMoreTabsHaveUnappliedDraftsAppliedChanges.
  ///
  /// In en, this message translates to:
  /// **'One or more tabs have unapplied drafts. Applied changes remain in the map and can be undone.'**
  String get editorOneOrMoreTabsHaveUnappliedDraftsAppliedChanges;

  /// No description provided for @editorKeepEditing.
  ///
  /// In en, this message translates to:
  /// **'Keep editing'**
  String get editorKeepEditing;

  /// No description provided for @editorDiscardAndClose.
  ///
  /// In en, this message translates to:
  /// **'Discard and close'**
  String get editorDiscardAndClose;

  /// No description provided for @editorMapSettings.
  ///
  /// In en, this message translates to:
  /// **'Map Settings'**
  String get editorMapSettings;

  /// No description provided for @editorMapWideSettingsTheCanvasInspectorEditsIndividualPlaced.
  ///
  /// In en, this message translates to:
  /// **'Map-wide settings. The canvas Inspector edits individual placed objects. Apply affects the current tab; Save As writes the map.'**
  String get editorMapWideSettingsTheCanvasInspectorEditsIndividualPlaced;

  /// No description provided for @editorEUDExecutionRules.
  ///
  /// In en, this message translates to:
  /// **'EUD execution rules'**
  String get editorEUDExecutionRules;

  /// No description provided for @editorMap.
  ///
  /// In en, this message translates to:
  /// **'Map'**
  String get editorMap;

  /// No description provided for @editorPlayers.
  ///
  /// In en, this message translates to:
  /// **'Players'**
  String get editorPlayers;

  /// No description provided for @editorForces.
  ///
  /// In en, this message translates to:
  /// **'Forces'**
  String get editorForces;

  /// No description provided for @editorUnits.
  ///
  /// In en, this message translates to:
  /// **'Units'**
  String get editorUnits;

  /// No description provided for @editorAvailability.
  ///
  /// In en, this message translates to:
  /// **'Availability'**
  String get editorAvailability;

  /// No description provided for @editorUpgrades.
  ///
  /// In en, this message translates to:
  /// **'Upgrades'**
  String get editorUpgrades;

  /// No description provided for @editorTech.
  ///
  /// In en, this message translates to:
  /// **'Tech'**
  String get editorTech;

  /// No description provided for @editorSlotType.
  ///
  /// In en, this message translates to:
  /// **'Slot type'**
  String get editorSlotType;

  /// No description provided for @editorRace.
  ///
  /// In en, this message translates to:
  /// **'Race'**
  String get editorRace;

  /// No description provided for @editorColor.
  ///
  /// In en, this message translates to:
  /// **'Color'**
  String get editorColor;

  /// No description provided for @editorUnavailable.
  ///
  /// In en, this message translates to:
  /// **'Unavailable'**
  String get editorUnavailable;

  /// No description provided for @editorPlayerSettings.
  ///
  /// In en, this message translates to:
  /// **'Player Settings'**
  String get editorPlayerSettings;

  /// No description provided for @editorPlayer203c6551.
  ///
  /// In en, this message translates to:
  /// **'Player {value0}{value1}'**
  String editorPlayer203c6551(String value0, String value1);

  /// No description provided for @editorReadOnly.
  ///
  /// In en, this message translates to:
  /// **' (read-only)'**
  String get editorReadOnly;

  /// No description provided for @editorSlotTypeRaceAndColorEditsForPlayablePlayers.
  ///
  /// In en, this message translates to:
  /// **'Slot type, race and color edits for playable Players 1–8 only.'**
  String get editorSlotTypeRaceAndColorEditsForPlayablePlayers;

  /// No description provided for @editorOnlyTheEightPlayableSlotsCanBeEditedPlayers.
  ///
  /// In en, this message translates to:
  /// **'Only the eight playable slots can be edited. Players 9–12 have no COLR color entry.'**
  String get editorOnlyTheEightPlayableSlotsCanBeEditedPlayers;

  /// No description provided for @editorColorSettingsAreSavedToTheMapCanvasPreviews.
  ///
  /// In en, this message translates to:
  /// **'Color settings are saved to the map. Canvas previews currently use default player colors.'**
  String get editorColorSettingsAreSavedToTheMapCanvasPreviews;

  /// No description provided for @editorPendingFieldChangesApplyUpdatesAllEditedPlayersSave.
  ///
  /// In en, this message translates to:
  /// **'{value0} pending field changes. Apply updates all edited players; Save As writes the map.'**
  String editorPendingFieldChangesApplyUpdatesAllEditedPlayersSave(
    String value0,
  );

  /// No description provided for @editorNoEditedFieldsInTheCurrentSelection.
  ///
  /// In en, this message translates to:
  /// **'No edited fields in the current selection.'**
  String get editorNoEditedFieldsInTheCurrentSelection;

  /// No description provided for @editorDraftFieldCopiesPreparedForIDsReviewThenApply.
  ///
  /// In en, this message translates to:
  /// **'{value0} draft field copies prepared for {value1} IDs. Review, then Apply.'**
  String editorDraftFieldCopiesPreparedForIDsReviewThenApply(
    String value0,
    String value1,
  );

  /// No description provided for @editorSearchNameOrID12ForExactID.
  ///
  /// In en, this message translates to:
  /// **'Search name or ID (#12 for exact ID)'**
  String get editorSearchNameOrID12ForExactID;

  /// No description provided for @editorCurrent.
  ///
  /// In en, this message translates to:
  /// **'Current: {value0}'**
  String editorCurrent(String value0);

  /// No description provided for @editorNoMatchingIDsCurrentSelectionAndDraftsAreUnchanged.
  ///
  /// In en, this message translates to:
  /// **'No matching IDs. Current selection and drafts are unchanged.'**
  String get editorNoMatchingIDsCurrentSelectionAndDraftsAreUnchanged;

  /// No description provided for @editorCopyEditedFieldsToIDs.
  ///
  /// In en, this message translates to:
  /// **'Copy edited fields to IDs'**
  String get editorCopyEditedFieldsToIDs;

  /// No description provided for @editorSource.
  ///
  /// In en, this message translates to:
  /// **'Source: {value0}. {value1}'**
  String editorSource(String value0, String value1);

  /// No description provided for @editorCopiesOnlyEditedFieldsReplacingThoseDraftFieldsAt.
  ///
  /// In en, this message translates to:
  /// **'Copies only edited fields, replacing those draft fields at the target IDs. Search does not select targets. The map changes only after Apply.'**
  String get editorCopiesOnlyEditedFieldsReplacingThoseDraftFieldsAt;

  /// No description provided for @editorTargetIDs.
  ///
  /// In en, this message translates to:
  /// **'Target IDs ({value0}–{value1})'**
  String editorTargetIDs(String value0, String value1);

  /// No description provided for @editorPrepareDraftCopies.
  ///
  /// In en, this message translates to:
  /// **'Prepare draft copies'**
  String get editorPrepareDraftCopies;

  /// No description provided for @editorUnappliedDraft.
  ///
  /// In en, this message translates to:
  /// **'Unapplied draft'**
  String get editorUnappliedDraft;

  /// No description provided for @editorTheMapChangedInAnotherEditorOrThroughUndo.
  ///
  /// In en, this message translates to:
  /// **'The map changed in another editor or through Undo/Redo. Reload before applying this tab.'**
  String get editorTheMapChangedInAnotherEditorOrThroughUndo;

  /// No description provided for @editorReloadAndDiscardThisDraft.
  ///
  /// In en, this message translates to:
  /// **'Reload and discard this draft'**
  String get editorReloadAndDiscardThisDraft;

  /// No description provided for @editorDiscardTabDraft.
  ///
  /// In en, this message translates to:
  /// **'Discard tab draft'**
  String get editorDiscardTabDraft;

  /// No description provided for @editorStarCraftDataAssets.
  ///
  /// In en, this message translates to:
  /// **'StarCraft Data Assets'**
  String get editorStarCraftDataAssets;

  /// No description provided for @editorChooseTheInstalledStarCraftRemasteredDirectoryTheEditorReads.
  ///
  /// In en, this message translates to:
  /// **'Choose the installed StarCraft: Remastered directory. The editor reads its local CASC storage through the bundled CascLib helper without extracting or copying copyrighted game data.'**
  String get editorChooseTheInstalledStarCraftRemasteredDirectoryTheEditorReads;

  /// No description provided for @editorClear.
  ///
  /// In en, this message translates to:
  /// **'Clear'**
  String get editorClear;

  /// No description provided for @editorRefresh.
  ///
  /// In en, this message translates to:
  /// **'Refresh'**
  String get editorRefresh;

  /// No description provided for @editorChooseInstallation.
  ///
  /// In en, this message translates to:
  /// **'Choose Installation…'**
  String get editorChooseInstallation;

  /// No description provided for @editorCASCBuildMiBCheckedCascLibHelper.
  ///
  /// In en, this message translates to:
  /// **'CASC {value0} • build {value1} • {value2} MiB checked • CascLib {value3} • helper {value4}'**
  String editorCASCBuildMiBCheckedCascLibHelper(
    String value0,
    String value1,
    String value2,
    String value3,
    String value4,
  );

  /// No description provided for @editorConfiguredPath.
  ///
  /// In en, this message translates to:
  /// **'Configured path'**
  String get editorConfiguredPath;

  /// No description provided for @editorNotConfigured.
  ///
  /// In en, this message translates to:
  /// **'Not configured'**
  String get editorNotConfigured;

  /// No description provided for @editorExpectedTheFolderContainingStarCraftExeBuildInfoAnd.
  ///
  /// In en, this message translates to:
  /// **'Expected: the folder containing StarCraft.exe, .build.info, and Data\\.'**
  String get editorExpectedTheFolderContainingStarCraftExeBuildInfoAnd;

  /// No description provided for @editorLoadingSettings.
  ///
  /// In en, this message translates to:
  /// **'Loading settings…'**
  String get editorLoadingSettings;

  /// No description provided for @editorInspectingAssets.
  ///
  /// In en, this message translates to:
  /// **'Inspecting assets…'**
  String get editorInspectingAssets;

  /// No description provided for @editorRequiredAssetsReady.
  ///
  /// In en, this message translates to:
  /// **'{value0}/{value1} required assets ready'**
  String editorRequiredAssetsReady(String value0, String value1);

  /// No description provided for @editorStarCraftInstallationIsNotConfigured.
  ///
  /// In en, this message translates to:
  /// **'StarCraft installation is not configured'**
  String get editorStarCraftInstallationIsNotConfigured;

  /// No description provided for @editorStarCraftCASCDataIsUnavailable.
  ///
  /// In en, this message translates to:
  /// **'StarCraft CASC data is unavailable'**
  String get editorStarCraftCASCDataIsUnavailable;

  /// No description provided for @editorRequiredAssetsFound.
  ///
  /// In en, this message translates to:
  /// **'{value0}/{value1} required assets found'**
  String editorRequiredAssetsFound(String value0, String value1);

  /// No description provided for @editorMissing.
  ///
  /// In en, this message translates to:
  /// **'Missing'**
  String get editorMissing;

  /// No description provided for @editorInvalid.
  ///
  /// In en, this message translates to:
  /// **'Invalid'**
  String get editorInvalid;

  /// No description provided for @editorUnavailableAssetFiles.
  ///
  /// In en, this message translates to:
  /// **'Unavailable asset files'**
  String get editorUnavailableAssetFiles;

  /// No description provided for @editorAndMore.
  ///
  /// In en, this message translates to:
  /// **'…and {value0} more'**
  String editorAndMore(String value0);

  /// No description provided for @editorStoredFlagPreserved.
  ///
  /// In en, this message translates to:
  /// **'Stored flag {value0} (preserved)'**
  String editorStoredFlagPreserved(String value0);

  /// No description provided for @editorTechd52bce90.
  ///
  /// In en, this message translates to:
  /// **'Tech #{value0}, {value1}: {value2}'**
  String editorTechd52bce90(String value0, String value1, String value2);

  /// No description provided for @editorEffectiveStateUnknownStoredFlagPreserved.
  ///
  /// In en, this message translates to:
  /// **'Effective state: unknown (stored flag preserved)'**
  String get editorEffectiveStateUnknownStoredFlagPreserved;

  /// No description provided for @editorEffectiveStateAvailableResearched.
  ///
  /// In en, this message translates to:
  /// **'Effective state: available {value0}, researched {value1}'**
  String editorEffectiveStateAvailableResearched(String value0, String value1);

  /// No description provided for @editorTechSettings.
  ///
  /// In en, this message translates to:
  /// **'Tech Settings'**
  String get editorTechSettings;

  /// No description provided for @editorEditing.
  ///
  /// In en, this message translates to:
  /// **'Editing {value0} / {value1}{value2}.'**
  String editorEditing(String value0, String value1, String value2);

  /// No description provided for @editorAlternateSectionsPreserved.
  ///
  /// In en, this message translates to:
  /// **'; alternate sections preserved'**
  String get editorAlternateSectionsPreserved;

  /// No description provided for @editorMapCostsAndOnlyInheritanceFlagsChangeOnlyIf.
  ///
  /// In en, this message translates to:
  /// **'Map costs and {value0} only. Inheritance flags change only if edited.'**
  String editorMapCostsAndOnlyInheritanceFlagsChangeOnlyIf(String value0);

  /// No description provided for @editorMapDefaults.
  ///
  /// In en, this message translates to:
  /// **'map defaults'**
  String get editorMapDefaults;

  /// No description provided for @editorUseCustomCosts.
  ///
  /// In en, this message translates to:
  /// **'Use custom costs'**
  String get editorUseCustomCosts;

  /// No description provided for @editorUseGameDefaults.
  ///
  /// In en, this message translates to:
  /// **'Use game defaults'**
  String get editorUseGameDefaults;

  /// No description provided for @editorGameDefaultsPreserveStoredCustomCostsDefaultGameValues.
  ///
  /// In en, this message translates to:
  /// **'Game defaults preserve stored custom costs. Default game values are not loaded here.'**
  String get editorGameDefaultsPreserveStoredCustomCostsDefaultGameValues;

  /// No description provided for @editorMapDefaultSettings.
  ///
  /// In en, this message translates to:
  /// **'Map default settings'**
  String get editorMapDefaultSettings;

  /// No description provided for @editorCopiesOnlyCurrentTechPlayerEditsToPlayers1.
  ///
  /// In en, this message translates to:
  /// **'Copies only current tech #{value0} player edits to Players 1–8. Map costs and defaults are excluded.'**
  String editorCopiesOnlyCurrentTechPlayerEditsToPlayers1(String value0);

  /// No description provided for @editorUsePlayerSettings.
  ///
  /// In en, this message translates to:
  /// **'Use player settings'**
  String get editorUsePlayerSettings;

  /// No description provided for @editorInheritMapSettings.
  ///
  /// In en, this message translates to:
  /// **'Inherit map settings'**
  String get editorInheritMapSettings;

  /// No description provided for @editorAvailable.
  ///
  /// In en, this message translates to:
  /// **'Available'**
  String get editorAvailable;

  /// No description provided for @editorNotResearched.
  ///
  /// In en, this message translates to:
  /// **'Not researched'**
  String get editorNotResearched;

  /// No description provided for @editorAlreadyResearched.
  ///
  /// In en, this message translates to:
  /// **'Already researched'**
  String get editorAlreadyResearched;

  /// No description provided for @editorMapSettingsAffectInheritingPlayersInheritancePreservesStoredPlayer.
  ///
  /// In en, this message translates to:
  /// **'Map settings affect inheriting players. Inheritance preserves stored player flags. Availability and research status are independent.'**
  String
  get editorMapSettingsAffectInheritingPlayersInheritancePreservesStoredPlayer;

  /// No description provided for @editorPendingChangesAcrossTechsAndPlayersApplyUpdatesThe.
  ///
  /// In en, this message translates to:
  /// **'{value0} pending changes across techs and players. Apply updates the document; Save As writes the map.'**
  String editorPendingChangesAcrossTechsAndPlayersApplyUpdatesThe(
    String value0,
  );

  /// No description provided for @editorUnitAvailability.
  ///
  /// In en, this message translates to:
  /// **'Unit Availability'**
  String get editorUnitAvailability;

  /// No description provided for @editorMapWideUnitProductionSettingsSeparateFromPlacedUnit.
  ///
  /// In en, this message translates to:
  /// **'Map-wide unit production settings, separate from placed-unit Inspector properties.'**
  String get editorMapWideUnitProductionSettingsSeparateFromPlacedUnit;

  /// No description provided for @editorUnit.
  ///
  /// In en, this message translates to:
  /// **'Unit'**
  String get editorUnit;

  /// No description provided for @editorMapDefaultsAndPlayerOnlyInheritanceChangesOnlyIf.
  ///
  /// In en, this message translates to:
  /// **'Map defaults and Player {value0} only. Inheritance changes only if edited.'**
  String editorMapDefaultsAndPlayerOnlyInheritanceChangesOnlyIf(String value0);

  /// No description provided for @editorMapDefaultAffectsAllInheritingPlayers.
  ///
  /// In en, this message translates to:
  /// **'Map default — affects all inheriting players'**
  String get editorMapDefaultAffectsAllInheritingPlayers;

  /// No description provided for @editorDefaultProhibited.
  ///
  /// In en, this message translates to:
  /// **'Default: prohibited'**
  String get editorDefaultProhibited;

  /// No description provided for @editorDefaultAllowed.
  ///
  /// In en, this message translates to:
  /// **'Default: allowed'**
  String get editorDefaultAllowed;

  /// No description provided for @editorCopiesOnlyCurrentUnitPlayerEditsToPlayers1.
  ///
  /// In en, this message translates to:
  /// **'Copies only current Unit #{value0} player edits to Players 1–8. Map defaults are excluded.'**
  String editorCopiesOnlyCurrentUnitPlayerEditsToPlayers1(String value0);

  /// No description provided for @editorPlayerSettingSource.
  ///
  /// In en, this message translates to:
  /// **'Player setting source'**
  String get editorPlayerSettingSource;

  /// No description provided for @editorUsePlayerOverride.
  ///
  /// In en, this message translates to:
  /// **'Use player override'**
  String get editorUsePlayerOverride;

  /// No description provided for @editorInheritMapDefault.
  ///
  /// In en, this message translates to:
  /// **'Inherit map default'**
  String get editorInheritMapDefault;

  /// No description provided for @editorStoredPlayerOverride.
  ///
  /// In en, this message translates to:
  /// **'Stored player override'**
  String get editorStoredPlayerOverride;

  /// No description provided for @editorPlayerProhibited.
  ///
  /// In en, this message translates to:
  /// **'Player: prohibited'**
  String get editorPlayerProhibited;

  /// No description provided for @editorPlayerAllowed.
  ///
  /// In en, this message translates to:
  /// **'Player: allowed'**
  String get editorPlayerAllowed;

  /// No description provided for @editorEffectiveAvailability.
  ///
  /// In en, this message translates to:
  /// **'Effective availability: {value0}'**
  String editorEffectiveAvailability(String value0);

  /// No description provided for @editorUnknownStoredFlagsPreserved.
  ///
  /// In en, this message translates to:
  /// **'unknown (stored flags preserved)'**
  String get editorUnknownStoredFlagsPreserved;

  /// No description provided for @editorInheritancePreservesTheStoredOverrideAvailabilityDoesNotBypass.
  ///
  /// In en, this message translates to:
  /// **'Inheritance preserves the stored override. Availability does not bypass game prerequisites or create placed units.'**
  String
  get editorInheritancePreservesTheStoredOverrideAvailabilityDoesNotBypass;

  /// No description provided for @editorPendingChangesApplyUpdatesAllEditedUnitsAndPlayers.
  ///
  /// In en, this message translates to:
  /// **'{value0} pending changes. Apply updates all edited units and players; Save As writes the map.'**
  String editorPendingChangesApplyUpdatesAllEditedUnitsAndPlayers(
    String value0,
  );

  /// No description provided for @editorLocalWeaponReferencesUnavailableConfigureStarCraftAssetsAndRetry.
  ///
  /// In en, this message translates to:
  /// **'Local weapon references unavailable. Configure StarCraft assets and retry.'**
  String
  get editorLocalWeaponReferencesUnavailableConfigureStarCraftAssetsAndRetry;

  /// No description provided for @editorUnit88a3c859.
  ///
  /// In en, this message translates to:
  /// **'{value0}\nUnit #{value1}'**
  String editorUnit88a3c859(String value0, String value1);

  /// No description provided for @editorUnitPreviewRequiresLocalStarCraftGraphics.
  ///
  /// In en, this message translates to:
  /// **'Unit preview requires local StarCraft graphics.'**
  String get editorUnitPreviewRequiresLocalStarCraftGraphics;

  /// No description provided for @editorConfigureStarCraftAssetsToLoadUnitLinks.
  ///
  /// In en, this message translates to:
  /// **'Configure StarCraft assets to load unit links.'**
  String get editorConfigureStarCraftAssetsToLoadUnitLinks;

  /// No description provided for @editorGround.
  ///
  /// In en, this message translates to:
  /// **'Ground'**
  String get editorGround;

  /// No description provided for @editorAir.
  ///
  /// In en, this message translates to:
  /// **'Air'**
  String get editorAir;

  /// No description provided for @editorNone.
  ///
  /// In en, this message translates to:
  /// **'{value0}: None'**
  String editorNone(String value0);

  /// No description provided for @editorSubunit.
  ///
  /// In en, this message translates to:
  /// **'Subunit: {value0} (#{value1})'**
  String editorSubunit(String value0, String value1);

  /// No description provided for @editorSubunitWeaponsKeepsTheSelectedUnit.
  ///
  /// In en, this message translates to:
  /// **'Subunit weapons — keeps the selected unit'**
  String get editorSubunitWeaponsKeepsTheSelectedUnit;

  /// No description provided for @editorNoLinkedWeaponSelectAWeaponManually.
  ///
  /// In en, this message translates to:
  /// **'No linked weapon. Select a weapon manually.'**
  String get editorNoLinkedWeaponSelectAWeaponManually;

  /// No description provided for @editorAutoSelectedFromWeaponChangesAffectAllUnitsSharing.
  ///
  /// In en, this message translates to:
  /// **'Auto-selected: {value0} (#{value1}) from {value2}. Weapon changes affect all units sharing it.'**
  String editorAutoSelectedFromWeaponChangesAffectAllUnitsSharing(
    String value0,
    String value1,
    String value2,
  );

  /// No description provided for @editorRetryUnitLinks.
  ///
  /// In en, this message translates to:
  /// **'Retry unit links'**
  String get editorRetryUnitLinks;

  /// No description provided for @editorUnit24496eb9.
  ///
  /// In en, this message translates to:
  /// **'Unit #{value0}: {value1}'**
  String editorUnit24496eb9(String value0, String value1);

  /// No description provided for @editorWeaponDamageMustBeAnIntegerFrom0To.
  ///
  /// In en, this message translates to:
  /// **'Weapon #{value0}: damage must be an integer from 0 to 65535.'**
  String editorWeaponDamageMustBeAnIntegerFrom0To(String value0);

  /// No description provided for @editorUnitSettings.
  ///
  /// In en, this message translates to:
  /// **'Unit Settings'**
  String get editorUnitSettings;

  /// No description provided for @editorMapWideUnitTypesSeparateFromPlacedUnitProperties.
  ///
  /// In en, this message translates to:
  /// **'Map-wide unit types, separate from placed-unit properties.'**
  String get editorMapWideUnitTypesSeparateFromPlacedUnitProperties;

  /// No description provided for @editorEditing4dc9e6e6.
  ///
  /// In en, this message translates to:
  /// **'Editing {value0}{value1}.'**
  String editorEditing4dc9e6e6(String value0, String value1);

  /// No description provided for @editorAlternateSectionPreservedWithoutSynchronization.
  ///
  /// In en, this message translates to:
  /// **'; alternate section preserved without synchronization'**
  String get editorAlternateSectionPreservedWithoutSynchronization;

  /// No description provided for @editorUnit38894196.
  ///
  /// In en, this message translates to:
  /// **'{value0} (Unit #{value1})'**
  String editorUnit38894196(String value0, String value1);

  /// No description provided for @editorUnitValuesNamesAndDefaultFlagsOnlySharedWeapon.
  ///
  /// In en, this message translates to:
  /// **'Unit values, names and default flags only. Shared weapon damage uses its own selection below.'**
  String get editorUnitValuesNamesAndDefaultFlagsOnlySharedWeapon;

  /// No description provided for @editorUseCustomValues.
  ///
  /// In en, this message translates to:
  /// **'Use custom values'**
  String get editorUseCustomValues;

  /// No description provided for @editorStoredDefaultFlagPreserved.
  ///
  /// In en, this message translates to:
  /// **'Stored default flag {value0} (preserved)'**
  String editorStoredDefaultFlagPreserved(String value0);

  /// No description provided for @editorFieldsShowStoredCustomValuesGameDefaultNumbersAre.
  ///
  /// In en, this message translates to:
  /// **'Fields show stored custom values. Game default numbers are not loaded.'**
  String get editorFieldsShowStoredCustomValuesGameDefaultNumbersAre;

  /// No description provided for @editorRestoreSelectedUnitDefaults.
  ///
  /// In en, this message translates to:
  /// **'Restore selected unit defaults'**
  String get editorRestoreSelectedUnitDefaults;

  /// No description provided for @editorUnitNameEmptyGameName.
  ///
  /// In en, this message translates to:
  /// **'Unit name (empty = game name)'**
  String get editorUnitNameEmptyGameName;

  /// No description provided for @editorSharedWeaponDamage.
  ///
  /// In en, this message translates to:
  /// **'Shared weapon damage'**
  String get editorSharedWeaponDamage;

  /// No description provided for @editorAWeaponChangeAffectsEveryUnitUsingThatWeapon.
  ///
  /// In en, this message translates to:
  /// **'A weapon change affects every unit using that weapon. Restoring a unit does not reset shared weapon damage.'**
  String get editorAWeaponChangeAffectsEveryUnitUsingThatWeapon;

  /// No description provided for @editorWeapon.
  ///
  /// In en, this message translates to:
  /// **'Weapon'**
  String get editorWeapon;

  /// No description provided for @editorSharedWeaponDamageOnlyAllUnitsReferencingTargetWeapons.
  ///
  /// In en, this message translates to:
  /// **'Shared weapon damage only. All units referencing target weapons may be affected.'**
  String get editorSharedWeaponDamageOnlyAllUnitsReferencingTargetWeapons;

  /// No description provided for @editorDamagePerUpgrade.
  ///
  /// In en, this message translates to:
  /// **'Damage per upgrade'**
  String get editorDamagePerUpgrade;

  /// No description provided for @editorBaseDamage.
  ///
  /// In en, this message translates to:
  /// **'Base damage'**
  String get editorBaseDamage;

  /// No description provided for @editorApplyUpdatesAllEditedUnitTypesAndWeaponsSave.
  ///
  /// In en, this message translates to:
  /// **'Apply updates all edited unit types and weapons. Save As writes the map.'**
  String get editorApplyUpdatesAllEditedUnitTypesAndWeaponsSave;

  /// No description provided for @editorUpgrade.
  ///
  /// In en, this message translates to:
  /// **'Upgrade #{value0}, {value1}: {value2}'**
  String editorUpgrade(String value0, String value1, String value2);

  /// No description provided for @editorEffectiveLevelsUnknownStoredFlagPreserved.
  ///
  /// In en, this message translates to:
  /// **'Effective levels: unknown (stored flag preserved)'**
  String get editorEffectiveLevelsUnknownStoredFlagPreserved;

  /// No description provided for @editorEffectiveLevelsStartMaximum.
  ///
  /// In en, this message translates to:
  /// **'Effective levels: {value0} / {value1} (start / maximum)'**
  String editorEffectiveLevelsStartMaximum(String value0, String value1);

  /// No description provided for @editorUpgradeSettings.
  ///
  /// In en, this message translates to:
  /// **'Upgrade Settings'**
  String get editorUpgradeSettings;

  /// No description provided for @editorUpgraded423b17.
  ///
  /// In en, this message translates to:
  /// **'Upgrade'**
  String get editorUpgraded423b17;

  /// No description provided for @editorMapDefaultLevels.
  ///
  /// In en, this message translates to:
  /// **'Map default levels'**
  String get editorMapDefaultLevels;

  /// No description provided for @editorCopiesOnlyCurrentUpgradePlayerEditsToPlayers1.
  ///
  /// In en, this message translates to:
  /// **'Copies only current upgrade #{value0} player edits to Players 1–8. Map costs and defaults are excluded.'**
  String editorCopiesOnlyCurrentUpgradePlayerEditsToPlayers1(String value0);

  /// No description provided for @editorUsePlayerLevels.
  ///
  /// In en, this message translates to:
  /// **'Use player levels'**
  String get editorUsePlayerLevels;

  /// No description provided for @editorInheritMapLevels.
  ///
  /// In en, this message translates to:
  /// **'Inherit map levels'**
  String get editorInheritMapLevels;

  /// No description provided for @editorMapLevelsAffectInheritingPlayersInheritancePreservesStoredPlayer.
  ///
  /// In en, this message translates to:
  /// **'Map levels affect inheriting players. Inheritance preserves stored player levels. Starting level must not exceed maximum.'**
  String
  get editorMapLevelsAffectInheritingPlayersInheritancePreservesStoredPlayer;

  /// No description provided for @editorPendingChangesAcrossUpgradesAndPlayersApplyUpdatesThe.
  ///
  /// In en, this message translates to:
  /// **'{value0} pending changes across upgrades and players. Apply updates the document; Save As writes the map.'**
  String editorPendingChangesAcrossUpgradesAndPlayersApplyUpdatesThe(
    String value0,
  );

  /// No description provided for @editorLoadingLocalWeaponReferences.
  ///
  /// In en, this message translates to:
  /// **'Loading local weapon references…'**
  String get editorLoadingLocalWeaponReferences;

  /// No description provided for @editorWeaponReferenceListUnavailable.
  ///
  /// In en, this message translates to:
  /// **'Weapon reference list unavailable: {value0}'**
  String editorWeaponReferenceListUnavailable(String value0);

  /// No description provided for @editorSourceChanged.
  ///
  /// In en, this message translates to:
  /// **'source changed'**
  String get editorSourceChanged;

  /// No description provided for @editorReloadWeaponReferences.
  ///
  /// In en, this message translates to:
  /// **'Reload weapon references'**
  String get editorReloadWeaponReferences;

  /// No description provided for @editorNoneInThisDATSnapshot.
  ///
  /// In en, this message translates to:
  /// **'None in this DAT snapshot'**
  String get editorNoneInThisDATSnapshot;

  /// No description provided for @editorWeaponDirectGroundAirReferences.
  ///
  /// In en, this message translates to:
  /// **'Weapon #{value0} — direct ground/air references: {value1}'**
  String editorWeaponDirectGroundAirReferences(String value0, String value1);

  /// No description provided for @editorUnitsReferencingThoseSubunits.
  ///
  /// In en, this message translates to:
  /// **'Units referencing those subunits: {value0}'**
  String editorUnitsReferencingThoseSubunits(String value0);

  /// No description provided for @editorSource854c792f.
  ///
  /// In en, this message translates to:
  /// **'Source: {value0}'**
  String editorSource854c792f(String value0);

  /// No description provided for @editorDATReferencesOnlySpellsSpawnedProjectilesUnitsAndEUD.
  ///
  /// In en, this message translates to:
  /// **'DAT references only. Spells, spawned projectiles/units and EUD runtime changes may have additional effects.'**
  String get editorDATReferencesOnlySpellsSpawnedProjectilesUnitsAndEUD;

  /// No description provided for @editorOpenAMapToManageResources.
  ///
  /// In en, this message translates to:
  /// **'Open a map to manage resources.'**
  String get editorOpenAMapToManageResources;

  /// No description provided for @editorResources.
  ///
  /// In en, this message translates to:
  /// **'Resources'**
  String get editorResources;

  /// No description provided for @editorUndo71fd4acf.
  ///
  /// In en, this message translates to:
  /// **'Undo'**
  String get editorUndo71fd4acf;

  /// No description provided for @editorRedo7412e5e9.
  ///
  /// In en, this message translates to:
  /// **'Redo'**
  String get editorRedo7412e5e9;

  /// No description provided for @editorAddString.
  ///
  /// In en, this message translates to:
  /// **'Add string'**
  String get editorAddString;

  /// No description provided for @editorImportPCMWAV.
  ///
  /// In en, this message translates to:
  /// **'Import PCM WAV'**
  String get editorImportPCMWAV;

  /// No description provided for @editorStopPreview.
  ///
  /// In en, this message translates to:
  /// **'Stop preview'**
  String get editorStopPreview;

  /// No description provided for @editorStringsBytesOffsetLimitSaveAsWritesPendingResource.
  ///
  /// In en, this message translates to:
  /// **'{value0} strings • {value1} bytes • offset limit {value2} • Save As writes pending resource changes.'**
  String editorStringsBytesOffsetLimitSaveAsWritesPendingResource(
    String value0,
    String value1,
    String value2,
  );

  /// No description provided for @editorReferenceCoverageIncompleteDeletionRestricted.
  ///
  /// In en, this message translates to:
  /// **'Reference coverage incomplete — deletion restricted'**
  String get editorReferenceCoverageIncompleteDeletionRestricted;

  /// No description provided for @editorArchiveListingIncompleteUnlistedSoundsMayExistImportsDeletions.
  ///
  /// In en, this message translates to:
  /// **'Archive listing incomplete. Unlisted sounds may exist; imports/deletions are restricted.'**
  String
  get editorArchiveListingIncompleteUnlistedSoundsMayExistImportsDeletions;

  /// No description provided for @editorSearchTextStringIDOrSoundPath.
  ///
  /// In en, this message translates to:
  /// **'Search text, string ID or sound path'**
  String get editorSearchTextStringIDOrSoundPath;

  /// No description provided for @editorWorking.
  ///
  /// In en, this message translates to:
  /// **'Working…'**
  String get editorWorking;

  /// No description provided for @editorStrings.
  ///
  /// In en, this message translates to:
  /// **'Strings'**
  String get editorStrings;

  /// No description provided for @editorSounds.
  ///
  /// In en, this message translates to:
  /// **'Sounds'**
  String get editorSounds;

  /// No description provided for @editorInvalidUTF8RawBytesPreserved.
  ///
  /// In en, this message translates to:
  /// **'Invalid UTF-8 — raw bytes preserved'**
  String get editorInvalidUTF8RawBytesPreserved;

  /// No description provided for @editorBytesKnownUseS.
  ///
  /// In en, this message translates to:
  /// **'{value0} bytes • {value1} known use(s){value2}'**
  String editorBytesKnownUseS(String value0, String value1, String value2);

  /// No description provided for @editorExplicitReplacementRequired.
  ///
  /// In en, this message translates to:
  /// **' • explicit replacement required'**
  String get editorExplicitReplacementRequired;

  /// No description provided for @editorClearUnreferencedString.
  ///
  /// In en, this message translates to:
  /// **'Clear unreferenced string'**
  String get editorClearUnreferencedString;

  /// No description provided for @editorBytesPendingImport.
  ///
  /// In en, this message translates to:
  /// **'{value0} bytes • pending import'**
  String editorBytesPendingImport(String value0);

  /// No description provided for @editorReferencedPathNotListedInThisMap.
  ///
  /// In en, this message translates to:
  /// **'Referenced path; not listed in this map'**
  String get editorReferencedPathNotListedInThisMap;

  /// No description provided for @editorBytesLocale.
  ///
  /// In en, this message translates to:
  /// **'{value0} bytes • locale {value1}'**
  String editorBytesLocale(String value0, String value1);

  /// No description provided for @editorPreviewSound.
  ///
  /// In en, this message translates to:
  /// **'Preview sound'**
  String get editorPreviewSound;

  /// No description provided for @editorExportSound.
  ///
  /// In en, this message translates to:
  /// **'Export sound'**
  String get editorExportSound;

  /// No description provided for @editorDeleteSound.
  ///
  /// In en, this message translates to:
  /// **'Delete sound'**
  String get editorDeleteSound;

  /// No description provided for @editorDeleteSoundf1d564e6.
  ///
  /// In en, this message translates to:
  /// **'Delete sound?'**
  String get editorDeleteSoundf1d564e6;

  /// No description provided for @editorRemovalAppliesOnSaveAsUndoRestoresThisEdit.
  ///
  /// In en, this message translates to:
  /// **'{value0}\nRemoval applies on Save As. Undo restores this edit.'**
  String editorRemovalAppliesOnSaveAsUndoRestoresThisEdit(String value0);

  /// No description provided for @editorDelete.
  ///
  /// In en, this message translates to:
  /// **'Delete'**
  String get editorDelete;

  /// No description provided for @editorMapChanged.
  ///
  /// In en, this message translates to:
  /// **'Map changed.'**
  String get editorMapChanged;

  /// No description provided for @editorResourcesAreReadOnly.
  ///
  /// In en, this message translates to:
  /// **'Resources are read-only: {value0}'**
  String editorResourcesAreReadOnly(String value0);

  /// No description provided for @editorInvalidUTF8EnterExplicitReplacementTextOriginalBytes.
  ///
  /// In en, this message translates to:
  /// **'Invalid UTF-8. Enter explicit replacement text; original bytes remain until Apply.'**
  String get editorInvalidUTF8EnterExplicitReplacementTextOriginalBytes;

  /// No description provided for @editorString.
  ///
  /// In en, this message translates to:
  /// **'String #{value0}'**
  String editorString(String value0);

  /// No description provided for @editorEditSharedIDAffectsAllReferences.
  ///
  /// In en, this message translates to:
  /// **'Edit shared ID — affects all references'**
  String get editorEditSharedIDAffectsAllReferences;

  /// No description provided for @editorSeparate.
  ///
  /// In en, this message translates to:
  /// **'Separate: {value0}'**
  String editorSeparate(String value0);

  /// No description provided for @editorAdditionalUnknownUsesMayExistNoAutomaticCleanupIs.
  ///
  /// In en, this message translates to:
  /// **'Additional unknown uses may exist. No automatic cleanup is performed.'**
  String get editorAdditionalUnknownUsesMayExistNoAutomaticCleanupIs;

  /// No description provided for @editorUTF8Text.
  ///
  /// In en, this message translates to:
  /// **'UTF-8 text'**
  String get editorUTF8Text;

  /// No description provided for @editorKnownReferences.
  ///
  /// In en, this message translates to:
  /// **'{value0} known references'**
  String editorKnownReferences(String value0);

  /// No description provided for @editorWriteEpScriptHere.
  ///
  /// In en, this message translates to:
  /// **'// Write epScript here'**
  String get editorWriteEpScriptHere;

  /// No description provided for @editorModified.
  ///
  /// In en, this message translates to:
  /// **'Modified'**
  String get editorModified;

  /// No description provided for @editorClean.
  ///
  /// In en, this message translates to:
  /// **'Clean'**
  String get editorClean;

  /// No description provided for @editorInMemoryDraft.
  ///
  /// In en, this message translates to:
  /// **'In-memory draft'**
  String get editorInMemoryDraft;

  /// No description provided for @editorLnCol.
  ///
  /// In en, this message translates to:
  /// **'Ln {value0}, Col {value1}'**
  String editorLnCol(String value0, String value1);

  /// No description provided for @editorActionSReferenceThisSlotApplyingChangesAffectsAll.
  ///
  /// In en, this message translates to:
  /// **'{value0} action(s) reference this slot. Applying changes affects all of them.'**
  String editorActionSReferenceThisSlotApplyingChangesAffectsAll(String value0);

  /// No description provided for @editorNewStringIDUseThisIDInATrigger.
  ///
  /// In en, this message translates to:
  /// **'New string ID: {value0}. Use this ID in a trigger action.'**
  String editorNewStringIDUseThisIDInATrigger(String value0);

  /// No description provided for @editorAddTriggerText.
  ///
  /// In en, this message translates to:
  /// **'Add trigger text'**
  String get editorAddTriggerText;

  /// No description provided for @editorSwitchNames.
  ///
  /// In en, this message translates to:
  /// **'Switch names'**
  String get editorSwitchNames;

  /// No description provided for @editorUnitPropertySlots.
  ///
  /// In en, this message translates to:
  /// **'Unit property slots'**
  String get editorUnitPropertySlots;

  /// No description provided for @editorID.
  ///
  /// In en, this message translates to:
  /// **'{value0} ID {value1}'**
  String editorID(String value0, String value1);

  /// No description provided for @editorProperty.
  ///
  /// In en, this message translates to:
  /// **'Property'**
  String get editorProperty;

  /// No description provided for @editorSwitch.
  ///
  /// In en, this message translates to:
  /// **'Switch'**
  String get editorSwitch;

  /// No description provided for @editorText.
  ///
  /// In en, this message translates to:
  /// **'Text'**
  String get editorText;

  /// No description provided for @editorUncheckedValuesInheritTheGameDefaultSpecialStatesCan.
  ///
  /// In en, this message translates to:
  /// **'Unchecked values inherit the game default. Special states can inherit, enable or disable.'**
  String get editorUncheckedValuesInheritTheGameDefaultSpecialStatesCan;

  /// No description provided for @editorInherit.
  ///
  /// In en, this message translates to:
  /// **'Inherit'**
  String get editorInherit;

  /// No description provided for @editorEnabled.
  ///
  /// In en, this message translates to:
  /// **'Enabled'**
  String get editorEnabled;

  /// No description provided for @editorDisabled.
  ///
  /// In en, this message translates to:
  /// **'Disabled'**
  String get editorDisabled;

  /// No description provided for @editorPrepareChanges.
  ///
  /// In en, this message translates to:
  /// **'Prepare changes'**
  String get editorPrepareChanges;

  /// No description provided for @editorApplyToMap.
  ///
  /// In en, this message translates to:
  /// **'Apply to map'**
  String get editorApplyToMap;

  /// No description provided for @editorYes.
  ///
  /// In en, this message translates to:
  /// **'yes'**
  String get editorYes;

  /// No description provided for @editorNo.
  ///
  /// In en, this message translates to:
  /// **'no'**
  String get editorNo;

  /// No description provided for @editorUnknown.
  ///
  /// In en, this message translates to:
  /// **'unknown'**
  String get editorUnknown;

  /// No description provided for @editorAllowed.
  ///
  /// In en, this message translates to:
  /// **'allowed'**
  String get editorAllowed;

  /// No description provided for @editorProhibited.
  ///
  /// In en, this message translates to:
  /// **'prohibited'**
  String get editorProhibited;

  /// No description provided for @editorMapdfa2efb1.
  ///
  /// In en, this message translates to:
  /// **'map'**
  String get editorMapdfa2efb1;

  /// No description provided for @editorTheCHKSectionHeaderIsTruncatedAtByteOffset.
  ///
  /// In en, this message translates to:
  /// **'The CHK section header is truncated at byte offset {value0}.'**
  String editorTheCHKSectionHeaderIsTruncatedAtByteOffset(String value0);

  /// No description provided for @editorUseAnIntactScenarioChkOrOpenTheMap.
  ///
  /// In en, this message translates to:
  /// **'Use an intact scenario.chk or open the map as read-only.'**
  String get editorUseAnIntactScenarioChkOrOpenTheMap;

  /// No description provided for @editorSectionDeclaresBytesButOnlyBytesRemain.
  ///
  /// In en, this message translates to:
  /// **'Section \"{value0}\" declares {value1} bytes, but only {value2} bytes remain.'**
  String editorSectionDeclaresBytesButOnlyBytesRemain(
    String value0,
    String value1,
    String value2,
  );

  /// No description provided for @editorSectionMustContainExactlyPayloadBytesButContains.
  ///
  /// In en, this message translates to:
  /// **'Section \"{value0}\" must contain exactly {value1} payload bytes, but contains {value2}.'**
  String editorSectionMustContainExactlyPayloadBytesButContains(
    String value0,
    String value1,
    String value2,
  );

  /// No description provided for @editorKeepThisSectionUnchangedAndTreatTheMapAs.
  ///
  /// In en, this message translates to:
  /// **'Keep this section unchanged and treat the map as read-only.'**
  String get editorKeepThisSectionUnchangedAndTreatTheMapAs;

  /// No description provided for @editorIsOutsideTheMapPixelBounds.
  ///
  /// In en, this message translates to:
  /// **'{value0} {value1} is outside the map pixel bounds.'**
  String editorIsOutsideTheMapPixelBounds(String value0, String value1);

  /// No description provided for @editorMoveTheObjectInside0By0OrKeep.
  ///
  /// In en, this message translates to:
  /// **'Move the object inside 0..{value0} by 0..{value1}, or keep the raw record unchanged if the value is intentional EUD data.'**
  String editorMoveTheObjectInside0By0OrKeep(String value0, String value1);

  /// No description provided for @editorRefersToPlayerValueOutsideTheSupported011.
  ///
  /// In en, this message translates to:
  /// **'{value0} {value1} refers to player value {value2}, outside the supported 0..11 range.'**
  String editorRefersToPlayerValueOutsideTheSupported011(
    String value0,
    String value1,
    String value2,
  );

  /// No description provided for @editorChoosePlayer1ThroughPlayer12OrKeepThe.
  ///
  /// In en, this message translates to:
  /// **'Choose Player 1 through Player 12, or keep the raw value unchanged if it is intentional EUD data.'**
  String get editorChoosePlayer1ThroughPlayer12OrKeepThe;

  /// No description provided for @editorLocationDoesNotFormAValidRectangleInsideThe.
  ///
  /// In en, this message translates to:
  /// **'Location {value0} does not form a valid rectangle inside the map.'**
  String editorLocationDoesNotFormAValidRectangleInsideThe(String value0);

  /// No description provided for @editorUseLeftRightAndTopBottomInside0By.
  ///
  /// In en, this message translates to:
  /// **'Use left < right and top < bottom inside 0..{value0} by 0..{value1}, or preserve the raw value if intentional.'**
  String editorUseLeftRightAndTopBottomInside0By(String value0, String value1);

  /// No description provided for @editorUsesStringIDButMultipleSTRSTRxTablesMake.
  ///
  /// In en, this message translates to:
  /// **'{value0} uses string ID {value1}, but multiple STR/STRx tables make the reference ambiguous.'**
  String editorUsesStringIDButMultipleSTRSTRxTablesMake(
    String value0,
    String value1,
  );

  /// No description provided for @editorInspectTheRawStringSectionsTheEditorWillNot.
  ///
  /// In en, this message translates to:
  /// **'Inspect the raw string sections; the editor will not guess an active table.'**
  String get editorInspectTheRawStringSectionsTheEditorWillNot;

  /// No description provided for @editorUsesStringIDButNoReadableSTRSTRxTable.
  ///
  /// In en, this message translates to:
  /// **'{value0} uses string ID {value1}, but no readable STR/STRx table is available.'**
  String editorUsesStringIDButNoReadableSTRSTRxTable(
    String value0,
    String value1,
  );

  /// No description provided for @editorInspectTheRawStringTableBeforeChangingThisReference.
  ///
  /// In en, this message translates to:
  /// **'Inspect the raw string table before changing this reference.'**
  String get editorInspectTheRawStringTableBeforeChangingThisReference;

  /// No description provided for @editorUsesStringIDButTheTableContainsOnlyEntries.
  ///
  /// In en, this message translates to:
  /// **'{value0} uses string ID {value1}, but the table contains only {value2} entries.'**
  String editorUsesStringIDButTheTableContainsOnlyEntries(
    String value0,
    String value1,
    String value2,
  );

  /// No description provided for @editorChooseAnExistingStringIDOrClearTheReference.
  ///
  /// In en, this message translates to:
  /// **'Choose an existing string ID or clear the reference to ID 0.'**
  String get editorChooseAnExistingStringIDOrClearTheReference;

  /// No description provided for @editorUsesStringIDWhoseRawEntryCannotBeResolved.
  ///
  /// In en, this message translates to:
  /// **'{value0} uses string ID {value1}, whose raw entry cannot be resolved safely.'**
  String editorUsesStringIDWhoseRawEntryCannotBeResolved(
    String value0,
    String value1,
  );

  /// No description provided for @editorInspectTheStringTableStructuralDiagnosticsAndPreserveThe.
  ///
  /// In en, this message translates to:
  /// **'Inspect the string table structural diagnostics and preserve the raw reference until the source is understood.'**
  String get editorInspectTheStringTableStructuralDiagnosticsAndPreserveThe;

  /// No description provided for @editorSectionEndsWithAnIncompleteByteRecord.
  ///
  /// In en, this message translates to:
  /// **'Section \"{value0}\" ends with an incomplete {value1}-byte {value2} record.'**
  String editorSectionEndsWithAnIncompleteByteRecord(
    String value0,
    String value1,
    String value2,
  );

  /// No description provided for @editorKeepThisObjectSectionUnchangedAndReadOnly.
  ///
  /// In en, this message translates to:
  /// **'Keep this object section unchanged and read-only.'**
  String get editorKeepThisObjectSectionUnchangedAndReadOnly;

  /// No description provided for @editorSectionMustContainEither64Or255CompleteLocation.
  ///
  /// In en, this message translates to:
  /// **'Section \"{value0}\" must contain either 64 or 255 complete location records.'**
  String editorSectionMustContainEither64Or255CompleteLocation(String value0);

  /// No description provided for @editorKeepThisLocationSectionUnchangedAndReadOnly.
  ///
  /// In en, this message translates to:
  /// **'Keep this location section unchanged and read-only.'**
  String get editorKeepThisLocationSectionUnchangedAndReadOnly;

  /// No description provided for @editorSectionDoesNotContainItsCompleteByteStringCount.
  ///
  /// In en, this message translates to:
  /// **'Section \"{value0}\" does not contain its complete {value1}-byte string count.'**
  String editorSectionDoesNotContainItsCompleteByteStringCount(
    String value0,
    String value1,
  );

  /// No description provided for @editorKeepThisStringTableUnchangedAndReadOnly.
  ///
  /// In en, this message translates to:
  /// **'Keep this string table unchanged and read-only.'**
  String get editorKeepThisStringTableUnchangedAndReadOnly;

  /// No description provided for @editorSectionDeclaresStringsButItsOffsetTableExceedsThe.
  ///
  /// In en, this message translates to:
  /// **'Section \"{value0}\" declares {value1} strings, but its offset table exceeds the payload.'**
  String editorSectionDeclaresStringsButItsOffsetTableExceedsThe(
    String value0,
    String value1,
  );

  /// No description provided for @editorStringInSectionPointsOutsideThePayload.
  ///
  /// In en, this message translates to:
  /// **'String {value0} in section \"{value1}\" points outside the payload.'**
  String editorStringInSectionPointsOutsideThePayload(
    String value0,
    String value1,
  );

  /// No description provided for @editorStringInSectionPointsIntoTheCountOrOffset.
  ///
  /// In en, this message translates to:
  /// **'String {value0} in section \"{value1}\" points into the count or offset table.'**
  String editorStringInSectionPointsIntoTheCountOrOffset(
    String value0,
    String value1,
  );

  /// No description provided for @editorStringInSectionHasNoNullTerminatorBeforeThe.
  ///
  /// In en, this message translates to:
  /// **'String {value0} in section \"{value1}\" has no null terminator before the payload ends.'**
  String editorStringInSectionHasNoNullTerminatorBeforeThe(
    String value0,
    String value1,
  );

  /// No description provided for @editorSectionEndsWithAnIncomplete2ByteTileRecord.
  ///
  /// In en, this message translates to:
  /// **'Section \"{value0}\" ends with an incomplete 2-byte tile record.'**
  String editorSectionEndsWithAnIncomplete2ByteTileRecord(String value0);

  /// No description provided for @editorKeepThisTerrainSectionUnchangedAndReadOnly.
  ///
  /// In en, this message translates to:
  /// **'Keep this terrain section unchanged and read-only.'**
  String get editorKeepThisTerrainSectionUnchangedAndReadOnly;

  /// No description provided for @editorSectionContainsTilesButXMapDimensionsRequire.
  ///
  /// In en, this message translates to:
  /// **'Section \"{value0}\" contains {value1} tiles, but {value2}x{value3} map dimensions require {value4}.'**
  String editorSectionContainsTilesButXMapDimensionsRequire(
    String value0,
    String value1,
    String value2,
    String value3,
    String value4,
  );

  /// No description provided for @editorRecoveryOpened.
  ///
  /// In en, this message translates to:
  /// **'Recovery opened'**
  String get editorRecoveryOpened;

  /// No description provided for @editorOnlyScmAndScxMapFilesCanBeOpened.
  ///
  /// In en, this message translates to:
  /// **'Only .scm and .scx map files can be opened.'**
  String get editorOnlyScmAndScxMapFilesCanBeOpened;

  /// No description provided for @editorChooseAStarCraftMapWithAScmOrScx.
  ///
  /// In en, this message translates to:
  /// **'Choose a StarCraft map with a .scm or .scx extension.'**
  String get editorChooseAStarCraftMapWithAScmOrScx;

  /// No description provided for @editorAnotherEditorOperationIsAlreadyRunning.
  ///
  /// In en, this message translates to:
  /// **'Another editor operation is already running.'**
  String get editorAnotherEditorOperationIsAlreadyRunning;

  /// No description provided for @editorWaitForTheCurrentOperationToFinishAndTry.
  ///
  /// In en, this message translates to:
  /// **'Wait for the current operation to finish and try again.'**
  String get editorWaitForTheCurrentOperationToFinishAndTry;

  /// No description provided for @editorReadingMapArchive.
  ///
  /// In en, this message translates to:
  /// **'Reading map archive'**
  String get editorReadingMapArchive;

  /// No description provided for @editorFingerprintingSourceMap.
  ///
  /// In en, this message translates to:
  /// **'Fingerprinting source map'**
  String get editorFingerprintingSourceMap;

  /// No description provided for @editorParsingScenarioChk.
  ///
  /// In en, this message translates to:
  /// **'Parsing scenario.chk'**
  String get editorParsingScenarioChk;

  /// No description provided for @editorValidatingMapMetadata.
  ///
  /// In en, this message translates to:
  /// **'Validating map metadata'**
  String get editorValidatingMapMetadata;

  /// No description provided for @editorTheSourceMapChangedWhileItWasBeingOpened.
  ///
  /// In en, this message translates to:
  /// **'The source map changed while it was being opened.'**
  String get editorTheSourceMapChangedWhileItWasBeingOpened;

  /// No description provided for @editorCloseTheOtherProgramThatIsEditingTheMap.
  ///
  /// In en, this message translates to:
  /// **'Close the other program that is editing the map and open it again.'**
  String get editorCloseTheOtherProgramThatIsEditingTheMap;

  /// No description provided for @editorTheMapOpenedButTheRecentMapsListWas.
  ///
  /// In en, this message translates to:
  /// **'The map opened, but the recent maps list was not updated.'**
  String get editorTheMapOpenedButTheRecentMapsListWas;

  /// No description provided for @editorCheckAccessToTheApplicationSettingsFolderAndReopen.
  ///
  /// In en, this message translates to:
  /// **'Check access to the application settings folder and reopen the map.'**
  String get editorCheckAccessToTheApplicationSettingsFolderAndReopen;

  /// No description provided for @editorMapOpenedInRestrictedReadOnlyMode.
  ///
  /// In en, this message translates to:
  /// **'Map opened in restricted read-only mode'**
  String get editorMapOpenedInRestrictedReadOnlyMode;

  /// No description provided for @editorMapOpened.
  ///
  /// In en, this message translates to:
  /// **'Map opened'**
  String get editorMapOpened;

  /// No description provided for @editorTheMapCouldNotBeOpenedBecauseOfAn.
  ///
  /// In en, this message translates to:
  /// **'The map could not be opened because of an unexpected error.'**
  String get editorTheMapCouldNotBeOpenedBecauseOfAn;

  /// No description provided for @editorRetryTheOperationIfItFailsAgainInspectThe.
  ///
  /// In en, this message translates to:
  /// **'Retry the operation. If it fails again, inspect the application log.'**
  String get editorRetryTheOperationIfItFailsAgainInspectThe;

  /// No description provided for @editorTheMapWasSavedButTheRecentMapsList.
  ///
  /// In en, this message translates to:
  /// **'The map was saved, but the recent maps list was not updated.'**
  String get editorTheMapWasSavedButTheRecentMapsList;

  /// No description provided for @editorCheckAccessToTheApplicationSettingsFolderAndReopen915aeaa0.
  ///
  /// In en, this message translates to:
  /// **'Check access to the application settings folder and reopen the saved map.'**
  String get editorCheckAccessToTheApplicationSettingsFolderAndReopen915aeaa0;

  /// No description provided for @editorTheMapFileDialogCouldNotBeOpened.
  ///
  /// In en, this message translates to:
  /// **'The map file dialog could not be opened.'**
  String get editorTheMapFileDialogCouldNotBeOpened;

  /// No description provided for @editorRetryTheOperationOrRestartTheApplication.
  ///
  /// In en, this message translates to:
  /// **'Retry the operation or restart the application.'**
  String get editorRetryTheOperationOrRestartTheApplication;

  /// No description provided for @editorTheSourceMapFingerprintCouldNotBeVerified.
  ///
  /// In en, this message translates to:
  /// **'The source map fingerprint could not be verified.'**
  String get editorTheSourceMapFingerprintCouldNotBeVerified;

  /// No description provided for @editorCheckThatTheMapStillExistsIsReadableAnd.
  ///
  /// In en, this message translates to:
  /// **'Check that the map still exists, is readable, and is not being changed by another program.'**
  String get editorCheckThatTheMapStillExistsIsReadableAnd;

  /// No description provided for @editorOpenAMapBeforeUsingSaveAs.
  ///
  /// In en, this message translates to:
  /// **'Open a map before using Save As.'**
  String get editorOpenAMapBeforeUsingSaveAs;

  /// No description provided for @editorOpenAScmOrScxMapAndTryAgain.
  ///
  /// In en, this message translates to:
  /// **'Open a .scm or .scx map and try again.'**
  String get editorOpenAScmOrScxMapAndTryAgain;

  /// No description provided for @editorEditedContainInvalidFieldValuesOrReferences.
  ///
  /// In en, this message translates to:
  /// **'Edited {value0} contain invalid field values or references.'**
  String editorEditedContainInvalidFieldValuesOrReferences(String value0);

  /// No description provided for @editorOpenValidateReferencesAndCorrectTheReportedSlots.
  ///
  /// In en, this message translates to:
  /// **'Open {value0} → Validate references and correct the reported slots.'**
  String editorOpenValidateReferencesAndCorrectTheReportedSlots(String value0);

  /// No description provided for @editorBriefing.
  ///
  /// In en, this message translates to:
  /// **'Briefing'**
  String get editorBriefing;

  /// No description provided for @editorTriggers.
  ///
  /// In en, this message translates to:
  /// **'Triggers'**
  String get editorTriggers;

  /// No description provided for @editorTheSaveAsDestinationMustBeAnAbsoluteWindows.
  ///
  /// In en, this message translates to:
  /// **'The Save As destination must be an absolute Windows path.'**
  String get editorTheSaveAsDestinationMustBeAnAbsoluteWindows;

  /// No description provided for @editorChooseTheDestinationUsingTheSaveAsDialog.
  ///
  /// In en, this message translates to:
  /// **'Choose the destination using the Save As dialog.'**
  String get editorChooseTheDestinationUsingTheSaveAsDialog;

  /// No description provided for @editorNewBroodWarMapsMustBeSavedAsScx.
  ///
  /// In en, this message translates to:
  /// **'New Brood War maps must be saved as .scx.'**
  String get editorNewBroodWarMapsMustBeSavedAsScx;

  /// No description provided for @editorSaveAsSupportsOnlyScmAndScxMapFiles.
  ///
  /// In en, this message translates to:
  /// **'Save As supports only .scm and .scx map files.'**
  String get editorSaveAsSupportsOnlyScmAndScxMapFiles;

  /// No description provided for @editorChooseADestinationEndingInScx.
  ///
  /// In en, this message translates to:
  /// **'Choose a destination ending in .scx.'**
  String get editorChooseADestinationEndingInScx;

  /// No description provided for @editorChooseADestinationEndingInScmOrScx.
  ///
  /// In en, this message translates to:
  /// **'Choose a destination ending in .scm or .scx.'**
  String get editorChooseADestinationEndingInScmOrScx;

  /// No description provided for @editorSaveAsCannotOverwriteTheCurrentlyOpenSourceMap.
  ///
  /// In en, this message translates to:
  /// **'Save As cannot overwrite the currently open source map.'**
  String get editorSaveAsCannotOverwriteTheCurrentlyOpenSourceMap;

  /// No description provided for @editorChooseADifferentOutputFileName.
  ///
  /// In en, this message translates to:
  /// **'Choose a different output file name.'**
  String get editorChooseADifferentOutputFileName;

  /// No description provided for @editorTheSaveAsDestinationAlreadyExists.
  ///
  /// In en, this message translates to:
  /// **'The Save As destination already exists.'**
  String get editorTheSaveAsDestinationAlreadyExists;

  /// No description provided for @editorChooseANewFileNameOrExplicitlyConfirmReplacement.
  ///
  /// In en, this message translates to:
  /// **'Choose a new file name or explicitly confirm replacement in the Save As dialog.'**
  String get editorChooseANewFileNameOrExplicitlyConfirmReplacement;

  /// No description provided for @editorPreparingNewMap.
  ///
  /// In en, this message translates to:
  /// **'Preparing new map'**
  String get editorPreparingNewMap;

  /// No description provided for @editorCheckingSourceMap.
  ///
  /// In en, this message translates to:
  /// **'Checking source map'**
  String get editorCheckingSourceMap;

  /// No description provided for @editorValidatingNewMap.
  ///
  /// In en, this message translates to:
  /// **'Validating new map'**
  String get editorValidatingNewMap;

  /// No description provided for @editorCheckingSourceMapFingerprint.
  ///
  /// In en, this message translates to:
  /// **'Checking source map fingerprint'**
  String get editorCheckingSourceMapFingerprint;

  /// No description provided for @editorTheSourceMapChangedAfterItWasOpenedSo.
  ///
  /// In en, this message translates to:
  /// **'The source map changed after it was opened, so Save As was stopped.'**
  String get editorTheSourceMapChangedAfterItWasOpenedSo;

  /// No description provided for @editorReopenTheSourceMapToReviewTheExternalChanges.
  ///
  /// In en, this message translates to:
  /// **'Reopen the source map to review the external changes before saving.'**
  String get editorReopenTheSourceMapToReviewTheExternalChanges;

  /// No description provided for @editorCheckingExistingDestinationFingerprint.
  ///
  /// In en, this message translates to:
  /// **'Checking existing destination fingerprint'**
  String get editorCheckingExistingDestinationFingerprint;

  /// No description provided for @editorATemporarySaveAsWorkspaceCouldNotBeCreated.
  ///
  /// In en, this message translates to:
  /// **'A temporary Save As workspace could not be created.'**
  String get editorATemporarySaveAsWorkspaceCouldNotBeCreated;

  /// No description provided for @editorCheckDestinationFolderPermissionsAndFreeDiskSpace.
  ///
  /// In en, this message translates to:
  /// **'Check destination folder permissions and free disk space.'**
  String get editorCheckDestinationFolderPermissionsAndFreeDiskSpace;

  /// No description provided for @editorWritingTemporaryMapArchive.
  ///
  /// In en, this message translates to:
  /// **'Writing temporary map archive'**
  String get editorWritingTemporaryMapArchive;

  /// No description provided for @editorReopeningAndVerifyingTemporaryMap.
  ///
  /// In en, this message translates to:
  /// **'Reopening and verifying temporary map'**
  String get editorReopeningAndVerifyingTemporaryMap;

  /// No description provided for @editorTheReopenedTemporaryMapDoesNotContainTheExpected.
  ///
  /// In en, this message translates to:
  /// **'The reopened temporary map does not contain the expected scenario.chk bytes.'**
  String get editorTheReopenedTemporaryMapDoesNotContainTheExpected;

  /// No description provided for @editorKeepTheSourceMapUnchangedAndReportTheArchive.
  ///
  /// In en, this message translates to:
  /// **'Keep the source map unchanged and report the archive writer failure.'**
  String get editorKeepTheSourceMapUnchangedAndReportTheArchive;

  /// No description provided for @editorTheReopenedTemporaryMapFailedCHKValidation.
  ///
  /// In en, this message translates to:
  /// **'The reopened temporary map failed CHK validation.'**
  String get editorTheReopenedTemporaryMapFailedCHKValidation;

  /// No description provided for @editorKeepTheSourceMapUnchangedAndInspectParserDiagnostics.
  ///
  /// In en, this message translates to:
  /// **'Keep the source map unchanged and inspect parser diagnostics.'**
  String get editorKeepTheSourceMapUnchangedAndInspectParserDiagnostics;

  /// No description provided for @editorFingerprintingVerifiedOutput.
  ///
  /// In en, this message translates to:
  /// **'Fingerprinting verified output'**
  String get editorFingerprintingVerifiedOutput;

  /// No description provided for @editorTheVerifiedTemporaryMapFingerprintCouldNotBeCalculated.
  ///
  /// In en, this message translates to:
  /// **'The verified temporary map fingerprint could not be calculated.'**
  String get editorTheVerifiedTemporaryMapFingerprintCouldNotBeCalculated;

  /// No description provided for @editorRecheckingSourceMapFingerprint.
  ///
  /// In en, this message translates to:
  /// **'Rechecking source map fingerprint'**
  String get editorRecheckingSourceMapFingerprint;

  /// No description provided for @editorTheSourceMapChangedDuringSaveAsSoThe.
  ///
  /// In en, this message translates to:
  /// **'The source map changed during Save As, so the verified output was not promoted.'**
  String get editorTheSourceMapChangedDuringSaveAsSoThe;

  /// No description provided for @editorReopenTheSourceMapToReviewTheExternalChangesf53fd806.
  ///
  /// In en, this message translates to:
  /// **'Reopen the source map to review the external changes and retry with a new output name.'**
  String get editorReopenTheSourceMapToReviewTheExternalChangesf53fd806;

  /// No description provided for @editorRecheckingSaveAsDestination.
  ///
  /// In en, this message translates to:
  /// **'Rechecking Save As destination'**
  String get editorRecheckingSaveAsDestination;

  /// No description provided for @editorPromotingVerifiedMapToFinalDestination.
  ///
  /// In en, this message translates to:
  /// **'Promoting verified map to final destination'**
  String get editorPromotingVerifiedMapToFinalDestination;

  /// No description provided for @editorTheExistingDestinationIsSafeInABackupBut.
  ///
  /// In en, this message translates to:
  /// **'The existing destination is safe in a backup, but automatic restoration failed.'**
  String get editorTheExistingDestinationIsSafeInABackupBut;

  /// No description provided for @editorRestoreTheBackupToBeforeRetryingSaveAs.
  ///
  /// In en, this message translates to:
  /// **'Restore the backup to {value0} before retrying Save As.'**
  String editorRestoreTheBackupToBeforeRetryingSaveAs(String value0);

  /// No description provided for @editorTheVerifiedMapCouldNotBePromotedToIts.
  ///
  /// In en, this message translates to:
  /// **'The verified map could not be promoted to its destination.'**
  String get editorTheVerifiedMapCouldNotBePromotedToIts;

  /// No description provided for @editorCheckDestinationFolderPermissionsAndChooseANewName.
  ///
  /// In en, this message translates to:
  /// **'Check destination folder permissions and choose a new name.'**
  String get editorCheckDestinationFolderPermissionsAndChooseANewName;

  /// No description provided for @editorThePreviousDestinationWasPreservedAsARecoveryBackup.
  ///
  /// In en, this message translates to:
  /// **'The previous destination was preserved as a recovery backup.'**
  String get editorThePreviousDestinationWasPreservedAsARecoveryBackup;

  /// No description provided for @editorKeepTheBackupUntilTheReplacementMapHasBeen.
  ///
  /// In en, this message translates to:
  /// **'Keep the backup until the replacement map has been verified.'**
  String get editorKeepTheBackupUntilTheReplacementMapHasBeen;

  /// No description provided for @editorMapSavedAndVerified.
  ///
  /// In en, this message translates to:
  /// **'Map saved and verified'**
  String get editorMapSavedAndVerified;

  /// No description provided for @editorMapSavedVerifiedAndBackedUp.
  ///
  /// In en, this message translates to:
  /// **'Map saved, verified, and backed up'**
  String get editorMapSavedVerifiedAndBackedUp;

  /// No description provided for @editorSaveAsFailedBecauseOfAnUnexpectedError.
  ///
  /// In en, this message translates to:
  /// **'Save As failed because of an unexpected error.'**
  String get editorSaveAsFailedBecauseOfAnUnexpectedError;

  /// No description provided for @editorRetryWithANewOutputNameTheSourceMap.
  ///
  /// In en, this message translates to:
  /// **'Retry with a new output name. The source map was not modified.'**
  String get editorRetryWithANewOutputNameTheSourceMap;

  /// No description provided for @editorTheSaveAsDialogCouldNotBeOpened.
  ///
  /// In en, this message translates to:
  /// **'The Save As dialog could not be opened.'**
  String get editorTheSaveAsDialogCouldNotBeOpened;

  /// No description provided for @editorCheckThatTheSourceMapStillExistsIsReadable.
  ///
  /// In en, this message translates to:
  /// **'Check that the source map still exists, is readable, and is not being changed by another program.'**
  String get editorCheckThatTheSourceMapStillExistsIsReadable;

  /// No description provided for @editorTheExistingSaveAsDestinationCouldNotBeVerified.
  ///
  /// In en, this message translates to:
  /// **'The existing Save As destination could not be verified.'**
  String get editorTheExistingSaveAsDestinationCouldNotBeVerified;

  /// No description provided for @editorCheckThatTheDestinationIsAReadableRegularFile.
  ///
  /// In en, this message translates to:
  /// **'Check that the destination is a readable regular file and retry.'**
  String get editorCheckThatTheDestinationIsAReadableRegularFile;

  /// No description provided for @editorTheSaveAsDestinationChangedWhileTheMapWas.
  ///
  /// In en, this message translates to:
  /// **'The Save As destination changed while the map was being prepared.'**
  String get editorTheSaveAsDestinationChangedWhileTheMapWas;

  /// No description provided for @editorReviewTheDestinationInAnotherProgramThenRetryAnd.
  ///
  /// In en, this message translates to:
  /// **'Review the destination in another program, then retry and confirm replacement again.'**
  String get editorReviewTheDestinationInAnotherProgramThenRetryAnd;

  /// No description provided for @editorWaitingForEuddraftToStart.
  ///
  /// In en, this message translates to:
  /// **'Waiting for euddraft to start'**
  String get editorWaitingForEuddraftToStart;

  /// No description provided for @editorTheEuddraftEventStreamFailedUnexpectedly.
  ///
  /// In en, this message translates to:
  /// **'The euddraft event stream failed unexpectedly.'**
  String get editorTheEuddraftEventStreamFailedUnexpectedly;

  /// No description provided for @editorTheEuddraftBuildCouldNotBeStarted.
  ///
  /// In en, this message translates to:
  /// **'The euddraft build could not be started.'**
  String get editorTheEuddraftBuildCouldNotBeStarted;

  /// No description provided for @editorStoppingEuddraft.
  ///
  /// In en, this message translates to:
  /// **'Stopping euddraft'**
  String get editorStoppingEuddraft;

  /// No description provided for @editorTheEUDBuildCancellationRequestFailed.
  ///
  /// In en, this message translates to:
  /// **'The EUD build cancellation request failed.'**
  String get editorTheEUDBuildCancellationRequestFailed;

  /// No description provided for @editorEuddraftIsStillRunning.
  ///
  /// In en, this message translates to:
  /// **'euddraft is still running'**
  String get editorEuddraftIsStillRunning;

  /// No description provided for @editorEuddraftReturnedAnEventForADifferentBuild.
  ///
  /// In en, this message translates to:
  /// **'euddraft returned an event for a different build.'**
  String get editorEuddraftReturnedAnEventForADifferentBuild;

  /// No description provided for @editorEuddraftIsRunning.
  ///
  /// In en, this message translates to:
  /// **'euddraft {value0} is running'**
  String editorEuddraftIsRunning(String value0);

  /// No description provided for @editorValidatingAndPromotingTheGeneratedEUDMap.
  ///
  /// In en, this message translates to:
  /// **'Validating and promoting the generated EUD map'**
  String get editorValidatingAndPromotingTheGeneratedEUDMap;

  /// No description provided for @editorEUDBuildWasCancelled.
  ///
  /// In en, this message translates to:
  /// **'EUD build was cancelled'**
  String get editorEUDBuildWasCancelled;

  /// No description provided for @editorEUDBuildFailed.
  ///
  /// In en, this message translates to:
  /// **'EUD build failed'**
  String get editorEUDBuildFailed;

  /// No description provided for @editorEUDMapBuiltVerifiedAndPromoted.
  ///
  /// In en, this message translates to:
  /// **'EUD map built, verified, and promoted'**
  String get editorEUDMapBuiltVerifiedAndPromoted;

  /// No description provided for @editorTheEuddraftEventStreamEndedWithoutAResult.
  ///
  /// In en, this message translates to:
  /// **'The euddraft event stream ended without a result.'**
  String get editorTheEuddraftEventStreamEndedWithoutAResult;

  /// No description provided for @editorInspectTheBuildLogAndRetry.
  ///
  /// In en, this message translates to:
  /// **'Inspect the build log and retry.'**
  String get editorInspectTheBuildLogAndRetry;

  /// No description provided for @editorABuildWithThisIDIsAlreadyActive.
  ///
  /// In en, this message translates to:
  /// **'A build with this ID is already active.'**
  String get editorABuildWithThisIDIsAlreadyActive;

  /// No description provided for @editorWaitForTheActiveBuildToFinishAndRetry.
  ///
  /// In en, this message translates to:
  /// **'Wait for the active build to finish and retry.'**
  String get editorWaitForTheActiveBuildToFinishAndRetry;

  /// No description provided for @editorTheEUDBuildInputsAreNotSafeRegularFiles.
  ///
  /// In en, this message translates to:
  /// **'The EUD build inputs are not safe regular files.'**
  String get editorTheEUDBuildInputsAreNotSafeRegularFiles;

  /// No description provided for @editorCheckTheBaseMapSourceRootEntrySourceAnd.
  ///
  /// In en, this message translates to:
  /// **'Check the base map, source root, entry source, and output folder.'**
  String get editorCheckTheBaseMapSourceRootEntrySourceAnd;

  /// No description provided for @editorTheEUDOutputResolvesToTheBaseMap.
  ///
  /// In en, this message translates to:
  /// **'The EUD output resolves to the base map.'**
  String get editorTheEUDOutputResolvesToTheBaseMap;

  /// No description provided for @editorChooseASeparateOutputFile.
  ///
  /// In en, this message translates to:
  /// **'Choose a separate output file.'**
  String get editorChooseASeparateOutputFile;

  /// No description provided for @editorTheEUDBaseMapFingerprintCouldNotBeCalculated.
  ///
  /// In en, this message translates to:
  /// **'The EUD base map fingerprint could not be calculated.'**
  String get editorTheEUDBaseMapFingerprintCouldNotBeCalculated;

  /// No description provided for @editorTheBaseMapDoesNotMatchTheEUDProject.
  ///
  /// In en, this message translates to:
  /// **'The base map does not match the EUD project binding.'**
  String get editorTheBaseMapDoesNotMatchTheEUDProject;

  /// No description provided for @editorOpenAndVerifyTheBoundMapThenPrepareAgain.
  ///
  /// In en, this message translates to:
  /// **'Open and verify the bound map, then prepare again.'**
  String get editorOpenAndVerifyTheBoundMapThenPrepareAgain;

  /// No description provided for @editorTheEpScriptEntrySourceFingerprintCouldNotBeCalculated.
  ///
  /// In en, this message translates to:
  /// **'The epScript entry source fingerprint could not be calculated.'**
  String get editorTheEpScriptEntrySourceFingerprintCouldNotBeCalculated;

  /// No description provided for @editorTheEUDOutputAlreadyExists.
  ///
  /// In en, this message translates to:
  /// **'The EUD output already exists.'**
  String get editorTheEUDOutputAlreadyExists;

  /// No description provided for @editorChooseANewOutputOrExplicitlyConfirmReplacement.
  ///
  /// In en, this message translates to:
  /// **'Choose a new output or explicitly confirm replacement.'**
  String get editorChooseANewOutputOrExplicitlyConfirmReplacement;

  /// No description provided for @editorTheExistingEUDOutputFingerprintCouldNotBeCalculated.
  ///
  /// In en, this message translates to:
  /// **'The existing EUD output fingerprint could not be calculated.'**
  String get editorTheExistingEUDOutputFingerprintCouldNotBeCalculated;

  /// No description provided for @editorTheTemporaryEUDBuildWorkspaceCouldNotBeCreated.
  ///
  /// In en, this message translates to:
  /// **'The temporary EUD build workspace could not be created.'**
  String get editorTheTemporaryEUDBuildWorkspaceCouldNotBeCreated;

  /// No description provided for @editorCheckOutputFolderPermissionsAndAvailableDiskSpace.
  ///
  /// In en, this message translates to:
  /// **'Check output folder permissions and available disk space.'**
  String get editorCheckOutputFolderPermissionsAndAvailableDiskSpace;

  /// No description provided for @editorEuddraftExitedSuccessfullyButDidNotCreateAReadable.
  ///
  /// In en, this message translates to:
  /// **'euddraft exited successfully but did not create a readable temporary map.'**
  String get editorEuddraftExitedSuccessfullyButDidNotCreateAReadable;

  /// No description provided for @editorEuddraftExitedSuccessfullyButCreatedAnEmptyTemporaryMap.
  ///
  /// In en, this message translates to:
  /// **'euddraft exited successfully but created an empty temporary map.'**
  String get editorEuddraftExitedSuccessfullyButCreatedAnEmptyTemporaryMap;

  /// No description provided for @editorInspectTheEuddraftOutputAndEpScriptSource.
  ///
  /// In en, this message translates to:
  /// **'Inspect the euddraft output and epScript source.'**
  String get editorInspectTheEuddraftOutputAndEpScriptSource;

  /// No description provided for @editorTheTemporaryEUDOutputIsNotAReadableMap.
  ///
  /// In en, this message translates to:
  /// **'The temporary EUD output is not a readable map archive.'**
  String get editorTheTemporaryEUDOutputIsNotAReadableMap;

  /// No description provided for @editorInspectTheEuddraftLogAndKeepTheBaseMap.
  ///
  /// In en, this message translates to:
  /// **'Inspect the euddraft log and keep the base map unchanged.'**
  String get editorInspectTheEuddraftLogAndKeepTheBaseMap;

  /// No description provided for @editorTheTemporaryEUDOutputContainsAnInvalidCHK.
  ///
  /// In en, this message translates to:
  /// **'The temporary EUD output contains an invalid CHK.'**
  String get editorTheTemporaryEUDOutputContainsAnInvalidCHK;

  /// No description provided for @editorTheTemporaryEUDOutputFailedCHKMetadataValidation.
  ///
  /// In en, this message translates to:
  /// **'The temporary EUD output failed CHK metadata validation.'**
  String get editorTheTemporaryEUDOutputFailedCHKMetadataValidation;

  /// No description provided for @editorInspectTheMapValidationDiagnosticsAndEuddraftLog.
  ///
  /// In en, this message translates to:
  /// **'Inspect the map validation diagnostics and euddraft log.'**
  String get editorInspectTheMapValidationDiagnosticsAndEuddraftLog;

  /// No description provided for @editorTheTemporaryEUDOutputIsMissingRequiredVERDIM.
  ///
  /// In en, this message translates to:
  /// **'The temporary EUD output is missing required VER, DIM, or ERA map metadata.'**
  String get editorTheTemporaryEUDOutputIsMissingRequiredVERDIM;

  /// No description provided for @editorUseAnIntactStarCraftMapAsTheEUDBase.
  ///
  /// In en, this message translates to:
  /// **'Use an intact StarCraft map as the EUD base map.'**
  String get editorUseAnIntactStarCraftMapAsTheEUDBase;

  /// No description provided for @editorTheEUDBaseMapFingerprintCouldNotBeRechecked.
  ///
  /// In en, this message translates to:
  /// **'The EUD base map fingerprint could not be rechecked.'**
  String get editorTheEUDBaseMapFingerprintCouldNotBeRechecked;

  /// No description provided for @editorTheBaseMapChangedDuringTheEUDBuildSo.
  ///
  /// In en, this message translates to:
  /// **'The base map changed during the EUD build, so the output was not promoted.'**
  String get editorTheBaseMapChangedDuringTheEUDBuildSo;

  /// No description provided for @editorReviewTheBaseMapChangesAndRebuild.
  ///
  /// In en, this message translates to:
  /// **'Review the base map changes and rebuild.'**
  String get editorReviewTheBaseMapChangesAndRebuild;

  /// No description provided for @editorTheEpScriptEntryFingerprintCouldNotBeRechecked.
  ///
  /// In en, this message translates to:
  /// **'The epScript entry fingerprint could not be rechecked.'**
  String get editorTheEpScriptEntryFingerprintCouldNotBeRechecked;

  /// No description provided for @editorTheEpScriptEntryChangedDuringTheEUDBuildSo.
  ///
  /// In en, this message translates to:
  /// **'The epScript entry changed during the EUD build, so the output was not promoted.'**
  String get editorTheEpScriptEntryChangedDuringTheEUDBuildSo;

  /// No description provided for @editorSaveTheSourceChangesAndRebuild.
  ///
  /// In en, this message translates to:
  /// **'Save the source changes and rebuild.'**
  String get editorSaveTheSourceChangesAndRebuild;

  /// No description provided for @editorThePreviousEUDOutputIsSafeInABackup.
  ///
  /// In en, this message translates to:
  /// **'The previous EUD output is safe in a backup, but automatic restoration failed.'**
  String get editorThePreviousEUDOutputIsSafeInABackup;

  /// No description provided for @editorRestoreTheBackupToBeforeBuildingAgain.
  ///
  /// In en, this message translates to:
  /// **'Restore the backup to {value0} before building again.'**
  String editorRestoreTheBackupToBeforeBuildingAgain(String value0);

  /// No description provided for @editorTheVerifiedEUDMapCouldNotBePromotedTo.
  ///
  /// In en, this message translates to:
  /// **'The verified EUD map could not be promoted to its output.'**
  String get editorTheVerifiedEUDMapCouldNotBePromotedTo;

  /// No description provided for @editorCheckOutputFolderPermissionsAndChooseANewName.
  ///
  /// In en, this message translates to:
  /// **'Check output folder permissions and choose a new name.'**
  String get editorCheckOutputFolderPermissionsAndChooseANewName;

  /// No description provided for @editorThePreviousEUDOutputWasPreservedAsARecovery.
  ///
  /// In en, this message translates to:
  /// **'The previous EUD output was preserved as a recovery backup.'**
  String get editorThePreviousEUDOutputWasPreservedAsARecovery;

  /// No description provided for @editorKeepTheBackupUntilTheGeneratedMapHasBeen.
  ///
  /// In en, this message translates to:
  /// **'Keep the backup until the generated map has been tested.'**
  String get editorKeepTheBackupUntilTheGeneratedMapHasBeen;

  /// No description provided for @editorTheSafeEUDBuildPipelineFailedUnexpectedly.
  ///
  /// In en, this message translates to:
  /// **'The safe EUD build pipeline failed unexpectedly.'**
  String get editorTheSafeEUDBuildPipelineFailedUnexpectedly;

  /// No description provided for @editorTheTemporaryEUDBuildWorkspaceWasNotRemoved.
  ///
  /// In en, this message translates to:
  /// **'The temporary EUD build workspace was not removed.'**
  String get editorTheTemporaryEUDBuildWorkspaceWasNotRemoved;

  /// No description provided for @editorCloseProcessesUsingTheFolderThenRemoveItManually.
  ///
  /// In en, this message translates to:
  /// **'Close processes using the folder, then remove it manually.'**
  String get editorCloseProcessesUsingTheFolderThenRemoveItManually;

  /// No description provided for @editorMapSourceOrEUDProjectChangedPrepareTheBuild.
  ///
  /// In en, this message translates to:
  /// **'Map, source or EUD project changed. Prepare the build again.'**
  String get editorMapSourceOrEUDProjectChangedPrepareTheBuild;

  /// No description provided for @editorSaveAndVerifyTheCurrentInputsThenPrepareAgain.
  ///
  /// In en, this message translates to:
  /// **'Save and verify the current inputs, then prepare again.'**
  String get editorSaveAndVerifyTheCurrentInputsThenPrepareAgain;

  /// No description provided for @editorTheSelectedEuddraftInstallationCouldNotBeRechecked.
  ///
  /// In en, this message translates to:
  /// **'The selected euddraft installation could not be rechecked.'**
  String get editorTheSelectedEuddraftInstallationCouldNotBeRechecked;

  /// No description provided for @editorInspectTheToolAndPrepareANewBuild.
  ///
  /// In en, this message translates to:
  /// **'Inspect the tool and prepare a new build.'**
  String get editorInspectTheToolAndPrepareANewBuild;

  /// No description provided for @editorTheSelectedEuddraftInstallationChangedOrIsNotReady.
  ///
  /// In en, this message translates to:
  /// **'The selected euddraft installation changed or is not ready.'**
  String get editorTheSelectedEuddraftInstallationChangedOrIsNotReady;

  /// No description provided for @editorCheckThatTheFileIsReadableAndIsNot.
  ///
  /// In en, this message translates to:
  /// **'Check that the file is readable and is not changing.'**
  String get editorCheckThatTheFileIsReadableAndIsNot;

  /// No description provided for @editorTheExistingEUDOutputCouldNotBeRechecked.
  ///
  /// In en, this message translates to:
  /// **'The existing EUD output could not be rechecked.'**
  String get editorTheExistingEUDOutputCouldNotBeRechecked;

  /// No description provided for @editorTheEUDOutputChangedWhileTheMapWasBeing.
  ///
  /// In en, this message translates to:
  /// **'The EUD output changed while the map was being built, so the temporary output was not promoted.'**
  String get editorTheEUDOutputChangedWhileTheMapWasBeing;

  /// No description provided for @editorReviewTheOtherProgramUsingTheOutputAndRebuild.
  ///
  /// In en, this message translates to:
  /// **'Review the other program using the output and rebuild.'**
  String get editorReviewTheOtherProgramUsingTheOutputAndRebuild;

  /// No description provided for @editorTheObjectCatalogRequestFailedUnexpectedly.
  ///
  /// In en, this message translates to:
  /// **'The object catalog request failed unexpectedly.'**
  String get editorTheObjectCatalogRequestFailedUnexpectedly;

  /// No description provided for @editorRetryOrRepairTheApplicationInstallation.
  ///
  /// In en, this message translates to:
  /// **'Retry or repair the application installation.'**
  String get editorRetryOrRepairTheApplicationInstallation;

  /// No description provided for @editorTheObjectThumbnailRequestFailedUnexpectedly.
  ///
  /// In en, this message translates to:
  /// **'The object thumbnail request failed unexpectedly.'**
  String get editorTheObjectThumbnailRequestFailedUnexpectedly;

  /// No description provided for @editorTheObjectCatalogRequestIsNoLongerCurrent.
  ///
  /// In en, this message translates to:
  /// **'The object catalog request is no longer current.'**
  String get editorTheObjectCatalogRequestIsNoLongerCurrent;

  /// No description provided for @editorLoadTheCurrentlySelectedCatalog.
  ///
  /// In en, this message translates to:
  /// **'Load the currently selected catalog.'**
  String get editorLoadTheCurrentlySelectedCatalog;

  /// No description provided for @editorTheObjectCatalogAndThumbnailResultsDidNotMatch.
  ///
  /// In en, this message translates to:
  /// **'The object catalog and thumbnail results did not match.'**
  String get editorTheObjectCatalogAndThumbnailResultsDidNotMatch;

  /// No description provided for @editorRepairTheApplicationOrReportTheHelperError.
  ///
  /// In en, this message translates to:
  /// **'Repair the application or report the helper error.'**
  String get editorRepairTheApplicationOrReportTheHelperError;

  /// No description provided for @editorTheStarCraftObjectAtlasRequestFailedUnexpectedly.
  ///
  /// In en, this message translates to:
  /// **'The StarCraft object atlas request failed unexpectedly.'**
  String get editorTheStarCraftObjectAtlasRequestFailedUnexpectedly;

  /// No description provided for @editorTheStarCraftObjectAtlasResultDidNotMatchIts.
  ///
  /// In en, this message translates to:
  /// **'The StarCraft object atlas result did not match its batch.'**
  String get editorTheStarCraftObjectAtlasResultDidNotMatchIts;

  /// No description provided for @editorOpenAMapBeforeBrowsingThePlacementCatalog.
  ///
  /// In en, this message translates to:
  /// **'Open a map before browsing the placement catalog.'**
  String get editorOpenAMapBeforeBrowsingThePlacementCatalog;

  /// No description provided for @editorSetTheStarCraftRemasteredDataFolderInSettingsFirst.
  ///
  /// In en, this message translates to:
  /// **'Set the StarCraft: Remastered data folder in settings first.'**
  String get editorSetTheStarCraftRemasteredDataFolderInSettingsFirst;

  /// No description provided for @editorTheMapNeedsExactlyOneERASectionWithA.
  ///
  /// In en, this message translates to:
  /// **'The map needs exactly one ERA section with a known tileset.'**
  String get editorTheMapNeedsExactlyOneERASectionWithA;

  /// No description provided for @editorTheCatalogChangedOrReturnedOverlappingPagesSelectThe.
  ///
  /// In en, this message translates to:
  /// **'The catalog changed or returned overlapping pages. Select the catalog kind again to reload.'**
  String get editorTheCatalogChangedOrReturnedOverlappingPagesSelectThe;

  /// No description provided for @editorThePlacementCatalogIsUnavailableInThisBuild.
  ///
  /// In en, this message translates to:
  /// **'The placement catalog is unavailable in this build.'**
  String get editorThePlacementCatalogIsUnavailableInThisBuild;

  /// No description provided for @editorStarCraftDataAssetSettingsCouldNotBeLoaded.
  ///
  /// In en, this message translates to:
  /// **'StarCraft data asset settings could not be loaded.'**
  String get editorStarCraftDataAssetSettingsCouldNotBeLoaded;

  /// No description provided for @editorCheckAccessToTheApplicationSettingsFolderAndRetry.
  ///
  /// In en, this message translates to:
  /// **'Check access to the application settings folder and retry.'**
  String get editorCheckAccessToTheApplicationSettingsFolderAndRetry;

  /// No description provided for @editorTheStarCraftInstallationFolderPickerCouldNotBeOpened.
  ///
  /// In en, this message translates to:
  /// **'The StarCraft installation folder picker could not be opened.'**
  String get editorTheStarCraftInstallationFolderPickerCouldNotBeOpened;

  /// No description provided for @editorRetryOrCheckWindowsDialogPermissions.
  ///
  /// In en, this message translates to:
  /// **'Retry or check Windows dialog permissions.'**
  String get editorRetryOrCheckWindowsDialogPermissions;

  /// No description provided for @editorTheStarCraftInstallationPathCouldNotBeSaved.
  ///
  /// In en, this message translates to:
  /// **'The StarCraft installation path could not be saved.'**
  String get editorTheStarCraftInstallationPathCouldNotBeSaved;

  /// No description provided for @editorTheStarCraftInstallationPathCouldNotBeCleared.
  ///
  /// In en, this message translates to:
  /// **'The StarCraft installation path could not be cleared.'**
  String get editorTheStarCraftInstallationPathCouldNotBeCleared;

  /// No description provided for @editorTheStarCraftCASCStorageCouldNotBeInspected.
  ///
  /// In en, this message translates to:
  /// **'The StarCraft CASC storage could not be inspected.'**
  String get editorTheStarCraftCASCStorageCouldNotBeInspected;

  /// No description provided for @editorCheckDirectoryAccessAndRetry.
  ///
  /// In en, this message translates to:
  /// **'Check directory access and retry.'**
  String get editorCheckDirectoryAccessAndRetry;

  /// No description provided for @editorTheStarCraftInstallationIsNotConfigured.
  ///
  /// In en, this message translates to:
  /// **'The StarCraft installation is not configured.'**
  String get editorTheStarCraftInstallationIsNotConfigured;

  /// No description provided for @editorOpenSettingsAndChooseTheStarCraftInstallationDirectory.
  ///
  /// In en, this message translates to:
  /// **'Open Settings and choose the StarCraft installation directory.'**
  String get editorOpenSettingsAndChooseTheStarCraftInstallationDirectory;

  /// No description provided for @editorTheStarCraftTileAtlasRequestFailedUnexpectedly.
  ///
  /// In en, this message translates to:
  /// **'The StarCraft tile atlas request failed unexpectedly.'**
  String get editorTheStarCraftTileAtlasRequestFailedUnexpectedly;

  /// No description provided for @editorTheStarCraftTileAtlasResultDidNotMatchIts.
  ///
  /// In en, this message translates to:
  /// **'The StarCraft tile atlas result did not match its batch.'**
  String get editorTheStarCraftTileAtlasResultDidNotMatchIts;

  /// No description provided for @editorTheTileCatalogRequestFailedUnexpectedly.
  ///
  /// In en, this message translates to:
  /// **'The Tile catalog request failed unexpectedly.'**
  String get editorTheTileCatalogRequestFailedUnexpectedly;

  /// No description provided for @editorTheTileThumbnailRequestFailedUnexpectedly.
  ///
  /// In en, this message translates to:
  /// **'The Tile thumbnail request failed unexpectedly.'**
  String get editorTheTileThumbnailRequestFailedUnexpectedly;

  /// No description provided for @editorTheTileCatalogRequestIsNoLongerCurrent.
  ///
  /// In en, this message translates to:
  /// **'The Tile catalog request is no longer current.'**
  String get editorTheTileCatalogRequestIsNoLongerCurrent;

  /// No description provided for @editorTheTileCatalogAndThumbnailResultsDidNotMatch.
  ///
  /// In en, this message translates to:
  /// **'The Tile catalog and thumbnail results did not match.'**
  String get editorTheTileCatalogAndThumbnailResultsDidNotMatch;

  /// No description provided for @editorTheMapPathMustBeAnAbsoluteWindowsPath.
  ///
  /// In en, this message translates to:
  /// **'The map path must be an absolute Windows path.'**
  String get editorTheMapPathMustBeAnAbsoluteWindowsPath;

  /// No description provided for @editorChooseTheMapAgainUsingTheOpenMapDialog.
  ///
  /// In en, this message translates to:
  /// **'Choose the map again using the Open Map dialog.'**
  String get editorChooseTheMapAgainUsingTheOpenMapDialog;

  /// No description provided for @editorAnArchiveOperationWithTheSameIDIsAlready.
  ///
  /// In en, this message translates to:
  /// **'An archive operation with the same ID is already active.'**
  String get editorAnArchiveOperationWithTheSameIDIsAlready;

  /// No description provided for @editorWaitForTheActiveOperationOrCancelItFirst.
  ///
  /// In en, this message translates to:
  /// **'Wait for the active operation or cancel it first.'**
  String get editorWaitForTheActiveOperationOrCancelItFirst;

  /// No description provided for @editorTheBundledMapArchiveHelperIsMissing.
  ///
  /// In en, this message translates to:
  /// **'The bundled map archive helper is missing.'**
  String get editorTheBundledMapArchiveHelperIsMissing;

  /// No description provided for @editorRepairOrReinstallTheApplication.
  ///
  /// In en, this message translates to:
  /// **'Repair or reinstall the application.'**
  String get editorRepairOrReinstallTheApplication;

  /// No description provided for @editorATemporaryArchiveWorkspaceCouldNotBeCreated.
  ///
  /// In en, this message translates to:
  /// **'A temporary archive workspace could not be created.'**
  String get editorATemporaryArchiveWorkspaceCouldNotBeCreated;

  /// No description provided for @editorCheckFreeDiskSpaceAndTemporaryFolderPermissions.
  ///
  /// In en, this message translates to:
  /// **'Check free disk space and temporary folder permissions.'**
  String get editorCheckFreeDiskSpaceAndTemporaryFolderPermissions;

  /// No description provided for @editorTheMapArchiveHelperTimedOut.
  ///
  /// In en, this message translates to:
  /// **'The map archive helper timed out.'**
  String get editorTheMapArchiveHelperTimedOut;

  /// No description provided for @editorRetryTheOperationOrInspectTheMapForCorruption.
  ///
  /// In en, this message translates to:
  /// **'Retry the operation or inspect the map for corruption.'**
  String get editorRetryTheOperationOrInspectTheMapForCorruption;

  /// No description provided for @editorTheMapArchiveOperationWasCancelled.
  ///
  /// In en, this message translates to:
  /// **'The map archive operation was cancelled.'**
  String get editorTheMapArchiveOperationWasCancelled;

  /// No description provided for @editorOpenTheMapAgainWhenReady.
  ///
  /// In en, this message translates to:
  /// **'Open the map again when ready.'**
  String get editorOpenTheMapAgainWhenReady;

  /// No description provided for @editorTheMapArchiveHelperProducedTooMuchOutput.
  ///
  /// In en, this message translates to:
  /// **'The map archive helper produced too much output.'**
  String get editorTheMapArchiveHelperProducedTooMuchOutput;

  /// No description provided for @editorRepairTheApplicationOrReportTheHelperFailure.
  ///
  /// In en, this message translates to:
  /// **'Repair the application or report the helper failure.'**
  String get editorRepairTheApplicationOrReportTheHelperFailure;

  /// No description provided for @editorScenarioChkExceedsTheConfiguredExtractionSizeLimit.
  ///
  /// In en, this message translates to:
  /// **'scenario.chk exceeds the configured extraction size limit.'**
  String get editorScenarioChkExceedsTheConfiguredExtractionSizeLimit;

  /// No description provided for @editorRaiseTheReviewedSizeLimitOnlyForATrusted.
  ///
  /// In en, this message translates to:
  /// **'Raise the reviewed size limit only for a trusted map.'**
  String get editorRaiseTheReviewedSizeLimitOnlyForATrusted;

  /// No description provided for @editorTheExtractedScenarioChkCouldNotBeRead.
  ///
  /// In en, this message translates to:
  /// **'The extracted scenario.chk could not be read.'**
  String get editorTheExtractedScenarioChkCouldNotBeRead;

  /// No description provided for @editorRetryTheOperationAndCheckTemporaryDiskAccess.
  ///
  /// In en, this message translates to:
  /// **'Retry the operation and check temporary disk access.'**
  String get editorRetryTheOperationAndCheckTemporaryDiskAccess;

  /// No description provided for @editorTheExtractedScenarioChkDoesNotMatchHelperMetadata.
  ///
  /// In en, this message translates to:
  /// **'The extracted scenario.chk does not match helper metadata.'**
  String get editorTheExtractedScenarioChkDoesNotMatchHelperMetadata;

  /// No description provided for @editorTheMapArchiveHelperCouldNotBeStarted.
  ///
  /// In en, this message translates to:
  /// **'The map archive helper could not be started.'**
  String get editorTheMapArchiveHelperCouldNotBeStarted;

  /// No description provided for @editorTheMapArchiveHelperReturnedAnInvalidResponse.
  ///
  /// In en, this message translates to:
  /// **'The map archive helper returned an invalid response.'**
  String get editorTheMapArchiveHelperReturnedAnInvalidResponse;

  /// No description provided for @editorTheSourceMapPathMustBeAnAbsoluteWindows.
  ///
  /// In en, this message translates to:
  /// **'The source map path must be an absolute Windows path.'**
  String get editorTheSourceMapPathMustBeAnAbsoluteWindows;

  /// No description provided for @editorOpenTheSourceMapAgainUsingTheOpenMap.
  ///
  /// In en, this message translates to:
  /// **'Open the source map again using the Open Map dialog.'**
  String get editorOpenTheSourceMapAgainUsingTheOpenMap;

  /// No description provided for @editorTheTemporaryOutputPathMustBeAnAbsoluteWindows.
  ///
  /// In en, this message translates to:
  /// **'The temporary output path must be an absolute Windows path.'**
  String get editorTheTemporaryOutputPathMustBeAnAbsoluteWindows;

  /// No description provided for @editorCreateTheSaveAsWorkspaceAgain.
  ///
  /// In en, this message translates to:
  /// **'Create the Save As workspace again.'**
  String get editorCreateTheSaveAsWorkspaceAgain;

  /// No description provided for @editorTheSourceMapCannotBeUsedAsTemporaryOutput.
  ///
  /// In en, this message translates to:
  /// **'The source map cannot be used as temporary output.'**
  String get editorTheSourceMapCannotBeUsedAsTemporaryOutput;

  /// No description provided for @editorChooseADifferentSaveAsDestination.
  ///
  /// In en, this message translates to:
  /// **'Choose a different Save As destination.'**
  String get editorChooseADifferentSaveAsDestination;

  /// No description provided for @editorTheTemporaryArchiveOutputAlreadyExists.
  ///
  /// In en, this message translates to:
  /// **'The temporary archive output already exists.'**
  String get editorTheTemporaryArchiveOutputAlreadyExists;

  /// No description provided for @editorCreateAFreshSaveAsWorkspaceAndRetry.
  ///
  /// In en, this message translates to:
  /// **'Create a fresh Save As workspace and retry.'**
  String get editorCreateAFreshSaveAsWorkspaceAndRetry;

  /// No description provided for @editorTheTemporarySaveAsWorkspaceDoesNotExist.
  ///
  /// In en, this message translates to:
  /// **'The temporary Save As workspace does not exist.'**
  String get editorTheTemporarySaveAsWorkspaceDoesNotExist;

  /// No description provided for @editorTheTemporarySaveAsWorkspaceCouldNotBeInspected.
  ///
  /// In en, this message translates to:
  /// **'The temporary Save As workspace could not be inspected.'**
  String get editorTheTemporarySaveAsWorkspaceCouldNotBeInspected;

  /// No description provided for @editorCheckDestinationFolderPermissionsAndRetry.
  ///
  /// In en, this message translates to:
  /// **'Check destination folder permissions and retry.'**
  String get editorCheckDestinationFolderPermissionsAndRetry;

  /// No description provided for @editorTheTemporaryScenarioInputPathAlreadyExists.
  ///
  /// In en, this message translates to:
  /// **'The temporary scenario input path already exists.'**
  String get editorTheTemporaryScenarioInputPathAlreadyExists;

  /// No description provided for @editorTheTemporaryArchiveWriterTimedOut.
  ///
  /// In en, this message translates to:
  /// **'The temporary archive writer timed out.'**
  String get editorTheTemporaryArchiveWriterTimedOut;

  /// No description provided for @editorTheMapArchiveWriteWasCancelled.
  ///
  /// In en, this message translates to:
  /// **'The map archive write was cancelled.'**
  String get editorTheMapArchiveWriteWasCancelled;

  /// No description provided for @editorRunSaveAsAgainWhenReady.
  ///
  /// In en, this message translates to:
  /// **'Run Save As again when ready.'**
  String get editorRunSaveAsAgainWhenReady;

  /// No description provided for @editorTheHelperReportedAnUnexpectedScenarioChkSize.
  ///
  /// In en, this message translates to:
  /// **'The helper reported an unexpected scenario.chk size.'**
  String get editorTheHelperReportedAnUnexpectedScenarioChkSize;

  /// No description provided for @editorTheHelperDidNotCreateTheTemporaryMapArchive.
  ///
  /// In en, this message translates to:
  /// **'The helper did not create the temporary map archive.'**
  String get editorTheHelperDidNotCreateTheTemporaryMapArchive;

  /// No description provided for @editorRetrySaveAsOrRepairTheApplication.
  ///
  /// In en, this message translates to:
  /// **'Retry Save As or repair the application.'**
  String get editorRetrySaveAsOrRepairTheApplication;

  /// No description provided for @editorTheTemporaryMapArchiveCouldNotBeInspected.
  ///
  /// In en, this message translates to:
  /// **'The temporary map archive could not be inspected.'**
  String get editorTheTemporaryMapArchiveCouldNotBeInspected;

  /// No description provided for @editorTheTemporaryMapSizeDoesNotMatchHelperMetadata.
  ///
  /// In en, this message translates to:
  /// **'The temporary map size does not match helper metadata.'**
  String get editorTheTemporaryMapSizeDoesNotMatchHelperMetadata;

  /// No description provided for @editorTheTemporaryScenarioInputCouldNotBeWritten.
  ///
  /// In en, this message translates to:
  /// **'The temporary scenario input could not be written.'**
  String get editorTheTemporaryScenarioInputCouldNotBeWritten;

  /// No description provided for @editorTheArchiveEntryListingIsIncomplete.
  ///
  /// In en, this message translates to:
  /// **'The archive entry listing is incomplete.'**
  String get editorTheArchiveEntryListingIsIncomplete;

  /// No description provided for @editorEditingCanContinueButVerifyProtectedOrUnnamedEntries.
  ///
  /// In en, this message translates to:
  /// **'Editing can continue, but verify protected or unnamed entries before saving.'**
  String get editorEditingCanContinueButVerifyProtectedOrUnnamedEntries;

  /// No description provided for @editorSomeArchiveEntryNamesWereRecoveredSynthetically.
  ///
  /// In en, this message translates to:
  /// **'Some archive entry names were recovered synthetically.'**
  String get editorSomeArchiveEntryNamesWereRecoveredSynthetically;

  /// No description provided for @editorTreatSyntheticNamesAsDiagnosticLabelsNotOriginalPaths.
  ///
  /// In en, this message translates to:
  /// **'Treat synthetic names as diagnostic labels, not original paths.'**
  String get editorTreatSyntheticNamesAsDiagnosticLabelsNotOriginalPaths;

  /// No description provided for @editorTheArchiveContainsDuplicateEntryPaths.
  ///
  /// In en, this message translates to:
  /// **'The archive contains duplicate entry paths.'**
  String get editorTheArchiveContainsDuplicateEntryPaths;

  /// No description provided for @editorReviewLocaleVariantsAndDuplicateEntriesBeforeSaving.
  ///
  /// In en, this message translates to:
  /// **'Review locale variants and duplicate entries before saving.'**
  String get editorReviewLocaleVariantsAndDuplicateEntriesBeforeSaving;

  /// No description provided for @editorTheMapUsesAnUnexpectedMPQFormatVersion.
  ///
  /// In en, this message translates to:
  /// **'The map uses an unexpected MPQ format version.'**
  String get editorTheMapUsesAnUnexpectedMPQFormatVersion;

  /// No description provided for @editorUseSaveAsAndReOpenTheOutputBefore.
  ///
  /// In en, this message translates to:
  /// **'Use Save As and re-open the output before replacing any map.'**
  String get editorUseSaveAsAndReOpenTheOutputBefore;

  /// No description provided for @editorTheArchiveContainsEncryptedEntries.
  ///
  /// In en, this message translates to:
  /// **'The archive contains encrypted entries.'**
  String get editorTheArchiveContainsEncryptedEntries;

  /// No description provided for @editorEncryptedEntriesAreReportedWithoutAttemptingRecovery.
  ///
  /// In en, this message translates to:
  /// **'Encrypted entries are reported without attempting recovery.'**
  String get editorEncryptedEntriesAreReportedWithoutAttemptingRecovery;

  /// No description provided for @editorTheStarCraftInstallationPathMustBeAnAbsoluteWindows.
  ///
  /// In en, this message translates to:
  /// **'The StarCraft installation path must be an absolute Windows drive or UNC directory.'**
  String get editorTheStarCraftInstallationPathMustBeAnAbsoluteWindows;

  /// No description provided for @editorChooseTheStarCraftInstallationUsingTheSettingsDialog.
  ///
  /// In en, this message translates to:
  /// **'Choose the StarCraft installation using the Settings dialog.'**
  String get editorChooseTheStarCraftInstallationUsingTheSettingsDialog;

  /// No description provided for @editorTheBundledStarCraftCASCHelperIsMissing.
  ///
  /// In en, this message translates to:
  /// **'The bundled StarCraft CASC helper is missing.'**
  String get editorTheBundledStarCraftCASCHelperIsMissing;

  /// No description provided for @editorTheStarCraftCASCInspectionTimedOut.
  ///
  /// In en, this message translates to:
  /// **'The StarCraft CASC inspection timed out.'**
  String get editorTheStarCraftCASCInspectionTimedOut;

  /// No description provided for @editorRetryAfterRepairingTheStarCraftInstallationInBattleNet.
  ///
  /// In en, this message translates to:
  /// **'Retry after repairing the StarCraft installation in Battle.net.'**
  String get editorRetryAfterRepairingTheStarCraftInstallationInBattleNet;

  /// No description provided for @editorTheStarCraftCASCHelperProducedTooMuchOutput.
  ///
  /// In en, this message translates to:
  /// **'The StarCraft CASC helper produced too much output.'**
  String get editorTheStarCraftCASCHelperProducedTooMuchOutput;

  /// No description provided for @editorTheStarCraftCASCHelperCouldNotBeStarted.
  ///
  /// In en, this message translates to:
  /// **'The StarCraft CASC helper could not be started.'**
  String get editorTheStarCraftCASCHelperCouldNotBeStarted;

  /// No description provided for @editorTheStarCraftInstallationCouldNotBeInspected.
  ///
  /// In en, this message translates to:
  /// **'The StarCraft installation could not be inspected.'**
  String get editorTheStarCraftInstallationCouldNotBeInspected;

  /// No description provided for @editorCheckDirectoryPermissionsAndRetry.
  ///
  /// In en, this message translates to:
  /// **'Check directory permissions and retry.'**
  String get editorCheckDirectoryPermissionsAndRetry;

  /// No description provided for @editorRequiredStarCraftCASCTilesetMissing.
  ///
  /// In en, this message translates to:
  /// **'{value0} required StarCraft CASC tileset {value1} missing.'**
  String editorRequiredStarCraftCASCTilesetMissing(
    String value0,
    String value1,
  );

  /// No description provided for @editorAssetIs.
  ///
  /// In en, this message translates to:
  /// **'asset is'**
  String get editorAssetIs;

  /// No description provided for @editorAssetsAre.
  ///
  /// In en, this message translates to:
  /// **'assets are'**
  String get editorAssetsAre;

  /// No description provided for @editorRepairTheStarCraftInstallationInBattleNetAndRetry.
  ///
  /// In en, this message translates to:
  /// **'Repair the StarCraft installation in Battle.net and retry.'**
  String get editorRepairTheStarCraftInstallationInBattleNetAndRetry;

  /// No description provided for @editorRequiredStarCraftCASCTilesetUnreadable.
  ///
  /// In en, this message translates to:
  /// **'{value0} required StarCraft CASC tileset {value1} unreadable.'**
  String editorRequiredStarCraftCASCTilesetUnreadable(
    String value0,
    String value1,
  );

  /// No description provided for @editorTheStarCraftCASCHelperReturnedAnInvalidResponse.
  ///
  /// In en, this message translates to:
  /// **'The StarCraft CASC helper returned an invalid response.'**
  String get editorTheStarCraftCASCHelperReturnedAnInvalidResponse;

  /// No description provided for @editorTheStarCraftInstallationPathIsInvalid.
  ///
  /// In en, this message translates to:
  /// **'The StarCraft installation path is invalid.'**
  String get editorTheStarCraftInstallationPathIsInvalid;

  /// No description provided for @editorChooseTheStarCraftInstallationFolderAgain.
  ///
  /// In en, this message translates to:
  /// **'Choose the StarCraft installation folder again.'**
  String get editorChooseTheStarCraftInstallationFolderAgain;

  /// No description provided for @editorAnObjectRenderingOperationWithThisIDIsActive.
  ///
  /// In en, this message translates to:
  /// **'An object rendering operation with this ID is active.'**
  String get editorAnObjectRenderingOperationWithThisIDIsActive;

  /// No description provided for @editorWaitForTheCurrentMapRenderingOperationToFinish.
  ///
  /// In en, this message translates to:
  /// **'Wait for the current map rendering operation to finish.'**
  String get editorWaitForTheCurrentMapRenderingOperationToFinish;

  /// No description provided for @editorTheStarCraftObjectRenderingHelperTimedOut.
  ///
  /// In en, this message translates to:
  /// **'The StarCraft object rendering helper timed out.'**
  String get editorTheStarCraftObjectRenderingHelperTimedOut;

  /// No description provided for @editorRepairTheStarCraftInstallationAndRetry.
  ///
  /// In en, this message translates to:
  /// **'Repair the StarCraft installation and retry.'**
  String get editorRepairTheStarCraftInstallationAndRetry;

  /// No description provided for @editorTheStarCraftObjectHelperProducedTooMuchOutput.
  ///
  /// In en, this message translates to:
  /// **'The StarCraft object helper produced too much output.'**
  String get editorTheStarCraftObjectHelperProducedTooMuchOutput;

  /// No description provided for @editorTheStarCraftObjectHelperCouldNotBeStarted.
  ///
  /// In en, this message translates to:
  /// **'The StarCraft object helper could not be started.'**
  String get editorTheStarCraftObjectHelperCouldNotBeStarted;

  /// No description provided for @editorTheStarCraftObjectAtlasCouldNotBeReadSafely.
  ///
  /// In en, this message translates to:
  /// **'The StarCraft object atlas could not be read safely.'**
  String get editorTheStarCraftObjectAtlasCouldNotBeReadSafely;

  /// No description provided for @editorTheStarCraftObjectHelperReturnedAnInvalidResponse.
  ///
  /// In en, this message translates to:
  /// **'The StarCraft object helper returned an invalid response.'**
  String get editorTheStarCraftObjectHelperReturnedAnInvalidResponse;

  /// No description provided for @editorTheStarCraftObjectRenderingOperationWasCancelled.
  ///
  /// In en, this message translates to:
  /// **'The StarCraft object rendering operation was cancelled.'**
  String get editorTheStarCraftObjectRenderingOperationWasCancelled;

  /// No description provided for @editorRetryAfterTheVisibleMapStateBecomesStable.
  ///
  /// In en, this message translates to:
  /// **'Retry after the visible map state becomes stable.'**
  String get editorRetryAfterTheVisibleMapStateBecomesStable;

  /// No description provided for @editorThisHelperVersionDoesNotSupportThatCatalogKind.
  ///
  /// In en, this message translates to:
  /// **'This helper version does not support that catalog kind.'**
  String get editorThisHelperVersionDoesNotSupportThatCatalogKind;

  /// No description provided for @editorChooseTheTileDoodadUnitOrPureSpriteCatalog.
  ///
  /// In en, this message translates to:
  /// **'Choose the Tile, Doodad, Unit, or pure Sprite catalog.'**
  String get editorChooseTheTileDoodadUnitOrPureSpriteCatalog;

  /// No description provided for @editorACatalogOperationWithThisIDIsAlreadyActive.
  ///
  /// In en, this message translates to:
  /// **'A catalog operation with this ID is already active.'**
  String get editorACatalogOperationWithThisIDIsAlreadyActive;

  /// No description provided for @editorWaitForTheActiveCatalogOperationToFinish.
  ///
  /// In en, this message translates to:
  /// **'Wait for the active catalog operation to finish.'**
  String get editorWaitForTheActiveCatalogOperationToFinish;

  /// No description provided for @editorTheStarCraftCatalogHelperTimedOut.
  ///
  /// In en, this message translates to:
  /// **'The StarCraft catalog helper timed out.'**
  String get editorTheStarCraftCatalogHelperTimedOut;

  /// No description provided for @editorTheStarCraftCatalogHelperProducedTooMuchOutput.
  ///
  /// In en, this message translates to:
  /// **'The StarCraft catalog helper produced too much output.'**
  String get editorTheStarCraftCatalogHelperProducedTooMuchOutput;

  /// No description provided for @editorTheStarCraftCatalogHelperCouldNotBeStarted.
  ///
  /// In en, this message translates to:
  /// **'The StarCraft catalog helper could not be started.'**
  String get editorTheStarCraftCatalogHelperCouldNotBeStarted;

  /// No description provided for @editorTheStarCraftCatalogCouldNotBeListedSafely.
  ///
  /// In en, this message translates to:
  /// **'The StarCraft catalog could not be listed safely.'**
  String get editorTheStarCraftCatalogCouldNotBeListedSafely;

  /// No description provided for @editorTheLocalDoodadRecipeIsInvalid.
  ///
  /// In en, this message translates to:
  /// **'The local Doodad recipe is invalid.'**
  String get editorTheLocalDoodadRecipeIsInvalid;

  /// No description provided for @editorTheLocalObjectPreviewIsUnavailable.
  ///
  /// In en, this message translates to:
  /// **'The local object preview is unavailable.'**
  String get editorTheLocalObjectPreviewIsUnavailable;

  /// No description provided for @editorVerifiedUnitCapabilityDataIsUnavailable.
  ///
  /// In en, this message translates to:
  /// **'Verified unit capability data is unavailable.'**
  String get editorVerifiedUnitCapabilityDataIsUnavailable;

  /// No description provided for @editorThisUnitNeedsAnAddonOrNydusRelation.
  ///
  /// In en, this message translates to:
  /// **'This unit needs an addon or Nydus relation.'**
  String get editorThisUnitNeedsAnAddonOrNydusRelation;

  /// No description provided for @editorTheStarCraftCatalogHelperReturnedAnInvalidResponse.
  ///
  /// In en, this message translates to:
  /// **'The StarCraft catalog helper returned an invalid response.'**
  String get editorTheStarCraftCatalogHelperReturnedAnInvalidResponse;

  /// No description provided for @editorRepairTheApplicationOrReportTheCatalogHelperError.
  ///
  /// In en, this message translates to:
  /// **'Repair the application or report the catalog helper error.'**
  String get editorRepairTheApplicationOrReportTheCatalogHelperError;

  /// No description provided for @editorTheStarCraftCatalogOperationWasCancelled.
  ///
  /// In en, this message translates to:
  /// **'The StarCraft catalog operation was cancelled.'**
  String get editorTheStarCraftCatalogOperationWasCancelled;

  /// No description provided for @editorRetryTheCatalogOperationWhenReady.
  ///
  /// In en, this message translates to:
  /// **'Retry the catalog operation when ready.'**
  String get editorRetryTheCatalogOperationWhenReady;

  /// No description provided for @editorTheStarCraftTileRenderingHelperTimedOut.
  ///
  /// In en, this message translates to:
  /// **'The StarCraft tile rendering helper timed out.'**
  String get editorTheStarCraftTileRenderingHelperTimedOut;

  /// No description provided for @editorTheStarCraftTileHelperProducedTooMuchOutput.
  ///
  /// In en, this message translates to:
  /// **'The StarCraft tile helper produced too much output.'**
  String get editorTheStarCraftTileHelperProducedTooMuchOutput;

  /// No description provided for @editorTheStarCraftTileHelperCouldNotBeStarted.
  ///
  /// In en, this message translates to:
  /// **'The StarCraft tile helper could not be started.'**
  String get editorTheStarCraftTileHelperCouldNotBeStarted;

  /// No description provided for @editorTheStarCraftTileAtlasCouldNotBeReadSafely.
  ///
  /// In en, this message translates to:
  /// **'The StarCraft tile atlas could not be read safely.'**
  String get editorTheStarCraftTileAtlasCouldNotBeReadSafely;

  /// No description provided for @editorTheStarCraftTileHelperReturnedAnInvalidResponse.
  ///
  /// In en, this message translates to:
  /// **'The StarCraft tile helper returned an invalid response.'**
  String get editorTheStarCraftTileHelperReturnedAnInvalidResponse;

  /// No description provided for @editorOpenTheReportedEpScriptModuleAndFixThisLine.
  ///
  /// In en, this message translates to:
  /// **'Open the reported epScript module and fix this line.'**
  String get editorOpenTheReportedEpScriptModuleAndFixThisLine;

  /// No description provided for @editorEuddraftInspectionIsSupportedOnlyOnWindows.
  ///
  /// In en, this message translates to:
  /// **'euddraft inspection is supported only on Windows.'**
  String get editorEuddraftInspectionIsSupportedOnlyOnWindows;

  /// No description provided for @editorRunTheEditorOnWindows10OrWindows11.
  ///
  /// In en, this message translates to:
  /// **'Run the editor on Windows 10 or Windows 11.'**
  String get editorRunTheEditorOnWindows10OrWindows11;

  /// No description provided for @editorAnEuddraftInstallationPathHasNotBeenConfigured.
  ///
  /// In en, this message translates to:
  /// **'An euddraft installation path has not been configured.'**
  String get editorAnEuddraftInstallationPathHasNotBeenConfigured;

  /// No description provided for @editorSelectTheExtractedEuddraftDirectoryOrEuddraftExe.
  ///
  /// In en, this message translates to:
  /// **'Select the extracted euddraft directory or euddraft.exe.'**
  String get editorSelectTheExtractedEuddraftDirectoryOrEuddraftExe;

  /// No description provided for @editorTheEuddraftInstallationCouldNotBeInspected.
  ///
  /// In en, this message translates to:
  /// **'The euddraft installation could not be inspected.'**
  String get editorTheEuddraftInstallationCouldNotBeInspected;

  /// No description provided for @editorCheckPathPermissionsAndRetry.
  ///
  /// In en, this message translates to:
  /// **'Check path permissions and retry.'**
  String get editorCheckPathPermissionsAndRetry;

  /// No description provided for @editorTheEuddraftPathMustBeAnAbsoluteWindowsPath.
  ///
  /// In en, this message translates to:
  /// **'The euddraft path must be an absolute Windows path.'**
  String get editorTheEuddraftPathMustBeAnAbsoluteWindowsPath;

  /// No description provided for @editorSelectThePathUsingTheEditorSettings.
  ///
  /// In en, this message translates to:
  /// **'Select the path using the editor settings.'**
  String get editorSelectThePathUsingTheEditorSettings;

  /// No description provided for @editorTheConfiguredFileIsNotEuddraftExe.
  ///
  /// In en, this message translates to:
  /// **'The configured file is not euddraft.exe.'**
  String get editorTheConfiguredFileIsNotEuddraftExe;

  /// No description provided for @editorSelectTheOfficialEuddraftExeOrItsInstallationFolder.
  ///
  /// In en, this message translates to:
  /// **'Select the official euddraft.exe or its installation folder.'**
  String get editorSelectTheOfficialEuddraftExeOrItsInstallationFolder;

  /// No description provided for @editorTheConfiguredEuddraftPathDoesNotExist.
  ///
  /// In en, this message translates to:
  /// **'The configured euddraft path does not exist.'**
  String get editorTheConfiguredEuddraftPathDoesNotExist;

  /// No description provided for @editorExtractTheOfficialEuddraftReleaseAndRetry.
  ///
  /// In en, this message translates to:
  /// **'Extract the official euddraft release and retry.'**
  String get editorExtractTheOfficialEuddraftReleaseAndRetry;

  /// No description provided for @editorTheConfiguredEuddraftPathIsNotARegularFile.
  ///
  /// In en, this message translates to:
  /// **'The configured euddraft path is not a regular file or folder.'**
  String get editorTheConfiguredEuddraftPathIsNotARegularFile;

  /// No description provided for @editorSelectALocalExtractedEuddraftInstallation.
  ///
  /// In en, this message translates to:
  /// **'Select a local extracted euddraft installation.'**
  String get editorSelectALocalExtractedEuddraftInstallation;

  /// No description provided for @editorTheInstallationDoesNotContainAUsableEuddraftExe.
  ///
  /// In en, this message translates to:
  /// **'The installation does not contain a usable euddraft.exe.'**
  String get editorTheInstallationDoesNotContainAUsableEuddraftExe;

  /// No description provided for @editorReExtractTheOfficialEuddraftRelease.
  ///
  /// In en, this message translates to:
  /// **'Re-extract the official euddraft release.'**
  String get editorReExtractTheOfficialEuddraftRelease;

  /// No description provided for @editorTheEuddraftVERSIONFileIsMissing.
  ///
  /// In en, this message translates to:
  /// **'The euddraft VERSION file is missing.'**
  String get editorTheEuddraftVERSIONFileIsMissing;

  /// No description provided for @editorUseACompleteOfficialEuddraftReleaseArchive.
  ///
  /// In en, this message translates to:
  /// **'Use a complete official euddraft release archive.'**
  String get editorUseACompleteOfficialEuddraftReleaseArchive;

  /// No description provided for @editorTheEuddraftVERSIONFileHasAnInvalidSize.
  ///
  /// In en, this message translates to:
  /// **'The euddraft VERSION file has an invalid size.'**
  String get editorTheEuddraftVERSIONFileHasAnInvalidSize;

  /// No description provided for @editorTheEuddraftVERSIONValueIsNotRecognized.
  ///
  /// In en, this message translates to:
  /// **'The euddraft VERSION value is not recognized.'**
  String get editorTheEuddraftVERSIONValueIsNotRecognized;

  /// No description provided for @editorUseAnOfficialFourComponentEuddraftRelease.
  ///
  /// In en, this message translates to:
  /// **'Use an official four-component euddraft release.'**
  String get editorUseAnOfficialFourComponentEuddraftRelease;

  /// No description provided for @editorEuddraftIsNotSupportedByThisEditor.
  ///
  /// In en, this message translates to:
  /// **'euddraft {value0} is not supported by this editor.'**
  String editorEuddraftIsNotSupportedByThisEditor(String value0);

  /// No description provided for @editorInstallASupportedRelease.
  ///
  /// In en, this message translates to:
  /// **'Install a supported release: {value0}.'**
  String editorInstallASupportedRelease(String value0);

  /// No description provided for @editorTheEuddraftInstallationIsIncomplete.
  ///
  /// In en, this message translates to:
  /// **'The euddraft installation is incomplete.'**
  String get editorTheEuddraftInstallationIsIncomplete;

  /// No description provided for @editorReExtractTheCompleteOfficialEuddraftRelease.
  ///
  /// In en, this message translates to:
  /// **'Re-extract the complete official euddraft release.'**
  String get editorReExtractTheCompleteOfficialEuddraftRelease;

  /// No description provided for @editorTheAppHasNoTrustedInventoryForThisBundled.
  ///
  /// In en, this message translates to:
  /// **'The app has no trusted inventory for this bundled tool.'**
  String get editorTheAppHasNoTrustedInventoryForThisBundled;

  /// No description provided for @editorUseAVerifiedAppPackageOrExplicitlySelectAn.
  ///
  /// In en, this message translates to:
  /// **'Use a verified app package or explicitly select an external installation.'**
  String get editorUseAVerifiedAppPackageOrExplicitlySelectAn;

  /// No description provided for @editorBundledToolIntegrityVerificationFailed.
  ///
  /// In en, this message translates to:
  /// **'Bundled tool integrity verification failed.'**
  String get editorBundledToolIntegrityVerificationFailed;

  /// No description provided for @editorRepairTheBundledInstallationOrExplicitlySelectAnExternal.
  ///
  /// In en, this message translates to:
  /// **'Repair the bundled installation or explicitly select an external tool.'**
  String get editorRepairTheBundledInstallationOrExplicitlySelectAnExternal;

  /// No description provided for @editorAnEUDBuildWithTheSameIDIsAlready.
  ///
  /// In en, this message translates to:
  /// **'An EUD build with the same ID is already active.'**
  String get editorAnEUDBuildWithTheSameIDIsAlready;

  /// No description provided for @editorWaitForTheActiveBuildOrCancelItFirst.
  ///
  /// In en, this message translates to:
  /// **'Wait for the active build or cancel it first.'**
  String get editorWaitForTheActiveBuildOrCancelItFirst;

  /// No description provided for @editorEuddraftCouldNotBeStarted.
  ///
  /// In en, this message translates to:
  /// **'euddraft could not be started.'**
  String get editorEuddraftCouldNotBeStarted;

  /// No description provided for @editorReinspectTheEuddraftInstallationAndRetry.
  ///
  /// In en, this message translates to:
  /// **'Reinspect the euddraft installation and retry.'**
  String get editorReinspectTheEuddraftInstallationAndRetry;

  /// No description provided for @editorTheEuddraftBuildTimedOut.
  ///
  /// In en, this message translates to:
  /// **'The euddraft build timed out.'**
  String get editorTheEuddraftBuildTimedOut;

  /// No description provided for @editorInspectTheBuildLogThenRetryOrCancel.
  ///
  /// In en, this message translates to:
  /// **'Inspect the build log, then retry or cancel.'**
  String get editorInspectTheBuildLogThenRetryOrCancel;

  /// No description provided for @editorEuddraftProducedMoreOutputThanTheSafetyLimit.
  ///
  /// In en, this message translates to:
  /// **'euddraft produced more output than the safety limit.'**
  String get editorEuddraftProducedMoreOutputThanTheSafetyLimit;

  /// No description provided for @editorInspectTheSourceForRunawayLoggingBeforeRetrying.
  ///
  /// In en, this message translates to:
  /// **'Inspect the source for runaway logging before retrying.'**
  String get editorInspectTheSourceForRunawayLoggingBeforeRetrying;

  /// No description provided for @editorEuddraftExitedWithAFailureCode.
  ///
  /// In en, this message translates to:
  /// **'euddraft exited with a failure code.'**
  String get editorEuddraftExitedWithAFailureCode;

  /// No description provided for @editorReviewStdoutAndStderrForTheCompilerError.
  ///
  /// In en, this message translates to:
  /// **'Review stdout and stderr for the compiler error.'**
  String get editorReviewStdoutAndStderrForTheCompilerError;

  /// No description provided for @editorTheEUDBuildCouldNotAccessARequiredFile.
  ///
  /// In en, this message translates to:
  /// **'The EUD build could not access a required file.'**
  String get editorTheEUDBuildCouldNotAccessARequiredFile;

  /// No description provided for @editorCheckFilePermissionsAndRetry.
  ///
  /// In en, this message translates to:
  /// **'Check file permissions and retry.'**
  String get editorCheckFilePermissionsAndRetry;

  /// No description provided for @editorTheEUDBuildFailedUnexpectedly.
  ///
  /// In en, this message translates to:
  /// **'The EUD build failed unexpectedly.'**
  String get editorTheEUDBuildFailedUnexpectedly;

  /// No description provided for @editorRetryTheBuildOrReportTheFailure.
  ///
  /// In en, this message translates to:
  /// **'Retry the build or report the failure.'**
  String get editorRetryTheBuildOrReportTheFailure;

  /// No description provided for @editorEuddraftBuildsAreSupportedOnlyOnWindows.
  ///
  /// In en, this message translates to:
  /// **'euddraft builds are supported only on Windows.'**
  String get editorEuddraftBuildsAreSupportedOnlyOnWindows;

  /// No description provided for @editorTheEuddraftExecutablePathMustBeAbsolute.
  ///
  /// In en, this message translates to:
  /// **'The euddraft executable path must be absolute.'**
  String get editorTheEuddraftExecutablePathMustBeAbsolute;

  /// No description provided for @editorInspectAndSelectTheEuddraftInstallationAgain.
  ///
  /// In en, this message translates to:
  /// **'Inspect and select the euddraft installation again.'**
  String get editorInspectAndSelectTheEuddraftInstallationAgain;

  /// No description provided for @editorTheInspectedEuddraftExecutableIsNoLongerAvailable.
  ///
  /// In en, this message translates to:
  /// **'The inspected euddraft executable is no longer available.'**
  String get editorTheInspectedEuddraftExecutableIsNoLongerAvailable;

  /// No description provided for @editorInspectTheEuddraftInstallationAgain.
  ///
  /// In en, this message translates to:
  /// **'Inspect the euddraft installation again.'**
  String get editorInspectTheEuddraftInstallationAgain;

  /// No description provided for @editorTheEuddraftSettingsPathMustBeAnAbsoluteEds.
  ///
  /// In en, this message translates to:
  /// **'The euddraft settings path must be an absolute .eds path.'**
  String get editorTheEuddraftSettingsPathMustBeAnAbsoluteEds;

  /// No description provided for @editorChooseAGeneratedOneShotEdsSettingsFile.
  ///
  /// In en, this message translates to:
  /// **'Choose a generated one-shot .eds settings file.'**
  String get editorChooseAGeneratedOneShotEdsSettingsFile;

  /// No description provided for @editorTheEuddraftSettingsFileIsMissingOrEmpty.
  ///
  /// In en, this message translates to:
  /// **'The euddraft settings file is missing or empty.'**
  String get editorTheEuddraftSettingsFileIsMissingOrEmpty;

  /// No description provided for @editorGenerateTheBuildSettingsAgainAndRetry.
  ///
  /// In en, this message translates to:
  /// **'Generate the build settings again and retry.'**
  String get editorGenerateTheBuildSettingsAgainAndRetry;

  /// No description provided for @editorTheEUDBuildWasCancelled.
  ///
  /// In en, this message translates to:
  /// **'The EUD build was cancelled.'**
  String get editorTheEUDBuildWasCancelled;

  /// No description provided for @editorStartTheBuildAgainWhenReady.
  ///
  /// In en, this message translates to:
  /// **'Start the build again when ready.'**
  String get editorStartTheBuildAgainWhenReady;

  /// No description provided for @editorInactive.
  ///
  /// In en, this message translates to:
  /// **'Inactive'**
  String get editorInactive;

  /// No description provided for @editorRescuePassive.
  ///
  /// In en, this message translates to:
  /// **'Rescue passive'**
  String get editorRescuePassive;

  /// No description provided for @editorComputer.
  ///
  /// In en, this message translates to:
  /// **'Computer'**
  String get editorComputer;

  /// No description provided for @editorHuman.
  ///
  /// In en, this message translates to:
  /// **'Human'**
  String get editorHuman;

  /// No description provided for @editorNeutral.
  ///
  /// In en, this message translates to:
  /// **'Neutral'**
  String get editorNeutral;

  /// No description provided for @editorZerg.
  ///
  /// In en, this message translates to:
  /// **'Zerg'**
  String get editorZerg;

  /// No description provided for @editorTerran.
  ///
  /// In en, this message translates to:
  /// **'Terran'**
  String get editorTerran;

  /// No description provided for @editorProtoss.
  ///
  /// In en, this message translates to:
  /// **'Protoss'**
  String get editorProtoss;

  /// No description provided for @editorIndependent.
  ///
  /// In en, this message translates to:
  /// **'Independent'**
  String get editorIndependent;

  /// No description provided for @editorUserSelectable.
  ///
  /// In en, this message translates to:
  /// **'User selectable'**
  String get editorUserSelectable;

  /// No description provided for @editorRandom.
  ///
  /// In en, this message translates to:
  /// **'Random'**
  String get editorRandom;

  /// No description provided for @editorRed.
  ///
  /// In en, this message translates to:
  /// **'Red'**
  String get editorRed;

  /// No description provided for @editorBlue.
  ///
  /// In en, this message translates to:
  /// **'Blue'**
  String get editorBlue;

  /// No description provided for @editorTeal.
  ///
  /// In en, this message translates to:
  /// **'Teal'**
  String get editorTeal;

  /// No description provided for @editorPurple.
  ///
  /// In en, this message translates to:
  /// **'Purple'**
  String get editorPurple;

  /// No description provided for @editorOrange.
  ///
  /// In en, this message translates to:
  /// **'Orange'**
  String get editorOrange;

  /// No description provided for @editorBrown.
  ///
  /// In en, this message translates to:
  /// **'Brown'**
  String get editorBrown;

  /// No description provided for @editorWhite.
  ///
  /// In en, this message translates to:
  /// **'White'**
  String get editorWhite;

  /// No description provided for @editorYellow.
  ///
  /// In en, this message translates to:
  /// **'Yellow'**
  String get editorYellow;

  /// No description provided for @editorGreen.
  ///
  /// In en, this message translates to:
  /// **'Green'**
  String get editorGreen;

  /// No description provided for @editorPaleYellow.
  ///
  /// In en, this message translates to:
  /// **'Pale yellow'**
  String get editorPaleYellow;

  /// No description provided for @editorTan.
  ///
  /// In en, this message translates to:
  /// **'Tan'**
  String get editorTan;

  /// No description provided for @editorAzure.
  ///
  /// In en, this message translates to:
  /// **'Azure'**
  String get editorAzure;

  /// No description provided for @editorExpectedOneSectionFound.
  ///
  /// In en, this message translates to:
  /// **'{value0}: expected one section; found {value1}.'**
  String editorExpectedOneSectionFound(String value0, String value1);

  /// No description provided for @editorExpectedBytesFound.
  ///
  /// In en, this message translates to:
  /// **'{value0}: expected {value1} bytes; found {value2}.'**
  String editorExpectedBytesFound(String value0, String value1, String value2);

  /// No description provided for @editorASingleKnownVERSectionIsRequired.
  ///
  /// In en, this message translates to:
  /// **'A single known VER section is required.'**
  String get editorASingleKnownVERSectionIsRequired;

  /// No description provided for @editorCRGBColorSettingsArePresentCOLREditingIsUnavailable.
  ///
  /// In en, this message translates to:
  /// **'CRGB color settings are present. COLR editing is unavailable until their interaction is supported.'**
  String get editorCRGBColorSettingsArePresentCOLREditingIsUnavailable;

  /// No description provided for @editorAPlayerFieldMayBeUpdatedOnlyOnce.
  ///
  /// In en, this message translates to:
  /// **'A player field may be updated only once.'**
  String get editorAPlayerFieldMayBeUpdatedOnlyOnce;

  /// No description provided for @editorUnsupportedID.
  ///
  /// In en, this message translates to:
  /// **'Unsupported {value0} ID: {value1}.'**
  String editorUnsupportedID(String value0, String value1);

  /// No description provided for @editorStartLocationsCannotBeCheckedAUNITSectionIs.
  ///
  /// In en, this message translates to:
  /// **'Start locations cannot be checked: a UNIT section is malformed.'**
  String get editorStartLocationsCannotBeCheckedAUNITSectionIs;

  /// No description provided for @editorStartLocationHasNonPlayableOwnerID.
  ///
  /// In en, this message translates to:
  /// **'Start location has non-playable owner ID {value0}.'**
  String editorStartLocationHasNonPlayableOwnerID(String value0);

  /// No description provided for @editorPlayerHasStartLocations.
  ///
  /// In en, this message translates to:
  /// **'Player {value0} has {value1} start locations.'**
  String editorPlayerHasStartLocations(String value0, String value1);

  /// No description provided for @editorPlayerHasNoStartLocationCheckTheIntendedUMS.
  ///
  /// In en, this message translates to:
  /// **'Player {value0} has no start location; check the intended UMS setup.'**
  String editorPlayerHasNoStartLocationCheckTheIntendedUMS(String value0);

  /// No description provided for @editorInactivePlayerOwnsAStartLocation.
  ///
  /// In en, this message translates to:
  /// **'Inactive player {value0} owns a start location.'**
  String editorInactivePlayerOwnsAStartLocation(String value0);

  /// No description provided for @editorForceNamesRequireOneSafeSTROrSTRxTable.
  ///
  /// In en, this message translates to:
  /// **'Force names require one safe STR or STRx table.'**
  String get editorForceNamesRequireOneSafeSTROrSTRxTable;

  /// No description provided for @editorForceSettingsRequireOneKnownVERAndOne20.
  ///
  /// In en, this message translates to:
  /// **'Force settings require one known VER and one 20-byte FORC section.'**
  String get editorForceSettingsRequireOneKnownVERAndOne20;

  /// No description provided for @editorInvalidForceNameStringID.
  ///
  /// In en, this message translates to:
  /// **'Invalid force name string ID {value0}.'**
  String editorInvalidForceNameStringID(String value0);

  /// No description provided for @editorForceNamesCannotContainNUL.
  ///
  /// In en, this message translates to:
  /// **'Force names cannot contain NUL.'**
  String get editorForceNamesCannotContainNUL;

  /// No description provided for @editorFORCStringIDsCannotExceed65535.
  ///
  /// In en, this message translates to:
  /// **'FORC string IDs cannot exceed 65535.'**
  String get editorFORCStringIDsCannotExceed65535;

  /// No description provided for @editorUseDefaults.
  ///
  /// In en, this message translates to:
  /// **'Use defaults'**
  String get editorUseDefaults;

  /// No description provided for @editorHitPoints.
  ///
  /// In en, this message translates to:
  /// **'Hit points'**
  String get editorHitPoints;

  /// No description provided for @editorShields.
  ///
  /// In en, this message translates to:
  /// **'Shields'**
  String get editorShields;

  /// No description provided for @editorArmor.
  ///
  /// In en, this message translates to:
  /// **'Armor'**
  String get editorArmor;

  /// No description provided for @editorBuildTime160S.
  ///
  /// In en, this message translates to:
  /// **'Build time (1/60 s)'**
  String get editorBuildTime160S;

  /// No description provided for @editorMineralCost.
  ///
  /// In en, this message translates to:
  /// **'Mineral cost'**
  String get editorMineralCost;

  /// No description provided for @editorGasCost.
  ///
  /// In en, this message translates to:
  /// **'Gas cost'**
  String get editorGasCost;

  /// No description provided for @editorHitPointsRequireANonnegativeDecimalInStepsOf.
  ///
  /// In en, this message translates to:
  /// **'Hit points require a nonnegative decimal in steps of 1/256.'**
  String get editorHitPointsRequireANonnegativeDecimalInStepsOf;

  /// No description provided for @editorHitPointsMustBeAMultipleOf1256.
  ///
  /// In en, this message translates to:
  /// **'Hit points must be a multiple of 1/256.'**
  String get editorHitPointsMustBeAMultipleOf1256;

  /// No description provided for @editorRequiresANonnegativeInteger.
  ///
  /// In en, this message translates to:
  /// **'{value0} requires a nonnegative integer.'**
  String editorRequiresANonnegativeInteger(String value0);

  /// No description provided for @editorInvalidUnitNameStringID.
  ///
  /// In en, this message translates to:
  /// **'Invalid unit name string ID {value0}.'**
  String editorInvalidUnitNameStringID(String value0);

  /// No description provided for @editorUnitSettingsRequireOneKnownVERSection.
  ///
  /// In en, this message translates to:
  /// **'Unit settings require one known VER section.'**
  String get editorUnitSettingsRequireOneKnownVERSection;

  /// No description provided for @editorUnitNamesRequireOneSafeSTROrSTRxTable.
  ///
  /// In en, this message translates to:
  /// **'Unit names require one safe STR or STRx table.'**
  String get editorUnitNamesRequireOneSafeSTROrSTRxTable;

  /// No description provided for @editorUnitNamesCannotContainNUL.
  ///
  /// In en, this message translates to:
  /// **'Unit names cannot contain NUL.'**
  String get editorUnitNamesCannotContainNUL;

  /// No description provided for @editorUnitNameIDsCannotExceed65535.
  ///
  /// In en, this message translates to:
  /// **'Unit name IDs cannot exceed 65535.'**
  String get editorUnitNameIDsCannotExceed65535;

  /// No description provided for @editorGlobalAvailabilityHasNoPlayer.
  ///
  /// In en, this message translates to:
  /// **'Global availability has no player.'**
  String get editorGlobalAvailabilityHasNoPlayer;

  /// No description provided for @editorAPlayerIsRequired.
  ///
  /// In en, this message translates to:
  /// **'A player is required.'**
  String get editorAPlayerIsRequired;

  /// No description provided for @editorUnitAvailabilityRequiresOneKnownVERSection.
  ///
  /// In en, this message translates to:
  /// **'Unit availability requires one known VER section.'**
  String get editorUnitAvailabilityRequiresOneKnownVERSection;

  /// No description provided for @editorPUNIExpectedOneSectionFound.
  ///
  /// In en, this message translates to:
  /// **'PUNI: expected one section; found {value0}.'**
  String editorPUNIExpectedOneSectionFound(String value0);

  /// No description provided for @editorPUNIExpected5700BytesFound.
  ///
  /// In en, this message translates to:
  /// **'PUNI: expected 5700 bytes; found {value0}.'**
  String editorPUNIExpected5700BytesFound(String value0);

  /// No description provided for @editorResearchTime160S.
  ///
  /// In en, this message translates to:
  /// **'Research time (1/60 s)'**
  String get editorResearchTime160S;

  /// No description provided for @editorEnergyCost.
  ///
  /// In en, this message translates to:
  /// **'Energy cost'**
  String get editorEnergyCost;

  /// No description provided for @editorCostsHaveNoPlayer.
  ///
  /// In en, this message translates to:
  /// **'Costs have no player.'**
  String get editorCostsHaveNoPlayer;

  /// No description provided for @editorInheritanceRequiresAPlayer.
  ///
  /// In en, this message translates to:
  /// **'Inheritance requires a player.'**
  String get editorInheritanceRequiresAPlayer;

  /// No description provided for @editorTechSettingsRequireOneKnownVERSection.
  ///
  /// In en, this message translates to:
  /// **'Tech settings require one known VER section.'**
  String get editorTechSettingsRequireOneKnownVERSection;

  /// No description provided for @editorBaseMineralCost.
  ///
  /// In en, this message translates to:
  /// **'Base mineral cost'**
  String get editorBaseMineralCost;

  /// No description provided for @editorMineralCostPerLevel.
  ///
  /// In en, this message translates to:
  /// **'Mineral cost per level'**
  String get editorMineralCostPerLevel;

  /// No description provided for @editorBaseGasCost.
  ///
  /// In en, this message translates to:
  /// **'Base gas cost'**
  String get editorBaseGasCost;

  /// No description provided for @editorGasCostPerLevel.
  ///
  /// In en, this message translates to:
  /// **'Gas cost per level'**
  String get editorGasCostPerLevel;

  /// No description provided for @editorBaseResearchTime160S.
  ///
  /// In en, this message translates to:
  /// **'Base research time (1/60 s)'**
  String get editorBaseResearchTime160S;

  /// No description provided for @editorResearchTimePerLevel160S.
  ///
  /// In en, this message translates to:
  /// **'Research time per level (1/60 s)'**
  String get editorResearchTimePerLevel160S;

  /// No description provided for @editorMaximumLevel.
  ///
  /// In en, this message translates to:
  /// **'Maximum level'**
  String get editorMaximumLevel;

  /// No description provided for @editorStartingLevel.
  ///
  /// In en, this message translates to:
  /// **'Starting level'**
  String get editorStartingLevel;

  /// No description provided for @editorUpgradeSettingsRequireOneKnownVERSection.
  ///
  /// In en, this message translates to:
  /// **'Upgrade settings require one known VER section.'**
  String get editorUpgradeSettingsRequireOneKnownVERSection;

  /// No description provided for @editorUpgradeStartingLevelMustNotExceedMaximumLevel.
  ///
  /// In en, this message translates to:
  /// **'Upgrade #{value0} {value1}: starting level must not exceed maximum level.'**
  String editorUpgradeStartingLevelMustNotExceedMaximumLevel(
    String value0,
    String value1,
  );

  /// No description provided for @editorEnterIDsSuchAs025.
  ///
  /// In en, this message translates to:
  /// **'Enter IDs such as 0, 2-5.'**
  String get editorEnterIDsSuchAs025;

  /// No description provided for @editorUseCommaSeparatedIDsOrAscendingRanges.
  ///
  /// In en, this message translates to:
  /// **'Use comma-separated IDs or ascending ranges.'**
  String get editorUseCommaSeparatedIDsOrAscendingRanges;

  /// No description provided for @editorIDsMustBeBetweenAndInAscendingRanges.
  ///
  /// In en, this message translates to:
  /// **'IDs must be between {value0} and {value1}, in ascending ranges.'**
  String editorIDsMustBeBetweenAndInAscendingRanges(
    String value0,
    String value1,
  );

  /// No description provided for @editorOneStructurallySafeSTRSTRxTableIsRequiredFor.
  ///
  /// In en, this message translates to:
  /// **'One structurally safe STR/STRx table is required for editing.'**
  String get editorOneStructurallySafeSTRSTRxTableIsRequiredFor;

  /// No description provided for @editorTruncated.
  ///
  /// In en, this message translates to:
  /// **'Truncated {value0}'**
  String editorTruncated(String value0);

  /// No description provided for @editorMalformedSPRP.
  ///
  /// In en, this message translates to:
  /// **'Malformed SPRP'**
  String get editorMalformedSPRP;

  /// No description provided for @editorMalformedFORC.
  ///
  /// In en, this message translates to:
  /// **'Malformed FORC'**
  String get editorMalformedFORC;

  /// No description provided for @editorForcef1368d9.
  ///
  /// In en, this message translates to:
  /// **'force {value0}'**
  String editorForcef1368d9(String value0);

  /// No description provided for @editorMalformedMRGN.
  ///
  /// In en, this message translates to:
  /// **'Malformed MRGN'**
  String get editorMalformedMRGN;

  /// No description provided for @editorLocation.
  ///
  /// In en, this message translates to:
  /// **'location {value0}'**
  String editorLocation(String value0);

  /// No description provided for @editorMalformedSWNM.
  ///
  /// In en, this message translates to:
  /// **'Malformed SWNM'**
  String get editorMalformedSWNM;

  /// No description provided for @editorSwitchffe3c882.
  ///
  /// In en, this message translates to:
  /// **'switch {value0}'**
  String editorSwitchffe3c882(String value0);

  /// No description provided for @editorMalformedWAV.
  ///
  /// In en, this message translates to:
  /// **'Malformed WAV'**
  String get editorMalformedWAV;

  /// No description provided for @editorSoundSlot.
  ///
  /// In en, this message translates to:
  /// **'sound slot {value0}'**
  String editorSoundSlot(String value0);

  /// No description provided for @editorMalformed.
  ///
  /// In en, this message translates to:
  /// **'Malformed {value0}'**
  String editorMalformed(String value0);

  /// No description provided for @editorUnitc6ee345c.
  ///
  /// In en, this message translates to:
  /// **'unit {value0}'**
  String editorUnitc6ee345c(String value0);

  /// No description provided for @editorRawConditionInTrigger.
  ///
  /// In en, this message translates to:
  /// **'Raw condition in trigger {value0}'**
  String editorRawConditionInTrigger(String value0);

  /// No description provided for @editorRawActionInTrigger.
  ///
  /// In en, this message translates to:
  /// **'Raw action in trigger {value0}'**
  String editorRawActionInTrigger(String value0);

  /// No description provided for @editorTriggerAction.
  ///
  /// In en, this message translates to:
  /// **'trigger {value0} action {value1} {value2}'**
  String editorTriggerAction(String value0, String value1, String value2);

  /// No description provided for @editorRawBriefingAction.
  ///
  /// In en, this message translates to:
  /// **'Raw briefing action'**
  String get editorRawBriefingAction;

  /// No description provided for @editorBriefingActionText.
  ///
  /// In en, this message translates to:
  /// **'briefing {value0} action {value1} text'**
  String editorBriefingActionText(String value0, String value1);

  /// No description provided for @editorBriefingActionSound.
  ///
  /// In en, this message translates to:
  /// **'briefing {value0} action {value1} sound'**
  String editorBriefingActionSound(String value0, String value1);

  /// No description provided for @editorUninterpretedSection.
  ///
  /// In en, this message translates to:
  /// **'Uninterpreted {value0} section'**
  String editorUninterpretedSection(String value0);

  /// No description provided for @editorDuplicateCHKSections.
  ///
  /// In en, this message translates to:
  /// **'Duplicate CHK sections'**
  String get editorDuplicateCHKSections;

  /// No description provided for @editorInvalidStringID.
  ///
  /// In en, this message translates to:
  /// **'Invalid string ID.'**
  String get editorInvalidStringID;

  /// No description provided for @editorSoundPathReferencesAreManagedThroughSoundImportDelete.
  ///
  /// In en, this message translates to:
  /// **'Sound path references are managed through sound import/delete. Separate a text reference to edit its text.'**
  String get editorSoundPathReferencesAreManagedThroughSoundImportDelete;

  /// No description provided for @editorReferencedOrIncompletelyTracedStringsCannotBeCleared.
  ///
  /// In en, this message translates to:
  /// **'Referenced or incompletely traced strings cannot be cleared.'**
  String get editorReferencedOrIncompletelyTracedStringsCannotBeCleared;

  /// No description provided for @editorNULIsNotAllowed.
  ///
  /// In en, this message translates to:
  /// **'NUL is not allowed.'**
  String get editorNULIsNotAllowed;

  /// No description provided for @editorTheSelectedReferenceChanged.
  ///
  /// In en, this message translates to:
  /// **'The selected reference changed.'**
  String get editorTheSelectedReferenceChanged;

  /// No description provided for @editorThisReferenceRequiresA16BitStringID.
  ///
  /// In en, this message translates to:
  /// **'This reference requires a 16-bit string ID.'**
  String get editorThisReferenceRequiresA16BitStringID;

  /// No description provided for @editorOneValidWAVTableIsRequired.
  ///
  /// In en, this message translates to:
  /// **'One valid WAV table is required.'**
  String get editorOneValidWAVTableIsRequired;

  /// No description provided for @editorAll512SoundSlotsAreOccupied.
  ///
  /// In en, this message translates to:
  /// **'All 512 sound slots are occupied.'**
  String get editorAll512SoundSlotsAreOccupied;

  /// No description provided for @editorSoundIsReferencedOrReferenceCoverageIsIncomplete.
  ///
  /// In en, this message translates to:
  /// **'Sound is referenced, or reference coverage is incomplete.'**
  String get editorSoundIsReferencedOrReferenceCoverageIsIncomplete;

  /// No description provided for @editorAmbiguousOrMalformedSection.
  ///
  /// In en, this message translates to:
  /// **'Ambiguous or malformed {value0} section.'**
  String editorAmbiguousOrMalformedSection(String value0);

  /// No description provided for @editorTextCannotContainNUL.
  ///
  /// In en, this message translates to:
  /// **'Text cannot contain NUL.'**
  String get editorTextCannotContainNUL;

  /// No description provided for @editorOneSafeStringTableIsRequired.
  ///
  /// In en, this message translates to:
  /// **'One safe string table is required.'**
  String get editorOneSafeStringTableIsRequired;

  /// No description provided for @editorSwitch8e2b60a2.
  ///
  /// In en, this message translates to:
  /// **'Switch {value0}'**
  String editorSwitch8e2b60a2(String value0);

  /// No description provided for @editorHitpoints.
  ///
  /// In en, this message translates to:
  /// **'Hitpoints %'**
  String get editorHitpoints;

  /// No description provided for @editorShields83e6a3a.
  ///
  /// In en, this message translates to:
  /// **'Shields %'**
  String get editorShields83e6a3a;

  /// No description provided for @editorEnergy.
  ///
  /// In en, this message translates to:
  /// **'Energy %'**
  String get editorEnergy;

  /// No description provided for @editorResourceAmount.
  ///
  /// In en, this message translates to:
  /// **'Resource amount'**
  String get editorResourceAmount;

  /// No description provided for @editorHangarCount.
  ///
  /// In en, this message translates to:
  /// **'Hangar count'**
  String get editorHangarCount;

  /// No description provided for @editorCloaked.
  ///
  /// In en, this message translates to:
  /// **'Cloaked'**
  String get editorCloaked;

  /// No description provided for @editorBurrowed.
  ///
  /// In en, this message translates to:
  /// **'Burrowed'**
  String get editorBurrowed;

  /// No description provided for @editorLifted.
  ///
  /// In en, this message translates to:
  /// **'Lifted'**
  String get editorLifted;

  /// No description provided for @editorHallucinated.
  ///
  /// In en, this message translates to:
  /// **'Hallucinated'**
  String get editorHallucinated;

  /// No description provided for @editorInvincible.
  ///
  /// In en, this message translates to:
  /// **'Invincible'**
  String get editorInvincible;

  /// No description provided for @editorInvalid8650455.
  ///
  /// In en, this message translates to:
  /// **'Invalid {value0}'**
  String editorInvalid8650455(String value0);

  /// No description provided for @editorFiveSpecialPropertyStatesRequired.
  ///
  /// In en, this message translates to:
  /// **'Five special property states required.'**
  String get editorFiveSpecialPropertyStatesRequired;

  /// No description provided for @editorOpenAMapFirst.
  ///
  /// In en, this message translates to:
  /// **'Open a map first.'**
  String get editorOpenAMapFirst;

  /// No description provided for @editorMapChangedDuringImport.
  ///
  /// In en, this message translates to:
  /// **'Map changed during import.'**
  String get editorMapChangedDuringImport;

  /// No description provided for @editorThisPathAlreadyHasASoundReferenceChooseA.
  ///
  /// In en, this message translates to:
  /// **'This path already has a sound reference. Choose a different file name.'**
  String get editorThisPathAlreadyHasASoundReferenceChooseA;

  /// No description provided for @editorASoundAlreadyUsesThisPathChooseADifferent.
  ///
  /// In en, this message translates to:
  /// **'A sound already uses this path. Choose a different file name.'**
  String get editorASoundAlreadyUsesThisPathChooseADifferent;

  /// No description provided for @editorIncompleteArchiveListingNameCollisionsCannotBeRuledOut.
  ///
  /// In en, this message translates to:
  /// **'Incomplete archive listing: name collisions cannot be ruled out.'**
  String get editorIncompleteArchiveListingNameCollisionsCannotBeRuledOut;

  /// No description provided for @editorAmbiguousArchiveEntryDeletionIsBlocked.
  ///
  /// In en, this message translates to:
  /// **'Ambiguous archive entry: deletion is blocked.'**
  String get editorAmbiguousArchiveEntryDeletionIsBlocked;

  /// No description provided for @editorSoundIsDeleted.
  ///
  /// In en, this message translates to:
  /// **'Sound is deleted.'**
  String get editorSoundIsDeleted;

  /// No description provided for @editorTheSoundIsNotStoredInThisNewMap.
  ///
  /// In en, this message translates to:
  /// **'The sound is not stored in this new map.'**
  String get editorTheSoundIsNotStoredInThisNewMap;

  /// No description provided for @editorSoundGatewayUnavailable.
  ///
  /// In en, this message translates to:
  /// **'Sound gateway unavailable.'**
  String get editorSoundGatewayUnavailable;

  /// No description provided for @editorSourceMapChangedOnDisk.
  ///
  /// In en, this message translates to:
  /// **'Source map changed on disk.'**
  String get editorSourceMapChangedOnDisk;

  /// No description provided for @editorMapChangedDuringSoundRead.
  ///
  /// In en, this message translates to:
  /// **'Map changed during sound read.'**
  String get editorMapChangedDuringSoundRead;

  /// No description provided for @editorTheSoundIsNotStoredInThisMap.
  ///
  /// In en, this message translates to:
  /// **'The sound is not stored in this map.'**
  String get editorTheSoundIsNotStoredInThisMap;

  /// No description provided for @editorOpenAnEditableMap.
  ///
  /// In en, this message translates to:
  /// **'Open an editable map.'**
  String get editorOpenAnEditableMap;

  /// No description provided for @editorMapChangedReopenTriggerResources.
  ///
  /// In en, this message translates to:
  /// **'Map changed. Reopen trigger resources.'**
  String get editorMapChangedReopenTriggerResources;

  /// No description provided for @editorPendingSoundEditsExceed64EntriesOr64MiB.
  ///
  /// In en, this message translates to:
  /// **'Pending sound edits exceed 64 entries or 64 MiB. Save first.'**
  String get editorPendingSoundEditsExceed64EntriesOr64MiB;

  /// No description provided for @editorResourceEditsCannotRemoveSections.
  ///
  /// In en, this message translates to:
  /// **'Resource edits cannot remove sections.'**
  String get editorResourceEditsCannotRemoveSections;

  /// No description provided for @editorUnsupportedAppendedResource.
  ///
  /// In en, this message translates to:
  /// **'Unsupported appended resource.'**
  String get editorUnsupportedAppendedResource;

  /// No description provided for @editorUnsupportedResourceChange.
  ///
  /// In en, this message translates to:
  /// **'Unsupported resource change.'**
  String get editorUnsupportedResourceChange;

  /// No description provided for @editorEditTriggerResources.
  ///
  /// In en, this message translates to:
  /// **'Edit trigger resources'**
  String get editorEditTriggerResources;

  /// No description provided for @editorMapChangedReopenTheTriggerEditor.
  ///
  /// In en, this message translates to:
  /// **'Map changed. Reopen the trigger editor.'**
  String get editorMapChangedReopenTheTriggerEditor;

  /// No description provided for @editorTRIGAndMBRFRecordsCannotBeMixed.
  ///
  /// In en, this message translates to:
  /// **'TRIG and MBRF records cannot be mixed.'**
  String get editorTRIGAndMBRFRecordsCannotBeMixed;

  /// No description provided for @editorCreateBriefing.
  ///
  /// In en, this message translates to:
  /// **'Create briefing'**
  String get editorCreateBriefing;

  /// No description provided for @editorEditBriefing.
  ///
  /// In en, this message translates to:
  /// **'Edit briefing'**
  String get editorEditBriefing;

  /// No description provided for @editorEditTriggers.
  ///
  /// In en, this message translates to:
  /// **'Edit triggers'**
  String get editorEditTriggers;

  /// No description provided for @editorOpenAnEditableMapBeforeChangingTechs.
  ///
  /// In en, this message translates to:
  /// **'Open an editable map before changing techs.'**
  String get editorOpenAnEditableMapBeforeChangingTechs;

  /// No description provided for @editorTheMapChangedReopenTechSettingsBeforeApplying.
  ///
  /// In en, this message translates to:
  /// **'The map changed. Reopen Tech Settings before applying.'**
  String get editorTheMapChangedReopenTechSettingsBeforeApplying;

  /// No description provided for @editorEditTechSettings.
  ///
  /// In en, this message translates to:
  /// **'Edit tech settings'**
  String get editorEditTechSettings;

  /// No description provided for @editorOpenAnEditableMapBeforeChangingUpgrades.
  ///
  /// In en, this message translates to:
  /// **'Open an editable map before changing upgrades.'**
  String get editorOpenAnEditableMapBeforeChangingUpgrades;

  /// No description provided for @editorTheMapChangedReopenUpgradeSettingsBeforeApplying.
  ///
  /// In en, this message translates to:
  /// **'The map changed. Reopen Upgrade Settings before applying.'**
  String get editorTheMapChangedReopenUpgradeSettingsBeforeApplying;

  /// No description provided for @editorEditUpgradeSettings.
  ///
  /// In en, this message translates to:
  /// **'Edit upgrade settings'**
  String get editorEditUpgradeSettings;

  /// No description provided for @editorOpenAnEditableMapBeforeChangingAvailability.
  ///
  /// In en, this message translates to:
  /// **'Open an editable map before changing availability.'**
  String get editorOpenAnEditableMapBeforeChangingAvailability;

  /// No description provided for @editorTheMapChangedReopenUnitAvailabilityBeforeApplying.
  ///
  /// In en, this message translates to:
  /// **'The map changed. Reopen Unit Availability before applying.'**
  String get editorTheMapChangedReopenUnitAvailabilityBeforeApplying;

  /// No description provided for @editorEditUnitAvailability.
  ///
  /// In en, this message translates to:
  /// **'Edit unit availability'**
  String get editorEditUnitAvailability;

  /// No description provided for @editorOpenAnEditableMapBeforeChangingUnitSettings.
  ///
  /// In en, this message translates to:
  /// **'Open an editable map before changing unit settings.'**
  String get editorOpenAnEditableMapBeforeChangingUnitSettings;

  /// No description provided for @editorTheMapChangedReopenUnitSettingsBeforeApplying.
  ///
  /// In en, this message translates to:
  /// **'The map changed. Reopen Unit Settings before applying.'**
  String get editorTheMapChangedReopenUnitSettingsBeforeApplying;

  /// No description provided for @editorEditUnitSettings.
  ///
  /// In en, this message translates to:
  /// **'Edit unit settings'**
  String get editorEditUnitSettings;

  /// No description provided for @editorOpenAnEditableMapBeforeChangingForceSettings.
  ///
  /// In en, this message translates to:
  /// **'Open an editable map before changing force settings.'**
  String get editorOpenAnEditableMapBeforeChangingForceSettings;

  /// No description provided for @editorTheMapChangedReopenForceSettingsBeforeApplying.
  ///
  /// In en, this message translates to:
  /// **'The map changed. Reopen Force Settings before applying.'**
  String get editorTheMapChangedReopenForceSettingsBeforeApplying;

  /// No description provided for @editorEditForceSettings.
  ///
  /// In en, this message translates to:
  /// **'Edit force settings'**
  String get editorEditForceSettings;

  /// No description provided for @editorOpenAnEditableMapBeforeChangingPlayerSettings.
  ///
  /// In en, this message translates to:
  /// **'Open an editable map before changing player settings.'**
  String get editorOpenAnEditableMapBeforeChangingPlayerSettings;

  /// No description provided for @editorTheMapChangedReopenPlayerSettingsBeforeApplying.
  ///
  /// In en, this message translates to:
  /// **'The map changed. Reopen Player Settings before applying.'**
  String get editorTheMapChangedReopenPlayerSettingsBeforeApplying;

  /// No description provided for @editorEditPlayerSettings.
  ///
  /// In en, this message translates to:
  /// **'Edit player settings'**
  String get editorEditPlayerSettings;

  /// No description provided for @editorOpenAnEditableMapBeforeChangingMapInformation.
  ///
  /// In en, this message translates to:
  /// **'Open an editable map before changing map information.'**
  String get editorOpenAnEditableMapBeforeChangingMapInformation;

  /// No description provided for @editorTheMapChangedReopenMapInformationBeforeApplying.
  ///
  /// In en, this message translates to:
  /// **'The map changed. Reopen Map Information before applying.'**
  String get editorTheMapChangedReopenMapInformationBeforeApplying;

  /// No description provided for @editorEditMapInformation.
  ///
  /// In en, this message translates to:
  /// **'Edit map information'**
  String get editorEditMapInformation;

  /// No description provided for @editorABuildOrPreparationIsAlreadyRunning.
  ///
  /// In en, this message translates to:
  /// **'A build or preparation is already running.'**
  String get editorABuildOrPreparationIsAlreadyRunning;

  /// No description provided for @editorConfirmThatYouTrustTheEpScriptSourceAndIts.
  ///
  /// In en, this message translates to:
  /// **'Confirm that you trust the epScript source and its imports.'**
  String get editorConfirmThatYouTrustTheEpScriptSourceAndIts;

  /// No description provided for @editorEnableTheUnverifiedSettingsTestBuildToCompileProject.
  ///
  /// In en, this message translates to:
  /// **'Enable the unverified settings test build to compile project settings.'**
  String get editorEnableTheUnverifiedSettingsTestBuildToCompileProject;

  /// No description provided for @editorVerifyTheSavedMapAndEUDProjectBindingBefore.
  ///
  /// In en, this message translates to:
  /// **'Verify the saved map and EUD project binding before building.'**
  String get editorVerifyTheSavedMapAndEUDProjectBindingBefore;

  /// No description provided for @editorTheBuildBaseMustBeTheMapBoundTo.
  ///
  /// In en, this message translates to:
  /// **'The build base must be the map bound to this EUD project.'**
  String get editorTheBuildBaseMustBeTheMapBoundTo;

  /// No description provided for @editorFinishOrRetryEUDToolsSettingsFirst.
  ///
  /// In en, this message translates to:
  /// **'Finish or retry EUD Tools settings first.'**
  String get editorFinishOrRetryEUDToolsSettingsFirst;

  /// No description provided for @editorChooseAnOutputSeparateFromTheBaseMap.
  ///
  /// In en, this message translates to:
  /// **'Choose an output separate from the base map.'**
  String get editorChooseAnOutputSeparateFromTheBaseMap;

  /// No description provided for @editorOutputAlreadyExistsChooseANewScxPath.
  ///
  /// In en, this message translates to:
  /// **'Output already exists. Choose a new .scx path.'**
  String get editorOutputAlreadyExistsChooseANewScxPath;

  /// No description provided for @editorPreparationCancelled.
  ///
  /// In en, this message translates to:
  /// **'Preparation cancelled.'**
  String get editorPreparationCancelled;

  /// No description provided for @editorToolSelectionChangedPrepareAgain.
  ///
  /// In en, this message translates to:
  /// **'Tool selection changed. Prepare again.'**
  String get editorToolSelectionChangedPrepareAgain;

  /// No description provided for @editorProjectOrMapChangedPrepareAgain.
  ///
  /// In en, this message translates to:
  /// **'Project or map changed. Prepare again.'**
  String get editorProjectOrMapChangedPrepareAgain;

  /// No description provided for @editorBuildPreparationFailed.
  ///
  /// In en, this message translates to:
  /// **'Build preparation failed: {value0}'**
  String editorBuildPreparationFailed(String value0);

  /// No description provided for @editorTheToolDirectoryCouldNotBeSelected.
  ///
  /// In en, this message translates to:
  /// **'The tool directory could not be selected: {value0}'**
  String editorTheToolDirectoryCouldNotBeSelected(String value0);

  /// No description provided for @editorEnterAnAbsoluteEuddraftInstallationPath.
  ///
  /// In en, this message translates to:
  /// **'Enter an absolute euddraft installation path.'**
  String get editorEnterAnAbsoluteEuddraftInstallationPath;

  /// No description provided for @editorToolSettingsCouldNotBeUpdated.
  ///
  /// In en, this message translates to:
  /// **'Tool settings could not be updated: {value0}'**
  String editorToolSettingsCouldNotBeUpdated(String value0);

  /// No description provided for @editorRangeErrorInvalidValueNotInInclusiveRange.
  ///
  /// In en, this message translates to:
  /// **'RangeError ({value0}): Invalid value: Not in inclusive range {value1}..{value2}: {value3}'**
  String editorRangeErrorInvalidValueNotInInclusiveRange(
    String value0,
    String value1,
    String value2,
    String value3,
  );

  /// No description provided for @editorRecovery.
  ///
  /// In en, this message translates to:
  /// **'Recovery'**
  String get editorRecovery;

  /// No description provided for @editorSaveAs.
  ///
  /// In en, this message translates to:
  /// **'Save As'**
  String get editorSaveAs;

  /// No description provided for @editorOpenMap.
  ///
  /// In en, this message translates to:
  /// **'Open Map'**
  String get editorOpenMap;

  /// No description provided for @editorEUDBuild.
  ///
  /// In en, this message translates to:
  /// **'EUD Build'**
  String get editorEUDBuild;

  /// No description provided for @editorTheMapCouldNotBeSaved.
  ///
  /// In en, this message translates to:
  /// **'The map could not be saved.'**
  String get editorTheMapCouldNotBeSaved;

  /// No description provided for @editorRepairTheApplicationOrReportTheObjectRenderingError.
  ///
  /// In en, this message translates to:
  /// **'Repair the application or report the object rendering error.'**
  String get editorRepairTheApplicationOrReportTheObjectRenderingError;

  /// No description provided for @editorRepairTheApplicationOrReportTheStarCraftTileHelper.
  ///
  /// In en, this message translates to:
  /// **'Repair the application or report the StarCraft tile helper error.'**
  String get editorRepairTheApplicationOrReportTheStarCraftTileHelper;

  /// No description provided for @editorTheEUDOutputMustBeAbsentOrARegular.
  ///
  /// In en, this message translates to:
  /// **'The EUD output must be absent or a regular file.'**
  String get editorTheEUDOutputMustBeAbsentOrARegular;

  /// No description provided for @editorTheCanonicalEUDEntrySourceIsOutsideTheSource.
  ///
  /// In en, this message translates to:
  /// **'The canonical EUD entry source is outside the source root.'**
  String get editorTheCanonicalEUDEntrySourceIsOutsideTheSource;

  /// No description provided for @editorTheCanonicalEUDOutputDirectoryIsInsideTheSource.
  ///
  /// In en, this message translates to:
  /// **'The canonical EUD output directory is inside the source root.'**
  String get editorTheCanonicalEUDOutputDirectoryIsInsideTheSource;

  /// No description provided for @editorSavedSnapshotNewerEditsRemain.
  ///
  /// In en, this message translates to:
  /// **'The saved snapshot was verified. Newer edits remain open and unsaved.'**
  String get editorSavedSnapshotNewerEditsRemain;

  /// No description provided for @editorSaveCurrentDocumentAgain.
  ///
  /// In en, this message translates to:
  /// **'Finish editing and use Save As again to save the current document.'**
  String get editorSaveCurrentDocumentAgain;
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
