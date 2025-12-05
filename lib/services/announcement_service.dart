import 'package:flutter/foundation.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

/// 📢 공지사항 서비스
/// 
/// Firestore에서 공지사항을 조회하고 관리합니다.
/// 
/// Firestore 데이터 구조:
/// ```
/// app_config/announcements (collection)
/// {
///   "id": "announcement_001",
///   "title": "공지사항 제목",
///   "message": "공지사항 내용",
///   "priority": "high", // high, normal, low
///   "is_active": true,
///   "start_date": Timestamp,
///   "end_date": Timestamp,
///   "created_at": Timestamp
/// }
/// ```
class AnnouncementService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  
  /// 활성 공지사항 조회
  Future<AnnouncementData?> getActiveAnnouncement() async {
    try {
      final now = Timestamp.now();
      
      // 활성 공지사항 조회 (is_active=true, 기간 내, priority 높은 순)
      final querySnapshot = await _firestore
          .collection('app_config')
          .doc('announcements')
          .collection('items')
          .where('is_active', isEqualTo: true)
          .where('start_date', isLessThanOrEqualTo: now)
          .where('end_date', isGreaterThanOrEqualTo: now)
          .orderBy('start_date')
          .orderBy('priority', descending: true)
          .limit(1)
          .get();
      
      if (querySnapshot.docs.isEmpty) {
        if (kDebugMode) {
          debugPrint('📢 [ANNOUNCEMENT] 활성 공지사항 없음');
        }
        return null;
      }
      
      final doc = querySnapshot.docs.first;
      final data = doc.data();
      
      final announcement = AnnouncementData(
        id: doc.id,
        title: data['title'] as String? ?? '공지사항',
        message: data['message'] as String? ?? '',
        priority: data['priority'] as String? ?? 'normal',
        isActive: data['is_active'] as bool? ?? true,
        startDate: (data['start_date'] as Timestamp?)?.toDate(),
        endDate: (data['end_date'] as Timestamp?)?.toDate(),
        createdAt: (data['created_at'] as Timestamp?)?.toDate(),
      );
      
      if (kDebugMode) {
        debugPrint('📢 [ANNOUNCEMENT] 공지사항 조회 성공');
        debugPrint('   ID: ${announcement.id}');
        debugPrint('   Title: ${announcement.title}');
        debugPrint('   Priority: ${announcement.priority}');
      }
      
      return announcement;
    } catch (e) {
      if (kDebugMode) {
        debugPrint('❌ [ANNOUNCEMENT] 조회 실패: $e');
      }
      return null;
    }
  }
}

/// 공지사항 데이터 모델
class AnnouncementData {
  final String id;
  final String title;
  final String message;
  final String priority; // high, normal, low
  final bool isActive;
  final DateTime? startDate;
  final DateTime? endDate;
  final DateTime? createdAt;
  
  AnnouncementData({
    required this.id,
    required this.title,
    required this.message,
    required this.priority,
    required this.isActive,
    this.startDate,
    this.endDate,
    this.createdAt,
  });
  
  /// 우선순위 색상
  String get priorityColor {
    switch (priority) {
      case 'high':
        return '#EF5350'; // 빨강
      case 'low':
        return '#66BB6A'; // 초록
      case 'normal':
      default:
        return '#1976D2'; // 파랑
    }
  }
  
  /// 우선순위 아이콘
  String get priorityIcon {
    switch (priority) {
      case 'high':
        return '⚠️';
      case 'low':
        return 'ℹ️';
      case 'normal':
      default:
        return '📢';
    }
  }
}
