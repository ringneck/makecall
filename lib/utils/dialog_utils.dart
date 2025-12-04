import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'dart:io' show Platform;
import 'package:flutter/foundation.dart' show kIsWeb;

/// 다이얼로그 타입
enum DialogType {
  success,  // 성공 메시지
  error,    // 오류 메시지
  warning,  // 경고 메시지
  info,     // 정보 메시지
  confirm,  // 확인 필요
}

/// 플랫폼별 최적화된 다이얼로그 유틸리티
/// 
/// SnackBar 대신 모바일 기기에서도 명확하게 보이는 다이얼로그 제공
/// - Android: Material Design AlertDialog
/// - iOS: Cupertino AlertDialog
/// - Web: Material Design AlertDialog
class DialogUtils {

  /// 플랫폼 확인
  static bool get isIOS => !kIsWeb && Platform.isIOS;
  static bool get isAndroid => !kIsWeb && Platform.isAndroid;

  /// 메시지 다이얼로그 표시 (SnackBar 대체)
  /// 
  /// [context] - BuildContext
  /// [message] - 표시할 메시지
  /// [type] - 다이얼로그 타입 (기본값: info)
  /// [title] - 다이얼로그 제목 (선택사항)
  /// [duration] - 자동 닫힘 시간 (선택사항, null이면 버튼으로만 닫기)
  /// [barrierDismissible] - 바깥 터치로 닫기 가능 여부 (기본값: true)
  static Future<void> showMessage(
    BuildContext context,
    String message, {
    DialogType type = DialogType.info,
    String? title,
    Duration? duration,
    bool barrierDismissible = true,
  }) async {
    if (!context.mounted) return;

    // 타이틀이 없으면 타입에 따라 기본 타이틀 설정
    final String dialogTitle = title ?? _getDefaultTitle(type);

    // iOS 스타일 다이얼로그
    if (isIOS) {
      await showCupertinoDialog(
        context: context,
        barrierDismissible: barrierDismissible,
        builder: (BuildContext dialogContext) {
          // 자동 닫힘 설정
          if (duration != null) {
            Future.delayed(duration, () {
              if (dialogContext.mounted && Navigator.of(dialogContext).canPop()) {
                Navigator.of(dialogContext).pop();
              }
            });
          }

          return CupertinoAlertDialog(
            title: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                _getIcon(type, isIOS: true),
                const SizedBox(width: 8),
                Text(dialogTitle),
              ],
            ),
            content: Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Text(
                message,
                style: const TextStyle(fontSize: 14),
              ),
            ),
            actions: [
              CupertinoDialogAction(
                onPressed: () {
                  Navigator.of(dialogContext).pop();
                },
                child: const Text('확인'),
              ),
            ],
          );
        },
      );
    } 
    // Android & Web 스타일 다이얼로그
    else {
      await showDialog(
        context: context,
        barrierDismissible: barrierDismissible,
        builder: (BuildContext dialogContext) {
          // 자동 닫힘 설정
          if (duration != null) {
            Future.delayed(duration, () {
              if (dialogContext.mounted && Navigator.of(dialogContext).canPop()) {
                Navigator.of(dialogContext).pop();
              }
            });
          }

          return AlertDialog(
            title: Row(
              children: [
                _getIcon(type, isIOS: false),
                const SizedBox(width: 12),
                Text(dialogTitle),
              ],
            ),
            content: Text(
              message,
              style: const TextStyle(fontSize: 14),
            ),
            actions: [
              TextButton(
                onPressed: () {
                  Navigator.of(dialogContext).pop();
                },
                child: const Text('확인'),
              ),
            ],
          );
        },
      );
    }
  }

  /// 액션이 있는 다이얼로그 표시 (SnackBar with action 대체)
  /// 
  /// [context] - BuildContext
  /// [message] - 표시할 메시지
  /// [actionLabel] - 액션 버튼 레이블
  /// [onAction] - 액션 버튼 클릭 콜백
  /// [type] - 다이얼로그 타입 (기본값: info)
  /// [title] - 다이얼로그 제목 (선택사항)
  static Future<bool?> showMessageWithAction(
    BuildContext context,
    String message, {
    required String actionLabel,
    required VoidCallback onAction,
    DialogType type = DialogType.info,
    String? title,
  }) async {
    if (!context.mounted) return null;

    final String dialogTitle = title ?? _getDefaultTitle(type);

    // iOS 스타일 다이얼로그
    if (isIOS) {
      return await showCupertinoDialog<bool>(
        context: context,
        barrierDismissible: true,
        builder: (BuildContext dialogContext) {
          return CupertinoAlertDialog(
            title: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                _getIcon(type, isIOS: true),
                const SizedBox(width: 8),
                Text(dialogTitle),
              ],
            ),
            content: Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Text(
                message,
                style: const TextStyle(fontSize: 14),
              ),
            ),
            actions: [
              CupertinoDialogAction(
                onPressed: () {
                  Navigator.of(dialogContext).pop(false);
                },
                child: const Text('닫기'),
              ),
              CupertinoDialogAction(
                isDefaultAction: true,
                onPressed: () {
                  Navigator.of(dialogContext).pop(true);
                  onAction();
                },
                child: Text(actionLabel),
              ),
            ],
          );
        },
      );
    } 
    // Android & Web 스타일 다이얼로그
    else {
      return await showDialog<bool>(
        context: context,
        barrierDismissible: true,
        builder: (BuildContext dialogContext) {
          return AlertDialog(
            title: Row(
              children: [
                _getIcon(type, isIOS: false),
                const SizedBox(width: 12),
                Text(dialogTitle),
              ],
            ),
            content: Text(
              message,
              style: const TextStyle(fontSize: 14),
            ),
            actions: [
              TextButton(
                onPressed: () {
                  Navigator.of(dialogContext).pop(false);
                },
                child: const Text('닫기'),
              ),
              TextButton(
                onPressed: () {
                  Navigator.of(dialogContext).pop(true);
                  onAction();
                },
                child: Text(actionLabel),
              ),
            ],
          );
        },
      );
    }
  }

  /// 확인 다이얼로그 표시
  /// 
  /// [context] - BuildContext
  /// [message] - 표시할 메시지
  /// [title] - 다이얼로그 제목 (선택사항)
  /// [confirmLabel] - 확인 버튼 레이블 (기본값: "확인")
  /// [cancelLabel] - 취소 버튼 레이블 (기본값: "취소")
  /// 
  /// 반환값: 확인 버튼 클릭 시 true, 취소 버튼 클릭 시 false
  static Future<bool> showConfirm(
    BuildContext context,
    String message, {
    String? title,
    String confirmLabel = '확인',
    String cancelLabel = '취소',
  }) async {
    if (!context.mounted) return false;

    final String dialogTitle = title ?? '확인';

    // iOS 스타일 다이얼로그
    if (isIOS) {
      final result = await showCupertinoDialog<bool>(
        context: context,
        barrierDismissible: true,
        builder: (BuildContext dialogContext) {
          return CupertinoAlertDialog(
            title: Text(dialogTitle),
            content: Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Text(
                message,
                style: const TextStyle(fontSize: 14),
              ),
            ),
            actions: [
              CupertinoDialogAction(
                onPressed: () {
                  Navigator.of(dialogContext).pop(false);
                },
                child: Text(cancelLabel),
              ),
              CupertinoDialogAction(
                isDefaultAction: true,
                onPressed: () {
                  Navigator.of(dialogContext).pop(true);
                },
                child: Text(confirmLabel),
              ),
            ],
          );
        },
      );
      return result ?? false;
    } 
    // Android & Web 스타일 다이얼로그
    else {
      final result = await showDialog<bool>(
        context: context,
        barrierDismissible: true,
        builder: (BuildContext dialogContext) {
          return AlertDialog(
            title: Text(dialogTitle),
            content: Text(
              message,
              style: const TextStyle(fontSize: 14),
            ),
            actions: [
              TextButton(
                onPressed: () {
                  Navigator.of(dialogContext).pop(false);
                },
                child: Text(cancelLabel),
              ),
              TextButton(
                onPressed: () {
                  Navigator.of(dialogContext).pop(true);
                },
                child: Text(confirmLabel),
              ),
            ],
          );
        },
      );
      return result ?? false;
    }
  }

  /// 타입에 따른 기본 타이틀 반환
  static String _getDefaultTitle(DialogType type) {
    switch (type) {
      case DialogType.success:
        return '성공';
      case DialogType.error:
        return '안내';
      case DialogType.warning:
        return '경고';
      case DialogType.info:
        return '알림';
      case DialogType.confirm:
        return '확인';
    }
  }

  /// 타입에 따른 아이콘 반환
  static Widget _getIcon(DialogType type, {required bool isIOS}) {
    IconData iconData;
    Color iconColor;

    switch (type) {
      case DialogType.success:
        iconData = isIOS ? CupertinoIcons.check_mark_circled_solid : Icons.check_circle;
        iconColor = Colors.green;
        break;
      case DialogType.error:
        iconData = isIOS ? CupertinoIcons.xmark_circle_fill : Icons.error;
        iconColor = Colors.red;
        break;
      case DialogType.warning:
        iconData = isIOS ? CupertinoIcons.exclamationmark_triangle_fill : Icons.warning_amber_rounded;
        iconColor = Colors.orange;
        break;
      case DialogType.info:
        iconData = isIOS ? CupertinoIcons.info_circle_fill : Icons.info_outline;
        iconColor = Colors.blue;
        break;
      case DialogType.confirm:
        iconData = isIOS ? CupertinoIcons.question_circle_fill : Icons.help_outline;
        iconColor = Colors.blue;
        break;
    }

    return Icon(iconData, color: iconColor, size: isIOS ? 24 : 28);
  }

  /// 간편 메서드: 성공 메시지
  static Future<void> showSuccess(
    BuildContext context,
    String message, {
    String? title,
    Duration? duration, // 기본값 제거 - 사용자가 확인 버튼을 눌러야 닫힘
  }) {
    return showMessage(
      context,
      message,
      type: DialogType.success,
      title: title,
      duration: duration,
    );
  }

  /// 간편 메서드: 오류 메시지
  static Future<void> showError(
    BuildContext context,
    String message, {
    String? title,
    Duration? duration,
  }) {
    return showMessage(
      context,
      message,
      type: DialogType.error,
      title: title,
      duration: duration,
    );
  }

  /// 간편 메서드: 경고 메시지
  static Future<void> showWarning(
    BuildContext context,
    String message, {
    String? title,
    Duration? duration,
  }) {
    return showMessage(
      context,
      message,
      type: DialogType.warning,
      title: title,
      duration: duration,
    );
  }

  /// 간편 메서드: 정보 메시지
  static Future<void> showInfo(
    BuildContext context,
    String message, {
    String? title,
    Duration? duration,
  }) {
    return showMessage(
      context,
      message,
      type: DialogType.info,
      title: title,
      duration: duration,
    );
  }

  /// 간편 메서드: 클립보드 복사 완료 메시지
  /// 
  /// [context] - BuildContext
  /// [label] - 복사된 항목 이름 (예: 'SIP Secret', '수신번호')
  /// [value] - 복사된 값
  /// [duration] - 자동 닫힘 시간 (기본값: 2초)
  static Future<void> showCopySuccess(
    BuildContext context,
    String label,
    String value, {
    Duration duration = const Duration(seconds: 1),
  }) {
    return showSuccess(
      context,
      '$label 값이 클립보드에 복사되었습니다\n\n📋 $value',
      title: '복사 완료',
      duration: duration,
    );
  }

  /// 간편 메서드: 이메일 인증 필요 다이얼로그 (다크모드 최적화)
  /// 
  /// [context] - BuildContext
  static Future<void> showEmailVerificationRequired(BuildContext context) async {
    if (!context.mounted) return;

    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return showDialog(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: isDark ? const Color(0xFF1E1E1E) : Colors.white,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
        ),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.orange.withValues(alpha: isDark ? 0.2 : 0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(
                Icons.warning_amber_rounded,
                color: isDark ? Colors.orange[300] : Colors.orange,
                size: 24,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                '이메일 인증 필요',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: isDark ? Colors.white : Colors.black87,
                ),
              ),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 메인 메시지
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: isDark
                      ? [
                          Colors.orange[900]!.withValues(alpha: 0.2),
                          Colors.deepOrange[900]!.withValues(alpha: 0.2),
                        ]
                      : [
                          Colors.orange[50]!,
                          Colors.deepOrange[50]!,
                        ],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: isDark 
                      ? Colors.orange[700]!.withValues(alpha: 0.3)
                      : Colors.orange[200]!,
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(
                        Icons.email_outlined,
                        size: 20,
                        color: isDark ? Colors.orange[300] : Colors.orange[700],
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          '이메일 인증이 완료되지 않았습니다',
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w600,
                            color: isDark ? Colors.orange[200] : Colors.orange[900],
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Text(
                    '회원가입 시 발송된 인증 메일의 링크를 클릭하여 이메일 인증을 완료해주세요.',
                    style: TextStyle(
                      fontSize: 14,
                      height: 1.5,
                      color: isDark ? Colors.grey[300] : Colors.grey[700],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),
            
            // 인증 방법 안내
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: isDark ? Colors.grey[850] : Colors.grey[50],
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: isDark ? Colors.grey[700]! : Colors.grey[200]!,
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(
                        Icons.checklist_rounded,
                        size: 18,
                        color: isDark ? Colors.blue[300] : const Color(0xFF2196F3),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        '인증 방법',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                          color: isDark ? Colors.blue[300] : const Color(0xFF2196F3),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  _buildSimpleStep('1. 이메일 앱 실행', isDark),
                  const SizedBox(height: 6),
                  _buildSimpleStep('2. 인증 메일 찾기 (스팸함 확인)', isDark),
                  const SizedBox(height: 6),
                  _buildSimpleStep('3. 인증 링크 클릭', isDark),
                  const SizedBox(height: 6),
                  _buildSimpleStep('4. 앱으로 돌아와 재로그인', isDark),
                ],
              ),
            ),
            const SizedBox(height: 16),
            
            // 추가 안내
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: isDark 
                    ? Colors.blue[900]!.withValues(alpha: 0.2)
                    : Colors.blue[50],
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: isDark 
                      ? Colors.blue[700]!.withValues(alpha: 0.3)
                      : Colors.blue[200]!,
                ),
              ),
              child: Row(
                children: [
                  Icon(
                    Icons.lightbulb_outline,
                    size: 18,
                    color: isDark ? Colors.blue[300] : Colors.blue[700],
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      '메일이 보이지 않으면 스팸함을 꼭 확인하세요',
                      style: TextStyle(
                        fontSize: 12,
                        color: isDark ? Colors.blue[200] : Colors.blue[800],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            style: TextButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              backgroundColor: const Color(0xFF2196F3).withValues(alpha: isDark ? 0.2 : 0.1),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
            child: Text(
              '확인',
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w600,
                color: isDark ? Colors.blue[300] : const Color(0xFF2196F3),
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// 간단한 단계 위젯 (내부 헬퍼 메서드)
  static Widget _buildSimpleStep(String text, bool isDark) {
    return Row(
      children: [
        Icon(
          Icons.arrow_forward_ios,
          size: 12,
          color: isDark ? Colors.grey[400] : Colors.grey[600],
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            text,
            style: TextStyle(
              fontSize: 13,
              color: isDark ? Colors.grey[300] : Colors.grey[700],
            ),
          ),
        ),
      ],
    );
  }
}
