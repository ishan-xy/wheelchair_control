enum EmergencyCallTargetType { emergencyServices, contact }

class EmergencyContact {
  final String id;
  final String name;
  final String phoneNumber;

  const EmergencyContact({
    required this.id,
    required this.name,
    required this.phoneNumber,
  });

  Map<String, String> toJson() => {
        'id': id,
        'name': name,
        'phoneNumber': phoneNumber,
      };

  static EmergencyContact? fromJson(Map<String, dynamic> json) {
    final id = json['id'];
    final name = json['name'];
    final phoneNumber = json['phoneNumber'];
    if (id is! String || name is! String || phoneNumber is! String) {
      return null;
    }
    return EmergencyContact(id: id, name: name, phoneNumber: phoneNumber);
  }
}

class EmergencyPlan {
  static const emergencyNumber = '112';
  static const defaultMessage =
      'VAYA emergency alert. Please check on us. Current location: {location}';

  final List<EmergencyContact> contacts;
  final EmergencyCallTargetType callTargetType;
  final String? callContactId;
  final String message;

  const EmergencyPlan({
    this.contacts = const [],
    this.callTargetType = EmergencyCallTargetType.emergencyServices,
    this.callContactId,
    this.message = defaultMessage,
  });

  EmergencyContact? get callContact {
    for (final contact in contacts) {
      if (contact.id == callContactId) return contact;
    }
    return null;
  }

  String get callNumber =>
      callTargetType == EmergencyCallTargetType.contact && callContact != null
          ? callContact!.phoneNumber
          : emergencyNumber;

  String get callLabel =>
      callTargetType == EmergencyCallTargetType.contact && callContact != null
          ? callContact!.name
          : 'Emergency services (112)';

  EmergencyPlan copyWith({
    List<EmergencyContact>? contacts,
    EmergencyCallTargetType? callTargetType,
    String? callContactId,
    bool clearCallContactId = false,
    String? message,
  }) =>
      EmergencyPlan(
        contacts: contacts ?? this.contacts,
        callTargetType: callTargetType ?? this.callTargetType,
        callContactId:
            clearCallContactId ? null : callContactId ?? this.callContactId,
        message: message ?? this.message,
      );

  Map<String, dynamic> toJson() => {
        'contacts': contacts.map((contact) => contact.toJson()).toList(),
        'callTargetType': callTargetType.name,
        'callContactId': callContactId,
        'message': message,
      };

  static EmergencyPlan fromJson(Map<String, dynamic> json) {
    final savedContacts = json['contacts'];
    final contacts = savedContacts is List
        ? savedContacts
            .whereType<Map>()
            .map((contact) =>
                EmergencyContact.fromJson(Map<String, dynamic>.from(contact)))
            .whereType<EmergencyContact>()
            .toList(growable: false)
        : const <EmergencyContact>[];
    final target =
        json['callTargetType'] == EmergencyCallTargetType.contact.name
            ? EmergencyCallTargetType.contact
            : EmergencyCallTargetType.emergencyServices;
    final selectedId = json['callContactId'];
    return EmergencyPlan(
      contacts: contacts,
      callTargetType: target,
      callContactId: selectedId is String ? selectedId : null,
      message:
          json['message'] is String && (json['message'] as String).isNotEmpty
              ? json['message'] as String
              : defaultMessage,
    );
  }
}
