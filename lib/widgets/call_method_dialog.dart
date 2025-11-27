import 'package:flutter/material.dart';
import '../utils/dialog_utils.dart';
import 'package:flutter/foundation.dart';
import 'package:provider/provider.dart';
import '../services/auth_service.dart';
import '../services/database_service.dart';
import '../services/call_service.dart';
import '../services/api_service.dart';
import '../services/dcmiws_service.dart';
import '../models/call_history_model.dart';
import '../models/call_forward_info_model.dart';
import '../providers/selected_extension_provider.dart';
import '../theme/call_theme_extension.dart';

class CallMethodDialog extends StatefulWidget {
  final String phoneNumber;
  final bool autoCallShortExtension; // 5자리 이하 자동 발신 옵션
  final VoidCallback? onClickToCallSuccess; // 클릭투콜 성공 콜백

  const CallMethodDialog({
    super.key,
    required this.phoneNumber,
    this.autoCallShortExtension = true, // 기본값: 자동 발신
    this.onClickToCallSuccess, // 클릭투콜 성공 시 호출될 콜백
  });

  @override
  State<CallMethodDialog> createState() => _CallMethodDialogState();
}

class _CallMethodDialogState extends State<CallMethodDialog> {
  final DatabaseService _databaseService = DatabaseService();
  final CallService _callService = CallService();
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    // 5자리 이하 숫자인 경우 자동으로 클릭투콜 실행
    if (widget.autoCallShortExtension) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _checkAndAutoCall();
      });
    }
  }



  // 5자리 이하 숫자인지 확인하고 자동 발신
  Future<void> _checkAndAutoCall() async {
    final phoneNumber = widget.phoneNumber.replaceAll(RegExp(r'[^0-9]'), ''); // 숫자만 추출
    
    // 5자리 이하 숫자이고, 숫자로만 구성된 경우
    if (phoneNumber.length > 0 && phoneNumber.length <= 5 && phoneNumber == widget.phoneNumber) {
      if (kDebugMode) {
        debugPrint('🔥 5자리 이하 내선번호 감지: $phoneNumber');
        debugPrint('📞 자동으로 클릭투콜 실행');
      }
      
      // 자동으로 단말 통화 실행
      await _handleExtensionCall();
    }
  }

  @override
  Widget build(BuildContext context) {
    final callTheme = CallThemeColors(context);
    
    return AlertDialog(
      title: const Text('발신 방법 선택'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            widget.phoneNumber,
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: callTheme.outgoingCallColor,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 24),
          _buildCallMethodButton(
            title: '로컬 통화',
            subtitle: '단말기 기본 전화 앱 사용',
            icon: Icons.phone,
            onTap: () => _handleLocalCall(),
          ),
          const Divider(),
          // 로컬 앱 통화 기능 - 주석 처리됨
          // _buildCallMethodButton(
          //   title: '로컬 앱 통화',
          //   subtitle: '앱 내부 다이얼러 사용',
          //   icon: Icons.phone_in_talk,
          //   onTap: () => _handleLocalAppCall(),
          // ),
          // const Divider(),
          _buildCallMethodButton(
            title: '단말 통화',
            subtitle: 'Click to Call API 사용',
            icon: Icons.phone_forwarded,
            onTap: () => _handleExtensionCall(),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: _isLoading ? null : () => Navigator.pop(context),
          child: const Text('취소'),
        ),
      ],
    );
  }

  Widget _buildCallMethodButton({
    required String title,
    required String subtitle,
    required IconData icon,
    required VoidCallback onTap,
  }) {
    final callTheme = CallThemeColors(context);
    
    return ListTile(
      leading: Icon(icon, color: callTheme.outgoingCallColor),
      title: Text(title),
      subtitle: Text(subtitle, style: const TextStyle(fontSize: 12)),
      onTap: _isLoading ? null : onTap,
      enabled: !_isLoading,
    );
  }

  Future<void> _handleLocalCall() async {
    setState(() => _isLoading = true);

    try {
      final userId = context.read<AuthService>().currentUser?.uid ?? '';
      final success = await _callService.makeLocalCall(widget.phoneNumber, userId);

      if (mounted && Navigator.canPop(context)) {
        Navigator.pop(context);
        // Navigator.pop 후 약간의 딜레이를 주어 안전하게 새 다이얼로그 표시
        await Future.delayed(const Duration(milliseconds: 100));
        
        if (mounted) {
          if (success) {
            await DialogUtils.showInfo(
              context,
              '전화를 거는 중입니다...',
              duration: const Duration(seconds: 1),
            );
          } else {
            await DialogUtils.showError(
              context,
              '전화를 걸 수 없습니다',
            );
          }
        }
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  // 로컬 앱 통화 기능 - 주석 처리됨
  // Future<void> _handleLocalAppCall() async {
  //   setState(() => _isLoading = true);
  //
  //   try {
  //     final userId = context.read<AuthService>().currentUser?.uid ?? '';
  //
  //     // 대표번호 가져오기
  //     final mainNumbers = await _databaseService
  //         .getUserMainNumbers(userId)
  //         .first;
  //
  //     final defaultMainNumber = mainNumbers.firstWhere(
  //       (mn) => mn.isDefault,
  //       orElse: () => mainNumbers.isNotEmpty ? mainNumbers.first : throw Exception('대표번호 없음'),
  //     );
  //
  //     final success = await _callService.makeLocalAppCall(
  //       widget.phoneNumber,
  //       userId,
  //       defaultMainNumber,
  //     );
  //
  //     if (mounted) {
  //       Navigator.pop(context);
  //       if (success) {
  //         ScaffoldMessenger.of(context).showSnackBar(
  //           const SnackBar(content: Text('전화를 거는 중입니다...')),
  //         );
  //       } else {
  //         ScaffoldMessenger.of(context).showSnackBar(
  //           const SnackBar(
  //             content: Text('전화를 걸 수 없습니다'),
  //             backgroundColor: Colors.red,
  //           ),
  //         );
  //       }
  //     }
  //   } catch (e) {
  //     if (mounted) {
  //       ScaffoldMessenger.of(context).showSnackBar(
  //         SnackBar(content: Text('오류 발생: $e'), backgroundColor: Colors.red),
  //       );
  //     }
  //   } finally {
  //     if (mounted) {
  //       setState(() => _isLoading = false);
  //     }
  //   }
  // }

  Future<void> _handleExtensionCall() async {
    setState(() => _isLoading = true);

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

      // 🔥 CRITICAL: DB에 단말번호가 실제로 존재하는지 확인
      final dbExtensions = await _databaseService.getMyExtensions(userId).first;
      final extensionExists = dbExtensions.any((ext) => ext.extension == selectedExtension.extension);
      
      if (!extensionExists) {
        if (kDebugMode) {
          debugPrint('❌ 단말번호가 DB에서 삭제됨: ${selectedExtension.extension}');
          debugPrint('🔄 착신전환 비활성화 시도');
        }
        
        // 착신전환 비활성화 시도 (DCMIWS 웹소켓으로 전송)
        try {
          if (userModel != null &&
              userModel.amiServerId != null && 
              userModel.tenantId != null && 
              selectedExtension.extension.isNotEmpty) {
            final dcmiws = DCMIWSService();
            await dcmiws.setCallForwardEnabled(
              amiServerId: userModel.amiServerId!,
              tenantId: userModel.tenantId!,
              extensionId: selectedExtension.extension,  // ← 단말번호 사용
              enabled: false,
              diversionType: 'CFI',
            );
            
            if (kDebugMode) {
              debugPrint('✅ 착신전환 비활성화 요청 전송 완료');
            }
          }
        } catch (e) {
          if (kDebugMode) {
            debugPrint('⚠️  착신전환 비활성화 실패: $e');
          }
        }
        
        throw Exception('등록된 단말번호가 없습니다.\n\n프로필 드로어에서 단말번호가 삭제되었습니다.\n다시 등록해주세요.');
      }

      if (kDebugMode) {
        debugPrint('🔥 Click to Call 시작');
        debugPrint('📞 선택된 단말번호: ${selectedExtension.extension}');
        debugPrint('👤 단말 이름: ${selectedExtension.name}');
        debugPrint('🔑 COS ID: ${selectedExtension.classOfServicesId}');
        debugPrint('📱 발신 대상: ${widget.phoneNumber}');
      }

      // 🔍 발신 대상 숫자 자릿수 확인
      final cleanNumber = widget.phoneNumber.replaceAll(RegExp(r'[^0-9]'), '');
      final is5DigitsOrLess = cleanNumber.length > 0 && cleanNumber.length <= 5;
      
      // 📞 CID 설정: 발신 대상에 따라 다르게 설정
      String cidName;
      String cidNumber;
      
      if (is5DigitsOrLess) {
        // 5자리 이하: my_extensions의 name, extension 사용
        cidName = selectedExtension.name;
        cidNumber = selectedExtension.extension;
        
        if (kDebugMode) {
          debugPrint('📞 5자리 이하 발신');
          debugPrint('   CID Name: $cidName (my_extensions.name)');
          debugPrint('   CID Number: $cidNumber (my_extensions.extension)');
        }
      } else {
        // 5자리 초과: my_extensions의 externalCidName, externalCidNumber 사용
        cidName = selectedExtension.externalCidName ?? '클릭투콜';
        cidNumber = selectedExtension.externalCidNumber ?? widget.phoneNumber;
        
        if (kDebugMode) {
          debugPrint('📞 5자리 초과 발신');
          debugPrint('   CID Name: $cidName (my_extensions.externalCidName)');
          debugPrint('   CID Number: $cidNumber (my_extensions.externalCidNumber)');
        }
      }

      // 🔥 Step 1: 착신전환 정보 먼저 조회 (API 호출 전)
      final callForwardInfo = await _databaseService
          .getCallForwardInfoOnce(userId, selectedExtension.extension);
      
      final isForwardEnabled = callForwardInfo?.isEnabled ?? false;
      final forwardDestination = (callForwardInfo?.destinationNumber ?? '').trim();

      if (kDebugMode) {
        debugPrint('');
        debugPrint('💾 ========== 통화 기록 준비 (착신전환 정보 포함) ==========');
        debugPrint('   📱 단말번호: ${selectedExtension.extension}');
        debugPrint('   📞 발신 대상: ${widget.phoneNumber}');
        debugPrint('   🔄 착신전환 활성화: $isForwardEnabled');
        debugPrint('   ➡️  착신전환 목적지: ${isForwardEnabled ? forwardDestination : "비활성화"}');
        debugPrint('   📦 준비 데이터:');
        debugPrint('      - callForwardEnabled: $isForwardEnabled');
        debugPrint('      - callForwardDestination: ${(isForwardEnabled && forwardDestination.isNotEmpty) ? forwardDestination : "null"}');
        debugPrint('========================================================');
        debugPrint('');
      }

      // 🚀 Step 2: Pending Storage에 먼저 저장 (Race Condition 방지!)
      // ✅ API 호출 전에 저장하여 Newchannel 이벤트보다 항상 먼저 준비됨
      final dcmiws = DCMIWSService();
      dcmiws.storePendingClickToCallRecord(
        extensionNumber: selectedExtension.extension,
        phoneNumber: widget.phoneNumber,
        userId: userId,
        mainNumberUsed: cidNumber,
        callForwardEnabled: isForwardEnabled,
        callForwardDestination: (isForwardEnabled && forwardDestination.isNotEmpty) ? forwardDestination : null,
      );

      // API 서비스 생성 (동적 API URL 사용)
      // apiHttpPort가 3501이면 HTTPS 사용, 3500이면 HTTP 사용
      final useHttps = (userModel!.apiHttpPort ?? 3500) == 3501;
      
      final apiService = ApiService(
        baseUrl: userModel.getApiUrl(useHttps: useHttps),
        companyId: userModel.companyId,
        appKey: userModel.appKey,
      );

      // 📞 Step 3: Click to Call API 호출 (Pending Storage 준비 완료 후)
      final result = await apiService.clickToCall(
        caller: selectedExtension.extension, // 선택된 단말번호 사용
        callee: widget.phoneNumber,
        cosId: selectedExtension.classOfServicesId, // 선택된 COS ID 사용
        cidName: cidName,
        cidNumber: cidNumber,
        accountCode: userModel.phoneNumber ?? '',
      );

      if (kDebugMode) {
        debugPrint('✅ Click to Call 성공: $result');
        debugPrint('   → Newchannel 이벤트 대기 중... (Pending Storage 준비 완료)');
      }

      if (mounted && Navigator.canPop(context)) {
        Navigator.pop(context);
        // Navigator.pop 후 약간의 딜레이를 주어 안전하게 새 다이얼로그 표시
        await Future.delayed(const Duration(milliseconds: 100));
        
        if (mounted) {
          final extensionDisplay = selectedExtension.name.isEmpty 
              ? selectedExtension.extension 
              : selectedExtension.name;
          
          await DialogUtils.showSuccess(
            context,
            '✅ Click to Call 요청 전송 완료\n\n단말: $extensionDisplay\n번호: ${selectedExtension.extension}\nCOS ID: ${selectedExtension.classOfServicesId}',
            duration: const Duration(seconds: 4),
          );
          
          // 🔄 클릭투콜 성공 콜백 호출 (최근통화 탭으로 전환)
          widget.onClickToCallSuccess?.call();
        }
      }
    } catch (e) {
      if (mounted) {
        await DialogUtils.showError(
          context,
          '오류 발생: $e',
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }
}
