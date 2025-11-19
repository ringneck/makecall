import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'dart:async';
import '../../services/fcm/fcm_device_approval_service.dart';
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
        _handleTimeout(); // 타이머 종료 시 처리
      }
    });
  }

  /// 타이머 종료 시 로그인 페이지로 이동
  Future<void> _handleTimeout() async {
    if (!mounted) return;

    if (kDebugMode) {
      debugPrint('⏰ [APPROVAL-SCREEN] 승인 대기 시간 초과 (5분)');
    }

    try {
      // 다이얼로그 표시 (3초 대기)
      await DialogUtils.showError(
        context,
        '승인 대기 시간이 초과되었습니다.\n다시 로그인해주세요.',
        duration: const Duration(seconds: 3),
      );
    } catch (e) {
      if (kDebugMode) {
        debugPrint('⚠️ [APPROVAL-SCREEN] 다이얼로그 표시 중 오류: $e');
      }
    }

    // 다이얼로그가 닫힌 후 로그인 페이지로 이동
    // mounted 체크를 한 번 더 수행 (다이얼로그 표시 중 화면이 dispose될 수 있음)
    if (!mounted) {
      if (kDebugMode) {
        debugPrint('⚠️ [APPROVAL-SCREEN] 화면이 이미 dispose됨, 네비게이션 취소');
      }
      return;
    }

    if (kDebugMode) {
      debugPrint('🔄 [APPROVAL-SCREEN] 로그인 페이지로 이동 시작');
    }

    // 로그인 페이지로 이동 (모든 이전 화면 제거)
    try {
      await Navigator.of(context).pushNamedAndRemoveUntil(
        '/login',
        (route) => false,
      );

      if (kDebugMode) {
        debugPrint('✅ [APPROVAL-SCREEN] 로그인 페이지 이동 완료');
      }
    } catch (e) {
      if (kDebugMode) {
        debugPrint('❌ [APPROVAL-SCREEN] 로그인 페이지 이동 실패: $e');
      }
    }
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

      await FCMDeviceApprovalService().resendApprovalRequest(
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
    final isDark = Theme.of(context).brightness == Brightness.dark;
    
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
              colors: isDark
                  ? [
                      const Color(0xFF2196F3).withValues(alpha: 0.2),
                      Colors.grey[900]!,
                    ]
                  : [
                      const Color(0xFF2196F3).withValues(alpha: 0.1),
                      Colors.white,
                    ],
            ),
          ),
          child: SafeArea(
            child: Center(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const SizedBox(height: 20), // 상단 여백 추가
                    // 🔐 아이콘
                    Container(
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        color: isDark
                            ? const Color(0xFF2196F3).withValues(alpha: 0.2)
                            : const Color(0xFF2196F3).withValues(alpha: 0.1),
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(
                            color: const Color(0xFF2196F3).withValues(alpha: isDark ? 0.3 : 0.2),
                            blurRadius: 20,
                            spreadRadius: 5,
                          ),
                        ],
                      ),
                      child: Icon(
                        Icons.devices,
                        size: 56,
                        color: isDark ? Colors.blue[300] : const Color(0xFF2196F3),
                      ),
                    ),
                    const SizedBox(height: 24),
                    
                    // 제목
                    Text(
                      '기기 승인 대기 중',
                      style: TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                        color: isDark ? Colors.grey[200] : Colors.black87,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 12),
                    
                    // 설명
                    Text(
                      '다른 기기에서 이 기기의 로그인을\n승인해주세요.',
                      style: TextStyle(
                        fontSize: 15,
                        color: isDark ? Colors.grey[400] : Colors.grey[700],
                        height: 1.5,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 32),
                    
                    // 타이머
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
                      decoration: BoxDecoration(
                        color: isDark ? Colors.grey[850] : Colors.white,
                        borderRadius: BorderRadius.circular(16),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: isDark ? 0.3 : 0.1),
                            blurRadius: 10,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.timer_outlined,
                            size: 22,
                            color: isDark ? Colors.blue[300] : const Color(0xFF2196F3),
                          ),
                          const SizedBox(width: 10),
                          Text(
                            _formatTime(_remainingSeconds),
                            style: TextStyle(
                              fontSize: 28,
                              fontWeight: FontWeight.bold,
                              color: isDark ? Colors.blue[300] : const Color(0xFF2196F3),
                              fontFeatures: const [FontFeature.tabularFigures()],
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 28),
                    
                    // 로딩 인디케이터
                    SizedBox(
                      width: 40,
                      height: 40,
                      child: CircularProgressIndicator(
                        strokeWidth: 3,
                        color: isDark ? Colors.blue[300] : const Color(0xFF2196F3),
                      ),
                    ),
                    const SizedBox(height: 32),
                    
                    // 재요청 버튼
                    OutlinedButton.icon(
                      onPressed: _isResending ? null : _handleResendRequest,
                      icon: _isResending
                          ? SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: isDark ? Colors.blue[300] : const Color(0xFF2196F3),
                              ),
                            )
                          : const Icon(Icons.refresh, size: 20),
                      label: Text(
                        _isResending ? '전송 중...' : '승인 요청 재전송',
                        style: const TextStyle(fontSize: 14),
                      ),
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 20,
                          vertical: 14,
                        ),
                        side: BorderSide(
                          color: isDark ? Colors.blue[300]! : const Color(0xFF2196F3),
                        ),
                        foregroundColor: isDark ? Colors.blue[300] : const Color(0xFF2196F3),
                      ),
                    ),
                    const SizedBox(height: 20),
                    
                    // 안내 텍스트
                    Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: isDark 
                            ? Colors.blue[900]!.withValues(alpha: 0.3)
                            : Colors.blue[50],
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: isDark ? Colors.blue[700]! : Colors.blue[100]!,
                        ),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Icon(
                                Icons.info_outline, 
                                size: 18, 
                                color: isDark ? Colors.blue[300] : Colors.blue[700],
                              ),
                              const SizedBox(width: 8),
                              Text(
                                '승인 방법',
                                style: TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.bold,
                                  color: isDark ? Colors.blue[300] : Colors.blue[900],
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
                              fontSize: 12,
                              color: isDark ? Colors.blue[200] : Colors.blue[800],
                              height: 1.5,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 20), // 하단 여백 추가
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
