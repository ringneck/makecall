import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../services/auth_service.dart';
import 'api_settings_dialog.dart';
import 'extension_management_screen.dart';

class ProfileTab extends StatelessWidget {
  const ProfileTab({super.key});

  @override
  Widget build(BuildContext context) {
    final authService = context.watch<AuthService>();
    final userModel = authService.currentUserModel;

    return Scaffold(
      appBar: AppBar(
        title: const Text('내 정보'),
      ),
      body: ListView(
        children: [
          const SizedBox(height: 24),
          // 사용자 정보
          CircleAvatar(
            radius: 50,
            backgroundColor: const Color(0xFF2196F3).withAlpha(51),
            child: const Icon(Icons.person, size: 50, color: Color(0xFF2196F3)),
          ),
          const SizedBox(height: 16),
          Text(
            userModel?.email ?? '이메일 없음',
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 32),
          const Divider(),
          // API 설정
          ListTile(
            leading: const Icon(Icons.api),
            title: const Text('API 설정'),
            subtitle: Text(
              userModel?.apiBaseUrl != null
                  ? '${userModel!.apiBaseUrl} (HTTP:${userModel.apiHttpPort}, HTTPS:${userModel.apiHttpsPort})'
                  : 'API 서버 주소 미설정',
              style: const TextStyle(fontSize: 12),
            ),
            trailing: const Icon(Icons.chevron_right),
            onTap: () {
              showDialog(
                context: context,
                builder: (context) => const ApiSettingsDialog(),
              );
            },
          ),
          const Divider(),
          // API Base URL 정보 표시
          if (userModel?.apiBaseUrl != null) ...[
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'API 서버 정보',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                      color: Colors.grey,
                    ),
                  ),
                  const SizedBox(height: 8),
                  // API Base URL 표시
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.blue[50],
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.blue[200]!),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            const Icon(Icons.dns, size: 16, color: Color(0xFF2196F3)),
                            const SizedBox(width: 8),
                            const Text(
                              'API Base URL:',
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 12,
                                color: Color(0xFF2196F3),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 4),
                        Text(
                          userModel!.apiBaseUrl!,
                          style: const TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            fontFamily: 'monospace',
                            color: Colors.black87,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Row(
                          children: [
                            const Icon(Icons.info_outline, size: 14, color: Colors.grey),
                            const SizedBox(width: 6),
                            Text(
                              'HTTP 포트: ${userModel.apiHttpPort}  |  HTTPS 포트: ${userModel.apiHttpsPort}',
                              style: const TextStyle(
                                fontSize: 11,
                                color: Colors.grey,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),
                  const Text(
                    'API 엔드포인트 (자동 생성)',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                      color: Colors.grey,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.grey[100],
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.grey[300]!),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            const Icon(Icons.https, size: 16, color: Colors.green),
                            const SizedBox(width: 8),
                            const Text(
                              'HTTPS + /api/v2:',
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 12,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 4),
                        Text(
                          userModel.getApiUrl(useHttps: true),
                          style: const TextStyle(
                            fontSize: 12,
                            fontFamily: 'monospace',
                            color: Colors.black87,
                          ),
                        ),
                        const SizedBox(height: 12),
                        Row(
                          children: [
                            const Icon(Icons.http, size: 16, color: Colors.orange),
                            const SizedBox(width: 8),
                            const Text(
                              'HTTP + /api/v2:',
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 12,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 4),
                        Text(
                          userModel.getApiUrl(useHttps: false),
                          style: const TextStyle(
                            fontSize: 12,
                            fontFamily: 'monospace',
                            color: Colors.black87,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 8),
            const Divider(),
          ],
          // 단말번호 관리
          ListTile(
            leading: const Icon(Icons.phone_android),
            title: const Text('단말번호 관리'),
            subtitle: const Text('단말번호 조회 및 선택'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => const ExtensionManagementScreen(),
                ),
              );
            },
          ),
          const Divider(),
          // 사용자 전화번호 정보
          ListTile(
            leading: const Icon(Icons.phone),
            title: const Text('내 전화번호'),
            subtitle: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (userModel?.phoneNumberName != null)
                  Text(
                    '${userModel!.phoneNumberName}',
                    style: const TextStyle(fontWeight: FontWeight.w600),
                  ),
                Text(userModel?.phoneNumber ?? '미설정'),
              ],
            ),
            trailing: const Icon(Icons.edit),
            onTap: () => _showPhoneNumberDialog(context),
          ),
          const Divider(),
        ],
      ),
    );
  }

  void _showPhoneNumberDialog(BuildContext context) {
    final authService = context.read<AuthService>();
    final nameController = TextEditingController(
      text: authService.currentUserModel?.phoneNumberName ?? '',
    );
    final numberController = TextEditingController(
      text: authService.currentUserModel?.phoneNumber ?? '',
    );

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('내 전화번호 설정'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: nameController,
              decoration: const InputDecoration(
                labelText: '전화번호 이름',
                hintText: '예: 내 휴대폰, 사무실 전화',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.label),
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: numberController,
              keyboardType: TextInputType.phone,
              decoration: const InputDecoration(
                labelText: '전화번호',
                hintText: '010-1234-5678',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.phone),
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
            onPressed: () async {
              try {
                await context.read<AuthService>().updateUserInfo(
                      phoneNumberName: nameController.text.trim().isEmpty 
                          ? null 
                          : nameController.text.trim(),
                      phoneNumber: numberController.text.trim().isEmpty 
                          ? null 
                          : numberController.text.trim(),
                    );
                if (context.mounted) {
                  Navigator.pop(context);
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('전화번호 정보가 저장되었습니다')),
                  );
                }
              } catch (e) {
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('오류 발생: $e')),
                  );
                }
              }
            },
            child: const Text('저장'),
          ),
        ],
      ),
    );
  }
}
