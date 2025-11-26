import 'package:flutter/material.dart';
import '../../utils/dialog_utils.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../../services/auth_service.dart';
import '../../services/database_service.dart';

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
          duration: const Duration(seconds: 1),
        );
      }
    } catch (e) {
      if (mounted) {
        await DialogUtils.showInfo(
          context,
          'iOS에서는 입력 필드를 길게 눌러\n"붙여넣기" 메뉴를 사용하세요\n\n오류: $e',
          duration: const Duration(seconds: 1),
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

      if (mounted && Navigator.canPop(context)) {
        Navigator.pop(context);
        // Navigator.pop 후 약간의 딜레이를 주어 안전하게 새 다이얼로그 표시
        await Future.delayed(const Duration(milliseconds: 100));
        
        if (mounted) {
          await DialogUtils.showSuccess(
            context,
            '기본 설정이 저장되었습니다',
          );
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
  
  /// 📤 API 설정 내보내기 (isAdmin 전용)
  Future<void> _exportApiSettings() async {
    final userModel = context.read<AuthService>().currentUserModel;
    
    if (userModel == null) {
      await DialogUtils.showError(context, '사용자 정보를 찾을 수 없습니다');
      return;
    }
    
    // 조직명(회사명) 확인
    if (userModel.companyName == null || userModel.companyName!.isEmpty) {
      await DialogUtils.showError(context, '조직명(회사명)이 설정되지 않았습니다.\n기본 API 설정에서 회사명을 먼저 입력하고 저장해주세요.');
      return;
    }
    
    // App-Key 확인
    if (userModel.appKey == null || userModel.appKey!.isEmpty) {
      await DialogUtils.showError(context, 'REST API App-Key가 설정되지 않았습니다.\n먼저 App-Key를 입력하고 저장해주세요.');
      return;
    }
    
    // 확인 다이얼로그
    final confirmed = await DialogUtils.showConfirm(
      context,
      '현재 설정을 내보내시겠습니까?\n\n조직명: ${userModel.companyName}\nApp-Key: ${userModel.appKey}\n\n같은 조직의 다른 사용자가 이 설정을 가져올 수 있습니다.',
      title: 'API 설정 내보내기',
    );
    
    if (confirmed != true) return;
    
    setState(() => _isLoading = true);
    
    try {
      final dbService = DatabaseService();
      
      await dbService.exportApiSettings(
        userId: userModel.uid,
        userEmail: userModel.email,
        organizationName: userModel.companyName!,
        appKey: userModel.appKey!,
        companyName: userModel.companyName,
        companyId: userModel.companyId,
        apiBaseUrl: userModel.apiBaseUrl,
        apiHttpPort: userModel.apiHttpPort,
        apiHttpsPort: userModel.apiHttpsPort,
        websocketServerUrl: userModel.websocketServerUrl,
        websocketServerPort: userModel.websocketServerPort,
        websocketUseSSL: userModel.websocketUseSSL,
        websocketHttpAuthId: userModel.websocketHttpAuthId,
        websocketHttpAuthPassword: userModel.websocketHttpAuthPassword,
        amiServerId: userModel.amiServerId,
      );
      
      if (mounted) {
        await DialogUtils.showSuccess(
          context,
          'API 설정이 성공적으로 내보내졌습니다.\n\n조직 구성원이 동일한 조직명과 App-Key로 설정을 가져올 수 있습니다.',
        );
      }
    } catch (e) {
      if (mounted) {
        await DialogUtils.showError(context, 'API 설정 내보내기 실패:\n$e');
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }
  
  /// 📥 API 설정 가져오기 다이얼로그 표시
  Future<void> _showImportDialog() async {
    final userModel = context.read<AuthService>().currentUserModel;
    
    if (userModel == null) {
      await DialogUtils.showError(context, '사용자 정보를 찾을 수 없습니다');
      return;
    }
    
    // 조직명(회사명) 확인 - 기본 다이얼로그로 안내
    if (userModel.companyName == null || userModel.companyName!.isEmpty) {
      await DialogUtils.showInfo(
        context,
        '조직명(회사명)이 설정되지 않았습니다.\n\n기본 API 설정에서 "회사명"을 먼저 입력하고 저장한 후\n설정을 가져올 수 있습니다.\n\n예: 회사명 = 우리회사',
        title: '조직명 설정 필요',
      );
      return;
    }
    
    // App-Key 입력 확인
    final appKey = _appKeyController.text.trim();
    if (appKey.isEmpty) {
      await DialogUtils.showError(context, 'REST API App-Key를 먼저 입력해주세요.');
      return;
    }
    
    setState(() => _isLoading = true);
    
    try {
      final dbService = DatabaseService();
      
      // 공유 설정 조회
      final sharedSettings = await dbService.searchSharedApiSettings(
        organizationName: userModel.companyName!,
        appKey: appKey,
      );
      
      if (mounted) {
        setState(() => _isLoading = false);
      }
      
      if (sharedSettings.isEmpty) {
        if (mounted) {
          await DialogUtils.showInfo(
            context,
            '조직명 "${userModel.companyName}"과 입력한 App-Key로\n내보낸 설정을 찾을 수 없습니다.\n\n관리자에게 먼저 설정을 내보내도록 요청해주세요.',
            title: '설정을 찾을 수 없음',
          );
        }
        return;
      }
      
      // 가져올 설정 선택 다이얼로그 표시
      if (mounted) {
        await _showSelectSettingDialog(sharedSettings);
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        await DialogUtils.showError(context, '설정 조회 실패:\n$e');
      }
    }
  }
  
  /// 📋 가져올 설정 선택 다이얼로그
  Future<void> _showSelectSettingDialog(List<Map<String, dynamic>> settings) async {
    final selectedSetting = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('API 설정 선택', style: TextStyle(fontSize: 15)),
          content: SizedBox(
            width: double.maxFinite,
            child: ListView.builder(
              shrinkWrap: true,
              itemCount: settings.length,
              itemBuilder: (context, index) {
                final setting = settings[index];
                final exportedAt = setting['lastUpdatedAt'] != null
                    ? DateTime.parse(setting['lastUpdatedAt'] as String)
                    : DateTime.parse(setting['exportedAt'] as String);
                
                return ListTile(
                  title: Text(
                    setting['apiBaseUrl'] ?? '설정 없음',
                    style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
                  ),
                  subtitle: Text(
                    '내보낸 사람: ${setting['exportedByEmail']}\n'
                    '업데이트: ${exportedAt.year}-${exportedAt.month.toString().padLeft(2, '0')}-${exportedAt.day.toString().padLeft(2, '0')} '
                    '${exportedAt.hour.toString().padLeft(2, '0')}:${exportedAt.minute.toString().padLeft(2, '0')}',
                    style: const TextStyle(fontSize: 12),
                  ),
                  onTap: () => Navigator.pop(context, setting),
                );
              },
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('취소', style: TextStyle(fontSize: 13)),
            ),
          ],
        );
      },
    );
    
    if (selectedSetting == null || !mounted) return;
    
    // 선택한 설정 가져오기
    await _importSelectedSetting(selectedSetting);
  }
  
  /// 💾 선택한 설정 가져오기 및 적용
  Future<void> _importSelectedSetting(Map<String, dynamic> setting) async {
    final userModel = context.read<AuthService>().currentUserModel;
    if (userModel == null) return;
    
    setState(() => _isLoading = true);
    
    try {
      final dbService = DatabaseService();
      
      // 사용자 계정에 설정 적용
      await dbService.importApiSettings(
        userId: userModel.uid,
        sharedSettings: setting,
      );
      
      // AuthService 사용자 모델 새로고침
      await context.read<AuthService>().refreshUserModel();
      
      if (mounted && Navigator.canPop(context)) {
        Navigator.pop(context);
        await Future.delayed(const Duration(milliseconds: 100));
        
        if (mounted) {
          await DialogUtils.showSuccess(
            context,
            'API 설정을 성공적으로 가져왔습니다.\n\n설정이 자동으로 적용되었습니다.',
          );
        }
      }
    } catch (e) {
      if (mounted) {
        await DialogUtils.showError(context, '설정 가져오기 실패:\n$e');
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final screenWidth = MediaQuery.of(context).size.width;
    final dialogWidth = screenWidth > 600 ? 500.0 : screenWidth * 0.9;
    final userModel = context.watch<AuthService>().currentUserModel;
    final isAdmin = userModel?.isAdmin ?? false;
    final companyName = userModel?.companyName;
    
    return AlertDialog(
      title: Row(
        children: [
          const Expanded(
            child: Text('기본 API 설정', style: TextStyle(fontSize: 15)),
          ),
          // 조직명(회사명)이 있고 isAdmin인 경우 내보내기 버튼 표시
          if (isAdmin && companyName != null && companyName.isNotEmpty)
            TextButton.icon(
              onPressed: _exportApiSettings,
              icon: const Icon(Icons.upload, size: 16),
              label: const Text('내보내기', style: TextStyle(fontSize: 12)),
              style: TextButton.styleFrom(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              ),
            ),
          // 일반 사용자 - 항상 가져오기 버튼 표시 (조직명 없으면 안내 다이얼로그)
          if (!isAdmin)
            TextButton.icon(
              onPressed: _showImportDialog,
              icon: const Icon(Icons.download, size: 16),
              label: const Text('가져오기', style: TextStyle(fontSize: 12)),
              style: TextButton.styleFrom(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              ),
            ),
        ],
      ),
      contentPadding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
      content: SizedBox(
        width: dialogWidth,
        child: SingleChildScrollView(
          child: Form(
            key: _formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
              // REST API 설정 헤더 (WebSocket과 동일한 스타일)
              Row(
                children: [
                  Icon(Icons.api, size: 16, color: isDark ? Colors.blue[300] : Colors.blue),
                  const SizedBox(width: 6),
                  Text(
                    'REST API 설정',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: isDark ? Colors.blue[300] : Colors.blue),
                  ),
                ],
              ),
              const SizedBox(height: 3),
              Text(
                'REST API 서버 설정',
                style: TextStyle(fontSize: 10, color: isDark ? Colors.grey[400] : Colors.grey),
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
                  labelText: 'REST API Base URL',
                  hintText: '예: api.makecall.io',
                  border: const OutlineInputBorder(),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                  labelStyle: const TextStyle(fontSize: 12),
                  hintStyle: const TextStyle(fontSize: 12),
                  errorStyle: const TextStyle(fontSize: 10),
                  suffixIcon: IconButton(
                    icon: const Icon(Icons.content_copy, size: 16),
                    onPressed: () async {
                      final value = _apiBaseUrlController.text.trim();
                      if (value.isNotEmpty) {
                        Clipboard.setData(ClipboardData(text: value));
                        await DialogUtils.showCopySuccess(context, 'REST API Base URL', value);
                      }
                    },
                    tooltip: '복사',
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
                    return 'REST API Base URL을 입력해주세요';
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
                  border: Border.all(color: isDark ? Colors.grey.shade700 : Colors.grey.shade300),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: SwitchListTile(
                  title: const Text('SSL 사용 (https)', style: TextStyle(fontSize: 13)),
                  subtitle: Text(
                    _apiUseSSL ? 'https:// (보안 연결)' : 'http:// (일반 연결)',
                    style: TextStyle(
                      fontSize: 10,
                      color: _apiUseSSL 
                          ? (isDark ? Colors.green[300] : Colors.green)
                          : (isDark ? Colors.orange[300] : Colors.orange),
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
                    color: _apiUseSSL 
                        ? (isDark ? Colors.green[300] : Colors.green)
                        : (isDark ? Colors.orange[300] : Colors.orange),
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
                    color: isDark ? Colors.blue[900]!.withValues(alpha: 0.3) : Colors.blue.shade50,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: isDark ? Colors.blue[700]! : Colors.blue.shade200,
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(
                            Icons.preview, 
                            size: 14, 
                            color: isDark ? Colors.blue[300] : Colors.blue.shade700,
                          ),
                          const SizedBox(width: 6),
                          Text(
                            'REST API 연결 주소 미리보기',
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                              color: isDark ? Colors.blue[300] : Colors.blue.shade900,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: _apiUseSSL 
                                  ? (isDark ? Colors.green[900]!.withValues(alpha: 0.3) : Colors.green.shade100)
                                  : (isDark ? Colors.orange[900]!.withValues(alpha: 0.3) : Colors.orange.shade100),
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Text(
                              _apiUseSSL ? 'https://' : 'http://',
                              style: TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.bold,
                                color: _apiUseSSL 
                                    ? (isDark ? Colors.green[300] : Colors.green.shade900)
                                    : (isDark ? Colors.orange[300] : Colors.orange.shade900),
                                fontFamily: 'monospace',
                              ),
                            ),
                          ),
                          const SizedBox(width: 4),
                          Expanded(
                            child: Text(
                              '${_apiBaseUrlController.text.trim()}/api/v2',
                              style: TextStyle(
                                fontSize: 10,
                                color: isDark ? Colors.blue[300] : Colors.blue.shade900,
                                fontFamily: 'monospace',
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
              const SizedBox(height: 16),
              // API 인증 정보 (WebSocket과 동일한 스타일)
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: isDark ? Colors.blue[900]!.withValues(alpha: 0.3) : Colors.blue.shade50,
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(
                    color: isDark ? Colors.blue[700]! : Colors.blue.shade200,
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(
                          Icons.security, 
                          size: 14, 
                          color: isDark ? Colors.blue[300] : Colors.blue.shade700,
                        ),
                        const SizedBox(width: 6),
                        Text(
                          'REST API 인증 정보 (필수)',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 11,
                            color: isDark ? Colors.blue[300] : Colors.blue.shade900,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 3),
                    Text(
                      'REST API 연결 시 Company ID와 App-Key 사용',
                      style: TextStyle(
                        fontSize: 9, 
                        color: isDark ? Colors.blue[400] : Colors.blue.shade700,
                      ),
                    ),
                  ],
                ),
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
                  hintText: '예: company001',
                  prefixIcon: const Icon(Icons.business, size: 18),
                  border: const OutlineInputBorder(),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                  labelStyle: const TextStyle(fontSize: 12),
                  hintStyle: const TextStyle(fontSize: 12),
                  errorStyle: const TextStyle(fontSize: 10),
                  suffixIcon: IconButton(
                    icon: const Icon(Icons.content_copy, size: 16),
                    onPressed: () async {
                      final value = _companyIdController.text.trim();
                      if (value.isNotEmpty) {
                        Clipboard.setData(ClipboardData(text: value));
                        await DialogUtils.showCopySuccess(context, 'Company ID', value);
                      }
                    },
                    tooltip: '복사',
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
                  hintText: '예: your-app-key-here',
                  prefixIcon: const Icon(Icons.vpn_key, size: 18),
                  border: const OutlineInputBorder(),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                  labelStyle: const TextStyle(fontSize: 12),
                  hintStyle: const TextStyle(fontSize: 12),
                  errorStyle: const TextStyle(fontSize: 10),
                  suffixIcon: IconButton(
                    icon: const Icon(Icons.content_copy, size: 16),
                    onPressed: () async {
                      final value = _appKeyController.text.trim();
                      if (value.isNotEmpty) {
                        Clipboard.setData(ClipboardData(text: value));
                        await DialogUtils.showCopySuccess(context, 'App-Key', value);
                      }
                    },
                    tooltip: '복사',
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
                  Icon(Icons.settings_input_antenna, size: 16, color: isDark ? Colors.teal[300] : Colors.teal),
                  const SizedBox(width: 6),
                  Text(
                    'WebSocket 설정',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: isDark ? Colors.teal[300] : Colors.teal),
                  ),
                ],
              ),
              const SizedBox(height: 3),
              Text(
                'DCMIWS WebSocket 서버 설정',
                style: TextStyle(fontSize: 10, color: isDark ? Colors.grey[400] : Colors.grey),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    flex: 2,
                    child: TextFormField(
                      controller: _websocketServerUrlController,
                      style: const TextStyle(fontSize: 12),
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
                          icon: const Icon(Icons.content_copy, size: 16),
                          onPressed: () async {
                            final value = _websocketServerUrlController.text.trim();
                            if (value.isNotEmpty) {
                              Clipboard.setData(ClipboardData(text: value));
                              await DialogUtils.showCopySuccess(context, 'WebSocket URL', value);
                            }
                          },
                          tooltip: '복사',
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
                  const SizedBox(width: 8),
                  Expanded(
                    flex: 1,
                    child: TextFormField(
                      controller: _websocketServerPortController,
                      style: const TextStyle(fontSize: 12),
                      decoration: const InputDecoration(
                        labelText: '포트',
                        hintText: '8800',
                        border: OutlineInputBorder(),
                        contentPadding: EdgeInsets.symmetric(horizontal: 8, vertical: 12),
                        labelStyle: TextStyle(fontSize: 11),
                        hintStyle: TextStyle(fontSize: 11),
                        errorStyle: TextStyle(fontSize: 9),
                      ),
                      keyboardType: TextInputType.number,
                      inputFormatters: [
                        FilteringTextInputFormatter.digitsOnly,
                      ],
                      validator: (value) {
                        if (value != null && value.trim().isNotEmpty) {
                          final port = int.tryParse(value.trim());
                          if (port == null || port < 1 || port > 65535) {
                            return '1-65535';
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
                  border: Border.all(color: isDark ? Colors.grey.shade700 : Colors.grey.shade300),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: SwitchListTile(
                  title: const Text('SSL 사용 (wss)', style: TextStyle(fontSize: 13)),
                  subtitle: Text(
                    _websocketUseSSL ? 'wss:// (보안 연결)' : 'ws:// (일반 연결)',
                    style: TextStyle(
                      fontSize: 10,
                      color: _websocketUseSSL 
                          ? (isDark ? Colors.green[300] : Colors.green)
                          : (isDark ? Colors.orange[300] : Colors.orange),
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
                    color: _websocketUseSSL 
                        ? (isDark ? Colors.green[300] : Colors.green)
                        : (isDark ? Colors.orange[300] : Colors.orange),
                    size: 20,
                  ),
                ),
              ),
              const SizedBox(height: 16),
              // HTTP 인증 정보 (필수)
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: isDark ? Colors.teal[900]!.withValues(alpha: 0.3) : Colors.teal.shade50,
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(
                    color: isDark ? Colors.teal[700]! : Colors.teal.shade200,
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(
                          Icons.security, 
                          size: 14, 
                          color: isDark ? Colors.teal[300] : Colors.teal.shade700,
                        ),
                        const SizedBox(width: 6),
                        Text(
                          'HTTP 인증 정보 (WebSocket 사용 시 필수)',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 11,
                            color: isDark ? Colors.teal[300] : Colors.teal.shade900,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 3),
                    Text(
                      'WebSocket 서버 연결 시 HTTP Basic Authentication 사용',
                      style: TextStyle(
                        fontSize: 9, 
                        color: isDark ? Colors.teal[400] : Colors.teal.shade700,
                      ),
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
                          icon: const Icon(Icons.content_copy, size: 16),
                          onPressed: () async {
                            final value = _websocketHttpAuthIdController.text.trim();
                            if (value.isNotEmpty) {
                              Clipboard.setData(ClipboardData(text: value));
                              await DialogUtils.showCopySuccess(context, 'HTTP Auth ID', value);
                            }
                          },
                          tooltip: '복사',
                          padding: const EdgeInsets.all(4),
                          constraints: const BoxConstraints(
                            minWidth: 32,
                            minHeight: 32,
                          ),
                          visualDensity: VisualDensity.compact,
                        ),
                      ),
                      validator: (value) {
                        // WebSocket 서버 주소가 입력되었을 때만 필수
                        final wsServerUrl = _websocketServerUrlController.text.trim();
                        if (wsServerUrl.isNotEmpty) {
                          if (value == null || value.trim().isEmpty) {
                            return 'HTTP Auth ID를 입력해주세요';
                          }
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
                    icon: const Icon(Icons.content_copy, size: 16),
                    onPressed: () async {
                      final value = _websocketHttpAuthPasswordController.text.trim();
                      if (value.isNotEmpty) {
                        Clipboard.setData(ClipboardData(text: value));
                        await DialogUtils.showCopySuccess(context, 'HTTP Auth Password', value);
                      }
                    },
                    tooltip: '복사',
                    padding: const EdgeInsets.all(4),
                    constraints: const BoxConstraints(
                      minWidth: 32,
                      minHeight: 32,
                    ),
                    visualDensity: VisualDensity.compact,
                  ),
                ),
                validator: (value) {
                  // WebSocket 서버 주소가 입력되었을 때만 필수
                  final wsServerUrl = _websocketServerUrlController.text.trim();
                  if (wsServerUrl.isNotEmpty) {
                    if (value == null || value.trim().isEmpty) {
                      return 'HTTP Auth Password를 입력해주세요';
                    }
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
                    color: isDark ? Colors.teal[900]!.withValues(alpha: 0.3) : Colors.teal.shade50,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: isDark ? Colors.teal[700]! : Colors.teal.shade200,
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(
                            Icons.preview, 
                            size: 14, 
                            color: isDark ? Colors.teal[300] : Colors.teal.shade700,
                          ),
                          const SizedBox(width: 6),
                          Text(
                            'WebSocket 연결 주소 미리보기',
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                              color: isDark ? Colors.teal[300] : Colors.teal.shade900,
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
                              color: _websocketUseSSL 
                                  ? (isDark ? Colors.green[900]!.withValues(alpha: 0.3) : Colors.green.shade100)
                                  : (isDark ? Colors.orange[900]!.withValues(alpha: 0.3) : Colors.orange.shade100),
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Text(
                              _websocketUseSSL ? 'wss://' : 'ws://',
                              style: TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.bold,
                                color: _websocketUseSSL 
                                    ? (isDark ? Colors.green[300] : Colors.green.shade900)
                                    : (isDark ? Colors.orange[300] : Colors.orange.shade900),
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
                                color: isDark ? Colors.blue[900]!.withValues(alpha: 0.3) : Colors.blue.shade100,
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(Icons.lock, size: 10, color: isDark ? Colors.blue[300] : Colors.blue.shade900),
                                  const SizedBox(width: 3),
                                  Text(
                                    '${_websocketHttpAuthIdController.text.trim()}:***',
                                    style: TextStyle(
                                      fontSize: 10,
                                      fontWeight: FontWeight.bold,
                                      color: isDark ? Colors.blue[300] : Colors.blue.shade900,
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
                                color: isDark ? Colors.grey[400] : Colors.grey.shade600,
                                fontFamily: 'monospace',
                              ),
                            ),
                          ],
                          Expanded(
                            child: Text(
                              '${_websocketServerUrlController.text.trim()}:${_websocketServerPortController.text.trim()}',
                              style: TextStyle(
                                fontSize: 10,
                                color: isDark ? Colors.teal[300] : Colors.teal.shade900,
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
                            Icon(Icons.check_circle, size: 12, color: isDark ? Colors.green[300] : Colors.green.shade700),
                            const SizedBox(width: 4),
                            Text(
                              'HTTP Basic Authentication 적용됨',
                              style: TextStyle(
                                fontSize: 9,
                                color: isDark ? Colors.green[300] : Colors.green.shade700,
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
