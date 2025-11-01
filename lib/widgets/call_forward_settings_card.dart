import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import '../services/dcmiws_service.dart';
import '../models/my_extension_model.dart';

/// 착신전환 설정 카드 (조회 + 변경)
/// 
/// WebSocket을 통해 실시간으로 착신번호를 조회하고 설정을 변경합니다.
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
  
  bool _isLoading = false;
  bool _isEnabled = false;
  String? _destination;
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

      // 착신번호 조회
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

  /// 착신번호 정보 조회
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
      final destination = await _wsService.getCallForwardDestination(
        amiServerId: widget.amiServerId ?? 1,
        tenantId: widget.tenantId!,
        extensionId: widget.extension.extension,
        diversionType: 'CFI',
      );

      if (mounted) {
        setState(() {
          _isEnabled = enabled;
          _destination = destination;
          _errorMessage = null;
        });
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

  /// 착신전환 활성화/비활성화 토글
  Future<void> _toggleCallForward(bool value) async {
    // 활성화하려는데 착신번호가 없으면 번호 입력 다이얼로그 표시
    if (value && (_destination == null || _destination!.isEmpty)) {
      await _showDestinationDialog();
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
        });

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(value ? '착신전환이 활성화되었습니다' : '착신전환이 비활성화되었습니다'),
              backgroundColor: value ? Colors.orange : Colors.grey,
              behavior: SnackBarBehavior.floating,
            ),
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
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('착신전환 설정 변경 실패'),
            backgroundColor: Colors.red,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } finally {
      setState(() {
        _isSaving = false;
      });
    }
  }

  /// 착신번호 설정 다이얼로그
  Future<void> _showDestinationDialog() async {
    final TextEditingController controller = TextEditingController(
      text: _destination ?? '',
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
                fontSize: 14,
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
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('착신번호를 입력하세요'),
                    backgroundColor: Colors.red,
                  ),
                );
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
        });

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('착신번호가 $newDestination로 변경되었습니다'),
              backgroundColor: Colors.green,
              behavior: SnackBarBehavior.floating,
            ),
          );

          // 착신번호 변경 후 자동으로 활성화
          if (!_isEnabled) {
            await _toggleCallForward(true);
          }
        }
      } else {
        throw Exception('Failed to update destination');
      }
    } catch (e) {
      if (kDebugMode) {
        debugPrint('❌ CallForwardSettings: Failed to update destination - $e');
      }
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('착신번호 변경 실패'),
            backgroundColor: Colors.red,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
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
    final hasDestination = _destination != null && _destination!.isNotEmpty;
    final displayColor = _isEnabled && hasDestination
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
                _isEnabled && hasDestination
                    ? Icons.phone_forwarded
                    : Icons.phone_disabled,
                size: 20,
                color: displayColor,
              ),
              const SizedBox(width: 8),
              Text(
                '착신전환 설정',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: displayColor,
                  letterSpacing: 1,
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
                              color: _isEnabled && hasDestination ? Colors.orange : Colors.grey,
                              shape: BoxShape.circle,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Text(
                            _isEnabled && hasDestination ? '활성화' : '비활성화',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color: displayColor,
                            ),
                          ),
                        ],
                      ),
                      if (hasDestination) ...[
                        const SizedBox(height: 4),
                        Text(
                          _destination!,
                          style: TextStyle(
                            fontSize: 14,
                            color: Colors.grey[600],
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                Switch(
                  value: _isEnabled && hasDestination,
                  onChanged: _isSaving ? null : _toggleCallForward,
                  activeTrackColor: const Color(0xFFFF9800).withValues(alpha: 0.5),
                  activeThumbColor: const Color(0xFFFF9800),
                ),
              ],
            ),
          ),
          
          const SizedBox(height: 12),
          
          // 액션 버튼들
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: _isSaving ? null : _showDestinationDialog,
                  icon: const Icon(Icons.edit, size: 18),
                  label: const Text('번호 변경'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: displayColor,
                    side: BorderSide(color: displayColor),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: _isSaving ? null : _fetchCallForwardInfo,
                  icon: const Icon(Icons.refresh, size: 18),
                  label: const Text('새로고침'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: displayColor,
                    side: BorderSide(color: displayColor),
                  ),
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
