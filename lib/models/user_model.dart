class UserModel {
  final String uid;
  final String email;
  final String? phoneNumberName;  // 전화번호 이름 (예: 내 휴대폰, 사무실 전화)
  final String? phoneNumber;      // 전화번호
  final String? companyId;
  final String? appKey;
  final String? apiBaseUrl;
  final int? apiHttpPort;
  final int? apiHttpsPort;
  final DateTime createdAt;
  final DateTime? lastLoginAt;
  final bool isActive;
  
  UserModel({
    required this.uid,
    required this.email,
    this.phoneNumberName,
    this.phoneNumber,
    this.companyId,
    this.appKey,
    this.apiBaseUrl,
    this.apiHttpPort = 3500,
    this.apiHttpsPort = 3501,
    required this.createdAt,
    this.lastLoginAt,
    this.isActive = true,
  });
  
  factory UserModel.fromMap(Map<String, dynamic> map, String uid) {
    return UserModel(
      uid: uid,
      email: map['email'] as String? ?? '',
      phoneNumberName: map['phoneNumberName'] as String?,
      phoneNumber: map['phoneNumber'] as String?,
      companyId: map['companyId'] as String?,
      appKey: map['appKey'] as String?,
      apiBaseUrl: map['apiBaseUrl'] as String?,
      apiHttpPort: map['apiHttpPort'] as int? ?? 3500,
      apiHttpsPort: map['apiHttpsPort'] as int? ?? 3501,
      createdAt: DateTime.parse(map['createdAt'] as String? ?? DateTime.now().toIso8601String()),
      lastLoginAt: map['lastLoginAt'] != null 
          ? DateTime.parse(map['lastLoginAt'] as String)
          : null,
      isActive: map['isActive'] as bool? ?? true,
    );
  }
  
  Map<String, dynamic> toMap() {
    return {
      'email': email,
      'phoneNumberName': phoneNumberName,
      'phoneNumber': phoneNumber,
      'companyId': companyId,
      'appKey': appKey,
      'apiBaseUrl': apiBaseUrl,
      'apiHttpPort': apiHttpPort,
      'apiHttpsPort': apiHttpsPort,
      'createdAt': createdAt.toIso8601String(),
      'lastLoginAt': lastLoginAt?.toIso8601String(),
      'isActive': isActive,
    };
  }
  
  UserModel copyWith({
    String? email,
    String? phoneNumberName,
    String? phoneNumber,
    String? companyId,
    String? appKey,
    String? apiBaseUrl,
    int? apiHttpPort,
    int? apiHttpsPort,
    DateTime? createdAt,
    DateTime? lastLoginAt,
    bool? isActive,
  }) {
    return UserModel(
      uid: uid,
      email: email ?? this.email,
      phoneNumberName: phoneNumberName ?? this.phoneNumberName,
      phoneNumber: phoneNumber ?? this.phoneNumber,
      companyId: companyId ?? this.companyId,
      appKey: appKey ?? this.appKey,
      apiBaseUrl: apiBaseUrl ?? this.apiBaseUrl,
      apiHttpPort: apiHttpPort ?? this.apiHttpPort,
      apiHttpsPort: apiHttpsPort ?? this.apiHttpsPort,
      createdAt: createdAt ?? this.createdAt,
      lastLoginAt: lastLoginAt ?? this.lastLoginAt,
      isActive: isActive ?? this.isActive,
    );
  }
  
  // API URL 생성 헬퍼 메서드 (/api/v2 경로 포함)
  String getApiUrl({bool useHttps = true}) {
    if (apiBaseUrl == null || apiBaseUrl!.isEmpty) {
      return '';
    }
    final port = useHttps ? apiHttpsPort : apiHttpPort;
    final protocol = useHttps ? 'https' : 'http';
    return '$protocol://$apiBaseUrl:$port/api/v2';
  }
}
