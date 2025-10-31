class UserModel {
  final String uid;
  final String email;
  final String? phoneNumberName;  // 전화번호 이름 (예: 내 휴대폰, 사무실 전화)
  final String? phoneNumber;      // 전화번호
  final String? profileImageUrl;  // 프로필 사진 URL (Firebase Storage)
  final String? companyName;      // 회사명
  final String? companyId;
  final String? appKey;
  final String? apiBaseUrl;
  final int? apiHttpPort;
  final int? apiHttpsPort;
  final DateTime createdAt;
  final DateTime? lastLoginAt;
  final bool isActive;
  final bool isPremium; // 프리미엄 사용자 여부 (하위 호환성 유지)
  final int maxExtensions; // 사용자별 단말번호 저장 가능 개수
  
  UserModel({
    required this.uid,
    required this.email,
    this.phoneNumberName,
    this.phoneNumber,
    this.profileImageUrl,
    this.companyName,
    this.companyId,
    this.appKey,
    this.apiBaseUrl,
    this.apiHttpPort = 3500,
    this.apiHttpsPort = 3501,
    required this.createdAt,
    this.lastLoginAt,
    this.isActive = true,
    this.isPremium = false, // 기본값: 무료 사용자 (하위 호환성)
    this.maxExtensions = 1, // 기본값: 1개
  });
  
  factory UserModel.fromMap(Map<String, dynamic> map, String uid) {
    return UserModel(
      uid: uid,
      email: map['email'] as String? ?? '',
      phoneNumberName: map['phoneNumberName'] as String?,
      phoneNumber: map['phoneNumber'] as String?,
      profileImageUrl: map['profileImageUrl'] as String?,
      companyName: map['companyName'] as String?,
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
      isPremium: map['isPremium'] as bool? ?? false,
      maxExtensions: map['maxExtensions'] as int? ?? 1, // 기본값 1개
    );
  }
  
  Map<String, dynamic> toMap() {
    return {
      'email': email,
      'phoneNumberName': phoneNumberName,
      'phoneNumber': phoneNumber,
      'profileImageUrl': profileImageUrl,
      'companyName': companyName,
      'companyId': companyId,
      'appKey': appKey,
      'apiBaseUrl': apiBaseUrl,
      'apiHttpPort': apiHttpPort,
      'apiHttpsPort': apiHttpsPort,
      'createdAt': createdAt.toIso8601String(),
      'lastLoginAt': lastLoginAt?.toIso8601String(),
      'isActive': isActive,
      'isPremium': isPremium,
      'maxExtensions': maxExtensions,
    };
  }
  
  UserModel copyWith({
    String? email,
    String? phoneNumberName,
    String? phoneNumber,
    String? profileImageUrl,
    String? companyName,
    String? companyId,
    String? appKey,
    String? apiBaseUrl,
    int? apiHttpPort,
    int? apiHttpsPort,
    DateTime? createdAt,
    DateTime? lastLoginAt,
    bool? isActive,
    bool? isPremium,
    int? maxExtensions,
  }) {
    return UserModel(
      uid: uid,
      email: email ?? this.email,
      phoneNumberName: phoneNumberName ?? this.phoneNumberName,
      phoneNumber: phoneNumber ?? this.phoneNumber,
      profileImageUrl: profileImageUrl ?? this.profileImageUrl,
      companyName: companyName ?? this.companyName,
      companyId: companyId ?? this.companyId,
      appKey: appKey ?? this.appKey,
      apiBaseUrl: apiBaseUrl ?? this.apiBaseUrl,
      apiHttpPort: apiHttpPort ?? this.apiHttpPort,
      apiHttpsPort: apiHttpsPort ?? this.apiHttpsPort,
      createdAt: createdAt ?? this.createdAt,
      lastLoginAt: lastLoginAt ?? this.lastLoginAt,
      isActive: isActive ?? this.isActive,
      isPremium: isPremium ?? this.isPremium,
      maxExtensions: maxExtensions ?? this.maxExtensions,
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
