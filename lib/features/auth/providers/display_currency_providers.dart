import 'package:accounts_manager/data/repositories/profile_repository.dart';
import 'package:accounts_manager/domain/services/reporting_currency_converter.dart';
import 'package:accounts_manager/features/auth/providers/app_providers.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

const _prefsKeyDisplayCurrency = 'fx_display_currency_code';

final displayCurrencyCodeProvider =
    NotifierProvider<DisplayCurrencyNotifier, String>(
      DisplayCurrencyNotifier.new,
    );

class DisplayCurrencyNotifier extends Notifier<String> {
  @override
  String build() {
    _loadFromPrefs();
    return 'PKR';
  }

  Future<void> _loadFromPrefs() async {
    final prefs = await SharedPreferences.getInstance();
    final saved = prefs.getString(_prefsKeyDisplayCurrency);
    if (saved != null && saved.isNotEmpty && saved != state) {
      state = saved;
    }
  }

  Future<void> setCurrency(String code) async {
    state = code;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_prefsKeyDisplayCurrency, code);
  }
}

final reportCurrencyViewProvider =
    NotifierProvider<ReportCurrencyViewNotifier, ReportCurrencyView>(
      ReportCurrencyViewNotifier.new,
    );

class ReportCurrencyViewNotifier extends Notifier<ReportCurrencyView> {
  @override
  ReportCurrencyView build() => ReportCurrencyView.base;

  void setView(ReportCurrencyView view) => state = view;
}

final companyAccountingContextProvider =
    FutureProvider<CompanyAccountingContext>((ref) async {
      final profile = await ref.watch(currentProfileProvider.future);
      if (profile == null) {
        return const CompanyAccountingContext(
          baseCurrencyCode: 'PKR',
          hasPostedTransactions: false,
        );
      }
      return ref
          .read(profileRepositoryProvider)
          .fetchCompanyAccountingContext(profile.companyId);
    });

/// Converter using latest rates for dashboard.
final dashboardCurrencyConverterProvider =
    FutureProvider<ReportingCurrencyConverter>((ref) async {
      final ctx = await ref.watch(companyAccountingContextProvider.future);
      final display = ref.watch(displayCurrencyCodeProvider);
      final rates = await ref.watch(ratesProvider.future);
      return ReportingCurrencyConverter.fromRates(
        baseCurrencyCode: ctx.baseCurrencyCode,
        displayCurrencyCode: display,
        rates: rates,
      );
    });

/// Converter using as-of date for reports.
final reportCurrencyConverterProvider =
    FutureProvider<ReportingCurrencyConverter>((ref) async {
      final asOf = ref.watch(trialBalanceAsOfProvider);
      return ref.watch(currencyConverterAsOfProvider(asOf).future);
    });

/// Converter for any report as-of date (balance sheet, currency position, etc.).
final currencyConverterAsOfProvider =
    FutureProvider.family<ReportingCurrencyConverter, DateTime>((
      ref,
      asOf,
    ) async {
      final ctx = await ref.watch(companyAccountingContextProvider.future);
      final display = ref.watch(displayCurrencyCodeProvider);
      final rates = await ref.read(rateRepositoryProvider).fetchRatesAsOf(asOf);
      return ReportingCurrencyConverter.fromRates(
        baseCurrencyCode: ctx.baseCurrencyCode,
        displayCurrencyCode: display,
        rates: rates,
        asOf: asOf,
      );
    });
