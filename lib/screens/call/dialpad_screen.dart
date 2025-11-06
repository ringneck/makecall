import 'package:flutter/material.dart';
import 'dart:io' show Platform;
import 'package:flutter/foundation.dart' show kIsWeb, kDebugMode, debugPrint;
import 'package:provider/provider.dart';
import '../../widgets/call_method_dialog.dart';
import '../../services/auth_service.dart';
import '../../services/api_service.dart';
import '../../services/database_service.dart';
import '../../models/call_history_model.dart';
import '../../providers/selected_extension_provider.dart';

class DialpadScreen extends StatefulWidget {
  final VoidCallback? onClickToCallSuccess; // 클릭투콜 성공 콜백
  
  const DialpadScreen({
    super.key,
    this.onClickToCallSuccess,
  });

  @override
  State<DialpadScreen> createState() => _DialpadScreenState();
}

class _DialpadScreenState extends State<DialpadScreen> {
  String _phoneNumber = '';
  final DatabaseService _databaseService = DatabaseService();

  // 플랫폼 감지
  bool get _isAndroid => !kIsWeb && Platform.isAndroid;
  bool get _isIOS => !kIsWeb && Platform.isIOS;

  void _onKeyPressed(String key) {
    setState(() {
      _phoneNumber += key;
    });
  }

  void _onBackspace() {
    if (_phoneNumber.isNotEmpty) {
      setState(() {
        _phoneNumber = _phoneNumber.substring(0, _phoneNumber.length - 1);
      });
    }
  }

  // 기능번호 판별 (키패드 전용)
  bool _isFeatureCode(String phoneNumber) {
    // *로 시작하는 번호는 기능번호로 판별
    return phoneNumber.startsWith('*');
  }

  void _onCall() {
    if (_phoneNumber.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('전화번호를 입력해주세요')),
      );
      return;
    }

    // 기능번호는 다이얼로그 없이 바로 Click to Call
    if (_isFeatureCode(_phoneNumber)) {
      if (kDebugMode) {
        debugPrint('🌟 키패드 기능번호 감지: $_phoneNumber');
      }
      _handleFeatureCodeCall(_phoneNumber);
      return;
    }

    // 5자리 이하 숫자만 있는 단말번호는 자동으로 클릭투콜 실행 (다이얼로그 없음)
    final cleanNumber = _phoneNumber.replaceAll(RegExp(r'[^0-9]'), '');
    if (cleanNumber.length > 0 && cleanNumber.length <= 5 && cleanNumber == _phoneNumber) {
      if (kDebugMode) {
        debugPrint('🔥 5자리 이하 내선번호 감지: $_phoneNumber');
        debugPrint('📞 자동으로 클릭투콜 실행 (다이얼로그 건너뛰기)');
      }
      _handleFeatureCodeCall(_phoneNumber);
      return;
    }

    // 일반 전화번호는 발신 방법 선택 다이얼로그 표시
    showDialog(
      context: context,
      builder: (context) => CallMethodDialog(
        phoneNumber: _phoneNumber, 
        autoCallShortExtension: false,
        onClickToCallSuccess: widget.onClickToCallSuccess, // 부모에게 콜백 전달
      ),
    );
  }

  // 기능번호 자동 발신 (Click to Call API 직접 호출)
  Future<void> _handleFeatureCodeCall(String phoneNumber) async {
    try {
      final authService = context.read<AuthService>();
      final userId = authService.currentUser?.uid ?? '';
      final userModel = authService.currentUserModel;

      if (userModel?.companyId == null || userModel?.appKey == null) {
        throw Exception('API 인증 정보가 설정되지 않았습니다. 내 정보에서 설정해주세요.');
      }

      if (userModel?.apiBaseUrl == null) {
        throw Exception('API 서버 주소가 설정되지 않았습니다. 내 정보 > API 설정에서 설정해주세요.');
      }

      // 홈 탭에서 선택된 단말번호 가져오기 (실시간 반영)
      final selectedExtension = context.read<SelectedExtensionProvider>().selectedExtension;
      
      if (selectedExtension == null) {
        throw Exception('선택된 단말번호가 없습니다.\n왼쪽 상단 프로필에서 단말번호를 등록해주세요.');
      }

      if (kDebugMode) {
        debugPrint('🌟 키패드 기능번호 자동 발신 시작 (다이얼로그 건너뛰기)');
        debugPrint('📞 선택된 단말번호: ${selectedExtension.extension}');
        debugPrint('👤 단말 이름: ${selectedExtension.name}');
        debugPrint('🔑 COS ID: ${selectedExtension.classOfServicesId}');
        debugPrint('🎯 기능번호: $phoneNumber');
      }

      // CID 설정: 고정값 사용
      String cidName = '클릭투콜';                // 고정값: "클릭투콜"
      String cidNumber = phoneNumber;      // callee 값 사용

      if (kDebugMode) {
        debugPrint('📞 CID Name: $cidName (고정값)');
        debugPrint('📞 CID Number: $cidNumber (callee 값)');
      }

      // 로딩 표시
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Row(
              children: [
                SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                  ),
                ),
                SizedBox(width: 16),
                Text('기능번호 발신 중...'),
              ],
            ),
            duration: Duration(seconds: 2),
          ),
        );
      }

      // API 서비스 생성 (동적 API URL 사용)
      // apiHttpPort가 3501이면 HTTPS 사용, 3500이면 HTTP 사용
      final useHttps = (userModel!.apiHttpPort ?? 3500) == 3501;
      
      final apiService = ApiService(
        baseUrl: userModel.getApiUrl(useHttps: useHttps),
        companyId: userModel.companyId,
        appKey: userModel.appKey,
      );

      // Click to Call API 호출
      final result = await apiService.clickToCall(
        caller: selectedExtension.extension, // 선택된 단말번호 사용
        callee: phoneNumber,
        cosId: selectedExtension.classOfServicesId, // 선택된 COS ID 사용
        cidName: cidName,
        cidNumber: cidNumber,
        accountCode: userModel.phoneNumber ?? '',
      );

      if (kDebugMode) {
        debugPrint('✅ 키패드 기능번호 Click to Call 성공: $result');
      }

      // 통화 기록 저장
      await _databaseService.addCallHistory(
        CallHistoryModel(
          id: '',
          userId: userId,
          phoneNumber: phoneNumber,
          callType: CallType.outgoing,
          callMethod: CallMethod.extension,
          callTime: DateTime.now(),
          mainNumberUsed: cidNumber,
          extensionUsed: selectedExtension.extension,
        ),
      );

      if (mounted) {
        ScaffoldMessenger.of(context).clearSnackBars();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  '🌟 기능번호 발신 완료',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 4),
                Text('단말: ${selectedExtension.name.isEmpty ? selectedExtension.extension : selectedExtension.name}'),
                Text('기능번호: $phoneNumber'),
              ],
            ),
            backgroundColor: Colors.orange,
            duration: const Duration(seconds: 3),
            behavior: SnackBarBehavior.floating,
          ),
        );
        
        // 발신 후 번호 초기화
        setState(() {
          _phoneNumber = '';
        });
        
        // 🔄 기능번호 발신 성공 시 콜백 호출 (최근통화 탭으로 전환)
        widget.onClickToCallSuccess?.call();
        
        if (kDebugMode) {
          debugPrint('✅ 키패드 기능번호 발신 성공 → 최근통화 탭 전환 콜백 호출');
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).clearSnackBars();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('기능번호 발신 실패: $e'),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 4),
          ),
        );
      }
      
      if (kDebugMode) {
        debugPrint('❌ 키패드 기능번호 발신 오류: $e');
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: OrientationBuilder(
          builder: (context, orientation) {
            if (orientation == Orientation.landscape) {
              // 랜드스케이프 모드: 가로 레이아웃
              return _buildLandscapeLayout();
            } else {
              // 포트레이트 모드: 세로 레이아웃
              return _buildPortraitLayout();
            }
          },
        ),
      ),
    );
  }

  // 세로 모드 레이아웃
  Widget _buildPortraitLayout() {
    final bool isIOS = _isIOS;
    
    return LayoutBuilder(
      builder: (context, constraints) {
        // 사용 가능한 높이 계산
        final availableHeight = constraints.maxHeight;
        
        // iOS 스타일: 더 많은 여백, 더 큰 버튼
        final phoneNumberHeight = isIOS ? 100.0 : 80.0;
        final callButtonHeight = isIOS ? 120.0 : 100.0;
        final keypadPadding = isIOS ? 24.0 : 20.0;
        final keySpacing = isIOS ? 16.0 : 12.0;
        
        return Column(
          children: [
            // 전화번호 표시 영역
            SizedBox(
              height: phoneNumberHeight,
              child: Padding(
                padding: EdgeInsets.symmetric(horizontal: keypadPadding),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        _phoneNumber.isEmpty ? '' : _phoneNumber,
                        style: TextStyle(
                          fontSize: isIOS ? 36 : 32,
                          fontWeight: FontWeight.w300,
                          letterSpacing: isIOS ? 0.5 : 1,
                          color: Colors.black87,
                        ),
                        textAlign: TextAlign.center,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    if (_phoneNumber.isNotEmpty)
                      IconButton(
                        icon: Icon(
                          Icons.backspace_outlined,
                          color: isIOS ? Colors.grey[600] : Colors.grey[700],
                        ),
                        iconSize: isIOS ? 26 : 28,
                        onPressed: _onBackspace,
                      ),
                  ],
                ),
              ),
            ),

            // 키패드 영역 (Expanded로 남은 공간 채우기)
            Expanded(
              child: Center(
                child: ConstrainedBox(
                  constraints: BoxConstraints(
                    maxWidth: isIOS ? 350 : 400,
                    maxHeight: availableHeight - phoneNumberHeight - callButtonHeight,
                  ),
                  child: Padding(
                    padding: EdgeInsets.symmetric(
                      horizontal: keypadPadding,
                      vertical: isIOS ? 12 : 10,
                    ),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        _buildKeypadRow(['1', '2', '3'], ['', 'ABC', 'DEF']),
                        SizedBox(height: keySpacing),
                        _buildKeypadRow(['4', '5', '6'], ['GHI', 'JKL', 'MNO']),
                        SizedBox(height: keySpacing),
                        _buildKeypadRow(['7', '8', '9'], ['PQRS', 'TUV', 'WXYZ']),
                        SizedBox(height: keySpacing),
                        _buildKeypadRow(['*', '0', '#'], ['', '+', '']),
                      ],
                    ),
                  ),
                ),
              ),
            ),

            // 통화 버튼 영역
            SizedBox(
              height: callButtonHeight,
              child: Center(
                child: Padding(
                  padding: EdgeInsets.only(
                    bottom: isIOS ? 32 : 16,
                    top: isIOS ? 16 : 16,
                  ),
                  child: _buildCallButton(),
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  // 가로 모드 레이아웃
  Widget _buildLandscapeLayout() {
    return Row(
      children: [
        // 왼쪽: 전화번호 표시 및 통화 버튼
        Expanded(
          flex: 2,
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // 전화번호 표시
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Flexible(
                      child: Text(
                        _phoneNumber.isEmpty ? '' : _phoneNumber,
                        style: const TextStyle(
                          fontSize: 28,
                          fontWeight: FontWeight.w300,
                          letterSpacing: 1,
                          color: Colors.black87,
                        ),
                        textAlign: TextAlign.center,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    if (_phoneNumber.isNotEmpty) ...[
                      const SizedBox(width: 8),
                      IconButton(
                        icon: Icon(Icons.backspace_outlined, color: Colors.grey[600]),
                        iconSize: 24,
                        onPressed: _onBackspace,
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(height: 20),
              // 통화 버튼
              _buildCallButton(),
            ],
          ),
        ),

        // 오른쪽: 키패드
        Expanded(
          flex: 3,
          child: Center(
            child: SingleChildScrollView(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 400),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      _buildKeypadRow(['1', '2', '3'], ['', 'ABC', 'DEF']),
                      const SizedBox(height: 8),
                      _buildKeypadRow(['4', '5', '6'], ['GHI', 'JKL', 'MNO']),
                      const SizedBox(height: 8),
                      _buildKeypadRow(['7', '8', '9'], ['PQRS', 'TUV', 'WXYZ']),
                      const SizedBox(height: 8),
                      _buildKeypadRow(['*', '0', '#'], ['', '+', '']),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildKeypadRow(List<String> numbers, List<String> letters) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      children: List.generate(3, (index) {
        return Expanded(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8),
            child: _buildKey(numbers[index], letters[index]),
          ),
        );
      }),
    );
  }

  Widget _buildKey(String number, String letters) {
    // Android/iOS 네이티브 스타일 구분
    final bool isAndroidStyle = _isAndroid || kIsWeb; // Web은 Android 스타일 사용
    final bool isIOS = _isIOS;
    
    return LayoutBuilder(
      builder: (context, constraints) {
        // 랜드스케이프 모드에서는 더 작은 크기 사용
        final isLandscape = MediaQuery.of(context).orientation == Orientation.landscape;
        
        // iOS: 더 큰 버튼 크기
        double size;
        if (isLandscape) {
          size = constraints.maxWidth.clamp(50.0, 70.0);
        } else if (isIOS) {
          // iOS: 최대 75px로 제한하여 화면에 맞춤
          size = constraints.maxWidth.clamp(60.0, 75.0);
        } else {
          size = constraints.maxWidth;
        }
        
        return SizedBox(
          width: size,
          height: size,
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: () => _onKeyPressed(number),
              customBorder: const CircleBorder(),
              splashColor: isAndroidStyle 
                  ? Colors.grey.withOpacity(0.2)
                  : Colors.blue.withOpacity(0.1),
              highlightColor: isAndroidStyle
                  ? Colors.grey.withOpacity(0.1)
                  : Colors.blue.withOpacity(0.05),
              child: Container(
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  // Android: 테두리 없음, iOS: 얇은 테두리
                  border: isAndroidStyle
                      ? null
                      : Border.all(
                          color: Colors.grey.withOpacity(0.3),
                          width: 1,
                        ),
                  // iOS 스타일 배경
                  color: isIOS ? Colors.grey.withOpacity(0.08) : null,
                ),
                child: Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      // 숫자
                      Text(
                        number,
                        style: TextStyle(
                          fontSize: isLandscape 
                              ? 24 
                              : (isIOS ? 38 : (isAndroidStyle ? 32 : 36)),
                          fontWeight: isIOS 
                              ? FontWeight.w200 
                              : (isAndroidStyle ? FontWeight.w300 : FontWeight.w200),
                          color: Colors.black87,
                          height: 1.0,
                        ),
                      ),
                      // 문자
                      if (letters.isNotEmpty)
                        Padding(
                          padding: EdgeInsets.only(top: isIOS ? 3 : 2),
                          child: Text(
                            letters,
                            style: TextStyle(
                              fontSize: isLandscape 
                                  ? 8 
                                  : (isIOS ? 10 : (isAndroidStyle ? 10 : 9)),
                              fontWeight: FontWeight.w500,
                              color: Colors.grey[600],
                              letterSpacing: isIOS ? 1.0 : (isAndroidStyle ? 1.2 : 0.8),
                              height: 1.0,
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildCallButton() {
    final bool isAndroidStyle = _isAndroid || kIsWeb;
    final bool isIOS = _isIOS;
    
    // iOS: 더 큰 버튼
    final buttonSize = isIOS ? 72.0 : 64.0;
    final iconSize = isIOS ? 34.0 : (isAndroidStyle ? 32.0 : 30.0);
    
    return Material(
      elevation: isAndroidStyle ? 4 : 1,
      shape: const CircleBorder(),
      color: isAndroidStyle ? const Color(0xFF4CAF50) : const Color(0xFF34C759),
      child: InkWell(
        onTap: _onCall,
        customBorder: const CircleBorder(),
        child: Container(
          width: buttonSize,
          height: buttonSize,
          decoration: const BoxDecoration(
            shape: BoxShape.circle,
          ),
          child: Icon(
            Icons.phone,
            color: Colors.white,
            size: iconSize,
          ),
        ),
      ),
    );
  }
}
