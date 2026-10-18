import 'dart:async';
import 'dart:isolate';
import '../../application/ports/trigger_script_gateway.dart';
import '../../domain/chk/raw_chk_document.dart';
import '../../domain/triggers/trigger_script.dart';

/// No Python/Lua/epScript execution. The bounded declaration parser runs in a
/// killable Dart isolate so closing/changing a draft does not block the editor.
final class IsolateTriggerScriptGateway implements TriggerScriptGateway {
  IsolateTriggerScriptGateway({this.timeout = const Duration(seconds: 5)});
  final Duration timeout;
  final _jobs = <String, _ScriptJob>{};
  @override
  Future<TriggerScriptAnalysis> analyze({
    required String operationId,
    required RawChkDocument document,
    required TriggerScriptLanguage language,
    String? source,
    TriggerScriptLanguage? target,
  }) async {
    if (_jobs.containsKey(operationId)) throw StateError('SCRIPT_OPERATION_ID');
    final job = _ScriptJob();
    _jobs[operationId] = job;
    job.subscription = job.port.listen((message) {
      if (message is TriggerScriptAnalysis) {
        job.finish(message);
      } else {
        job.finish(
          const TriggerScriptAnalysis(
            diagnostic: TriggerScriptDiagnostic('SCRIPT_WORKER_FAILED', 0),
          ),
        );
      }
    });
    job.timer = Timer(
      timeout,
      () => job.finish(
        const TriggerScriptAnalysis(
          diagnostic: TriggerScriptDiagnostic('SCRIPT_TIMEOUT', 0),
        ),
      ),
    );
    try {
      final isolate = await Isolate.spawn(_analyze, (
        job.port.sendPort,
        document,
        source,
        language,
        target ?? language,
      ), onError: job.port.sendPort);
      job.isolate = isolate;
      if (job.result.isCompleted) isolate.kill(priority: Isolate.immediate);
      return await job.result.future;
    } on Object {
      job.finish(
        const TriggerScriptAnalysis(
          diagnostic: TriggerScriptDiagnostic('SCRIPT_WORKER_FAILED', 0),
        ),
      );
      return await job.result.future;
    } finally {
      _jobs.remove(operationId);
      job.dispose();
    }
  }

  @override
  void cancel(String operationId) => _jobs[operationId]?.finish(
    const TriggerScriptAnalysis(
      diagnostic: TriggerScriptDiagnostic('SCRIPT_CANCELLED', 0),
    ),
  );
}

void _analyze(
  (
    SendPort,
    RawChkDocument,
    String?,
    TriggerScriptLanguage,
    TriggerScriptLanguage,
  )
  request,
) {
  try {
    final snapshot = TriggerScriptSnapshot(request.$2);
    final program = request.$3 == null
        ? snapshot.initial
        : snapshot.parse(request.$3!, request.$4);
    final output = snapshot.format(program, request.$5);
    if (!program.sameMeaning(snapshot.parse(output, request.$5))) {
      throw const TriggerScriptDiagnostic('SCRIPT_EQUIVALENCE', 0);
    }
    request.$1.send(TriggerScriptAnalysis(program: program, generated: output));
  } on TriggerScriptDiagnostic catch (e) {
    request.$1.send(TriggerScriptAnalysis(diagnostic: e));
  } on FormatException catch (e) {
    request.$1.send(
      TriggerScriptAnalysis(
        diagnostic: TriggerScriptDiagnostic('SCRIPT_MAP_FORMAT', 0, e.message),
      ),
    );
  } on Object {
    request.$1.send(
      const TriggerScriptAnalysis(
        diagnostic: TriggerScriptDiagnostic('SCRIPT_WORKER_FAILED', 0),
      ),
    );
  }
}

final class _ScriptJob {
  final port = ReceivePort();
  final result = Completer<TriggerScriptAnalysis>();
  StreamSubscription<Object?>? subscription;
  Timer? timer;
  Isolate? isolate;
  void finish(TriggerScriptAnalysis value) {
    if (result.isCompleted) return;
    result.complete(value);
    dispose();
  }

  void dispose() {
    timer?.cancel();
    unawaited(subscription?.cancel());
    port.close();
    isolate?.kill(priority: Isolate.immediate);
  }
}
