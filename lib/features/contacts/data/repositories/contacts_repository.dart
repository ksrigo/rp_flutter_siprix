import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter_contacts/flutter_contacts.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
import 'package:dio/dio.dart';

import '../../../../core/services/api_service.dart';
import '../../../../core/services/auth_service.dart';
import '../../../../shared/services/storage_service.dart';
import '../models/contact_model.dart';

class ContactsRepository extends ChangeNotifier {
  static final ContactsRepository _instance = ContactsRepository._internal();
  static ContactsRepository get instance => _instance;
  ContactsRepository._internal();

  Database? _database;
  bool _isInitialized = false;
  bool _isDeviceContactsEnabled = false;
  
  // Getters
  bool get isInitialized => _isInitialized;
  bool get isDeviceContactsEnabled => _isDeviceContactsEnabled;

  /// Initialize the contacts repository
  Future<void> initialize() async {
    try {
      debugPrint('ContactsRepository: Initializing...');
      
      await _initializeDatabase();
      await _loadSettings();
      
      _isInitialized = true;
      debugPrint('ContactsRepository: Initialized successfully');
      notifyListeners();
    } catch (e) {
      debugPrint('ContactsRepository: Error initializing: $e');
      rethrow;
    }
  }

  /// Initialize SQLite database
  Future<void> _initializeDatabase() async {
    if (_database != null) return;

    final databasesPath = await getDatabasesPath();
    final path = join(databasesPath, 'contacts.db');
    
    _database = await openDatabase(
      path,
      version: 2,
      onCreate: (db, version) async {
        await db.execute('''
          CREATE TABLE contacts(
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            contact_id TEXT NOT NULL,
            name TEXT NOT NULL,
            display_name TEXT,
            first_name TEXT,
            last_name TEXT,
            company TEXT,
            notes TEXT,
            source TEXT NOT NULL,
            is_favorite INTEGER NOT NULL DEFAULT 0,
            phones TEXT,
            emails TEXT,
            created_at TEXT NOT NULL,
            updated_at TEXT NOT NULL
          )
        ''');
        
        // Create indexes for better performance
        await db.execute('CREATE INDEX idx_contact_id ON contacts(contact_id)');
        await db.execute('CREATE INDEX idx_name ON contacts(name)');
        await db.execute('CREATE INDEX idx_source ON contacts(source)');
        await db.execute('CREATE INDEX idx_is_favorite ON contacts(is_favorite)');
      },
      onUpgrade: (db, oldVersion, newVersion) async {
        if (oldVersion < 2) {
          // Add notes column if upgrading from version 1
          await db.execute('ALTER TABLE contacts ADD COLUMN notes TEXT');
        }
      },
    );
    
    debugPrint('ContactsRepository: SQLite database initialized');
  }

  /// Load settings from storage
  Future<void> _loadSettings() async {
    _isDeviceContactsEnabled = await StorageService.instance.getBool('device_contacts_enabled') ?? false;
    
    if (_isDeviceContactsEnabled) {
      await _enableDeviceContactsSync();
    }
  }

  /// Enable device contacts sync
  Future<void> enableDeviceContacts() async {
    try {
      _isDeviceContactsEnabled = true;
      await StorageService.instance.setBool('device_contacts_enabled', true);
      await _enableDeviceContactsSync();
      notifyListeners();
    } catch (e) {
      debugPrint('ContactsRepository: Error enabling device contacts: $e');
      rethrow;
    }
  }

  /// Disable device contacts sync
  Future<void> disableDeviceContacts() async {
    try {
      _isDeviceContactsEnabled = false;
      await StorageService.instance.setBool('device_contacts_enabled', false);
      
      // Remove all device contacts from cache
      await _database?.delete(
        'contacts',
        where: 'source = ?',
        whereArgs: ['device'],
      );
      
      notifyListeners();
    } catch (e) {
      debugPrint('ContactsRepository: Error disabling device contacts: $e');
      rethrow;
    }
  }

  /// Enable device contacts synchronization
  Future<void> _enableDeviceContactsSync() async {
    if (!_isDeviceContactsEnabled) return;

    // Request permissions
    final permission = await _requestContactsPermission();
    if (!permission) {
      debugPrint('ContactsRepository: Contacts permission denied');
      return;
    }

    // Initial sync
    await syncDeviceContacts();
  }

  /// Request contacts permission
  Future<bool> _requestContactsPermission() async {
    if (kIsWeb) return false;
    
    final status = await Permission.contacts.status;
    if (status.isGranted) return true;
    
    if (status.isDenied) {
      final result = await Permission.contacts.request();
      return result.isGranted;
    }
    
    return false;
  }

  /// Fetch contacts from API
  Future<void> fetchApiContacts() async {
    try {
      debugPrint('ContactsRepository: Fetching API contacts...');
      
      final authService = AuthService.instance;
      final apiService = ApiService.instance;
      
      if (!authService.isAuthenticated || authService.extensionDetails == null) {
        debugPrint('ContactsRepository: Not authenticated or no extension');
        return;
      }

      final extensionId = authService.extensionDetails!.id;
      final response = await apiService.getAuthenticated('/extension/$extensionId/contacts');
      
      // Check if authentication failed (response is null)
      if (response == null) {
        debugPrint('ContactsRepository: Authentication failed - redirected to login');
        return;
      }
      
      // Only process if response is 200 OK, ignore other status codes
      if (response.statusCode == 200) {
        if (response.data is Map && response.data['contacts'] is List) {
          final contactsJson = response.data['contacts'] as List;
          
          // Get existing favorite status before removing contacts
          final existingFavorites = <String, bool>{};
          final existingContacts = await _database?.query(
            'contacts',
            columns: ['contact_id', 'is_favorite'],
            where: 'source = ?',
            whereArgs: ['api'],
          );
          
          if (existingContacts != null) {
            for (final row in existingContacts) {
              if (row['is_favorite'] == 1) {
                existingFavorites[row['contact_id'] as String] = true;
              }
            }
          }
          
          // Remove old API contacts
          await _database?.delete(
            'contacts',
            where: 'source = ?',
            whereArgs: ['api'],
          );
          
          // Add new API contacts with preserved favorite status
          final batch = _database?.batch();
          for (final json in contactsJson) {
            final contact = ContactModel.fromApiJson(json);
            
            // Preserve local favorite status if it was set
            final contactId = contact.contactId;
            if (existingFavorites.containsKey(contactId)) {
              contact.isFavorite = existingFavorites[contactId]!;
            }
            
            batch?.insert('contacts', contact.toMap());
          }
          await batch?.commit();
          
          debugPrint('ContactsRepository: Fetched ${contactsJson.length} API contacts');
          notifyListeners();
        } else if (response.data is List) {
          // Handle case where response is directly an array of contacts
          final contactsJson = response.data as List;
          
          // Get existing favorite status before removing contacts
          final existingFavorites = <String, bool>{};
          final existingContacts = await _database?.query(
            'contacts',
            columns: ['contact_id', 'is_favorite'],
            where: 'source = ?',
            whereArgs: ['api'],
          );
          
          if (existingContacts != null) {
            for (final row in existingContacts) {
              if (row['is_favorite'] == 1) {
                existingFavorites[row['contact_id'] as String] = true;
              }
            }
          }
          
          // Remove old API contacts
          await _database?.delete(
            'contacts',
            where: 'source = ?',
            whereArgs: ['api'],
          );
          
          // Add new API contacts with preserved favorite status
          final batch = _database?.batch();
          for (final json in contactsJson) {
            final contact = ContactModel.fromApiJson(json);
            
            // Preserve local favorite status if it was set
            final contactId = contact.contactId;
            if (existingFavorites.containsKey(contactId)) {
              contact.isFavorite = existingFavorites[contactId]!;
            }
            
            batch?.insert('contacts', contact.toMap());
          }
          await batch?.commit();
          
          debugPrint('ContactsRepository: Fetched ${contactsJson.length} API contacts');
          notifyListeners();
        } else {
          debugPrint('ContactsRepository: No contacts found in API response');
        }
      } else {
        debugPrint('ContactsRepository: API returned status ${response.statusCode}, ignoring response');
      }
    } catch (e) {
      // Check if it's a DioException with a non-200 status code
      if (e is DioException && e.response != null && e.response!.statusCode != 200) {
        debugPrint('ContactsRepository: API returned status ${e.response!.statusCode}, ignoring response');
        // Don't rethrow for expected non-200 responses
        return;
      }
      
      // Rethrow only for actual network/parsing errors (connection issues, timeouts, etc.)
      debugPrint('ContactsRepository: Error fetching API contacts: $e');
      rethrow;
    }
  }

  /// Sync device contacts
  Future<void> syncDeviceContacts() async {
    if (!_isDeviceContactsEnabled) return;
    
    try {
      debugPrint('ContactsRepository: Syncing device contacts...');
      
      final permission = await _requestContactsPermission();
      if (!permission) {
        debugPrint('ContactsRepository: No contacts permission');
        return;
      }

      // Fetch all device contacts with details
      final deviceContacts = await FlutterContacts.getContacts(
        withProperties: true,
        withPhoto: false,
      );

      // Remove old device contacts
      await _database?.delete(
        'contacts',
        where: 'source = ?',
        whereArgs: ['device'],
      );
      
      // Add new device contacts
      final batch = _database?.batch();
      for (final deviceContact in deviceContacts) {
        if (deviceContact.phones.isNotEmpty) {
          final contact = ContactModel.fromDeviceContact(deviceContact);
          batch?.insert('contacts', contact.toMap());
        }
      }
      await batch?.commit();
      
      debugPrint('ContactsRepository: Synced ${deviceContacts.length} device contacts');
      notifyListeners();
    } catch (e) {
      debugPrint('ContactsRepository: Error syncing device contacts: $e');
      rethrow;
    }
  }

  /// Refresh all contacts (API + Device)
  Future<void> refreshContacts() async {
    try {
      debugPrint('ContactsRepository: Refreshing all contacts...');
      
      // Fetch API contacts
      await fetchApiContacts();
      
      // Sync device contacts if enabled
      if (_isDeviceContactsEnabled) {
        await syncDeviceContacts();
      }
      
      debugPrint('ContactsRepository: Contacts refreshed successfully');
    } catch (e) {
      debugPrint('ContactsRepository: Error refreshing contacts: $e');
      rethrow;
    }
  }

  /// Get all contacts
  Stream<List<ContactModel>> getAllContacts() {
    if (_database == null) return Stream.value([]);
    
    late StreamController<List<ContactModel>> controller;
    
    controller = StreamController<List<ContactModel>>(
      onListen: () async {
        try {
          final List<Map<String, dynamic>> maps = await _database!.query(
            'contacts',
            orderBy: 'name COLLATE NOCASE ASC',
          );
          
          final contacts = maps.map((map) => ContactModel.fromMap(map)).toList();
          controller.add(contacts);
        } catch (e) {
          controller.addError(e);
        }
      },
    );
    
    // Listen to changes and refresh
    addListener(() async {
      try {
        final List<Map<String, dynamic>> maps = await _database!.query(
          'contacts',
          orderBy: 'name COLLATE NOCASE ASC',
        );
        
        final contacts = maps.map((map) => ContactModel.fromMap(map)).toList();
        controller.add(contacts);
      } catch (e) {
        controller.addError(e);
      }
    });
    
    return controller.stream;
  }

  /// Get favorite contacts
  Stream<List<ContactModel>> getFavoriteContacts() {
    if (_database == null) return Stream.value([]);
    
    late StreamController<List<ContactModel>> controller;
    
    controller = StreamController<List<ContactModel>>(
      onListen: () async {
        try {
          final List<Map<String, dynamic>> maps = await _database!.query(
            'contacts',
            where: 'is_favorite = ?',
            whereArgs: [1],
            orderBy: 'name COLLATE NOCASE ASC',
          );
          
          final contacts = maps.map((map) => ContactModel.fromMap(map)).toList();
          controller.add(contacts);
        } catch (e) {
          controller.addError(e);
        }
      },
    );
    
    // Listen to changes and refresh
    addListener(() async {
      try {
        final List<Map<String, dynamic>> maps = await _database!.query(
          'contacts',
          where: 'is_favorite = ?',
          whereArgs: [1],
          orderBy: 'name COLLATE NOCASE ASC',
        );
        
        final contacts = maps.map((map) => ContactModel.fromMap(map)).toList();
        controller.add(contacts);
      } catch (e) {
        controller.addError(e);
      }
    });
    
    return controller.stream;
  }

  /// Search contacts
  Stream<List<ContactModel>> searchContacts(String query) {
    if (_database == null) return Stream.value([]);
    
    if (query.isEmpty) {
      return getAllContacts();
    }
    
    late StreamController<List<ContactModel>> controller;
    
    controller = StreamController<List<ContactModel>>(
      onListen: () async {
        try {
          final lowerQuery = query.toLowerCase();
          final List<Map<String, dynamic>> maps = await _database!.query(
            'contacts',
            where: '''
              LOWER(name) LIKE ? OR 
              LOWER(display_name) LIKE ? OR 
              LOWER(first_name) LIKE ? OR 
              LOWER(last_name) LIKE ?
            ''',
            whereArgs: [
              '%$lowerQuery%',
              '%$lowerQuery%',
              '%$lowerQuery%',
              '%$lowerQuery%',
            ],
            orderBy: 'name COLLATE NOCASE ASC',
          );
          
          final contacts = maps.map((map) => ContactModel.fromMap(map)).toList();
          controller.add(contacts);
        } catch (e) {
          controller.addError(e);
        }
      },
    );
    
    return controller.stream;
  }

  /// Add contact to API phonebook
  Future<ContactModel?> addApiContact(ContactModel contact) async {
    try {
      debugPrint('ContactsRepository: Adding API contact...');
      
      final authService = AuthService.instance;
      final apiService = ApiService.instance;
      
      if (!authService.isAuthenticated || authService.extensionDetails == null) {
        throw Exception('Not authenticated');
      }

      final extensionId = authService.extensionDetails!.id;
      final response = await apiService.postAuthenticated(
        '/extension/$extensionId/contacts',
        data: contact.toApiJson(),
      );
      
      // Check if authentication failed (response is null)
      if (response == null) {
        debugPrint('ContactsRepository: Authentication failed during contact creation');
        throw Exception('Authentication failed');
      }
      
      if (response.statusCode == 200 || response.statusCode == 201 || response.statusCode == 202) {
        // Parse the created contact from response
        final createdContact = ContactModel.fromApiJson(response.data);
        
        // Add to local cache
        final id = await _database?.insert('contacts', createdContact.toMap());
        createdContact.id = id;
        
        debugPrint('ContactsRepository: API contact added successfully');
        notifyListeners();
        return createdContact;
      } else {
        throw Exception('Failed to create contact: ${response.statusCode}');
      }
    } catch (e) {
      debugPrint('ContactsRepository: Error adding API contact: $e');
      rethrow;
    }
  }

  /// Update contact in API phonebook
  Future<ContactModel?> updateApiContact(ContactModel contact) async {
    try {
      debugPrint('ContactsRepository: Updating API contact...');
      
      final authService = AuthService.instance;
      final apiService = ApiService.instance;
      
      if (!authService.isAuthenticated) {
        throw Exception('Not authenticated');
      }

      final response = await apiService.patchAuthenticated(
        '/contact/${contact.contactId}',
        data: contact.toApiJson(),
      );
      
      // Check if authentication failed (response is null)
      if (response == null) {
        debugPrint('ContactsRepository: Authentication failed during contact update');
        throw Exception('Authentication failed');
      }
      
      if (response.statusCode == 200 || response.statusCode == 201 || response.statusCode == 202) {
        // Parse the updated contact from response
        final updatedContact = ContactModel.fromApiJson(response.data);
        
        // Update in local cache
        await _database?.update(
          'contacts',
          updatedContact.toMap(),
          where: 'contact_id = ?',
          whereArgs: [contact.contactId],
        );
        
        debugPrint('ContactsRepository: API contact updated successfully');
        notifyListeners();
        return updatedContact;
      } else {
        throw Exception('Failed to update contact: ${response.statusCode}');
      }
    } catch (e) {
      debugPrint('ContactsRepository: Error updating API contact: $e');
      rethrow;
    }
  }

  /// Delete contact from API phonebook
  Future<void> deleteApiContact(String contactId) async {
    try {
      debugPrint('ContactsRepository: Deleting API contact...');
      
      final authService = AuthService.instance;
      final apiService = ApiService.instance;
      
      if (!authService.isAuthenticated) {
        throw Exception('Not authenticated');
      }

      final response = await apiService.deleteAuthenticated('/contact/$contactId');
      
      // Check if authentication failed (response is null)
      if (response == null) {
        debugPrint('ContactsRepository: Authentication failed during contact deletion');
        throw Exception('Authentication failed');
      }
      
      if (response.statusCode == 200 || response.statusCode == 202 || response.statusCode == 204) {
        // Remove from local cache
        await _database?.delete(
          'contacts',
          where: 'contact_id = ?',
          whereArgs: [contactId],
        );
        
        debugPrint('ContactsRepository: API contact deleted successfully');
        notifyListeners();
      } else {
        throw Exception('Failed to delete contact: ${response.statusCode}');
      }
    } catch (e) {
      debugPrint('ContactsRepository: Error deleting API contact: $e');
      rethrow;
    }
  }

  /// Update contact favorite status
  Future<void> updateContactFavorite(String contactId, bool isFavorite) async {
    try {
      await _database?.update(
        'contacts',
        {
          'is_favorite': isFavorite ? 1 : 0,
          'updated_at': DateTime.now().toIso8601String(),
        },
        where: 'contact_id = ?',
        whereArgs: [contactId],
      );
      
      // TODO: Sync with API if it's an API contact
      
      notifyListeners();
    } catch (e) {
      debugPrint('ContactsRepository: Error updating contact favorite: $e');
      rethrow;
    }
  }

  /// Get contact by phone number
  Future<ContactModel?> getContactByPhone(String phoneNumber) async {
    if (_database == null) return null;
    
    try {
      // Clean the phone number for comparison
      final cleanNumber = phoneNumber.replaceAll(RegExp(r'[^\d+]'), '');
      
      final List<Map<String, dynamic>> maps = await _database!.query('contacts');
      
      for (final map in maps) {
        final contact = ContactModel.fromMap(map);
        for (final phone in contact.phones) {
          final cleanContactNumber = phone.number.replaceAll(RegExp(r'[^\d+]'), '');
          if (cleanContactNumber.contains(cleanNumber) || cleanNumber.contains(cleanContactNumber)) {
            return contact;
          }
        }
      }
      
      return null;
    } catch (e) {
      debugPrint('ContactsRepository: Error getting contact by phone: $e');
      return null;
    }
  }

  /// Get contacts count
  Future<int> getContactsCount() async {
    final result = await _database?.rawQuery('SELECT COUNT(*) as count FROM contacts');
    return Sqflite.firstIntValue(result ?? []) ?? 0;
  }

  /// Get API contacts count
  Future<int> getApiContactsCount() async {
    final result = await _database?.rawQuery(
      'SELECT COUNT(*) as count FROM contacts WHERE source = ?',
      ['api'],
    );
    return Sqflite.firstIntValue(result ?? []) ?? 0;
  }

  /// Get device contacts count
  Future<int> getDeviceContactsCount() async {
    final result = await _database?.rawQuery(
      'SELECT COUNT(*) as count FROM contacts WHERE source = ?',
      ['device'],
    );
    return Sqflite.firstIntValue(result ?? []) ?? 0;
  }

  @override
  void dispose() {
    _database?.close();
    super.dispose();
  }
}