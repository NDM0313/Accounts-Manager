import 'package:accounts_manager/domain/models/fx_party.dart';
import 'package:accounts_manager/domain/models/fx_transaction.dart';

/// Business-friendly presets layered on generic settlement transaction types.
enum TransactionDraftMode {
  standard,
  customerReceipt,
  agentPayment,
  agentReturn,
  customerRefund;

  static TransactionDraftMode fromQuery(String? value) {
    if (value == null || value.isEmpty) return TransactionDraftMode.standard;
    return switch (value) {
      'customer_receipt' => TransactionDraftMode.customerReceipt,
      'agent_payment' => TransactionDraftMode.agentPayment,
      'agent_return' => TransactionDraftMode.agentReturn,
      'customer_refund' => TransactionDraftMode.customerRefund,
      _ => TransactionDraftMode.standard,
    };
  }

  String get dbValue => switch (this) {
    TransactionDraftMode.standard => '',
    TransactionDraftMode.customerReceipt => 'customer_receipt',
    TransactionDraftMode.agentPayment => 'agent_payment',
    TransactionDraftMode.agentReturn => 'agent_return',
    TransactionDraftMode.customerRefund => 'customer_refund',
  };

  FxTransactionType get transactionType => switch (this) {
    TransactionDraftMode.customerReceipt ||
    TransactionDraftMode.agentReturn => FxTransactionType.settlementReceive,
    TransactionDraftMode.agentPayment ||
    TransactionDraftMode.customerRefund => FxTransactionType.settlementSend,
    TransactionDraftMode.standard => FxTransactionType.currencyBuy,
  };

  String get menuLabel => switch (this) {
    TransactionDraftMode.customerReceipt => 'Customer Payment Receive',
    TransactionDraftMode.agentPayment => 'Agent Payment Send',
    TransactionDraftMode.agentReturn => 'Receive from Agent',
    TransactionDraftMode.customerRefund => 'Customer Refund',
    TransactionDraftMode.standard => '',
  };

  String get screenTitle => switch (this) {
    TransactionDraftMode.customerReceipt => 'Receive from Customer',
    TransactionDraftMode.agentPayment => 'Pay Agent',
    TransactionDraftMode.agentReturn => 'Receive from Agent',
    TransactionDraftMode.customerRefund => 'Refund Customer',
    TransactionDraftMode.standard => '',
  };

  String get confirmTitle => switch (this) {
    TransactionDraftMode.customerReceipt => 'Confirm Customer Payment',
    TransactionDraftMode.agentPayment => 'Confirm Agent Payment',
    TransactionDraftMode.agentReturn => 'Confirm Agent Return',
    TransactionDraftMode.customerRefund => 'Confirm Customer Refund',
    TransactionDraftMode.standard => 'Confirm Transaction Posting',
  };

  String get successTitle => switch (this) {
    TransactionDraftMode.customerReceipt => 'Payment received',
    TransactionDraftMode.agentPayment => 'Agent payment posted',
    TransactionDraftMode.agentReturn => 'Agent return received',
    TransactionDraftMode.customerRefund => 'Customer refund posted',
    TransactionDraftMode.standard => 'Transaction posted',
  };

  /// Default settlement GL account code.
  String? get defaultSettlementAccount => switch (this) {
    TransactionDraftMode.customerReceipt => '1190',
    TransactionDraftMode.agentPayment => '2100',
    TransactionDraftMode.agentReturn => '1180',
    TransactionDraftMode.customerRefund => '2200',
    TransactionDraftMode.standard => null,
  };

  bool matchesParty(FxPartyType type) => switch (this) {
    TransactionDraftMode.customerReceipt ||
    TransactionDraftMode.customerRefund => type == FxPartyType.customer,
    TransactionDraftMode.agentPayment || TransactionDraftMode.agentReturn =>
      type == FxPartyType.agent || type == FxPartyType.settlement,
    TransactionDraftMode.standard => true,
  };

  bool get requiresParty => this != TransactionDraftMode.standard;
}
