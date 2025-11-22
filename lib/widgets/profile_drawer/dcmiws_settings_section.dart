import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:provider/provider.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../services/auth_service.dart';
import '../../services/database_service.dart';
import '../../services/dcmiws_connection_manager.dart';
import '../../utils/dialog_utils.dart';

/// 📡 DCMIWS 착신전화 수신 설정 섹션
/// 
/// 기능:
/// - DCMIWS 실시간 수신 On/Off 토글
/// - 웹소켓 vs FCM 방식 안내
/// - ConnectionManager와 자동 연동
/// 
/// 독립적인 StatefulWidget으로 구현:
/// - 자체 상태 관리 (_dcmiwsEnabled)
/// - initState에서 Firestore 설정 로드
/// - 부모 위젯과의 결합도 최소화
class DcmiwsSettingsSection extends StatefulWidget {
  const DcmiwsSettingsSection({super.key});

  @override
  State<DcmiwsSettingsSection> createState() => _DcmiwsSettingsSectionState();
}

class _DcmiwsSettingsSectionState extends State<DcmiwsSettingsSection> {
  bool _dcmiwsEnabled = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadDcmiwsSettings();
    });
  }

  /// DCMIWS 착신전화 수신 설정 불러오기
  Future<void> _loadDcmiwsSettings() async {
    try {
      if (kDebugMode) {
        debugPrint('📥 [DCMIWS설정] 로드 시작');
      }
      
      final authService = context.read<AuthService>();
      final userId = authService.currentUser?.uid;
      
      if (userId == null) {
        if (kDebugMode) {
          debugPrint('❌ [DCMIWS설정] userId가 null입니다');
        }
        return;
      }
      
      // 🔄 CRITICAL: Firestore에서 직접 최신 값 읽기
      // AuthService의 currentUserModel이 업데이트 안 될 수 있으므로
      // Firestore에서 직접 읽어서 확실하게 최신 값 사용
      if (kDebugMode) {
        debugPrint('🔄 [DCMIWS설정] Firestore에서 직접 최신 값 읽기...');
      }
      
      final userDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(userId)
          .get();
      
      if (userDoc.exists && userDoc.data() != null) {
        final dcmiwsEnabled = userDoc.data()!['dcmiwsEnabled'] as bool? ?? false;
        
        if (mounted) {
          setState(() {
            _dcmiwsEnabled = dcmiwsEnabled;
          });
          
          if (kDebugMode) {
            debugPrint('✅ [DCMIWS설정] Firestore에서 로드 완료: dcmiwsEnabled=$_dcmiwsEnabled');
          }
        }
      } else {
        if (kDebugMode) {
          debugPrint('❌ [DCMIWS설정] Firestore 문서가 없습니다');
        }
      }
    } catch (e) {
      if (kDebugMode) {
        debugPrint('❌ [DCMIWS설정] 로드 오류: $e');
      }
    }
  }

  /// DCMIWS 착신전화 수신 설정 업데이트
  Future<void> _updateDcmiwsEnabled(bool value) async {
    try {
      if (kDebugMode) {
        debugPrint('🔧 [DCMIWS설정] 업데이트 시작: $_dcmiwsEnabled -> $value');
      }
      
      final authService = context.read<AuthService>();
      final userId = authService.currentUser?.uid;
      
      if (userId == null) {
        throw Exception('사용자 인증 정보가 없습니다');
      }
      
      final databaseService = DatabaseService();
      await databaseService.updateUserField(userId, 'dcmiwsEnabled', value);
      
      // 🔍 DEBUG: Firestore 업데이트 확인
      if (kDebugMode) {
        debugPrint('✅ [DCMIWS설정] Firestore 업데이트 완료: dcmiwsEnabled=$value');
        // 실제 Firestore 값 재확인
        final userDoc = await FirebaseFirestore.instance
            .collection('users')
            .doc(userId)
            .get();
        final actualValue = userDoc.data()?['dcmiwsEnabled'];
        debugPrint('🔍 [DCMIWS설정] Firestore 실제 값 확인: $actualValue (타입: ${actualValue.runtimeType})');
      }
      
      if (mounted) {
        setState(() {
          _dcmiwsEnabled = value;
        });
        
        if (kDebugMode) {
          debugPrint('✅ [DCMIWS설정] UI 상태 업데이트 완료: dcmiwsEnabled=$value');
        }
        
        // DCMIWS 웹소켓 연결 상태 관리
        // ConnectionManager를 통해 설정 변경 반영
        final connectionManager = DCMIWSConnectionManager();
        
        if (value) {
          // DCMIWS 활성화 시: ConnectionManager가 자동으로 연결 시도
          await connectionManager.refreshSettings();
          
          if (kDebugMode) {
            debugPrint('✅ [DCMIWS설정] ConnectionManager 설정 갱신 완료');
          }
          
          if (mounted) {
            await DialogUtils.showSuccess(
              context,
              'DCMIWS 착신전화 수신이 활성화되었습니다\n\n웹소켓 연결이 시작됩니다',
              duration: const Duration(seconds: 1),
            );
          }
        } else {
          // DCMIWS 비활성화 시: ConnectionManager가 자동으로 연결 해제
          await connectionManager.refreshSettings();
          
          if (kDebugMode) {
            debugPrint('✅ [DCMIWS설정] ConnectionManager 연결 해제 완료');
          }
          
          if (mounted) {
            await DialogUtils.showSuccess(
              context,
              'DCMIWS 착신전화 수신이 비활성화되었습니다\n\nPUSH(FCM) 방식으로 착신전화를 수신합니다',
              duration: const Duration(seconds: 1),
            );
          }
        }
      }
    } catch (e) {
      if (kDebugMode) {
        debugPrint('❌ [DCMIWS설정] 업데이트 오류: $e');
      }
      
      if (mounted) {
        await DialogUtils.showError(
          context,
          'DCMIWS 설정 업데이트 실패: $e',
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    
    return Column(
      children: [
        // DCMIWS 착신전화 수신 설정
        _buildSwitchTile(
          isDark: isDark,
          icon: Icons.wifi_tethering,
          title: 'DCMIWS 실시간 수신',
          subtitle: _dcmiwsEnabled 
              ? '웹소켓으로 실시간 착신전화 수신 중' 
              : 'PUSH(FCM)로 착신전화 수신 (기본)',
          value: _dcmiwsEnabled,
          onChanged: (value) => _updateDcmiwsEnabled(value),
        ),
        
        // DCMIWS 설명
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
          child: Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: isDark ? Colors.grey[850] : Colors.grey[100],
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: isDark ? Colors.grey[700]! : Colors.grey[300]!),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(
                      Icons.info_outline, 
                      size: 16, 
                      color: isDark ? Colors.grey[400] : Colors.grey[600],
                    ),
                    const SizedBox(width: 6),
                    Text(
                      '착신전화 수신 방식 안내',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: isDark ? Colors.grey[300] : Colors.grey[800],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  '• PUSH(기본): FCM을 통해 착신전화 알림 수신\n'
                  '  배터리 효율적, 안정적인 방식\n\n'
                  '• DCMIWS: 웹소켓으로 실시간 수신\n'
                  '  더 빠른 응답, 배터리 사용량 증가',
                  style: TextStyle(
                    fontSize: 11,
                    color: isDark ? Colors.grey[400] : Colors.grey[700],
                    height: 1.4,
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  /// 스위치 타일 빌더 (가독성 향상)
  Widget _buildSwitchTile({
    required bool isDark,
    required IconData icon,
    required String title,
    required String subtitle,
    required bool value,
    required ValueChanged<bool> onChanged,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      child: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: isDark
                ? [Colors.grey[850]!.withValues(alpha: 0.5), Colors.grey[900]!.withValues(alpha: 0.5)]
                : [Colors.white, Colors.grey[50]!],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isDark ? Colors.grey[700]! : Colors.grey[300]!,
            width: 1,
          ),
        ),
        child: SwitchListTile(
          secondary: Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: isDark ? Colors.blue[900]!.withValues(alpha: 0.5) : Colors.blue[50],
              shape: BoxShape.circle,
            ),
            child: Icon(
              icon,
              size: 20,
              color: isDark ? Colors.blue[300] : const Color(0xFF2196F3),
            ),
          ),
          title: Text(
            title,
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: isDark ? Colors.grey[200] : Colors.black87,
            ),
          ),
          subtitle: Text(
            subtitle,
            style: TextStyle(
              fontSize: 12,
              color: isDark ? Colors.grey[400] : Colors.black54,
            ),
          ),
          value: value,
          onChanged: onChanged,
          activeColor: const Color(0xFF2196F3),
        ),
      ),
    );
  }
}
