import 'package:flutter/material.dart';

import '../../application/editing/object_editing_controller.dart';
import '../../application/layers/map_layer_controller.dart';
import '../../application/placement/placement_catalog_controller.dart';
import '../../domain/placement/doodad_placement_recipe.dart';
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
    if (selected.length != 1) {
      throw StateError(context.l10n.doodadDeleteOneRequired);
    }
    final session = editing.openMapController.state.session!;
    if (session.objectViews.spriteSections.length > 1) {
      throw StateError(context.l10n.doodadDeleteAmbiguousSprites);
    }
    final object = selected.single.object;
    final section = session.objectViews.doodadSections
        .where((s) => s.sectionIndex == object.sectionIndex)
        .single;
    final doodad = section.doodads[object.recordIndex];
    final recipes = await catalog.doodadRecipes(doodad.doodadType);
    if (!context.mounted) return;
    if (!identical(
      editing.openMapController.state.session?.rawDocument,
      session.rawDocument,
    )) {
      throw StateError(context.l10n.doodadDeleteMapChanged);
    }
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
