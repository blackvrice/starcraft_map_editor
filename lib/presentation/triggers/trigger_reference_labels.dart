import 'package:flutter/widgets.dart';
import '../localization/l10n.dart';

String triggerReferenceLabel(BuildContext context, String kind) =>
    switch (kind) {
      'location' => context.l10n.triggerRefLocation,
      'string' => context.l10n.triggerRefString,
      'unit' => context.l10n.triggerRefUnit,
      'unitGroup' => context.l10n.triggerRefUnitGroup,
      'switch' => context.l10n.triggerRefSwitch,
      'property' => context.l10n.triggerRefProperty,
      _ => kind,
    };
