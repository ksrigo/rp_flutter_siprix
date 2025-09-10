import 'dart:convert';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../core/constants/app_constants.dart';

class StorageService {
  static final StorageService _instance = StorageService._internal();
  static StorageService get instance => _instance;
  StorageService._internal();

  late SharedPreferences _prefs;
  late FlutterSecureStorage _secureStorage;

  Future<void> initialize() async {
    _prefs = await SharedPreferences.getInstance();
    _secureStorage = const FlutterSecureStorage(
      aOptions: AndroidOptions(
        encryptedSharedPreferences: true,
      ),
      iOptions: IOSOptions(
        accessibility: KeychainAccessibility.first_unlock_this_device,
      ),
    );
  }

  // Secure storage methods for sensitive data
  Future<void> storeCredentials({
    required String name,
    required String extension,
    required String password,
    required String domain,
    required String proxy,
    required int port,
  }) async {
    final credentials = {
      'name': name,
      'extension': extension,
      'password': password,
      'domain': domain,
      'proxy': proxy,
      'port': port,
      'timestamp': DateTime.now().millisecondsSinceEpoch,
    };

    await _secureStorage.write(
      key: AppConstants.keyUserCredentials,
      value: jsonEncode(credentials),
    );
  }

  Future<Map<String, dynamic>?> getCredentials() async {
    final credentialsJson = await _secureStorage.read(
      key: AppConstants.keyUserCredentials,
    );

    if (credentialsJson != null) {
      return jsonDecode(credentialsJson) as Map<String, dynamic>;
    }
    return null;
  }

  Future<void> clearCredentials() async {
    await _secureStorage.delete(key: AppConstants.keyUserCredentials);
  }

  Future<bool> hasStoredCredentials() async {
    final credentials = await getCredentials();
    return credentials != null;
  }

  // Token storage methods
  Future<void> saveAccessToken(String token) async {
    await _secureStorage.write(key: 'access_token', value: token);
  }

  Future<String?> getAccessToken() async {
    return await _secureStorage.read(key: 'access_token');
  }

  Future<void> saveRefreshToken(String token) async {
    await _secureStorage.write(key: 'refresh_token', value: token);
  }

  Future<String?> getRefreshToken() async {
    return await _secureStorage.read(key: 'refresh_token');
  }

  Future<void> saveTokenExpiry(DateTime expiresAt) async {
    await _secureStorage.write(
      key: 'token_expires_at',
      value: expiresAt.millisecondsSinceEpoch.toString(),
    );
  }

  Future<DateTime?> getTokenExpiry() async {
    final expiryString = await _secureStorage.read(key: 'token_expires_at');
    if (expiryString != null) {
      final milliseconds = int.tryParse(expiryString);
      if (milliseconds != null) {
        return DateTime.fromMillisecondsSinceEpoch(milliseconds);
      }
    }
    return null;
  }

  Future<void> clearTokens() async {
    await _secureStorage.delete(key: 'access_token');
    await _secureStorage.delete(key: 'refresh_token');
    await _secureStorage.delete(key: 'token_expires_at');
  }

  Future<bool> hasValidToken() async {
    final token = await getAccessToken();
    final expiry = await getTokenExpiry();

    if (token == null || expiry == null) return false;

    // Check if token expires in more than 1 minute
    final now = DateTime.now();
    final oneMinuteBeforeExpiry = expiry.subtract(const Duration(minutes: 1));

    return now.isBefore(oneMinuteBeforeExpiry);
  }

  // Regular storage methods for non-sensitive data
  Future<void> storeAppSettings(Map<String, dynamic> settings) async {
    await _prefs.setString(
      AppConstants.keyAppSettings,
      jsonEncode(settings),
    );
  }

  Future<Map<String, dynamic>?> getAppSettings() async {
    final settingsJson = _prefs.getString(AppConstants.keyAppSettings);
    if (settingsJson != null) {
      return jsonDecode(settingsJson) as Map<String, dynamic>;
    }
    return null;
  }

  // Theme and language preferences
  Future<void> setThemeMode(String themeMode) async {
    await _prefs.setString(AppConstants.keyThemeMode, themeMode);
  }

  Future<String?> getThemeMode() async {
    return _prefs.getString(AppConstants.keyThemeMode);
  }

  Future<void> setLanguage(String languageCode) async {
    await _prefs.setString(AppConstants.keyLanguage, languageCode);
  }

  Future<String?> getLanguage() async {
    return _prefs.getString(AppConstants.keyLanguage);
  }

  // Call history storage
  Future<void> storeCallHistory(List<Map<String, dynamic>> callHistory) async {
    // Limit the number of stored entries
    final limitedHistory =
        callHistory.take(AppConstants.maxCallHistoryEntries).toList();
    await _prefs.setString(
      AppConstants.keyCallHistory,
      jsonEncode(limitedHistory),
    );
  }

  Future<List<Map<String, dynamic>>> getCallHistory() async {
    final historyJson = _prefs.getString(AppConstants.keyCallHistory);
    if (historyJson != null) {
      final List<dynamic> historyList = jsonDecode(historyJson);
      return historyList.cast<Map<String, dynamic>>();
    }
    return [];
  }

  Future<void> addCallToHistory(Map<String, dynamic> call) async {
    final currentHistory = await getCallHistory();
    currentHistory.insert(0, call); // Add to beginning
    await storeCallHistory(currentHistory);
  }

  // Contacts storage
  Future<void> storeContacts(List<Map<String, dynamic>> contacts) async {
    await _prefs.setString(
      AppConstants.keyContacts,
      jsonEncode(contacts),
    );
  }

  Future<List<Map<String, dynamic>>> getContacts() async {
    final contactsJson = _prefs.getString(AppConstants.keyContacts);
    if (contactsJson != null) {
      final List<dynamic> contactsList = jsonDecode(contactsJson);
      return contactsList.cast<Map<String, dynamic>>();
    }
    return [];
  }

  Future<void> addContact(Map<String, dynamic> contact) async {
    final currentContacts = await getContacts();
    currentContacts.add(contact);
    await storeContacts(currentContacts);
  }

  Future<void> updateContact(
      String contactId, Map<String, dynamic> updatedContact) async {
    final currentContacts = await getContacts();
    final index =
        currentContacts.indexWhere((contact) => contact['id'] == contactId);
    if (index != -1) {
      currentContacts[index] = updatedContact;
      await storeContacts(currentContacts);
    }
  }

  Future<void> deleteContact(String contactId) async {
    final currentContacts = await getContacts();
    currentContacts.removeWhere((contact) => contact['id'] == contactId);
    await storeContacts(currentContacts);
  }

  // Voicemail storage
  Future<void> storeVoicemails(List<Map<String, dynamic>> voicemails) async {
    // Limit the number of stored entries
    final limitedVoicemails =
        voicemails.take(AppConstants.maxVoicemailEntries).toList();
    await _prefs.setString(
      AppConstants.keyVoicemails,
      jsonEncode(limitedVoicemails),
    );
  }

  Future<List<Map<String, dynamic>>> getVoicemails() async {
    final voicemailsJson = _prefs.getString(AppConstants.keyVoicemails);
    if (voicemailsJson != null) {
      final List<dynamic> voicemailsList = jsonDecode(voicemailsJson);
      return voicemailsList.cast<Map<String, dynamic>>();
    }
    return [];
  }

  Future<void> addVoicemail(Map<String, dynamic> voicemail) async {
    final currentVoicemails = await getVoicemails();
    currentVoicemails.insert(0, voicemail); // Add to beginning
    await storeVoicemails(currentVoicemails);
  }

  Future<void> markVoicemailAsRead(String voicemailId) async {
    final currentVoicemails = await getVoicemails();
    final index = currentVoicemails.indexWhere((vm) => vm['id'] == voicemailId);
    if (index != -1) {
      currentVoicemails[index]['isRead'] = true;
      await storeVoicemails(currentVoicemails);
    }
  }

  // Generic storage methods
  Future<void> setString(String key, String value) async {
    await _prefs.setString(key, value);
  }

  Future<String?> getString(String key) async {
    return _prefs.getString(key);
  }

  Future<void> setBool(String key, bool value) async {
    await _prefs.setBool(key, value);
  }

  Future<bool?> getBool(String key) async {
    return _prefs.getBool(key);
  }

  Future<void> setInt(String key, int value) async {
    await _prefs.setInt(key, value);
  }

  Future<int?> getInt(String key) async {
    return _prefs.getInt(key);
  }

  Future<void> setDouble(String key, double value) async {
    await _prefs.setDouble(key, value);
  }

  Future<double?> getDouble(String key) async {
    return _prefs.getDouble(key);
  }

  // Clear all data
  Future<void> clearAllData() async {
    await _prefs.clear();
    await _secureStorage.deleteAll();
  }

  // Clear only non-secure data
  Future<void> clearAppData() async {
    await _prefs.clear();
  }

  // Clear call history
  Future<void> clearCallHistory() async {
    await _prefs.remove('call_history');
  }
}
