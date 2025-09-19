import 'dart:convert';

class ContactModel {
  int? id;
  late String contactId;
  late String name;
  String? displayName;
  String? firstName;
  String? lastName;
  String? company;
  String? notes;
  List<ContactPhoneModel> phones = [];
  List<ContactEmailModel> emails = [];
  late ContactSource source;
  bool isFavorite = false;
  DateTime createdAt = DateTime.now();
  DateTime updatedAt = DateTime.now();

  ContactModel();

  // Factory constructor from API response
  factory ContactModel.fromApiJson(Map<String, dynamic> json) {
    final contact = ContactModel()
      ..contactId = json['id']?.toString() ?? ''
      ..name = json['name'] ?? ''
      ..displayName = json['display_name']
      ..firstName = json['first_name']
      ..lastName = json['last_name']
      ..company = json['company']
      ..notes = json['notes']
      ..source = ContactSource.api
      ..isFavorite = json['is_favorite'] ?? false
      ..createdAt = json['created_at'] != null 
          ? DateTime.parse(json['created_at'])
          : DateTime.now()
      ..updatedAt = json['updated_at'] != null
          ? DateTime.parse(json['updated_at'])
          : DateTime.now();

    // Parse phone numbers from 'numbers' field in API
    if (json['numbers'] is List) {
      contact.phones = (json['numbers'] as List)
          .map((phone) => ContactPhoneModel.fromJson(phone))
          .toList();
    } else if (json['phones'] is List) {
      contact.phones = (json['phones'] as List)
          .map((phone) => ContactPhoneModel.fromJson(phone))
          .toList();
    }

    // Parse emails
    if (json['emails'] is List) {
      contact.emails = (json['emails'] as List)
          .map((email) => ContactEmailModel.fromJson(email))
          .toList();
    }

    return contact;
  }
  
  // Factory constructor from device contact
  factory ContactModel.fromDeviceContact(dynamic deviceContact) {
    final contact = ContactModel()
      ..contactId = deviceContact.id ?? ''
      ..name = deviceContact.displayName ?? ''
      ..displayName = deviceContact.displayName
      ..firstName = deviceContact.name?.first
      ..lastName = deviceContact.name?.last
      ..company = deviceContact.organizations.isNotEmpty 
          ? deviceContact.organizations.first.company
          : null
      ..notes = null
      ..source = ContactSource.device
      ..isFavorite = deviceContact.isStarred ?? false
      ..createdAt = DateTime.now()
      ..updatedAt = DateTime.now();

    // Parse phone numbers
    contact.phones = deviceContact.phones
        .map<ContactPhoneModel>((phone) => ContactPhoneModel.fromDevicePhone(phone))
        .toList();

    // Parse emails
    contact.emails = deviceContact.emails
        .map<ContactEmailModel>((email) => ContactEmailModel.fromDeviceEmail(email))
        .toList();

    return contact;
  }

  // Factory constructor from database map
  factory ContactModel.fromMap(Map<String, dynamic> map) {
    final contact = ContactModel()
      ..id = map['id']
      ..contactId = map['contact_id'] ?? ''
      ..name = map['name'] ?? ''
      ..displayName = map['display_name']
      ..firstName = map['first_name']
      ..lastName = map['last_name']
      ..company = map['company']
      ..notes = map['notes']
      ..source = ContactSource.values.firstWhere(
        (e) => e.toString() == 'ContactSource.${map['source']}',
        orElse: () => ContactSource.api,
      )
      ..isFavorite = map['is_favorite'] == 1
      ..createdAt = DateTime.parse(map['created_at'])
      ..updatedAt = DateTime.parse(map['updated_at']);

    // Parse JSON arrays for phones and emails
    if (map['phones'] != null) {
      final phonesJson = jsonDecode(map['phones']) as List;
      contact.phones = phonesJson
          .map((phone) => ContactPhoneModel.fromJson(phone))
          .toList();
    }

    if (map['emails'] != null) {
      final emailsJson = jsonDecode(map['emails']) as List;
      contact.emails = emailsJson
          .map((email) => ContactEmailModel.fromJson(email))
          .toList();
    }

    return contact;
  }

  // Convert to database map
  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'contact_id': contactId,
      'name': name,
      'display_name': displayName,
      'first_name': firstName,
      'last_name': lastName,
      'company': company,
      'notes': notes,
      'source': source.toString().split('.').last,
      'is_favorite': isFavorite ? 1 : 0,
      'phones': jsonEncode(phones.map((phone) => phone.toJson()).toList()),
      'emails': jsonEncode(emails.map((email) => email.toJson()).toList()),
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
    };
  }

  // Convert to JSON for API calls
  Map<String, dynamic> toApiJson() {
    return {
      'name': name,
      'display_name': displayName,
      'first_name': firstName,
      'last_name': lastName,
      'company': company,
      'notes': notes,
      'is_favorite': isFavorite,
      'phones': phones.map((phone) => phone.toJson()).toList(),
      'emails': emails.map((email) => email.toJson()).toList(),
    };
  }

  // Get primary phone number
  String? get primaryPhone {
    if (phones.isEmpty) return null;
    
    // Try to find a mobile number first
    final mobile = phones.where((p) => p.label.toLowerCase().contains('mobile')).firstOrNull;
    if (mobile != null) return mobile.number;
    
    // Otherwise return the first phone
    return phones.first.number;
  }

  // Get formatted display name
  String get formattedName {
    if (displayName?.isNotEmpty == true) return displayName!;
    if (name.isNotEmpty) return name;
    
    final parts = <String>[];
    if (firstName?.isNotEmpty == true) parts.add(firstName!);
    if (lastName?.isNotEmpty == true) parts.add(lastName!);
    
    return parts.isNotEmpty ? parts.join(' ') : 'Unknown Contact';
  }

  // Get initials for avatar
  String get initials {
    final displayName = formattedName;
    if (displayName.isEmpty) return '?';
    
    final words = displayName.trim().split(RegExp(r'\s+'));
    if (words.length >= 2) {
      return '${words[0][0]}${words[1][0]}'.toUpperCase();
    } else if (words.isNotEmpty && words[0].isNotEmpty) {
      return words[0][0].toUpperCase();
    }
    return '?';
  }
}

class ContactPhoneModel {
  late String number;
  late String label;
  bool isPrimary = false;

  ContactPhoneModel();

  factory ContactPhoneModel.fromJson(Map<String, dynamic> json) {
    return ContactPhoneModel()
      ..number = json['number'] ?? json['phone_number'] ?? ''
      ..label = json['label'] ?? json['type'] ?? 'Mobile'
      ..isPrimary = json['is_primary'] ?? false;
  }

  factory ContactPhoneModel.fromDevicePhone(dynamic devicePhone) {
    return ContactPhoneModel()
      ..number = devicePhone.number ?? ''
      ..label = devicePhone.label?.name ?? 'Mobile'
      ..isPrimary = false;
  }

  Map<String, dynamic> toJson() {
    return {
      'number': number,
      'label': label,
      'is_primary': isPrimary,
    };
  }
}

class ContactEmailModel {
  late String address;
  late String label;
  
  ContactEmailModel();

  factory ContactEmailModel.fromJson(Map<String, dynamic> json) {
    return ContactEmailModel()
      ..address = json['address'] ?? ''
      ..label = json['label'] ?? 'Personal';
  }

  factory ContactEmailModel.fromDeviceEmail(dynamic deviceEmail) {
    return ContactEmailModel()
      ..address = deviceEmail.address ?? ''
      ..label = deviceEmail.label?.name ?? 'Personal';
  }

  Map<String, dynamic> toJson() {
    return {
      'address': address,
      'label': label,
    };
  }
}

enum ContactSource {
  api,
  device,
}