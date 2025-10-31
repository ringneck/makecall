class MyExtensionModel {
  final String id; // Firestore document ID
  final String userId; // 사용자 ID
  final String extensionId; // API의 extension_id
  final String extension; // 단말번호
  final String name; // 이름
  final String classOfServicesId; // COS ID
  final String? externalCid; // 외부발신 정보 원본 (예: "외부발신" <16682471>)
  final String? externalCidName; // 외부발신 이름 (파싱됨)
  final String? externalCidNumber; // 외부발신 번호 (파싱됨)
  final String? accountCode; // 계정 코드
  final String? sipUserId; // SIP user id (devices.user)
  final String? sipSecret; // SIP secret (devices.secret)
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
    this.externalCid,
    this.externalCidName,
    this.externalCidNumber,
    this.accountCode,
    this.sipUserId,
    this.sipSecret,
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
      externalCid: data['externalCid'] as String?,
      externalCidName: data['externalCidName'] as String?,
      externalCidNumber: data['externalCidNumber'] as String?,
      accountCode: data['accountCode'] as String?,
      sipUserId: data['sipUserId'] as String?,
      sipSecret: data['sipSecret'] as String?,
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
      'externalCid': externalCid,
      'externalCidName': externalCidName,
      'externalCidNumber': externalCidNumber,
      'accountCode': accountCode,
      'sipUserId': sipUserId,
      'sipSecret': sipSecret,
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
    // external_cid 파싱
    final externalCidRaw = apiData['external_cid']?.toString();
    String? parsedName;
    String? parsedNumber;
    
    if (externalCidRaw != null && externalCidRaw.isNotEmpty) {
      // "외부발신" 형식에서 큰따옴표 안의 이름 추출
      final nameMatch = RegExp(r'"([^"]+)"').firstMatch(externalCidRaw);
      if (nameMatch != null) {
        parsedName = nameMatch.group(1);
      }
      
      // <16682471> 형식에서 꺾쇠괄호 안의 번호 추출
      final numberMatch = RegExp(r'<([0-9\-]+)>').firstMatch(externalCidRaw);
      if (numberMatch != null) {
        parsedNumber = numberMatch.group(1);
      }
    }
    
    // devices에서 SIP user와 secret 추출
    String? sipUser;
    String? sipSecretValue;
    
    if (apiData['devices'] is List && (apiData['devices'] as List).isNotEmpty) {
      final firstDevice = (apiData['devices'] as List).first;
      if (firstDevice is Map<String, dynamic>) {
        sipUser = firstDevice['user']?.toString();
        sipSecretValue = firstDevice['secret']?.toString();
      }
    }
    
    return MyExtensionModel(
      id: '', // Firestore에서 자동 생성
      userId: userId,
      extensionId: apiData['extension_id']?.toString() ?? '',
      extension: apiData['extension']?.toString() ?? '',
      name: apiData['name']?.toString() ?? '',
      classOfServicesId: apiData['class_of_service_id']?.toString() ?? '',
      externalCid: externalCidRaw,
      externalCidName: parsedName,
      externalCidNumber: parsedNumber,
      accountCode: apiData['accountcode']?.toString(),
      sipUserId: sipUser,
      sipSecret: sipSecretValue,
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
  
  // 외부발신 정보 파싱 ("외부발신" <16682471> 형식)
  Map<String, String> parseExternalCid() {
    if (externalCid == null || externalCid!.isEmpty) {
      return {'name': '', 'number': ''};
    }
    
    final cidString = externalCid!;
    String callerName = '';
    String callerNumber = '';
    
    // "외부발신" 형식에서 큰따옴표 안의 이름 추출
    final nameMatch = RegExp(r'"([^"]+)"').firstMatch(cidString);
    if (nameMatch != null) {
      callerName = nameMatch.group(1) ?? '';
    }
    
    // <16682471> 형식에서 꺾쇠괄호 안의 번호 추출
    final numberMatch = RegExp(r'<([0-9\-]+)>').firstMatch(cidString);
    if (numberMatch != null) {
      callerNumber = numberMatch.group(1) ?? '';
    }
    
    return {'name': callerName, 'number': callerNumber};
  }
  
  // copyWith 메서드 (API 설정 업데이트용)
  MyExtensionModel copyWith({
    String? id,
    String? userId,
    String? extensionId,
    String? extension,
    String? name,
    String? classOfServicesId,
    String? externalCid,
    String? externalCidName,
    String? externalCidNumber,
    String? accountCode,
    String? sipUserId,
    String? sipSecret,
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
      externalCid: externalCid ?? this.externalCid,
      externalCidName: externalCidName ?? this.externalCidName,
      externalCidNumber: externalCidNumber ?? this.externalCidNumber,
      accountCode: accountCode ?? this.accountCode,
      sipUserId: sipUserId ?? this.sipUserId,
      sipSecret: sipSecret ?? this.sipSecret,
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
