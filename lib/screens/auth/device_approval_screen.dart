import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'dart:async';

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

class _DeviceApprovalScreenState extends State<DeviceApprovalScreen> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  StreamSubscription<DocumentSnapshot>? _approvalSubscription;
  
  bool _isWaitingForApproval = true;
  bool _isEmailOptionSelected = false;
  bool _isVerifyingCode = false;
  
  final TextEditingController _codeController = TextEditingController();
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _startListeningForApproval();
  }

  @override
  void dispose() {
    _approvalSubscription?.cancel();
    _codeController.dispose();
    super.dispose();
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
  void _handleApprovalSuccess() {
    if (!mounted) return;
    
    setState(() {
      _isWaitingForApproval = false;
    });
    
    // 성공 스낵바
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('✅ 기기 승인 완료!'),
        backgroundColor: Colors.green,
        duration: Duration(seconds: 2),
      ),
    );
    
    // 메인 화면으로 이동 (Navigator를 완전히 교체)
    Navigator.of(context).pushNamedAndRemoveUntil('/', (route) => false);
  }

  /// 승인 거부 처리
  void _handleApprovalRejected() {
    if (!mounted) return;
    
    setState(() {
      _isWaitingForApproval = false;
      _errorMessage = '기존 기기에서 로그인을 거부했습니다.';
    });
    
    // 거부 다이얼로그 표시
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.block, color: Colors.red, size: 28),
            SizedBox(width: 12),
            Text('로그인 거부됨'),
          ],
        ),
        content: const Text(
          '기존 기기에서 로그인을 거부했습니다.\n로그인 화면으로 돌아갑니다.',
          style: TextStyle(fontSize: 14),
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.of(context).pop(); // 다이얼로그 닫기
              Navigator.of(context).pop(); // DeviceApprovalScreen 닫기
            },
            child: const Text('확인'),
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
    
    // 만료 다이얼로그 표시
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.access_time, color: Colors.orange, size: 28),
            SizedBox(width: 12),
            Text('승인 요청 만료'),
          ],
        ),
        content: const Text(
          '5분이 경과하여 승인 요청이 만료되었습니다.\n다시 로그인해주세요.',
          style: TextStyle(fontSize: 14),
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.of(context).pop(); // 다이얼로그 닫기
              Navigator.of(context).pop(); // DeviceApprovalScreen 닫기
            },
            child: const Text('확인'),
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
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('📧 이메일로 인증 코드를 전송했습니다 (1-3분 소요)'),
            backgroundColor: Colors.blue,
            duration: Duration(seconds: 3),
          ),
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
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: const Text('🔐 기기 승인 대기'),
        backgroundColor: Colors.blue,
        foregroundColor: Colors.white,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () {
            Navigator.of(context).pop();
          },
        ),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // 상단 아이콘 및 제목
              const Icon(
                Icons.security,
                size: 80,
                color: Colors.blue,
              ),
              const SizedBox(height: 24),
              
              const Text(
                '새 기기 로그인 감지',
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                ),
                textAlign: TextAlign.center,
              ),
              
              const SizedBox(height: 16),
              
              // 기기 정보 카드
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.blue.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: Colors.blue.withOpacity(0.3),
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Icon(Icons.devices, size: 20, color: Colors.blue),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            '기기: ${widget.deviceName}',
                            style: const TextStyle(fontSize: 14),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        const Icon(Icons.phone_android, size: 20, color: Colors.blue),
                        const SizedBox(width: 8),
                        Text(
                          '플랫폼: ${widget.platform}',
                          style: const TextStyle(fontSize: 14),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              
              const SizedBox(height: 32),
              
              // 에러 메시지
              if (_errorMessage != null)
                Container(
                  padding: const EdgeInsets.all(12),
                  margin: const EdgeInsets.only(bottom: 16),
                  decoration: BoxDecoration(
                    color: Colors.red.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.red.withOpacity(0.3)),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.error_outline, color: Colors.red, size: 20),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          _errorMessage!,
                          style: const TextStyle(color: Colors.red, fontSize: 12),
                        ),
                      ),
                    ],
                  ),
                ),
              
              // 옵션 A: 기존 기기에서 승인 (기본 옵션)
              if (!_isEmailOptionSelected) ...[
                _buildOptionACard(),
                const SizedBox(height: 16),
                const Divider(),
                const SizedBox(height: 16),
                _buildOptionBButton(),
              ] else ...[
                // 옵션 B: 이메일 인증 코드 입력
                _buildEmailVerificationCard(),
              ],
            ],
          ),
        ),
      ),
    );
  }

  /// 옵션 A: 기존 기기에서 FCM 푸시 승인
  Widget _buildOptionACard() {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: Colors.blue.withOpacity(0.3)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Row(
              children: [
                Icon(Icons.phone_android, color: Colors.blue, size: 28),
                SizedBox(width: 12),
                Text(
                  '옵션 A: 기존 기기에서 승인 ✅',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: Colors.blue,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            
            // 로딩 인디케이터
            if (_isWaitingForApproval) ...[
              const Center(
                child: CircularProgressIndicator(),
              ),
              const SizedBox(height: 16),
              const Text(
                '기존 기기로 알림을 전송했습니다.\n기존 기기에서 "승인" 버튼을 클릭하세요.',
                style: TextStyle(fontSize: 14),
                textAlign: TextAlign.center,
              ),
            ],
            
            const SizedBox(height: 12),
            
            // 특징 안내
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.green.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(Icons.check_circle, color: Colors.green, size: 16),
                      SizedBox(width: 8),
                      Text(
                        '즉시 승인 (푸시 알림)',
                        style: TextStyle(fontSize: 12, color: Colors.green),
                      ),
                    ],
                  ),
                  SizedBox(height: 4),
                  Row(
                    children: [
                      Icon(Icons.check_circle, color: Colors.green, size: 16),
                      SizedBox(width: 8),
                      Text(
                        '추가 비용 없음',
                        style: TextStyle(fontSize: 12, color: Colors.green),
                      ),
                    ],
                  ),
                  SizedBox(height: 4),
                  Row(
                    children: [
                      Icon(Icons.check_circle, color: Colors.green, size: 16),
                      SizedBox(width: 8),
                      Text(
                        '간편하고 빠른 인증',
                        style: TextStyle(fontSize: 12, color: Colors.green),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// 옵션 B 버튼: 이메일 인증 코드 받기
  Widget _buildOptionBButton() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Text(
          '기존 기기를 사용할 수 없나요?',
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.bold,
            color: Colors.grey,
          ),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 12),
        OutlinedButton.icon(
          onPressed: _requestEmailVerificationCode,
          icon: const Icon(Icons.email),
          label: const Text('옵션 B: 이메일 인증 코드 받기'),
          style: OutlinedButton.styleFrom(
            padding: const EdgeInsets.all(16),
            side: const BorderSide(color: Colors.blue),
          ),
        ),
        const SizedBox(height: 8),
        const Text(
          '이메일로 6자리 코드를 받아 인증할 수 있습니다.\n(1-3분 소요)',
          style: TextStyle(fontSize: 12, color: Colors.grey),
          textAlign: TextAlign.center,
        ),
      ],
    );
  }

  /// 옵션 B: 이메일 인증 코드 입력 카드
  Widget _buildEmailVerificationCard() {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: Colors.blue.withOpacity(0.3)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Row(
              children: [
                Icon(Icons.email, color: Colors.blue, size: 28),
                SizedBox(width: 12),
                Text(
                  '옵션 B: 이메일 인증',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: Colors.blue,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            
            const Text(
              '이메일로 전송된 6자리 코드를 입력하세요.',
              style: TextStyle(fontSize: 14),
            ),
            
            const SizedBox(height: 16),
            
            // 코드 입력 필드
            TextField(
              controller: _codeController,
              keyboardType: TextInputType.number,
              maxLength: 6,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                letterSpacing: 8,
              ),
              decoration: InputDecoration(
                hintText: '000000',
                counterText: '',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: const BorderSide(color: Colors.blue, width: 2),
                ),
              ),
              onChanged: (value) {
                if (value.length == 6) {
                  // 6자리 입력 완료 시 자동 검증
                  _verifyEmailCode();
                }
              },
            ),
            
            const SizedBox(height: 16),
            
            // 검증 버튼
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _isVerifyingCode ? null : _verifyEmailCode,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.blue,
                  padding: const EdgeInsets.all(16),
                ),
                child: _isVerifyingCode
                    ? const SizedBox(
                        height: 20,
                        width: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                        ),
                      )
                    : const Text(
                        '코드 확인',
                        style: TextStyle(fontSize: 16, color: Colors.white),
                      ),
              ),
            ),
            
            const SizedBox(height: 16),
            
            // 뒤로가기 버튼
            TextButton(
              onPressed: () {
                setState(() {
                  _isEmailOptionSelected = false;
                  _codeController.clear();
                  _errorMessage = null;
                });
              },
              child: const Text('← 푸시 알림 승인으로 돌아가기'),
            ),
          ],
        ),
      ),
    );
  }
}
