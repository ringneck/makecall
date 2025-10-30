import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/auth_service.dart';
import '../services/database_service.dart';
import '../services/call_service.dart';
import '../services/api_service.dart';

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

      // 대표번호 가져오기
      final mainNumbers = await _databaseService.getUserMainNumbers(userId).first;
      final defaultMainNumber = mainNumbers.firstWhere(
        (mn) => mn.isDefault,
        orElse: () => mainNumbers.isNotEmpty ? mainNumbers.first : throw Exception('대표번호를 설정해주세요'),
      );

      // 단말번호 가져오기
      final extensions = await _databaseService.getUserExtensions(userId).first;
      final selectedExtension = extensions.firstWhere(
        (ext) => ext.isSelected,
        orElse: () => extensions.isNotEmpty ? extensions.first : throw Exception('단말번호를 설정해주세요'),
      );

      // API 서비스 생성
      final apiService = ApiService(
        baseUrl: 'https://api.example.com', // 실제 API 주소로 변경 필요
        companyId: userModel!.companyId,
        appKey: userModel.appKey,
      );

      final success = await _callService.makeExtensionCall(
        phoneNumber: widget.phoneNumber,
        userId: userId,
        extension: selectedExtension,
        mainNumber: defaultMainNumber,
        userPhoneNumber: userModel.phoneNumber ?? '',
        apiService: apiService,
      );

      if (mounted) {
        Navigator.pop(context);
        if (success) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Click to Call 요청이 전송되었습니다')),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('오류 발생: $e'),
            backgroundColor: Colors.red,
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
