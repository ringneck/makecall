import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:provider/provider.dart';
import '../services/auth_service.dart';
import '../services/database_service.dart';
import '../services/call_service.dart';
import '../services/api_service.dart';
import '../models/call_history_model.dart';
import '../providers/selected_extension_provider.dart';

class CallMethodDialog extends StatefulWidget {
  final String phoneNumber;

  const CallMethodDialog({
    super.key,
    required this.phoneNumber,
  });

  @override
  State<CallMethodDialog> createState() => _CallMethodDialogState();
}

class _CallMethodDialogState extends State<CallMethodDialog> {
  final DatabaseService _databaseService = DatabaseService();
  final CallService _callService = CallService();
  bool _isLoading = false;

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('발신 방법 선택'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            widget.phoneNumber,
            style: const TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: Color(0xFF2196F3),
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
    return ListTile(
      leading: Icon(icon, color: const Color(0xFF2196F3)),
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

      if (mounted) {
        Navigator.pop(context);
        if (success) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('전화를 거는 중입니다...')),
          );
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('전화를 걸 수 없습니다'),
              backgroundColor: Colors.red,
            ),
          );
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
        throw Exception('선택된 단말번호가 없습니다.\n홈 탭에서 단말번호를 확인해주세요.');
      }

      if (kDebugMode) {
        debugPrint('🔥 Click to Call 시작');
        debugPrint('📞 선택된 단말번호: ${selectedExtension.extension}');
        debugPrint('👤 단말 이름: ${selectedExtension.name}');
        debugPrint('🔑 COS ID: ${selectedExtension.classOfServicesId}');
        debugPrint('📱 발신 대상: ${widget.phoneNumber}');
      }

      // 대표번호 가져오기 (선택사항)
      final mainNumbers = await _databaseService.getUserMainNumbers(userId).first;
      String cidName = selectedExtension.name.isEmpty 
          ? selectedExtension.extension 
          : selectedExtension.name;
      String cidNumber = selectedExtension.extension;

      // 대표번호가 있으면 사용
      if (mainNumbers.isNotEmpty) {
        final defaultMainNumber = mainNumbers.firstWhere(
          (mn) => mn.isDefault,
          orElse: () => mainNumbers.first,
        );
        cidName = defaultMainNumber.name;
        cidNumber = defaultMainNumber.number;
      }

      if (kDebugMode) {
        debugPrint('📞 CID Name: $cidName');
        debugPrint('📞 CID Number: $cidNumber');
      }

      // API 서비스 생성 (동적 API URL 사용)
      final apiService = ApiService(
        baseUrl: userModel!.getApiUrl(useHttps: false), // HTTP 사용
        companyId: userModel.companyId,
        appKey: userModel.appKey,
      );

      // Click to Call API 호출
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
      }

      // 통화 기록 저장
      await _databaseService.addCallHistory(
        CallHistoryModel(
          id: '',
          userId: userId,
          phoneNumber: widget.phoneNumber,
          callType: CallType.outgoing,
          callMethod: CallMethod.extension,
          callTime: DateTime.now(),
          mainNumberUsed: cidNumber,
          extensionUsed: selectedExtension.extension,
        ),
      );

      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  '✅ Click to Call 요청 전송 완료',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 4),
                Text('단말: ${selectedExtension.name.isEmpty ? selectedExtension.extension : selectedExtension.name}'),
                Text('번호: ${selectedExtension.extension}'),
                Text('COS ID: ${selectedExtension.classOfServicesId}'),
              ],
            ),
            backgroundColor: Colors.green,
            duration: const Duration(seconds: 4),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('오류 발생: $e'),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 4),
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }
}
