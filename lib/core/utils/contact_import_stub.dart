import 'package:file_picker/file_picker.dart';

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

class ContactImport {
  ContactImport._();

  static bool get isContactPickerSupported => false;

  static Future<ImportedContact?> pickFromBrowser() async => null;

  static Future<List<ImportedContact>> pickFromVcf() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: const ['vcf', 'vcard'],
      withData: true,
    );
    if (result == null || result.files.isEmpty) return const [];
    final bytes = result.files.first.bytes;
    if (bytes == null) return const [];
    return parseVcf(String.fromCharCodes(bytes));
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
}

String normalizePhoneE164ish(String raw) {
  final t = raw.trim();
  if (t.isEmpty) return '';
  final keepPlus = t.startsWith('+');
  final digits = t.replaceAll(RegExp(r'[^\d]'), '');
  if (digits.isEmpty) return '';
  return keepPlus ? '+$digits' : digits;
}
