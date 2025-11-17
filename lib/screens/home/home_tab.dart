import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../services/auth_service.dart';
import '../../services/database_service.dart';
import '../../models/my_extension_model.dart';
import '../../providers/selected_extension_provider.dart';
import '../../widgets/call_forward_settings_card.dart';
import '../../widgets/call_state_indicator.dart';
import '../../utils/phone_formatter.dart';

class HomeTab extends StatefulWidget {
  final VoidCallback? onNavigateToProfile;
  
  const HomeTab({super.key, this.onNavigateToProfile});

  @override
  State<HomeTab> createState() => _HomeTabState();
}

class _HomeTabState extends State<HomeTab> {
  final DatabaseService _databaseService = DatabaseService();
  final PageController _pageController = PageController();
  int _currentPage = 0;
  List<MyExtensionModel> _previousExtensions = [];

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final authService = context.watch<AuthService>();
    final userId = authService.currentUser?.uid ?? '';
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      appBar: AppBar(
        title: const Text('홈'),
      ),
      body: SafeArea(
        bottom: true,
        child: userId.isEmpty
            ? Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.login, 
                      size: 64, 
                      color: isDark ? Colors.grey[600] : Colors.grey[400],
                    ),
                    const SizedBox(height: 16),
                    Text(
                      '로그인이 필요합니다',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: isDark ? Colors.grey[300] : Colors.grey[700],
                      ),
                    ),
                  ],
                ),
              )
            : StreamBuilder<List<MyExtensionModel>>(
        stream: _databaseService.getMyExtensions(userId),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (snapshot.hasError) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.error_outline, size: 56, color: Colors.red),
                  const SizedBox(height: 16),
                  Text(
                    '오류가 발생했습니다: ${snapshot.error}',
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            );
          }

          final extensions = snapshot.data ?? [];

          // 단말번호 목록이 변경되었는지 확인
          final extensionsChanged = !_areExtensionListsEqual(_previousExtensions, extensions);
          
          if (extensionsChanged) {
            // 단말번호 목록이 변경되었을 때만 상태 업데이트
            WidgetsBinding.instance.addPostFrameCallback((_) {
              // 이전 목록 저장
              _previousExtensions = List.from(extensions);
              
              // 현재 페이지가 범위를 벗어나면 조정
              if (_currentPage >= extensions.length && extensions.isNotEmpty) {
                setState(() {
                  _currentPage = extensions.length - 1;
                });
                // PageController도 업데이트
                if (_pageController.hasClients) {
                  _pageController.jumpToPage(_currentPage);
                }
              } else if (extensions.isEmpty) {
                setState(() {
                  _currentPage = 0;
                });
              }
              
              // 선택된 단말번호 업데이트
              if (extensions.isNotEmpty && _currentPage < extensions.length) {
                context.read<SelectedExtensionProvider>().setSelectedExtension(
                      extensions[_currentPage],
                    );
              }
            });
          }

          // 사용자 전역 설정 가져오기
          final companyName = authService.currentUserModel?.companyName;
          final hasCompanyName = companyName != null && companyName.isNotEmpty;

          if (extensions.isEmpty) {
            return LayoutBuilder(
              builder: (context, constraints) {
                return SingleChildScrollView(
                  physics: const BouncingScrollPhysics(),
                  child: ConstrainedBox(
                    constraints: BoxConstraints(
                      minHeight: constraints.maxHeight,
                    ),
                    child: Center(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.phone_disabled,
                              size: 64,
                              color: isDark ? Colors.grey[700] : Colors.grey[400],
                            ),
                            const SizedBox(height: 24),
                            Text(
                              '등록된 단말번호가 없습니다',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w600,
                                color: isDark ? Colors.grey[300] : Colors.grey,
                              ),
                            ),
                            const SizedBox(height: 12),
                            Text(
                              '내 정보 탭에서 단말번호를 조회하고 등록해주세요.',
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                fontSize: 13,
                                color: isDark ? Colors.grey[500] : Colors.grey[600],
                              ),
                            ),
                            const SizedBox(height: 32),
                            ElevatedButton.icon(
                              onPressed: () {
                                // 내 정보 탭으로 이동 (인덱스 2)
                                widget.onNavigateToProfile?.call();
                              },
                              icon: const Icon(Icons.person),
                              label: const Text('내 정보로 이동'),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: const Color(0xFF2196F3),
                                foregroundColor: Colors.white,
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 32,
                                  vertical: 16,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                );
              },
            );
          }

          return LayoutBuilder(
            builder: (context, constraints) {
              return SingleChildScrollView(
                physics: const BouncingScrollPhysics(),
                child: ConstrainedBox(
                  constraints: BoxConstraints(
                    minHeight: constraints.maxHeight,
                  ),
                  child: IntrinsicHeight(
                    child: Column(
                      children: [
                        // 단말번호 선택 드롭다운
                        if (extensions.length > 1)
                          Padding(
                            padding: const EdgeInsets.fromLTRB(20, 12, 20, 8),
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 16),
                              decoration: BoxDecoration(
                                color: isDark ? Colors.grey[850] : Colors.white,
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(
                                  color: isDark 
                                      ? const Color(0xFF2196F3).withAlpha(180)
                                      : const Color(0xFF2196F3).withAlpha(77),
                                  width: 2,
                                ),
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.black.withAlpha(isDark ? 26 : 13),
                                    blurRadius: 8,
                                    offset: const Offset(0, 2),
                                  ),
                                ],
                              ),
                              child: DropdownButtonHideUnderline(
                                child: DropdownButton<int>(
                                  value: _currentPage,
                                  isExpanded: true,
                                  dropdownColor: isDark ? Colors.grey[850] : Colors.white,
                                  icon: Icon(
                                    Icons.arrow_drop_down, 
                                    size: 24, 
                                    color: isDark ? Colors.blue[300] : const Color(0xFF2196F3),
                                  ),
                                  style: TextStyle(
                                    fontSize: 15,
                                    fontWeight: FontWeight.w600,
                                    color: isDark ? Colors.grey[300] : Colors.black87,
                                  ),
                                  onChanged: (int? newValue) {
                                    if (newValue != null) {
                                      setState(() {
                                        _currentPage = newValue;
                                      });
                                      // 선택된 단말번호 업데이트
                                      context.read<SelectedExtensionProvider>().setSelectedExtension(
                                            extensions[newValue],
                                          );
                                      if (kDebugMode) {
                                        debugPrint('📄 Dropdown changed to index: $newValue');
                                        debugPrint('   - Extension: ${extensions[newValue].extension}');
                                        debugPrint('   - Name: ${extensions[newValue].name}');
                                      }
                                    }
                                  },
                                  items: extensions.asMap().entries.map((entry) {
                                    final index = entry.key;
                                    final extension = entry.value;
                                    return DropdownMenuItem<int>(
                                      value: index,
                                      child: Row(
                                        children: [
                                          Icon(
                                            Icons.phone_in_talk,
                                            size: 18,
                                            color: isDark ? Colors.blue[300] : const Color(0xFF2196F3),
                                          ),
                                          const SizedBox(width: 12),
                                          Expanded(
                                            child: Text(
                                              extension.name.isNotEmpty 
                                                  ? '${extension.name} (${extension.extension})'
                                                  : extension.extension,
                                              overflow: TextOverflow.ellipsis,
                                            ),
                                          ),
                                        ],
                                      ),
                                    );
                                  }).toList(),
                                ),
                              ),
                            ),
                          ),
                        
                        // 단말번호 정보 카드
                        Expanded(
                          child: Padding(
                            padding: const EdgeInsets.only(bottom: 16),
                            child: _buildExtensionCard(
                              extensions[_currentPage], 
                              _currentPage,
                              companyName: companyName,
                              hasCompanyName: hasCompanyName,
                              authService: authService,
                              key: ValueKey(extensions[_currentPage].id),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              );
            },
          );
        },
        ),
      ),
    );
  }

  // 두 단말번호 목록이 동일한지 비교
  bool _areExtensionListsEqual(List<MyExtensionModel> list1, List<MyExtensionModel> list2) {
    if (list1.length != list2.length) return false;
    
    for (int i = 0; i < list1.length; i++) {
      if (list1[i].id != list2[i].id || 
          list1[i].extension != list2[i].extension ||
          list1[i].extensionId != list2[i].extensionId) {
        return false;
      }
    }
    
    return true;
  }

  Widget _buildExtensionCard(
    MyExtensionModel extension, 
    int index, {
    required String? companyName,
    required bool hasCompanyName,
    required AuthService authService,
    Key? key,
  }) {
    if (kDebugMode) {
      debugPrint('🎨 [STEP 3] Building card for index: $index');
      debugPrint('   - Extension: ${extension.extension}');
      debugPrint('   - Name: ${extension.name}');
      debugPrint('   - ID: ${extension.id}');
      debugPrint('   - Extension ID: ${extension.extensionId}');
    }
    
    // 사용자 전역 WebSocket 설정 가져오기
    final userWsServerUrl = authService.currentUserModel?.websocketServerUrl;
    final userCompanyId = authService.currentUserModel?.companyId;
    final userWsPort = authService.currentUserModel?.websocketServerPort ?? 7099;
    final userUseSSL = authService.currentUserModel?.websocketUseSSL ?? false;
    final userAmiServerId = authService.currentUserModel?.amiServerId ?? 1;
    final userHttpAuthId = authService.currentUserModel?.websocketHttpAuthId;
    final userHttpAuthPassword = authService.currentUserModel?.websocketHttpAuthPassword;
    
    return Card(
      key: key,
        margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
        elevation: 8,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
        ),
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(20),
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                const Color(0xFF2196F3).withAlpha(13),
                Colors.white,
              ],
            ),
          ),
          child: SingleChildScrollView(
            physics: const BouncingScrollPhysics(),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
              // 중앙 단말번호 정보
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 20, 20, 16),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                        // 외부발신 정보 카드
                        if ((extension.externalCidName != null && extension.externalCidName!.isNotEmpty) ||
                            (extension.externalCidNumber != null && extension.externalCidNumber!.isNotEmpty)) ...[
                          Container(
                            width: double.infinity,
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              color: const Color(0xFF4CAF50).withAlpha(26),
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(
                                color: const Color(0xFF4CAF50).withAlpha(77),
                                width: 2,
                              ),
                            ),
                            child: Column(
                              children: [
                                // 외부발신 레이블
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Icon(
                                      Icons.call_made,
                                      size: 16,
                                      color: const Color(0xFF4CAF50),
                                    ),
                                    const SizedBox(width: 8),
                                    Text(
                                      '외부발신 표시정보',
                                      style: TextStyle(
                                        fontSize: 12,
                                        fontWeight: FontWeight.w600,
                                        color: const Color(0xFF4CAF50),
                                        letterSpacing: 0.5,
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 8),
                                
                                // 외부발신 이름
                                if (extension.externalCidName != null && extension.externalCidName!.isNotEmpty)
                                  Text(
                                    extension.externalCidName!,
                                    style: const TextStyle(
                                      fontSize: 18,
                                      fontWeight: FontWeight.bold,
                                      color: Colors.black87,
                                    ),
                                    textAlign: TextAlign.center,
                                  ),
                                
                                if (extension.externalCidName != null && 
                                    extension.externalCidName!.isNotEmpty &&
                                    extension.externalCidNumber != null &&
                                    extension.externalCidNumber!.isNotEmpty)
                                  const SizedBox(height: 6),
                                
                                // 외부발신 번호
                                if (extension.externalCidNumber != null && extension.externalCidNumber!.isNotEmpty)
                                  Text(
                                    PhoneFormatter.format(extension.externalCidNumber!),
                                    style: const TextStyle(
                                      fontSize: 24,
                                      fontWeight: FontWeight.w600,
                                      color: Color(0xFF4CAF50),
                                      letterSpacing: 1.5,
                                    ),
                                    textAlign: TextAlign.center,
                                  ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 16),
                        ],
                        
                        // 통화 상태 표시 (실시간)
                        CallStateIndicator(extension: extension.extension),
                        
                        // 단말 정보 카드
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: const Color(0xFF2196F3).withAlpha(26),
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(
                              color: const Color(0xFF2196F3).withAlpha(77),
                              width: 2,
                            ),
                          ),
                          child: Column(
                            children: [
                              // 단말 레이블
                              Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(
                                    Icons.phone_in_talk,
                                    size: 16,
                                    color: const Color(0xFF2196F3),
                                  ),
                                  const SizedBox(width: 8),
                                  Text(
                                    '단말발신 표시정보',
                                    style: TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.w600,
                                      color: const Color(0xFF2196F3),
                                      letterSpacing: 0.5,
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 8),
                              
                              // 단말 이름
                              if (extension.name.isNotEmpty)
                                Text(
                                  extension.name,
                                  style: const TextStyle(
                                    fontSize: 18,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.black87,
                                  ),
                                  textAlign: TextAlign.center,
                                ),
                              
                              if (extension.name.isNotEmpty)
                                const SizedBox(height: 6),
                              
                              // 단말번호
                              Text(
                                PhoneFormatter.format(extension.extension),
                                style: const TextStyle(
                                  fontSize: 24,
                                  fontWeight: FontWeight.w600,
                                  color: Color(0xFF2196F3),
                                  letterSpacing: 1.5,
                                ),
                                textAlign: TextAlign.center,
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 16),
                        
                        // 착신전환 설정 카드 (항상 표시)
                        CallForwardSettingsCard(
                          extension: extension,
                          tenantId: userCompanyId,
                          wsServerAddress: userWsServerUrl,
                          wsServerPort: userWsPort,
                          useSSL: userUseSSL,
                          amiServerId: userAmiServerId,
                          httpAuthId: userHttpAuthId,
                          httpAuthPassword: userHttpAuthPassword,
                        ),
                        const SizedBox(height: 16),
                  ],
                ),
              ),
              ],
            ),
          ),
        ),
      );
  }
}
