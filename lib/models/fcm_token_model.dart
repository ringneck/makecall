import 'package:cloud_firestore/cloud_firestore.dart';

/// FCM 토큰 관리 모델
/// 
/// 사용자의 FCM 등록 토큰을 관리하여 중복 로그인을 방지합니다.
/// 한 사용자당 하나의 활성 세션(토큰)만 유지됩니다.
class FcmTokenModel {
  final String userId;           // 사용자 ID (Firebase UID)
  final String fcmToken;         // FCM 등록 토큰
  final String deviceId;         // 기기 고유 식별자
  final String deviceName;       // 기기 이름 (예: "iPhone 15 Pro")
  final String platform;         // 플랫폼 (ios, android, web)
  final DateTime createdAt;      // 토큰 생성 시간
  final DateTime lastActiveAt;   // 마지막 활동 시간
  final bool isActive;           // 활성 상태
  final bool isApproved;         // 기기 승인 여부 (첫 기기는 자동 승인, 추가 기기는 승인 필요)

  FcmTokenModel({
    required this.userId,
    required this.fcmToken,
    required this.deviceId,
    required this.deviceName,
    required this.platform,
    required this.createdAt,
    required this.lastActiveAt,
    this.isActive = true,
    this.isApproved = true, // 기본값: 승인됨 (하위 호환성)
  });

  /// Firestore에서 데이터를 가져와 모델로 변환
  factory FcmTokenModel.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return FcmTokenModel(
      userId: data['userId'] as String? ?? '',
      fcmToken: data['fcmToken'] as String? ?? '',
      deviceId: data['deviceId'] as String? ?? '',
      deviceName: data['deviceName'] as String? ?? '',
      platform: data['platform'] as String? ?? '',
      createdAt: (data['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      lastActiveAt: (data['lastActiveAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      isActive: data['isActive'] as bool? ?? true,
      isApproved: data['isApproved'] as bool? ?? true, // 기존 데이터는 승인된 것으로 간주
    );
  }

  /// Map으로 변환하여 Firestore에 저장
  Map<String, dynamic> toMap() {
    return {
      'userId': userId,
      'fcmToken': fcmToken,
      'deviceId': deviceId,
      'deviceName': deviceName,
      'platform': platform,
      'createdAt': Timestamp.fromDate(createdAt),
      'lastActiveAt': Timestamp.fromDate(lastActiveAt),
      'isActive': isActive,
      'isApproved': isApproved,
    };
  }

  /// 복사본 생성 (일부 필드 수정)
  FcmTokenModel copyWith({
    String? userId,
    String? fcmToken,
    String? deviceId,
    String? deviceName,
    String? platform,
    DateTime? createdAt,
    DateTime? lastActiveAt,
    bool? isActive,
    bool? isApproved,
  }) {
    return FcmTokenModel(
      userId: userId ?? this.userId,
      fcmToken: fcmToken ?? this.fcmToken,
      deviceId: deviceId ?? this.deviceId,
      deviceName: deviceName ?? this.deviceName,
      platform: platform ?? this.platform,
      createdAt: createdAt ?? this.createdAt,
      lastActiveAt: lastActiveAt ?? this.lastActiveAt,
      isActive: isActive ?? this.isActive,
      isApproved: isApproved ?? this.isApproved,
    );
  }

  @override
  String toString() {
    return 'FcmTokenModel(userId: $userId, deviceName: $deviceName, platform: $platform, isActive: $isActive, isApproved: $isApproved)';
  }
}
