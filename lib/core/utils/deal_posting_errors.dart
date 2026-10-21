/// Maps deal/payment PostgREST errors to short actionable UI copy.
String friendlyDealPostingError(Object error) {
  final raw = error.toString();
  final lower = raw.toLowerCase();

  if (lower.contains('1160') || lower.contains('customer advances')) {
    return 'Accounting setup incomplete: Customer Advances (1160) is missing. '
        'Ask an admin to provision deal COA, then retry.';
  }
  if (lower.contains('1110') || lower.contains('cash pkr')) {
    return 'Select a valid PKR cash/bank receiving account (or add Cash PKR 1110).';
  }
  if (lower.contains('exceeds outstanding') || lower.contains('exceeds deal total')) {
    return 'Payment is higher than the amount still due on this deal.';
  }
  if (lower.contains('another company')) {
    return 'That receiving account belongs to another company.';
  }
  if (lower.contains('must be positive')) {
    return 'Enter a payment amount greater than zero, or choose Payment later.';
  }
  if (lower.contains('missing account_id')) {
    return 'A required ledger account is missing for this company. '
        'Deal COA (1160 Customer Advances) must exist before receiving payment.';
  }
  if (lower.contains('unauthorized')) {
    return 'You do not have permission to post this deal or payment.';
  }
  if (lower.contains('currency_mismatch')) {
    return 'Currency must match the selected source leg. '
        'This screen receives sourced foreign currency — use Receive customer payment for PKR.';
  }
  if (lower.contains('counterparty_mismatch')) {
    return 'Counterparty must be the source agent on the selected leg.';
  }
  if (lower.contains('over_remaining') ||
      lower.contains('exceeds remaining on source')) {
    return 'Receipt amount exceeds remaining on the source leg (same currency). '
        'Lower the amount or refresh the deal and try again.';
  }
  if (lower.contains('must be greater than zero')) {
    return 'Enter a receipt amount greater than zero in the source currency.';
  }
  if (lower.contains('parent_leg_id')) {
    return 'Select the agent source leg this receipt belongs to.';
  }
  if (lower.contains('not open for receipt')) {
    return 'That source leg is already fully received. Refresh the deal.';
  }

  // Keep a short sanitized hint without dumping full PostgREST JSON.
  final msgMatch = RegExp(r'message:\s*([^,\)]+)').firstMatch(raw);
  if (msgMatch != null) {
    return 'Could not save: ${msgMatch.group(1)!.trim()}';
  }
  return 'Could not save. Check currency, amounts, and try again.';
}
