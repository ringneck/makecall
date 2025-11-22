import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:provider/provider.dart';
import 'dart:async';
import '../../utils/dialog_utils.dart';
import '../../services/auth_service.dart';

/// 기기 승인 대기 화면
/// 
/// 새 기기에서 로그인 시도 시 기존 기기의 승인을 대기하는 화면입니다.
/// 두 가지 옵션을 제공합니다:
/// - 옵션 A: 기존 기기에서 FCM 푸시로 승인 (추천, 즉시)
/// - 옵션 B: 이메일 인증 코드 입력 (백업, 1-3분)
class DeviceApprovalScreen extends StatefulWidget {
  final String userId;
  final String approvalRequestId;
  final String deviceName;
  final String platform;

  const DeviceApprovalScreen({
    super.key,
    required this.userId,
    required this.approvalRequestId,
    required this.deviceName,
    required this.platform,
  });

  @override
  State<DeviceApprovalScreen> createState() => _DeviceApprovalScreenState();
}

class _DeviceApprovalScreenState extends State<DeviceApprovalScreen> with TickerProviderStateMixin {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  StreamSubscription<DocumentSnapshot>? _approvalSubscription;
  
  bool _isWaitingForApproval = true;
  bool _isEmailOptionSelected = false;
  bool _isVerifyingCode = false;
  
  final TextEditingController _codeController = TextEditingController();
  String? _errorMessage;
  
  // 타이머 관련
  Timer? _expiryTimer;
  int _remainingSeconds = 300; // 5분
  
  // 애니메이션 컨트롤러
  late AnimationController _pulseController;
  late Animation<double> _pulseAnimation;

  @override
  void initState() {
    super.initState();
    _startListeningForApproval();
    _startExpiryTimer();
    
    // 펄스 애니메이션 설정
    _pulseController = AnimationController(
      duration: const Duration(seconds: 1),
      vsync: this,
    )..repeat(reverse: true);
    
    _pulseAnimation = Tween<double>(begin: 0.95, end: 1.05).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _approvalSubscription?.cancel();
    _expiryTimer?.cancel();
    _codeController.dispose();
    _pulseController.dispose();
    super.dispose();
  }

  /// 만료 타이머 시작
  void _startExpiryTimer() {
    _expiryTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (_remainingSeconds > 0) {
        setState(() {
          _remainingSeconds--;
        });
      } else {
        timer.cancel();
        _handleApprovalExpired();
      }
    });
  }

  /// 타이머 포맷 (MM:SS)
  String _formatTime(int seconds) {
    final minutes = seconds ~/ 60;
    final secs = seconds % 60;
    return '${minutes.toString().padLeft(2, '0')}:${secs.toString().padLeft(2, '0')}';
  }

  /// Firestore에서 승인 상태 실시간 모니터링
  void _startListeningForApproval() {
    _approvalSubscription = _firestore
        .collection('device_approval_requests')
        .doc(widget.approvalRequestId)
        .snapshots()
        .listen((snapshot) {
      if (!snapshot.exists) {
        debugPrint('❌ [APPROVAL] 승인 요청 문서 없음');
        return;
      }

      final data = snapshot.data();
      if (data == null) return;

      final status = data['status'] as String?;
      
      debugPrint('🔍 [APPROVAL] 상태 변경: $status');

      if (status == 'approved') {
        // 승인됨 - 로그인 완료
        debugPrint('✅ [APPROVAL] 승인 완료!');
        _handleApprovalSuccess();
      } else if (status == 'rejected') {
        // 거부됨 - 로그인 취소
        debugPrint('❌ [APPROVAL] 거부됨');
        _handleApprovalRejected();
      } else if (status == 'expired') {
        // 만료됨 (5분 경과)
        debugPrint('⏰ [APPROVAL] 승인 요청 만료');
        _handleApprovalExpired();
      }
    });
  }

  /// 승인 성공 처리
  Future<void> _handleApprovalSuccess() async {
    if (!mounted) return;
    
    setState(() {
      _isWaitingForApproval = false;
    });
    
    // 성공 다이얼로그
    await DialogUtils.showSuccess(
      context,
      '기기 승인 완료!',
      duration: const Duration(seconds: 1),
    );
    
    // 🔥 CRITICAL FIX: Navigator 조작 대신 AuthService 상태만 변경
    // MaterialApp.home Consumer가 자동으로 MainScreen으로 전환함
    final authService = context.read<AuthService>();
    authService.setWaitingForApproval(false);
    
    if (kDebugMode) {
      debugPrint('✅ [APPROVAL] 승인 완료 - MaterialApp.home이 MainScreen으로 전환됨');
    }
  }

  /// 승인 거부 처리
  void _handleApprovalRejected() {
    if (!mounted) return;
    
    setState(() {
      _isWaitingForApproval = false;
      _errorMessage = '기존 기기에서 로그인을 거부했습니다.';
    });
    
    final isDark = Theme.of(context).brightness == Brightness.dark;
    
    // 거부 다이얼로그 표시
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        backgroundColor: isDark ? Colors.grey[900] : Colors.white,
        title: Row(
          children: [
            Icon(Icons.block, color: isDark ? Colors.red[300] : Colors.red, size: 28),
            const SizedBox(width: 12),
            Text(
              '로그인 거부됨',
              style: TextStyle(color: isDark ? Colors.grey[200] : Colors.black87),
            ),
          ],
        ),
        content: Text(
          '기존 기기에서 로그인을 거부했습니다.\n로그인 화면으로 돌아갑니다.',
          style: TextStyle(fontSize: 14, color: isDark ? Colors.grey[300] : Colors.black87),
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.of(context).pop(); // 다이얼로그 닫기
              Navigator.of(context).pop(); // DeviceApprovalScreen 닫기
            },
            child: Text(
              '확인',
              style: TextStyle(color: isDark ? Colors.blue[300] : const Color(0xFF2196F3)),
            ),
          ),
        ],
      ),
    );
  }

  /// 승인 만료 처리
  void _handleApprovalExpired() {
    if (!mounted) return;
    
    setState(() {
      _isWaitingForApproval = false;
      _errorMessage = '승인 요청이 만료되었습니다 (5분 경과).';
    });
    
    final isDark = Theme.of(context).brightness == Brightness.dark;
    
    // 만료 다이얼로그 표시
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        backgroundColor: isDark ? Colors.grey[900] : Colors.white,
        title: Row(
          children: [
            Icon(Icons.access_time, color: isDark ? Colors.orange[300] : Colors.orange, size: 28),
            const SizedBox(width: 12),
            Text(
              '승인 요청 만료',
              style: TextStyle(color: isDark ? Colors.grey[200] : Colors.black87),
            ),
          ],
        ),
        content: Text(
          '5분이 경과하여 승인 요청이 만료되었습니다.\n다시 로그인해주세요.',
          style: TextStyle(fontSize: 14, color: isDark ? Colors.grey[300] : Colors.black87),
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.of(context).pop(); // 다이얼로그 닫기
              Navigator.of(context).pop(); // DeviceApprovalScreen 닫기
            },
            child: Text(
              '확인',
              style: TextStyle(color: isDark ? Colors.blue[300] : const Color(0xFF2196F3)),
            ),
          ),
        ],
      ),
    );
  }

  /// 이메일 인증 코드 전송 요청
  Future<void> _requestEmailVerificationCode() async {
    try {
      debugPrint('📧 [EMAIL] 인증 코드 전송 요청');
      
      setState(() {
        _isEmailOptionSelected = true;
        _errorMessage = null;
      });
      
      // Firestore에 이메일 인증 요청 추가 (Cloud Functions에서 처리)
      await _firestore.collection('email_verification_requests').add({
        'userId': widget.userId,
        'approvalRequestId': widget.approvalRequestId,
        'code': _generateVerificationCode(),
        'createdAt': FieldValue.serverTimestamp(),
        'expiresAt': Timestamp.fromDate(DateTime.now().add(const Duration(minutes: 5))),
        'used': false,
      });
      
      debugPrint('✅ [EMAIL] 인증 코드 전송 요청 완료');
      
      if (mounted) {
        await DialogUtils.showInfo(
          context,
          '이메일로 인증 코드를 전송했습니다 (1-3분 소요)',
          duration: const Duration(seconds: 1),
        );
      }
      
    } catch (e) {
      debugPrint('❌ [EMAIL] 인증 코드 전송 실패: $e');
      
      if (mounted) {
        setState(() {
          _errorMessage = '이메일 전송 실패. 다시 시도해주세요.';
        });
      }
    }
  }

  /// 6자리 랜덤 인증 코드 생성
  String _generateVerificationCode() {
    final random = DateTime.now().millisecondsSinceEpoch % 1000000;
    return random.toString().padLeft(6, '0');
  }

  /// 이메일 인증 코드 검증
  Future<void> _verifyEmailCode() async {
    final code = _codeController.text.trim();
    
    if (code.length != 6) {
      setState(() {
        _errorMessage = '6자리 코드를 입력하세요.';
      });
      return;
    }
    
    setState(() {
      _isVerifyingCode = true;
      _errorMessage = null;
    });
    
    try {
      debugPrint('🔍 [EMAIL] 코드 검증 시작: $code');
      
      // Firestore에서 인증 코드 조회
      final querySnapshot = await _firestore
          .collection('email_verification_requests')
          .where('userId', isEqualTo: widget.userId)
          .where('approvalRequestId', isEqualTo: widget.approvalRequestId)
          .where('code', isEqualTo: code)
          .where('used', isEqualTo: false)
          .get();
      
      if (querySnapshot.docs.isEmpty) {
        debugPrint('❌ [EMAIL] 유효하지 않은 코드');
        setState(() {
          _errorMessage = '유효하지 않은 코드입니다.';
          _isVerifyingCode = false;
        });
        return;
      }
      
      final verificationDoc = querySnapshot.docs.first;
      final data = verificationDoc.data();
      
      // 만료 시간 확인
      final expiresAt = (data['expiresAt'] as Timestamp).toDate();
      if (DateTime.now().isAfter(expiresAt)) {
        debugPrint('⏰ [EMAIL] 코드 만료됨');
        setState(() {
          _errorMessage = '코드가 만료되었습니다. 다시 요청하세요.';
          _isVerifyingCode = false;
        });
        return;
      }
      
      // 코드 검증 성공 - 승인 처리
      debugPrint('✅ [EMAIL] 코드 검증 성공');
      
      // 인증 코드를 사용됨으로 표시
      await verificationDoc.reference.update({'used': true});
      
      // 승인 요청 상태 업데이트
      await _firestore
          .collection('device_approval_requests')
          .doc(widget.approvalRequestId)
          .update({
        'status': 'approved',
        'approvedAt': FieldValue.serverTimestamp(),
        'approvalMethod': 'email',
      });
      
      debugPrint('✅ [EMAIL] 이메일 인증으로 승인 완료');
      
      // 성공 처리는 Firestore 리스너에서 자동으로 처리됨
      
    } catch (e) {
      debugPrint('❌ [EMAIL] 코드 검증 오류: $e');
      setState(() {
        _errorMessage = '코드 검증 실패. 다시 시도하세요.';
        _isVerifyingCode = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final screenWidth = MediaQuery.of(context).size.width;
    final isSmallScreen = screenWidth < 600;
    final contentMaxWidth = isSmallScreen ? double.infinity : 500.0;
    
    return Scaffold(
      backgroundColor: isDark ? Theme.of(context).scaffoldBackgroundColor : Colors.grey[50],
      appBar: AppBar(
        title: const Text('🔐 기기 승인 대기'),
        centerTitle: true,
        elevation: 0,
        backgroundColor: isDark ? Colors.grey[900] : const Color(0xFF2196F3),
        foregroundColor: Colors.white,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () {
            Navigator.of(context).pop();
          },
        ),
      ),
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: EdgeInsets.all(isSmallScreen ? 20.0 : 32.0),
            child: Container(
              constraints: BoxConstraints(maxWidth: contentMaxWidth),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // 타이머 표시
                  _buildTimerCard(isDark),
                  
                  SizedBox(height: isSmallScreen ? 24 : 32),
                  
                  // 앱 로고와 애니메이션
                  _buildAnimatedLogo(isDark),
                  
                  SizedBox(height: isSmallScreen ? 24 : 32),
                  
                  // 제목 및 부제목
                  Text(
                    '새 기기 로그인 감지',
                    style: TextStyle(
                      fontSize: isSmallScreen ? 24 : 28,
                      fontWeight: FontWeight.bold,
                      color: isDark ? Colors.grey[100] : Colors.black87,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  
                  SizedBox(height: isSmallScreen ? 8 : 12),
                  
                  Text(
                    '보안을 위해 기기 승인이 필요합니다',
                    style: TextStyle(
                      fontSize: isSmallScreen ? 14 : 16,
                      color: isDark ? Colors.grey[400] : Colors.grey[600],
                    ),
                    textAlign: TextAlign.center,
                  ),
                  
                  SizedBox(height: isSmallScreen ? 24 : 32),
                  
                  // 기기 정보 카드
                  _buildDeviceInfoCard(isDark, isSmallScreen),
                  
                  SizedBox(height: isSmallScreen ? 24 : 32),
                  
                  // 에러 메시지
                  if (_errorMessage != null) ...[
                    _buildErrorMessage(isDark),
                    const SizedBox(height: 16),
                  ],
                  
                  // 옵션 A: 기존 기기에서 승인 (기본 옵션)
                  if (!_isEmailOptionSelected) ...[
                    _buildOptionACard(isDark, isSmallScreen),
                    SizedBox(height: isSmallScreen ? 20 : 24),
                    _buildDividerWithText(isDark),
                    SizedBox(height: isSmallScreen ? 20 : 24),
                    _buildOptionBButton(isDark, isSmallScreen),
                  ] else ...[
                    // 옵션 B: 이메일 인증 코드 입력
                    _buildEmailVerificationCard(isDark, isSmallScreen),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  /// 타이머 카드
  Widget _buildTimerCard(bool isDark) {
    final progress = _remainingSeconds / 300;
    final isUrgent = _remainingSeconds < 60;
    
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: isUrgent
              ? [
                  isDark ? Colors.red[900]! : Colors.red[100]!,
                  isDark ? Colors.orange[900]! : Colors.orange[100]!,
                ]
              : [
                  isDark ? Colors.blue[900]! : Colors.blue[50]!,
                  isDark ? Colors.cyan[900]! : Colors.cyan[50]!,
                ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: (isUrgent ? Colors.red : Colors.blue).withAlpha(51),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Icon(
                    Icons.timer,
                    color: isUrgent
                        ? (isDark ? Colors.red[300] : Colors.red[700])
                        : (isDark ? Colors.blue[300] : Colors.blue[700]),
                    size: 20,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    '남은 시간',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: isDark ? Colors.grey[300] : Colors.grey[700],
                    ),
                  ),
                ],
              ),
              Text(
                _formatTime(_remainingSeconds),
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: isUrgent
                      ? (isDark ? Colors.red[300] : Colors.red[700])
                      : (isDark ? Colors.blue[300] : Colors.blue[700]),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: LinearProgressIndicator(
              value: progress,
              minHeight: 8,
              backgroundColor: isDark ? Colors.grey[800] : Colors.grey[300],
              valueColor: AlwaysStoppedAnimation<Color>(
                isUrgent
                    ? (isDark ? Colors.red[400]! : Colors.red[600]!)
                    : (isDark ? Colors.blue[400]! : Colors.blue[600]!),
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// 애니메이션 로고
  Widget _buildAnimatedLogo(bool isDark) {
    return ScaleTransition(
      scale: _pulseAnimation,
      child: Center(
        child: Container(
          width: 100,
          height: 100,
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [
                isDark ? Colors.blue[700]! : const Color(0xFF2196F3),
                isDark ? Colors.cyan[700]! : const Color(0xFF00BCD4),
              ],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(24),
            boxShadow: [
              BoxShadow(
                color: const Color(0xFF2196F3).withAlpha(77),
                blurRadius: 24,
                spreadRadius: 4,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(24),
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Image.asset(
                'assets/images/app_logo.png',
                fit: BoxFit.contain,
                filterQuality: FilterQuality.high,
                errorBuilder: (context, error, stackTrace) {
                  return const Icon(
                    Icons.phone_in_talk_rounded,
                    size: 50,
                    color: Colors.white,
                  );
                },
              ),
            ),
          ),
        ),
      ),
    );
  }

  /// 기기 정보 카드
  Widget _buildDeviceInfoCard(bool isDark, bool isSmallScreen) {
    return Container(
      padding: EdgeInsets.all(isSmallScreen ? 16 : 20),
      decoration: BoxDecoration(
        color: isDark ? Colors.grey[850] : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isDark 
              ? Colors.blue[700]!.withAlpha(77) 
              : Colors.blue[100]!,
          width: 2,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withAlpha(isDark ? 51 : 13),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: isDark 
                      ? Colors.blue[900]!.withAlpha(77) 
                      : Colors.blue[50],
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  Icons.devices,
                  size: 24,
                  color: isDark ? Colors.blue[300] : Colors.blue[700],
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '로그인 시도 기기',
                      style: TextStyle(
                        fontSize: 12,
                        color: isDark ? Colors.grey[500] : Colors.grey[600],
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      widget.deviceName,
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: isDark ? Colors.grey[200] : Colors.black87,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: isDark ? Colors.grey[800] : Colors.grey[50],
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(
              children: [
                Icon(
                  Icons.phone_android,
                  size: 18,
                  color: isDark ? Colors.grey[400] : Colors.grey[700],
                ),
                const SizedBox(width: 8),
                Text(
                  '플랫폼: ${widget.platform}',
                  style: TextStyle(
                    fontSize: 14,
                    color: isDark ? Colors.grey[400] : Colors.grey[700],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  /// 에러 메시지
  Widget _buildErrorMessage(bool isDark) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark ? Colors.red[900]!.withAlpha(51) : Colors.red[50],
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isDark ? Colors.red[700]!.withAlpha(77) : Colors.red[200]!,
        ),
      ),
      child: Row(
        children: [
          Icon(
            Icons.error_outline,
            color: isDark ? Colors.red[300] : Colors.red[700],
            size: 24,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              _errorMessage!,
              style: TextStyle(
                color: isDark ? Colors.red[300] : Colors.red[700],
                fontSize: 14,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// 옵션 A: 기존 기기에서 FCM 푸시 승인
  Widget _buildOptionACard(bool isDark, bool isSmallScreen) {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            isDark ? Colors.green[900]! : Colors.green[50]!,
            isDark ? Colors.teal[900]! : Colors.teal[50]!,
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isDark ? Colors.green[700]! : Colors.green[200]!,
          width: 2,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.green.withAlpha(51),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Padding(
        padding: EdgeInsets.all(isSmallScreen ? 20.0 : 24.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: isDark ? Colors.green[800] : Colors.green[100],
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(
                    Icons.phone_android,
                    color: isDark ? Colors.green[300] : Colors.green[700],
                    size: 24,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Text(
                            '옵션 A',
                            style: TextStyle(
                              fontSize: 12,
                              color: isDark ? Colors.grey[400] : Colors.grey[600],
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                            decoration: BoxDecoration(
                              color: isDark ? Colors.green[700] : Colors.green[200],
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Text(
                              '추천',
                              style: TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.bold,
                                color: isDark ? Colors.grey[900] : Colors.green[900],
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '기존 기기에서 승인',
                        style: TextStyle(
                          fontSize: isSmallScreen ? 16 : 18,
                          fontWeight: FontWeight.bold,
                          color: isDark ? Colors.green[300] : Colors.green[800],
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            
            const SizedBox(height: 20),
            
            // 로딩 인디케이터
            if (_isWaitingForApproval) ...[
              Center(
                child: Column(
                  children: [
                    SizedBox(
                      width: 60,
                      height: 60,
                      child: CircularProgressIndicator(
                        strokeWidth: 6,
                        valueColor: AlwaysStoppedAnimation<Color>(
                          isDark ? Colors.green[400]! : Colors.green[600]!,
                        ),
                      ),
                    ),
                    const SizedBox(height: 20),
                    Text(
                      '기존 기기로 푸시 알림을 전송했습니다',
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                        color: isDark ? Colors.grey[300] : Colors.grey[800],
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      '기존 기기에서 "승인" 버튼을 눌러주세요',
                      style: TextStyle(
                        fontSize: 13,
                        color: isDark ? Colors.grey[400] : Colors.grey[600],
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),
            ],
            
            // 특징 안내
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: isDark 
                    ? Colors.green[800]!.withAlpha(77) 
                    : Colors.green[100],
                borderRadius: BorderRadius.circular(12),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildFeatureRow(Icons.flash_on, '즉시 승인', '푸시 알림으로 빠른 인증', isDark),
                  const SizedBox(height: 8),
                  _buildFeatureRow(Icons.verified_user, '안전한 인증', '기존 기기 확인 필요', isDark),
                  const SizedBox(height: 8),
                  _buildFeatureRow(Icons.no_accounts, '추가 비용 없음', '무료로 간편하게', isDark),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// 특징 행
  Widget _buildFeatureRow(IconData icon, String title, String subtitle, bool isDark) {
    return Row(
      children: [
        Icon(
          icon,
          color: isDark ? Colors.green[300] : Colors.green[700],
          size: 20,
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.bold,
                  color: isDark ? Colors.green[200] : Colors.green[800],
                ),
              ),
              Text(
                subtitle,
                style: TextStyle(
                  fontSize: 11,
                  color: isDark ? Colors.grey[400] : Colors.grey[700],
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  /// 구분선
  Widget _buildDividerWithText(bool isDark) {
    return Row(
      children: [
        Expanded(
          child: Divider(
            color: isDark ? Colors.grey[700] : Colors.grey[300],
            thickness: 1,
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Text(
            '또는',
            style: TextStyle(
              fontSize: 14,
              color: isDark ? Colors.grey[500] : Colors.grey[600],
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
        Expanded(
          child: Divider(
            color: isDark ? Colors.grey[700] : Colors.grey[300],
            thickness: 1,
          ),
        ),
      ],
    );
  }

  /// 옵션 B 버튼: 이메일 인증 코드 받기
  Widget _buildOptionBButton(bool isDark, bool isSmallScreen) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          '기존 기기를 사용할 수 없나요?',
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            color: isDark ? Colors.grey[400] : Colors.grey[700],
          ),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 12),
        Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [
                isDark ? Colors.blue[900]! : Colors.blue[50]!,
                isDark ? Colors.indigo[900]! : Colors.indigo[50]!,
              ],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: isDark ? Colors.blue[700]! : Colors.blue[200]!,
              width: 2,
            ),
          ),
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: _requestEmailVerificationCode,
              borderRadius: BorderRadius.circular(12),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.email,
                      color: isDark ? Colors.blue[300] : Colors.blue[700],
                      size: 24,
                    ),
                    const SizedBox(width: 12),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '옵션 B: 이메일 인증',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: isDark ? Colors.blue[300] : Colors.blue[700],
                          ),
                        ),
                        Text(
                          '인증 코드를 이메일로 받기',
                          style: TextStyle(
                            fontSize: 12,
                            color: isDark ? Colors.grey[400] : Colors.grey[600],
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
        const SizedBox(height: 8),
        Text(
          '※ 이메일 수신까지 1-3분 소요될 수 있습니다',
          style: TextStyle(
            fontSize: 11,
            color: isDark ? Colors.grey[500] : Colors.grey[500],
          ),
          textAlign: TextAlign.center,
        ),
      ],
    );
  }

  /// 옵션 B: 이메일 인증 코드 입력 카드
  Widget _buildEmailVerificationCard(bool isDark, bool isSmallScreen) {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            isDark ? Colors.blue[900]! : Colors.blue[50]!,
            isDark ? Colors.purple[900]! : Colors.purple[50]!,
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isDark ? Colors.blue[700]! : Colors.blue[200]!,
          width: 2,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.blue.withAlpha(51),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Padding(
        padding: EdgeInsets.all(isSmallScreen ? 20.0 : 24.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: isDark ? Colors.blue[800] : Colors.blue[100],
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(
                    Icons.email,
                    color: isDark ? Colors.blue[300] : Colors.blue[700],
                    size: 24,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '옵션 B',
                        style: TextStyle(
                          fontSize: 12,
                          color: isDark ? Colors.grey[400] : Colors.grey[600],
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '이메일 인증 코드',
                        style: TextStyle(
                          fontSize: isSmallScreen ? 16 : 18,
                          fontWeight: FontWeight.bold,
                          color: isDark ? Colors.blue[300] : Colors.blue[800],
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            
            const SizedBox(height: 20),
            
            Text(
              '이메일로 전송된 6자리 코드를 입력하세요',
              style: TextStyle(
                fontSize: 14,
                color: isDark ? Colors.grey[300] : Colors.grey[700],
              ),
            ),
            
            const SizedBox(height: 20),
            
            // 코드 입력 필드
            Container(
              decoration: BoxDecoration(
                color: isDark ? Colors.grey[850] : Colors.white,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: isDark ? Colors.blue[700]! : Colors.blue[300]!,
                  width: 2,
                ),
              ),
              child: TextField(
                controller: _codeController,
                keyboardType: TextInputType.number,
                maxLength: 6,
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 32,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 12,
                  color: isDark ? Colors.grey[200] : Colors.black87,
                ),
                decoration: InputDecoration(
                  hintText: '000000',
                  hintStyle: TextStyle(
                    color: isDark ? Colors.grey[700] : Colors.grey[300],
                    letterSpacing: 12,
                  ),
                  counterText: '',
                  border: InputBorder.none,
                  contentPadding: const EdgeInsets.symmetric(vertical: 20),
                ),
                onChanged: (value) {
                  if (value.length == 6) {
                    // 6자리 입력 완료 시 자동 검증
                    _verifyEmailCode();
                  }
                },
              ),
            ),
            
            const SizedBox(height: 20),
            
            // 검증 버튼
            SizedBox(
              width: double.infinity,
              height: 56,
              child: ElevatedButton(
                onPressed: _isVerifyingCode ? null : _verifyEmailCode,
                style: ElevatedButton.styleFrom(
                  backgroundColor: isDark ? Colors.blue[700] : const Color(0xFF2196F3),
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  elevation: 4,
                ),
                child: _isVerifyingCode
                    ? const SizedBox(
                        height: 24,
                        width: 24,
                        child: CircularProgressIndicator(
                          strokeWidth: 3,
                          valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                        ),
                      )
                    : const Text(
                        '코드 확인',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
              ),
            ),
            
            const SizedBox(height: 16),
            
            // 뒤로가기 버튼
            TextButton.icon(
              onPressed: () {
                setState(() {
                  _isEmailOptionSelected = false;
                  _codeController.clear();
                  _errorMessage = null;
                });
              },
              icon: Icon(
                Icons.arrow_back,
                size: 18,
                color: isDark ? Colors.blue[300] : Colors.blue[700],
              ),
              label: Text(
                '푸시 알림 승인으로 돌아가기',
                style: TextStyle(
                  color: isDark ? Colors.blue[300] : Colors.blue[700],
                ),
              ),
              style: TextButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 12),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
