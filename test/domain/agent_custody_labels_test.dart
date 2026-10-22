import 'package:accounts_manager/domain/services/agent_custody_labels.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/intl.dart';

void main() {
  group('AgentCustodyLabels', () {
    test('custody section title', () {
      expect(AgentCustodyLabels.custodySectionTitle(), 'FX held with agent');
    });

    test('payable PKR credit label', () {
      expect(
        AgentCustodyLabels.payablePkrCreditLabel(),
        'PKR payable credit (custody book)',
      );
    });

    test('party foreign net label includes currency and amount only', () {
      final fmt = NumberFormat('#,##0.00');
      expect(
        AgentCustodyLabels.partyForeignNetLabel(
          currencyCode: 'USD',
          foreignNet: 1234.5,
          formatter: fmt,
        ),
        'USD control net 1,234.50',
      );
      expect(
        AgentCustodyLabels.partyForeignNetLabel(
          currencyCode: 'EUR',
          foreignNet: -50,
          formatter: fmt,
        ),
        'EUR control net -50.00',
      );
    });

    test('double-count note mentions separate books', () {
      expect(
        AgentCustodyLabels.pkrLedgerVsCustodyNote,
        contains('do not double-count'),
      );
    });
  });
}
