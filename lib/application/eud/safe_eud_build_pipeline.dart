import '../../domain/chk/chk.dart';
import '../../domain/diagnostics/editor_diagnostic.dart';
import '../ports/eud_build_file_gateway.dart';
import '../ports/eud_build_gateway.dart';
import '../ports/eud_compiler_gateway.dart';
import '../ports/eud_tool_inspector.dart';
import '../ports/map_archive_gateway.dart';
import '../ports/map_file_fingerprint_gateway.dart';

abstract final class EudBuildPipelineDiagnosticCodes {
  static const duplicateBuildId = 'EUD_BUILD_DUPLICATE_ID';
  static const toolChanged = 'EUD_BUILD_TOOL_CHANGED';
  static const invalidInputs = 'EUD_BUILD_INVALID_INPUTS';
  static const inputOutputSame = 'EUD_BUILD_INPUT_OUTPUT_SAME';
  static const inputFingerprintFailed = 'EUD_BUILD_INPUT_FINGERPRINT_FAILED';
  static const sourceFingerprintFailed = 'EUD_BUILD_SOURCE_FINGERPRINT_FAILED';
  static const destinationExists = 'EUD_BUILD_DESTINATION_EXISTS';
  static const destinationFingerprintFailed =
      'EUD_BUILD_DESTINATION_FINGERPRINT_FAILED';
  static const workspaceFailed = 'EUD_BUILD_WORKSPACE_FAILED';
  static const processStreamEnded = 'EUD_BUILD_PROCESS_STREAM_ENDED';
  static const eventBuildIdMismatch = 'EUD_BUILD_EVENT_ID_MISMATCH';
  static const outputInvalid = 'EUD_BUILD_OUTPUT_INVALID';
  static const outputArchiveInvalid = 'EUD_BUILD_OUTPUT_ARCHIVE_INVALID';
  static const outputChkInvalid = 'EUD_BUILD_OUTPUT_CHK_INVALID';
  static const outputStructureInvalid = 'EUD_BUILD_OUTPUT_STRUCTURE_INVALID';
  static const inputChanged = 'EUD_BUILD_INPUT_CHANGED';
  static const sourceChanged = 'EUD_BUILD_SOURCE_CHANGED';
  static const destinationChanged = 'EUD_BUILD_DESTINATION_CHANGED';
  static const promotionFailed = 'EUD_BUILD_PROMOTION_FAILED';
  static const promotionRecoveryRequired =
      'EUD_BUILD_PROMOTION_RECOVERY_REQUIRED';
  static const backupCreated = 'EUD_BUILD_BACKUP_CREATED';
  static const cleanupFailed = 'EUD_BUILD_CLEANUP_FAILED';
  static const unexpectedFailure = 'EUD_BUILD_UNEXPECTED_FAILURE';
}

final class SafeEudBuildPipeline implements EudBuildGateway {
  SafeEudBuildPipeline({
    required this.toolInspector,
    required this.compilerGateway,
    required this.archiveGateway,
    required this.fingerprintGateway,
    required this.buildFileGateway,
    this.rawChkParser = const RawChkParser(),
    this.metadataViewDecoder = const ChkMetadataViewDecoder(),
    this.archiveTimeout = const Duration(seconds: 30),
  }) {
    if (archiveTimeout <= Duration.zero) {
      throw ArgumentError.value(
        archiveTimeout,
        'archiveTimeout',
        'The archive timeout must be positive.',
      );
    }
  }

  final EudToolInspector toolInspector;
  final EudCompilerGateway compilerGateway;
  final MapArchiveGateway archiveGateway;
  final MapFileFingerprintGateway fingerprintGateway;
  final EudBuildFileGateway buildFileGateway;
  final RawChkParser rawChkParser;
  final ChkMetadataViewDecoder metadataViewDecoder;
  final Duration archiveTimeout;
  final Set<String> _activeBuildIds = {};
  final Set<String> _activeCompilerBuildIds = {};

  @override
  Stream<EudBuildEvent> build(EudBuildPlan plan) async* {
    if (!_activeBuildIds.add(plan.buildId)) {
      yield EudBuildEvent.failed(
        buildId: plan.buildId,
        diagnostic: _diagnostic(
          code: EudBuildPipelineDiagnosticCodes.duplicateBuildId,
          message: 'A build with this ID is already active.',
          filePath: plan.configuration.entrySourcePath,
          remediation: 'Wait for the active build to finish and retry.',
        ),
      );
      return;
    }

    EudBuildWorkspace? workspace;
    EudBuildEvent? terminalEvent;
    final trailingDiagnostics = <EditorDiagnostic>[];
    try {
      final inspected = await toolInspector.inspect(
        EudToolInspectionRequest(projectProfilePath: plan.tool.executablePath),
      );
      if (!inspected.isReady) {
        throw _EudBuildFailure(
          _diagnostic(
            code: EudBuildPipelineDiagnosticCodes.toolChanged,
            message: 'The selected euddraft installation is no longer ready.',
            filePath: plan.tool.executablePath,
            remediation:
                'Inspect the configured euddraft installation and retry.',
          ),
          diagnostics: inspected.diagnostics,
        );
      }
      for (final diagnostic in inspected.diagnostics) {
        yield EudBuildEvent.diagnostic(
          buildId: plan.buildId,
          diagnostic: diagnostic,
        );
      }

      try {
        await buildFileGateway.validateInputs(plan.configuration);
      } on Object catch (error, stackTrace) {
        throw _EudBuildFailure(
          _diagnostic(
            code: EudBuildPipelineDiagnosticCodes.invalidInputs,
            message: 'The EUD build inputs are not safe regular files.',
            filePath: plan.configuration.entrySourcePath,
            remediation:
                'Check the base map, source root, entry source, and output '
                'folder.',
            rawDetails: '$error\n$stackTrace',
          ),
        );
      }

      final sameInputAndOutput = await buildFileGateway.refersToSameLocation(
        plan.configuration.baseMapPath,
        plan.configuration.outputMapPath,
      );
      if (sameInputAndOutput) {
        throw _EudBuildFailure(
          _diagnostic(
            code: EudBuildPipelineDiagnosticCodes.inputOutputSame,
            message: 'The EUD output resolves to the base map.',
            filePath: plan.configuration.outputMapPath,
            remediation: 'Choose a separate output file.',
          ),
        );
      }

      final inputFingerprintAtStart = await _fingerprint(
        path: plan.configuration.baseMapPath,
        code: EudBuildPipelineDiagnosticCodes.inputFingerprintFailed,
        message: 'The EUD base map fingerprint could not be calculated.',
      );
      final sourceFingerprintAtStart = await _fingerprint(
        path: plan.configuration.entrySourcePath,
        code: EudBuildPipelineDiagnosticCodes.sourceFingerprintFailed,
        message:
            'The epScript entry source fingerprint could not be calculated.',
      );

      final destinationExistedAtStart = await buildFileGateway
          .destinationExists(plan.configuration.outputMapPath);
      if (destinationExistedAtStart && !plan.replaceExistingOutput) {
        throw _EudBuildFailure(
          _diagnostic(
            code: EudBuildPipelineDiagnosticCodes.destinationExists,
            message: 'The EUD output already exists.',
            filePath: plan.configuration.outputMapPath,
            remediation:
                'Choose a new output or explicitly confirm replacement.',
          ),
        );
      }
      final destinationFingerprintAtStart = destinationExistedAtStart
          ? await _fingerprint(
              path: plan.configuration.outputMapPath,
              code:
                  EudBuildPipelineDiagnosticCodes.destinationFingerprintFailed,
              message:
                  'The existing EUD output fingerprint could not be '
                  'calculated.',
            )
          : null;

      try {
        workspace = await buildFileGateway.createWorkspace(plan.configuration);
      } on Object catch (error, stackTrace) {
        throw _EudBuildFailure(
          _diagnostic(
            code: EudBuildPipelineDiagnosticCodes.workspaceFailed,
            message: 'The temporary EUD build workspace could not be created.',
            filePath: plan.configuration.outputMapPath,
            remediation:
                'Check output folder permissions and available disk space.',
            rawDetails: '$error\n$stackTrace',
          ),
        );
      }

      final compilerRequest = plan.configuration.createCompilerRequest(
        buildId: plan.buildId,
        tool: inspected.tool!,
        settingsFilePath: workspace.settingsFilePath,
        timeout: plan.timeout,
      );
      var processSucceeded = false;
      _activeCompilerBuildIds.add(plan.buildId);
      try {
        await for (final event in compilerGateway.build(compilerRequest)) {
          if (event.buildId != plan.buildId) {
            await compilerGateway.cancel(plan.buildId);
            throw _EudBuildFailure(
              _diagnostic(
                code: EudBuildPipelineDiagnosticCodes.eventBuildIdMismatch,
                message: 'euddraft returned an event for a different build.',
                filePath: workspace.settingsFilePath,
                remediation: 'Inspect the build log and retry.',
                rawDetails: 'expected=${plan.buildId}; actual=${event.buildId}',
              ),
            );
          }

          if (event.kind == EudBuildEventKind.succeeded) {
            processSucceeded = true;
            break;
          }
          if (event.isTerminal) {
            terminalEvent = event;
            break;
          }
          yield event;
        }
      } finally {
        _activeCompilerBuildIds.remove(plan.buildId);
      }

      if (terminalEvent == null && !processSucceeded) {
        throw _EudBuildFailure(
          _diagnostic(
            code: EudBuildPipelineDiagnosticCodes.processStreamEnded,
            message: 'The euddraft event stream ended without a result.',
            filePath: workspace.settingsFilePath,
            remediation: 'Inspect the build log and retry.',
          ),
        );
      }

      if (processSucceeded) {
        yield EudBuildEvent.finalizing(buildId: plan.buildId);

        final outputFingerprint = await _fingerprint(
          path: workspace.temporaryOutputMapPath,
          code: EudBuildPipelineDiagnosticCodes.outputInvalid,
          message:
              'euddraft exited successfully but did not create a readable '
              'temporary map.',
          processExitCode: 0,
        );
        if (outputFingerprint.sizeBytes == 0) {
          throw _EudBuildFailure(
            _diagnostic(
              code: EudBuildPipelineDiagnosticCodes.outputInvalid,
              message:
                  'euddraft exited successfully but created an empty '
                  'temporary map.',
              filePath: workspace.temporaryOutputMapPath,
              remediation: 'Inspect the euddraft output and epScript source.',
            ),
            exitCode: 0,
          );
        }

        final archiveResult = await archiveGateway.open(
          MapArchiveOpenRequest(
            operationId: '${plan.buildId}-verify-output',
            sourcePath: workspace.temporaryOutputMapPath,
            timeout: archiveTimeout,
          ),
        );
        if (!archiveResult.isSuccess) {
          throw _EudBuildFailure(
            _diagnostic(
              code: EudBuildPipelineDiagnosticCodes.outputArchiveInvalid,
              message:
                  'The temporary EUD output is not a readable map archive.',
              filePath: workspace.temporaryOutputMapPath,
              remediation:
                  'Inspect the euddraft log and keep the base map unchanged.',
            ),
            diagnostics: archiveResult.diagnostics,
            exitCode: 0,
          );
        }
        for (final diagnostic in archiveResult.diagnostics) {
          yield EudBuildEvent.diagnostic(
            buildId: plan.buildId,
            diagnostic: diagnostic,
          );
        }

        final parseResult = rawChkParser.parse(
          archiveResult.extractedMap!.scenarioChkBytes,
        );
        if (!parseResult.isSuccess) {
          throw _EudBuildFailure(
            _diagnostic(
              code: EudBuildPipelineDiagnosticCodes.outputChkInvalid,
              message: 'The temporary EUD output contains an invalid CHK.',
              filePath: workspace.temporaryOutputMapPath,
              remediation:
                  'Inspect the euddraft log and keep the base map unchanged.',
            ),
            diagnostics: parseResult.diagnostics,
            exitCode: 0,
          );
        }

        final metadata = metadataViewDecoder.decode(parseResult.document!);
        if (metadata.hasBlockingDiagnostics) {
          throw _EudBuildFailure(
            _diagnostic(
              code: EudBuildPipelineDiagnosticCodes.outputStructureInvalid,
              message:
                  'The temporary EUD output failed CHK metadata validation.',
              filePath: workspace.temporaryOutputMapPath,
              remediation:
                  'Inspect the map validation diagnostics and euddraft log.',
            ),
            diagnostics: metadata.diagnostics,
            exitCode: 0,
          );
        }
        for (final diagnostic in metadata.diagnostics) {
          yield EudBuildEvent.diagnostic(
            buildId: plan.buildId,
            diagnostic: diagnostic,
          );
        }
        final hasMinimumStructure =
            metadata.versions.isNotEmpty &&
            metadata.dimensions.isNotEmpty &&
            metadata.tilesets.isNotEmpty &&
            metadata.dimensions.any(
              (view) => view.width > 0 && view.height > 0,
            );
        if (!hasMinimumStructure) {
          throw _EudBuildFailure(
            _diagnostic(
              code: EudBuildPipelineDiagnosticCodes.outputStructureInvalid,
              message:
                  'The temporary EUD output is missing required VER, DIM, '
                  'or ERA map metadata.',
              filePath: workspace.temporaryOutputMapPath,
              remediation: 'Use an intact StarCraft map as the EUD base map.',
            ),
            exitCode: 0,
          );
        }

        final inputFingerprintBeforePromotion = await _fingerprint(
          path: plan.configuration.baseMapPath,
          code: EudBuildPipelineDiagnosticCodes.inputFingerprintFailed,
          message: 'The EUD base map fingerprint could not be rechecked.',
          processExitCode: 0,
        );
        if (inputFingerprintBeforePromotion != inputFingerprintAtStart) {
          throw _EudBuildFailure(
            _diagnostic(
              code: EudBuildPipelineDiagnosticCodes.inputChanged,
              message:
                  'The base map changed during the EUD build, so the output '
                  'was not promoted.',
              filePath: plan.configuration.baseMapPath,
              remediation: 'Review the base map changes and rebuild.',
              rawDetails:
                  'start=$inputFingerprintAtStart; '
                  'beforePromotion=$inputFingerprintBeforePromotion',
            ),
            exitCode: 0,
          );
        }

        final sourceFingerprintBeforePromotion = await _fingerprint(
          path: plan.configuration.entrySourcePath,
          code: EudBuildPipelineDiagnosticCodes.sourceFingerprintFailed,
          message: 'The epScript entry fingerprint could not be rechecked.',
          processExitCode: 0,
        );
        if (sourceFingerprintBeforePromotion != sourceFingerprintAtStart) {
          throw _EudBuildFailure(
            _diagnostic(
              code: EudBuildPipelineDiagnosticCodes.sourceChanged,
              message:
                  'The epScript entry changed during the EUD build, so the '
                  'output was not promoted.',
              filePath: plan.configuration.entrySourcePath,
              remediation: 'Save the source changes and rebuild.',
              rawDetails:
                  'start=$sourceFingerprintAtStart; '
                  'beforePromotion=$sourceFingerprintBeforePromotion',
            ),
            exitCode: 0,
          );
        }

        await _verifyDestinationUnchanged(
          plan: plan,
          existedAtStart: destinationExistedAtStart,
          fingerprintAtStart: destinationFingerprintAtStart,
        );

        late final EudBuildPromotionResult promotion;
        try {
          promotion = await buildFileGateway.promote(
            workspace: workspace,
            destinationPath: plan.configuration.outputMapPath,
            replaceExisting: destinationExistedAtStart,
          );
        } on EudBuildPromotionRecoveryException catch (error, stackTrace) {
          throw _EudBuildFailure(
            _diagnostic(
              code: EudBuildPipelineDiagnosticCodes.promotionRecoveryRequired,
              message:
                  'The previous EUD output is safe in a backup, but automatic '
                  'restoration failed.',
              filePath: error.backupPath,
              remediation:
                  'Restore the backup to ${error.destinationPath} before '
                  'building again.',
              rawDetails: '$error\n$stackTrace',
            ),
            exitCode: 0,
          );
        } on Object catch (error, stackTrace) {
          throw _EudBuildFailure(
            _diagnostic(
              code: EudBuildPipelineDiagnosticCodes.promotionFailed,
              message:
                  'The verified EUD map could not be promoted to its output.',
              filePath: plan.configuration.outputMapPath,
              remediation:
                  'Check output folder permissions and choose a new name.',
              rawDetails: '$error\n$stackTrace',
            ),
            exitCode: 0,
          );
        }

        if (promotion.backupPath case final backupPath?) {
          yield EudBuildEvent.diagnostic(
            buildId: plan.buildId,
            diagnostic: EditorDiagnostic(
              code: EudBuildPipelineDiagnosticCodes.backupCreated,
              message:
                  'The previous EUD output was preserved as a recovery '
                  'backup.',
              severity: DiagnosticSeverity.info,
              stage: DiagnosticStage.compile,
              filePath: backupPath,
              remediation:
                  'Keep the backup until the generated map has been tested.',
            ),
          );
        }
        terminalEvent = EudBuildEvent.succeeded(
          buildId: plan.buildId,
          exitCode: 0,
        );
      }
    } on _EudBuildFailure catch (failure) {
      trailingDiagnostics.addAll(failure.diagnostics);
      terminalEvent = EudBuildEvent.failed(
        buildId: plan.buildId,
        diagnostic: failure.diagnostic,
        exitCode: failure.exitCode,
      );
    } on Object catch (error, stackTrace) {
      terminalEvent = EudBuildEvent.failed(
        buildId: plan.buildId,
        diagnostic: _diagnostic(
          code: EudBuildPipelineDiagnosticCodes.unexpectedFailure,
          message: 'The safe EUD build pipeline failed unexpectedly.',
          filePath: plan.configuration.outputMapPath,
          remediation: 'Inspect the build log and retry.',
          rawDetails: '$error\n$stackTrace',
        ),
      );
    } finally {
      if (workspace != null) {
        try {
          await buildFileGateway.cleanup(workspace);
        } on Object catch (error, stackTrace) {
          trailingDiagnostics.add(
            EditorDiagnostic(
              code: EudBuildPipelineDiagnosticCodes.cleanupFailed,
              message: 'The temporary EUD build workspace was not removed.',
              severity: DiagnosticSeverity.warning,
              stage: DiagnosticStage.compile,
              filePath: workspace.directoryPath,
              remediation:
                  'Close processes using the folder, then remove it manually.',
              rawDetails: '$error\n$stackTrace',
            ),
          );
        }
      }
      _activeCompilerBuildIds.remove(plan.buildId);
      _activeBuildIds.remove(plan.buildId);
    }

    for (final diagnostic in trailingDiagnostics) {
      if (diagnostic != terminalEvent?.diagnostic) {
        yield EudBuildEvent.diagnostic(
          buildId: plan.buildId,
          diagnostic: diagnostic,
        );
      }
    }
    if (terminalEvent != null) {
      yield terminalEvent;
    }
  }

  @override
  Future<bool> cancel(String buildId) async {
    if (!_activeCompilerBuildIds.contains(buildId)) {
      return false;
    }
    return compilerGateway.cancel(buildId);
  }

  Future<MapFileFingerprint> _fingerprint({
    required String path,
    required String code,
    required String message,
    int? processExitCode,
  }) async {
    try {
      return await fingerprintGateway.fingerprint(path);
    } on Object catch (error, stackTrace) {
      throw _EudBuildFailure(
        _diagnostic(
          code: code,
          message: message,
          filePath: path,
          remediation: 'Check that the file is readable and is not changing.',
          rawDetails: '$error\n$stackTrace',
        ),
        exitCode: processExitCode,
      );
    }
  }

  Future<void> _verifyDestinationUnchanged({
    required EudBuildPlan plan,
    required bool existedAtStart,
    required MapFileFingerprint? fingerprintAtStart,
  }) async {
    final existsBeforePromotion = await buildFileGateway.destinationExists(
      plan.configuration.outputMapPath,
    );
    if (existedAtStart) {
      if (!existsBeforePromotion) {
        throw _destinationChanged(
          plan.configuration.outputMapPath,
          'The existing output disappeared.',
        );
      }
      final fingerprintBeforePromotion = await _fingerprint(
        path: plan.configuration.outputMapPath,
        code: EudBuildPipelineDiagnosticCodes.destinationFingerprintFailed,
        message: 'The existing EUD output could not be rechecked.',
        processExitCode: 0,
      );
      if (fingerprintBeforePromotion != fingerprintAtStart) {
        throw _destinationChanged(
          plan.configuration.outputMapPath,
          'start=$fingerprintAtStart; '
          'beforePromotion=$fingerprintBeforePromotion',
        );
      }
    } else if (existsBeforePromotion) {
      throw _destinationChanged(
        plan.configuration.outputMapPath,
        'A new output appeared after the build started.',
      );
    }
  }

  _EudBuildFailure _destinationChanged(String path, String rawDetails) {
    return _EudBuildFailure(
      _diagnostic(
        code: EudBuildPipelineDiagnosticCodes.destinationChanged,
        message:
            'The EUD output changed while the map was being built, so the '
            'temporary output was not promoted.',
        filePath: path,
        remediation: 'Review the other program using the output and rebuild.',
        rawDetails: rawDetails,
      ),
      exitCode: 0,
    );
  }

  EditorDiagnostic _diagnostic({
    required String code,
    required String message,
    required String remediation,
    String? filePath,
    String? rawDetails,
  }) {
    return EditorDiagnostic(
      code: code,
      message: message,
      severity: DiagnosticSeverity.error,
      stage: DiagnosticStage.compile,
      filePath: filePath,
      remediation: remediation,
      rawDetails: rawDetails,
    );
  }
}

final class _EudBuildFailure implements Exception {
  _EudBuildFailure(
    this.diagnostic, {
    Iterable<EditorDiagnostic> diagnostics = const [],
    this.exitCode,
  }) : diagnostics = List.unmodifiable(diagnostics);

  final EditorDiagnostic diagnostic;
  final List<EditorDiagnostic> diagnostics;
  final int? exitCode;
}
