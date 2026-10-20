import 'package:flutter/material.dart';

import '../errors/app_failure.dart';
import '../errors/failure_message.dart';

/// Pesan kesalahan ramah untuk objek error apa pun.
String errorMessageOf(Object error) =>
    error is AppFailure ? failureMessage(error) : 'Terjadi kesalahan. Coba lagi.';

/// Snackbar konsisten. [actionLabel] + [onAction] opsional (mis. "Urungkan").
void showAppSnackBar(
  BuildContext context,
  String message, {
  String? actionLabel,
  VoidCallback? onAction,
}) {
  final messenger = ScaffoldMessenger.maybeOf(context);
  if (messenger == null) return;
  messenger
    ..hideCurrentSnackBar()
    ..showSnackBar(
      SnackBar(
        content: Text(message),
        action: actionLabel != null && onAction != null
            ? SnackBarAction(label: actionLabel, onPressed: onAction)
            : null,
      ),
    );
}

void showErrorSnackBar(BuildContext context, Object error) =>
    showAppSnackBar(context, errorMessageOf(error));
