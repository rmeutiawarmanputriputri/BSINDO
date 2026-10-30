# Rollback migrasi v1.1.0

Jalankan **berurutan dari nomor terbesar ke terkecil** (0120 → 0110), satu file per eksekusi,
setelah **mencadangkan database** (Supabase Dashboard → Database → Backups, atau `pg_dump`).
File bertanda ⚠️ menghapus data yang dibuat sesudah v1.1.0 (dijelaskan di kepala tiap file).
Rollback penuh telah diuji di PostgreSQL 16 lokal: skema kembali setara 0001–0010 dan
`tests/local/10_rls_tests.sql` lulus 30/30 (lihat `docs/TEST_REPORT_v1.1.0.md`).
