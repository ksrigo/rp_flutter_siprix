import 'dart:async';
import 'package:flutter/foundation.dart';

import '../../features/contacts/data/models/contact_model.dart';
import '../../features/contacts/data/repositories/contacts_repository.dart';

/// Centralized contacts service for the app
class ContactsService extends ChangeNotifier {
  static final ContactsService _instance = ContactsService._internal();
  static ContactsService get instance => _instance;
  ContactsService._internal();

  final ContactsRepository _repository = ContactsRepository.instance;
  bool _isInitialized = false;

  // Getters
  bool get isInitialized => _isInitialized;
  bool get isDeviceContactsEnabled => _repository.isDeviceContactsEnabled;

  /// Initialize the contacts service
  Future<void> initialize() async {
    try {
      debugPrint('ContactsService: Initializing...');
      
      await _repository.initialize();
      
      // Listen to repository changes
      _repository.addListener(_onRepositoryChanged);
      
      // Initial data fetch
      await refreshContacts();
      
      _isInitialized = true;
      debugPrint('ContactsService: Initialized successfully');
      notifyListeners();
    } catch (e) {
      debugPrint('ContactsService: Error initializing: $e');
      rethrow;
    }
  }

  /// Initialize the contacts service without making API call (cache only)
  Future<void> initializeWithoutApiCall() async {
    try {
      debugPrint('ContactsService: Initializing without API call...');
      
      await _repository.initialize();
      
      // Listen to repository changes
      _repository.addListener(_onRepositoryChanged);
      
      _isInitialized = true;
      debugPrint('ContactsService: Initialized successfully (cache only)');
      notifyListeners();
    } catch (e) {
      debugPrint('ContactsService: Error initializing: $e');
      rethrow;
    }
  }

  /// Handle repository changes
  void _onRepositoryChanged() {
    notifyListeners();
  }

  /// Refresh all contacts
  Future<void> refreshContacts() async {
    try {
      await _repository.refreshContacts();
    } catch (e) {
      debugPrint('ContactsService: Error refreshing contacts: $e');
      rethrow;
    }
  }

  /// Enable device contacts
  Future<void> enableDeviceContacts() async {
    try {
      await _repository.enableDeviceContacts();
    } catch (e) {
      debugPrint('ContactsService: Error enabling device contacts: $e');
      rethrow;
    }
  }

  /// Disable device contacts
  Future<void> disableDeviceContacts() async {
    try {
      await _repository.disableDeviceContacts();
    } catch (e) {
      debugPrint('ContactsService: Error disabling device contacts: $e');
      rethrow;
    }
  }

  /// Get all contacts stream
  Stream<List<ContactModel>> getAllContacts() {
    return _repository.getAllContacts();
  }

  /// Get favorite contacts stream
  Stream<List<ContactModel>> getFavoriteContacts() {
    return _repository.getFavoriteContacts();
  }

  /// Search contacts
  Stream<List<ContactModel>> searchContacts(String query) {
    return _repository.searchContacts(query);
  }

  /// Get contact by phone number
  Future<ContactModel?> getContactByPhone(String phoneNumber) async {
    return await _repository.getContactByPhone(phoneNumber);
  }

  /// Add contact to API phonebook
  Future<ContactModel?> addApiContact(ContactModel contact) async {
    return await _repository.addApiContact(contact);
  }

  /// Update contact favorite status
  Future<void> updateContactFavorite(String contactId, bool isFavorite) async {
    await _repository.updateContactFavorite(contactId, isFavorite);
  }

  /// Get contacts count
  Future<int> getContactsCount() async {
    return await _repository.getContactsCount();
  }

  /// Get API contacts count
  Future<int> getApiContactsCount() async {
    return await _repository.getApiContactsCount();
  }

  /// Get device contacts count
  Future<int> getDeviceContactsCount() async {
    return await _repository.getDeviceContactsCount();
  }

  /// Manually sync device contacts
  Future<void> syncDeviceContacts() async {
    try {
      await _repository.syncDeviceContacts();
    } catch (e) {
      debugPrint('ContactsService: Error syncing device contacts: $e');
      rethrow;
    }
  }

  @override
  void dispose() {
    _repository.removeListener(_onRepositoryChanged);
    _repository.dispose();
    super.dispose();
  }
}