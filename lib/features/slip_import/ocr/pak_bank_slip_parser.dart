/// Structured OCR extract for Pakistani bank / wallet payment slips.
/// Unknown fields stay null — never invent amounts, dates, or account digits.
class SlipOcrExtract {
  const SlipOcrExtract({
    this.amount,
    this.currencyCode,
    this.txnDate,
    this.txnTimeText,
    this.senderName,
    this.senderBank,
    this.senderAccountMask,
    this.receiverName,
    this.receiverBank,
    this.receiverAccountMask,
    this.bankReference,
    this.providerName,
    this.printedStatus,
    required this.rawText,
    this.uncertainFields = const [],
    this.confidence = 0,
  });

  final double? amount;
  final String? currencyCode;
  final String? txnDate; // YYYY-MM-DD
  final String? txnTimeText; // as printed / HH:mm
  final String? senderName;
  final String? senderBank;
  final String? senderAccountMask;
  final String? receiverName;
  final String? receiverBank;
  final String? receiverAccountMask;
  final String? bankReference;
  final String? providerName;
  final String? printedStatus;
  final String rawText;
  final List<String> uncertainFields;
  final double confidence;

  Map<String, dynamic> toJson() => {
        'amount': amount,
        'currency_code': currencyCode,
        'txn_date': txnDate,
        'txn_time_text': txnTimeText,
        'sender_name': senderName,
        'sender_bank': senderBank,
        'sender_account_mask': senderAccountMask,
        'receiver_name': receiverName,
        'receiver_bank': receiverBank,
        'receiver_account_mask': receiverAccountMask,
        'bank_reference': bankReference,
        'provider_name': providerName,
        'printed_status': printedStatus,
        'raw_text': rawText,
        'uncertain_fields': uncertainFields,
        'confidence': confidence,
      };
}

class PakBankSlipParser {
  static final _months = <String, int>{
    'jan': 1,
    'january': 1,
    'feb': 2,
    'february': 2,
    'mar': 3,
    'march': 3,
    'apr': 4,
    'april': 4,
    'may': 5,
    'jun': 6,
    'june': 6,
    'jul': 7,
    'july': 7,
    'aug': 8,
    'august': 8,
    'sep': 9,
    'sept': 9,
    'september': 9,
    'oct': 10,
    'october': 10,
    'nov': 11,
    'november': 11,
    'dec': 12,
    'december': 12,
  };

  static String normalize(String text, {bool keepNewlines = false}) {
    var s = text;
    s = s.replaceAll(RegExp(r'[\u0600-\u06FF\u0750-\u077F]+'), ' ');
    s = s.replaceAll('\u00a0', ' ');
    s = s.replaceAll(RegExp(r'[|¦]'), ' ');
    if (keepNewlines) {
      s = s.replaceAll(RegExp(r'[^\S\r\n]+'), ' ');
      s = s.replaceAll(RegExp(r'\n{3,}'), '\n\n');
    } else {
      s = s.replaceAll(RegExp(r'\s+'), ' ');
    }
    return s.trim();
  }

  static SlipOcrExtract parse(String rawText) {
    final raw = rawText;
    final lined = normalize(raw, keepNewlines: true);
    final text = normalize(raw);
    final uncertain = <String>[];

    final currency = _detectCurrency(text);
    final amount = _detectAmount(text, currency);
    if (amount == null) uncertain.add('amount');

    final date = _detectDate(text);
    if (date == null) uncertain.add('txn_date');

    final time = _detectTime(text);
    final reference = _detectReference(text);
    if (reference == null) uncertain.add('bank_reference');

    final from = _lineAfter(lined, RegExp(r'^(From\s*Account|Sent\s+by|From)\s*:?', caseSensitive: false));
    final to = _lineAfter(lined, RegExp(r'^(To\s*Account|Sent\s+to|To)\s*:?', caseSensitive: false));

    final provider = _detectProvider(text);
    final status = _detectPrintedStatus(text);

    var confidence = 0.2;
    if (amount != null) confidence += 0.35;
    if (date != null) confidence += 0.15;
    if (reference != null) confidence += 0.2;
    if (from != null || to != null) confidence += 0.1;

    return SlipOcrExtract(
      amount: amount,
      currencyCode: currency,
      txnDate: date,
      txnTimeText: time,
      senderName: from,
      receiverName: to,
      senderAccountMask: _findAccountMask(text, afterFrom: true),
      receiverAccountMask: _findAccountMask(text, afterFrom: false),
      bankReference: reference,
      providerName: provider,
      printedStatus: status,
      rawText: raw,
      uncertainFields: uncertain,
      confidence: confidence.clamp(0, 1),
    );
  }

  static String? _detectCurrency(String text) {
    final m = RegExp(r'\b(PKR|USD|AED|CNY|RMB|SAR|EUR|GBP)\b', caseSensitive: false)
        .firstMatch(text);
    if (m == null) return null;
    final c = m.group(1)!.toUpperCase();
    return c == 'RMB' ? 'CNY' : c;
  }

  static double? _detectAmount(String text, String? currency) {
    // Prefer labeled amount lines
    final labeled = RegExp(
      r'(?:Amount|Total|Transferred|Paid)\s*:?\s*(?:PKR|Rs\.?|USD|AED|CNY|RMB)?\s*([\d,]+\.?\d*)',
      caseSensitive: false,
    ).firstMatch(text);
    if (labeled != null) {
      return _parseNum(labeled.group(1)!);
    }
    final withCur = RegExp(
      r'(?:PKR|Rs\.?)\s*([\d,]+\.?\d*)',
      caseSensitive: false,
    ).firstMatch(text);
    if (withCur != null) return _parseNum(withCur.group(1)!);

    // Avoid inventing from random numbers — require at least one comma or decimal for PKR-like amounts
    final candidates = RegExp(r'\b([\d]{1,3}(?:,\d{3})+(?:\.\d{1,2})?|\d+\.\d{2})\b')
        .allMatches(text)
        .map((m) => _parseNum(m.group(1)!))
        .whereType<double>()
        .where((n) => n >= 1)
        .toList();
    if (candidates.isEmpty) return null;
    candidates.sort();
    return candidates.last;
  }

  static double? _parseNum(String s) {
    final cleaned = s.replaceAll(',', '');
    return double.tryParse(cleaned);
  }

  static String? _detectDate(String text) {
    final iso = RegExp(r'\b(20\d{2})-(\d{2})-(\d{2})\b').firstMatch(text);
    if (iso != null) {
      return '${iso.group(1)}-${iso.group(2)}-${iso.group(3)}';
    }
    final dmy = RegExp(r'\b(\d{1,2})[/\-.](\d{1,2})[/\-.](20\d{2})\b').firstMatch(text);
    if (dmy != null) {
      final d = dmy.group(1)!.padLeft(2, '0');
      final m = dmy.group(2)!.padLeft(2, '0');
      final y = dmy.group(3)!;
      // Ambiguous DMY vs MDY — flag via returning only when day > 12 or keep as printed-order DMY common in PK
      return '$y-$m-$d';
    }
    final mon = RegExp(
      r'\b(\d{1,2})\s+(Jan|January|Feb|February|Mar|March|Apr|April|May|Jun|June|Jul|July|Aug|August|Sep|Sept|September|Oct|October|Nov|November|Dec|December)\s+(20\d{2})\b',
      caseSensitive: false,
    ).firstMatch(text);
    if (mon != null) {
      final d = mon.group(1)!.padLeft(2, '0');
      final m = (_months[mon.group(2)!.toLowerCase()] ?? 0).toString().padLeft(2, '0');
      final y = mon.group(3)!;
      if (m == '00') return null;
      return '$y-$m-$d';
    }
    return null;
  }

  static String? _detectTime(String text) {
    final ampm = RegExp(r'\b(\d{1,2}):(\d{2})\s*(AM|PM)\b', caseSensitive: false)
        .firstMatch(text);
    if (ampm != null) {
      var h = int.parse(ampm.group(1)!);
      final m = ampm.group(2)!;
      final ap = ampm.group(3)!.toUpperCase();
      if (ap == 'PM' && h < 12) h += 12;
      if (ap == 'AM' && h == 12) h = 0;
      return '${h.toString().padLeft(2, '0')}:$m';
    }
    final h24 = RegExp(r'\b([01]?\d|2[0-3]):([0-5]\d)(?::[0-5]\d)?\b').firstMatch(text);
    if (h24 != null) {
      return '${h24.group(1)!.padLeft(2, '0')}:${h24.group(2)}';
    }
    return null;
  }

  static String? _detectReference(String text) {
    final labeled = RegExp(
      r'(?:TID|RRN|STAN|Transaction\s*(?:ID|No\.?|Number)|Reference|Ref\.?|FT\s*No\.?)\s*:?\s*([A-Za-z0-9\-]{6,})',
      caseSensitive: false,
    ).firstMatch(text);
    if (labeled != null) return labeled.group(1);
    // Preserve leading zeros — do not parse as int
    final longDigits = RegExp(r'\b(0\d{9,22}|\d{10,22})\b').firstMatch(text);
    return longDigits?.group(1);
  }

  static String? _detectProvider(String text) {
    for (final name in [
      'Meezan',
      'HBL',
      'UBL',
      'MCB',
      'Allied',
      'JazzCash',
      'Easypaisa',
      'Bank Alfalah',
      'Faysal',
      'Askari',
      'SadaPay',
      'NayaPay',
    ]) {
      if (RegExp(name, caseSensitive: false).hasMatch(text)) return name;
    }
    return null;
  }

  static String? _detectPrintedStatus(String text) {
    final m = RegExp(
      r'\b(Successful|Success|Completed|Failed|Pending|Processing)\b',
      caseSensitive: false,
    ).firstMatch(text);
    return m?.group(1);
  }

  static String? _lineAfter(String text, RegExp label) {
    final lines = text.split(RegExp(r'[\r\n]+'));
    for (var i = 0; i < lines.length; i++) {
      final line = lines[i].trim();
      if (!label.hasMatch(line)) continue;
      final same = line.replaceFirst(label, '').replaceFirst(RegExp(r'^[:\-\s]+'), '').trim();
      if (same.length >= 3) return same.length > 120 ? same.substring(0, 120) : same;
      if (i + 1 < lines.length) {
        final next = lines[i + 1].trim();
        if (next.length >= 3) return next.length > 120 ? next.substring(0, 120) : next;
      }
    }
    // Flat normalized text fallback
    final m = RegExp(
      '${label.pattern}\\s*[:\\-]?\\s*([A-Za-z][A-Za-z0-9 .&\\-]{2,80})',
      caseSensitive: false,
    ).firstMatch(text);
    return m?.group(1)?.trim();
  }

  static String? _findAccountMask(String text, {required bool afterFrom}) {
    final masks = RegExp(r'\b(\d{2,4}[x*]{2,}\d{2,4}|PK[\d*A-Z]{8,}|0?3\d{2}[\s-]?\d{7})\b')
        .allMatches(text)
        .map((m) => m.group(1)!)
        .toList();
    if (masks.isEmpty) return null;
    if (masks.length == 1) return masks.first;
    return afterFrom ? masks.first : masks.last;
  }

  static String buildDescription(SlipOcrExtract e) {
    final parts = <String>[];
    if (e.amount != null) {
      parts.add('${e.currencyCode ?? 'PKR'} ${e.amount}');
    }
    if (e.txnDate != null) {
      parts.add([e.txnDate, e.txnTimeText].whereType<String>().join(' '));
    }
    final fromBits = [
      if (e.senderName != null) e.senderName,
      if (e.senderBank != null) e.senderBank,
      if (e.senderAccountMask != null) e.senderAccountMask,
    ].join('/');
    final toBits = [
      if (e.receiverName != null) e.receiverName,
      if (e.receiverBank != null) e.receiverBank,
      if (e.receiverAccountMask != null) e.receiverAccountMask,
    ].join('/');
    if (fromBits.isNotEmpty) parts.add('from $fromBits');
    if (toBits.isNotEmpty) parts.add('to $toBits');
    if (e.bankReference != null) parts.add('reference ${e.bankReference}');
    if (e.printedStatus != null) {
      parts.add('(slip status: ${e.printedStatus} — not bank-verified)');
    }
    return parts.join(', ');
  }
}
