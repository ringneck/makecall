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
  /// 
  /// 복합 인덱스 없이 작동하도록 단순 쿼리 + 메모리 필터링 방식 사용
  Future<AnnouncementData?> getActiveAnnouncement() async {
    try {
      final now = DateTime.now();
      
      // ✅ 단순 쿼리: is_active만 필터링 (인덱스 불필요)
      final querySnapshot = await _firestore
          .collection('app_config')
          .doc('announcements')
          .collection('items')
          .where('is_active', isEqualTo: true)
          .get();
      
      if (querySnapshot.docs.isEmpty) {
        if (kDebugMode) {
          debugPrint('📢 [ANNOUNCEMENT] 활성 공지사항 없음');
        }
        return null;
      }
      
      // 메모리에서 기간 필터링 및 정렬
      final announcements = querySnapshot.docs
          .map((doc) {
            final data = doc.data();
            return AnnouncementData(
              id: doc.id,
              title: data['title'] as String? ?? '공지사항',
              message: data['message'] as String? ?? '',
              priority: data['priority'] as String? ?? 'normal',
              isActive: data['is_active'] as bool? ?? true,
              startDate: (data['start_date'] as Timestamp?)?.toDate(),
              endDate: (data['end_date'] as Timestamp?)?.toDate(),
              createdAt: (data['created_at'] as Timestamp?)?.toDate(),
            );
          })
          .where((announcement) {
            // 기간 내 공지사항만 필터링
            if (announcement.startDate != null && 
                announcement.startDate!.isAfter(now)) {
              return false;
            }
            if (announcement.endDate != null && 
                announcement.endDate!.isBefore(now)) {
              return false;
            }
            return true;
          })
          .toList();
      
      if (announcements.isEmpty) {
        if (kDebugMode) {
          debugPrint('📢 [ANNOUNCEMENT] 기간 내 공지사항 없음');
        }
        return null;
      }
      
      // 우선순위 순으로 정렬 (high > normal > low)
      announcements.sort((a, b) {
        final priorityOrder = {'high': 3, 'normal': 2, 'low': 1};
        final aPriority = priorityOrder[a.priority] ?? 0;
        final bPriority = priorityOrder[b.priority] ?? 0;
        return bPriority.compareTo(aPriority);
      });
      
      final announcement = announcements.first;
      
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
