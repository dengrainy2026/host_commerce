import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:host_commerce/host_commerce.dart';

void main() {
  test('host and H5 store behaviors retain exclusive ownership', () async {
    final StoreOperationCoordinator coordinator = StoreOperationCoordinator();
    final Completer<void> finishHost = Completer<void>();
    final List<StoreOperationOwner> started = <StoreOperationOwner>[];

    final Future<void> host = coordinator.run(StoreOperationOwner.host, () {
      started.add(coordinator.activeOwner!);
      return finishHost.future;
    });
    await Future<void>.delayed(Duration.zero);

    final Future<void> h5 = coordinator.run(StoreOperationOwner.h5, () async {
      started.add(coordinator.activeOwner!);
    });
    await Future<void>.delayed(Duration.zero);

    expect(started, <StoreOperationOwner>[StoreOperationOwner.host]);
    expect(coordinator.activeOwner, StoreOperationOwner.host);

    finishHost.complete();
    await Future.wait(<Future<void>>[host, h5]);

    expect(started, <StoreOperationOwner>[
      StoreOperationOwner.host,
      StoreOperationOwner.h5,
    ]);
    expect(coordinator.activeOwner, isNull);
  });
}
