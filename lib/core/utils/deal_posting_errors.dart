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

  // Keep a short sanitized hint without dumping full PostgREST JSON.
  final msgMatch = RegExp(r'message:\s*([^,\)]+)').firstMatch(raw);
  if (msgMatch != null) {
    return 'Could not save deal: ${msgMatch.group(1)!.trim()}';
  }
  return 'Could not save deal. Check amounts, accounts, and try again.';
}
