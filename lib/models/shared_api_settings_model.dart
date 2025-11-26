/// 공유 API 설정 모델
/// isAdmin 사용자가 내보낸 설정을 저장하고 조회하기 위한 모델
class SharedApiSettingsModel {
  final String id; // 문서 ID (자동 생성)
  final String organizationName; // 조직명 (검색 키)
  final String appKey; // REST API App-Key (검색 키)
  
  // 기본 API 설정 필드들
  final String? companyName;
  final String? companyId;
  final String? apiBaseUrl;
  final int? apiHttpPort;
  final int? apiHttpsPort;
  final String? websocketServerUrl;
  final int? websocketServerPort;
  final bool? websocketUseSSL;
  final String? websocketHttpAuthId;
  final String? websocketHttpAuthPassword;
  final int? amiServerId;
  
  // 메타데이터
  final String exportedByUserId; // 내보낸 사용자 UID
  final String exportedByEmail; // 내보낸 사용자 이메일
  final DateTime exportedAt; // 내보낸 시간
  final DateTime? lastUpdatedAt; // 마지막 업데이트 시간
  
  SharedApiSettingsModel({
    required this.id,
    required this.organizationName,
    required this.appKey,
    this.companyName,
    this.companyId,
    this.apiBaseUrl,
    this.apiHttpPort = 3500,
    this.apiHttpsPort = 3501,
    this.websocketServerUrl,
    this.websocketServerPort = 6600,
    this.websocketUseSSL = false,
    this.websocketHttpAuthId,
    this.websocketHttpAuthPassword,
    this.amiServerId = 1,
    required this.exportedByUserId,
    required this.exportedByEmail,
    required this.exportedAt,
    this.lastUpdatedAt,
  });
  
  factory SharedApiSettingsModel.fromMap(Map<String, dynamic> map, String id) {
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
    
    return SharedApiSettingsModel(
      id: id,
      organizationName: map['organizationName'] as String? ?? '',
      appKey: map['appKey'] as String? ?? '',
      companyName: map['companyName'] as String?,
      companyId: map['companyId'] as String?,
      apiBaseUrl: map['apiBaseUrl'] as String?,
      apiHttpPort: map['apiHttpPort'] as int? ?? 3500,
      apiHttpsPort: map['apiHttpsPort'] as int? ?? 3501,
      websocketServerUrl: map['websocketServerUrl'] as String?,
      websocketServerPort: map['websocketServerPort'] as int? ?? 6600,
      websocketUseSSL: map['websocketUseSSL'] as bool? ?? false,
      websocketHttpAuthId: map['websocketHttpAuthId'] as String?,
      websocketHttpAuthPassword: map['websocketHttpAuthPassword'] as String?,
      amiServerId: map['amiServerId'] as int? ?? 1,
      exportedByUserId: map['exportedByUserId'] as String? ?? '',
      exportedByEmail: map['exportedByEmail'] as String? ?? '',
      exportedAt: parseTimestamp(map['exportedAt']) ?? DateTime.now(),
      lastUpdatedAt: parseTimestamp(map['lastUpdatedAt']),
    );
  }
  
  Map<String, dynamic> toMap() {
    return {
      'organizationName': organizationName,
      'appKey': appKey,
      'companyName': companyName,
      'companyId': companyId,
      'apiBaseUrl': apiBaseUrl,
      'apiHttpPort': apiHttpPort,
      'apiHttpsPort': apiHttpsPort,
      'websocketServerUrl': websocketServerUrl,
      'websocketServerPort': websocketServerPort,
      'websocketUseSSL': websocketUseSSL,
      'websocketHttpAuthId': websocketHttpAuthId,
      'websocketHttpAuthPassword': websocketHttpAuthPassword,
      'amiServerId': amiServerId,
      'exportedByUserId': exportedByUserId,
      'exportedByEmail': exportedByEmail,
      'exportedAt': exportedAt.toIso8601String(),
      if (lastUpdatedAt != null) 'lastUpdatedAt': lastUpdatedAt!.toIso8601String(),
    };
  }
  
  // API URL 생성 헬퍼 메서드
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
}
