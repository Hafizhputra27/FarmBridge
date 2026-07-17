-- ============================================================
-- FG-42: aktifkan pg_net + reschedule check-recurring-orders
-- supaya benar-benar memanggil Edge Function (kirim reminder
-- H-1), bukan cuma insert log placeholder seperti sejak Sprint 1.
-- ============================================================
CREATE EXTENSION IF NOT EXISTS pg_net;

SELECT cron.unschedule('check-recurring-orders');

SELECT cron.schedule(
  'check-recurring-orders',
  '0 8 * * *',
  $$
  SELECT net.http_post(
    url := 'https://rwxnjxmzkcfoddnzjosi.supabase.co/functions/v1/check-recurring-orders',
    headers := '{"Content-Type": "application/json", "Authorization": "Bearer sb_publishable_-tmXQTkiRSNHtvjBVILpvA_oGVnliRX"}'::jsonb,
    body := '{}'::jsonb
  );
  $$
);
