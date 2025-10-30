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
  late final TextEditingController _apiBaseUrlController;
  late final TextEditingController _apiHttpPortController;
  late final TextEditingController _apiHttpsPortController;
  late final TextEditingController _companyIdController;
  late final TextEditingController _appKeyController;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    final userModel = context.read<AuthService>().currentUserModel;
    _apiBaseUrlController = TextEditingController(text: userModel?.apiBaseUrl ?? '');
    _apiHttpPortController = TextEditingController(text: (userModel?.apiHttpPort ?? 3500).toString());
    _apiHttpsPortController = TextEditingController(text: (userModel?.apiHttpsPort ?? 3501).toString());
    _companyIdController = TextEditingController(text: userModel?.companyId ?? '');
    _appKeyController = TextEditingController(text: userModel?.appKey ?? '');
  }

  @override
  void dispose() {
    _apiBaseUrlController.dispose();
    _apiHttpPortController.dispose();
    _apiHttpsPortController.dispose();
    _companyIdController.dispose();
    _appKeyController.dispose();
    super.dispose();
  }

  Future<void> _handleSave() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    try {
      await context.read<AuthService>().updateUserInfo(
            apiBaseUrl: _apiBaseUrlController.text.trim(),
            apiHttpPort: int.tryParse(_apiHttpPortController.text.trim()),
            apiHttpsPort: int.tryParse(_apiHttpsPortController.text.trim()),
            companyId: _companyIdController.text.trim(),
            appKey: _appKeyController.text.trim(),
          );

      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('API 설정이 저장되었습니다')),
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
    final userModel = context.watch<AuthService>().currentUserModel;
    final httpUrl = userModel?.getApiUrl(useHttps: false) ?? '';
    final httpsUrl = userModel?.getApiUrl(useHttps: true) ?? '';

    return AlertDialog(
      title: const Text('API 설정'),
      content: SingleChildScrollView(
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
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
                  helperText: '프로토콜(http://, https://)과 포트 제외',
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
              const SizedBox(height: 16),
              // HTTP 포트
              TextFormField(
                controller: _apiHttpPortController,
                keyboardType: TextInputType.number,
                inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                decoration: const InputDecoration(
                  labelText: 'HTTP 포트',
                  hintText: '3500',
                  border: OutlineInputBorder(),
                ),
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return 'HTTP 포트를 입력해주세요';
                  }
                  final port = int.tryParse(value);
                  if (port == null || port < 1 || port > 65535) {
                    return '올바른 포트 번호를 입력해주세요 (1-65535)';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),
              // HTTPS 포트
              TextFormField(
                controller: _apiHttpsPortController,
                keyboardType: TextInputType.number,
                inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                decoration: const InputDecoration(
                  labelText: 'HTTPS 포트',
                  hintText: '3501',
                  border: OutlineInputBorder(),
                ),
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return 'HTTPS 포트를 입력해주세요';
                  }
                  final port = int.tryParse(value);
                  if (port == null || port < 1 || port > 65535) {
                    return '올바른 포트 번호를 입력해주세요 (1-65535)';
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
              if (httpUrl.isNotEmpty || httpsUrl.isNotEmpty) ...[
                const Divider(),
                const SizedBox(height: 8),
                const Text(
                  '현재 설정된 URL:',
                  style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 4),
                if (httpUrl.isNotEmpty)
                  Text(
                    'HTTP: $httpUrl',
                    style: const TextStyle(fontSize: 11, color: Colors.grey),
                  ),
                if (httpsUrl.isNotEmpty)
                  Text(
                    'HTTPS: $httpsUrl',
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
