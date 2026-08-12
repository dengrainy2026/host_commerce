import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:host_commerce/host_commerce.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

void main() {
  const HostPurchaseEvidence creditsEvidence = HostPurchaseEvidence(
    productId: 'credits_1000',
    transactionId: 'transaction-1',
    platform: 'app_store',
    receipt: 'signed-receipt',
    kind: HostPurchaseKind.credits,
    restored: false,
    expectedCredits: 1000,
  );

  test(
    'HTTPS verifier binds a credit grant to the submitted evidence',
    () async {
      final HttpHostPurchaseVerifier verifier = HttpHostPurchaseVerifier(
        Uri.parse('https://commerce.example.com/verify'),
        client: MockClient((http.Request request) async {
          expect(request.method, 'POST');
          expect(request.headers['content-type'], 'application/json');
          expect(jsonDecode(request.body), <String, Object?>{
            'productId': 'credits_1000',
            'transactionId': 'transaction-1',
            'platform': 'app_store',
            'receipt': 'signed-receipt',
            'kind': 'credits',
            'restored': false,
          });
          return http.Response(
            jsonEncode(<String, Object?>{
              'verified': true,
              'productId': 'credits_1000',
              'transactionId': 'transaction-1',
              'kind': 'credits',
              'creditsGranted': 1000,
            }),
            200,
          );
        }),
      );

      final HostVerifiedPurchase purchase = await verifier.verify(
        creditsEvidence,
      );

      expect(purchase.creditsGranted, 1000);
      expect(purchase.transactionId, 'transaction-1');
    },
  );

  test('verifier rejects a grant for a different transaction', () async {
    final HttpHostPurchaseVerifier verifier = HttpHostPurchaseVerifier(
      Uri.parse('https://commerce.example.com/verify'),
      client: MockClient(
        (_) async => http.Response(
          jsonEncode(<String, Object?>{
            'verified': true,
            'productId': 'credits_1000',
            'transactionId': 'transaction-2',
            'kind': 'credits',
            'creditsGranted': 1000,
          }),
          200,
        ),
      ),
    );

    await expectLater(
      verifier.verify(creditsEvidence),
      throwsA(isA<FormatException>()),
    );
  });

  test('verifier rejects a catalog credit mismatch', () async {
    final HttpHostPurchaseVerifier verifier = HttpHostPurchaseVerifier(
      Uri.parse('https://commerce.example.com/verify'),
      client: MockClient(
        (_) async => http.Response(
          jsonEncode(<String, Object?>{
            'verified': true,
            'productId': 'credits_1000',
            'transactionId': 'transaction-1',
            'kind': 'credits',
            'creditsGranted': 4000,
          }),
          200,
        ),
      ),
    );

    await expectLater(
      verifier.verify(creditsEvidence),
      throwsA(isA<FormatException>()),
    );
  });

  test('verifier refuses a non-HTTPS endpoint', () async {
    final HttpHostPurchaseVerifier verifier = HttpHostPurchaseVerifier(
      Uri.parse('http://commerce.example.com/verify'),
      client: MockClient((_) async => http.Response('{}', 200)),
    );

    await expectLater(
      verifier.verify(creditsEvidence),
      throwsA(isA<StateError>()),
    );
  });
}
