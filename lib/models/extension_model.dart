class ExtensionModel {
  final String id;
  final String userId;
  final String extensionNumber;
  final String? deviceId;
  final String? cosId;
  final String? user;
  final String? secret;
  final bool isSelected;
  final DateTime createdAt;
  
  ExtensionModel({
    required this.id,
    required this.userId,
    required this.extensionNumber,
    this.deviceId,
    this.cosId,
    this.user,
    this.secret,
    this.isSelected = false,
    required this.createdAt,
  });
  
  factory ExtensionModel.fromMap(Map<String, dynamic> map, String id) {
    return ExtensionModel(
      id: id,
      userId: map['userId'] as String? ?? '',
      extensionNumber: map['extensionNumber'] as String? ?? '',
      deviceId: map['deviceId'] as String?,
      cosId: map['cosId'] as String?,
      user: map['user'] as String?,
      secret: map['secret'] as String?,
      isSelected: map['isSelected'] as bool? ?? false,
      createdAt: DateTime.parse(map['createdAt'] as String? ?? DateTime.now().toIso8601String()),
    );
  }
  
  Map<String, dynamic> toMap() {
    return {
      'userId': userId,
      'extensionNumber': extensionNumber,
      'deviceId': deviceId,
      'cosId': cosId,
      'user': user,
      'secret': secret,
      'isSelected': isSelected,
      'createdAt': createdAt.toIso8601String(),
    };
  }
  
  ExtensionModel copyWith({
    String? userId,
    String? extensionNumber,
    String? deviceId,
    String? cosId,
    String? user,
    String? secret,
    bool? isSelected,
    DateTime? createdAt,
  }) {
    return ExtensionModel(
      id: id,
      userId: userId ?? this.userId,
      extensionNumber: extensionNumber ?? this.extensionNumber,
      deviceId: deviceId ?? this.deviceId,
      cosId: cosId ?? this.cosId,
      user: user ?? this.user,
      secret: secret ?? this.secret,
      isSelected: isSelected ?? this.isSelected,
      createdAt: createdAt ?? this.createdAt,
    );
  }
}
