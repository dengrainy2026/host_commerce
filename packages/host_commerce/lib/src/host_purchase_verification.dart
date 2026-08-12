import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:in_app_purchase/in_app_purchase.dart';

enum HostPurchaseKind { subscription, credits }

/// Receipt/token evidence sent to an app-owned verification backend.
@immutable
final class HostPurchaseEvidence {
  const HostPurchaseEvidence({
    required this.productId,
    required this.transactionId,
    required this.platform,
    required this.receipt,
    required this.kind,
    required this.restored,
    this.expectedCredits,
  });

  final String productId;
  final String transactionId;
  final String platform;
  final String receipt;
  final HostPurchaseKind kind;
  final bool restored;
  final int? expectedCredits;
}

/// Backend truth for one verified native purchase.
@immutable
final class HostVerifiedPurchase {
  const HostVerifiedPurchase({
    required this.productId,
    required this.transactionId,
    required this.kind,
    this.creditsGranted,
    this.membershipExpiresAt,
  });

  final String productId;
  final String transactionId;
  final HostPurchaseKind kind;
  final int? creditsGranted;
  final DateTime? membershipExpiresAt;
}

abstract interface class HostPurchaseVerifier {
  Future<HostVerifiedPurchase> verify(HostPurchaseEvidence evidence);
}

/// Safe default used when a host has not supplied production verification.
final class RejectingHostPurchaseVerifier implements HostPurchaseVerifier {
  const RejectingHostPurchaseVerifier();

  @override
  Future<HostVerifiedPurchase> verify(HostPurchaseEvidence evidence) {
    return Future<HostVerifiedPurchase>.error(
      StateError('Native purchase verification is not configured.'),
    );
  }
}

/// Strict HTTPS verifier shared by generated Native Host applications.
///
/// The response must bind the result to the submitted product and transaction
/// identifiers. Consumables must return `creditsGranted`; subscriptions must
/// return a future `membershipExpiresAt` timestamp.
final class HttpHostPurchaseVerifier implements HostPurchaseVerifier {
  HttpHostPurchaseVerifier(this.endpoint, {http.Client? client})
    : _client = client ?? http.Client();

  final Uri endpoint;
  final http.Client _client;

  @override
  Future<HostVerifiedPurchase> verify(HostPurchaseEvidence evidence) async {
    if (endpoint.scheme != 'https' || endpoint.host.isEmpty) {
      throw StateError('Purchase verification requires an HTTPS endpoint.');
    }
    final http.Response response = await _client
        .post(
          endpoint,
          headers: const <String, String>{'content-type': 'application/json'},
          body: jsonEncode(<String, Object?>{
            'productId': evidence.productId,
            'transactionId': evidence.transactionId,
            'platform': evidence.platform,
            'receipt': evidence.receipt,
            'kind': evidence.kind.name,
            'restored': evidence.restored,
          }),
        )
        .timeout(const Duration(seconds: 20));
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw StateError('The purchase could not be verified.');
    }
    final Object? decoded = jsonDecode(response.body);
    if (decoded is! Map || decoded['verified'] != true) {
      throw StateError('The purchase was not verified.');
    }
    final Map<String, Object?> payload = Map<String, Object?>.from(decoded);
    if (payload['productId'] != evidence.productId ||
        payload['transactionId'] != evidence.transactionId) {
      throw const FormatException(
        'Verified purchase identifiers do not match the request.',
      );
    }
    final HostPurchaseKind kind = _parseKind(payload['kind']);
    if (kind != evidence.kind) {
      throw const FormatException('Verified purchase kind does not match.');
    }
    final int? credits = payload['creditsGranted'] as int?;
    final DateTime? expiresAt = _parseTimestamp(payload['membershipExpiresAt']);
    if (kind == HostPurchaseKind.credits &&
        (credits == null ||
            credits <= 0 ||
            credits != evidence.expectedCredits)) {
      throw const FormatException('Invalid verified credit grant.');
    }
    if (kind == HostPurchaseKind.subscription &&
        (expiresAt == null || !expiresAt.isAfter(DateTime.now().toUtc()))) {
      throw const FormatException('Verified membership is not active.');
    }
    return HostVerifiedPurchase(
      productId: evidence.productId,
      transactionId: evidence.transactionId,
      kind: kind,
      creditsGranted: credits,
      membershipExpiresAt: expiresAt,
    );
  }

  static HostPurchaseKind _parseKind(Object? value) => switch (value) {
    'subscription' => HostPurchaseKind.subscription,
    'credits' || 'consumable' => HostPurchaseKind.credits,
    _ => throw const FormatException('Invalid verified purchase kind.'),
  };

  static DateTime? _parseTimestamp(Object? value) {
    if (value == null) {
      return null;
    }
    if (value is! String) {
      throw const FormatException('Invalid membership expiration timestamp.');
    }
    return DateTime.parse(value).toUtc();
  }
}

abstract interface class HostVerifiedCommerceReporter {
  Future<void> report(
    HostVerifiedPurchase purchase, {
    required bool restored,
    required PurchaseDetails storePurchase,
    ProductDetails? storeProduct,
  });
}

final class NoopHostVerifiedCommerceReporter
    implements HostVerifiedCommerceReporter {
  const NoopHostVerifiedCommerceReporter();

  @override
  Future<void> report(
    HostVerifiedPurchase purchase, {
    required bool restored,
    required PurchaseDetails storePurchase,
    ProductDetails? storeProduct,
  }) async {}
}
