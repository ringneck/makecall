import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import '../services/auth_service.dart';
import 'dialog_utils.dart';

/// 공통 유틸리티 함수
/// 
/// profile_tab.dart와 profile_drawer.dart에서 공통으로 사용하는
/// 유틸리티 함수를 통합 관리합니다.
/// 
/// 주요 기능:
/// - 타임스탬프 포맷팅 (한국어 형식)
/// - 수동 새로고침 처리 (Firestore 데이터 갱신)
class CommonUtils {
  /// 타임스탬프 포맷 함수 (한국어 형식)
  /// 
  /// 1분 이내: "방금 업데이트됨"
  /// 1시간 이내: "N분 전 업데이트"
  /// 24시간 이내: "N시간 전 업데이트"
  /// 그 외: "YYYY년 MM월 DD일 오전/오후 HH:MM 업데이트"
  static String formatUpdateTimestamp(DateTime timestamp) {
    final now = DateTime.now();
    final difference = now.difference(timestamp);

    // 1분 이내
    if (difference.inSeconds < 60) {
      return '방금 업데이트됨';
    }
    // 1시간 이내
    else if (difference.inMinutes < 60) {
      return '${difference.inMinutes}분 전 업데이트';
    }
    // 24시간 이내
    else if (difference.inHours < 24) {
      return '${difference.inHours}시간 전 업데이트';
    }
    // 그 외 - 전체 날짜 표시
    else {
      final year = timestamp.year;
      final month = timestamp.month;
      final day = timestamp.day;
      final hour = timestamp.hour;
      final minute = timestamp.minute;
      final period = hour >= 12 ? '오후' : '오전';
      final displayHour = hour > 12 ? hour - 12 : (hour == 0 ? 12 : hour);

      return '$year년 $month월 $day일 $period $displayHour:${minute.toString().padLeft(2, '0')} 업데이트';
    }
  }

  /// 수동 업데이트 핸들러 (Firestore에서 사용자 데이터 새로고침)
  /// 
  /// [context]: BuildContext (다이얼로그 표시용)
  /// [authService]: AuthService 인스턴스
  /// [isRefreshing]: 현재 새로고침 중인지 여부를 나타내는 변수의 참조
  /// [setRefreshing]: 새로고침 상태를 업데이트하는 콜백
  /// 
  /// Returns: 새로고침 성공 여부 (true: 성공, false: 실패 또는 이미 실행 중)
  static Future<bool> handleManualRefresh(
    BuildContext context,
    AuthService authService, {
    required bool isRefreshing,
    required Function(bool) setRefreshing,
  }) async {
    if (isRefreshing) return false;

    setRefreshing(true);

    try {
      final userId = authService.currentUser?.uid;

      if (userId == null) {
        if (kDebugMode) {
          debugPrint('⚠️ [CommonUtils] 사용자 ID가 없어서 새로고침을 건너뜁니다');
        }
        return false;
      }

      // Firestore에서 사용자 데이터 강제 새로고침
      await authService.refreshUserModel();

      if (kDebugMode) {
        debugPrint('✅ [CommonUtils] 사용자 데이터 새로고침 완료');
      }

      if (context.mounted) {
        await DialogUtils.showSuccess(
          context,
          '정보가 업데이트되었습니다',
          duration: const Duration(seconds: 1),
        );
      }

      return true;
    } catch (e) {
      if (kDebugMode) {
        debugPrint('❌ [CommonUtils] 새로고침 실패: $e');
      }

      if (context.mounted) {
        await DialogUtils.showError(
          context,
          '업데이트 실패: $e',
        );
      }

      return false;
    } finally {
      setRefreshing(false);
    }
  }
}
