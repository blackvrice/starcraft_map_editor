import 'package:flutter_test/flutter_test.dart';
import 'package:starcraft_map_editor/application/operations/operation_progress.dart';
import 'package:starcraft_map_editor/application/operations/operation_progress_controller.dart';

void main() {
  test('publishes a complete operation lifecycle', () async {
    final controller = OperationProgressController();
    final phases = <OperationPhase>[];
    final subscription = controller.changes.listen((progress) {
      if (progress != null) {
        phases.add(progress.phase);
      }
    });

    controller.start(
      operationId: 'open-map',
      label: 'Opening map',
      canCancel: true,
    );
    controller.update(
      operationId: 'open-map',
      phase: OperationPhase.reading,
      message: 'Reading archive',
      fraction: 0.25,
    );
    controller.succeed(operationId: 'open-map', message: 'Map opened');

    expect(phases, [
      OperationPhase.queued,
      OperationPhase.reading,
      OperationPhase.succeeded,
    ]);
    expect(controller.current?.isTerminal, isTrue);
    expect(controller.current?.fraction, 1);
    expect(controller.current?.canCancel, isFalse);

    await subscription.cancel();
    await controller.dispose();
  });

  test('rejects overlapping operations', () async {
    final controller = OperationProgressController()
      ..start(operationId: 'first', label: 'First operation');

    expect(
      () => controller.start(operationId: 'second', label: 'Second operation'),
      throwsStateError,
    );

    controller.cancel(operationId: 'first');
    controller.clear();
    expect(controller.current, isNull);

    await controller.dispose();
  });
}
