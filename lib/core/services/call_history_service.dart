import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:siprix_voip_sdk/cdrs_model.dart';
import 'package:siprix_voip_sdk/calls_model.dart';

import '../../shared/services/storage_service.dart';

/// Service to manage call history using Siprix CdrsModel
class CallHistoryService extends ChangeNotifier {
  static final CallHistoryService _instance = CallHistoryService._internal();
  static CallHistoryService get instance => _instance;
  CallHistoryService._internal();

  CdrsModel? _cdrsModel;
  bool _isInitialized = false;

  CdrsModel? get cdrsModel => _cdrsModel;
  bool get isInitialized => _isInitialized;

  /// Initialize the call history service
  Future<void> initialize() async {
    try {
      debugPrint('CallHistory: Initializing call history service...');
      
      // Create CdrsModel instance
      _cdrsModel = CdrsModel();
      
      // Set up listener for changes
      _cdrsModel?.addListener(_onCallHistoryChanged);
      
      // Load existing call history from storage
      await _loadCallHistoryFromStorage();
      
      _isInitialized = true;
      debugPrint('CallHistory: Service initialized successfully');
      notifyListeners();
    } catch (e) {
      debugPrint('CallHistory: Error initializing service: $e');
    }
  }

  /// Load call history from persistent storage
  Future<void> _loadCallHistoryFromStorage() async {
    try {
      final storedHistory = await StorageService.instance.getCdrCallHistory();
      if (storedHistory != null && storedHistory.isNotEmpty) {
        _cdrsModel?.loadFromJson(storedHistory);
        debugPrint('CallHistory: Loaded ${_cdrsModel?.length ?? 0} calls from storage');
      }
    } catch (e) {
      debugPrint('CallHistory: Error loading from storage: $e');
    }
  }

  /// Save call history to persistent storage
  Future<void> _saveCallHistoryToStorage() async {
    try {
      if (_cdrsModel != null) {
        final jsonData = _cdrsModel!.storeToJson();
        await StorageService.instance.saveCdrCallHistory(jsonData);
        debugPrint('CallHistory: Saved ${_cdrsModel!.length} calls to storage');
      }
    } catch (e) {
      debugPrint('CallHistory: Error saving to storage: $e');
    }
  }

  /// Handle changes in call history
  void _onCallHistoryChanged() {
    debugPrint('CallHistory: Call history changed, updating listeners');
    _saveCallHistoryToStorage();
    notifyListeners();
  }

  /// Add a new call record
  void addCallRecord(CallModel callModel) {
    try {
      if (_cdrsModel != null) {
        _cdrsModel!.add(callModel);
        debugPrint('CallHistory: Added new call record - CallId: ${callModel.myCallId}');
      }
    } catch (e) {
      debugPrint('CallHistory: Error adding call record: $e');
    }
  }

  /// Get all call records
  List<CdrModel> getAllCalls() {
    if (_cdrsModel == null || _cdrsModel!.isEmpty) {
      return [];
    }
    
    try {
      // Convert to list and sort by date (newest first)
      final calls = <CdrModel>[];
      for (int i = 0; i < _cdrsModel!.length; i++) {
        calls.add(_cdrsModel![i]);
      }
      
      // Sort by madeAt timestamp, newest first
      calls.sort((a, b) => b.madeAt.compareTo(a.madeAt));
      return calls;
    } catch (e) {
      debugPrint('CallHistory: Error getting all calls: $e');
      return [];
    }
  }

  /// Get missed calls only
  List<CdrModel> getMissedCalls() {
    try {
      return getAllCalls().where((call) => 
        call.incoming && !call.connected
      ).toList();
    } catch (e) {
      debugPrint('CallHistory: Error getting missed calls: $e');
      return [];
    }
  }

  /// Get call count
  int get callCount => _cdrsModel?.length ?? 0;

  /// Get missed call count
  int get missedCallCount => getMissedCalls().length;

  /// Clear all call history
  Future<void> clearAllHistory() async {
    try {
      if (_cdrsModel != null) {
        // Clear all records
        while (_cdrsModel!.length > 0) {
          _cdrsModel!.remove(0);
        }
        await _saveCallHistoryToStorage();
        debugPrint('CallHistory: Cleared all call history');
      }
    } catch (e) {
      debugPrint('CallHistory: Error clearing history: $e');
    }
  }

  /// Remove a specific call record
  void removeCallRecord(int index) {
    try {
      if (_cdrsModel != null && index >= 0 && index < _cdrsModel!.length) {
        _cdrsModel!.remove(index);
        debugPrint('CallHistory: Removed call record at index $index');
      }
    } catch (e) {
      debugPrint('CallHistory: Error removing call record: $e');
    }
  }

  /// Get call by ID
  CdrModel? getCallById(int callId) {
    try {
      final calls = getAllCalls();
      for (final call in calls) {
        if (call.myCallId == callId) {
          return call;
        }
      }
      return null;
    } catch (e) {
      debugPrint('CallHistory: Error getting call by ID: $e');
      return null;
    }
  }

  /// Format call duration
  static String formatDuration(String duration) {
    try {
      // Duration comes as seconds, format as MM:SS
      final seconds = int.tryParse(duration) ?? 0;
      final minutes = seconds ~/ 60;
      final remainingSeconds = seconds % 60;
      return '${minutes.toString().padLeft(2, '0')}:${remainingSeconds.toString().padLeft(2, '0')}';
    } catch (e) {
      return '00:00';
    }
  }

  /// Format call date/time
  static String formatCallTime(DateTime dateTime) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final yesterday = today.subtract(const Duration(days: 1));
    final callDate = DateTime(dateTime.year, dateTime.month, dateTime.day);

    if (callDate == today) {
      // Today - show time only
      final hour = dateTime.hour;
      final minute = dateTime.minute.toString().padLeft(2, '0');
      final period = hour >= 12 ? 'PM' : 'AM';
      final displayHour = hour > 12 ? hour - 12 : (hour == 0 ? 12 : hour);
      return 'Today, $displayHour:$minute $period';
    } else if (callDate == yesterday) {
      // Yesterday - show time
      final hour = dateTime.hour;
      final minute = dateTime.minute.toString().padLeft(2, '0');
      final period = hour >= 12 ? 'PM' : 'AM';
      final displayHour = hour > 12 ? hour - 12 : (hour == 0 ? 12 : hour);
      return 'Yesterday, $displayHour:$minute $period';
    } else {
      // Older - show days ago
      final daysDifference = today.difference(callDate).inDays;
      if (daysDifference <= 7) {
        final hour = dateTime.hour;
        final minute = dateTime.minute.toString().padLeft(2, '0');
        final period = hour >= 12 ? 'PM' : 'AM';
        final displayHour = hour > 12 ? hour - 12 : (hour == 0 ? 12 : hour);
        return '$daysDifference days ago, $displayHour:$minute $period';
      } else {
        // Very old - show date
        return '${dateTime.day}/${dateTime.month}/${dateTime.year}';
      }
    }
  }

  /// Get call type icon based on direction and status
  static CallType getCallType(CdrModel call) {
    if (call.incoming) {
      return call.connected ? CallType.incoming : CallType.missed;
    } else {
      return CallType.outgoing;
    }
  }

  @override
  void dispose() {
    _cdrsModel?.removeListener(_onCallHistoryChanged);
    super.dispose();
  }
}

/// Enum for call types
enum CallType {
  incoming,
  outgoing,
  missed,
}