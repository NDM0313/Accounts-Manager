-- Verify report RPCs exist (SQL Editor safe — no JWT required for catalog check)
SELECT routine_name
FROM information_schema.routines
WHERE routine_schema = 'public'
  AND routine_name IN (
    'fx_get_general_ledger',
    'fx_get_profit_and_loss',
    'fx_get_balance_sheet',
    'fx_get_currency_position',
    'fx_get_closing_preview',
    'fx_close_day',
    'fx_is_day_closed'
  )
ORDER BY routine_name;

-- Posted transaction smoke (direct table — no RPC permission needed)
SELECT status, count(*) AS cnt
FROM fx_transactions
WHERE is_deleted = false
GROUP BY status
ORDER BY status;
