import 'package:accounts_manager/domain/models/fx_account.dart';

/// Cash vs bank eligibility using account codes from fx_create_cash_bank_account.
/// Cash: 1110–1159 and 1181–1189. Bank: 1210–1299.
/// Control accounts 1180/1190/2100/2200/2300 are never settlement vaults.
abstract final class CashBankAccountRules {
  static const _controlCodes = {'1180', '1190', '2100', '2200', '2300'};

  static bool isControlAccount(FxAccount a) => _controlCodes.contains(a.code);

  static bool isCashVault(FxAccount a) {
    if (a.accountType != 'asset' || !a.isActive) return false;
    if (isControlAccount(a)) return false;
    final code = int.tryParse(a.code);
    if (code == null) return false;
    return (code >= 1110 && code <= 1159) || (code >= 1181 && code <= 1189);
  }

  static bool isBankVault(FxAccount a) {
    if (a.accountType != 'asset' || !a.isActive) return false;
    if (isControlAccount(a)) return false;
    final code = int.tryParse(a.code);
    if (code == null) return false;
    return code >= 1210 && code <= 1299;
  }

  static bool matchesMethod(FxAccount a, String method) =>
      method == 'bank' ? isBankVault(a) : isCashVault(a);

  static List<FxAccount> filterEligible({
    required List<FxAccount> accounts,
    required String method,
    required String currencyCode,
  }) {
    final cur = currencyCode.toUpperCase();
    return accounts
        .where(
          (a) =>
              matchesMethod(a, method) &&
              (a.currencyCode ?? 'PKR').toUpperCase() == cur,
        )
        .toList();
  }

  static String maskIdentifier(String? raw) {
    if (raw == null || raw.trim().isEmpty) return '';
    final t = raw.trim();
    if (t.length <= 4) return t;
    return '• ${t.substring(t.length - 4)}';
  }

  static String displayLabel(FxAccount a) {
    final bits = <String>[a.name];
    final mask = maskIdentifier(a.accountNumber ?? a.iban);
    if (mask.isNotEmpty) bits.add(mask);
    bits.add(a.currencyCode ?? 'PKR');
    return bits.join(' · ');
  }
}
