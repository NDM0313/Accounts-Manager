/// Local calendar date for fx_transactions.transaction_date (YYYY-MM-DD).
String localTransactionDateIso(DateTime date) {
  return DateTime(
    date.year,
    date.month,
    date.day,
  ).toIso8601String().split('T').first;
}
