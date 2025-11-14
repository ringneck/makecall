import 'package:flutter/material.dart';
import '../../utils/dialog_utils.dart';
import 'package:flutter/foundation.dart';
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
  late final TextEditingController _websocketHttpAuthIdController;
  late final TextEditingController _websocketHttpAuthPasswordController;
  bool _isLoading = false;
  bool _apiUseSSL = false; // API SSL 사용 여부
  bool _websocketUseSSL = false;
  
  // DialogUtils 사용 (ScaffoldMessenger 제거)

  @override
  void initState() {
    super.initState();
    final userModel = context.read<AuthService>().currentUserModel;
    
    // 🔧 DB에서 기존 값 로드 (있으면 채워넣기)
    _apiBaseUrlController = TextEditingController(
      text: userModel?.apiBaseUrl?.isNotEmpty == true ? userModel!.apiBaseUrl! : ''
    );
    _companyIdController = TextEditingController(
      text: userModel?.companyId?.isNotEmpty == true ? userModel!.companyId! : ''
    );
    _appKeyController = TextEditingController(
      text: userModel?.appKey?.isNotEmpty == true ? userModel!.appKey! : ''
    );
    _websocketServerUrlController = TextEditingController(
      text: userModel?.websocketServerUrl?.isNotEmpty == true ? userModel!.websocketServerUrl! : ''
    );
    _websocketServerPortController = TextEditingController(
      text: (userModel?.websocketServerPort ?? 6600).toString()
    );
    _websocketHttpAuthIdController = TextEditingController(
      text: userModel?.websocketHttpAuthId?.isNotEmpty == true ? userModel!.websocketHttpAuthId! : ''
    );
    _websocketHttpAuthPasswordController = TextEditingController(
      text: userModel?.websocketHttpAuthPassword?.isNotEmpty == true ? userModel!.websocketHttpAuthPassword! : ''
    );
    // SSL 기본값: false (체크 안함이 기본)
    // HTTP 포트가 3500이면 SSL 사용 안함, 3501이면 SSL 사용
    _apiUseSSL = (userModel?.apiHttpPort ?? 3500) == 3501;
    _websocketUseSSL = userModel?.websocketUseSSL ?? false;
    
    // 디버그 로그: DB 값 로드 확인
    if (kDebugMode) {
      debugPrint('📋 기본설정 다이얼로그 - DB 값 로드:');
      debugPrint('   - API Base URL: ${userModel?.apiBaseUrl ?? "(없음)"}');
      debugPrint('   - API SSL: ${(userModel?.apiHttpsPort ?? 3501) == 3501}');
      debugPrint('   - Company ID: ${userModel?.companyId ?? "(없음)"}');
      debugPrint('   - App Key: ${userModel?.appKey != null && userModel!.appKey!.isNotEmpty ? "[설정됨]" : "(없음)"}');
      debugPrint('   - WebSocket URL: ${userModel?.websocketServerUrl ?? "(없음)"}');
      debugPrint('   - WebSocket Port: ${userModel?.websocketServerPort ?? 6600}');
      debugPrint('   - WebSocket SSL: ${userModel?.websocketUseSSL ?? false}');
      debugPrint('   - WebSocket HTTP Auth ID: ${userModel?.websocketHttpAuthId != null && userModel!.websocketHttpAuthId!.isNotEmpty ? "[설정됨]" : "(없음)"}');
      debugPrint('   - WebSocket HTTP Auth Password: ${userModel?.websocketHttpAuthPassword != null && userModel!.websocketHttpAuthPassword!.isNotEmpty ? "[설정됨]" : "(없음)"}');
    }
  }
  


  @override
  void dispose() {
    _apiBaseUrlController.dispose();
    _companyIdController.dispose();
    _appKeyController.dispose();
    _websocketServerUrlController.dispose();
    _websocketServerPortController.dispose();
    _websocketHttpAuthIdController.dispose();
    _websocketHttpAuthPasswordController.dispose();
    super.dispose();
  }

  // 클립보드 붙여넣기 헬퍼 메서드 (안전한 비동기 처리)
  Future<void> _pasteFromClipboard(TextEditingController controller, String fieldName) async {
    // iOS에서는 포커스를 먼저 설정
    if (mounted) {
      FocusScope.of(context).requestFocus(FocusNode());
    }
    
    try {
      final data = await Clipboard.getData(Clipboard.kTextPlain);
      
      // 비동기 작업 후 mounted 체크
      if (!mounted) return;
      
      if (data?.text != null && data!.text!.isNotEmpty) {
        // iOS에서는 직접 컨트롤러에 설정
        controller.value = TextEditingValue(
          text: data.text!,
          selection: TextSelection.collapsed(offset: data.text!.length),
        );
        
        await DialogUtils.showSuccess(
          context,
          '$fieldName 붙여넣기 완료: ${data.text!.length}자',
          duration: const Duration(seconds: 1),
        );
      } else {
        await DialogUtils.showInfo(
          context,
          '클립보드가 비어있습니다\n\n💡 iOS Tip: 입력 필드를 길게 눌러\n"붙여넣기" 메뉴를 사용하세요',
          duration: const Duration(seconds: 3),
        );
      }
    } catch (e) {
      if (mounted) {
        await DialogUtils.showInfo(
          context,
          'iOS에서는 입력 필드를 길게 눌러\n"붙여넣기" 메뉴를 사용하세요\n\n오류: $e',
          duration: const Duration(seconds: 3),
        );
      }
    }
  }

  Future<void> _handleSave() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    try {
      // SSL 체크에 따라 포트 설정
      // SSL 사용 안함 (기본): apiHttpPort=3500, apiHttpsPort=3501
      // SSL 사용: apiHttpPort=3501, apiHttpsPort=3501
      await context.read<AuthService>().updateUserInfo(
            apiBaseUrl: _apiBaseUrlController.text.trim(),
            apiHttpPort: _apiUseSSL ? 3501 : 3500,  // SSL 안함: 3500, SSL: 3501
            apiHttpsPort: 3501,                      // HTTPS 포트는 항상 3501
            companyId: _companyIdController.text.trim(),
            appKey: _appKeyController.text.trim(),
            websocketServerUrl: _websocketServerUrlController.text.trim(),
            websocketServerPort: int.tryParse(_websocketServerPortController.text.trim()) ?? 6600,
            websocketUseSSL: _websocketUseSSL,
            websocketHttpAuthId: _websocketHttpAuthIdController.text.trim(),
            websocketHttpAuthPassword: _websocketHttpAuthPasswordController.text.trim(),
            amiServerId: 1,
          );

      if (mounted) {
        Navigator.pop(context);
        await DialogUtils.showSuccess(
          context,
          '기본 설정이 저장되었습니다',
        );
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
                    icon: const Icon(Icons.content_paste, size: 16),
                    onPressed: () => _pasteFromClipboard(_apiBaseUrlController, 'API URL'),
                    tooltip: '붙여넣기',
                    padding: const EdgeInsets.all(4),
                    constraints: const BoxConstraints(
                      minWidth: 32,
                      minHeight: 32,
                    ),
                    visualDensity: VisualDensity.compact,
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
              const SizedBox(height: 16),
              // http/https 프로토콜 선택
              Container(
                decoration: BoxDecoration(
                  border: Border.all(color: Colors.grey.shade300),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: SwitchListTile(
                  title: const Text('SSL 사용 (https)', style: TextStyle(fontSize: 13)),
                  subtitle: Text(
                    _apiUseSSL ? 'https:// (보안 연결)' : 'http:// (일반 연결)',
                    style: TextStyle(
                      fontSize: 10,
                      color: _apiUseSSL ? Colors.green : Colors.orange,
                    ),
                  ),
                  value: _apiUseSSL,
                  onChanged: (value) {
                    setState(() {
                      _apiUseSSL = value;
                    });
                  },
                  secondary: Icon(
                    _apiUseSSL ? Icons.lock : Icons.lock_open,
                    color: _apiUseSSL ? Colors.green : Colors.orange,
                    size: 20,
                  ),
                ),
              ),
              // API URL 미리보기
              if (_apiBaseUrlController.text.trim().isNotEmpty) ...[
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
                        'CDR API 주소:',
                        style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '${_apiUseSSL ? 'https' : 'http'}://${_apiBaseUrlController.text.trim()}/api/v2/cdr',
                        style: TextStyle(
                          fontSize: 9,
                          color: _apiUseSSL ? Colors.green.shade700 : Colors.orange.shade700,
                          fontFamily: 'monospace',
                        ),
                        overflow: TextOverflow.ellipsis,
                        maxLines: 2,
                      ),
                    ],
                  ),
                ),
              ],
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
                    icon: const Icon(Icons.content_paste, size: 16),
                    onPressed: () => _pasteFromClipboard(_companyIdController, 'Company ID'),
                    tooltip: '붙여넣기',
                    padding: const EdgeInsets.all(4),
                    constraints: const BoxConstraints(
                      minWidth: 32,
                      minHeight: 32,
                    ),
                    visualDensity: VisualDensity.compact,
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
                    icon: const Icon(Icons.content_paste, size: 16),
                    onPressed: () => _pasteFromClipboard(_appKeyController, 'App-Key'),
                    tooltip: '붙여넣기',
                    padding: const EdgeInsets.all(4),
                    constraints: const BoxConstraints(
                      minWidth: 32,
                      minHeight: 32,
                    ),
                    visualDensity: VisualDensity.compact,
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
              // WebSocket 설정 헤더
              Row(
                children: [
                  const Icon(Icons.settings_input_antenna, size: 18, color: Colors.teal),
                  const SizedBox(width: 8),
                  const Text(
                    'WebSocket 설정',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: Colors.teal),
                  ),
                ],
              ),
              const SizedBox(height: 4),
              const Text(
                'DCMIWS 실시간 수신을 위한 WebSocket 서버 설정',
                style: TextStyle(fontSize: 11, color: Colors.grey),
              ),
              const SizedBox(height: 12),
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
                          icon: const Icon(Icons.content_paste, size: 16),
                          onPressed: () => _pasteFromClipboard(_websocketServerUrlController, 'WebSocket URL'),
                          tooltip: '붙여넣기',
                          padding: const EdgeInsets.all(4),
                          constraints: const BoxConstraints(
                            minWidth: 32,
                            minHeight: 32,
                          ),
                          visualDensity: VisualDensity.compact,
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
              const SizedBox(height: 16),
              // HTTP 인증 정보 (필수)
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.teal.shade50,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.teal.shade200),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(Icons.security, size: 16, color: Colors.teal.shade700),
                        const SizedBox(width: 8),
                        Text(
                          'HTTP 인증 정보 (필수)',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 12,
                            color: Colors.teal.shade900,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'WebSocket 서버 연결 시 HTTP Basic Authentication 사용',
                      style: TextStyle(fontSize: 10, color: Colors.teal.shade700),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: TextFormField(
                      controller: _websocketHttpAuthIdController,
                      style: const TextStyle(fontSize: 13),
                      enableInteractiveSelection: true,
                      enableSuggestions: false,
                      autocorrect: false,
                      keyboardType: TextInputType.text,
                      textInputAction: TextInputAction.next,
                      decoration: InputDecoration(
                        labelText: 'HTTP Auth ID',
                        hintText: '예: admin',
                        prefixIcon: const Icon(Icons.person_outline, size: 18),
                        border: const OutlineInputBorder(),
                        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                        labelStyle: const TextStyle(fontSize: 12),
                        hintStyle: const TextStyle(fontSize: 12),
                        errorStyle: const TextStyle(fontSize: 10),
                        suffixIcon: IconButton(
                          icon: const Icon(Icons.content_paste, size: 16),
                          onPressed: () => _pasteFromClipboard(_websocketHttpAuthIdController, 'HTTP Auth ID'),
                          tooltip: '붙여넣기',
                          padding: const EdgeInsets.all(4),
                          constraints: const BoxConstraints(
                            minWidth: 32,
                            minHeight: 32,
                          ),
                          visualDensity: VisualDensity.compact,
                        ),
                      ),
                      validator: (value) {
                        if (value == null || value.trim().isEmpty) {
                          return 'HTTP Auth ID를 입력해주세요';
                        }
                        return null;
                      },
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _websocketHttpAuthPasswordController,
                style: const TextStyle(fontSize: 13),
                enableInteractiveSelection: true,
                enableSuggestions: false,
                autocorrect: false,
                obscureText: true,
                keyboardType: TextInputType.visiblePassword,
                textInputAction: TextInputAction.done,
                decoration: InputDecoration(
                  labelText: 'HTTP Auth Password',
                  hintText: '비밀번호 입력',
                  prefixIcon: const Icon(Icons.lock_outline, size: 18),
                  border: const OutlineInputBorder(),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                  labelStyle: const TextStyle(fontSize: 12),
                  hintStyle: const TextStyle(fontSize: 12),
                  errorStyle: const TextStyle(fontSize: 10),
                  suffixIcon: IconButton(
                    icon: const Icon(Icons.content_paste, size: 16),
                    onPressed: () => _pasteFromClipboard(_websocketHttpAuthPasswordController, 'HTTP Auth Password'),
                    tooltip: '붙여넣기',
                    padding: const EdgeInsets.all(4),
                    constraints: const BoxConstraints(
                      minWidth: 32,
                      minHeight: 32,
                    ),
                    visualDensity: VisualDensity.compact,
                  ),
                ),
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return 'HTTP Auth Password를 입력해주세요';
                  }
                  return null;
                },
              ),
              // WebSocket URL 미리보기
              if (_websocketServerUrlController.text.trim().isNotEmpty) ...[
                const SizedBox(height: 16),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.teal.shade50,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.teal.shade200),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(Icons.preview, size: 14, color: Colors.teal.shade700),
                          const SizedBox(width: 6),
                          Text(
                            'WebSocket 연결 주소 미리보기',
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                              color: Colors.teal.shade900,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      // 프로토콜 및 기본 주소
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: _websocketUseSSL ? Colors.green.shade100 : Colors.orange.shade100,
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Text(
                              _websocketUseSSL ? 'wss://' : 'ws://',
                              style: TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.bold,
                                color: _websocketUseSSL ? Colors.green.shade900 : Colors.orange.shade900,
                                fontFamily: 'monospace',
                              ),
                            ),
                          ),
                          const SizedBox(width: 4),
                          // HTTP Auth 정보 (있을 경우)
                          if (_websocketHttpAuthIdController.text.trim().isNotEmpty &&
                              _websocketHttpAuthPasswordController.text.trim().isNotEmpty) ...[
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                              decoration: BoxDecoration(
                                color: Colors.blue.shade100,
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(Icons.lock, size: 10, color: Colors.blue.shade900),
                                  const SizedBox(width: 3),
                                  Text(
                                    '${_websocketHttpAuthIdController.text.trim()}:***',
                                    style: TextStyle(
                                      fontSize: 10,
                                      fontWeight: FontWeight.bold,
                                      color: Colors.blue.shade900,
                                      fontFamily: 'monospace',
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            Text(
                              '@',
                              style: TextStyle(
                                fontSize: 10,
                                color: Colors.grey.shade600,
                                fontFamily: 'monospace',
                              ),
                            ),
                          ],
                          Expanded(
                            child: Text(
                              '${_websocketServerUrlController.text.trim()}:${_websocketServerPortController.text.trim()}',
                              style: TextStyle(
                                fontSize: 10,
                                color: Colors.teal.shade900,
                                fontFamily: 'monospace',
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                      // 인증 상태 표시
                      if (_websocketHttpAuthIdController.text.trim().isNotEmpty &&
                          _websocketHttpAuthPasswordController.text.trim().isNotEmpty) ...[
                        const SizedBox(height: 6),
                        Row(
                          children: [
                            Icon(Icons.check_circle, size: 12, color: Colors.green.shade700),
                            const SizedBox(width: 4),
                            Text(
                              'HTTP Basic Authentication 적용됨',
                              style: TextStyle(
                                fontSize: 9,
                                color: Colors.green.shade700,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ],
                        ),
                      ],
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
