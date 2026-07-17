-- Fix: cron job 'expire-negotiations' set status='EXPIRED' (uppercase),
-- sementara seluruh kode aplikasi (Flutter + Edge Functions lain) cek
-- 'expired' (lowercase). Akibatnya guard di negotiations/index.ts
-- ("Negosiasi sudah selesai") gagal total untuk negosiasi yang sudah
-- expired via cron -- user masih bisa kirim pesan/aksi baru.
-- Ditemukan & dibuktikan di Sprint 10 QA (docs/qa/edge-case-checklist.md baris 3).
--
-- Catatan: migration ini SUDAH diterapkan ke remote (version 20260717044256)
-- lewat dashboard/MCP tanpa file-nya masuk repo, sehingga `supabase db push`
-- gagal ("Remote migration versions not found in local migrations directory").
-- File ini merekonstruksi isinya supaya riwayat lokal == remote.

-- 1. Perbaiki job supaya ke depan selalu set lowercase.
SELECT cron.alter_job(
  (SELECT jobid FROM cron.job WHERE jobname = 'expire-negotiations'),
  command => $cron$
  DO $job$
  DECLARE
    expired_count INT;
  BEGIN
    UPDATE negotiations
    SET status = 'expired'
    WHERE status IN ('open', 'countered')
    AND expires_at IS NOT NULL
    AND expires_at < NOW()
    AND status NOT IN ('accepted', 'declined');

    GET DIAGNOSTICS expired_count = ROW_COUNT;

    INSERT INTO cron_execution_log (job_name, status, message)
    VALUES ('expire-negotiations', 'success',
      CASE WHEN expired_count > 0
        THEN expired_count || ' negosiasi expired'
        ELSE 'Tidak ada negosiasi expired'
      END);
  END;
  $job$
  $cron$
);

-- 2. Backfill baris yang sudah kadung 'EXPIRED' (uppercase) dari histori
--    cron sebelum fix ini -- termasuk data real (bukan cuma data test).
UPDATE negotiations SET status = 'expired' WHERE status = 'EXPIRED';
