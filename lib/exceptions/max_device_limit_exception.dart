/// 최대 사용 기기 수 초과 예외
/// 
/// 사용자가 허용된 최대 기기 수를 초과하여 로그인을 시도할 때 발생합니다.
/// 
/// 사용 예:
/// ```dart
/// try {
///   await fcmTokenManager.saveFCMToken(...);
/// } on MaxDeviceLimitException catch (e) {
///   showDialog(
///     context: context,
///     builder: (context) => AlertDialog(
///       title: const Text('최대 사용 기기 수 초과'),
///       content: Text(e.getUserMessage()),
///     ),
///   );
/// }
/// ```
class MaxDeviceLimitException implements Exception {
  /// 허용된 최대 기기 수
  final int maxDevices;
  
  /// 현재 활성화된 기기 수
  final int currentDevices;
  
  /// 로그인을 시도한 새 기기 이름
  final String deviceName;
  
  MaxDeviceLimitException({
    required this.maxDevices,
    required this.currentDevices,
    required this.deviceName,
  });
  
  @override
  String toString() {
    return 'MaxDeviceLimitException: '
           'maxDevices=$maxDevices, '
           'currentDevices=$currentDevices, '
           'deviceName=$deviceName';
  }
  
  /// 사용자 친화적 에러 메시지 반환
  /// 
  /// UI에서 다이얼로그로 표시하기 적합한 메시지를 생성합니다.
  String getUserMessage() {
    return '최대 사용 기기 수를 초과했습니다.\n'
           '본 기기에서 계속 사용하시려면,\n'
           '다른 기기에서 로그아웃 하신 후\n'
           '본 기기에서 로그인 하세요.\n\n'
           '현재 활성 기기: $currentDevices개\n'
           '최대 허용 기기: $maxDevices개';
  }
  
  /// 짧은 에러 메시지 (토스트/스낵바용)
  String getShortMessage() {
    return '최대 사용 기기 수($maxDevices개)를 초과했습니다.';
  }
  
  /// 상세 정보가 포함된 로그용 메시지
  String getDetailedMessage() {
    return '최대 사용 기기 수 초과\n'
           '- 시도한 기기: $deviceName\n'
           '- 현재 활성 기기: $currentDevices개\n'
           '- 최대 허용 기기: $maxDevices개\n'
           '- 조치 방법: 다른 기기에서 로그아웃 필요';
  }
}
