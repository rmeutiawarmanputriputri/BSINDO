# FLUTTER_ARCHITECTURE — BISINDO

> Versi paket **tidak dipatok** di sini. Claude Work memakai versi stabil terbaru yang kompatibel dengan Flutter SDK terpasang (`flutter pub add`), membaca changelog paket utama (Riverpod, go_router, supabase_flutter, speech_to_text, video_player) karena API dapat berubah, dan melaporkan versi yang dipakai.

## 1. Keputusan

| Area | Pilihan | Alasan |
|---|---|---|
| State | `flutter_riverpod` (tanpa codegen, `AsyncNotifier`/`Notifier`/`FutureProvider`/`StreamProvider`) | Testable, `AsyncValue` untuk loading/error/data, tanpa `build_runner` |
| Routing | `go_router` + `ShellRoute`/`StatefulShellRoute` untuk tab bawah | Redirect sesi/role, deep link |
| Arsitektur | Feature-first; `data` / `domain` / `presentation` | Memisahkan UI, logika, akses DB |
| Model | Kelas Dart immutable manual (`fromJson`/`copyWith`) | Hindari codegen (`freezed`) di MVP |
| Backend client | `supabase_flutter` dibungkus repository | Tidak ada panggilan Supabase dari widget |
| Error | Hierarki `AppFailure` (sealed) dipetakan di repository | UI hanya melihat error yang bermakna |

Satu pendekatan konsisten; tidak ada Bloc/GetX/Provider campuran. Tidak menambah dependensi tanpa alasan tertulis.

## 2. Dependensi

| Paket | Tujuan |
|---|---|
| `supabase_flutter` | Auth, DB, Storage, deep link auth |
| `flutter_riverpod` | State & DI |
| `go_router` | Routing |
| `video_player` | Pemutaran video (kontrol kustom: play/pause/loop/kecepatan) |
| `speech_to_text` | STT Android |
| `cached_network_image` | Cache thumbnail (signed URL berubah → gunakan `cacheKey` = path) |
| `flutter_svg` | Logo/ikon vektor |
| `file_picker` | Admin memilih video/gambar |
| `shared_preferences` | Preferensi ringan (bila perlu) |
| `intl` | Format tanggal Indonesia |
| dev: `flutter_lints`, `flutter_test`, `mocktail`, `flutter_native_splash` | Lint, tes, splash |

Ditunda: `connectivity_plus` (deteksi online dikerjakan lewat penanganan error), `freezed`, `drift/hive` (tanpa mode offline), `google_sign_in` (K-03). Putuskan sebelum menambah paket lain dan catat di laporan.

## 3. Struktur proyek

```
lib/
  main.dart                      // bootstrap: Supabase.initialize, ProviderScope
  app/
    app.dart                     // MaterialApp.router
    router/ (app_router.dart, routes.dart, guards.dart)
    config/ (env.dart)           // String.fromEnvironment
    theme/ (tokens.dart, app_theme.dart, text_theme.dart)
  core/
    errors/ (app_failure.dart, failure_mapper.dart)
    supabase/ (supabase_providers.dart, signed_url_cache.dart)
    widgets/ (app_button.dart, app_text_field.dart, state_views.dart, ...)
    utils/ (validators.dart, debouncer.dart, sanitize_search.dart)
    responsive/ (breakpoints.dart)
  features/
    auth/          {data/auth_repository.dart, domain/app_user.dart, presentation/(screens, widgets, controllers)}
    home/
    dictionary/    {data/sign_repository.dart, domain/sign.dart, ...}
    video/         // VideoPlayerView + controller
    conversation/
    transcription/ // STT controller + screen
    difficult_vocab/
    favorites/
    reports/
    learning/      // lessons, quiz, progress
    profile/
    admin/
assets/ (brand/, fonts/)
env/ (example.json)              // dev.json/prod.json di-.gitignore
supabase/ (migrations/, seed/, tests/)
test/ (mirror lib/), integration_test/
docs/ (design/reference/, planning docs)
```

## 4. Aturan lapisan

- `presentation` → membaca provider; tidak mengimpor `supabase_flutter` (kecuali tipe auth di `auth`).
- `data` (repository) → satu-satunya tempat memanggil Supabase; mengembalikan model domain; menerjemahkan exception → `AppFailure`.
- `domain` → model murni Dart.
- Repository diekspos lewat `Provider` sehingga tes dapat `override` dengan fake.
- Tidak ada logika bisnis di widget `build`.

## 5. Pola state (contoh bentuk)

```dart
// data
class SignRepository {
  SignRepository(this._db, this._urls);
  final SupabaseClient _db; final SignedUrlCache _urls;
  Future<List<Sign>> search({String? q, String? categoryId, int page = 0}) async { /* .from('signs').select(...).eq('status','published') ... range() */ }
}
final signRepositoryProvider = Provider((ref) => SignRepository(ref.watch(supabaseClientProvider), ref.watch(signedUrlCacheProvider)));

// presentation
final dictionaryQueryProvider = StateProvider<DictionaryQuery>((_) => const DictionaryQuery());
final dictionaryResultsProvider = FutureProvider.autoDispose((ref) {
  final q = ref.watch(dictionaryQueryProvider);
  return ref.watch(signRepositoryProvider).search(q: q.text, categoryId: q.categoryId);
});
```
Widget: `ref.watch(...).when(loading, error: ErrorView(onRetry: () => ref.invalidate(...)), data: …)`. Daftar kosong → `EmptyView`. Debounce 350 ms di controller input, bukan di widget `build`. Ingat: filter `status = 'published'` **eksplisit** pada repository sisi pengguna.

## 6. Routing & guard

| Rute | Layar | Guard |
|---|---|---|
| `/splash` | S01 | — |
| `/login`, `/register`, `/forgot-password`, `/verify-email`, `/reset-password` | S02–S06 | hanya tamu (kecuali reset: sesi recovery) |
| `/home`, `/dictionary`, `/conversations`, `/learn`, `/profile` | tab | login |
| `/dictionary/sign/:id`, `/conversations/:id`, `/learn/:id`, `/learn/:id/quiz`, `/learn/progress`, `/transcribe`, `/favorites`, `/difficult`, `/difficult/review/:signId`, `/report/new`, `/reports` | detail | login |
| `/admin`, `/admin/:entity`, `/admin/reports` | S25–S27 | login **dan** `role == admin` (UI); RLS di backend |

`GoRouter(refreshListenable: authState)`: redirect → `/login` bila tak ada sesi; `/home` bila sudah login di rute tamu; `passwordRecovery` → `/reset-password`. Rute tak dikenal → halaman 404 ramah. Parameter ID divalidasi UUID.

## 7. Sesi, error, loading, lifecycle

- `supabase_flutter` menyimpan & menyegarkan sesi otomatis; `authStateProvider` (stream `onAuthStateChange`) memandu router. Saat `signedOut`: `ref.invalidate` semua provider data pengguna.
- Profil (nama, role) di-cache di `currentProfileProvider`; role dipakai hanya untuk menampilkan menu admin.
- `AppFailure`: `NetworkFailure`, `AuthFailure(code)`, `PermissionFailure` (RLS 401/403/`42501`), `NotFoundFailure`, `ValidationFailure`, `RateLimitFailure`, `UnknownFailure`. Pesan pengguna dari satu `failure_message.dart` (Indonesia). Detail teknis hanya `debugPrint` (tanpa PII, tanpa transkrip).
- Timeout permintaan (mis. 15 s) → `NetworkFailure`.
- Lifecycle: `dispose` `VideoPlayerController`, `TextEditingController`, `Timer`; `ref.onDispose` untuk sesi STT; cek `mounted` setelah `await` sebelum memakai `context`; `autoDispose` untuk provider layar.
- Tidak ada `print` sensitif; log email/sandi dilarang.

## 8. Konvensi data

- **Signed URL:** `SignedUrlCache` menyimpan `path → (url, expiresAt)`; ambil ulang bila sisa < 10 menit; `invalidate(path)` saat gagal putar. TTL 2 jam.
- **Query:** `select` hanya kolom diperlukan; relasi media lewat join `media_assets!video_asset_id(path,duration_ms,...)`; pagination `range(from, to)`; urut `term_normalized`.
- **Pencarian:** `ilike('term_normalized', '%${escape(q)}%')`; `escape` menangani `%`, `_`, `\`; panjang maksimum 80.
- **Optimistic update** untuk favorit/tandai sulit dengan rollback.
- **Upsert** `difficult_vocabulary` memakai `onConflict: 'user_id,sign_id'`.
- **Kuis:** panggil `rpc('submit_quiz_attempt', params: {...})`; jangan pernah menghitung skor di klien.
- Tidak ada pemanggilan Storage list/upload dari aplikasi pengguna biasa.

## 9. Speech-to-text (D-08)

- Paket `speech_to_text`: inisialisasi sekali (`initialize` meminta izin mikrofon), cek `locales()` untuk `id_ID`, `listen(localeId: 'id_ID', listenOptions: partialResults true, …)`, `stop()` / `cancel()`.
- Kode error umum (verifikasi pada versi terpasang): `error_no_match`, `error_speech_timeout`, `error_permission`, `error_network`, `error_language_not_supported`, `error_busy`, `error_client`.
- **Fakta & batas yang harus dinyatakan jujur:** di Android, plugin memakai layanan pengenal ucapan sistem (umumnya Google). Pengenalan dapat memerlukan internet dan audio dapat diproses penyedia layanan perangkat; kemampuan offline bergantung paket bahasa yang terpasang. Sesi dapat berhenti sendiri setelah jeda diam → UI menyediakan tombol mulai lagi (dan boleh sambung otomatis dengan batas). Tidak tersedia di perangkat tanpa layanan pengenal ucapan. Emulator tidak dapat diandalkan → uji di perangkat nyata. Tidak ada biaya API/kunci dari sisi aplikasi (biaya/batas ditentukan penyedia sistem; **verifikasi** kebijakan terkini sebelum rilis).
- Alternatif jika kualitas `id_ID` tidak memadai (bukan MVP): model on-device (mis. Vosk), atau layanan cloud lewat Edge Function (membawa biaya, privasi, dan kunci server). Putuskan setelah uji perangkat.
- Privasi: tidak menyimpan audio; teks hanya di memori `Notifier` `autoDispose`; tidak di-log; tidak dikirim ke Supabase.
- Salin: `Clipboard.setData`. Edit: `TextField`. Hapus: kosongkan state.
- Hentikan sesi saat `AppLifecycleState.paused`.

## 10. Konfigurasi Android (periksa setelah scaffold)

`android/app/src/main/AndroidManifest.xml`:
```xml
<uses-permission android:name="android.permission.INTERNET"/>
<uses-permission android:name="android.permission.RECORD_AUDIO"/>
<queries>
  <intent><action android:name="android.speech.RecognitionService"/></intent>
</queries>
<!-- di <activity>: deep link auth -->
<intent-filter>
  <action android:name="android.intent.action.VIEW"/>
  <category android:name="android.intent.category.DEFAULT"/>
  <category android:name="android.intent.category.BROWSABLE"/>
  <data android:scheme="bisindo" android:host="auth-callback"/>
</intent-filter>
```
`applicationId` sementara `com.example.bisindo` (K-05). `minSdk` mengikuti syarat plugin tertinggi (K-07). Atur `usesCleartextTraffic` tetap default (false). Ikon launcher dari aset K-01.

## 11. Konfigurasi runtime

`lib/app/config/env.dart`: `String.fromEnvironment('SUPABASE_URL')`, `SUPABASE_ANON_KEY`; gagal cepat dengan layar error konfigurasi jelas bila kosong. Jalankan: `flutter run --dart-define-from-file=env/dev.json`; build: `flutter build apk --debug --dart-define-from-file=env/dev.json`. `env/example.json` berisi kunci kosong.

## 12. Strategi pengujian (ringkas; rinci di TEST_PLAN)

Unit: validator, mapper error, `SignedUrlCache`, sanitasi pencarian, controller STT dengan fake. Widget: Login/Register/field/state views dengan repository palsu (`ProviderScope(overrides)`). Integrasi: alur utama bila lingkungan mendukung. RLS/Storage diuji di database dev (bukan dari widget test).

## 13. Kualitas

`flutter_lints` aktif; `flutter analyze` harus bersih (0 error; peringatan dijelaskan). Format `dart format`. Nama berkas `snake_case`; satu widget publik utama per berkas. Tanpa `!` berlebihan; null-safety ketat. Teks UI di satu tempat per fitur agar mudah dilokalkan nanti (tanpa `intl` ARB di MVP).
