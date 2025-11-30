/// 한글 초성 검색 유틸리티
/// 
/// 초성만으로 한글 이름을 검색할 수 있는 기능 제공
/// 예: "ㄱㅎㄷ" → "김현동", "강효동" 등 매칭
class KoreanSearchUtils {
  // 한글 초성 리스트
  static const List<String> _chosung = [
    'ㄱ', 'ㄲ', 'ㄴ', 'ㄷ', 'ㄸ', 'ㄹ', 'ㅁ', 'ㅂ', 'ㅃ',
    'ㅅ', 'ㅆ', 'ㅇ', 'ㅈ', 'ㅉ', 'ㅊ', 'ㅋ', 'ㅌ', 'ㅍ', 'ㅎ'
  ];

  /// 한글 문자에서 초성 추출
  /// 
  /// 예: '김' → 'ㄱ', '이' → 'ㅇ'
  static String? getChosung(String char) {
    if (char.isEmpty) return null;
    
    final code = char.codeUnitAt(0);
    
    // 한글 유니코드 범위: 0xAC00 ~ 0xD7A3
    if (code >= 0xAC00 && code <= 0xD7A3) {
      final chosungIndex = ((code - 0xAC00) / 28 / 21).floor();
      return _chosung[chosungIndex];
    }
    
    // 이미 초성인 경우
    if (_chosung.contains(char)) {
      return char;
    }
    
    return null;
  }

  /// 문자열에서 초성 문자열 추출
  /// 
  /// 예: '김현동' → 'ㄱㅎㄷ'
  static String getChosungString(String text) {
    final buffer = StringBuffer();
    
    for (int i = 0; i < text.length; i++) {
      final chosung = getChosung(text[i]);
      if (chosung != null) {
        buffer.write(chosung);
      }
    }
    
    return buffer.toString();
  }

  /// 부분 문자열 검색 (대소문자 구분 없음)
  /// 
  /// query: 검색어
  /// target: 검색 대상 문자열
  /// 
  /// 반환: 매칭 여부
  /// 
  /// 예:
  /// - matchesChosung('김', '김현동') → true
  /// - matchesChosung('현', '김현동') → true
  /// - matchesChosung('010', '010-1234-5678') → true
  /// - matchesChosung('echo', 'Echo Test') → true
  static bool matchesChosung(String query, String target) {
    if (query.isEmpty || target.isEmpty) return false;
    
    // 쿼리와 타겟을 소문자로 변환하여 부분 문자열 검색
    final lowerQuery = query.toLowerCase();
    final lowerTarget = target.toLowerCase();
    
    return lowerTarget.contains(lowerQuery);
  }

  /// 혼합 검색 (초성 + 일반 문자)
  static bool _matchesMixed(String query, String target, String targetChosung) {
    int queryIndex = 0;
    int targetIndex = 0;
    
    while (queryIndex < query.length && targetIndex < target.length) {
      final queryChar = query[queryIndex];
      
      // 쿼리 문자가 초성인 경우
      if (_chosung.contains(queryChar)) {
        // 타겟의 초성과 비교
        final targetChar = target[targetIndex];
        final targetCharChosung = getChosung(targetChar);
        
        if (targetCharChosung == queryChar) {
          queryIndex++;
          targetIndex++;
        } else {
          targetIndex++;
        }
      } else {
        // 일반 문자인 경우
        if (target[targetIndex] == queryChar) {
          queryIndex++;
          targetIndex++;
        } else {
          targetIndex++;
        }
      }
    }
    
    return queryIndex == query.length;
  }

  /// 여러 필드에서 초성 검색
  /// 
  /// query: 검색어
  /// fields: 검색 대상 필드 리스트
  /// 
  /// 반환: 하나라도 매칭되면 true
  static bool matchesAnyField(String query, List<String?> fields) {
    if (query.isEmpty) return true;
    
    for (final field in fields) {
      if (field != null && field.isNotEmpty) {
        if (matchesChosung(query, field)) {
          return true;
        }
      }
    }
    
    return false;
  }

  /// 전화번호 검색 (숫자만)
  /// 
  /// query: 검색어
  /// phoneNumber: 전화번호
  /// 
  /// 반환: 전화번호에 검색어가 포함되면 true
  static bool matchesPhoneNumber(String query, String phoneNumber) {
    if (query.isEmpty) return true;
    
    // 숫자만 추출
    final queryDigits = query.replaceAll(RegExp(r'[^0-9]'), '');
    final phoneDigits = phoneNumber.replaceAll(RegExp(r'[^0-9]'), '');
    
    return phoneDigits.contains(queryDigits);
  }
}
