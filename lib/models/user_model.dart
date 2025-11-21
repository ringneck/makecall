import 'consent_record.dart';

class UserModel {
  final String uid;
  final String email;
  final String? organizationName; // 조직명/닉네임 (사용자 지정 이름)
  final String? phoneNumberName;  // 전화번호 이름 (예: 내 휴대폰, 사무실 전화)
  final String? phoneNumber;      // 전화번호
  final String? profileImageUrl;  // 프로필 사진 URL (Firebase Storage)
  final String? companyName;      // 회사명
  final String? companyId;
  final String? appKey;
  final String? apiBaseUrl;
  final int? apiHttpPort;
  final int? apiHttpsPort;
  final String? websocketServerUrl;  // WebSocket 서버 주소
  final int? websocketServerPort;    // WebSocket 서버 포트 (기본: 6600)
  final bool? websocketUseSSL;       // WebSocket SSL 사용 여부 (wss 또는 ws, 기본: false)
  final String? websocketHttpAuthId; // WebSocket HTTP Basic Auth ID
  final String? websocketHttpAuthPassword; // WebSocket HTTP Basic Auth Password
  final int? amiServerId;            // AMI 서버 ID (다중 서버 구분, 기본: 1)
  final bool? dcmiwsEnabled;         // DCMIWS 착신전화 수신 사용 여부 (기본: false, PUSH 사용)
  final DateTime createdAt;
  final DateTime? lastLoginAt;
  final DateTime? lastMaxExtensionsUpdate; // maxExtensions 마지막 업데이트 일시
  final bool isActive;
  final bool isPremium; // 프리미엄 사용자 여부 (하위 호환성 유지)
  final int maxExtensions; // 사용자별 단말번호 저장 가능 개수
  final List<String>? myExtensions; // 내 단말번호 목록
  
  // 🆕 개인정보보호법 준수 - 동의 관리 필드
  final String? consentVersion;              // 약관 버전 (예: "1.0")
  final bool termsAgreed;                    // 이용약관 동의 여부
  final DateTime? termsAgreedAt;             // 이용약관 동의 날짜
  final bool privacyPolicyAgreed;            // 개인정보처리방침 동의 여부
  final DateTime? privacyPolicyAgreedAt;     // 개인정보처리방침 동의 날짜
  final bool? marketingConsent;              // 마케팅 수신 동의 (선택)
  final DateTime? marketingConsentAt;        // 마케팅 수신 동의 날짜
  final DateTime? lastConsentCheckAt;        // 마지막 동의 확인 날짜
  final DateTime? nextConsentCheckDue;       // 다음 재동의 예정일 (2년 후)
  final List<ConsentRecord>? consentHistory; // 동의 이력
  
  UserModel({
    required this.uid,
    required this.email,
    this.organizationName,
    this.phoneNumberName,
    this.phoneNumber,
    this.profileImageUrl,
    this.companyName,
    this.companyId,
    this.appKey,
    this.apiBaseUrl,
    this.apiHttpPort = 3500,
    this.apiHttpsPort = 3501,
    this.websocketServerUrl,
    this.websocketServerPort = 6600,
    this.websocketUseSSL = false,
    this.websocketHttpAuthId,
    this.websocketHttpAuthPassword,
    this.amiServerId = 1,
    this.dcmiwsEnabled = false,
    required this.createdAt,
    this.lastLoginAt,
    this.lastMaxExtensionsUpdate,
    this.isActive = true,
    this.isPremium = false, // 기본값: 무료 사용자 (하위 호환성)
    this.maxExtensions = 1, // 기본값: 1개
    this.myExtensions,
    // 🆕 동의 관리 필드
    this.consentVersion,
    this.termsAgreed = false,
    this.termsAgreedAt,
    this.privacyPolicyAgreed = false,
    this.privacyPolicyAgreedAt,
    this.marketingConsent,
    this.marketingConsentAt,
    this.lastConsentCheckAt,
    this.nextConsentCheckDue,
    this.consentHistory,
  });
  
  // 🆕 동의 만료 체크 메서드
  bool get needsConsentRenewal {
    if (nextConsentCheckDue == null) return true;
    return DateTime.now().isAfter(nextConsentCheckDue!);
  }
  
  // 🆕 동의 유효성 체크
  bool get hasValidConsent {
    return termsAgreed && privacyPolicyAgreed && !needsConsentRenewal;
  }
  
  factory UserModel.fromMap(Map<String, dynamic> map, String uid) {
    // Firestore Timestamp 또는 String을 DateTime으로 변환하는 헬퍼 함수
    DateTime? parseTimestamp(dynamic value) {
      if (value == null) return null;
      if (value is String) {
        return DateTime.parse(value);
      }
      // Firestore Timestamp 처리
      if (value.runtimeType.toString().contains('Timestamp')) {
        return (value as dynamic).toDate() as DateTime;
      }
      return null;
    }

    return UserModel(
      uid: uid,
      email: map['email'] as String? ?? '',
      organizationName: map['organizationName'] as String?,
      phoneNumberName: map['phoneNumberName'] as String?,
      phoneNumber: map['phoneNumber'] as String?,
      profileImageUrl: map['profileImageUrl'] as String?,
      companyName: map['companyName'] as String?,
      companyId: map['companyId'] as String?,
      appKey: map['appKey'] as String?,
      apiBaseUrl: map['apiBaseUrl'] as String?,
      apiHttpPort: map['apiHttpPort'] as int? ?? 3500,
      apiHttpsPort: map['apiHttpsPort'] as int? ?? 3501,
      websocketServerUrl: map['websocketServerUrl'] as String?,
      websocketServerPort: map['websocketServerPort'] as int? ?? 6600,
      websocketUseSSL: map['websocketUseSSL'] as bool? ?? false,
      websocketHttpAuthId: map['websocketHttpAuthId'] as String?,
      websocketHttpAuthPassword: map['websocketHttpAuthPassword'] as String?,
      amiServerId: map['amiServerId'] as int? ?? 1,
      dcmiwsEnabled: map['dcmiwsEnabled'] as bool? ?? false,
      createdAt: parseTimestamp(map['createdAt']) ?? DateTime.now(),
      lastLoginAt: parseTimestamp(map['lastLoginAt']),
      lastMaxExtensionsUpdate: parseTimestamp(map['lastMaxExtensionsUpdate']),
      isActive: map['isActive'] as bool? ?? true,
      isPremium: map['isPremium'] as bool? ?? false,
      maxExtensions: map['maxExtensions'] as int? ?? 1, // 기본값 1개
      myExtensions: map['myExtensions'] != null 
          ? List<String>.from(map['myExtensions'] as List)
          : null,
      // 🆕 동의 관리 필드 파싱
      consentVersion: map['consentVersion'] as String?,
      termsAgreed: map['termsAgreed'] as bool? ?? false,
      termsAgreedAt: parseTimestamp(map['termsAgreedAt']),
      privacyPolicyAgreed: map['privacyPolicyAgreed'] as bool? ?? false,
      privacyPolicyAgreedAt: parseTimestamp(map['privacyPolicyAgreedAt']),
      marketingConsent: map['marketingConsent'] as bool?,
      marketingConsentAt: parseTimestamp(map['marketingConsentAt']),
      lastConsentCheckAt: parseTimestamp(map['lastConsentCheckAt']),
      nextConsentCheckDue: parseTimestamp(map['nextConsentCheckDue']),
      consentHistory: map['consentHistory'] != null
          ? (map['consentHistory'] as List)
              .map((item) => ConsentRecord.fromMap(item as Map<String, dynamic>))
              .toList()
          : null,
    );
  }
  
  Map<String, dynamic> toMap() {
    return {
      'email': email,
      'organizationName': organizationName,
      'phoneNumberName': phoneNumberName,
      'phoneNumber': phoneNumber,
      'profileImageUrl': profileImageUrl,
      'companyName': companyName,
      'companyId': companyId,
      'appKey': appKey,
      'apiBaseUrl': apiBaseUrl,
      'apiHttpPort': apiHttpPort,
      'apiHttpsPort': apiHttpsPort,
      'websocketServerUrl': websocketServerUrl,
      'websocketServerPort': websocketServerPort,
      'websocketUseSSL': websocketUseSSL,
      'websocketHttpAuthId': websocketHttpAuthId,
      'websocketHttpAuthPassword': websocketHttpAuthPassword,
      'amiServerId': amiServerId,
      'dcmiwsEnabled': dcmiwsEnabled,
      'createdAt': createdAt.toIso8601String(),
      'lastLoginAt': lastLoginAt?.toIso8601String(),
      'lastMaxExtensionsUpdate': lastMaxExtensionsUpdate?.toIso8601String(),
      'isActive': isActive,
      'isPremium': isPremium,
      'maxExtensions': maxExtensions,
      'myExtensions': myExtensions,
      // 🆕 동의 관리 필드
      if (consentVersion != null) 'consentVersion': consentVersion,
      'termsAgreed': termsAgreed,
      if (termsAgreedAt != null) 'termsAgreedAt': termsAgreedAt!.toIso8601String(),
      'privacyPolicyAgreed': privacyPolicyAgreed,
      if (privacyPolicyAgreedAt != null) 'privacyPolicyAgreedAt': privacyPolicyAgreedAt!.toIso8601String(),
      if (marketingConsent != null) 'marketingConsent': marketingConsent,
      if (marketingConsentAt != null) 'marketingConsentAt': marketingConsentAt!.toIso8601String(),
      if (lastConsentCheckAt != null) 'lastConsentCheckAt': lastConsentCheckAt!.toIso8601String(),
      if (nextConsentCheckDue != null) 'nextConsentCheckDue': nextConsentCheckDue!.toIso8601String(),
      if (consentHistory != null) 
        'consentHistory': consentHistory!.map((record) => record.toMap()).toList(),
    };
  }
  
  UserModel copyWith({
    String? email,
    String? organizationName,
    String? phoneNumberName,
    String? phoneNumber,
    String? profileImageUrl,
    String? companyName,
    String? companyId,
    String? appKey,
    String? apiBaseUrl,
    int? apiHttpPort,
    int? apiHttpsPort,
    String? websocketServerUrl,
    int? websocketServerPort,
    bool? websocketUseSSL,
    String? websocketHttpAuthId,
    String? websocketHttpAuthPassword,
    int? amiServerId,
    bool? dcmiwsEnabled,
    DateTime? createdAt,
    DateTime? lastLoginAt,
    DateTime? lastMaxExtensionsUpdate,
    bool? isActive,
    bool? isPremium,
    int? maxExtensions,
    List<String>? myExtensions,
  }) {
    return UserModel(
      uid: uid,
      email: email ?? this.email,
      organizationName: organizationName ?? this.organizationName,
      phoneNumberName: phoneNumberName ?? this.phoneNumberName,
      phoneNumber: phoneNumber ?? this.phoneNumber,
      profileImageUrl: profileImageUrl ?? this.profileImageUrl,
      companyName: companyName ?? this.companyName,
      companyId: companyId ?? this.companyId,
      appKey: appKey ?? this.appKey,
      apiBaseUrl: apiBaseUrl ?? this.apiBaseUrl,
      apiHttpPort: apiHttpPort ?? this.apiHttpPort,
      apiHttpsPort: apiHttpsPort ?? this.apiHttpsPort,
      websocketServerUrl: websocketServerUrl ?? this.websocketServerUrl,
      websocketServerPort: websocketServerPort ?? this.websocketServerPort,
      websocketUseSSL: websocketUseSSL ?? this.websocketUseSSL,
      websocketHttpAuthId: websocketHttpAuthId ?? this.websocketHttpAuthId,
      websocketHttpAuthPassword: websocketHttpAuthPassword ?? this.websocketHttpAuthPassword,
      amiServerId: amiServerId ?? this.amiServerId,
      dcmiwsEnabled: dcmiwsEnabled ?? this.dcmiwsEnabled,
      createdAt: createdAt ?? this.createdAt,
      lastLoginAt: lastLoginAt ?? this.lastLoginAt,
      lastMaxExtensionsUpdate: lastMaxExtensionsUpdate ?? this.lastMaxExtensionsUpdate,
      isActive: isActive ?? this.isActive,
      isPremium: isPremium ?? this.isPremium,
      maxExtensions: maxExtensions ?? this.maxExtensions,
      myExtensions: myExtensions ?? this.myExtensions,
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
  
  // WebSocket URL 생성 헬퍼 메서드
  String getWebSocketUrl() {
    if (websocketServerUrl == null || websocketServerUrl!.isEmpty) {
      return '';
    }
    final protocol = (websocketUseSSL ?? false) ? 'wss' : 'ws';
    return '$protocol://$websocketServerUrl:$websocketServerPort';
  }
  
  // TenantID getter (companyId와 동일)
  String? get tenantId => companyId;
}
