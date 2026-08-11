import 'dart:convert';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import 'host_commerce_state.dart';
import 'permanent_host_mode.dart';

/// Persistence boundary for [HostCommerceState].
abstract interface class HostCommerceStore implements PermanentHostModeChecking {
  Future<HostCommerceState> read();

  Future<void> write(HostCommerceState state);

  Future<void> clear();
}

final class SecureHostCommerceStore implements HostCommerceStore {
  SecureHostCommerceStore({
    FlutterSecureStorage? storage,
    this.stateKey = defaultStateKey,
  }) : _storage = storage ?? const FlutterSecureStorage();

  static const String defaultStateKey = 'host_commerce.state.v1';
  final String stateKey;
  final FlutterSecureStorage _storage;

  @override
  Future<HostCommerceState> read() async {
    final String? encoded = await _storage.read(key: stateKey);
    if (encoded == null || encoded.isEmpty) {
      return const HostCommerceState();
    }
    try {
      final Object? decoded = jsonDecode(encoded);
      if (decoded is! Map) {
        return const HostCommerceState();
      }
      return HostCommerceState.fromJson(Map<String, Object?>.from(decoded));
    } on Object {
      return const HostCommerceState();
    }
  }

  @override
  Future<void> write(HostCommerceState state) {
    return _storage.write(key: stateKey, value: jsonEncode(state.toJson()));
  }

  @override
  Future<void> clear() => _storage.delete(key: stateKey);

  @override
  Future<bool> isPermanentHostModeEnabled() async => (await read()).hasRedeemedCode;
}

final class MemoryHostCommerceStore implements HostCommerceStore {
  MemoryHostCommerceStore([this.state = const HostCommerceState()]);

  HostCommerceState state;

  @override
  Future<HostCommerceState> read() async => state;

  @override
  Future<void> write(HostCommerceState state) async => this.state = state;

  @override
  Future<void> clear() async => state = const HostCommerceState();

  @override
  Future<bool> isPermanentHostModeEnabled() async => state.hasRedeemedCode;
}
