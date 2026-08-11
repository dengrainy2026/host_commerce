import 'dart:async';

enum StoreOperationOwner { host, h5 }

/// Serializes state-changing store operations and records who initiated them.
///
/// The platform purchase stream is process-wide. Keeping one operation owner
/// active at a time prevents a native-host action from being observed as an H5
/// action, or an H5 action from changing native-host commerce state.
final class StoreOperationCoordinator {
  Future<void> _tail = Future<void>.value();
  StoreOperationOwner? _activeOwner;

  StoreOperationOwner? get activeOwner => _activeOwner;

  Future<T> run<T>(
    StoreOperationOwner owner,
    Future<T> Function() operation,
  ) async {
    final Completer<void> turn = Completer<void>();
    final Future<void> previous = _tail;
    _tail = turn.future;
    await previous;
    _activeOwner = owner;
    try {
      return await operation();
    } finally {
      _activeOwner = null;
      turn.complete();
    }
  }
}
