class ManualJournalLineAmounts {
  const ManualJournalLineAmounts({
    required this.debitText,
    required this.creditText,
  });

  final String debitText;
  final String creditText;
}

bool manualJournalLineHasBothSides(ManualJournalLineAmounts line) {
  final d = double.tryParse(line.debitText) ?? 0;
  final c = double.tryParse(line.creditText) ?? 0;
  return d > 0 && c > 0;
}

double manualJournalTotalDebit(Iterable<ManualJournalLineAmounts> lines) {
  return lines.fold(0.0, (s, l) {
    if (manualJournalLineHasBothSides(l)) return s;
    return s + (double.tryParse(l.debitText) ?? 0);
  });
}

double manualJournalTotalCredit(Iterable<ManualJournalLineAmounts> lines) {
  return lines.fold(0.0, (s, l) {
    if (manualJournalLineHasBothSides(l)) return s;
    return s + (double.tryParse(l.creditText) ?? 0);
  });
}

bool manualJournalHasInvalidLines(Iterable<ManualJournalLineAmounts> lines) {
  return lines.any(manualJournalLineHasBothSides);
}

bool manualJournalIsBalanced(Iterable<ManualJournalLineAmounts> lines) {
  if (manualJournalHasInvalidLines(lines)) return false;
  final debit = manualJournalTotalDebit(lines);
  final credit = manualJournalTotalCredit(lines);
  return debit == credit && debit > 0;
}
