import 'package:flutter/material.dart';

/// 단말번호 탭 반응형 레이아웃 헬퍼
/// 
/// 화면 크기에 따라 그리드 레이아웃과 크기를 동적으로 조정합니다.
class PhonebookResponsiveHelper {
  /// 반응형 크기 계산
  /// 
  /// 기준: 360px (일반 스마트폰 너비)
  /// 태블릿: ~600px 이상
  /// 
  /// [baseSize]: 기준 크기 (360px 기준)
  /// 반환: 스케일링된 크기 (최소 0.8배, 최대 2배)
  static double getResponsiveSize(BuildContext context, double baseSize) {
    final screenWidth = MediaQuery.of(context).size.width;
    final scaleFactor = screenWidth / 360.0;
    return baseSize * scaleFactor.clamp(0.8, 2.0);
  }

  /// 화면 크기에 따라 그리드 컬럼 수 결정
  /// 
  /// - 1024px 이상: 6열 (대형 태블릿/데스크톱)
  /// - 768px 이상: 5열 (일반 태블릿)
  /// - 600px 이상: 4열 (소형 태블릿)
  /// - 600px 미만: 3열 (스마트폰)
  static int getGridColumnCount(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    
    if (screenWidth >= 1024) {
      return 6; // 대형 태블릿/데스크톱: 6열
    } else if (screenWidth >= 768) {
      return 5; // 일반 태블릿: 5열
    } else if (screenWidth >= 600) {
      return 4; // 소형 태블릿: 4열
    } else {
      return 3; // 스마트폰: 3열
    }
  }

  /// 화면 방향에 따라 그리드 childAspectRatio 결정
  /// 
  /// Landscape 모드에서는 더 넓은 비율 (높이 확보)
  /// Portrait 모드에서는 더 높은 비율
  static double getGridChildAspectRatio(BuildContext context) {
    final orientation = MediaQuery.of(context).orientation;
    final screenWidth = MediaQuery.of(context).size.width;
    
    if (orientation == Orientation.landscape) {
      // 랜드스케이프 모드: 더 넓은 비율 (높이를 더 확보)
      if (screenWidth >= 1024) {
        return 1.15; // 대형 화면
      } else if (screenWidth >= 768) {
        return 1.05; // 태블릿
      } else {
        return 1.0; // 스마트폰
      }
    } else {
      // 포트레이트 모드: 높이 여유 확보
      return 0.9;
    }
  }
}
