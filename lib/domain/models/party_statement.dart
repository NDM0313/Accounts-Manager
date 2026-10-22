import 'package:accounts_manager/domain/models/fx_party.dart';
import 'package:accounts_manager/domain/models/fx_transaction.dart';

enum PartyStatementFormat { simple, detailed }

enum PartyStatementAudience { external, internal }

class PartyStatementLine {
  const PartyStatementLine({
    required this.transactionDate,
    required this.transactionNo,
    required this.transactionType,
    required this.status,
    required this.currencyCode,
    required this.foreignAmount,
    required this.rateUsed,
    required this.debitPkr,
    required this.creditPkr,
    required this.runningBalancePkr,
    required this.pkrEquivalent,
    required this.transactionId,
    required this.narrative,
    this.detailBlocks = const [],
    this.description,
    this.dealNo,
    this.attachmentCount = 0,
    this.hasAttachment = false,
  });

  final DateTime transactionDate;
  final String? transactionNo;
  final FxTransactionType transactionType;
  final String status;
  final String currencyCode;
  final double foreignAmount;
  final double rateUsed;
  final double debitPkr;
  final double creditPkr;
  final double runningBalancePkr;
  final double pkrEquivalent;
  final String transactionId;
  final String narrative;
  final List<String> detailBlocks;
  final String? description;
  final String? dealNo;
  final int attachmentCount;
  final bool hasAttachment;
}

class PartyStatementSummary {
  const PartyStatementSummary({
    required this.totalDebitPkr,
    required this.totalCreditPkr,
    required this.netBalancePkr,
    required this.pendingDraftCount,
    this.lastTransactionDate,
    this.balancesByCurrency = const {},
  });

  final double totalDebitPkr;
  final double totalCreditPkr;
  final double netBalancePkr;
  final int pendingDraftCount;
  final DateTime? lastTransactionDate;
  final Map<String, double> balancesByCurrency;
}

class PartyStatementCompanyMeta {
  const PartyStatementCompanyMeta({
    required this.companyName,
    this.branchName,
    this.isDemo = false,
  });

  final String companyName;
  final String? branchName;
  final bool isDemo;
}

class PartyStatementView {
  const PartyStatementView({
    required this.party,
    required this.from,
    required this.to,
    required this.summary,
    required this.lines,
    this.isInternalView = true,
    this.openingBalancePkr = 0,
    this.statementCurrency = 'PKR',
    this.company,
    this.generatedAt,
    this.balanceExplanation = '',
    this.timezoneLabel = 'PKT',
  });

  final FxParty party;
  final DateTime from;
  final DateTime to;
  final PartyStatementSummary summary;
  final List<PartyStatementLine> lines;
  final bool isInternalView;
  final double openingBalancePkr;
  final String statementCurrency;
  final PartyStatementCompanyMeta? company;
  final DateTime? generatedAt;
  final String balanceExplanation;
  final String timezoneLabel;

  double get closingBalancePkr => summary.netBalancePkr;
}

/// Filter options for party statement queries.
enum PartyStatementStatusFilter { all, posted, draft, voided }

class PartyStatementFilters {
  const PartyStatementFilters({
    required this.from,
    required this.to,
    this.currencyCode,
    this.transactionType,
    this.status = PartyStatementStatusFilter.posted,
    this.search = '',
    this.isInternalView = true,
  });

  final DateTime from;
  final DateTime to;
  final String? currencyCode;
  final FxTransactionType? transactionType;
  final PartyStatementStatusFilter status;
  final String search;
  final bool isInternalView;

  PartyStatementFilters copyWith({
    DateTime? from,
    DateTime? to,
    String? currencyCode,
    FxTransactionType? transactionType,
    PartyStatementStatusFilter? status,
    String? search,
    bool? isInternalView,
    bool clearCurrency = false,
    bool clearType = false,
  }) {
    return PartyStatementFilters(
      from: from ?? this.from,
      to: to ?? this.to,
      currencyCode: clearCurrency ? null : (currencyCode ?? this.currencyCode),
      transactionType: clearType
          ? null
          : (transactionType ?? this.transactionType),
      status: status ?? this.status,
      search: search ?? this.search,
      isInternalView: isInternalView ?? this.isInternalView,
    );
  }
}
