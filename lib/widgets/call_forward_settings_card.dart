import 'package:flutter/material.dart';
import '../utils/dialog_utils.dart';
import 'package:flutter/foundation.dart';
import '../services/dcmiws_service.dart';
import '../services/database_service.dart';
import '../services/auth_service.dart';
import '../services/fcm/fcm_call_forward_service.dart';
import '../models/my_extension_model.dart';
import '../models/call_forward_info_model.dart';
import '../utils/phone_formatter.dart';
import 'package:provider/provider.dart';

/// 착신전환 설정 카드 (조회 + 변경 + DB 저장)
/// 
/// WebSocket을 통해 실시간으로 착신번호를 조회하고 설정을 변경합니다.
/// 변경 사항은 Firestore DB에 저장되어 마지막 업데이트 시간을 표시합니다.
class CallForwardSettingsCard extends StatefulWidget {
  final MyExtensionModel extension;
  final String? tenantId;
  final String? wsServerAddress;
  final int? wsServerPort;
  final bool? useSSL;
  final int? amiServerId;
  final String? httpAuthId;
  final String? httpAuthPassword;

  const CallForwardSettingsCard({
    super.key,
    required this.extension,
    this.tenantId,
    this.wsServerAddress,
    this.wsServerPort,
    this.useSSL,
    this.amiServerId,
    this.httpAuthId,
    this.httpAuthPassword,
  });

  @override
  State<CallForwardSettingsCard> createState() => _CallForwardSettingsCardState();
}

class _CallForwardSettingsCardState extends State<CallForwardSettingsCard> {
  final DCMIWSService _wsService = DCMIWSService();
  final DatabaseService _dbService = DatabaseService();
  final FCMCallForwardService _fcmCallForwardService = FCMCallForwardService();
  
  bool _isLoading = false;
  bool _isEnabled = false;
  String _destination = '00000000000'; // 기본값
  DateTime? _lastUpdated;
  String? _errorMessage;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _initializeAndFetch();
  }

  @override
  void dispose() {
    // WebSocket 연결 유지 (다른 화면에서도 사용 가능)
    super.dispose();
  }



  /// WebSocket 초기화 및 착신번호 조회
  Future<void> _initializeAndFetch() async {
    // 전체 설정 확인 (tenantId 포함)
    if (!_hasFullConfig()) {
      if (kDebugMode) {
        debugPrint('⚠️ CallForwardSettings: Invalid WebSocket configuration');
      }
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      // 먼저 DB에서 저장된 정보 불러오기
      await _loadFromDatabase();

      // WebSocket 연결 (이미 연결되어 있으면 재사용)
      if (!_wsService.isConnected) {
        final connected = await _wsService.connect(
          serverAddress: widget.wsServerAddress!,
          port: widget.wsServerPort!,
          useSSL: widget.useSSL ?? false,
          httpAuthId: widget.httpAuthId,
          httpAuthPassword: widget.httpAuthPassword,
        );

        if (!connected) {
          throw Exception('WebSocket connection failed');
        }
      }

      // 착신번호 조회 (WebSocket에서 최신 정보)
      await _fetchCallForwardInfo();
    } catch (e) {
      if (kDebugMode) {
        debugPrint('❌ CallForwardSettings: Error - $e');
      }
      setState(() {
        _errorMessage = 'WebSocket 연결 실패';
      });
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  /// DB에서 저장된 착신전환 정보 불러오기
  Future<void> _loadFromDatabase() async {
    try {
      final authService = context.read<AuthService>();
      final userId = authService.currentUser?.uid;
      
      if (userId == null) return;

      // DB에서 스트림으로 정보 가져오기
      final stream = _dbService.getCallForwardInfo(userId, widget.extension.extension);
      final info = await stream.first;

      if (info != null && mounted) {
        setState(() {
          _isEnabled = info.isEnabled;
          _destination = info.destinationNumber;
          _lastUpdated = info.lastUpdated;
        });

        if (kDebugMode) {
          debugPrint('');
          debugPrint('📂 ========== 착신전환 정보 DB 로드 ==========');
          debugPrint('   📱 단말번호: ${widget.extension.extension}');
          debugPrint('   🔄 착신전환 활성화: $_isEnabled');
          debugPrint('   ➡️  착신번호: $_destination');
          debugPrint('   📅 마지막 업데이트: $_lastUpdated');
          debugPrint('   ✅ DB 로드 완료');
          debugPrint('================================================');
          debugPrint('');
        }
      } else {
        if (kDebugMode) {
          debugPrint('');
          debugPrint('📂 ========== 착신전환 정보 DB 로드 ==========');
          debugPrint('   📱 단말번호: ${widget.extension.extension}');
          debugPrint('   ⚠️  저장된 정보 없음 - 기본값 사용');
          debugPrint('   🔄 착신전환: 비활성화 (기본값)');
          debugPrint('   ➡️  착신번호: 00000000000 (기본값)');
          debugPrint('================================================');
          debugPrint('');
        }
      }
    } catch (e) {
      if (kDebugMode) {
        debugPrint('❌ Failed to load from DB: $e');
      }
    }
  }

  /// 착신번호 정보 조회 (WebSocket)
  Future<void> _fetchCallForwardInfo() async {
    try {
      // 착신전환 활성화 상태 조회
      final enabled = await _wsService.getCallForwardEnabled(
        amiServerId: widget.amiServerId ?? 1,
        tenantId: widget.tenantId!,
        extensionId: widget.extension.extension,
        diversionType: 'CFI',
      );

      // 착신번호 조회
      String? destination = await _wsService.getCallForwardDestination(
        amiServerId: widget.amiServerId ?? 1,
        tenantId: widget.tenantId!,
        extensionId: widget.extension.extension,
        diversionType: 'CFI',
      );

      // 🔥 CRITICAL FIX: WebSocket 조회 결과가 없을 때 DB 값 유지
      // 조회된 착신번호가 없으면 현재 값 유지 (DB에서 로드한 값)
      if (destination == null || destination.isEmpty) {
        // 현재 값이 기본값이면 기본값 유지, 아니면 DB 값 유지
        if (_destination == '00000000000') {
          destination = '00000000000';
        } else {
          destination = _destination; // DB에서 로드한 값 유지
          if (kDebugMode) {
            debugPrint('⚠️ WebSocket 조회 실패 - DB 저장 값 유지: $_destination');
          }
        }
      }

      if (mounted) {
        setState(() {
          _isEnabled = enabled;
          _destination = destination!;
          _lastUpdated = DateTime.now();
          _errorMessage = null;
        });

        // DB에 저장 (WebSocket 조회 성공 시에만)
        if (destination != _destination || enabled != _isEnabled) {
          await _saveToDatabase();
          if (kDebugMode) {
            debugPrint('💾 WebSocket 조회 결과를 DB에 저장: enabled=$enabled, destination=$destination');
          }
        }
      }

      if (kDebugMode) {
        debugPrint('');
        debugPrint('📡 ========== WebSocket 착신전환 조회 완료 ==========');
        debugPrint('   📱 단말번호: ${widget.extension.extension}');
        debugPrint('   🔄 착신전환 활성화: $enabled');
        debugPrint('   ➡️  착신번호: $destination');
        debugPrint('   💾 DB 저장 여부: ${destination != _destination || enabled != _isEnabled ? "예" : "아니오 (변경 없음)"}');
        debugPrint('================================================');
        debugPrint('');
      }
    } catch (e) {
      if (kDebugMode) {
        debugPrint('');
        debugPrint('❌ ========== WebSocket 조회 실패 ==========');
        debugPrint('   📱 단말번호: ${widget.extension.extension}');
        debugPrint('   ⚠️  오류: $e');
        debugPrint('   💡 DB 저장 값 유지: enabled=$_isEnabled, destination=$_destination');
        debugPrint('================================================');
        debugPrint('');
      }
      if (mounted) {
        setState(() {
          _errorMessage = '착신번호 조회 실패 (DB 값 유지)';
        });
      }
    }
  }

  /// DB에 착신전환 정보 저장
  Future<void> _saveToDatabase() async {
    try {
      final authService = context.read<AuthService>();
      final userId = authService.currentUser?.uid;
      
      if (userId == null) return;

      final info = CallForwardInfoModel(
        id: '${userId}_${widget.extension.extension}',
        userId: userId,
        extensionNumber: widget.extension.extension,
        isEnabled: _isEnabled,
        destinationNumber: _destination,
        lastUpdated: DateTime.now(),
      );

      await _dbService.saveCallForwardInfo(info);

      if (kDebugMode) {
        debugPrint('');
        debugPrint('💾 ========== 착신전환 정보 DB 저장 ==========');
        debugPrint('   📱 단말번호: ${widget.extension.extension}');
        debugPrint('   🔄 착신전환 활성화: $_isEnabled');
        debugPrint('   ➡️  착신번호: $_destination');
        debugPrint('   🆔 문서 ID: ${info.id}');
        debugPrint('   📅 저장 시간: ${info.lastUpdated}');
        debugPrint('   ✅ Firestore 저장 완료');
        debugPrint('================================================');
        debugPrint('');
      }
    } catch (e) {
      if (kDebugMode) {
        debugPrint('❌ Failed to save to DB: $e');
      }
    }
  }

  /// 착신전환 활성화/비활성화 토글
  Future<void> _toggleCallForward(bool value) async {
    // 활성화하려는데 착신번호가 기본값이면 번호 입력 요청
    if (value && _destination == '00000000000') {
      if (mounted) {
        await DialogUtils.showWarning(
          context,
          '먼저 착신번호를 설정해주세요',
          duration: const Duration(seconds: 2),
        );
      }
      return;
    }

    setState(() {
      _isSaving = true;
      _errorMessage = null;
    });

    // DCMIWS 활성화 여부 확인 (임시 연결 필요 여부 판단)
    final authService = context.read<AuthService>();
    final userModel = authService.currentUserModel;
    final dcmiwsEnabled = userModel?.dcmiwsEnabled ?? false;
    bool temporaryConnection = false;

    try {
      // DCMIWS가 비활성화되어 있으면 임시 연결
      if (!dcmiwsEnabled && widget.wsServerAddress != null) {
        if (kDebugMode) {
          debugPrint('🔄 [착신전환] DCMIWS 비활성화 상태 - 임시 연결 시작');
        }
        
        await _wsService.connect(
          serverAddress: widget.wsServerAddress!,
          port: widget.wsServerPort ?? 6600,
          useSSL: widget.useSSL ?? false,
          httpAuthId: widget.httpAuthId,
          httpAuthPassword: widget.httpAuthPassword,
        );
        temporaryConnection = true;
        
        if (kDebugMode) {
          debugPrint('✅ [착신전환] 임시 연결 완료');
        }
      }

      final success = await _wsService.setCallForwardEnabled(
        amiServerId: widget.amiServerId ?? 1,
        tenantId: widget.tenantId!,
        extensionId: widget.extension.extension,
        enabled: value,
        diversionType: 'CFI',
      );

      if (success) {
        setState(() {
          _isEnabled = value;
          _lastUpdated = DateTime.now();
        });

        // DB에 저장
        await _saveToDatabase();

        // 푸시 알림 전송 (다른 기기에)
        try {
          final userId = authService.currentUser?.uid;
          if (userId != null) {
            if (value) {
              await _fcmCallForwardService.sendCallForwardEnabledNotification(
                userId: userId,
                extensionNumber: widget.extension.extension,
              );
            } else {
              await _fcmCallForwardService.sendCallForwardDisabledNotification(
                userId: userId,
                extensionNumber: widget.extension.extension,
              );
            }
          }
        } catch (e) {
          if (kDebugMode) {
            debugPrint('⚠️ 착신전환 푸시 알림 전송 실패 (무시): $e');
          }
        }

        if (mounted) {
          await DialogUtils.showSuccess(
            context,
            value ? '착신전환이 활성화되었습니다' : '착신전환이 비활성화되었습니다',
            duration: const Duration(seconds: 2),
          );
        }
      } else {
        throw Exception('Failed to update call forward status');
      }
    } catch (e) {
      if (kDebugMode) {
        debugPrint('❌ CallForwardSettings: Failed to toggle - $e');
      }
      if (mounted) {
        await DialogUtils.showError(
          context,
          '착신전환 설정 변경 실패',
        );
      }
    } finally {
      // 임시 연결이었다면 연결 해제
      if (temporaryConnection) {
        if (kDebugMode) {
          debugPrint('🔌 [착신전환] 임시 연결 해제');
        }
        await _wsService.disconnect();
      }
      
      setState(() {
        _isSaving = false;
      });
    }
  }

  /// 착신번호 클릭 시 다이얼로그 표시
  Future<void> _onDestinationTap() async {
    final TextEditingController controller = TextEditingController(
      text: _destination == '00000000000' ? '' : _destination,
    );

    final result = await showDialog<String>(
      context: context,
      builder: (dialogContext) {
        final dialogIsDark = Theme.of(dialogContext).brightness == Brightness.dark;
        
        return AlertDialog(
          title: Row(
            children: [
              const Icon(Icons.phone_forwarded, color: Color(0xFFFF9800)),
              const SizedBox(width: 12),
              Text('착신번호 설정', style: TextStyle(color: dialogIsDark ? Colors.white : Colors.black87)),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '전화를 받을 번호를 입력하세요',
                style: TextStyle(
                  fontSize: 12,
                  color: dialogIsDark ? Colors.grey[400] : Colors.grey[600],
                ),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: controller,
                keyboardType: TextInputType.phone,
                decoration: const InputDecoration(
                  labelText: '착신번호',
                  hintText: '예: 01012345678',
                  prefixIcon: Icon(Icons.phone),
                  border: OutlineInputBorder(),
                ),
                autofocus: true,
              ),
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.blue.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Row(
                  children: [
                    Icon(Icons.info_outline, size: 20, color: Colors.blue),
                    SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        '하이픈(-) 없이 숫자만 입력하세요',
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.blue,
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
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('취소'),
            ),
            ElevatedButton(
              onPressed: () async {
                final number = controller.text.trim();
                if (number.isEmpty) {
                  // 다이얼로그 내부에서는 try-catch로 안전하게 처리
                  try {
                    await DialogUtils.showError(dialogContext, '착신번호를 입력하세요', duration: const Duration(seconds: 3));
                  } catch (e) {
                    if (kDebugMode) {
                      debugPrint('⚠️ Dialog SnackBar 건너뜀: $e');
                    }
                  }
                  return;
                }
                Navigator.pop(dialogContext, number);
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFFF9800),
                foregroundColor: Colors.white,
              ),
              child: const Text('저장'),
            ),
          ],
        );
      },
    );

    if (result != null) {
      await _updateDestination(result);
    }
  }

  /// 착신번호 업데이트
  Future<void> _updateDestination(String newDestination) async {
    setState(() {
      _isSaving = true;
      _errorMessage = null;
    });

    // DCMIWS 활성화 여부 확인 (임시 연결 필요 여부 판단)
    final authService = context.read<AuthService>();
    final userModel = authService.currentUserModel;
    final dcmiwsEnabled = userModel?.dcmiwsEnabled ?? false;
    bool temporaryConnection = false;

    try {
      // DCMIWS가 비활성화되어 있으면 임시 연결
      if (!dcmiwsEnabled && widget.wsServerAddress != null) {
        if (kDebugMode) {
          debugPrint('🔄 [착신번호변경] DCMIWS 비활성화 상태 - 임시 연결 시작');
        }
        
        await _wsService.connect(
          serverAddress: widget.wsServerAddress!,
          port: widget.wsServerPort ?? 6600,
          useSSL: widget.useSSL ?? false,
          httpAuthId: widget.httpAuthId,
          httpAuthPassword: widget.httpAuthPassword,
        );
        temporaryConnection = true;
        
        if (kDebugMode) {
          debugPrint('✅ [착신번호변경] 임시 연결 완료');
        }
      }

      final success = await _wsService.setCallForwardDestination(
        amiServerId: widget.amiServerId ?? 1,
        tenantId: widget.tenantId!,
        extensionId: widget.extension.extension,
        destination: newDestination,
        diversionType: 'CFI',
      );

      if (success) {
        setState(() {
          _destination = newDestination;
          _lastUpdated = DateTime.now();
        });

        // DB에 저장
        await _saveToDatabase();

        // 푸시 알림 전송 (다른 기기에)
        try {
          final userId = authService.currentUser?.uid;
          if (userId != null) {
            await _fcmCallForwardService.sendCallForwardNumberChangedNotification(
              userId: userId,
              extensionNumber: widget.extension.extension,
              newNumber: PhoneFormatter.format(newDestination),
            );
          }
        } catch (e) {
          if (kDebugMode) {
            debugPrint('⚠️ 착신전환 번호 변경 푸시 알림 전송 실패 (무시): $e');
          }
        }

        if (mounted) {
          await DialogUtils.showSuccess(
            context,
            '착신번호가 ${PhoneFormatter.format(newDestination)}로 변경되었습니다',
            duration: const Duration(seconds: 2),
          );
        }

        // 착신번호 변경 후 자동으로 활성화
        if (!_isEnabled && mounted) {
          await _toggleCallForward(true);
        }
      } else {
        throw Exception('Failed to update destination');
      }
    } catch (e) {
      if (kDebugMode) {
        debugPrint('❌ CallForwardSettings: Failed to update destination - $e');
      }
      if (mounted) {
        await DialogUtils.showError(
          context,
          '착신번호 변경 실패',
        );
      }
    } finally {
      // 임시 연결이었다면 연결 해제
      if (temporaryConnection) {
        if (kDebugMode) {
          debugPrint('🔌 [착신번호변경] 임시 연결 해제');
        }
        await _wsService.disconnect();
      }
      
      setState(() {
        _isSaving = false;
      });
    }
  }

  /// WebSocket 설정 유효성 확인
  bool _hasValidConfig() {
    return widget.wsServerAddress != null &&
           widget.wsServerAddress!.isNotEmpty &&
           widget.wsServerPort != null &&
           widget.wsServerPort! > 0;
  }
  
  /// WebSocket 연결에 필요한 모든 설정 확인 (tenantId 포함)
  bool _hasFullConfig() {
    return _hasValidConfig() &&
           widget.tenantId != null &&
           widget.tenantId!.isNotEmpty;
  }

  /// 마지막 업데이트 시간 포맷팅
  String _formatLastUpdated() {
    if (_lastUpdated == null) return '정보 없음';
    
    final now = DateTime.now();
    final diff = now.difference(_lastUpdated!);

    if (diff.inMinutes < 1) {
      return '방금 전';
    } else if (diff.inMinutes < 60) {
      return '${diff.inMinutes}분 전';
    } else if (diff.inHours < 24) {
      return '${diff.inHours}시간 전';
    } else if (diff.inDays == 1) {
      return '어제';
    } else if (diff.inDays < 7) {
      return '${diff.inDays}일 전';
    } else {
      // 7일 이상이면 날짜 표시
      return '${_lastUpdated!.month}/${_lastUpdated!.day}';
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    
    // WebSocket 설정이 없으면 추가 연동 안내 표시
    if (!_hasValidConfig()) {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: Colors.orange.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: Colors.orange.withValues(alpha: 0.3),
            width: 2,
          ),
        ),
        child: Column(
          children: [
            const Icon(
              Icons.lock_outline,
              size: 32,
              color: Colors.orange,
            ),
            const SizedBox(height: 12),
            Text(
              '착신전환 설정',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: isDark ? Colors.orange[300] : Colors.orange[700],
              ),
            ),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: isDark ? Colors.orange[900]!.withValues(alpha: 0.3) : Colors.orange.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: isDark ? Colors.orange[700]! : Colors.orange.withValues(alpha: 0.3),
                  width: 1,
                ),
              ),
              child: Column(
                children: [
                  const Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.star, size: 18, color: Colors.orange),
                      SizedBox(width: 8),
                      Text(
                        '추가 연동 안내',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.bold,
                          color: Colors.orange,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    '착신전환 기능을 사용하려면\nDCMIWS 추가 연동이 필요합니다.',
                    style: TextStyle(
                      fontSize: 12,
                      color: isDark ? Colors.grey[300] : Colors.grey[700],
                      height: 1.4,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 12),
                  Text(
                    '담당자에게 문의하세요.',
                    style: TextStyle(
                      fontSize: 11,
                      color: isDark ? Colors.grey[500] : Colors.grey[600],
                    ),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            ),
          ],
        ),
      );
    }

    // 로딩 중
    if (_isLoading) {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: Colors.grey.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: Colors.grey.withValues(alpha: 0.3),
            width: 2,
          ),
        ),
        child: Column(
          children: [
            const CircularProgressIndicator(),
            const SizedBox(height: 12),
            Text(
              '착신번호 조회 중...',
              style: TextStyle(
                fontSize: 14,
                color: isDark ? Colors.grey[400] : Colors.grey[600],
              ),
            ),
          ],
        ),
      );
    }

    // 에러 발생 (WebSocket 연결 실패 시 간단한 에러 메시지)
    if (_errorMessage != null) {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: Colors.red.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: Colors.red.withValues(alpha: 0.3),
            width: 2,
          ),
        ),
        child: Column(
          children: [
            const Icon(
              Icons.error_outline,
              size: 32,
              color: Colors.red,
            ),
            const SizedBox(height: 12),
            const Text(
              'WebSocket 연결 실패',
              style: TextStyle(
                fontSize: 14,
                color: Colors.red,
                fontWeight: FontWeight.w600,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            TextButton.icon(
              onPressed: _initializeAndFetch,
              icon: const Icon(Icons.refresh, size: 20),
              label: const Text('다시 시도'),
              style: TextButton.styleFrom(
                foregroundColor: Colors.red,
              ),
            ),
          ],
        ),
      );
    }

    // 정상 표시
    final isDefaultNumber = _destination == '00000000000';
    final displayColor = _isEnabled && !isDefaultNumber
        ? const Color(0xFFFF9800) // 주황색 (착신전환 활성화)
        : Colors.grey; // 회색 (비활성화 또는 번호 미설정)

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: displayColor.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: displayColor.withValues(alpha: 0.3),
          width: 2,
        ),
      ),
      child: Column(
        children: [
          // 레이블
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                _isEnabled && !isDefaultNumber
                    ? Icons.phone_forwarded
                    : Icons.phone_disabled,
                size: 16,
                color: displayColor,
              ),
              const SizedBox(width: 8),
              Text(
                '착신전환 설정',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: displayColor,
                  letterSpacing: 0.5,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          
          // 활성화 토글 스위치
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: isDark ? Colors.grey[850] : Colors.white,
              borderRadius: BorderRadius.circular(12),
              boxShadow: [
                BoxShadow(
                  color: (isDark ? Colors.black : Colors.black).withValues(alpha: isDark ? 0.3 : 0.05),
                  blurRadius: 4,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Container(
                            width: 8,
                            height: 8,
                            decoration: BoxDecoration(
                              color: _isEnabled && !isDefaultNumber ? Colors.orange : Colors.grey,
                              shape: BoxShape.circle,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Text(
                            _isEnabled && !isDefaultNumber ? '활성화' : '비활성화',
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.bold,
                              color: displayColor,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      // 착신번호 (클릭 가능)
                      GestureDetector(
                        onTap: _isSaving ? null : _onDestinationTap,
                        child: Container(
                          padding: const EdgeInsets.symmetric(vertical: 5, horizontal: 8),
                          decoration: BoxDecoration(
                            color: Colors.grey.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(6),
                            border: Border.all(
                              color: Colors.grey.withValues(alpha: 0.3),
                              width: 1,
                            ),
                          ),
                          child: Row(
                            children: [
                              Icon(
                                Icons.phone,
                                size: 12,
                                color: isDefaultNumber 
                                    ? (isDark ? Colors.grey[600] : Colors.grey)
                                    : Colors.blue,
                              ),
                              const SizedBox(width: 4),
                              Expanded(
                                child: FittedBox(
                                  fit: BoxFit.scaleDown,
                                  alignment: Alignment.centerLeft,
                                  child: Text(
                                    PhoneFormatter.format(_destination),
                                    style: TextStyle(
                                      fontSize: 13,
                                      fontWeight: FontWeight.w600,
                                      color: isDefaultNumber 
                                          ? (isDark ? Colors.grey[600] : Colors.grey)
                                          : (isDark ? Colors.white : Colors.black87),
                                    ),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 3),
                              Icon(
                                Icons.edit,
                                size: 12,
                                color: isDark ? Colors.grey[400] : Colors.grey[600],
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          
          const SizedBox(height: 12),
          
          // 착신전환 활성화 스위치 & 새로고침 버튼
          Row(
            children: [
              // 착신전환 활성화 스위치
              Expanded(
                child: Row(
                  children: [
                    Text(
                      '착신전환',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w500,
                        color: isDark ? Colors.grey[400] : Colors.grey[700],
                      ),
                    ),
                    const SizedBox(width: 8),
                    Switch(
                      value: _isEnabled && !isDefaultNumber,
                      onChanged: _isSaving ? null : _toggleCallForward,
                      activeTrackColor: const Color(0xFFFF9800).withValues(alpha: 0.5),
                      activeThumbColor: const Color(0xFFFF9800),
                      materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    ),
                  ],
                ),
              ),
              // 새로고침 버튼 (아이콘만)
              IconButton(
                onPressed: _isSaving ? null : _fetchCallForwardInfo,
                icon: Icon(Icons.refresh, size: 20, color: displayColor),
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
                tooltip: '새로고침',
              ),
            ],
          ),
          
          // 저장 중 표시
          if (_isSaving) ...[
            const SizedBox(height: 12),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
                const SizedBox(width: 8),
                Text(
                  '저장 중...',
                  style: TextStyle(
                    fontSize: 12,
                    color: isDark ? Colors.grey[400] : Colors.grey[600],
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}
