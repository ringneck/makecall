class ContactModel {
  final String id;
  final String userId;
  final String name;
  final String phoneNumber;
  final String? email;
  final String? company;
  final String? notes;
  final bool isFavorite;
  final bool isDeviceContact; // 장치 연락처 여부
  final DateTime createdAt;
  final DateTime? updatedAt;
  
  ContactModel({
    required this.id,
    required this.userId,
    required this.name,
    required this.phoneNumber,
    this.email,
    this.company,
    this.notes,
    this.isFavorite = false,
    this.isDeviceContact = false,
    required this.createdAt,
    this.updatedAt,
  });
  
  factory ContactModel.fromMap(Map<String, dynamic> map, String id) {
    return ContactModel(
      id: id,
      userId: map['userId'] as String? ?? '',
      name: map['name'] as String? ?? '',
      phoneNumber: map['phoneNumber'] as String? ?? '',
      email: map['email'] as String?,
      company: map['company'] as String?,
      notes: map['notes'] as String?,
      isFavorite: map['isFavorite'] as bool? ?? false,
      isDeviceContact: map['isDeviceContact'] as bool? ?? false,
      createdAt: DateTime.parse(map['createdAt'] as String? ?? DateTime.now().toIso8601String()),
      updatedAt: map['updatedAt'] != null 
          ? DateTime.parse(map['updatedAt'] as String)
          : null,
    );
  }
  
  Map<String, dynamic> toMap() {
    return {
      'userId': userId,
      'name': name,
      'phoneNumber': phoneNumber,
      'email': email,
      'company': company,
      'notes': notes,
      'isFavorite': isFavorite,
      'isDeviceContact': isDeviceContact,
      'createdAt': createdAt.toIso8601String(),
      'updatedAt': updatedAt?.toIso8601String(),
    };
  }
  
  ContactModel copyWith({
    String? userId,
    String? name,
    String? phoneNumber,
    String? email,
    String? company,
    String? notes,
    bool? isFavorite,
    bool? isDeviceContact,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return ContactModel(
      id: id,
      userId: userId ?? this.userId,
      name: name ?? this.name,
      phoneNumber: phoneNumber ?? this.phoneNumber,
      email: email ?? this.email,
      company: company ?? this.company,
      notes: notes ?? this.notes,
      isFavorite: isFavorite ?? this.isFavorite,
      isDeviceContact: isDeviceContact ?? this.isDeviceContact,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}
