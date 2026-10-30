/// Penanda materi contoh dev (DATABASE_SCHEMA §4). Murni Dart (tanpa Flutter)
/// agar model domain dapat diuji tanpa engine.
bool isSampleValidator(String? validatedBy) =>
    validatedBy != null && validatedBy.startsWith('DEV-SAMPLE');
