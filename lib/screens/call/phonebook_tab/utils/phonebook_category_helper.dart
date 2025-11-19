import 'package:flutter/material.dart';
import '../../../../models/phonebook_model.dart';

/// 단말번호 카테고리 정보
class CategoryInfo {
  final Color color;
  final IconData icon;
  final bool isRegistered;
  final bool isOtherUserExtension;

  const CategoryInfo({
    required this.color,
    required this.icon,
    required this.isRegistered,
    required this.isOtherUserExtension,
  });
}

/// 단말번호 카테고리 헬퍼
/// 
/// 연락처 카테고리에 따른 색상, 아이콘, 상태를 관리합니다.
class PhonebookCategoryHelper {
  /// 카테고리 정보 가져오기
  /// 
  /// [contact]: 연락처 모델
  /// [registeredExtensions]: 등록된 단말번호 목록 (옵션)
  /// 
  /// 반환: 카테고리 색상, 아이콘, 등록 상태
  static CategoryInfo getCategoryInfo(
    PhonebookContactModel contact, {
    List<String>? registeredExtensions,
  }) {
    Color categoryColor = Colors.blue;
    IconData categoryIcon = Icons.phone;

    // 카테고리별 색상 및 아이콘 결정
    if (contact.category == 'Extensions') {
      categoryColor = Colors.green;
      categoryIcon = Icons.phone_android;
    } else if (contact.category == 'Feature Codes') {
      categoryColor = Colors.orange;
      categoryIcon = Icons.star;
    }

    // 등록 여부 확인
    final isRegistered = registeredExtensions?.contains(contact.telephone) ?? false;
    
    // 다른 사용자의 단말번호 여부 (Extensions 카테고리이면서 본인이 등록하지 않은 경우)
    final isOtherUserExtension = contact.category == 'Extensions' && !isRegistered;

    return CategoryInfo(
      color: categoryColor,
      icon: categoryIcon,
      isRegistered: isRegistered,
      isOtherUserExtension: isOtherUserExtension,
    );
  }

  /// 다크 모드에 따른 카테고리 색상 가져오기
  /// 
  /// [categoryColor]: 기본 카테고리 색상
  /// [isDark]: 다크 모드 여부
  /// [alpha]: 투명도 (0~255)
  static Color getCategoryColorWithOpacity(
    Color categoryColor,
    bool isDark, {
    int alpha = 77,
  }) {
    if (isDark) {
      return categoryColor.withAlpha(alpha);
    } else {
      return categoryColor.withAlpha((alpha * 0.66).toInt());
    }
  }

  /// 다크 모드에 따른 카테고리 아이콘 색상 가져오기
  static Color getCategoryIconColor(Color categoryColor, bool isDark) {
    if (isDark) {
      if (categoryColor == Colors.blue) {
        return Colors.blue[300]!;
      } else if (categoryColor == Colors.green) {
        return Colors.green[300]!;
      } else if (categoryColor == Colors.orange) {
        return Colors.orange[300]!;
      }
    }
    return categoryColor;
  }
}
