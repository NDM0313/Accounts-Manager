-- Verify pending deal leg edit/delete guards (run manually on FXDEV after migration 202606210006)

-- Expect: pending agent_source leg without linked tx can be updated and deleted
-- Replace :leg_id with a test pending leg UUID

-- SELECT fx_update_deal_leg_v2(jsonb_build_object(
--   'leg_id', ':leg_id',
--   'receive_amount', 1000,
--   'notes', 'Updated via verify script'
-- ));

-- SELECT fx_delete_deal_leg_v2(':leg_id');

-- Negative cases (should raise):
-- completed deal leg, customer_order leg, leg with linked_transaction_id

SELECT proname
FROM pg_proc
WHERE proname IN ('fx_delete_deal_leg_v2', 'fx_update_deal_leg_v2', 'fx_recompute_deal_status');
