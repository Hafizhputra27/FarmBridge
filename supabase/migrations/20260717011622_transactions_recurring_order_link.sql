-- ============================================================
-- FG-38: transactions dari siklus recurring order tidak punya
-- negotiation (bukan hasil tawar-menawar) — negotiation_id jadi
-- nullable, tambah recurring_order_id sebagai tautan gantinya.
-- Invariant (tidak di-enforce lewat CHECK constraint, sengaja —
-- lihat catatan di plan): tepat satu dari negotiation_id/
-- recurring_order_id yang terisi per baris transactions.
-- ============================================================
ALTER TABLE transactions ALTER COLUMN negotiation_id DROP NOT NULL;

ALTER TABLE transactions
  ADD COLUMN recurring_order_id uuid REFERENCES recurring_orders(id) ON DELETE SET NULL;
