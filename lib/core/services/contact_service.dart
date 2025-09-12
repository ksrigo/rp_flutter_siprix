import 'package:flutter/foundation.dart';
import 'package:flutter_contacts/flutter_contacts.dart';
import 'package:permission_handler/permission_handler.dart';

class ContactInfo {
  final String displayName;
  final String phoneNumber;
  final Uint8List? photo;
  final bool hasPhoto;

  ContactInfo({
    required this.displayName,
    required this.phoneNumber,
    this.photo,
    this.hasPhoto = false,
  });
}

class ContactService {
  static final ContactService _instance = ContactService._internal();
  static ContactService get instance => _instance;
  ContactService._internal();

  bool _permissionGranted = false;
  List<Contact>? _cachedContacts;

  /// Initialize the contact service and request permissions
  Future<bool> initialize() async {
    try {
      debugPrint('ContactService: Initializing...');
      
      if (kIsWeb) {
        debugPrint('ContactService: Web platform - contacts not supported');
        return false;
      }

      // Check current permission status
      final status = await Permission.contacts.status;
      debugPrint('ContactService: Current permission status: $status');

      if (status == PermissionStatus.granted) {
        _permissionGranted = true;
        // Load contacts in background to avoid blocking
        _loadContacts().catchError((e) {
          debugPrint('ContactService: Background contact loading failed: $e');
        });
        debugPrint('ContactService: Permission granted, loading contacts in background');
        return true;
      }

      // Request permission if not granted
      final requestResult = await Permission.contacts.request();
      debugPrint('ContactService: Permission request result: $requestResult');

      if (requestResult == PermissionStatus.granted) {
        _permissionGranted = true;
        // Load contacts in background to avoid blocking
        _loadContacts().catchError((e) {
          debugPrint('ContactService: Background contact loading failed: $e');
        });
        debugPrint('ContactService: Permission granted after request, loading contacts in background');
        return true;
      }

      debugPrint('ContactService: Permission denied - $requestResult');
      return false;
    } catch (e) {
      debugPrint('ContactService: Error during initialization: $e');
      return false;
    }
  }

  /// Load all contacts from the device
  Future<void> _loadContacts() async {
    try {
      if (!_permissionGranted) {
        debugPrint('ContactService: Cannot load contacts - permission not granted');
        return;
      }

      debugPrint('ContactService: Loading contacts...');
      _cachedContacts = await FlutterContacts.getContacts(
        withProperties: true,
        withPhoto: true,
      );
      debugPrint('ContactService: Loaded ${_cachedContacts?.length ?? 0} contacts');
    } catch (e) {
      debugPrint('ContactService: Error loading contacts: $e');
      _cachedContacts = [];
    }
  }

  /// Find contact information by phone number
  Future<ContactInfo?> findContactByPhoneNumber(String phoneNumber) async {
    try {
      if (!_permissionGranted || _cachedContacts == null) {
        debugPrint('ContactService: Cannot search - permission not granted or contacts not loaded');
        return null;
      }

      // Clean the phone number for comparison (remove spaces, dashes, etc.)
      final cleanedSearchNumber = _cleanPhoneNumber(phoneNumber);
      debugPrint('ContactService: Searching for contact with number: $phoneNumber (cleaned: $cleanedSearchNumber)');

      for (final contact in _cachedContacts!) {
        for (final phone in contact.phones) {
          final cleanedContactNumber = _cleanPhoneNumber(phone.number);
          
          // Check for exact match or if one number ends with the other (for different formats)
          if (cleanedContactNumber == cleanedSearchNumber ||
              cleanedContactNumber.endsWith(cleanedSearchNumber) ||
              cleanedSearchNumber.endsWith(cleanedContactNumber)) {
            
            debugPrint('ContactService: Found contact: ${contact.displayName}');
            
            return ContactInfo(
              displayName: contact.displayName.isNotEmpty ? contact.displayName : phone.number,
              phoneNumber: phone.number,
              photo: contact.photo,
              hasPhoto: contact.photo != null && contact.photo!.isNotEmpty,
            );
          }
        }
      }

      debugPrint('ContactService: No contact found for number: $phoneNumber');
      return null;
    } catch (e) {
      debugPrint('ContactService: Error finding contact: $e');
      return null;
    }
  }

  /// Clean phone number by removing non-digit characters except +
  String _cleanPhoneNumber(String phoneNumber) {
    // Keep only digits and +
    String cleaned = phoneNumber.replaceAll(RegExp(r'[^\d+]'), '');
    
    // Remove leading +, country codes for better matching
    if (cleaned.startsWith('+1')) {
      cleaned = cleaned.substring(2);
    } else if (cleaned.startsWith('+')) {
      // Remove + but keep other country codes for now
      cleaned = cleaned.substring(1);
    }
    
    return cleaned;
  }

  /// Refresh contacts cache
  Future<void> refreshContacts() async {
    if (_permissionGranted) {
      await _loadContacts();
    }
  }

  /// Check if contacts permission is granted
  bool get hasPermission => _permissionGranted;

  /// Get total number of cached contacts
  int get contactCount => _cachedContacts?.length ?? 0;
}