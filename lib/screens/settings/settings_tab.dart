import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:package_info_plus/package_info_plus.dart';
import '../../services/auth_service.dart';

class SettingsTab extends StatelessWidget {
  const SettingsTab({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('설정'),
      ),
      body: ListView(
        children: [
          const SizedBox(height: 16),
          // 푸시 알림 설정
          const ListTile(
            leading: Icon(Icons.notifications),
            title: Text('푸시 알림'),
            subtitle: Text('알림 수신 설정'),
          ),
          SwitchListTile(
            secondary: const Icon(Icons.notifications_active),
            title: const Text('푸시 알림 표시'),
            subtitle: const Text('새로운 통화 및 메시지 알림'),
            value: true,
            onChanged: (value) {
              // 푸시 알림 설정 변경
            },
          ),
          SwitchListTile(
            secondary: const Icon(Icons.volume_up),
            title: const Text('알림음'),
            subtitle: const Text('알림 수신 시 소리'),
            value: true,
            onChanged: (value) {
              // 알림음 설정 변경
            },
          ),
          SwitchListTile(
            secondary: const Icon(Icons.vibration),
            title: const Text('진동'),
            subtitle: const Text('알림 수신 시 진동'),
            value: true,
            onChanged: (value) {
              // 진동 설정 변경
            },
          ),
          const Divider(),
          // 약관 및 정책
          ListTile(
            leading: const Icon(Icons.description),
            title: const Text('이용 약관'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () {
              _showTextDialog(
                context,
                '이용 약관',
                '여기에 이용 약관 내용이 표시됩니다.\n\n'
                '1. 서비스 이용 약관\n'
                '2. 개인정보 수집 및 이용 동의\n'
                '3. 위치기반서비스 이용약관\n'
                '...',
              );
            },
          ),
          ListTile(
            leading: const Icon(Icons.privacy_tip),
            title: const Text('개인정보 처리방침'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () {
              _showTextDialog(
                context,
                '개인정보 처리방침',
                '여기에 개인정보 처리방침 내용이 표시됩니다.\n\n'
                '1. 개인정보의 수집 및 이용 목적\n'
                '2. 수집하는 개인정보의 항목\n'
                '3. 개인정보의 보유 및 이용 기간\n'
                '...',
              );
            },
          ),
          ListTile(
            leading: const Icon(Icons.code),
            title: const Text('오픈소스 라이선스'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () {
              _showLicensePage(context);
            },
          ),
          const Divider(),
          // 앱 정보
          FutureBuilder<PackageInfo>(
            future: PackageInfo.fromPlatform(),
            builder: (context, snapshot) {
              final version = snapshot.data?.version ?? '1.0.0';
              final buildNumber = snapshot.data?.buildNumber ?? '1';
              return ListTile(
                leading: const Icon(Icons.info),
                title: const Text('앱 버전'),
                subtitle: Text('$version ($buildNumber)'),
              );
            },
          ),
          const Divider(),
          // 계정 관리
          ListTile(
            leading: const Icon(Icons.logout, color: Colors.orange),
            title: const Text('로그아웃'),
            onTap: () => _handleLogout(context),
          ),
          ListTile(
            leading: const Icon(Icons.block, color: Colors.red),
            title: const Text('이용 중지'),
            subtitle: const Text('계정을 삭제하고 모든 데이터를 제거합니다'),
            onTap: () => _handleDeleteAccount(context),
          ),
        ],
      ),
    );
  }

  void _showTextDialog(BuildContext context, String title, String content) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(title),
        content: SingleChildScrollView(
          child: Text(content),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('닫기'),
          ),
        ],
      ),
    );
  }

  void _showLicensePage(BuildContext context) {
    showLicensePage(
      context: context,
      applicationName: 'MakeCall',
      applicationVersion: '1.0.0',
      applicationIcon: const Icon(Icons.phone_in_talk, size: 48),
    );
  }

  Future<void> _handleLogout(BuildContext context) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('로그아웃'),
        content: const Text('로그아웃 하시겠습니까?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('취소'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('로그아웃'),
          ),
        ],
      ),
    );

    if (confirmed == true && context.mounted) {
      await context.read<AuthService>().signOut();
    }
  }

  Future<void> _handleDeleteAccount(BuildContext context) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('이용 중지'),
        content: const Text(
          '정말로 계정을 삭제하시겠습니까?\n\n'
          '이 작업은 되돌릴 수 없으며, 모든 데이터가 영구적으로 삭제됩니다.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('취소'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('삭제'),
          ),
        ],
      ),
    );

    if (confirmed == true && context.mounted) {
      try {
        await context.read<AuthService>().deleteAccount();
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('계정이 삭제되었습니다')),
          );
        }
      } catch (e) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('오류 발생: $e'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    }
  }
}
