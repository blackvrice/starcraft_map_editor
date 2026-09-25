import 'package:flutter/material.dart';

import '../../application/editing/object_editing_controller.dart';
import '../../application/layers/map_layer_controller.dart';
import '../../application/placement/placement_catalog_controller.dart';
import '../../domain/placement/doodad_placement_recipe.dart';

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
      throw StateError('Select one Doodad for verified composite deletion.');
    }
    final session = editing.openMapController.state.session!;
    if (session.objectViews.spriteSections.length > 1) {
      throw StateError('Multiple THG2 sections are ambiguous.');
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
      throw StateError('The map changed. Select the Doodad again.');
    }
    if (recipes.isEmpty) {
      throw StateError('No verified recipe is available for this Doodad.');
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
                    sprite.flags == overlay.thg2Flags &&
                    sprite.unused == 0)
                  sprite,
          ];
          return AlertDialog(
            title: const Text('Delete Doodad and restore terrain'),
            content: SizedBox(
              width: 520,
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Restore the verified footprint from TILE and delete DD2 metadata together. Cancel leaves the map unchanged.',
                    ),
                    DropdownButton<DoodadPlacementRecipe>(
                      value: recipe,
                      isExpanded: true,
                      items: [
                        for (final r in recipes)
                          DropdownMenuItem(
                            value: r,
                            child: Text(
                              'Group ${r.startTileGroup} · ${r.width} × ${r.height}',
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
                      const Text(
                        'Choose the overlay that belongs to this Doodad. Matching coordinates do not prove ownership. If unsure, cancel.',
                      ),
                      DropdownButton<int>(
                        value: overlayIndex,
                        hint: const Text('Confirm overlay ownership'),
                        isExpanded: true,
                        items: [
                          for (final s in candidates)
                            DropdownMenuItem(
                              value: s.recordIndex,
                              child: Text(
                                'THG2 record #${s.recordIndex} · type ${s.spriteType}',
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
                onPressed: () => Navigator.pop(dialogContext),
                child: const Text('Cancel'),
              ),
              FilledButton(
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
                              'The map changed. Reopen this dialog.',
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
                child: const Text('Delete together'),
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
