import 'dart:convert';
import 'dart:js_interop';
import 'dart:js_interop_unsafe';

import 'package:file_picker/file_picker.dart';
import 'package:web/web.dart' as web;

class ImportedContact {
  const ImportedContact({
    this.name,
    this.phones = const [],
    this.emails = const [],
  });

  final String? name;
  final List<String> phones;
  final List<String> emails;
}

/// Contact Picker API (Chromium) + .vcf fallback.
/// iPhone Safari: picker generally unavailable — runtime detection only.
class ContactImport {
  ContactImport._();

  static bool get isContactPickerSupported {
    try {
      final nav = web.window.navigator as JSObject;
      return nav.has('contacts');
    } catch (_) {
      return false;
    }
  }

  static Future<ImportedContact?> pickFromBrowser() async {
    if (!isContactPickerSupported) return null;
    try {
      final nav = web.window.navigator as JSObject;
      final contacts = nav.getProperty('contacts'.toJS) as JSObject?;
      if (contacts == null) return null;
      final select = contacts.getProperty('select'.toJS) as JSFunction?;
      if (select == null) return null;

      final props = <JSAny?>['name'.toJS, 'tel'.toJS, 'email'.toJS].toJS;
      final opts = {'multiple': false}.jsify();
      final promise = select.callAsFunction(contacts, props, opts);
      if (promise == null) return null;
      final result = await (promise as JSPromise<JSAny?>).toDart;
      if (result == null) return null;
      final list = (result as JSObject).dartify();
      if (list is! List || list.isEmpty) return null;
      final first = list.first;
      if (first is! Map) return null;
      final map = Map<String, dynamic>.from(first);
      return ImportedContact(
        name: _firstFromDynamic(map['name']),
        phones: _listFromDynamic(map['tel']),
        emails: _listFromDynamic(map['email']),
      );
    } catch (_) {
      return null;
    }
  }

  static Future<List<ImportedContact>> pickFromVcf() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: const ['vcf', 'vcard'],
      withData: true,
    );
    if (result == null || result.files.isEmpty) return const [];
    final bytes = result.files.first.bytes;
    if (bytes == null) return const [];
    return parseVcf(utf8.decode(bytes));
  }

  static List<ImportedContact> parseVcf(String text) {
    final cards = text.split(RegExp(r'BEGIN:VCARD', caseSensitive: false));
    final out = <ImportedContact>[];
    for (final raw in cards) {
      if (!raw.toUpperCase().contains('END:VCARD')) continue;
      String? name;
      final phones = <String>[];
      final emails = <String>[];
      for (final line in raw.split(RegExp(r'\r?\n'))) {
        final upper = line.toUpperCase();
        if (upper.startsWith('FN:')) {
          name = line.substring(3).trim();
        } else if (upper.startsWith('TEL')) {
          final i = line.indexOf(':');
          if (i > 0) phones.add(line.substring(i + 1).trim());
        } else if (upper.startsWith('EMAIL')) {
          final i = line.indexOf(':');
          if (i > 0) emails.add(line.substring(i + 1).trim());
        }
      }
      if ((name != null && name.isNotEmpty) ||
          phones.isNotEmpty ||
          emails.isNotEmpty) {
        out.add(ImportedContact(name: name, phones: phones, emails: emails));
      }
    }
    return out;
  }

  static String? _firstFromDynamic(dynamic value) {
    final list = _listFromDynamic(value);
    return list.isEmpty ? null : list.first;
  }

  static List<String> _listFromDynamic(dynamic value) {
    if (value == null) return const [];
    if (value is List) {
      return value
          .map((e) => e?.toString() ?? '')
          .where((s) => s.trim().isNotEmpty)
          .toList();
    }
    final s = value.toString();
    if (s.trim().isEmpty) return const [];
    return [s.trim()];
  }
}

String normalizePhoneE164ish(String raw) {
  final t = raw.trim();
  if (t.isEmpty) return '';
  final keepPlus = t.startsWith('+');
  final digits = t.replaceAll(RegExp(r'[^\d]'), '');
  if (digits.isEmpty) return '';
  return keepPlus ? '+$digits' : digits;
}
