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
  late final TextEditingController _websocketServerUrlController;
  late final TextEditingController _websocketServerPortController;
  late final TextEditingController _amiServerIdController;
  bool _isLoading = false;
  bool _websocketUseSSL = false;

  @override
  void initState() {
    super.initState();
    final userModel = context.read<AuthService>().currentUserModel;
    _companyNameController = TextEditingController(text: userModel?.companyName ?? '');
    _apiBaseUrlController = TextEditingController(text: userModel?.apiBaseUrl ?? '');
    _companyIdController = TextEditingController(text: userModel?.companyId ?? '');
    _appKeyController = TextEditingController(text: userModel?.appKey ?? '');
    _websocketServerUrlController = TextEditingController(text: userModel?.websocketServerUrl ?? '');
    _websocketServerPortController = TextEditingController(text: (userModel?.websocketServerPort ?? 6600).toString());
    _amiServerIdController = TextEditingController(text: (userModel?.amiServerId ?? 1).toString());
    _websocketUseSSL = userModel?.websocketUseSSL ?? false;
  }

  @override
  void dispose() {
    _companyNameController.dispose();
    _apiBaseUrlController.dispose();
    _companyIdController.dispose();
    _appKeyController.dispose();
    _websocketServerUrlController.dispose();
    _websocketServerPortController.dispose();
    _amiServerIdController.dispose();
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
            websocketServerUrl: _websocketServerUrlController.text.trim(),
            websocketServerPort: int.tryParse(_websocketServerPortController.text.trim()) ?? 6600,
            websocketUseSSL: _websocketUseSSL,
            amiServerId: int.tryParse(_amiServerIdController.text.trim()) ?? 1,
          );

      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('회사/API/WebSocket 설정이 저장되었습니다')),
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
              const SizedBox(height: 24),
              const Divider(),
              const SizedBox(height: 16),
              // WebSocket 설정
              const Text(
                'WebSocket 설정',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
              ),
              const SizedBox(height: 8),
              TextFormField(
                controller: _websocketServerUrlController,
                decoration: const InputDecoration(
                  labelText: 'WebSocket 서버 주소',
                  hintText: '예: ws.example.com',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.wifi),
                ),
                validator: (value) {
                  if (value != null && value.trim().isNotEmpty) {
                    if (value.contains('://')) {
                      return 'ws://, wss:// 제외하고 입력해주세요';
                    }
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: TextFormField(
                      controller: _websocketServerPortController,
                      decoration: const InputDecoration(
                        labelText: 'WebSocket 포트',
                        hintText: '6600',
                        border: OutlineInputBorder(),
                        prefixIcon: Icon(Icons.numbers),
                      ),
                      keyboardType: TextInputType.number,
                      inputFormatters: [
                        FilteringTextInputFormatter.digitsOnly,
                      ],
                      validator: (value) {
                        if (value != null && value.trim().isNotEmpty) {
                          final port = int.tryParse(value.trim());
                          if (port == null || port < 1 || port > 65535) {
                            return '1-65535 범위의 포트를 입력해주세요';
                          }
                        }
                        return null;
                      },
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: TextFormField(
                      controller: _amiServerIdController,
                      decoration: const InputDecoration(
                        labelText: 'AMI Server ID',
                        hintText: '1',
                        border: OutlineInputBorder(),
                        prefixIcon: Icon(Icons.dns),
                      ),
                      keyboardType: TextInputType.number,
                      inputFormatters: [
                        FilteringTextInputFormatter.digitsOnly,
                      ],
                      validator: (value) {
                        if (value != null && value.trim().isNotEmpty) {
                          final id = int.tryParse(value.trim());
                          if (id == null || id < 1) {
                            return '1 이상의 숫자를 입력해주세요';
                          }
                        }
                        return null;
                      },
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              // ws/wss 프로토콜 선택
              Container(
                decoration: BoxDecoration(
                  border: Border.all(color: Colors.grey.shade300),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: SwitchListTile(
                  title: const Text('SSL 사용 (wss)'),
                  subtitle: Text(
                    _websocketUseSSL ? 'wss:// (보안 연결)' : 'ws:// (일반 연결)',
                    style: TextStyle(
                      fontSize: 12,
                      color: _websocketUseSSL ? Colors.green : Colors.orange,
                    ),
                  ),
                  value: _websocketUseSSL,
                  onChanged: (value) {
                    setState(() {
                      _websocketUseSSL = value;
                    });
                  },
                  secondary: Icon(
                    _websocketUseSSL ? Icons.lock : Icons.lock_open,
                    color: _websocketUseSSL ? Colors.green : Colors.orange,
                  ),
                ),
              ),
              // WebSocket URL 미리보기
              if (_websocketServerUrlController.text.trim().isNotEmpty) ...[
                const SizedBox(height: 8),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.grey.shade100,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.grey.shade300),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'WebSocket 연결 주소:',
                        style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '${_websocketUseSSL ? 'wss' : 'ws'}://${_websocketServerUrlController.text.trim()}:${_websocketServerPortController.text.trim()}',
                        style: TextStyle(
                          fontSize: 11,
                          color: _websocketUseSSL ? Colors.green.shade700 : Colors.orange.shade700,
                          fontFamily: 'monospace',
                        ),
                      ),
                    ],
                  ),
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
