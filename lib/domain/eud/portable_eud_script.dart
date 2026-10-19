import '../triggers/trigger_script_syntax.dart';

/// A deliberately bounded EUD interchange contract, not a general interpreter.
/// A hook contains ordered action calls; action statements in epScript lower to
/// DoActions in Python. Treating those calls as bare Python expressions loses
/// their effect, so both readers normalize to the same action-only model.
final class PortableEudScript {
  PortableEudScript._(this.hooks);
  final Map<String, List<TriggerScriptCall>> hooks;
  static const hookNames = {
    'onPluginStart',
    'beforeTriggerExec',
    'afterTriggerExec',
  };
  static const actions = {
    'SetMemory',
    'SetMemoryX',
    'SetDeaths',
    'SetDeathsX',
    'SetResources',
    'SetScore',
    'SetSwitch',
    'SetCountdownTimer',
    'SetInvincibility',
    'SetDoodadState',
    'SetAllianceStatus',
    'SetMissionObjectives',
    'DisplayText',
    'PlayWAV',
    'CenterView',
    'PingMinimap',
    'TalkingPortrait',
    'CreateUnit',
    'CreateUnitWithProperties',
    'KillUnit',
    'KillUnitAt',
    'RemoveUnit',
    'RemoveUnitAt',
    'MoveUnit',
    'MoveLocation',
    'GiveUnits',
    'Order',
    'ModifyUnitHitPoints',
    'ModifyUnitEnergy',
    'ModifyUnitShields',
    'ModifyUnitResourceAmount',
    'ModifyUnitHangarCount',
    'SetNextScenario',
    'RunAIScript',
    'RunAIScriptAt',
    'Victory',
    'Defeat',
    'Draw',
    'PreserveTrigger',
    'Comment',
    'MuteUnitSpeech',
    'UnMuteUnitSpeech',
    'PauseGame',
    'UnpauseGame',
    'PauseTimer',
    'UnpauseTimer',
  };
  static const constants = {
    'P1',
    'P2',
    'P3',
    'P4',
    'P5',
    'P6',
    'P7',
    'P8',
    'P9',
    'P10',
    'P11',
    'P12',
    'CurrentPlayer',
    'AllPlayers',
    'Force1',
    'Force2',
    'Force3',
    'Force4',
    'SetTo',
    'Add',
    'Subtract',
    'Ore',
    'Gas',
    'OreAndGas',
    'Total',
    'Units',
    'Buildings',
    'UnitsAndBuildings',
    'Kills',
    'Razings',
    'KillsAndRazings',
    'Custom',
    'Enable',
    'Disable',
    'Toggle',
    'Set',
    'Clear',
    'Random',
    'Ally',
    'Enemy',
    'AlliedVictory',
    'Move',
    'Patrol',
    'Attack',
    'All',
  };

  factory PortableEudScript.parse(
    String source,
    TriggerScriptLanguage language,
  ) {
    if (source.length > TriggerScriptSyntax.maximumCharacters) {
      throw const TriggerScriptDiagnostic('SCRIPT_SIZE', 0);
    }
    final lines = source.split('\n');
    final hooks = <String, List<TriggerScriptCall>>{};
    String? name;
    var body = StringBuffer(), offset = 0, bodyOffset = 0;
    var decorated = false, imported = false;
    final bodyPositions = <int>[];
    int absolute(int position) => bodyPositions.isEmpty
        ? bodyOffset
        : bodyPositions[position.clamp(0, bodyPositions.length - 1)];
    void finish() {
      var text = body.toString();
      final emptyPython =
          language == TriggerScriptLanguage.python && text.trim() == 'pass';
      // pass is only allowed as the entire empty Python hook.
      if (language == TriggerScriptLanguage.python && text.trim() == 'pass') {
        text = '';
      }
      List<TriggerScriptCall> calls;
      try {
        calls = TriggerScriptSyntax(
          text,
          language,
          allowIdentifiers: true,
        ).parse();
      } on TriggerScriptDiagnostic catch (e) {
        throw TriggerScriptDiagnostic(e.code, absolute(e.offset), e.detail);
      }
      if (language == TriggerScriptLanguage.python &&
          calls.isEmpty &&
          !emptyPython) {
        throw TriggerScriptDiagnostic('EUD_EMPTY_PYTHON_BODY', bodyOffset);
      }
      final normalized = <TriggerScriptCall>[];
      for (var call in calls) {
        if (language == TriggerScriptLanguage.python) {
          if (call.name != 'DoActions' ||
              call.arguments.length != 1 ||
              call.arguments.single is! TriggerScriptCall) {
            throw TriggerScriptDiagnostic(
              'EUD_ACTION_WRAPPER',
              absolute(call.offset),
            );
          }
          call = call.arguments.single as TriggerScriptCall;
        }
        if (!actions.contains(call.name)) {
          throw TriggerScriptDiagnostic(
            'EUD_UNSUPPORTED_CALL',
            absolute(call.offset),
            call.name,
          );
        }
        void check(Object value) {
          if (value is TriggerScriptIdentifier &&
              !constants.contains(value.name)) {
            throw TriggerScriptDiagnostic(
              'EUD_UNSUPPORTED_CONSTANT',
              absolute(call.offset),
              value.name,
            );
          }
          if (value is TriggerScriptCall) {
            if (value.name != 'EPD' ||
                value.arguments.length != 1 ||
                value.arguments.single is! int) {
              throw TriggerScriptDiagnostic(
                'EUD_UNSUPPORTED_EXPRESSION',
                absolute(call.offset),
                value.name,
              );
            }
            value.arguments.forEach(check);
          }
        }

        call.arguments.forEach(check);
        normalized.add(call);
      }
      hooks[name!] = List.unmodifiable(normalized);
      name = null;
      body = StringBuffer();
      bodyPositions.clear();
    }

    final header = switch (language) {
      TriggerScriptLanguage.epScript => RegExp(
        r'^function ([A-Za-z][A-Za-z0-9]*)\(\) \{$',
      ),
      TriggerScriptLanguage.python => RegExp(
        r'^def ([A-Za-z][A-Za-z0-9]*)\(\):$',
      ),
      TriggerScriptLanguage.lua => RegExp(
        r'^function ([A-Za-z][A-Za-z0-9]*)\(\)$',
      ),
    };
    for (final rawLine in lines) {
      final line = rawLine.endsWith('\r')
          ? rawLine.substring(0, rawLine.length - 1)
          : rawLine;
      final lineLength = rawLine.length + 1;
      final trimmed = line.trim();
      final empty = trimmed.isEmpty || trimmed.startsWith(language.comment);
      if (language == TriggerScriptLanguage.python &&
          name != null &&
          !empty &&
          !line.startsWith(' ')) {
        finish();
      }
      if (name == null) {
        if (empty) {
          offset += lineLength;
          continue;
        }
        if (language == TriggerScriptLanguage.python &&
            line == 'from eudplib import *' &&
            !imported &&
            hooks.isEmpty &&
            !decorated) {
          imported = true;
          offset += lineLength;
          continue;
        }
        if (language == TriggerScriptLanguage.python &&
            line == '@EUDFunc' &&
            !decorated) {
          decorated = true;
          offset += lineLength;
          continue;
        }
        final match = header.firstMatch(line);
        if (match == null ||
            !hookNames.contains(match.group(1)) ||
            hooks.containsKey(match.group(1)) ||
            (language == TriggerScriptLanguage.python &&
                (!decorated || !imported))) {
          throw TriggerScriptDiagnostic('EUD_UNSUPPORTED_STRUCTURE', offset);
        }
        name = match.group(1)!;
        decorated = false;
        bodyOffset = offset + lineLength;
      } else if ((language == TriggerScriptLanguage.epScript && line == '}') ||
          (language == TriggerScriptLanguage.lua && line == 'end')) {
        finish();
      } else {
        if (!empty && !line.startsWith('    ')) {
          throw TriggerScriptDiagnostic('EUD_UNSUPPORTED_INDENT', offset);
        }
        final removed =
            language == TriggerScriptLanguage.python && line.startsWith('    ')
            ? 4
            : 0;
        body.writeln(line.substring(removed));
        // Map normalized body offsets back to UTF-16 editor positions, including
        // removed indentation and CRLF. Diagnostics never select the wrong line.
        for (var i = removed; i <= line.length; i++) {
          bodyPositions.add(offset + i);
        }
      }
      offset += lineLength;
    }
    if (name != null) {
      if (language != TriggerScriptLanguage.python) {
        throw TriggerScriptDiagnostic('EUD_UNCLOSED_HOOK', source.length);
      }
      finish();
    }
    if (decorated || hooks.isEmpty) {
      throw const TriggerScriptDiagnostic('EUD_EMPTY_OR_INCOMPLETE', 0);
    }
    return PortableEudScript._(Map.unmodifiable(hooks));
  }

  String format(TriggerScriptLanguage language) {
    String value(Object v) => switch (v) {
      TriggerScriptIdentifier() => v.name,
      TriggerScriptCall() => '${v.name}(${v.arguments.map(value).join(', ')})',
      String() => v.contains('"') ? "'$v'" : '"$v"',
      bool() => language.boolean(v),
      int() => '$v',
      _ => throw StateError('EUD_VALUE'),
    };
    final lines = <String>[
      '${language.comment} Portable EUD actions v1; original source retained',
      if (language == TriggerScriptLanguage.python) 'from eudplib import *',
      '',
      for (final hook in hooks.entries) ...[
        if (language == TriggerScriptLanguage.python) '@EUDFunc',
        switch (language) {
          TriggerScriptLanguage.epScript => 'function ${hook.key}() {',
          TriggerScriptLanguage.python => 'def ${hook.key}():',
          TriggerScriptLanguage.lua => 'function ${hook.key}()',
        },
        if (hook.value.isEmpty && language == TriggerScriptLanguage.python)
          '    pass',
        for (final call in hook.value)
          '    ${language == TriggerScriptLanguage.python ? 'DoActions(${value(call)})' : value(call)}${language == TriggerScriptLanguage.epScript ? ';' : ''}',
        if (language == TriggerScriptLanguage.epScript) '}',
        if (language == TriggerScriptLanguage.lua) 'end',
        '',
      ],
    ];
    return '${lines.join('\n')}\n';
  }

  String convert(TriggerScriptLanguage language) {
    final output = format(language);
    // Formatting the normalized model verifies hook order, values and calls.
    if (PortableEudScript.parse(
          output,
          language,
        ).format(TriggerScriptLanguage.python) !=
        format(TriggerScriptLanguage.python)) {
      throw const TriggerScriptDiagnostic('SCRIPT_EQUIVALENCE', 0);
    }
    return output;
  }
}
