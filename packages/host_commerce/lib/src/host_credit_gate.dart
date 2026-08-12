import 'dart:async';

import 'host_commerce_repository.dart';

enum HostCreditGateStatus { completed, insufficientCredits }

final class HostCreditGateResult<T> {
  const HostCreditGateResult._({required this.status, this.value});

  const HostCreditGateResult.completed(T value)
    : this._(status: HostCreditGateStatus.completed, value: value);

  const HostCreditGateResult.insufficientCredits()
    : this._(status: HostCreditGateStatus.insufficientCredits);

  final HostCreditGateStatus status;
  final T? value;

  bool get isCompleted => status == HostCreditGateStatus.completed;
}

/// Serializes paid Native Tool executions and charges only successful work.
///
/// Tool failures are rethrown without consuming credits. Keeping the complete
/// check/run/charge sequence in one queue also prevents concurrent taps from
/// overspending the same balance.
final class HostCreditGate {
  HostCreditGate(this._commerceRepository);

  final HostCommerceRepository _commerceRepository;
  Future<void> _tail = Future<void>.value();

  Future<HostCreditGateResult<T>> run<T>(
    Future<T> Function() operation, {
    int? cost,
  }) {
    final Completer<HostCreditGateResult<T>> result =
        Completer<HostCreditGateResult<T>>();
    _tail = _tail
        .then((_) async {
          try {
            await _commerceRepository.refresh();
            final int effectiveCost =
                cost ?? _commerceRepository.rules.creationCost;
            if (effectiveCost <= 0) {
              throw ArgumentError.value(
                effectiveCost,
                'cost',
                'Must be positive.',
              );
            }
            if (_commerceRepository.state.creditBalance < effectiveCost) {
              result.complete(HostCreditGateResult<T>.insufficientCredits());
              return;
            }
            final T value = await operation();
            final bool consumed = await _commerceRepository.consumeCredits(
              effectiveCost,
            );
            if (!consumed) {
              throw StateError(
                'Credits changed before the tool charge completed.',
              );
            }
            result.complete(HostCreditGateResult<T>.completed(value));
          } on Object catch (error, stackTrace) {
            result.completeError(error, stackTrace);
          }
        })
        .catchError((Object _, StackTrace _) {
          // Each operation reports through its own completer; keep the queue alive.
        });
    return result.future;
  }
}
