import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:speech_to_text/speech_recognition_error.dart';
import 'package:speech_to_text/speech_recognition_result.dart';
import 'package:speech_to_text/speech_to_text.dart';

/// Status izin mikrofon yang relevan bagi UI.
enum MicPermission { granted, denied, permanentlyDenied }

/// Abstraksi pengenal ucapan (D-08) agar controller dapat dites dengan fake.
abstract interface class SpeechService {
  Future<MicPermission> permissionStatus();
  Future<MicPermission> requestPermission();
  Future<bool> openSettings();

  /// `false` bila layanan pengenal ucapan tidak tersedia di perangkat.
  Future<bool> initialize({
    required void Function(String errorCode, bool permanent) onError,
    required void Function(String status) onStatus,
  });

  /// Apakah locale `id_ID` tersedia.
  Future<bool> supportsIndonesian();

  Future<void> listen({
    required void Function(String words, bool isFinal) onResult,
    required bool useIndonesian,
  });

  Future<void> stop();
  Future<void> cancel();
}

/// Implementasi dengan paket `speech_to_text` (SpeechRecognizer Android).
/// Audio diproses layanan pengenal ucapan perangkat; aplikasi TIDAK
/// menyimpan audio maupun teks.
class SpeechToTextService implements SpeechService {
  final SpeechToText _speech = SpeechToText();
  static const indonesianLocale = 'id_ID';

  static MicPermission _map(PermissionStatus status) {
    if (status.isGranted || status.isLimited) return MicPermission.granted;
    if (status.isPermanentlyDenied || status.isRestricted) {
      return MicPermission.permanentlyDenied;
    }
    return MicPermission.denied;
  }

  @override
  Future<MicPermission> permissionStatus() async =>
      _map(await Permission.microphone.status);

  @override
  Future<MicPermission> requestPermission() async =>
      _map(await Permission.microphone.request());

  @override
  Future<bool> openSettings() => openAppSettings();

  // `SpeechToText.initialize` hanya mendaftarkan listener pada panggilan
  // pertama (panggilan berikutnya langsung mengembalikan hasil lama). Karena
  // layanan ini hidup lebih lama dari controller (autoDispose), listener
  // diteruskan lewat field agar controller baru tetap menerima event.
  void Function(String errorCode, bool permanent)? _onError;
  void Function(String status)? _onStatus;

  @override
  Future<bool> initialize({
    required void Function(String errorCode, bool permanent) onError,
    required void Function(String status) onStatus,
  }) {
    _onError = onError;
    _onStatus = onStatus;
    return _speech.initialize(
      onError: (SpeechRecognitionError e) =>
          _onError?.call(e.errorMsg, e.permanent),
      onStatus: (String status) => _onStatus?.call(status),
    );
  }

  @override
  Future<bool> supportsIndonesian() async {
    final locales = await _speech.locales();
    return locales.any(
      (l) => l.localeId.replaceAll('-', '_').toLowerCase() == 'id_id',
    );
  }

  @override
  Future<void> listen({
    required void Function(String words, bool isFinal) onResult,
    required bool useIndonesian,
  }) async {
    await _speech.listen(
      onResult: (SpeechRecognitionResult r) =>
          onResult(r.recognizedWords, r.finalResult),
      localeId: useIndonesian ? indonesianLocale : null,
      listenFor: const Duration(minutes: 1),
      pauseFor: const Duration(seconds: 5),
      listenOptions: SpeechListenOptions(
        partialResults: true,
        cancelOnError: true,
        listenMode: ListenMode.dictation,
      ),
    );
  }

  @override
  Future<void> stop() => _speech.stop();

  @override
  Future<void> cancel() => _speech.cancel();
}

final speechServiceProvider = Provider<SpeechService>((ref) => SpeechToTextService());
