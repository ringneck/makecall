/// 동의 이력 레코드
/// 
/// 개인정보보호법 준수를 위한 동의 이력 추적
/// - 동의 버전
/// - 동의 일시
/// - 동의 타입 (최초/갱신/업데이트)
class ConsentRecord {
  final String version;           // 약관 버전 (예: "1.0")
  final DateTime agreedAt;        // 동의 일시
  final String type;              // 'initial' | 'renewal' | 'update'
  final String? ipAddress;        // 동의 시 IP 주소 (선택)
  
  ConsentRecord({
    required this.version,
    required this.agreedAt,
    required this.type,
    this.ipAddress,
  });
  
  /// Firestore 맵에서 ConsentRecord 생성
  factory ConsentRecord.fromMap(Map<String, dynamic> map) {
    // Firestore Timestamp 또는 String을 DateTime으로 변환
    DateTime parseTimestamp(dynamic value) {
      if (value == null) return DateTime.now();
      if (value is String) {
        return DateTime.parse(value);
      }
      // Firestore Timestamp 처리
      if (value.runtimeType.toString().contains('Timestamp')) {
        return (value as dynamic).toDate() as DateTime;
      }
      return DateTime.now();
    }
    
    return ConsentRecord(
      version: map['version'] as String? ?? '1.0',
      agreedAt: parseTimestamp(map['agreedAt']),
      type: map['type'] as String? ?? 'initial',
      ipAddress: map['ipAddress'] as String?,
    );
  }
  
  /// Firestore 저장용 맵으로 변환
  Map<String, dynamic> toMap() {
    return {
      'version': version,
      'agreedAt': agreedAt.toIso8601String(),
      'type': type,
      if (ipAddress != null) 'ipAddress': ipAddress,
    };
  }
}
