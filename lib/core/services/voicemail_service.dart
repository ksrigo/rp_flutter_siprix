import 'package:flutter/foundation.dart';

import '../../features/voicemail/data/models/voicemail_model.dart';
import '../../features/voicemail/data/repositories/voicemail_repository.dart';

class VoicemailService extends ChangeNotifier {
  static final VoicemailService _instance = VoicemailService._internal();
  static VoicemailService get instance => _instance;
  VoicemailService._internal();

  final VoicemailRepository _repository = VoicemailRepository.instance;

  List<VoicemailModel> _voicemails = [];
  bool _isLoading = false;
  String? _error;

  // Getters
  List<VoicemailModel> get voicemails => _voicemails;
  bool get isLoading => _isLoading;
  String? get error => _error;
  bool get isSyncing => _repository.isSyncing;
  DateTime? get lastSyncTime => _repository.lastSyncTime;

  // Filtered getters
  List<VoicemailModel> get unreadVoicemails =>
      _voicemails.where((v) => v.isUnread).toList();

  List<VoicemailModel> get savedVoicemails =>
      _voicemails.where((v) => v.isSaved).toList();

  int get unreadCount => unreadVoicemails.length;

  /// Initialize the service
  Future<void> initialize() async {
    try {
      debugPrint('VoicemailService: Initializing...');

      await _repository.initialize();

      // Load cached voicemails first
      await loadCachedVoicemails();

      // Set up repository listener
      _repository.addListener(_onRepositoryChanged);

      debugPrint('VoicemailService: Initialized successfully');
    } catch (e) {
      debugPrint('VoicemailService: Error initializing: $e');
      _error = e.toString();
      notifyListeners();
    }
  }

  /// Load cached voicemails
  Future<void> loadCachedVoicemails() async {
    try {
      _voicemails = await _repository.getCachedVoicemails();
      _error = null;
      notifyListeners();
      debugPrint(
          'VoicemailService: Loaded ${_voicemails.length} cached voicemails');
    } catch (e) {
      debugPrint('VoicemailService: Error loading cached voicemails: $e');
      _error = e.toString();
      notifyListeners();
    }
  }

  /// Fetch voicemails from API and update cache
  Future<void> fetchVoicemails({bool forceRefresh = false}) async {
    try {
      _isLoading = true;
      _error = null;
      notifyListeners();

      debugPrint(
          'VoicemailService: Fetching voicemails (forceRefresh: $forceRefresh)...');

      _voicemails =
          await _repository.fetchAndCacheVoicemails(forceRefresh: forceRefresh);

      _error = null;
      debugPrint('VoicemailService: Fetched ${_voicemails.length} voicemails');
    } catch (e) {
      debugPrint('VoicemailService: Error fetching voicemails: $e');
      _error = e.toString();

      // Try to load from cache as fallback
      await loadCachedVoicemails();
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  /// Refresh voicemails (force refresh)
  Future<void> refreshVoicemails() async {
    await fetchVoicemails(forceRefresh: true);
  }

  /// Mark voicemail as read
  Future<void> markAsRead(String uuid) async {
    try {
      await _repository.markAsRead(uuid);

      // Update local list
      final index = _voicemails.indexWhere((v) => v.uuid == uuid);
      if (index != -1) {
        _voicemails[index] = _voicemails[index].copyWith(
          readOn: DateTime.now(),
        );
        notifyListeners();
      }

      debugPrint('VoicemailService: Marked voicemail $uuid as read');
    } catch (e) {
      debugPrint('VoicemailService: Error marking voicemail as read: $e');
      rethrow;
    }
  }

  /// Save voicemail
  Future<void> saveVoicemail(String uuid) async {
    try {
      await _repository.saveVoicemail(uuid);

      // Update local list
      final index = _voicemails.indexWhere((v) => v.uuid == uuid);
      if (index != -1) {
        _voicemails[index] = _voicemails[index].copyWith(
          isSaved: true,
        );
        notifyListeners();
      }

      debugPrint('VoicemailService: Saved voicemail $uuid');
    } catch (e) {
      debugPrint('VoicemailService: Error saving voicemail: $e');
      rethrow;
    }
  }

  /// Unsave voicemail
  Future<void> unsaveVoicemail(String uuid) async {
    try {
      await _repository.unsaveVoicemail(uuid);

      // Update local list
      final index = _voicemails.indexWhere((v) => v.uuid == uuid);
      if (index != -1) {
        _voicemails[index] = _voicemails[index].copyWith(
          isSaved: false,
        );
        notifyListeners();
      }

      debugPrint('VoicemailService: Unsaved voicemail $uuid');
    } catch (e) {
      debugPrint('VoicemailService: Error unsaving voicemail: $e');
      rethrow;
    }
  }

  /// Delete single voicemail
  Future<void> deleteVoicemail(String uuid) async {
    try {
      await _repository.deleteVoicemail(uuid);

      // Update local list
      _voicemails.removeWhere((v) => v.uuid == uuid);
      notifyListeners();

      debugPrint('VoicemailService: Deleted voicemail $uuid');
    } catch (e) {
      debugPrint('VoicemailService: Error deleting voicemail: $e');
      rethrow;
    }
  }

  /// Delete multiple voicemails
  Future<void> deleteVoicemails(List<String> uuids) async {
    try {
      await _repository.deleteVoicemails(uuids);

      // Update local list
      _voicemails.removeWhere((v) => uuids.contains(v.uuid));
      notifyListeners();

      debugPrint('VoicemailService: Deleted ${uuids.length} voicemails');
    } catch (e) {
      debugPrint('VoicemailService: Error deleting voicemails: $e');
      rethrow;
    }
  }

  /// Get voicemail by UUID
  VoicemailModel? getVoicemailByUuid(String uuid) {
    try {
      return _voicemails.firstWhere((v) => v.uuid == uuid);
    } catch (e) {
      return null;
    }
  }

  /// Handle repository changes
  void _onRepositoryChanged() {
    debugPrint('VoicemailService: Repository changed, reloading voicemails');
    loadCachedVoicemails();
  }

  /// Clear all data
  Future<void> clearData() async {
    try {
      await _repository.clearCache();
      _voicemails = [];
      _error = null;
      notifyListeners();
      debugPrint('VoicemailService: Cleared all data');
    } catch (e) {
      debugPrint('VoicemailService: Error clearing data: $e');
      rethrow;
    }
  }

  @override
  void dispose() {
    _repository.removeListener(_onRepositoryChanged);
    super.dispose();
  }
}
