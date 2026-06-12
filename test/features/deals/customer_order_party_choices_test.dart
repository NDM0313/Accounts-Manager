import 'package:accounts_manager/domain/models/fx_party.dart';
import 'package:accounts_manager/features/auth/providers/app_providers.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const customer = FxParty(
    id: 'c1',
    companyId: 'company-1',
    partyType: FxPartyType.customer,
    code: 'C001',
    name: 'Alpha Customer',
    isActive: true,
  );

  const agent = FxParty(
    id: 'a1',
    companyId: 'company-1',
    partyType: FxPartyType.agent,
    code: 'A001',
    name: 'Beta Agent',
    isActive: true,
  );

  const settlement = FxParty(
    id: 's1',
    companyId: 'company-1',
    partyType: FxPartyType.settlement,
    code: 'S001',
    name: 'Gamma Settlement',
    isActive: true,
  );

  ProviderContainer containerWith({
    required List<FxParty> customers,
    required List<FxParty> allParties,
  }) {
    return ProviderContainer(
      overrides: [
        partiesProvider(
          FxPartyType.customer,
        ).overrideWith((ref) async => customers),
        partiesProvider(null).overrideWith((ref) async => allParties),
      ],
    );
  }

  test('returns customers when Customer-type parties exist', () async {
    final container = containerWith(
      customers: [customer],
      allParties: [customer, agent],
    );
    addTearDown(container.dispose);

    final result = await container.read(
      customerOrderPartyChoicesProvider.future,
    );

    expect(result.isFallback, isFalse);
    expect(result.parties, [customer]);
  });

  test(
    'falls back to all parties sorted by name when no customers exist',
    () async {
      final container = containerWith(
        customers: [],
        allParties: [agent, settlement],
      );
      addTearDown(container.dispose);

      final result = await container.read(
        customerOrderPartyChoicesProvider.future,
      );

      expect(result.isFallback, isTrue);
      expect(result.parties.map((p) => p.id).toList(), ['a1', 's1']);
    },
  );

  test('returns empty list when no parties exist at all', () async {
    final container = containerWith(customers: [], allParties: []);
    addTearDown(container.dispose);

    final result = await container.read(
      customerOrderPartyChoicesProvider.future,
    );

    expect(result.isFallback, isTrue);
    expect(result.parties, isEmpty);
  });
}
