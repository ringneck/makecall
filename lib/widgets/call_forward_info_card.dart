import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import '../services/dcmiws_service.dart';
import '../models/my_extension_model.dart';

/// 착신번호 정보 표시 카드
/// 
/// WebSocket을 통해 실시간으로 착신번호를 조회하고 표시합니다.
class CallForwardInfoCard extends StatefulWidget {
  final MyExtensionModel extension;
  final String? tenantId;
  final String? wsServerAddress;
  final int? wsServerPort;
  final bool? useSSL;
  final int? amiServerId;

  const CallForwardInfoCard({
    super.key,
    required this.extension,
    this.tenantId,
    this.wsServerAddress,
    this.wsServerPort,
    this.useSSL,
    this.amiServerId,
  });

  @override
  State<CallForwardInfoCard> createState() => _CallForwardInfoCardState();
}

class _CallForwardInfoCardState extends State<CallForwardInfoCard> {
  final DCMIWSService _wsService = DCMIWSService();
  
  bool _isLoading = false;
  bool _isEnabled = false;
  String? _destination;
  String? _errorMessage;

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
        debugPrint('⚠️ CallForwardInfo: Invalid WebSocket configuration');
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
        debugPrint('❌ CallForwardInfo: Error - $e');
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
        debugPrint('✅ CallForwardInfo: Enabled=$enabled, Destination=$destination');
      }
    } catch (e) {
      if (kDebugMode) {
        debugPrint('❌ CallForwardInfo: Failed to fetch - $e');
      }
      if (mounted) {
        setState(() {
          _errorMessage = '착신번호 조회 실패';
        });
      }
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
                '착신전환 정보',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: displayColor,
                  letterSpacing: 1,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          
          // 상태 표시
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
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
          
          // 착신번호 표시
          if (hasDestination) ...[
            const SizedBox(height: 8),
            Text(
              _destination!,
              style: TextStyle(
                fontSize: 28,
                fontWeight: FontWeight.w600,
                color: displayColor,
                letterSpacing: 2,
              ),
              textAlign: TextAlign.center,
            ),
          ] else ...[
            const SizedBox(height: 8),
            Text(
              '착신번호 미설정',
              style: TextStyle(
                fontSize: 16,
                color: Colors.grey[600],
                fontStyle: FontStyle.italic,
              ),
            ),
          ],
          
          // 새로고침 버튼
          const SizedBox(height: 12),
          TextButton.icon(
            onPressed: _fetchCallForwardInfo,
            icon: Icon(
              Icons.refresh,
              size: 16,
              color: displayColor,
            ),
            label: Text(
              '새로고침',
              style: TextStyle(
                fontSize: 12,
                color: displayColor,
              ),
            ),
            style: TextButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              minimumSize: Size.zero,
              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
            ),
          ),
        ],
      ),
    );
  }
}
