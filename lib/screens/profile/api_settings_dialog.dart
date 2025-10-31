import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../../services/auth_service.dart';

class ApiSettingsDialog extends StatefulWidget {
  const ApiSettingsDialog({super.key});

  @override
  State<ApiSettingsDialog> createState() => _ApiSettingsDialogState();
}

class _ApiSettingsDialogState extends State<ApiSettingsDialog> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _companyNameController;
  late final TextEditingController _apiBaseUrlController;
  late final TextEditingController _companyIdController;
  late final TextEditingController _appKeyController;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    final userModel = context.read<AuthService>().currentUserModel;
    _companyNameController = TextEditingController(text: userModel?.companyName ?? '');
    _apiBaseUrlController = TextEditingController(text: userModel?.apiBaseUrl ?? '');
    _companyIdController = TextEditingController(text: userModel?.companyId ?? '');
    _appKeyController = TextEditingController(text: userModel?.appKey ?? '');
  }

  @override
  void dispose() {
    _companyNameController.dispose();
    _apiBaseUrlController.dispose();
    _companyIdController.dispose();
    _appKeyController.dispose();
    super.dispose();
  }

  Future<void> _handleSave() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    try {
      await context.read<AuthService>().updateUserInfo(
            companyName: _companyNameController.text.trim(),
            apiBaseUrl: _apiBaseUrlController.text.trim(),
            apiHttpPort: 3500,
            apiHttpsPort: 3501,
            companyId: _companyIdController.text.trim(),
            appKey: _appKeyController.text.trim(),
          );

      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('회사/API 설정이 저장되었습니다')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('오류 발생: $e'), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('회사 / API 설정'),
      content: SingleChildScrollView(
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // 회사명
              const Text(
                '회사 정보',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
              ),
              const SizedBox(height: 8),
              TextFormField(
                controller: _companyNameController,
                decoration: const InputDecoration(
                  labelText: '회사명',
                  hintText: '예: OO주식회사',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.business),
                ),
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return '회사명을 입력해주세요';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 24),
              const Divider(),
              const SizedBox(height: 16),
              // API 베이스 URL
              const Text(
                'API 서버 주소',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
              ),
              const SizedBox(height: 8),
              TextFormField(
                controller: _apiBaseUrlController,
                decoration: const InputDecoration(
                  labelText: 'API Base URL',
                  hintText: '예: api.example.com',
                  border: OutlineInputBorder(),
                ),
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return 'API Base URL을 입력해주세요';
                  }
                  if (value.contains('://')) {
                    return 'http://, https:// 제외하고 입력해주세요';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 24),
              const Divider(),
              const SizedBox(height: 16),
              // API 인증 정보
              const Text(
                'API 인증 정보',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
              ),
              const SizedBox(height: 8),
              TextFormField(
                controller: _companyIdController,
                decoration: const InputDecoration(
                  labelText: 'Company ID',
                  hintText: 'REST API Company ID',
                  border: OutlineInputBorder(),
                ),
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return 'Company ID를 입력해주세요';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _appKeyController,
                decoration: const InputDecoration(
                  labelText: 'App-Key',
                  hintText: 'REST API App-Key',
                  border: OutlineInputBorder(),
                ),
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return 'App-Key를 입력해주세요';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),
              // 미리보기
              if (_apiBaseUrlController.text.trim().isNotEmpty) ...[
                const Divider(),
                const SizedBox(height: 8),
                const Text(
                  '현재 설정된 API 서버:',
                  style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 4),
                Text(
                  _apiBaseUrlController.text.trim(),
                  style: const TextStyle(fontSize: 11, color: Colors.grey),
                ),
              ],
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: _isLoading ? null : () => Navigator.pop(context),
          child: const Text('취소'),
        ),
        ElevatedButton(
          onPressed: _isLoading ? null : _handleSave,
          child: _isLoading
              ? const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Text('저장'),
        ),
      ],
    );
  }
}
