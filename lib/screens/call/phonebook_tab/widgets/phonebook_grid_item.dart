import 'package:flutter/material.dart';
import '../../../../models/phonebook_model.dart';
import '../utils/phonebook_category_helper.dart';
import '../utils/phonebook_translation_service.dart';
import '../utils/phonebook_responsive_helper.dart';

/// 단말번호 그리드 아이템 위젯
/// 
/// 그리드뷰 모드에서 사용하는 연락처 카드 위젯
class PhonebookGridItem extends StatelessWidget {
  final PhonebookContactModel contact;
  final List<String>? registeredExtensions;
  final VoidCallback onTap;
  final VoidCallback onLongPress;

  const PhonebookGridItem({
    required this.contact,
    required this.onTap,
    required this.onLongPress,
    this.registeredExtensions,
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    
    // 카테고리 정보 가져오기
    final categoryInfo = PhonebookCategoryHelper.getCategoryInfo(
      contact,
      registeredExtensions: registeredExtensions,
    );
    
    // 이름 번역
    final translatedName = PhonebookTranslationService.translate(contact.name);

    return Card(
      elevation: 1,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(
          PhonebookResponsiveHelper.getResponsiveSize(context, 8),
        ),
        side: BorderSide(
          color: contact.isFavorite 
              ? (isDark ? Colors.amber[700]!.withAlpha(128) : Colors.amber.withAlpha(128))
              : (isDark 
                  ? categoryInfo.color.withAlpha(102)
                  : categoryInfo.color.withAlpha(77)),
          width: contact.isFavorite ? 1.5 : 0.5,
        ),
      ),
      child: InkWell(
        onTap: onTap,
        onLongPress: onLongPress,
        borderRadius: BorderRadius.circular(
          PhonebookResponsiveHelper.getResponsiveSize(context, 8),
        ),
        child: Padding(
          padding: EdgeInsets.all(
            PhonebookResponsiveHelper.getResponsiveSize(context, 3),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // 아이콘 (즐겨찾기 별 표시 포함)
              _buildContactIcon(context, isDark, categoryInfo),
              
              SizedBox(height: PhonebookResponsiveHelper.getResponsiveSize(context, 3)),
              
              // 이름
              Flexible(
                child: Text(
                  translatedName,
                  style: TextStyle(
                    fontSize: PhonebookResponsiveHelper.getResponsiveSize(context, 10),
                    fontWeight: FontWeight.bold,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  textAlign: TextAlign.center,
                ),
              ),
              
              SizedBox(height: PhonebookResponsiveHelper.getResponsiveSize(context, 1)),
              
              // 전화번호 (더 크게 표시)
              Flexible(
                child: Text(
                  contact.telephone,
                  style: TextStyle(
                    fontSize: PhonebookResponsiveHelper.getResponsiveSize(context, 13),
                    fontWeight: FontWeight.w700,
                    color: isDark ? Colors.grey[200] : Colors.black87,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  textAlign: TextAlign.center,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// 연락처 아이콘 빌드
  Widget _buildContactIcon(BuildContext context, bool isDark, CategoryInfo categoryInfo) {
    return Stack(
      children: [
        // 메인 아이콘
        Container(
          width: PhonebookResponsiveHelper.getResponsiveSize(context, 36),
          height: PhonebookResponsiveHelper.getResponsiveSize(context, 36),
          decoration: BoxDecoration(
            color: contact.isFavorite
                ? (isDark ? Colors.amber[900]!.withAlpha(128) : Colors.amber[100])
                : (isDark 
                    ? categoryInfo.color.withAlpha(77)
                    : categoryInfo.color.withAlpha(51)),
            shape: BoxShape.circle,
          ),
          child: Icon(
            contact.isFavorite ? Icons.star : categoryInfo.icon,
            size: PhonebookResponsiveHelper.getResponsiveSize(context, 18),
            color: contact.isFavorite 
                ? (isDark ? Colors.amber[300] : Colors.amber[700])
                : PhonebookCategoryHelper.getCategoryIconColor(categoryInfo.color, isDark),
          ),
        ),
        
        // 등록된 단말번호 배지
        if (categoryInfo.isRegistered)
          _buildRegisteredBadge(context, isDark),
        
        // 다른 사용자 배지
        if (categoryInfo.isOtherUserExtension)
          _buildOtherUserBadge(context, isDark),
      ],
    );
  }

  /// 등록된 단말번호 배지
  Widget _buildRegisteredBadge(BuildContext context, bool isDark) {
    return Positioned(
      right: 0,
      bottom: 0,
      child: Container(
        width: PhonebookResponsiveHelper.getResponsiveSize(context, 12),
        height: PhonebookResponsiveHelper.getResponsiveSize(context, 12),
        decoration: BoxDecoration(
          color: isDark ? Colors.grey[850] : Colors.white,
          shape: BoxShape.circle,
          border: Border.all(
            color: isDark ? Colors.green[400]! : Colors.green, 
            width: 1,
          ),
        ),
        child: ClipOval(
          child: Image.asset(
            'assets/images/app_logo.png',
            fit: BoxFit.cover,
          ),
        ),
      ),
    );
  }

  /// 다른 사용자 배지
  Widget _buildOtherUserBadge(BuildContext context, bool isDark) {
    return Positioned(
      right: 0,
      bottom: 0,
      child: Container(
        width: PhonebookResponsiveHelper.getResponsiveSize(context, 10),
        height: PhonebookResponsiveHelper.getResponsiveSize(context, 10),
        decoration: BoxDecoration(
          color: isDark ? Colors.grey[700] : Colors.grey[300],
          shape: BoxShape.circle,
          border: Border.all(
            color: isDark ? Colors.grey[600]! : Colors.grey[500]!, 
            width: 0.5,
          ),
        ),
        child: Icon(
          Icons.person,
          size: PhonebookResponsiveHelper.getResponsiveSize(context, 6),
          color: isDark ? Colors.grey[400] : Colors.grey[700],
        ),
      ),
    );
  }
}
