class VoicemailModel {
  final int? id; // Auto-increment ID for SQLite
  final String uuid; // Unique identifier from API
  final String reqUser; // Extension that received the voicemail
  final String realm;
  final String fromName;
  final String fromUser;
  final int duration; // Duration in seconds
  final DateTime created;
  final DateTime? readOn; // Null if unread
  final bool isSaved; // True if saved by user

  VoicemailModel({
    this.id,
    required this.uuid,
    required this.reqUser,
    required this.realm,
    required this.fromName,
    required this.fromUser,
    required this.duration,
    required this.created,
    this.readOn,
    this.isSaved = false,
  });

  // Factory constructor from JSON
  factory VoicemailModel.fromJson(Map<String, dynamic> json) {
    return VoicemailModel(
      uuid: json['uuid'] as String,
      reqUser: json['req_user'] as String,
      realm: json['realm'] as String,
      fromName: json['from_name'] as String? ?? '',
      fromUser: json['from_user'] as String,
      duration: json['duration'] as int,
      created: DateTime.parse(json['created'] as String),
      readOn: json['read_on'] != null
          ? DateTime.parse(json['read_on'] as String)
          : null,
    );
  }

  // Convert to JSON
  Map<String, dynamic> toJson() {
    return {
      'uuid': uuid,
      'req_user': reqUser,
      'realm': realm,
      'from_name': fromName,
      'from_user': fromUser,
      'duration': duration,
      'created': created.toIso8601String(),
      'read_on': readOn?.toIso8601String(),
    };
  }

  // Helper getters
  bool get isUnread => readOn == null;

  String get displayName {
    if (fromName.isNotEmpty && fromName != fromUser) {
      return fromName;
    }
    return fromUser;
  }

  // Convert to SQLite map
  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'uuid': uuid,
      'req_user': reqUser,
      'realm': realm,
      'from_name': fromName,
      'from_user': fromUser,
      'duration': duration,
      'created': created.toIso8601String(),
      'read_on': readOn?.toIso8601String(),
      'is_saved': isSaved ? 1 : 0,
    };
  }

  // Factory constructor from SQLite map
  factory VoicemailModel.fromMap(Map<String, dynamic> map) {
    return VoicemailModel(
      id: map['id'] as int?,
      uuid: map['uuid'] as String,
      reqUser: map['req_user'] as String,
      realm: map['realm'] as String,
      fromName: map['from_name'] as String? ?? '',
      fromUser: map['from_user'] as String,
      duration: map['duration'] as int,
      created: DateTime.parse(map['created'] as String),
      readOn: map['read_on'] != null
          ? DateTime.parse(map['read_on'] as String)
          : null,
      isSaved: (map['is_saved'] as int?) == 1,
    );
  }

  // Copy with
  VoicemailModel copyWith({
    int? id,
    String? uuid,
    String? reqUser,
    String? realm,
    String? fromName,
    String? fromUser,
    int? duration,
    DateTime? created,
    DateTime? readOn,
    bool? isSaved,
  }) {
    return VoicemailModel(
      id: id ?? this.id,
      uuid: uuid ?? this.uuid,
      reqUser: reqUser ?? this.reqUser,
      realm: realm ?? this.realm,
      fromName: fromName ?? this.fromName,
      fromUser: fromUser ?? this.fromUser,
      duration: duration ?? this.duration,
      created: created ?? this.created,
      readOn: readOn ?? this.readOn,
      isSaved: isSaved ?? this.isSaved,
    );
  }
}
