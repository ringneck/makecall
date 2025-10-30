import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../services/auth_service.dart';
import '../../services/database_service.dart';
import '../../models/my_extension_model.dart';
import '../../providers/selected_extension_provider.dart';

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

    return Scaffold(
      appBar: AppBar(
        title: const Text('MakeCall'),
      ),
      body: StreamBuilder<List<MyExtensionModel>>(
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
                  const Icon(Icons.error_outline, size: 64, color: Colors.red),
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

          if (extensions.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.phone_disabled,
                    size: 80,
                    color: Colors.grey[400],
                  ),
                  const SizedBox(height: 24),
                  const Text(
                    '저장된 단말번호가 없습니다',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w600,
                      color: Colors.grey,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    '내 정보 탭에서 단말번호를 조회하고 저장해주세요.',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 14,
                      color: Colors.grey[600],
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
            );
          }

          // API 설정을 한 번만 가져오기 (PageView 외부에서)
          final apiBaseUrl = authService.currentUserModel?.apiBaseUrl ?? '설정 필요';
          final hasApiConfig = authService.currentUserModel?.apiBaseUrl != null;

          return Column(
            children: [
              // 단말번호 슬라이드 카드
              Expanded(
                child: PageView.builder(
                  controller: _pageController,
                  onPageChanged: (index) {
                    if (kDebugMode) {
                      debugPrint('📄 [STEP 1] Page changed to index: $index');
                      if (index < extensions.length) {
                        debugPrint('   - Extension from list: ${extensions[index].extension}');
                        debugPrint('   - Name from list: ${extensions[index].name}');
                        debugPrint('   - ID from list: ${extensions[index].id}');
                      }
                    }
                    setState(() {
                      _currentPage = index;
                    });
                    // 선택된 단말번호 업데이트
                    if (index < extensions.length) {
                      context.read<SelectedExtensionProvider>().setSelectedExtension(
                            extensions[index],
                          );
                    }
                  },
                  itemCount: extensions.length,
                  itemBuilder: (context, index) {
                    final extension = extensions[index];
                    if (kDebugMode) {
                      debugPrint('🏗️ ItemBuilder called for index: $index, extension: ${extension.extension}, name: ${extension.name}, id: ${extension.id}');
                    }
                    // 각 카드에 고유한 key 지정하여 제대로 재빌드되도록 함
                    return _buildExtensionCard(
                      extension, 
                      index,
                      apiBaseUrl: apiBaseUrl,
                      hasApiConfig: hasApiConfig,
                      key: ValueKey(extension.id),
                    );
                  },
                ),
              ),

              // 페이지 인디케이터
              if (extensions.length > 1)
                Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      // 이전 버튼
                      IconButton(
                        onPressed: _currentPage > 0
                            ? () {
                                _pageController.previousPage(
                                  duration: const Duration(milliseconds: 300),
                                  curve: Curves.easeInOut,
                                );
                              }
                            : null,
                        icon: const Icon(Icons.chevron_left),
                        color: const Color(0xFF2196F3),
                        disabledColor: Colors.grey[300],
                      ),
                      const SizedBox(width: 8),
                      // 페이지 도트 인디케이터
                      ...List.generate(
                        extensions.length,
                        (index) => Container(
                          width: 8,
                          height: 8,
                          margin: const EdgeInsets.symmetric(horizontal: 4),
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: _currentPage == index
                                ? const Color(0xFF2196F3)
                                : Colors.grey.withAlpha(128),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      // 다음 버튼
                      IconButton(
                        onPressed: _currentPage < extensions.length - 1
                            ? () {
                                _pageController.nextPage(
                                  duration: const Duration(milliseconds: 300),
                                  curve: Curves.easeInOut,
                                );
                              }
                            : null,
                        icon: const Icon(Icons.chevron_right),
                        color: const Color(0xFF2196F3),
                        disabledColor: Colors.grey[300],
                      ),
                    ],
                  ),
                ),

              // 페이지 번호 텍스트
              if (extensions.length > 1)
                Padding(
                  padding: const EdgeInsets.only(bottom: 16),
                  child: Text(
                    '${_currentPage + 1} / ${extensions.length}',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: Colors.grey[600],
                    ),
                  ),
                ),
            ],
          );
        },
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
    required String apiBaseUrl,
    required bool hasApiConfig,
    Key? key,
  }) {
    if (kDebugMode) {
      debugPrint('🎨 [STEP 3] Building card for index: $index');
      debugPrint('   - Extension: ${extension.extension}');
      debugPrint('   - Name: ${extension.name}');
      debugPrint('   - ID: ${extension.id}');
      debugPrint('   - Extension ID: ${extension.extensionId}');
    }
    
    return Card(
      key: key,
        margin: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
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
          child: Column(
            children: [
              // API Base URL을 맨 위에 크게 표시
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
                decoration: BoxDecoration(
                  color: hasApiConfig 
                      ? const Color(0xFF2196F3).withAlpha(26)
                      : Colors.orange.withAlpha(26),
                  borderRadius: const BorderRadius.only(
                    topLeft: Radius.circular(20),
                    topRight: Radius.circular(20),
                  ),
                ),
                child: Column(
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          hasApiConfig ? Icons.cloud_done : Icons.cloud_off,
                          size: 20,
                          color: hasApiConfig ? const Color(0xFF2196F3) : Colors.orange,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          'API 서버',
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: hasApiConfig ? const Color(0xFF2196F3) : Colors.orange,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text(
                      apiBaseUrl,
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: hasApiConfig ? Colors.black87 : Colors.orange[900],
                        letterSpacing: 0.5,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              ),
              
              // 중앙 단말번호 정보
              Expanded(
                child: Center(
                  child: Padding(
                    padding: const EdgeInsets.all(32.0),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        // 단말 이름
                        if (extension.name.isNotEmpty) ...[
                          Text(
                            extension.name,
                            style: const TextStyle(
                              fontSize: 28,
                              fontWeight: FontWeight.bold,
                              color: Colors.black87,
                            ),
                            textAlign: TextAlign.center,
                          ),
                          const SizedBox(height: 16),
                        ],

                        // 단말번호
                        Text(
                          extension.extension,
                          style: const TextStyle(
                            fontSize: 56,
                            fontWeight: FontWeight.w600,
                            color: Color(0xFF2196F3),
                            letterSpacing: 4,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      );
  }
}
