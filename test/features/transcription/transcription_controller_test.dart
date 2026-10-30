import 'package:bisindo_app/features/transcription/data/speech_service.dart';
import 'package:bisindo_app/features/transcription/presentation/transcription_controller.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

class FakeSpeechService implements SpeechService {
  MicPermission status = MicPermission.denied;
  MicPermission afterRequest = MicPermission.granted;
  bool available = true;
  bool indonesian = true;
  int listenCalls = 0;
  int cancelCalls = 0;
  bool? lastUseIndonesian;
  void Function(String, bool)? onResult;
  void Function(String, bool)? onError;
  void Function(String)? onStatus;

  @override
  Future<MicPermission> permissionStatus() async => status;
  @override
  Future<MicPermission> requestPermission() async => status = afterRequest;
  @override
  Future<bool> openSettings() async => true;
  @override
  Future<bool> initialize({
    required void Function(String errorCode, bool permanent) onError,
    required void Function(String status) onStatus,
  }) async {
    this.onError = onError;
    this.onStatus = onStatus;
    return available;
  }

  @override
  Future<bool> supportsIndonesian() async => indonesian;
  @override
  Future<void> listen({
    required void Function(String words, bool isFinal) onResult,
    required bool useIndonesian,
  }) async {
    listenCalls++;
    lastUseIndonesian = useIndonesian;
    this.onResult = onResult;
    onStatus?.call('listening');
  }

  @override
  Future<void> stop() async => onStatus?.call('notListening');
  @override
  Future<void> cancel() async => cancelCalls++;
}

/// STT-01: transisi status controller dengan fake.
void main() {
  late FakeSpeechService speech;
  late ProviderContainer container;

  setUp(() {
    speech = FakeSpeechService();
    container = ProviderContainer(
      retry: (retryCount, error) => null,
      overrides: [speechServiceProvider.overrideWithValue(speech)],
    );
  });
  tearDown(() => container.dispose());

  TranscriptionController controller() {
    container.listen(transcriptionControllerProvider, (prev, next) {});
    return container.read(transcriptionControllerProvider.notifier);
  }

  TranscriptionState state() => container.read(transcriptionControllerProvider);

  Future<bool> yes() async => true;
  Future<bool> no() async => false;

  test(
    'idle → (penjelasan izin) → listening → hasil sementara → final → stopped',
    () async {
      final c = controller();
      var explained = false;
      await c.start(
        explainPermission: () async => explained = true,
        askFallback: no,
      );
      expect(explained, isTrue);
      expect(state().status, SttStatus.listening);
      expect(speech.lastUseIndonesian, isTrue);

      speech.onResult!('halo apa', false);
      expect(state().partial, 'halo apa');
      expect(state().text, '');

      await c.stop();
      speech.onResult!('halo apa kabar', true);
      expect(state().text, 'halo apa kabar');
      expect(state().partial, '');
      expect(state().status, SttStatus.stopped);

      // Sesi kedua menyambung teks.
      await c.start(explainPermission: yes, askFallback: no);
      speech.onResult!('baik', true);
      expect(state().text, 'halo apa kabar baik');
    },
  );

  test('izin ditolak permanen → error dengan aksi pengaturan', () async {
    speech.afterRequest = MicPermission.permanentlyDenied;
    final c = controller();
    await c.start(explainPermission: yes, askFallback: no);
    expect(state().status, SttStatus.error);
    expect(state().error, SttError.permissionPermanentlyDenied);
    expect(speech.listenCalls, 0);
  });

  test('pengguna membatalkan penjelasan izin → tidak meminta izin', () async {
    final c = controller();
    await c.start(explainPermission: no, askFallback: no);
    expect(state().status, SttStatus.idle);
    expect(speech.status, MicPermission.denied);
  });

  test('layanan tidak tersedia', () async {
    speech.status = MicPermission.granted;
    speech.available = false;
    final c = controller();
    await c.start(explainPermission: yes, askFallback: no);
    expect(state().error, SttError.unavailable);
  });

  test('id_ID tidak ada: fallback hanya jika pengguna setuju', () async {
    speech.status = MicPermission.granted;
    speech.indonesian = false;
    final c = controller();
    await c.start(explainPermission: yes, askFallback: no);
    expect(state().error, SttError.languageUnavailable);
    expect(speech.listenCalls, 0);

    await c.start(explainPermission: yes, askFallback: yes);
    expect(state().status, SttStatus.listening);
    expect(state().usingFallbackLocale, isTrue);
    expect(speech.lastUseIndonesian, isFalse);
  });

  test(
    'error_no_match & error_network dipetakan; ke latar → berhenti',
    () async {
      speech.status = MicPermission.granted;
      final c = controller();
      await c.start(explainPermission: yes, askFallback: no);
      speech.onError!('error_no_match', false);
      expect(state().error, SttError.noMatch);
      expect(
        sttErrorMessage(SttError.noMatch),
        'Suara tidak terdengar jelas. Coba lagi.',
      );
      expect(mapSpeechError('error_network'), SttError.network);

      await c.start(explainPermission: yes, askFallback: no);
      await c.pause();
      expect(state().status, SttStatus.stopped);
      expect(speech.cancelCalls, greaterThan(0));
    },
  );

  test(
    'salin/hapus: clear mengosongkan teks; dispose membatalkan mikrofon',
    () async {
      speech.status = MicPermission.granted;
      final c = controller();
      c.setText('teks');
      expect(state().text, 'teks');
      c.clear();
      expect(state().text, '');
      final before = speech.cancelCalls;
      container.dispose();
      expect(speech.cancelCalls, before + 1);
      container = ProviderContainer();
    },
  );
}
