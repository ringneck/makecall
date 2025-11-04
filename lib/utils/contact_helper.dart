import 'package:flutter/foundation.dart';
import 'package:flutter_contacts/flutter_contacts.dart';

/// 📞 연락처 조회 헬퍼
/// 
/// 전화번호로 기기 연락처에서 이름을 조회하는 유틸리티
class ContactHelper {
  // Singleton 패턴
  static final ContactHelper _instance = ContactHelper._internal();
  factory ContactHelper() => _instance;
  ContactHelper._internal();
  
  // 연락처 권한 상태 캐시
  bool? _hasPermission;
  
  /// 전화번호로 연락처 정보 조회 (이름 + 사진)
  /// 
  /// [phoneNumber] - 조회할 전화번호
  /// Returns: {name: String?, photo: Uint8List?} 또는 null
  Future<Map<String, dynamic>?> getContactInfoByPhone(String phoneNumber) async {
    try {
      // 1. 연락처 권한 확인
      if (!await _checkPermission()) {
        if (kDebugMode) {
          debugPrint('⚠️ ContactHelper: 연락처 권한 없음');
        }
        return null;
      }
      
      // 2. 전화번호 정규화 (하이픈, 공백 제거)
      final normalizedPhone = _normalizePhoneNumber(phoneNumber);
      
      if (kDebugMode) {
        debugPrint('🔍 ContactHelper: 연락처 조회 중...');
        debugPrint('  원본 번호: $phoneNumber');
        debugPrint('  정규화 번호: $normalizedPhone');
      }
      
      // 3. 연락처 조회 (사진 포함)
      final contacts = await FlutterContacts.getContacts(
        withProperties: true,
        withPhoto: true,
      );
      
      if (kDebugMode) {
        debugPrint('📱 ContactHelper: 총 ${contacts.length}개 연락처 검색');
      }
      
      // 4. 전화번호 매칭
      for (final contact in contacts) {
        for (final phone in contact.phones) {
          final contactPhone = _normalizePhoneNumber(phone.number);
          
          // 정규화된 번호로 비교
          if (_matchPhoneNumbers(normalizedPhone, contactPhone)) {
            final name = contact.displayName;
            final photo = contact.photo;
            
            if (kDebugMode) {
              debugPrint('✅ ContactHelper: 연락처 찾음!');
              debugPrint('  이름: $name');
              debugPrint('  사진: ${photo != null ? "${photo.length} bytes" : "없음"}');
              debugPrint('  연락처 번호: ${phone.number}');
            }
            
            return {
              'name': name,
              'photo': photo,
            };
          }
        }
      }
      
      if (kDebugMode) {
        debugPrint('❌ ContactHelper: 연락처를 찾지 못함');
      }
      return null;
      
    } catch (e) {
      if (kDebugMode) {
        debugPrint('❌ ContactHelper: 연락처 조회 오류: $e');
      }
      return null;
    }
  }

  /// 전화번호로 연락처 이름 조회 (기존 메서드 유지)
  /// 
  /// [phoneNumber] - 조회할 전화번호
  /// Returns: 연락처 이름 또는 null (찾지 못한 경우)
  Future<String?> getContactNameByPhone(String phoneNumber) async {
    final contactInfo = await getContactInfoByPhone(phoneNumber);
    return contactInfo?['name'] as String?;
  }
  
  /// 연락처 권한 확인
  Future<bool> _checkPermission() async {
    // 캐시된 권한 상태가 있으면 재사용
    if (_hasPermission != null) {
      return _hasPermission!;
    }
    
    try {
      // flutter_contacts 패키지의 권한 확인
      final granted = await FlutterContacts.requestPermission();
      _hasPermission = granted;
      
      if (kDebugMode) {
        debugPrint('📋 ContactHelper: 연락처 권한 ${granted ? "허용됨" : "거부됨"}');
      }
      
      return granted;
    } catch (e) {
      if (kDebugMode) {
        debugPrint('❌ ContactHelper: 권한 확인 오류: $e');
      }
      _hasPermission = false;
      return false;
    }
  }
  
  /// 전화번호 정규화
  /// 
  /// 하이픈(-), 공백, 괄호 등을 제거하고 숫자만 남김
  String _normalizePhoneNumber(String phone) {
    // 숫자만 추출
    String normalized = phone.replaceAll(RegExp(r'[^\d+]'), '');
    
    // 국가 코드 정규화
    if (normalized.startsWith('82')) {
      // +82 또는 82로 시작하는 경우 → 0으로 변환
      normalized = '0${normalized.substring(2)}';
    } else if (normalized.startsWith('+82')) {
      normalized = '0${normalized.substring(3)}';
    }
    
    return normalized;
  }
  
  /// 전화번호 매칭
  /// 
  /// 두 전화번호가 같은 번호인지 확인
  /// - 끝 8자리가 일치하면 같은 번호로 간주 (국가 코드 변형 대응)
  bool _matchPhoneNumbers(String phone1, String phone2) {
    // 정확히 일치
    if (phone1 == phone2) return true;
    
    // 끝 8자리 비교 (모바일 번호 매칭)
    if (phone1.length >= 8 && phone2.length >= 8) {
      final suffix1 = phone1.substring(phone1.length - 8);
      final suffix2 = phone2.substring(phone2.length - 8);
      
      if (suffix1 == suffix2) {
        if (kDebugMode) {
          debugPrint('  📞 번호 매칭 (끝 8자리): $suffix1');
        }
        return true;
      }
    }
    
    return false;
  }
  
  /// 권한 캐시 초기화 (테스트용)
  void resetPermissionCache() {
    _hasPermission = null;
  }
}
