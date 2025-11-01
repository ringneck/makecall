/// 전화번호 포맷팅 유틸리티
/// 
/// 뒤에서부터 4자리마다 하이픈(-)을 추가하여 포맷팅합니다.
/// 예: 01012345678 -> 010-1234-5678
///     00000000000 -> 000-0000-0000
class PhoneFormatter {
  /// 전화번호를 뒤에서부터 4자리마다 하이픈으로 구분하여 포맷팅
  /// 
  /// [phoneNumber]: 포맷팅할 전화번호 (숫자만 포함)
  /// 
  /// Returns: 포맷팅된 전화번호 문자열
  /// 
  /// Example:
  /// ```dart
  /// PhoneFormatter.format('01012345678')  // Returns: '010-1234-5678'
  /// PhoneFormatter.format('00000000000')  // Returns: '000-0000-0000'
  /// PhoneFormatter.format('12345')        // Returns: '1-2345'
  /// ```
  static String format(String phoneNumber) {
    if (phoneNumber.isEmpty) {
      return phoneNumber;
    }

    // 숫자만 추출
    final digitsOnly = phoneNumber.replaceAll(RegExp(r'[^0-9]'), '');
    
    if (digitsOnly.isEmpty) {
      return phoneNumber;
    }

    // 뒤에서부터 4자리씩 분리
    final List<String> parts = [];
    int remainingLength = digitsOnly.length;
    int endIndex = digitsOnly.length;

    while (remainingLength > 0) {
      final chunkSize = remainingLength > 4 ? 4 : remainingLength;
      final startIndex = endIndex - chunkSize;
      parts.insert(0, digitsOnly.substring(startIndex, endIndex));
      
      remainingLength -= chunkSize;
      endIndex = startIndex;
    }

    return parts.join('-');
  }

  /// 포맷팅된 전화번호에서 숫자만 추출
  /// 
  /// [formattedNumber]: 포맷팅된 전화번호
  /// 
  /// Returns: 숫자만 포함된 문자열
  /// 
  /// Example:
  /// ```dart
  /// PhoneFormatter.unformat('010-1234-5678')  // Returns: '01012345678'
  /// PhoneFormatter.unformat('000-0000-0000')  // Returns: '00000000000'
  /// ```
  static String unformat(String formattedNumber) {
    return formattedNumber.replaceAll(RegExp(r'[^0-9]'), '');
  }

  /// 전화번호가 유효한 형식인지 검증
  /// 
  /// [phoneNumber]: 검증할 전화번호
  /// [minLength]: 최소 자릿수 (기본값: 8)
  /// [maxLength]: 최대 자릿수 (기본값: 11)
  /// 
  /// Returns: 유효하면 true, 아니면 false
  static bool isValid(String phoneNumber, {int minLength = 8, int maxLength = 11}) {
    final digitsOnly = unformat(phoneNumber);
    return digitsOnly.length >= minLength && digitsOnly.length <= maxLength;
  }
}
