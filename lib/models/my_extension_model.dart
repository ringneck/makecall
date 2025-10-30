class MyExtensionModel {
  final String id; // Firestore document ID
  final String userId; // 사용자 ID
  final String extensionId; // API의 extension_id
  final String extension; // 단말번호
  final String name; // 이름
  final String classOfServicesId; // COS ID
  final DateTime createdAt; // 생성 시간

  MyExtensionModel({
    required this.id,
    required this.userId,
    required this.extensionId,
    required this.extension,
    required this.name,
    required this.classOfServicesId,
    required this.createdAt,
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
      classOfServicesId: apiData['class_of_services_id']?.toString() ?? '',
      createdAt: DateTime.now(),
    );
  }

  @override
  String toString() {
    return 'MyExtensionModel(id: $id, extension: $extension, name: $name)';
  }
}
