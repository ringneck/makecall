import 'package:flutter/material.dart';
import '../../../../models/call_history_model.dart';
import '../../../../theme/call_theme_extension.dart';

/// 통화 기록의 단말번호 정보를 표시하는 위젯
/// 
/// 착신전환 상태와 통화 상태에 따라 다른 색상과 아이콘을 표시합니다.
class ExtensionInfoWidget extends StatelessWidget {
  final CallHistoryModel call;

  const ExtensionInfoWidget({
    super.key,
    required this.call,
  });

  @override
  Widget build(BuildContext context) {
    final callTheme = CallThemeColors(context);
    final isForwardEnabled = call.callForwardEnabled == true;
    final destinationNumber = call.callForwardDestination ?? '';
    
    // 상태에 따른 색상 결정 (테마 색상 헬퍼 사용)
    Color badgeColor;
    Color textColor;
    if (isForwardEnabled) {
      // 착신전환 활성화: 주황색
      badgeColor = callTheme.forwardedCallBackgroundColor;
      textColor = callTheme.forwardedCallColor;
    } else if (call.status == 'device_answered') {
      // 단말수신: 녹색
      badgeColor = callTheme.deviceAnsweredBackgroundColor;
      textColor = callTheme.deviceAnsweredColor;
    } else if (call.status == 'confirmed') {
      // 알림확인: 파란색
      badgeColor = callTheme.confirmedCallBackgroundColor;
      textColor = callTheme.confirmedCallColor;
    } else {
      // 기본: 파란색
      badgeColor = callTheme.defaultBadgeBackgroundColor;
      textColor = callTheme.defaultBadgeColor;
    }
    
    return Padding(
      padding: const EdgeInsets.only(top: 4),
      child: Row(
        children: [
          Expanded(
            child: Container(
              padding: const EdgeInsets.symmetric(
                horizontal: 8,
                vertical: 3,
              ),
              decoration: BoxDecoration(
                color: badgeColor,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                  color: isForwardEnabled
                      ? callTheme.forwardedCallBorderColor
                      : textColor.withValues(alpha: 0.5),
                  width: 1,
                ),
              ),
              child: Row(
                children: [
                  Icon(
                    Icons.phone_android,
                    size: 12,
                    color: textColor,
                  ),
                  const SizedBox(width: 4),
                  Expanded(
                    child: isForwardEnabled && destinationNumber.isNotEmpty
                        ? Text(
                            '${call.extensionUsed} → $destinationNumber',
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                              color: textColor,
                              letterSpacing: -0.3,
                            ),
                            overflow: TextOverflow.ellipsis,
                            maxLines: 1,
                          )
                        : Text(
                            call.extensionUsed ?? '',
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                              color: textColor,
                              letterSpacing: -0.3,
                            ),
                            overflow: TextOverflow.ellipsis,
                            maxLines: 1,
                          ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// 통화 타입에 따른 아이콘 반환
IconData getCallTypeIcon(CallType type) {
  switch (type) {
    case CallType.incoming:
      return Icons.call_received;
    case CallType.outgoing:
      return Icons.call_made;
    case CallType.missed:
      return Icons.call_missed;
  }
}

/// 통화 타입에 따른 색상 반환
Color getCallTypeColor(CallType type, BuildContext context) {
  final colors = CallThemeColors(context);
  switch (type) {
    case CallType.incoming:
      return colors.incomingCallColor;
    case CallType.outgoing:
      return colors.outgoingCallColor;
    case CallType.missed:
      return colors.missedCallColor;
  }
}

/// 날짜/시간을 yyyy.MM.dd HH:mm:ss 형식으로 포맷
String formatDateTime(DateTime dateTime) {
  return '${dateTime.year}.${dateTime.month.toString().padLeft(2, '0')}.${dateTime.day.toString().padLeft(2, '0')} '
         '${dateTime.hour.toString().padLeft(2, '0')}:${dateTime.minute.toString().padLeft(2, '0')}:${dateTime.second.toString().padLeft(2, '0')}';
}
