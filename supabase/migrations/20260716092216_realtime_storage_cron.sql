-- ============================================================
-- Realtime publication, storage bucket, dan pg_cron scheduled jobs
-- Direkonstruksi 2026-07-16 dari state live project (versi ini sudah
-- applied di remote sejak awal Sprint 1, tapi filenya sempat tidak
-- ter-commit ke git — lihat sprint1_hafizh_dev_report.md).
-- ============================================================

-- TABEL: cron_execution_log (dipakai job di bawah untuk logging)
-- ============================================================
CREATE TABLE cron_execution_log (
  id           bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
  job_name     text NOT NULL,
  status       text NOT NULL,
  message      text NULL,
  executed_at  timestamptz DEFAULT now()
);

ALTER TABLE cron_execution_log ENABLE ROW LEVEL SECURITY;
-- Sengaja tanpa policy: hanya bisa diakses lewat service_role/pg_cron
-- (yang bypass RLS), tidak untuk anon/authenticated.

-- REALTIME: aktifkan replikasi untuk chat/negotiation
-- ============================================================
ALTER PUBLICATION supabase_realtime ADD TABLE negotiations;
ALTER PUBLICATION supabase_realtime ADD TABLE negotiation_messages;

-- STORAGE: bucket foto listing
-- ============================================================
INSERT INTO storage.buckets (id, name, public)
VALUES ('listing-photos', 'listing-photos', true);

CREATE POLICY "listing_photos_public_read" ON storage.objects
  FOR SELECT
  USING (bucket_id = 'listing-photos');

CREATE POLICY "listing_photos_farmer_insert" ON storage.objects
  FOR INSERT
  WITH CHECK (
    bucket_id = 'listing-photos'
    AND auth.uid() IS NOT NULL
    AND EXISTS (
      SELECT 1 FROM users WHERE users.id = auth.uid() AND users.role = 'farmer'
    )
  );

CREATE POLICY "listing_photos_farmer_update" ON storage.objects
  FOR UPDATE
  USING (bucket_id = 'listing-photos' AND owner = auth.uid());

CREATE POLICY "listing_photos_farmer_delete" ON storage.objects
  FOR DELETE
  USING (bucket_id = 'listing-photos' AND owner = auth.uid());

-- PG_CRON: scheduled jobs (logic aslinya menyusul di Sprint 6 & Sprint 8)
-- ============================================================
CREATE EXTENSION IF NOT EXISTS pg_cron;

SELECT cron.schedule(
  'expire-negotiations',
  '*/5 * * * *',
  $$INSERT INTO cron_execution_log (job_name, status, message) VALUES ('expire-negotiations', 'skipped', 'Logic not yet implemented (Sprint 6)')$$
);

SELECT cron.schedule(
  'check-recurring-orders',
  '0 8 * * *',
  $$INSERT INTO cron_execution_log (job_name, status, message) VALUES ('check-recurring-orders', 'skipped', 'Logic not yet implemented (Sprint 8)')$$
);
