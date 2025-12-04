import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'dart:io' show Platform;
import 'package:provider/provider.dart';
import 'package:permission_handler/permission_handler.dart';
import '../../services/auth_service.dart';
import '../../services/fcm_service.dart';
import '../../utils/dialog_utils.dart';

/// 📱 알림 설정 섹션 위젯
/// 
/// FCM 푸시 알림 설정을 관리하는 섹션입니다.
/// - 푸시 알림 ON/OFF
/// - 알림음 설정
/// - 진동 설정
/// - 플랫폼별 설정 UI (Web, iOS, Android)
class NotificationSettingsSection extends StatefulWidget {
  const NotificationSettingsSection({super.key});

  @override
  State<NotificationSettingsSection> createState() => _NotificationSettingsSectionState();
}

class _NotificationSettingsSectionState extends State<NotificationSettingsSection> {
  // FCM 알림 설정
  bool _pushEnabled = true;
  bool _soundEnabled = true;
  bool _vibrationEnabled = true;
  
  @override
  void initState() {
    super.initState();
    // 알림 설정 불러오기
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadNotificationSettings();
    });
  }

  // FCM 알림 설정 불러오기
  Future<void> _loadNotificationSettings() async {
    try {
      debugPrint('📥 [iOS-알림설정] 로드 시작');
      
      final authService = context.read<AuthService>();
      final userId = authService.currentUser?.uid;
      
      if (userId == null) {
        debugPrint('❌ [iOS-알림설정] userId가 null입니다');
        return;
      }
      
      debugPrint('✓ [iOS-알림설정] userId: $userId');
      
      final fcmService = FCMService();
      final settings = await fcmService.getUserNotificationSettings(userId);
      
      debugPrint('📦 [iOS-알림설정] Firestore에서 가져온 설정: $settings');
      
      if (settings != null && mounted) {
        setState(() {
          _pushEnabled = settings['pushEnabled'] ?? true;
          _soundEnabled = settings['soundEnabled'] ?? true;
          _vibrationEnabled = settings['vibrationEnabled'] ?? true;
        });
        
        debugPrint('✅ [iOS-알림설정] 로드 완료 및 UI 업데이트:');
        debugPrint('   - 푸시 알림: $_pushEnabled');
        debugPrint('   - 알림음: $_soundEnabled');
        debugPrint('   - 진동: $_vibrationEnabled');
      } else {
        debugPrint('⚠️ [iOS-알림설정] settings가 null이거나 widget이 unmounted됨');
      }
    } catch (e, stackTrace) {
      debugPrint('❌ [iOS-알림설정] 로드 오류: $e');
      debugPrint('   스택 트레이스: $stackTrace');
    }
  }

  // FCM 알림 설정 업데이트
  Future<void> _updateNotificationSetting(String key, bool value) async {
    try {
      debugPrint('🔧 [iOS-알림설정] 업데이트 시작: $key = $value');
      
      final authService = context.read<AuthService>();
      final userId = authService.currentUser?.uid;
      
      if (userId == null) {
        debugPrint('❌ [iOS-알림설정] userId가 null입니다');
        return;
      }
      
      debugPrint('✓ [iOS-알림설정] userId: $userId');
      
      final fcmService = FCMService();
      await fcmService.updateSingleSetting(userId, key, value);
      
      debugPrint('✅ [iOS-알림설정] Firestore 업데이트 성공: $key = $value');
      
      if (mounted) {
        await DialogUtils.showSuccess(
          context,
          '설정이 저장되었습니다',
          duration: const Duration(seconds: 1),
        );
      }
    } catch (e, stackTrace) {
      debugPrint('❌ [iOS-알림설정] 업데이트 오류: $e');
      debugPrint('   스택 트레이스: $stackTrace');
      
      if (mounted) {
        await DialogUtils.showError(
          context,
          '설정 저장 실패: $e',
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: isDark 
                ? [Colors.blue[900]!.withValues(alpha: 0.3), Colors.blue[800]!.withValues(alpha: 0.3)]
                : [Colors.blue[50]!, Colors.blue[100]!],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isDark ? Colors.blue[700]! : Colors.blue[200]!, 
            width: 1.5,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.blue.withValues(alpha: isDark ? 0.2 : 0.1),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: ListTile(
          leading: Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: isDark ? Colors.blue[900]!.withValues(alpha: 0.5) : Colors.white,
              shape: BoxShape.circle,
            ),
            child: Icon(
              Icons.notifications_active, 
              color: isDark ? Colors.blue[300] : const Color(0xFF2196F3), 
              size: 24,
            ),
          ),
          title: Text(
            '앱 알림 설정',
            style: TextStyle(
              fontWeight: FontWeight.w700,
              fontSize: 16,
              color: isDark ? Colors.blue[300] : const Color(0xFF1976D2),
            ),
          ),
          subtitle: Text(
            _pushEnabled 
              ? '푸시 알림 활성화 • ${_soundEnabled ? "소리 켜짐" : "소리 꺼짐"}' 
              : '푸시 알림 비활성화',
            style: TextStyle(
              fontSize: 12,
              color: isDark ? Colors.blue[200] : Colors.blue[900],
              fontWeight: FontWeight.w500,
            ),
          ),
          trailing: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                _pushEnabled ? Icons.check_circle : Icons.cancel,
                color: _pushEnabled 
                    ? (isDark ? Colors.green[300] : Colors.green) 
                    : (isDark ? Colors.grey[600] : Colors.grey),
                size: 22,
              ),
              const SizedBox(width: 4),
              Icon(
                Icons.chevron_right, 
                color: isDark ? Colors.blue[300] : const Color(0xFF1976D2),
              ),
            ],
          ),
          onTap: () => _showNotificationSettingsDialog(context),
        ),
      ),
    );
  }

  /// 📱 통합 알림 설정 다이얼로그 (UI/UX 최적화)
  void _showNotificationSettingsDialog(BuildContext context) {
    final authService = context.read<AuthService>();
    final userId = authService.currentUser?.uid;
    final fcmService = FCMService();
    final isDark = Theme.of(context).brightness == Brightness.dark;
    
    if (userId == null) {
      DialogUtils.showError(context, '사용자 정보를 찾을 수 없습니다.');
      return;
    }

    showDialog(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setDialogState) {
          return AlertDialog(
            backgroundColor: isDark ? Colors.grey[900] : Colors.white,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(20),
            ),
            title: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: isDark 
                        ? Colors.blue[900]!.withValues(alpha: 0.5)
                        : Colors.blue[50],
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    Icons.notifications_active,
                    color: isDark ? Colors.blue[300] : const Color(0xFF2196F3),
                    size: 28,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    '앱 알림 설정',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w700,
                      color: isDark ? Colors.grey[200] : Colors.black87,
                    ),
                  ),
                ),
              ],
            ),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // 📱 플랫폼 정보 배너
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: isDark
                          ? (kIsWeb 
                              ? [Colors.orange[900]!.withValues(alpha: 0.3), Colors.orange[800]!.withValues(alpha: 0.3)]
                              : [Colors.blue[900]!.withValues(alpha: 0.3), Colors.blue[800]!.withValues(alpha: 0.3)])
                          : (kIsWeb 
                              ? [Colors.orange[50]!, Colors.orange[100]!]
                              : [Colors.blue[50]!, Colors.blue[100]!]),
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: isDark
                          ? (kIsWeb ? Colors.orange[700]! : Colors.blue[700]!)
                          : (kIsWeb ? Colors.orange[200]! : Colors.blue[200]!),
                      ),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          kIsWeb 
                            ? Icons.web 
                            : (Platform.isIOS ? Icons.apple : Icons.android),
                          color: isDark
                            ? (kIsWeb ? Colors.orange[300] : Colors.blue[300])
                            : (kIsWeb ? Colors.orange[700] : Colors.blue[700]),
                          size: 24,
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                kIsWeb 
                                  ? '웹 브라우저'
                                  : (Platform.isIOS ? 'iOS 기기' : 'Android 기기'),
                                style: TextStyle(
                                  fontWeight: FontWeight.w700,
                                  fontSize: 14,
                                  color: isDark
                                    ? (kIsWeb ? Colors.orange[200] : Colors.blue[200])
                                    : (kIsWeb ? Colors.orange[900] : Colors.blue[900]),
                                ),
                              ),
                              Text(
                                kIsWeb 
                                  ? '브라우저 푸시 알림'
                                  : (Platform.isIOS ? 'APNs 푸시 알림' : 'FCM 푸시 알림'),
                                style: TextStyle(
                                  fontSize: 11,
                                  color: isDark
                                    ? (kIsWeb ? Colors.orange[400] : Colors.blue[400])
                                    : (kIsWeb ? Colors.orange[700] : Colors.blue[700]),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  
                  const SizedBox(height: 20),
                  
                  // 🔔 푸시 알림 ON/OFF
                  Container(
                    decoration: BoxDecoration(
                      color: _pushEnabled 
                          ? (isDark ? Colors.green[900]!.withValues(alpha: 0.3) : Colors.green[50])
                          : (isDark ? Colors.grey[850] : Colors.grey[100]),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: _pushEnabled 
                            ? (isDark ? Colors.green[700]! : Colors.green[200]!)
                            : (isDark ? Colors.grey[700]! : Colors.grey[300]!),
                        width: 2,
                      ),
                    ),
                    child: SwitchListTile(
                      value: _pushEnabled,
                      onChanged: (value) async {
                        setDialogState(() {
                          _pushEnabled = value;
                        });
                        setState(() {
                          _pushEnabled = value;
                        });
                        
                        try {
                          await fcmService.updateSingleSetting(userId, 'pushEnabled', value);
                          if (kDebugMode) {
                            debugPrint('✅ [알림설정] pushEnabled 업데이트: $value');
                          }
                        } catch (e) {
                          if (kDebugMode) {
                            debugPrint('❌ [알림설정] 업데이트 실패: $e');
                          }
                        }
                      },
                      title: Row(
                        children: [
                          Icon(
                            _pushEnabled ? Icons.notifications_active : Icons.notifications_off,
                            color: _pushEnabled 
                                ? (isDark ? Colors.green[300] : Colors.green[700])
                                : (isDark ? Colors.grey[500] : Colors.grey[600]),
                            size: 24,
                          ),
                          const SizedBox(width: 12),
                          Text(
                            '푸시 알림',
                            style: TextStyle(
                              fontWeight: FontWeight.w700,
                              fontSize: 16,
                              color: isDark ? Colors.grey[200] : Colors.black87,
                            ),
                          ),
                        ],
                      ),
                      subtitle: Padding(
                        padding: const EdgeInsets.only(left: 36, top: 4),
                        child: Text(
                          _pushEnabled 
                            ? '모든 푸시 알림을 받습니다'
                            : '푸시 알림을 받지 않습니다',
                          style: TextStyle(
                            fontSize: 12,
                            color: _pushEnabled 
                                ? (isDark ? Colors.green[400] : Colors.green[900])
                                : (isDark ? Colors.grey[500] : Colors.grey[600]),
                          ),
                        ),
                      ),
                      activeColor: isDark ? Colors.green[400] : Colors.green[600],
                    ),
                  ),
                  
                  const SizedBox(height: 16),
                  
                  // 🔊 알림음 & 진동 (푸시 알림이 켜져 있을 때만 활성화)
                  Opacity(
                    opacity: _pushEnabled ? 1.0 : 0.5,
                    child: AbsorbPointer(
                      absorbing: !_pushEnabled,
                      child: Container(
                        decoration: BoxDecoration(
                          color: isDark 
                              ? Colors.blue[900]!.withValues(alpha: 0.3)
                              : Colors.blue[50],
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: isDark ? Colors.blue[700]! : Colors.blue[200]!,
                          ),
                        ),
                        child: Column(
                          children: [
                            SwitchListTile(
                              value: _soundEnabled,
                              onChanged: _pushEnabled ? (value) async {
                                setDialogState(() {
                                  _soundEnabled = value;
                                });
                                setState(() {
                                  _soundEnabled = value;
                                });
                                
                                try {
                                  await fcmService.updateSingleSetting(userId, 'soundEnabled', value);
                                  if (kDebugMode) {
                                    debugPrint('✅ [알림설정] soundEnabled 업데이트: $value');
                                  }
                                } catch (e) {
                                  if (kDebugMode) {
                                    debugPrint('❌ [알림설정] 업데이트 실패: $e');
                                  }
                                }
                              } : null,
                              title: Row(
                                children: [
                                  Icon(
                                    _soundEnabled ? Icons.volume_up : Icons.volume_off,
                                    color: isDark ? Colors.blue[300] : Colors.blue[700],
                                    size: 20,
                                  ),
                                  const SizedBox(width: 12),
                                  Text(
                                    '알림음',
                                    style: TextStyle(
                                      fontWeight: FontWeight.w600,
                                      fontSize: 15,
                                      color: isDark ? Colors.grey[200] : Colors.black87,
                                    ),
                                  ),
                                ],
                              ),
                              subtitle: Padding(
                                padding: const EdgeInsets.only(left: 32, top: 2),
                                child: Text(
                                  '알림 수신 시 소리 재생',
                                  style: TextStyle(
                                    fontSize: 11,
                                    color: isDark ? Colors.grey[400] : Colors.black54,
                                  ),
                                ),
                              ),
                              activeColor: isDark ? Colors.blue[400] : Colors.blue[600],
                            ),
                            Divider(
                              height: 1, 
                              indent: 16, 
                              endIndent: 16,
                              color: isDark ? Colors.grey[700] : Colors.grey[300],
                            ),
                            SwitchListTile(
                              value: _vibrationEnabled,
                              onChanged: _pushEnabled ? (value) async {
                                setDialogState(() {
                                  _vibrationEnabled = value;
                                });
                                setState(() {
                                  _vibrationEnabled = value;
                                });
                                
                                try {
                                  await fcmService.updateSingleSetting(userId, 'vibrationEnabled', value);
                                  if (kDebugMode) {
                                    debugPrint('✅ [알림설정] vibrationEnabled 업데이트: $value');
                                  }
                                } catch (e) {
                                  if (kDebugMode) {
                                    debugPrint('❌ [알림설정] 업데이트 실패: $e');
                                  }
                                }
                              } : null,
                              title: Row(
                                children: [
                                  Icon(
                                    _vibrationEnabled ? Icons.vibration : Icons.mobile_off,
                                    color: isDark ? Colors.blue[300] : Colors.blue[700],
                                    size: 20,
                                  ),
                                  const SizedBox(width: 12),
                                  Text(
                                    '진동',
                                    style: TextStyle(
                                      fontWeight: FontWeight.w600,
                                      fontSize: 15,
                                      color: isDark ? Colors.grey[200] : Colors.black87,
                                    ),
                                  ),
                                ],
                              ),
                              subtitle: Padding(
                                padding: const EdgeInsets.only(left: 32, top: 2),
                                child: Text(
                                  '알림 수신 시 진동',
                                  style: TextStyle(
                                    fontSize: 11,
                                    color: isDark ? Colors.grey[400] : Colors.black54,
                                  ),
                                ),
                              ),
                              activeColor: isDark ? Colors.blue[400] : Colors.blue[600],
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                  
                  const SizedBox(height: 20),
                  
                  // 💡 시스템 설정 안내 (웹이 아닐 때만)
                  if (!kIsWeb)
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: isDark 
                            ? Colors.amber[900]!.withValues(alpha: 0.3)
                            : Colors.amber[50],
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                          color: isDark ? Colors.amber[700]! : Colors.amber[200]!,
                        ),
                      ),
                      child: Row(
                        children: [
                          Icon(
                            Icons.info_outline, 
                            color: isDark ? Colors.amber[300] : Colors.amber[800], 
                            size: 20,
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              Platform.isIOS
                                ? '시스템 푸시 권한은\niOS 설정에서 관리됩니다'
                                : '시스템 푸시 권한은\nAndroid 설정에서 관리됩니다',
                              style: TextStyle(
                                fontSize: 11,
                                color: isDark ? Colors.amber[200] : Colors.amber[900],
                                height: 1.4,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                ],
              ),
            ),
            actions: [
              if (!kIsWeb)
                TextButton.icon(
                  onPressed: () async {
                    await openAppSettings();
                  },
                  icon: Icon(
                    Icons.settings, 
                    size: 18,
                    color: isDark ? Colors.blue[300] : Colors.blue[700],
                  ),
                  label: Text(
                    Platform.isIOS ? 'iOS 설정' : 'Android 설정',
                    style: TextStyle(
                      color: isDark ? Colors.blue[300] : Colors.blue[700],
                    ),
                  ),
                  style: TextButton.styleFrom(
                    foregroundColor: isDark ? Colors.blue[300] : Colors.blue[700],
                  ),
                ),
              const SizedBox(width: 8),
              ElevatedButton(
                onPressed: () {
                  Navigator.pop(context);
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: isDark 
                      ? Colors.blue[700]
                      : const Color(0xFF2196F3),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
                child: const Text(
                  '완료',
                  style: TextStyle(fontWeight: FontWeight.w600),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}
