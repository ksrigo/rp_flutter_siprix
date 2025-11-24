import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
import 'package:dio/dio.dart';

import '../../../../core/services/api_service.dart';
import '../../../../core/services/auth_service.dart';
import '../models/voicemail_model.dart';

class VoicemailRepository extends ChangeNotifier {
  static final VoicemailRepository _instance = VoicemailRepository._internal();
  static VoicemailRepository get instance => _instance;
  VoicemailRepository._internal();

  Database? _database;
  bool _isInitialized = false;
  bool _isSyncing = false;
  DateTime? _lastSyncTime;

  // Getters
  bool get isInitialized => _isInitialized;
  bool get isSyncing => _isSyncing;
  DateTime? get lastSyncTime => _lastSyncTime;

  /// Initialize the voicemail repository
  Future<void> initialize() async {
    try {
      debugPrint('VoicemailRepository: Initializing...');

      await _initializeDatabase();

      _isInitialized = true;
      debugPrint('VoicemailRepository: Initialized successfully');
      notifyListeners();
    } catch (e) {
      debugPrint('VoicemailRepository: Error initializing: $e');
      rethrow;
    }
  }

  /// Initialize SQLite database
  Future<void> _initializeDatabase() async {
    if (_database != null) return;

    final databasesPath = await getDatabasesPath();
    final path = join(databasesPath, 'voicemails.db');

    _database = await openDatabase(
      path,
      version: 2,
      onCreate: (db, version) async {
        await db.execute('''
          CREATE TABLE voicemails(
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            uuid TEXT UNIQUE NOT NULL,
            req_user TEXT NOT NULL,
            realm TEXT NOT NULL,
            from_name TEXT,
            from_user TEXT NOT NULL,
            duration INTEGER NOT NULL,
            created TEXT NOT NULL,
            read_on TEXT,
            is_saved INTEGER DEFAULT 0
          )
        ''');

        // Create indexes for better performance
        await db.execute('CREATE INDEX idx_uuid ON voicemails(uuid)');
        await db.execute('CREATE INDEX idx_req_user ON voicemails(req_user)');
        await db.execute('CREATE INDEX idx_created ON voicemails(created DESC)');
        await db.execute('CREATE INDEX idx_read_on ON voicemails(read_on)');
        await db.execute('CREATE INDEX idx_is_saved ON voicemails(is_saved)');
      },
      onUpgrade: (db, oldVersion, newVersion) async {
        if (oldVersion < 2) {
          // Add is_saved column for version 2
          await db.execute('ALTER TABLE voicemails ADD COLUMN is_saved INTEGER DEFAULT 0');
          await db.execute('CREATE INDEX idx_is_saved ON voicemails(is_saved)');
          debugPrint('VoicemailRepository: Migrated database to version 2');
        }
      },
    );

    debugPrint('VoicemailRepository: SQLite database initialized');
  }

  /// Fetch voicemails from API and update cache
  Future<List<VoicemailModel>> fetchAndCacheVoicemails(
      {bool forceRefresh = false}) async {
    if (!_isInitialized) {
      await initialize();
    }

    // Check if we should fetch from API
    final shouldFetch = forceRefresh ||
        _lastSyncTime == null ||
        DateTime.now().difference(_lastSyncTime!).inMinutes > 5;

    if (!shouldFetch) {
      debugPrint(
          'VoicemailRepository: Using cached data (last sync: $_lastSyncTime)');
      return getCachedVoicemails();
    }

    try {
      _isSyncing = true;
      notifyListeners();

      final extensionDetails = AuthService.instance.extensionDetails;
      if (extensionDetails == null) {
        throw Exception('Extension details not available');
      }

      final extensionId = extensionDetails.id;
      debugPrint(
          'VoicemailRepository: Fetching voicemails for extension $extensionId');

      final response = await ApiService.instance.getAuthenticated(
        '/extension/$extensionId/voice_mails',
      );

      if (response == null) {
        debugPrint(
            'VoicemailRepository: Authentication failed - redirected to login');
        // Return cached data as fallback
        return getCachedVoicemails();
      }

      if (response.statusCode == 200 && response.data != null) {
        final List<dynamic> data = response.data as List<dynamic>;
        final voicemails = data
            .map((json) => VoicemailModel.fromJson(json as Map<String, dynamic>))
            .toList();

        debugPrint(
            'VoicemailRepository: Fetched ${voicemails.length} voicemails from API');

        // Update cache
        await _updateCache(voicemails);

        _lastSyncTime = DateTime.now();
        debugPrint('VoicemailRepository: Cache updated successfully');

        return voicemails;
      } else {
        debugPrint(
            'VoicemailRepository: Failed to fetch voicemails - Status: ${response.statusCode}');
        // Return cached data as fallback
        return getCachedVoicemails();
      }
    } on DioException catch (e) {
      debugPrint(
          'VoicemailRepository: Network error fetching voicemails: ${e.message}');
      // Return cached data when offline
      return getCachedVoicemails();
    } catch (e) {
      debugPrint('VoicemailRepository: Error fetching voicemails: $e');
      // Return cached data as fallback
      return getCachedVoicemails();
    } finally {
      _isSyncing = false;
      notifyListeners();
    }
  }

  /// Update cache with fetched voicemails
  Future<void> _updateCache(List<VoicemailModel> voicemails) async {
    if (_database == null) return;

    final extensionDetails = AuthService.instance.extensionDetails;
    if (extensionDetails == null) return;

    final reqUser = extensionDetails.extension;

    final batch = _database!.batch();

    // Clear existing voicemails for this extension
    batch.delete(
      'voicemails',
      where: 'req_user = ?',
      whereArgs: [reqUser],
    );

    // Insert new voicemails
    for (final voicemail in voicemails) {
      batch.insert(
        'voicemails',
        voicemail.toMap(),
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
    }

    await batch.commit(noResult: true);
    debugPrint('VoicemailRepository: Cached ${voicemails.length} voicemails');
  }

  /// Get cached voicemails from SQLite
  Future<List<VoicemailModel>> getCachedVoicemails() async {
    if (_database == null) {
      await initialize();
    }

    final extensionDetails = AuthService.instance.extensionDetails;
    if (extensionDetails == null) {
      debugPrint('VoicemailRepository: No extension details available');
      return [];
    }

    final reqUser = extensionDetails.extension;

    final List<Map<String, dynamic>> maps = await _database!.query(
      'voicemails',
      where: 'req_user = ?',
      whereArgs: [reqUser],
      orderBy: 'created DESC',
    );

    final voicemails =
        maps.map((map) => VoicemailModel.fromMap(map)).toList();

    debugPrint(
        'VoicemailRepository: Retrieved ${voicemails.length} cached voicemails');
    return voicemails;
  }

  /// Mark voicemail as read
  Future<void> markAsRead(String uuid) async {
    if (_database == null) return;

    await _database!.update(
      'voicemails',
      {'read_on': DateTime.now().toIso8601String()},
      where: 'uuid = ?',
      whereArgs: [uuid],
    );

    debugPrint('VoicemailRepository: Marked voicemail $uuid as read');
    notifyListeners();

    // TODO: Also update on server via API
  }

  /// Save voicemail
  Future<void> saveVoicemail(String uuid) async {
    if (_database == null) return;

    await _database!.update(
      'voicemails',
      {'is_saved': 1},
      where: 'uuid = ?',
      whereArgs: [uuid],
    );

    debugPrint('VoicemailRepository: Saved voicemail $uuid');
    notifyListeners();

    // TODO: Also update on server via API if needed
  }

  /// Unsave voicemail
  Future<void> unsaveVoicemail(String uuid) async {
    if (_database == null) return;

    await _database!.update(
      'voicemails',
      {'is_saved': 0},
      where: 'uuid = ?',
      whereArgs: [uuid],
    );

    debugPrint('VoicemailRepository: Unsaved voicemail $uuid');
    notifyListeners();

    // TODO: Also update on server via API if needed
  }

  /// Delete voicemail
  Future<void> deleteVoicemail(String uuid) async {
    if (_database == null) return;

    await _database!.delete(
      'voicemails',
      where: 'uuid = ?',
      whereArgs: [uuid],
    );

    debugPrint('VoicemailRepository: Deleted voicemail $uuid from cache');
    notifyListeners();

    // TODO: Also delete on server via API
  }

  /// Delete multiple voicemails
  Future<void> deleteVoicemails(List<String> uuids) async {
    if (_database == null || uuids.isEmpty) return;

    final batch = _database!.batch();

    for (final uuid in uuids) {
      batch.delete(
        'voicemails',
        where: 'uuid = ?',
        whereArgs: [uuid],
      );
    }

    await batch.commit(noResult: true);

    debugPrint(
        'VoicemailRepository: Deleted ${uuids.length} voicemails from cache');
    notifyListeners();

    // TODO: Also delete on server via API
  }

  /// Clear all cached voicemails
  Future<void> clearCache() async {
    if (_database == null) return;

    await _database!.delete('voicemails');
    debugPrint('VoicemailRepository: Cleared all cached voicemails');
    notifyListeners();
  }

  /// Dispose resources
  Future<void> dispose() async {
    await _database?.close();
    _database = null;
    _isInitialized = false;
    super.dispose();
  }
}
