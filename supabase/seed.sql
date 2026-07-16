-- Seed data price_reference_data — FG-7, Sprint 3.
-- Re-runnable: DELETE semua baris lalu INSERT ulang, bukan ON CONFLICT,
-- karena tabel ini tidak punya unique constraint di (category, region).

DELETE FROM price_reference_data;

INSERT INTO price_reference_data (category, region, avg_price, min_price, max_price) VALUES
  ('Beras', 'Jawa Barat', 12000, 10500, 13500),
  ('Beras', 'Jawa Tengah', 11500, 10000, 13000),
  ('Beras', 'Jawa Timur', 11800, 10200, 13200),

  ('Cabai Merah', 'Jawa Barat', 38000, 28000, 55000),
  ('Cabai Merah', 'Jawa Tengah', 35000, 25000, 50000),
  ('Cabai Merah', 'Jawa Timur', 36000, 26000, 52000),

  ('Bawang Merah', 'Jawa Barat', 30000, 24000, 40000),
  ('Bawang Merah', 'Jawa Tengah', 28000, 22000, 38000),
  ('Bawang Merah', 'Jawa Timur', 29000, 23000, 39000),

  ('Tomat', 'Jawa Barat', 8500, 6000, 12000),
  ('Tomat', 'Jawa Tengah', 7500, 5500, 11000),
  ('Tomat', 'Jawa Timur', 8000, 5800, 11500),

  ('Jagung', 'Jawa Barat', 5500, 4500, 6500),
  ('Jagung', 'Jawa Tengah', 5000, 4200, 6000),
  ('Jagung', 'Jawa Timur', 5200, 4300, 6200),

  ('Kentang', 'Jawa Barat', 11000, 9000, 14000),
  ('Kentang', 'Jawa Tengah', 10000, 8200, 13000),
  ('Kentang', 'Jawa Timur', 10500, 8600, 13500);
