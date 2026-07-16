-- ============================================================
-- FK: listings.farmer_id → farmer_profiles(user_id)
-- Sprint 5 — Fix PostgREST join query PGRST200
-- ============================================================
-- PostgREST tidak bisa auto-resolve join listings→farmer_profiles
-- karena listings.farmer_id mengarah ke users(id), bukan langsung
-- ke farmer_profiles. FK ini menambahkan relasi langsung supaya
-- .select('*, farmer_profiles(nama, lokasi)') berfungsi.
-- farmer_profiles.user_id sudah UNIQUE → valid sebagai FK target.

ALTER TABLE listings
  ADD CONSTRAINT listings_farmer_profiles_fkey
  FOREIGN KEY (farmer_id) REFERENCES farmer_profiles(user_id);
