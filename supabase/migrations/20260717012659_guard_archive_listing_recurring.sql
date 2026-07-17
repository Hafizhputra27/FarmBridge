-- ============================================================
-- FG-60: cegah archive listing yang masih terikat recurring
-- order aktif (edge case §11 ke-8). Trigger, bukan cuma validasi
-- Edge Function/client, supaya tidak bisa di-bypass jalur manapun.
-- ============================================================
CREATE OR REPLACE FUNCTION guard_archive_listing_with_active_recurring()
RETURNS trigger AS $$
DECLARE
  active_count integer;
BEGIN
  IF NEW.status = 'archived' AND OLD.status IS DISTINCT FROM 'archived' THEN
    SELECT count(*) INTO active_count
    FROM recurring_orders
    WHERE listing_id = NEW.id AND status = 'active';

    IF active_count > 0 THEN
      RAISE EXCEPTION 'Listing masih terikat % recurring order aktif — pause/cancel dulu sebelum archive', active_count
        USING ERRCODE = 'check_violation';
    END IF;
  END IF;
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER trg_guard_archive_listing
BEFORE UPDATE ON listings
FOR EACH ROW
EXECUTE FUNCTION guard_archive_listing_with_active_recurring();
