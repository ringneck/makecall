import 'package:flutter/material.dart';
import '../../../models/phonebook_model.dart';
import '../utils/phonebook_category_helper.dart';
import '../utils/phonebook_translation_service.dart';

/// 단말번호 리스트 아이템 위젯
/// 
/// 리스트뷰 모드에서 사용하는 연락처 ListTile 위젯
class PhonebookListItem extends StatelessWidget {
  final PhonebookContactModel contact;
  final List<String>? registeredExtensions;
  final VoidCallback onTap;
  final VoidCallback onToggleFavorite;
  final VoidCallback onQuickCall;

  const PhonebookListItem({
    required this.contact,
    required this.onTap,
    required this.onToggleFavorite,
    required this.onQuickCall,
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

    return ListTile(
      leading: _buildLeadingAvatar(isDark, categoryInfo),
      title: _buildTitle(categoryInfo),
      subtitle: _buildSubtitle(isDark, translatedName),
      trailing: _buildTrailing(isDark),
      onTap: onTap,
    );
  }

  /// Leading 아바타 (아이콘 + 배지)
  Widget _buildLeadingAvatar(bool isDark, CategoryInfo categoryInfo) {
    return Stack(
      children: [
        // 메인 아바타
        CircleAvatar(
          backgroundColor: contact.isFavorite
              ? (isDark ? Colors.amber[900]!.withAlpha(128) : Colors.amber[100])
              : (isDark 
                  ? categoryInfo.color.withAlpha(77) 
                  : categoryInfo.color.withAlpha(51)),
          child: Icon(
            contact.isFavorite ? Icons.star : categoryInfo.icon,
            color: contact.isFavorite 
                ? (isDark ? Colors.amber[300] : Colors.amber[700])
                : PhonebookCategoryHelper.getCategoryIconColor(categoryInfo.color, isDark),
          ),
        ),
        
        // 등록된 단말번호 배지
        if (categoryInfo.isRegistered)
          _buildRegisteredBadge(isDark),
        
        // 다른 사용자 배지
        if (categoryInfo.isOtherUserExtension)
          _buildOtherUserBadge(isDark),
      ],
    );
  }

  /// 등록된 단말번호 배지
  Widget _buildRegisteredBadge(bool isDark) {
    return Positioned(
      right: 0,
      bottom: 0,
      child: Container(
        width: 20,
        height: 20,
        decoration: BoxDecoration(
          color: isDark ? Colors.grey[850] : Colors.white,
          shape: BoxShape.circle,
          border: Border.all(
            color: isDark ? Colors.green[400]! : Colors.green, 
            width: 1.5,
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
  Widget _buildOtherUserBadge(bool isDark) {
    return Positioned(
      right: 0,
      bottom: 0,
      child: Container(
        width: 18,
        height: 18,
        decoration: BoxDecoration(
          color: isDark ? Colors.grey[700] : Colors.grey[300],
          shape: BoxShape.circle,
          border: Border.all(
            color: isDark ? Colors.grey[600]! : Colors.grey[500]!, 
            width: 1,
          ),
        ),
        child: Icon(
          Icons.person,
          size: 12,
          color: isDark ? Colors.grey[400] : Colors.grey[700],
        ),
      ),
    );
  }

  /// 타이틀 (이름 + 카테고리 태그)
  Widget _buildTitle(CategoryInfo categoryInfo) {
    final translatedName = PhonebookTranslationService.translate(contact.name);
    
    return Row(
      children: [
        // 즐겨찾기 별 아이콘 (이름 앞)
        if (contact.isFavorite)
          const Padding(
            padding: EdgeInsets.only(right: 4),
            child: Icon(Icons.star, size: 16, color: Colors.amber),
          ),
        Expanded(
          child: Text(
            translatedName,
            style: const TextStyle(fontWeight: FontWeight.w600),
          ),
        ),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          decoration: BoxDecoration(
            color: categoryInfo.color.withAlpha(26),
            borderRadius: BorderRadius.circular(4),
            border: Border.all(color: categoryInfo.color.withAlpha(77)),
          ),
          child: Text(
            contact.categoryDisplay,
            style: TextStyle(
              fontSize: 11,
              color: categoryInfo.color,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ],
    );
  }

  /// 서브타이틀 (전화번호 + 회사명)
  Widget _buildSubtitle(bool isDark, String translatedName) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          contact.telephone,
          style: const TextStyle(fontWeight: FontWeight.w500),
        ),
        if (contact.company != null)
          Text(
            contact.company!,
            style: TextStyle(
              fontSize: 12, 
              color: isDark ? Colors.grey[500] : Colors.grey[600],
            ),
          ),
      ],
    );
  }

  /// 트레일링 (즐겨찾기 버튼 + 전화 걸기 버튼)
  Widget _buildTrailing(bool isDark) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        // 즐겨찾기 토글 버튼
        IconButton(
          icon: Icon(
            contact.isFavorite ? Icons.star : Icons.star_border,
            color: contact.isFavorite 
                ? (isDark ? Colors.amber[300] : Colors.amber)
                : (isDark ? Colors.grey[600] : Colors.grey),
          ),
          onPressed: onToggleFavorite,
          tooltip: contact.isFavorite ? '즐겨찾기 해제' : '즐겨찾기 추가',
        ),
        // 전화 걸기 버튼
        IconButton(
          icon: Icon(
            Icons.phone, 
            color: isDark ? Colors.blue[300] : const Color(0xFF2196F3),
          ),
          onPressed: onQuickCall,
          tooltip: '빠른 발신',
        ),
      ],
    );
  }
}
