import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import '../services/dcmiws_service.dart';
import '../services/database_service.dart';
import '../services/auth_service.dart';
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

  const CallForwardSettingsCard({
    super.key,
    required this.extension,
    this.tenantId,
    this.wsServerAddress,
    this.wsServerPort,
    this.useSSL,
    this.amiServerId,
  });

  @override
  State<CallForwardSettingsCard> createState() => _CallForwardSettingsCardState();
}

class _CallForwardSettingsCardState extends State<CallForwardSettingsCard> {
  final DCMIWSService _wsService = DCMIWSService();
  final DatabaseService _dbService = DatabaseService();
  
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

  /// 안전한 SnackBar 표시 헬퍼 (위젯이 dispose되어도 에러 없음)
  void _safeShowSnackBar(SnackBar snackBar) {
    if (!mounted) return;
    
    try {
      ScaffoldMessenger.of(context).showSnackBar(snackBar);
    } catch (e) {
      // 위젯이 이미 dispose된 경우 무시
      if (kDebugMode) {
        debugPrint('⚠️ CallForwardSettings: SnackBar 표시 건너뜀 (위젯 비활성화): $e');
      }
    }
  }

  /// WebSocket 초기화 및 착신번호 조회
  Future<void> _initializeAndFetch() async {
    // 필수 설정 확인
    if (!_hasValidConfig()) {
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
          debugPrint('✅ Loaded from DB: enabled=$_isEnabled, destination=$_destination');
        }
      }
    } catch (e) {
      if (kDebugMode) {
        debugPrint('⚠️ Failed to load from DB: $e');
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

      // 조회된 착신번호가 없으면 기본값 사용
      if (destination == null || destination.isEmpty) {
        destination = '00000000000';
      }

      if (mounted) {
        setState(() {
          _isEnabled = enabled;
          _destination = destination!;
          _lastUpdated = DateTime.now();
          _errorMessage = null;
        });

        // DB에 저장
        await _saveToDatabase();
      }

      if (kDebugMode) {
        debugPrint('✅ CallForwardSettings: Enabled=$enabled, Destination=$destination');
      }
    } catch (e) {
      if (kDebugMode) {
        debugPrint('❌ CallForwardSettings: Failed to fetch - $e');
      }
      if (mounted) {
        setState(() {
          _errorMessage = '착신번호 조회 실패';
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
        debugPrint('✅ Saved to DB: ${info.id}');
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
      _safeShowSnackBar(
        const SnackBar(
          content: Text('먼저 착신번호를 설정해주세요'),
          backgroundColor: Colors.orange,
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    setState(() {
      _isSaving = true;
      _errorMessage = null;
    });

    try {
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

        _safeShowSnackBar(
          SnackBar(
            content: Text(value ? '착신전환이 활성화되었습니다' : '착신전환이 비활성화되었습니다'),
            backgroundColor: value ? Colors.orange : Colors.grey,
            behavior: SnackBarBehavior.floating,
          ),
        );
      } else {
        throw Exception('Failed to update call forward status');
      }
    } catch (e) {
      if (kDebugMode) {
        debugPrint('❌ CallForwardSettings: Failed to toggle - $e');
      }
      _safeShowSnackBar(
        const SnackBar(
          content: Text('착신전환 설정 변경 실패'),
          backgroundColor: Colors.red,
          behavior: SnackBarBehavior.floating,
        ),
      );
    } finally {
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
      builder: (context) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.phone_forwarded, color: Color(0xFFFF9800)),
            SizedBox(width: 12),
            Text('착신번호 설정'),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              '전화를 받을 번호를 입력하세요',
              style: TextStyle(
                fontSize: 12,
                color: Colors.grey,
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
            onPressed: () => Navigator.pop(context),
            child: const Text('취소'),
          ),
          ElevatedButton(
            onPressed: () {
              final number = controller.text.trim();
              if (number.isEmpty) {
                // 다이얼로그 내부에서는 try-catch로 안전하게 처리
                try {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('착신번호를 입력하세요'),
                      backgroundColor: Colors.red,
                    ),
                  );
                } catch (e) {
                  if (kDebugMode) {
                    debugPrint('⚠️ Dialog SnackBar 건너뜀: $e');
                  }
                }
                return;
              }
              Navigator.pop(context, number);
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFFF9800),
              foregroundColor: Colors.white,
            ),
            child: const Text('저장'),
          ),
        ],
      ),
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

    try {
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

        _safeShowSnackBar(
          SnackBar(
            content: Text('착신번호가 ${PhoneFormatter.format(newDestination)}로 변경되었습니다'),
            backgroundColor: Colors.green,
            behavior: SnackBarBehavior.floating,
          ),
        );

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
      _safeShowSnackBar(
        const SnackBar(
          content: Text('착신번호 변경 실패'),
          backgroundColor: Colors.red,
          behavior: SnackBarBehavior.floating,
        ),
      );
    } finally {
      setState(() {
        _isSaving = false;
      });
    }
  }

  /// 설정 유효성 확인
  bool _hasValidConfig() {
    return widget.tenantId != null &&
           widget.tenantId!.isNotEmpty &&
           widget.wsServerAddress != null &&
           widget.wsServerAddress!.isNotEmpty &&
           widget.wsServerPort != null &&
           widget.wsServerPort! > 0;
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
    // 설정이 없으면 표시하지 않음
    if (!_hasValidConfig()) {
      return const SizedBox.shrink();
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
        child: const Column(
          children: [
            CircularProgressIndicator(),
            SizedBox(height: 12),
            Text(
              '착신번호 조회 중...',
              style: TextStyle(
                fontSize: 14,
                color: Colors.grey,
              ),
            ),
          ],
        ),
      );
    }

    // 에러 발생
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
            const SizedBox(height: 8),
            Text(
              _errorMessage!,
              style: const TextStyle(
                fontSize: 14,
                color: Colors.red,
                fontWeight: FontWeight.w600,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 12),
            TextButton.icon(
              onPressed: _initializeAndFetch,
              icon: const Icon(Icons.refresh),
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
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.05),
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
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                Icons.phone,
                                size: 12,
                                color: isDefaultNumber ? Colors.grey : Colors.blue,
                              ),
                              const SizedBox(width: 4),
                              Flexible(
                                child: Text(
                                  PhoneFormatter.format(_destination),
                                  style: TextStyle(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w600,
                                    color: isDefaultNumber ? Colors.grey : Colors.black87,
                                  ),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                              const SizedBox(width: 3),
                              Icon(
                                Icons.edit,
                                size: 12,
                                color: Colors.grey[600],
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
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              // 착신전환 활성화 스위치
              Row(
                children: [
                  Text(
                    '착신전환',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w500,
                      color: Colors.grey[700],
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
              // 새로고침 버튼
              TextButton.icon(
                onPressed: _isSaving ? null : _fetchCallForwardInfo,
                icon: const Icon(Icons.refresh, size: 16),
                label: const Text('새로고침', style: TextStyle(fontSize: 11)),
                style: TextButton.styleFrom(
                  foregroundColor: displayColor,
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  minimumSize: Size.zero,
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
              ),
            ],
          ),
          
          // 저장 중 표시
          if (_isSaving) ...[
            const SizedBox(height: 12),
            const Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
                SizedBox(width: 8),
                Text(
                  '저장 중...',
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.grey,
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
