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
  late final TextEditingController _companyIdController;
  late final TextEditingController _appKeyController;
  late final TextEditingController _websocketServerUrlController;
  late final TextEditingController _websocketServerPortController;
  bool _isLoading = false;
  bool _websocketUseSSL = false;

  @override
  void initState() {
    super.initState();
    final userModel = context.read<AuthService>().currentUserModel;
    _apiBaseUrlController = TextEditingController(text: userModel?.apiBaseUrl ?? '');
    _companyIdController = TextEditingController(text: userModel?.companyId ?? '');
    _appKeyController = TextEditingController(text: userModel?.appKey ?? '');
    _websocketServerUrlController = TextEditingController(text: userModel?.websocketServerUrl ?? '');
    _websocketServerPortController = TextEditingController(text: (userModel?.websocketServerPort ?? 6600).toString());
    _websocketUseSSL = userModel?.websocketUseSSL ?? false;
  }

  @override
  void dispose() {
    _apiBaseUrlController.dispose();
    _companyIdController.dispose();
    _appKeyController.dispose();
    _websocketServerUrlController.dispose();
    _websocketServerPortController.dispose();
    super.dispose();
  }

  // 클립보드 붙여넣기 헬퍼 메서드
  Future<void> _pasteFromClipboard(TextEditingController controller, String fieldName) async {
    // iOS에서는 포커스를 먼저 설정
    FocusScope.of(context).requestFocus(FocusNode());
    
    try {
      final data = await Clipboard.getData(Clipboard.kTextPlain);
      if (data?.text != null && data!.text!.isNotEmpty) {
        // iOS에서는 직접 컨트롤러에 설정
        controller.value = TextEditingValue(
          text: data.text!,
          selection: TextSelection.collapsed(offset: data.text!.length),
        );
        
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('$fieldName 붙여넣기 완료: ${data.text!.length}자'),
              duration: const Duration(seconds: 1),
              backgroundColor: Colors.green,
            ),
          );
        }
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('클립보드가 비어있습니다\n\n💡 iOS Tip: 입력 필드를 길게 눌러\n"붙여넣기" 메뉴를 사용하세요'),
              duration: Duration(seconds: 3),
              backgroundColor: Colors.orange,
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('iOS에서는 입력 필드를 길게 눌러\n"붙여넣기" 메뉴를 사용하세요\n\n오류: $e'),
            duration: const Duration(seconds: 3),
            backgroundColor: Colors.blue,
          ),
        );
      }
    }
  }

  Future<void> _handleSave() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    try {
      await context.read<AuthService>().updateUserInfo(
            apiBaseUrl: _apiBaseUrlController.text.trim(),
            apiHttpPort: 3500,
            apiHttpsPort: 3501,
            companyId: _companyIdController.text.trim(),
            appKey: _appKeyController.text.trim(),
            websocketServerUrl: _websocketServerUrlController.text.trim(),
            websocketServerPort: int.tryParse(_websocketServerPortController.text.trim()) ?? 6600,
            websocketUseSSL: _websocketUseSSL,
            amiServerId: 1,
          );

      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('기본 설정이 저장되었습니다')),
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
    final screenWidth = MediaQuery.of(context).size.width;
    final dialogWidth = screenWidth > 600 ? 500.0 : screenWidth * 0.9;
    
    return AlertDialog(
      title: const Text('기본 설정', style: TextStyle(fontSize: 16)),
      contentPadding: const EdgeInsets.fromLTRB(20, 20, 20, 12),
      content: SizedBox(
        width: dialogWidth,
        child: SingleChildScrollView(
          child: Form(
            key: _formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
              // API 베이스 URL
              const Text(
                'API 서버 주소',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
              ),
              const SizedBox(height: 8),
              TextFormField(
                controller: _apiBaseUrlController,
                style: const TextStyle(fontSize: 13),
                enableInteractiveSelection: true,
                enableSuggestions: false,
                autocorrect: false,
                keyboardType: TextInputType.url,
                textInputAction: TextInputAction.next,
                // iOS에서 기본 컨텍스트 메뉴 사용 (길게 누르기 + 붙여넣기)
                decoration: InputDecoration(
                  labelText: 'API Base URL',
                  hintText: '예: api.example.com',
                  border: const OutlineInputBorder(),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                  labelStyle: const TextStyle(fontSize: 12),
                  hintStyle: const TextStyle(fontSize: 12),
                  errorStyle: const TextStyle(fontSize: 10),
                  suffixIcon: IconButton(
                    icon: const Icon(Icons.content_paste, size: 18),
                    onPressed: () => _pasteFromClipboard(_apiBaseUrlController, 'API URL'),
                    tooltip: '클립보드에서 붙여넣기',
                  ),
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
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
              ),
              const SizedBox(height: 8),
              TextFormField(
                controller: _companyIdController,
                style: const TextStyle(fontSize: 13),
                enableInteractiveSelection: true,
                enableSuggestions: false,
                autocorrect: false,
                keyboardType: TextInputType.text,
                textInputAction: TextInputAction.next,
                // iOS에서 기본 컨텍스트 메뉴 사용 (길게 누르기 + 붙여넣기)
                decoration: InputDecoration(
                  labelText: 'Company ID',
                  hintText: 'REST API Company ID',
                  border: const OutlineInputBorder(),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                  labelStyle: const TextStyle(fontSize: 12),
                  hintStyle: const TextStyle(fontSize: 12),
                  errorStyle: const TextStyle(fontSize: 10),
                  suffixIcon: IconButton(
                    icon: const Icon(Icons.content_paste, size: 18),
                    onPressed: () => _pasteFromClipboard(_companyIdController, 'Company ID'),
                    tooltip: '클립보드에서 붙여넣기',
                  ),
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
                style: const TextStyle(fontSize: 13),
                enableInteractiveSelection: true,
                enableSuggestions: false,
                autocorrect: false,
                keyboardType: TextInputType.visiblePassword,
                textInputAction: TextInputAction.next,
                // iOS에서 기본 컨텍스트 메뉴 사용 (길게 누르기 + 붙여넣기)
                decoration: InputDecoration(
                  labelText: 'App-Key',
                  hintText: 'REST API App-Key',
                  border: const OutlineInputBorder(),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                  labelStyle: const TextStyle(fontSize: 12),
                  hintStyle: const TextStyle(fontSize: 12),
                  errorStyle: const TextStyle(fontSize: 10),
                  suffixIcon: IconButton(
                    icon: const Icon(Icons.content_paste, size: 18),
                    onPressed: () => _pasteFromClipboard(_appKeyController, 'App-Key'),
                    tooltip: '클립보드에서 붙여넣기',
                  ),
                ),
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return 'App-Key를 입력해주세요';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 24),
              const Divider(),
              const SizedBox(height: 16),
              // WebSocket 설정
              const Text(
                'WebSocket 설정',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    flex: 3,
                    child: TextFormField(
                      controller: _websocketServerUrlController,
                      style: const TextStyle(fontSize: 13),
                      enableInteractiveSelection: true,
                      enableSuggestions: false,
                      autocorrect: false,
                      keyboardType: TextInputType.url,
                      textInputAction: TextInputAction.next,
                      // iOS에서 기본 컨텍스트 메뉴 사용 (길게 누르기 + 붙여넣기)
                      decoration: InputDecoration(
                        labelText: 'WebSocket 서버 주소',
                        hintText: '예: ws.example.com',
                        border: const OutlineInputBorder(),
                        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                        labelStyle: const TextStyle(fontSize: 12),
                        hintStyle: const TextStyle(fontSize: 12),
                        errorStyle: const TextStyle(fontSize: 10),
                        suffixIcon: IconButton(
                          icon: const Icon(Icons.content_paste, size: 18),
                          onPressed: () => _pasteFromClipboard(_websocketServerUrlController, 'WebSocket URL'),
                          tooltip: '클립보드에서 붙여넣기',
                        ),
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
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    flex: 1,
                    child: TextFormField(
                      controller: _websocketServerPortController,
                      style: const TextStyle(fontSize: 13),
                      decoration: const InputDecoration(
                        labelText: '포트',
                        hintText: '6600',
                        border: OutlineInputBorder(),
                        contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                        labelStyle: TextStyle(fontSize: 12),
                        hintStyle: TextStyle(fontSize: 12),
                        errorStyle: TextStyle(fontSize: 10),
                      ),
                      keyboardType: TextInputType.number,
                      inputFormatters: [
                        FilteringTextInputFormatter.digitsOnly,
                      ],
                      validator: (value) {
                        if (value != null && value.trim().isNotEmpty) {
                          final port = int.tryParse(value.trim());
                          if (port == null || port < 1 || port > 65535) {
                            return '포트 범위: 1-65535';
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
                  title: const Text('SSL 사용 (wss)', style: TextStyle(fontSize: 13)),
                  subtitle: Text(
                    _websocketUseSSL ? 'wss:// (보안 연결)' : 'ws:// (일반 연결)',
                    style: TextStyle(
                      fontSize: 10,
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
                    size: 20,
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
                        style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '${_websocketUseSSL ? 'wss' : 'ws'}://${_websocketServerUrlController.text.trim()}:${_websocketServerPortController.text.trim()}',
                        style: TextStyle(
                          fontSize: 9,
                          color: _websocketUseSSL ? Colors.green.shade700 : Colors.orange.shade700,
                          fontFamily: 'monospace',
                        ),
                        overflow: TextOverflow.ellipsis,
                        maxLines: 2,
                      ),
                    ],
                  ),
                ),
              ],
            ],
          ),
        ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: _isLoading ? null : () => Navigator.pop(context),
          child: const Text('취소', style: TextStyle(fontSize: 13)),
        ),
        ElevatedButton(
          onPressed: _isLoading ? null : _handleSave,
          child: _isLoading
              ? const SizedBox(
                  width: 14,
                  height: 14,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Text('저장', style: TextStyle(fontSize: 13)),
        ),
      ],
    );
  }
}
