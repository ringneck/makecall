import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'dart:async';
import 'dart:ui';
import '../../services/fcm_service.dart';
import '../../utils/dialog_utils.dart';

/// 기기 승인 대기 전용 화면
/// 
/// 새 기기에서 로그인 시 기존 기기의 승인을 대기하는 전체 화면
/// - 5분 타이머 표시
/// - 승인 요청 재전송 기능
/// - 승인 완료/거부/시간 초과 처리
class ApprovalWaitingScreen extends StatefulWidget {
  final String approvalRequestId;
  final String userId;
  
  const ApprovalWaitingScreen({
    super.key,
    required this.approvalRequestId,
    required this.userId,
  });

  @override
  State<ApprovalWaitingScreen> createState() => _ApprovalWaitingScreenState();
}

class _ApprovalWaitingScreenState extends State<ApprovalWaitingScreen> {
  static const int _maxSeconds = 300; // 5분
  int _remainingSeconds = _maxSeconds;
  Timer? _timer;
  bool _isResending = false;

  @override
  void initState() {
    super.initState();
    _startTimer();
    _waitForApproval();
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  void _startTimer() {
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (_remainingSeconds > 0) {
        setState(() {
          _remainingSeconds--;
        });
      } else {
        timer.cancel();
      }
    });
  }

  String _formatTime(int seconds) {
    final minutes = seconds ~/ 60;
    final secs = seconds % 60;
    return '${minutes.toString().padLeft(2, '0')}:${secs.toString().padLeft(2, '0')}';
  }

  /// 승인 대기 (FCMService와 연동)
  Future<void> _waitForApproval() async {
    try {
      if (kDebugMode) {
        debugPrint('⏳ [APPROVAL-SCREEN] 승인 대기 시작');
        debugPrint('   - Approval Request ID: ${widget.approvalRequestId}');
      }

      // FCMService를 통해 승인 대기
      // FCMService 내부에서 Firestore 리스너로 승인 상태 모니터링
      // 이 함수는 승인이 완료되거나 거부/시간 초과될 때까지 대기
      
      // 이미 FCMService.initialize()에서 대기 중이므로
      // 여기서는 별도의 대기 로직 없이 화면만 표시
      
    } catch (e) {
      if (kDebugMode) {
        debugPrint('❌ [APPROVAL-SCREEN] 승인 대기 오류: $e');
      }
    }
  }

  /// 승인 요청 재전송
  Future<void> _handleResendRequest() async {
    if (_isResending) return;

    setState(() => _isResending = true);

    try {
      if (kDebugMode) {
        debugPrint('🔄 [APPROVAL-SCREEN] 재요청 버튼 클릭');
      }

      await FCMService().resendApprovalRequest(
        widget.approvalRequestId,
        widget.userId,
      );

      if (mounted) {
        await DialogUtils.showSuccess(
          context,
          '✅ 승인 요청을 다시 전송했습니다',
          duration: const Duration(seconds: 2),
        );
      }
    } catch (e) {
      if (kDebugMode) {
        debugPrint('❌ [APPROVAL-SCREEN] 재전송 오류: $e');
      }

      if (mounted) {
        await DialogUtils.showError(
          context,
          '❌ 재전송 실패: $e',
          duration: const Duration(seconds: 3),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isResending = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false, // 뒤로 가기 방지
      child: Scaffold(
        body: Container(
          width: double.infinity,
          height: double.infinity,
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [
                const Color(0xFF2196F3).withValues(alpha: 0.1),
                Colors.white,
              ],
            ),
          ),
          child: SafeArea(
            child: Center(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(32),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    // 🔐 아이콘
                    Container(
                      padding: const EdgeInsets.all(24),
                      decoration: BoxDecoration(
                        color: const Color(0xFF2196F3).withValues(alpha: 0.1),
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(
                            color: const Color(0xFF2196F3).withValues(alpha: 0.2),
                            blurRadius: 20,
                            spreadRadius: 5,
                          ),
                        ],
                      ),
                      child: const Icon(
                        Icons.devices,
                        size: 64,
                        color: Color(0xFF2196F3),
                      ),
                    ),
                    const SizedBox(height: 32),
                    
                    // 제목
                    const Text(
                      '기기 승인 대기 중',
                      style: TextStyle(
                        fontSize: 28,
                        fontWeight: FontWeight.bold,
                        color: Colors.black87,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 16),
                    
                    // 설명
                    Text(
                      '다른 기기에서 이 기기의 로그인을\n승인해주세요.',
                      style: TextStyle(
                        fontSize: 16,
                        color: Colors.grey[700],
                        height: 1.5,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 48),
                    
                    // 타이머
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(16),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.1),
                            blurRadius: 10,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(
                            Icons.timer_outlined,
                            size: 24,
                            color: Color(0xFF2196F3),
                          ),
                          const SizedBox(width: 12),
                          Text(
                            _formatTime(_remainingSeconds),
                            style: const TextStyle(
                              fontSize: 32,
                              fontWeight: FontWeight.bold,
                              color: Color(0xFF2196F3),
                              fontFeatures: [FontFeature.tabularFigures()],
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 32),
                    
                    // 로딩 인디케이터
                    const SizedBox(
                      width: 48,
                      height: 48,
                      child: CircularProgressIndicator(
                        strokeWidth: 3,
                        color: Color(0xFF2196F3),
                      ),
                    ),
                    const SizedBox(height: 48),
                    
                    // 재요청 버튼
                    OutlinedButton.icon(
                      onPressed: _isResending ? null : _handleResendRequest,
                      icon: _isResending
                          ? const SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Icon(Icons.refresh),
                      label: Text(_isResending ? '전송 중...' : '승인 요청 재전송'),
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 24,
                          vertical: 16,
                        ),
                        side: const BorderSide(color: Color(0xFF2196F3)),
                        foregroundColor: const Color(0xFF2196F3),
                      ),
                    ),
                    const SizedBox(height: 24),
                    
                    // 안내 텍스트
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.blue[50],
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: Colors.blue[100]!),
                      ),
                      child: Column(
                        children: [
                          Row(
                            children: [
                              Icon(Icons.info_outline, size: 20, color: Colors.blue[700]),
                              const SizedBox(width: 8),
                              Text(
                                '승인 방법',
                                style: TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.blue[900],
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          Text(
                            '1. 기존 기기에서 알림을 확인하세요\n'
                            '2. "승인" 버튼을 눌러주세요\n'
                            '3. 승인이 완료되면 자동으로 로그인됩니다',
                            style: TextStyle(
                              fontSize: 13,
                              color: Colors.blue[800],
                              height: 1.5,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
