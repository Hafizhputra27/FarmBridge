CREATE EXTENSION IF NOT EXISTS "uuid-ossp";

-- ============================================================
-- TABEL 1: users
-- ============================================================
CREATE TABLE users (
  id          uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  email       text UNIQUE NULL,
  role        text NOT NULL CHECK (role IN ('farmer', 'buyer', 'admin')),
  device_token text NULL,
  created_at  timestamptz DEFAULT now()
);

-- ============================================================
-- TABEL 2: farmer_profiles
-- ============================================================
CREATE TABLE farmer_profiles (
  id       uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id  uuid NOT NULL UNIQUE REFERENCES users(id) ON DELETE CASCADE,
  nama     text NOT NULL,
  lokasi   text,
  bio      text,
  verified boolean DEFAULT false
);

-- ============================================================
-- TABEL 3: buyer_profiles
-- ============================================================
CREATE TABLE buyer_profiles (
  id              uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id         uuid NOT NULL UNIQUE REFERENCES users(id) ON DELETE CASCADE,
  nama_institusi  text NOT NULL
);

-- ============================================================
-- TABEL 4: listings
-- ============================================================
CREATE TABLE listings (
  id                  uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  farmer_id           uuid NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  category            text NOT NULL,
  region              text NOT NULL,
  harga_per_unit      numeric NOT NULL,
  quantity_available  numeric NOT NULL,
  status              text DEFAULT 'active',
  foto_url            text,
  created_at          timestamptz DEFAULT now()
);

CREATE INDEX idx_listings_status ON listings(status);

-- ============================================================
-- TABEL 5: price_reference_data
-- ============================================================
CREATE TABLE price_reference_data (
  id         uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  category   text NOT NULL,
  region     text NOT NULL,
  avg_price  numeric NOT NULL,
  min_price  numeric NOT NULL,
  max_price  numeric NOT NULL
);

-- ============================================================
-- TABEL 6: negotiations
-- ============================================================
CREATE TABLE negotiations (
  id                  uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  listing_id          uuid NOT NULL REFERENCES listings(id) ON DELETE CASCADE,
  buyer_id            uuid NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  farmer_id           uuid NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  status              text DEFAULT 'open',
  initial_price       numeric NOT NULL,
  current_offer_price numeric NOT NULL,
  counter_count       int DEFAULT 0,
  recommended_price   numeric NULL,
  expires_at          timestamptz,
  created_at          timestamptz DEFAULT now()
);

CREATE INDEX idx_negotiations_status ON negotiations(status);

-- ============================================================
-- TABEL 7: negotiation_messages
-- ============================================================
CREATE TABLE negotiation_messages (
  id              uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  negotiation_id  uuid NOT NULL REFERENCES negotiations(id) ON DELETE CASCADE,
  sender_id       uuid NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  action_type     text NOT NULL,
  message_text    text NULL,
  offer_price     numeric NULL,
  created_at      timestamptz DEFAULT now()
);

-- ============================================================
-- TABEL 8: transactions
-- ============================================================
CREATE TABLE transactions (
  id                     uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  negotiation_id         uuid NOT NULL REFERENCES negotiations(id) ON DELETE CASCADE,
  farmer_id              uuid NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  buyer_id               uuid NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  status                 text DEFAULT 'pending',
  agreed_quantity        numeric NOT NULL,
  total_amount           numeric NOT NULL,
  delivered_quantity     numeric NULL,
  actual_delivery_date   date NULL,
  promised_delivery_date date NOT NULL,
  anomaly_flag           boolean DEFAULT false,
  created_at             timestamptz DEFAULT now()
);

CREATE INDEX idx_transactions_status ON transactions(status);
CREATE INDEX idx_transactions_farmer_id ON transactions(farmer_id);

-- ============================================================
-- TABEL 9: recurring_orders
-- ============================================================
CREATE TABLE recurring_orders (
  id              uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  buyer_id        uuid NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  farmer_id       uuid NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  listing_id      uuid NOT NULL REFERENCES listings(id) ON DELETE CASCADE,
  quantity        numeric NOT NULL,
  frequency       text NOT NULL,
  locked_price    numeric NOT NULL,
  status          text DEFAULT 'active',
  next_order_date date NOT NULL,
  created_at      timestamptz DEFAULT now()
);

-- ============================================================
-- TABEL 10: trust_metrics
-- ============================================================
CREATE TABLE trust_metrics (
  farmer_id               uuid PRIMARY KEY REFERENCES users(id) ON DELETE CASCADE,
  on_time_delivery_rate   numeric(5,2) DEFAULT 0,
  rejection_rate          numeric(5,2) DEFAULT 0,
  fulfillment_consistency numeric(5,2) DEFAULT 0,
  total_transactions      int DEFAULT 0,
  window_days             int DEFAULT 90,
  updated_at              timestamptz DEFAULT now()
);

-- ============================================================
-- TABEL 11: buyer_metrics
-- ============================================================
CREATE TABLE buyer_metrics (
  id                   uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  buyer_id             uuid NOT NULL REFERENCES buyer_profiles(id) ON DELETE CASCADE,
  total_procurement    numeric(14,2) DEFAULT 0,
  active_orders_count  int DEFAULT 0,
  fulfillment_rate     numeric(5,2) DEFAULT 0,
  avg_monthly_volume   numeric(12,2) DEFAULT 0,
  window_days          int DEFAULT 90,
  updated_at           timestamptz DEFAULT now()
);
