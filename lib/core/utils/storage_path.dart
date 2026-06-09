/// Sanitize a user file name for Supabase Storage object keys.
/// Original name is kept in DB for display; storage path uses this safe form.
String sanitizeStorageFileName(String name) {
  final base = name.split('/').last.split('\\').last;
  final dot = base.lastIndexOf('.');
  final ext = dot > 0 ? base.substring(dot) : '';
  final stem = dot > 0 ? base.substring(0, dot) : base;
  var safe = stem.replaceAll(RegExp(r'[^a-zA-Z0-9._-]'), '_');
  safe = safe.replaceAll(RegExp(r'_+'), '_').replaceAll(RegExp(r'^_|_$'), '');
  if (safe.isEmpty) safe = 'file';
  return '$safe$ext';
}

/// Sanitize a single path segment for Supabase Storage keys (UUIDs pass through unchanged).
String sanitizeStoragePathSegment(String segment) {
  return segment.replaceAll(RegExp(r'[^a-zA-Z0-9._-]'), '_');
}
