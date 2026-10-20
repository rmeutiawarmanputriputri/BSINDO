import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/speech_service.dart';

enum SttStatus { idle, listening, processing, stopped, error }

enum SttError {
  permissionDenied,
  permissionPermanentlyDenied,
  network,
  noMatch,
  unavailable,
  languageUnavailable,
  busy,
  other,
}

class TranscriptionState {
  const TranscriptionState({
    this.status = SttStatus.idle,
    this.text = '',
    this.partial = '',
    this.error,
    this.usingFallbackLocale = false,
  });

  final SttStatus status;

  /// Teks final (dapat diedit pengguna). Hanya di memori.
  final String text;

  /// Hasil sementara yang sedang dikenali.
  final String partial;
  final SttError? error;
  final bool usingFallbackLocale;

  bool get isListening => status == SttStatus.listening;

  TranscriptionState copyWith({
    SttStatus? status,
    String? text,
    String? partial,
    SttError? Function()? error,
    bool? usingFallbackLocale,
  }) =>
      TranscriptionState(
        status: status ?? this.status,
        text: text ?? this.text,
        partial: partial ?? this.partial,
        error: error != null ? error() : this.error,
        usingFallbackLocale: usingFallbackLocale ?? this.usingFallbackLocale,
      );
}

/// Mesin status transkripsi (STT-01). Privasi: teks hanya di state
/// autoDispose; tidak ditulis ke log, DB, atau penyimpanan.
class TranscriptionController extends Notifier<TranscriptionState> {
  bool _initialized = false;
  bool? _hasIndonesian;
  bool _allowFallback = false;

  late SpeechService _service;

  @override
  TranscriptionState build() {
    _service = ref.watch(speechServiceProvider);
    final service = _service;
    // Hentikan mikrofon saat layar ditutup (ref.read tidak boleh di onDispose).
    ref.onDispose(service.cancel);
    return const TranscriptionState();
  }

  /// Memulai mendengarkan.
  /// [explainPermission]: dialog penjelasan sebelum dialog izin sistem.
  /// [askFallback]: persetujuan memakai bahasa perangkat bila `id_ID` tidak ada.
  Future<void> start({
    required Future<bool> Function() explainPermission,
    required Future<bool> Function() askFallback,
  }) async {
    if (state.isListening || state.status == SttStatus.processing) return;

    var permission = await _service.permissionStatus();
    if (permission == MicPermission.denied) {
      final agreed = await explainPermission();
      if (!ref.mounted || !agreed) return;
      permission = await _service.requestPermission();
    }
    if (!ref.mounted) return;
    if (permission != MicPermission.granted) {
      _fail(permission == MicPermission.permanentlyDenied
          ? SttError.permissionPermanentlyDenied
          : SttError.permissionDenied);
      return;
    }

    if (!_initialized) {
      final available = await _service.initialize(
        onError: _onError,
        onStatus: _onStatus,
      );
      if (!ref.mounted) return;
      if (!available) {
        _fail(SttError.unavailable);
        return;
      }
      _initialized = true;
    }

    _hasIndonesian ??= await _service.supportsIndonesian();
    if (!ref.mounted) return;
    if (_hasIndonesian == false && !_allowFallback) {
      final agreed = await askFallback();
      if (!ref.mounted) return;
      if (!agreed) {
        _fail(SttError.languageUnavailable);
        return;
      }
      _allowFallback = true;
    }

    state = state.copyWith(
      status: SttStatus.listening,
      partial: '',
      error: () => null,
      usingFallbackLocale: _hasIndonesian == false,
    );
    try {
      await _service.listen(
        onResult: _onResult,
        useIndonesian: _hasIndonesian ?? false,
      );
    } catch (_) {
      if (ref.mounted) _fail(SttError.other);
    }
  }

  Future<void> stop() async {
    if (!state.isListening) return;
    state = state.copyWith(status: SttStatus.processing);
    await _service.stop();
  }

  /// Dipanggil saat aplikasi ke latar belakang.
  Future<void> pause() async {
    if (state.isListening || state.status == SttStatus.processing) {
      await _service.cancel();
      if (ref.mounted) {
        state = state.copyWith(status: SttStatus.stopped, partial: '');
      }
    }
  }

  void setText(String text) => state = state.copyWith(text: text);

  void clear() => state = state.copyWith(text: '', partial: '', error: () => null);

  Future<void> openSettings() => _service.openSettings();

  void _onResult(String words, bool isFinal) {
    if (!ref.mounted) return;
    if (isFinal) {
      final trimmed = words.trim();
      final joined = trimmed.isEmpty
          ? state.text
          : (state.text.isEmpty ? trimmed : '${state.text} $trimmed');
      state = state.copyWith(text: joined, partial: '', status: SttStatus.stopped);
    } else {
      state = state.copyWith(partial: words);
    }
  }

  void _onStatus(String status) {
    if (!ref.mounted) return;
    switch (status) {
      case 'listening':
        state = state.copyWith(status: SttStatus.listening);
      case 'notListening':
        if (state.isListening) state = state.copyWith(status: SttStatus.processing);
      case 'done':
        if (state.status != SttStatus.error) {
          state = state.copyWith(status: SttStatus.stopped, partial: '');
        }
    }
  }

  void _onError(String code, bool permanent) {
    if (!ref.mounted) return;
    _fail(mapSpeechError(code));
  }

  void _fail(SttError error) {
    state = state.copyWith(status: SttStatus.error, error: () => error, partial: '');
  }
}

/// Pemetaan kode error `speech_to_text` (FLUTTER_ARCHITECTURE §9).
SttError mapSpeechError(String code) => switch (code) {
      'error_no_match' || 'error_speech_timeout' => SttError.noMatch,
      'error_network' || 'error_network_timeout' || 'error_server' ||
      'error_server_disconnected' =>
        SttError.network,
      'error_permission' || 'error_insufficient_permissions' =>
        SttError.permissionDenied,
      'error_language_not_supported' || 'error_language_unavailable' =>
        SttError.languageUnavailable,
      'error_busy' || 'error_recognizer_busy' => SttError.busy,
      _ => SttError.other,
    };

/// Pesan pengguna (UI_UX §S13).
String sttErrorMessage(SttError error) => switch (error) {
      SttError.permissionDenied =>
        'Izin mikrofon ditolak. Izinkan mikrofon untuk memakai transkripsi.',
      SttError.permissionPermanentlyDenied =>
        'Izin mikrofon ditolak permanen. Buka Pengaturan untuk mengizinkannya.',
      SttError.network =>
        'Pengenalan suara membutuhkan koneksi pada perangkat ini.',
      SttError.noMatch => 'Suara tidak terdengar jelas. Coba lagi.',
      SttError.unavailable =>
        'Perangkat ini tidak mendukung pengenalan suara (layanan pengenal ucapan tidak tersedia).',
      SttError.languageUnavailable =>
        'Bahasa Indonesia tidak tersedia untuk pengenalan suara di perangkat ini.',
      SttError.busy => 'Pengenal suara sedang sibuk. Coba lagi sebentar lagi.',
      SttError.other => 'Terjadi kesalahan pada pengenalan suara. Coba lagi.',
    };

final transcriptionControllerProvider =
    NotifierProvider.autoDispose<TranscriptionController, TranscriptionState>(
  TranscriptionController.new,
);
