import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

void showCommerceFailure(
  BuildContext context, {
  required String operation,
  required Object error,
  StackTrace? stackTrace,
}) {
  if (!kReleaseMode) {
    debugPrint('[host_commerce] $operation failed: $error');
    if (stackTrace != null) {
      debugPrintStack(stackTrace: stackTrace);
    }
  }
  final String message = kReleaseMode
      ? '$operation could not be completed. Please try again.'
      : '$operation failed: $error';
  ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(
      SnackBar(
        behavior: SnackBarBehavior.floating,
        duration: kReleaseMode
            ? const Duration(seconds: 4)
            : const Duration(seconds: 10),
        content: Text(message),
      ),
    );
}
