import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:host_commerce/host_commerce.dart';

void main() {
  test('successful tool work consumes the configured cost', () async {
    final HostCommerceRepository commerce = HostCommerceRepository(
      MemoryHostCommerceStore(),
      scheduleBoundaryTimers: false,
    );
    await commerce.initialize();
    final HostCreditGate gate = HostCreditGate(commerce);

    final HostCreditGateResult<String> result = await gate.run(
      () async => 'output',
    );

    expect(result.isCompleted, isTrue);
    expect(result.value, 'output');
    expect(commerce.state.creditBalance, 0);
  });

  test('failed tool work does not consume credits', () async {
    final HostCommerceRepository commerce = HostCommerceRepository(
      MemoryHostCommerceStore(),
      scheduleBoundaryTimers: false,
    );
    await commerce.initialize();
    final HostCreditGate gate = HostCreditGate(commerce);

    await expectLater(
      gate.run<void>(() => Future<void>.error(StateError('tool failed'))),
      throwsA(isA<StateError>()),
    );
    expect(commerce.state.creditBalance, 100);
  });

  test('concurrent work cannot overspend one balance', () async {
    final HostCommerceRepository commerce = HostCommerceRepository(
      MemoryHostCommerceStore(),
      scheduleBoundaryTimers: false,
    );
    await commerce.initialize();
    final HostCreditGate gate = HostCreditGate(commerce);
    final Completer<void> release = Completer<void>();

    final Future<HostCreditGateResult<void>> first = gate.run(
      () => release.future,
    );
    final Future<HostCreditGateResult<void>> second = gate.run(() async {});
    release.complete();

    expect((await first).status, HostCreditGateStatus.completed);
    expect((await second).status, HostCreditGateStatus.insufficientCredits);
    expect(commerce.state.creditBalance, 0);
  });
}
