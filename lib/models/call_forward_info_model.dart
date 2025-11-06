import 'package:cloud_firestore/cloud_firestore.dart';

class CallForwardInfoModel {
  final String id; // userId + extensionNumber 조합
  final String userId;
  final String extensionNumber;
  final bool isEnabled;
  final String destinationNumber; // 착신번호
  final DateTime lastUpdated;

  CallForwardInfoModel({
    required this.id,
    required this.userId,
    required this.extensionNumber,
    required this.isEnabled,
    required this.destinationNumber,
    required this.lastUpdated,
  });

  // Firestore 문서로 변환
  Map<String, dynamic> toFirestore() {
    return {
      'userId': userId,
      'extensionNumber': extensionNumber,
      'isEnabled': isEnabled,
      'destinationNumber': destinationNumber,
      'lastUpdated': Timestamp.fromDate(lastUpdated),
    };
  }

  // Firestore 문서에서 생성
  factory CallForwardInfoModel.fromFirestore(
    DocumentSnapshot doc,
  ) {
    final data = doc.data() as Map<String, dynamic>;
    return CallForwardInfoModel(
      id: doc.id,
      userId: data['userId'] as String? ?? '',
      extensionNumber: data['extensionNumber'] as String? ?? '',
      isEnabled: data['isEnabled'] as bool? ?? false,
      destinationNumber: data['destinationNumber'] as String? ?? '',
      lastUpdated: (data['lastUpdated'] as Timestamp?)?.toDate() ?? DateTime.now(),
    );
  }

  // Map에서 생성
  factory CallForwardInfoModel.fromMap(Map<String, dynamic> data, String documentId) {
    return CallForwardInfoModel(
      id: documentId,
      userId: data['userId'] as String? ?? '',
      extensionNumber: data['extensionNumber'] as String? ?? '',
      isEnabled: data['isEnabled'] as bool? ?? false,
      destinationNumber: data['destinationNumber'] as String? ?? '',
      lastUpdated: (data['lastUpdated'] as Timestamp?)?.toDate() ?? DateTime.now(),
    );
  }

  // 복사본 생성
  CallForwardInfoModel copyWith({
    String? id,
    String? userId,
    String? extensionNumber,
    bool? isEnabled,
    String? destinationNumber,
    DateTime? lastUpdated,
  }) {
    return CallForwardInfoModel(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      extensionNumber: extensionNumber ?? this.extensionNumber,
      isEnabled: isEnabled ?? this.isEnabled,
      destinationNumber: destinationNumber ?? this.destinationNumber,
      lastUpdated: lastUpdated ?? this.lastUpdated,
    );
  }

  @override
  String toString() {
    return 'CallForwardInfoModel(id: $id, userId: $userId, extensionNumber: $extensionNumber, '
        'isEnabled: $isEnabled, destinationNumber: $destinationNumber, lastUpdated: $lastUpdated)';
  }
}
