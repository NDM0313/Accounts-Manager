/// Human-readable rate source labels (no fake live integrations).
abstract final class RateSourceLabels {
  static const options = <String, String>{
    'manual': 'Manual Reference Rate',
    'import': 'Imported (CSV)',
    'market': 'Market (manual entry)',
    'api': 'API (future — not connected)',
  };

  static String label(String? source) {
    if (source == null || source.isEmpty) return options['manual']!;
    return options[source] ?? source;
  }

  static bool isSelectable(String source) => source != 'api';
}
