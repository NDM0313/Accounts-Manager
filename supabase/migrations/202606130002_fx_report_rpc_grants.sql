-- Re-grant report RPCs after signature changes in 202606130001

GRANT EXECUTE ON FUNCTION fx_get_profit_and_loss(UUID, DATE, DATE) TO authenticated;
GRANT EXECUTE ON FUNCTION fx_get_balance_sheet(UUID, DATE) TO authenticated;
GRANT EXECUTE ON FUNCTION fx_get_currency_position(UUID, DATE) TO authenticated;
GRANT EXECUTE ON FUNCTION fx_is_day_closed(UUID, DATE) TO authenticated;
