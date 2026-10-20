import '../../../../core/errors/app_failure.dart';

/// State aksi kirim form (loading / gagal / berhasil).
sealed class SubmitState<T> {
  const SubmitState();

  bool get isLoading => this is SubmitLoading<T>;
}

final class SubmitIdle<T> extends SubmitState<T> {
  const SubmitIdle();
}

final class SubmitLoading<T> extends SubmitState<T> {
  const SubmitLoading();
}

final class SubmitFailed<T> extends SubmitState<T> {
  const SubmitFailed(this.failure);
  final AppFailure failure;
}

final class SubmitSucceeded<T> extends SubmitState<T> {
  const SubmitSucceeded(this.value);
  final T value;
}
