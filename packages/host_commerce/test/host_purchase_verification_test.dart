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

  test(
    'no-receipt host verifier resolves an allowlisted subscription',
    () async {
      final NoReceiptHostPurchaseVerifier verifier =
          NoReceiptHostPurchaseVerifier(
            const HostProductCatalog(
              weeklySubscriptionId: 'test.week',
              yearlySubscriptionId: 'test.year',
              creditProducts: <HostCreditProduct>[
                HostCreditProduct(productId: 'test.1000', credits: 1000),
              ],
            ),
            clock: () => DateTime.utc(2026, 1, 1),
          );

      final HostVerifiedPurchase purchase = await verifier.verify(
        const HostPurchaseEvidence(
          productId: 'test.week',
          transactionId: 'store-transaction-1',
          platform: 'app_store',
          receipt: 'ignored-by-host-mode',
          kind: HostPurchaseKind.subscription,
          restored: false,
        ),
      );

      expect(purchase.membershipExpiresAt, DateTime.utc(2026, 1, 8));
    },
  );

  test('no-receipt host verifier still rejects a catalog mismatch', () async {
    final NoReceiptHostPurchaseVerifier verifier =
        NoReceiptHostPurchaseVerifier(
          const HostProductCatalog(
            weeklySubscriptionId: 'test.week',
            yearlySubscriptionId: 'test.year',
            creditProducts: <HostCreditProduct>[
              HostCreditProduct(productId: 'test.1000', credits: 1000),
            ],
          ),
        );

    await expectLater(
      verifier.verify(
        const HostPurchaseEvidence(
          productId: 'test.1000',
          transactionId: 'store-transaction-2',
          platform: 'app_store',
          receipt: 'ignored-by-host-mode',
          kind: HostPurchaseKind.credits,
          restored: false,
          expectedCredits: 4000,
        ),
      ),
      throwsA(isA<StateError>()),
    );
  });
}
