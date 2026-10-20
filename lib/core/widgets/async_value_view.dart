import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'app_snackbar.dart';
import 'state_views.dart';

/// Menampilkan [AsyncValue] dengan pola 4 state (UI_UX §2): loading (skeleton),
/// error (pesan + "Coba Lagi"), data kosong ([isEmpty] → [empty]), dan data.
class AsyncValueView<T> extends StatelessWidget {
  const AsyncValueView({
    super.key,
    required this.value,
    required this.data,
    required this.onRetry,
    this.isEmpty,
    this.empty,
    this.loading,
  });

  final AsyncValue<T> value;
  final Widget Function(T data) data;
  final VoidCallback onRetry;
  final bool Function(T data)? isEmpty;
  final Widget? empty;
  final Widget? loading;

  @override
  Widget build(BuildContext context) {
    return value.when(
      skipLoadingOnRefresh: false,
      loading: () => loading ?? const LoadingView(),
      error: (error, _) =>
          ErrorView(message: errorMessageOf(error), onRetry: onRetry),
      data: (value) {
        if (empty != null && (isEmpty?.call(value) ?? false)) return empty!;
        return data(value);
      },
    );
  }
}
