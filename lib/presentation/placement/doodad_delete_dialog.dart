import 'package:flutter/material.dart';

import '../../application/editing/object_editing_controller.dart';
import '../../application/layers/map_layer_controller.dart';
import '../../application/placement/placement_catalog_controller.dart';
import '../../domain/placement/doodad_placement_recipe.dart';
import '../../domain/placement/doodad_deletion_plan.dart';
import '../../domain/placement/unit_deletion_plan.dart';
import '../../domain/placement/location_deletion_plan.dart';
import '../../domain/chk/typed/chk_object_views.dart';
import '../../application/documents/opened_map_session.dart';
import '../localization/l10n.dart';

Future<void> deleteObjectsWithDoodadReview(
  BuildContext context,
  ObjectEditingController editing,
  PlacementCatalogController catalog,
) async {
  final selected = editing.mapLayerController.state.selections.toList();
  if (!selected.any((s) => s.object.layer == MapLayerType.doodads)) {
    editing.deleteSelection();
    return;
  }
  try {
    if (selected.any(
      (s) =>
          s.object.layer != MapLayerType.doodads &&
          s.object.layer != MapLayerType.sprites &&
          s.object.layer != MapLayerType.units &&
          s.object.layer != MapLayerType.locations,
    )) {
      throw StateError(context.l10n.doodadDeleteMixedSelection);
    }
    final doodads = selected
        .where((s) => s.object.layer == MapLayerType.doodads)
        .toList();
    final sprites = selected
        .where((s) => s.object.layer == MapLayerType.sprites)
        .toList();
    final units = selected
        .where((s) => s.object.layer == MapLayerType.units)
        .toList();
    final locations = selected
        .where((s) => s.object.layer == MapLayerType.locations)
        .toList();
    if (doodads.length > DoodadDeletionPlan.maximumBatchSize) {
      throw StateError(
        context.l10n.doodadDeleteBatchLimit(
          DoodadDeletionPlan.maximumBatchSize,
        ),
      );
    }
    if (sprites.length > DoodadDeletionPlan.maximumSelectedSprites) {
      throw StateError(
        context.l10n.doodadDeleteSpriteLimit(
          DoodadDeletionPlan.maximumSelectedSprites,
        ),
      );
    }
    if (units.length > UnitDeletionPlan.maximumSelectedUnits) {
      throw StateError(
        context.l10n.doodadDeleteUnitLimit(
          UnitDeletionPlan.maximumSelectedUnits,
        ),
      );
    }
    if (locations.length > LocationDeletionPlan.maximumSelectedLocations) {
      throw StateError(
        context.l10n.doodadDeleteLocationLimit(
          LocationDeletionPlan.maximumSelectedLocations,
        ),
      );
    }
    final session = editing.openMapController.state.session!;
    if (session.objectViews.spriteSections.length > 1) {
      throw StateError(context.l10n.doodadDeleteAmbiguousSprites);
    }
    if (selected.length > 1) {
      await _reviewBatch(
        context,
        editing,
        catalog,
        session,
        doodads,
        sprites,
        units,
        locations,
      );
      return;
    }
    final object = selected.single.object;
    final section = session.objectViews.doodadSections
        .where((s) => s.sectionIndex == object.sectionIndex)
        .single;
    final doodad = section.doodads[object.recordIndex];
    final byType = await catalog.doodadRecipesForTypes(
      editing.doodadDeletionRecipeTypes([object.recordIndex]),
      requireCompleteTypes: true,
    );
    if (!context.mounted) return;
    if (!identical(
      editing.openMapController.state.session?.rawDocument,
      session.rawDocument,
    )) {
      throw StateError(context.l10n.doodadDeleteMapChanged);
    }
    final recipes =
        byType[doodad.doodadType] ?? const <DoodadPlacementRecipe>[];
    if (recipes.isEmpty) {
      throw StateError(context.l10n.doodadDeleteNoRecipe);
    }
    var recipe = recipes.first;
    int? overlayIndex;
    String? error;
    await showDialog<void>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, update) {
          final overlay = recipe.overlay;
          final candidates = [
            for (final sprites in session.objectViews.spriteSections)
              for (final sprite in sprites.sprites)
                if (overlay != null &&
                    sprite.spriteType == overlay.id &&
                    sprite.x == doodad.x &&
                    sprite.y == doodad.y &&
                    sprite.owner == doodad.owner &&
                    sprite.flags ==
                        overlay.flagsForEnabled(doodad.enabledValue == 0) &&
                    sprite.unused == 0)
                  sprite,
          ];
          return AlertDialog(
            title: Text(context.l10n.doodadDeleteTitle),
            content: SizedBox(
              width: 520,
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      context.l10n.doodadDeleteRecord(
                        object.recordIndex,
                        doodad.doodadType,
                        doodad.enabledValue,
                      ),
                    ),
                    DropdownButton<DoodadPlacementRecipe>(
                      value: recipe,
                      isExpanded: true,
                      items: [
                        for (final r in recipes)
                          DropdownMenuItem(
                            value: r,
                            child: Text(
                              context.l10n.doodadDeleteRecipe(
                                r.startTileGroup,
                                r.width,
                                r.height,
                              ),
                            ),
                          ),
                      ],
                      onChanged: (r) => update(() {
                        recipe = r!;
                        overlayIndex = null;
                        error = null;
                      }),
                    ),
                    if (overlay != null) ...[
                      Text(context.l10n.doodadDeleteOwnershipWarning),
                      DropdownButton<int>(
                        key: const Key('doodad-delete-overlay'),
                        value: overlayIndex,
                        hint: Text(context.l10n.doodadDeleteOverlayHint),
                        isExpanded: true,
                        items: [
                          for (final s in candidates)
                            DropdownMenuItem(
                              value: s.recordIndex,
                              child: Text(
                                context.l10n.doodadDeleteOverlayRecord(
                                  s.recordIndex,
                                  s.spriteType,
                                ),
                              ),
                            ),
                        ],
                        onChanged: (value) => update(() {
                          overlayIndex = value;
                          error = null;
                        }),
                      ),
                    ],
                    if (error != null)
                      Text(
                        error!,
                        style: TextStyle(
                          color: Theme.of(context).colorScheme.error,
                        ),
                      ),
                  ],
                ),
              ),
            ),
            actions: [
              TextButton(
                key: const Key('doodad-delete-cancel'),
                onPressed: () => Navigator.pop(dialogContext),
                child: Text(context.l10n.eudCancel),
              ),
              FilledButton(
                key: const Key('doodad-delete-apply'),
                onPressed: overlay != null && overlayIndex == null
                    ? null
                    : () {
                        try {
                          if (!identical(
                            editing
                                .openMapController
                                .state
                                .session
                                ?.rawDocument,
                            session.rawDocument,
                          )) {
                            throw StateError(
                              context.l10n.doodadDeleteMapChanged,
                            );
                          }
                          final plan = editing.prepareDoodadDeletion(
                            recipe: recipe,
                            recordIndex: object.recordIndex,
                            overlayRecordIndex: overlayIndex,
                            retainedNeighborCandidates: byType,
                          );
                          editing.deleteDoodad(plan);
                          Navigator.pop(dialogContext);
                        } catch (failure) {
                          update(() => error = '$failure');
                        }
                      },
                child: Text(context.l10n.doodadDeleteApply),
              ),
            ],
          );
        },
      ),
    );
  } catch (error) {
    if (context.mounted) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('$error')));
    }
  }
}

final class _DoodadReview {
  _DoodadReview(this.doodad, this.recipes);
  final ChkDoodadPlacement doodad;
  final List<DoodadPlacementRecipe> recipes;
  late DoodadPlacementRecipe recipe = recipes.first;
  int? overlayIndex;
}

Future<void> _reviewBatch(
  BuildContext context,
  ObjectEditingController editing,
  PlacementCatalogController catalog,
  OpenedMapSession session,
  List<MapLayerSelection> selected,
  List<MapLayerSelection> sprites,
  List<MapLayerSelection> units,
  List<MapLayerSelection> locations,
) async {
  if (locations.any(
    (s) =>
        session.objectViews.locationSections.length != 1 ||
        s.object.sectionIndex !=
            session.objectViews.locationSections.single.sectionIndex,
  )) {
    throw StateError(context.l10n.doodadDeleteAmbiguousLocations);
  }
  final LocationDeletionPlan? locationPlan;
  try {
    locationPlan = locations.isEmpty
        ? null
        : editing.prepareLocationDeletion(
            locations.map((s) => s.object.recordIndex),
          );
  } on Object catch (failure) {
    throw StateError('${context.l10n.doodadDeleteLocationUnsafe}\n$failure');
  }
  if (units.any(
    (s) =>
        session.objectViews.unitSections.length != 1 ||
        s.object.sectionIndex !=
            session.objectViews.unitSections.single.sectionIndex,
  )) {
    throw StateError(context.l10n.doodadDeleteAmbiguousUnits);
  }
  final unitPlan = units.isEmpty
      ? null
      : editing.prepareUnitDeletion(units.map((s) => s.object.recordIndex));
  if (sprites.any(
    (s) =>
        session.objectViews.spriteSections.length != 1 ||
        s.object.sectionIndex !=
            session.objectViews.spriteSections.single.sectionIndex,
  )) {
    throw StateError(context.l10n.doodadDeleteAmbiguousSprites);
  }
  final doodads = <ChkDoodadPlacement>[];
  for (final selection in selected) {
    final object = selection.object;
    final section = session.objectViews.doodadSections
        .where((s) => s.sectionIndex == object.sectionIndex)
        .single;
    doodads.add(section.doodads[object.recordIndex]);
  }
  final byType = await catalog.doodadRecipesForTypes(
    editing.doodadDeletionRecipeTypes(doodads.map((d) => d.recordIndex)),
    requireCompleteTypes: true,
  );
  if (!context.mounted) return;
  if (!identical(
    editing.openMapController.state.session?.rawDocument,
    session.rawDocument,
  )) {
    throw StateError(context.l10n.doodadDeleteMapChanged);
  }
  final reviews = <_DoodadReview>[];
  for (final d in doodads) {
    final recipes = byType[d.doodadType] ?? const <DoodadPlacementRecipe>[];
    if (recipes.isEmpty) throw StateError(context.l10n.doodadDeleteNoRecipe);
    reviews.add(_DoodadReview(d, recipes));
  }
  if (!context.mounted) return;
  String? error;
  var unlinkConfirmed =
      unitPlan == null || unitPlan.unlinkedPeerRecordIndices.isEmpty;
  var locationsConfirmed = locationPlan == null;
  await showDialog<void>(
    context: context,
    builder: (dialogContext) => StatefulBuilder(
      builder: (context, update) {
        final ready =
            unlinkConfirmed &&
            locationsConfirmed &&
            reviews.every(
              (r) => r.recipe.overlay == null || r.overlayIndex != null,
            );
        return AlertDialog(
          title: Text(
            units.isNotEmpty || locations.isNotEmpty
                ? context.l10n.doodadDeleteUnitMixedTitle
                : sprites.isEmpty
                ? context.l10n.doodadDeleteBatchTitle(reviews.length)
                : context.l10n.doodadDeleteMixedTitle(
                    reviews.length,
                    sprites.length,
                  ),
          ),
          content: SizedBox(
            width: 560,
            height: 420,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Expanded(
                  child: ListView(
                    children: [
                      if (unitPlan != null || locationPlan != null)
                        Text(
                          context.l10n.doodadDeleteUnitSummary(
                            reviews.length,
                            units.length,
                            sprites.length,
                          ),
                        ),
                      if (locationPlan != null) ...[
                        CheckboxListTile(
                          key: const Key('doodad-delete-location-confirm'),
                          value: locationsConfirmed,
                          contentPadding: EdgeInsets.zero,
                          controlAffinity: ListTileControlAffinity.leading,
                          title: Text(
                            context.l10n.doodadDeleteLocationConfirm(
                              locations.length,
                            ),
                          ),
                          onChanged: (value) => update(() {
                            locationsConfirmed = value!;
                            error = null;
                          }),
                        ),
                        for (final index in locationPlan.recordIndices)
                          Text(
                            context.l10n.doodadDeleteLocationRecord(
                              index + 1,
                              index,
                            ),
                          ),
                        const Divider(),
                      ],
                      if (unitPlan != null) ...[
                        for (final selection in units)
                          Text(
                            context.l10n.doodadDeleteUnitRecord(
                              selection.object.recordIndex,
                              session
                                  .objectViews
                                  .unitSections
                                  .single
                                  .units[selection.object.recordIndex]
                                  .unitType,
                            ),
                          ),
                        if (unitPlan.unlinkedPeerRecordIndices.isNotEmpty) ...[
                          CheckboxListTile(
                            key: const Key('doodad-delete-unit-unlink'),
                            value: unlinkConfirmed,
                            controlAffinity: ListTileControlAffinity.leading,
                            contentPadding: EdgeInsets.zero,
                            title: Text(
                              context.l10n.doodadDeleteUnitUnlink(
                                unitPlan.unlinkedPeerRecordIndices.length,
                              ),
                            ),
                            onChanged: (value) => update(() {
                              unlinkConfirmed = value!;
                              error = null;
                            }),
                          ),
                          for (final index
                              in unitPlan.unlinkedPeerRecordIndices)
                            Text(
                              context.l10n.doodadDeleteUnitRecord(
                                index,
                                session
                                    .objectViews
                                    .unitSections
                                    .single
                                    .units[index]
                                    .unitType,
                              ),
                            ),
                        ],
                        const Divider(),
                      ],
                      if (sprites.isNotEmpty) ...[
                        Text(context.l10n.doodadDeleteSelectedSprites),
                        for (final selection in sprites)
                          Text(
                            context.l10n.doodadDeleteOverlayRecord(
                              selection.object.recordIndex,
                              session
                                  .objectViews
                                  .spriteSections
                                  .single
                                  .sprites[selection.object.recordIndex]
                                  .spriteType,
                            ),
                          ),
                        const Divider(),
                      ],
                      for (final r in reviews) ...[
                        Text(
                          context.l10n.doodadDeleteRecord(
                            r.doodad.recordIndex,
                            r.doodad.doodadType,
                            r.doodad.enabledValue,
                          ),
                        ),
                        DropdownButton<DoodadPlacementRecipe>(
                          key: Key(
                            'doodad-delete-recipe-${r.doodad.recordIndex}',
                          ),
                          value: r.recipe,
                          isExpanded: true,
                          items: [
                            for (final recipe in r.recipes)
                              DropdownMenuItem(
                                value: recipe,
                                child: Text(
                                  context.l10n.doodadDeleteRecipe(
                                    recipe.startTileGroup,
                                    recipe.width,
                                    recipe.height,
                                  ),
                                ),
                              ),
                          ],
                          onChanged: (value) => update(() {
                            r.recipe = value!;
                            r.overlayIndex = null;
                            error = null;
                          }),
                        ),
                        if (r.recipe.overlay case final overlay?) ...[
                          Text(context.l10n.doodadDeleteOwnershipWarning),
                          DropdownButton<int>(
                            key: Key(
                              'doodad-delete-overlay-${r.doodad.recordIndex}',
                            ),
                            value: r.overlayIndex,
                            isExpanded: true,
                            hint: Text(context.l10n.doodadDeleteOverlayHint),
                            items: [
                              for (final section
                                  in session.objectViews.spriteSections)
                                for (final s in section.sprites)
                                  if (s.spriteType == overlay.id &&
                                      s.x == r.doodad.x &&
                                      s.y == r.doodad.y &&
                                      s.owner == r.doodad.owner &&
                                      s.flags ==
                                          overlay.flagsForEnabled(
                                            r.doodad.enabledValue == 0,
                                          ) &&
                                      s.unused == 0)
                                    DropdownMenuItem(
                                      value: s.recordIndex,
                                      child: Text(
                                        context.l10n.doodadDeleteOverlayRecord(
                                          s.recordIndex,
                                          s.spriteType,
                                        ),
                                      ),
                                    ),
                            ],
                            onChanged: (value) => update(() {
                              r.overlayIndex = value;
                              error = null;
                            }),
                          ),
                        ],
                        const Divider(),
                      ],
                    ],
                  ),
                ),
                if (error != null)
                  Text(
                    error!,
                    maxLines: 3,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.error,
                    ),
                  ),
              ],
            ),
          ),
          actions: [
            TextButton(
              key: const Key('doodad-delete-cancel'),
              onPressed: () => Navigator.pop(dialogContext),
              child: Text(context.l10n.eudCancel),
            ),
            FilledButton(
              key: const Key('doodad-delete-apply'),
              onPressed: !ready
                  ? null
                  : () {
                      try {
                        if (!identical(
                          editing.openMapController.state.session?.rawDocument,
                          session.rawDocument,
                        )) {
                          throw StateError(context.l10n.doodadDeleteMapChanged);
                        }
                        final plan = editing.prepareDoodadDeletions(
                          [
                            for (final r in reviews)
                              DoodadDeletionRequest(
                                recipe: r.recipe,
                                recordIndex: r.doodad.recordIndex,
                                confirmedOverlayRecordIndex: r.overlayIndex,
                              ),
                          ],
                          selectedSpriteRecordIndices: sprites.map(
                            (s) => s.object.recordIndex,
                          ),
                          selectedUnitRecordIndices: units.map(
                            (s) => s.object.recordIndex,
                          ),
                          confirmedUnitPeerRecordIndices:
                              unitPlan?.unlinkedPeerRecordIndices ?? const [],
                          selectedLocationRecordIndices: locations.map(
                            (s) => s.object.recordIndex,
                          ),
                          confirmedLocationRecordIndices:
                              locationPlan?.recordIndices ?? const [],
                          retainedNeighborCandidates: byType,
                        );
                        editing.deleteDoodad(plan);
                        Navigator.pop(dialogContext);
                      } on Object catch (e) {
                        update(() => error = '$e');
                      }
                    },
              child: Text(context.l10n.doodadDeleteApply),
            ),
          ],
        );
      },
    ),
  );
}
