import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';

/// Generates and preserves a client operation ID for a logical money action
/// across retries until [complete] is called after a successful server response.
class ClientOperationId {
  ClientOperationId._();

  static const _uuid = Uuid();
  static const _prefix = 'fx_op_';

  static String _prefsKey(String action, String entityId) =>
      '$_prefix${action}_$entityId';

  /// Returns an existing in-flight ID for [action]/[entityId], or creates one.
  static Future<String> begin(String action, String entityId) async {
    final prefs = await SharedPreferences.getInstance();
    final key = _prefsKey(action, entityId);
    final existing = prefs.getString(key);
    if (existing != null && existing.isNotEmpty) return existing;
    final id = _uuid.v4();
    await prefs.setString(key, id);
    return id;
  }

  /// Clears the in-flight ID after the server accepted the operation.
  static Future<void> complete(String action, String entityId) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_prefsKey(action, entityId));
  }

  /// Stable key including amount fingerprint for amount-changing retries that
  /// must be treated as a new logical action (call [complete] first if amount changes intentionally).
  static Future<String> beginAmounted(
    String action,
    String entityId,
    double amount,
  ) async {
    final prefs = await SharedPreferences.getInstance();
    final amountKey = amount.toStringAsFixed(8);
    final metaKey = '${_prefsKey(action, entityId)}_meta';
    final idKey = _prefsKey(action, entityId);
    final prevAmount = prefs.getString(metaKey);
    if (prevAmount != null && prevAmount != amountKey) {
      await prefs.remove(idKey);
    }
    await prefs.setString(metaKey, amountKey);
    return begin(action, entityId);
  }

  static Future<void> completeAmounted(String action, String entityId) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('${_prefsKey(action, entityId)}_meta');
    await complete(action, entityId);
  }
}
