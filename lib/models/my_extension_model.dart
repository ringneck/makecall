class MyExtensionModel {
  final String id; // Firestore document ID
  final String userId; // 사용자 ID
  final String extensionId; // API의 extension_id
  final String extension; // 단말번호
  final String name; // 이름
  final String classOfServicesId; // COS ID
  final DateTime createdAt; // 생성 시간
  
  // API 서버 설정 (각 단말번호마다 개별 설정 가능)
  final String? apiBaseUrl; // API 서버 주소
  final String? companyId; // 회사 ID
  final String? appKey; // 앱 키
  final int? apiHttpPort; // HTTP 포트
  final int? apiHttpsPort; // HTTPS 포트

  MyExtensionModel({
    required this.id,
    required this.userId,
    required this.extensionId,
    required this.extension,
    required this.name,
    required this.classOfServicesId,
    required this.createdAt,
    this.apiBaseUrl,
    this.companyId,
    this.appKey,
    this.apiHttpPort,
    this.apiHttpsPort,
  });

  // Firestore에서 데이터 읽기
  factory MyExtensionModel.fromFirestore(Map<String, dynamic> data, String id) {
    return MyExtensionModel(
      id: id,
      userId: data['userId'] as String? ?? '',
      extensionId: data['extensionId'] as String? ?? '',
      extension: data['extension'] as String? ?? '',
      name: data['name'] as String? ?? '',
      classOfServicesId: data['classOfServicesId'] as String? ?? '',
      createdAt: data['createdAt'] != null
          ? DateTime.fromMillisecondsSinceEpoch(data['createdAt'] as int)
          : DateTime.now(),
      apiBaseUrl: data['apiBaseUrl'] as String?,
      companyId: data['companyId'] as String?,
      appKey: data['appKey'] as String?,
      apiHttpPort: data['apiHttpPort'] as int?,
      apiHttpsPort: data['apiHttpsPort'] as int?,
    );
  }

  // Firestore에 저장할 데이터
  Map<String, dynamic> toFirestore() {
    return {
      'userId': userId,
      'extensionId': extensionId,
      'extension': extension,
      'name': name,
      'classOfServicesId': classOfServicesId,
      'createdAt': createdAt.millisecondsSinceEpoch,
      'apiBaseUrl': apiBaseUrl,
      'companyId': companyId,
      'appKey': appKey,
      'apiHttpPort': apiHttpPort,
      'apiHttpsPort': apiHttpsPort,
    };
  }

  // API 응답에서 생성
  factory MyExtensionModel.fromApi({
    required String userId,
    required Map<String, dynamic> apiData,
  }) {
    return MyExtensionModel(
      id: '', // Firestore에서 자동 생성
      userId: userId,
      extensionId: apiData['extension_id']?.toString() ?? '',
      extension: apiData['extension']?.toString() ?? '',
      name: apiData['name']?.toString() ?? '',
      classOfServicesId: apiData['class_of_service_id']?.toString() ?? '',
      createdAt: DateTime.now(),
      // API 설정은 나중에 사용자가 수동으로 설정
      apiBaseUrl: null,
      companyId: null,
      appKey: null,
      apiHttpPort: null,
      apiHttpsPort: null,
    );
  }
  
  // API URL 생성 헬퍼 메서드
  String? getApiUrl({bool useHttps = false}) {
    if (apiBaseUrl == null) return null;
    
    final port = useHttps ? (apiHttpsPort ?? 443) : (apiHttpPort ?? 80);
    final protocol = useHttps ? 'https' : 'http';
    
    return '$protocol://$apiBaseUrl:$port';
  }
  
  // API 설정이 완료되었는지 확인
  bool get hasApiConfig {
    return apiBaseUrl != null && 
           companyId != null && 
           appKey != null && 
           apiHttpPort != null && 
           apiHttpsPort != null;
  }
  
  // copyWith 메서드 (API 설정 업데이트용)
  MyExtensionModel copyWith({
    String? id,
    String? userId,
    String? extensionId,
    String? extension,
    String? name,
    String? classOfServicesId,
    DateTime? createdAt,
    String? apiBaseUrl,
    String? companyId,
    String? appKey,
    int? apiHttpPort,
    int? apiHttpsPort,
  }) {
    return MyExtensionModel(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      extensionId: extensionId ?? this.extensionId,
      extension: extension ?? this.extension,
      name: name ?? this.name,
      classOfServicesId: classOfServicesId ?? this.classOfServicesId,
      createdAt: createdAt ?? this.createdAt,
      apiBaseUrl: apiBaseUrl ?? this.apiBaseUrl,
      companyId: companyId ?? this.companyId,
      appKey: appKey ?? this.appKey,
      apiHttpPort: apiHttpPort ?? this.apiHttpPort,
      apiHttpsPort: apiHttpsPort ?? this.apiHttpsPort,
    );
  }

  @override
  String toString() {
    return 'MyExtensionModel(id: $id, extension: $extension, name: $name)';
  }
}
