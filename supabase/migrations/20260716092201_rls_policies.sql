-- ============================================================
-- RLS POLICIES — Sprint 2, FG-3
-- ============================================================

-- ============================================================
-- 1. users — Self-only
-- ============================================================
CREATE POLICY "users_select_self" ON users
  FOR SELECT USING (auth.uid() = id);

CREATE POLICY "users_update_self" ON users
  FOR UPDATE USING (auth.uid() = id);

CREATE POLICY "users_delete_self" ON users
  FOR DELETE USING (auth.uid() = id);

-- ============================================================
-- 2. farmer_profiles — Public read, self-write
-- ============================================================
CREATE POLICY "farmer_profiles_select_public" ON farmer_profiles
  FOR SELECT USING (true);

CREATE POLICY "farmer_profiles_insert_self" ON farmer_profiles
  FOR INSERT WITH CHECK (auth.uid() = user_id);

CREATE POLICY "farmer_profiles_update_self" ON farmer_profiles
  FOR UPDATE USING (auth.uid() = user_id);

CREATE POLICY "farmer_profiles_delete_self" ON farmer_profiles
  FOR DELETE USING (auth.uid() = user_id);

-- ============================================================
-- 3. buyer_profiles — Public read, self-write
-- ============================================================
CREATE POLICY "buyer_profiles_select_public" ON buyer_profiles
  FOR SELECT USING (true);

CREATE POLICY "buyer_profiles_insert_self" ON buyer_profiles
  FOR INSERT WITH CHECK (auth.uid() = user_id);

CREATE POLICY "buyer_profiles_update_self" ON buyer_profiles
  FOR UPDATE USING (auth.uid() = user_id);

CREATE POLICY "buyer_profiles_delete_self" ON buyer_profiles
  FOR DELETE USING (auth.uid() = user_id);

-- ============================================================
-- 4. listings — Public read, self-write
-- ============================================================
CREATE POLICY "listings_select_public" ON listings
  FOR SELECT USING (true);

CREATE POLICY "listings_insert_self" ON listings
  FOR INSERT WITH CHECK (auth.uid() = farmer_id);

CREATE POLICY "listings_update_self" ON listings
  FOR UPDATE USING (auth.uid() = farmer_id);

CREATE POLICY "listings_delete_self" ON listings
  FOR DELETE USING (auth.uid() = farmer_id);

-- ============================================================
-- 5. trust_metrics — Public read, owner-write
-- ============================================================
CREATE POLICY "trust_metrics_select_public" ON trust_metrics
  FOR SELECT USING (true);

CREATE POLICY "trust_metrics_insert_self" ON trust_metrics
  FOR INSERT WITH CHECK (auth.uid() = farmer_id);

CREATE POLICY "trust_metrics_update_self" ON trust_metrics
  FOR UPDATE USING (auth.uid() = farmer_id);

-- ============================================================
-- 6. price_reference_data — Public read only
-- ============================================================
CREATE POLICY "price_reference_data_select_public" ON price_reference_data
  FOR SELECT USING (true);

-- ============================================================
-- 7. buyer_metrics — Public read, self-write via buyer_profiles
-- ============================================================
CREATE POLICY "buyer_metrics_select_public" ON buyer_metrics
  FOR SELECT USING (true);

CREATE POLICY "buyer_metrics_insert_self" ON buyer_metrics
  FOR INSERT WITH CHECK (
    EXISTS (
      SELECT 1 FROM buyer_profiles
      WHERE buyer_profiles.id = buyer_metrics.buyer_id
        AND buyer_profiles.user_id = auth.uid()
    )
  );

CREATE POLICY "buyer_metrics_update_self" ON buyer_metrics
  FOR UPDATE USING (
    EXISTS (
      SELECT 1 FROM buyer_profiles
      WHERE buyer_profiles.id = buyer_metrics.buyer_id
        AND buyer_profiles.user_id = auth.uid()
    )
  );

CREATE POLICY "buyer_metrics_delete_self" ON buyer_metrics
  FOR DELETE USING (
    EXISTS (
      SELECT 1 FROM buyer_profiles
      WHERE buyer_profiles.id = buyer_metrics.buyer_id
        AND buyer_profiles.user_id = auth.uid()
    )
  );

-- ============================================================
-- 8. negotiations — Participant-only
-- ============================================================
CREATE POLICY "negotiations_select_participant" ON negotiations
  FOR SELECT USING (auth.uid() = buyer_id OR auth.uid() = farmer_id);

CREATE POLICY "negotiations_insert_buyer" ON negotiations
  FOR INSERT WITH CHECK (auth.uid() = buyer_id);

CREATE POLICY "negotiations_update_participant" ON negotiations
  FOR UPDATE USING (auth.uid() = buyer_id OR auth.uid() = farmer_id);

CREATE POLICY "negotiations_delete_participant" ON negotiations
  FOR DELETE USING (auth.uid() = buyer_id OR auth.uid() = farmer_id);

-- ============================================================
-- 9. transactions — Participant-only
-- ============================================================
CREATE POLICY "transactions_select_participant" ON transactions
  FOR SELECT USING (auth.uid() = buyer_id OR auth.uid() = farmer_id);

CREATE POLICY "transactions_insert_participant" ON transactions
  FOR INSERT WITH CHECK (auth.uid() = buyer_id OR auth.uid() = farmer_id);

CREATE POLICY "transactions_update_participant" ON transactions
  FOR UPDATE USING (auth.uid() = buyer_id OR auth.uid() = farmer_id);

CREATE POLICY "transactions_delete_participant" ON transactions
  FOR DELETE USING (auth.uid() = buyer_id OR auth.uid() = farmer_id);

-- ============================================================
-- 10. recurring_orders — Participant-only
-- ============================================================
CREATE POLICY "recurring_orders_select_participant" ON recurring_orders
  FOR SELECT USING (auth.uid() = buyer_id OR auth.uid() = farmer_id);

CREATE POLICY "recurring_orders_insert_participant" ON recurring_orders
  FOR INSERT WITH CHECK (auth.uid() = buyer_id OR auth.uid() = farmer_id);

CREATE POLICY "recurring_orders_update_participant" ON recurring_orders
  FOR UPDATE USING (auth.uid() = buyer_id OR auth.uid() = farmer_id);

CREATE POLICY "recurring_orders_delete_participant" ON recurring_orders
  FOR DELETE USING (auth.uid() = buyer_id OR auth.uid() = farmer_id);

-- ============================================================
-- 11. negotiation_messages — Participant via parent negotiation
-- ============================================================
CREATE POLICY "negotiation_messages_select_participant" ON negotiation_messages
  FOR SELECT USING (
    EXISTS (
      SELECT 1 FROM negotiations
      WHERE negotiations.id = negotiation_messages.negotiation_id
        AND (auth.uid() = negotiations.buyer_id OR auth.uid() = negotiations.farmer_id)
    )
  );

CREATE POLICY "negotiation_messages_insert_sender" ON negotiation_messages
  FOR INSERT WITH CHECK (
    auth.uid() = sender_id
    AND EXISTS (
      SELECT 1 FROM negotiations
      WHERE negotiations.id = negotiation_messages.negotiation_id
        AND (auth.uid() = negotiations.buyer_id OR auth.uid() = negotiations.farmer_id)
    )
  );

CREATE POLICY "negotiation_messages_update_sender" ON negotiation_messages
  FOR UPDATE USING (auth.uid() = sender_id);

CREATE POLICY "negotiation_messages_delete_sender" ON negotiation_messages
  FOR DELETE USING (auth.uid() = sender_id);
