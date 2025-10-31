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
      body: SafeArea(
        bottom: true,
        child: StreamBuilder<List<MyExtensionModel>>(
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
                      ),
                    ),
                  ),
                );
              },
            );
          }

          // API 설정을 한 번만 가져오기 (PageView 외부에서)
          final companyName = authService.currentUserModel?.companyName ?? '회사명 설정 필요';
          final hasCompanyName = authService.currentUserModel?.companyName != null;

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
                            padding: const EdgeInsets.fromLTRB(20, 16, 20, 12),
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 16),
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(
                                  color: const Color(0xFF2196F3).withAlpha(77),
                                  width: 2,
                                ),
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.black.withAlpha(13),
                                    blurRadius: 8,
                                    offset: const Offset(0, 2),
                                  ),
                                ],
                              ),
                              child: DropdownButtonHideUnderline(
                                child: DropdownButton<int>(
                                  value: _currentPage,
                                  isExpanded: true,
                                  icon: const Icon(Icons.arrow_drop_down, color: Color(0xFF2196F3)),
                                  style: const TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.w600,
                                    color: Colors.black87,
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
                                            size: 20,
                                            color: const Color(0xFF2196F3),
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
    required String companyName,
    required bool hasCompanyName,
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
              // 회사명을 맨 위에 크게 표시
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
                decoration: BoxDecoration(
                  color: hasCompanyName 
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
                          hasCompanyName ? Icons.business : Icons.business_outlined,
                          size: 20,
                          color: hasCompanyName ? const Color(0xFF2196F3) : Colors.orange,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          '회사',
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: hasCompanyName ? const Color(0xFF2196F3) : Colors.orange,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text(
                      companyName,
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: hasCompanyName ? Colors.black87 : Colors.orange[900],
                        letterSpacing: 0.5,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              ),
              
              // 중앙 단말번호 정보
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 20, 20, 24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                        // 외부발신 정보 카드
                        if ((extension.externalCidName != null && extension.externalCidName!.isNotEmpty) ||
                            (extension.externalCidNumber != null && extension.externalCidNumber!.isNotEmpty)) ...[
                          Container(
                            width: double.infinity,
                            padding: const EdgeInsets.all(20),
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
                                      size: 20,
                                      color: const Color(0xFF4CAF50),
                                    ),
                                    const SizedBox(width: 8),
                                    Text(
                                      '외부발신 표시정보',
                                      style: TextStyle(
                                        fontSize: 14,
                                        fontWeight: FontWeight.w600,
                                        color: const Color(0xFF4CAF50),
                                        letterSpacing: 1,
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 12),
                                
                                // 외부발신 이름
                                if (extension.externalCidName != null && extension.externalCidName!.isNotEmpty)
                                  Text(
                                    extension.externalCidName!,
                                    style: const TextStyle(
                                      fontSize: 24,
                                      fontWeight: FontWeight.bold,
                                      color: Colors.black87,
                                    ),
                                    textAlign: TextAlign.center,
                                  ),
                                
                                if (extension.externalCidName != null && 
                                    extension.externalCidName!.isNotEmpty &&
                                    extension.externalCidNumber != null &&
                                    extension.externalCidNumber!.isNotEmpty)
                                  const SizedBox(height: 8),
                                
                                // 외부발신 번호
                                if (extension.externalCidNumber != null && extension.externalCidNumber!.isNotEmpty)
                                  Text(
                                    extension.externalCidNumber!,
                                    style: const TextStyle(
                                      fontSize: 36,
                                      fontWeight: FontWeight.w600,
                                      color: Color(0xFF4CAF50),
                                      letterSpacing: 2,
                                    ),
                                    textAlign: TextAlign.center,
                                  ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 24),
                        ],
                        
                        // 단말 정보 카드
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(20),
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
                                    size: 20,
                                    color: const Color(0xFF2196F3),
                                  ),
                                  const SizedBox(width: 8),
                                  Text(
                                    '단말발신 표시정보',
                                    style: TextStyle(
                                      fontSize: 14,
                                      fontWeight: FontWeight.w600,
                                      color: const Color(0xFF2196F3),
                                      letterSpacing: 1,
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 12),
                              
                              // 단말 이름
                              if (extension.name.isNotEmpty)
                                Text(
                                  extension.name,
                                  style: const TextStyle(
                                    fontSize: 24,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.black87,
                                  ),
                                  textAlign: TextAlign.center,
                                ),
                              
                              if (extension.name.isNotEmpty)
                                const SizedBox(height: 8),
                              
                              // 단말번호
                              Text(
                                extension.extension,
                                style: const TextStyle(
                                  fontSize: 36,
                                  fontWeight: FontWeight.w600,
                                  color: Color(0xFF2196F3),
                                  letterSpacing: 2,
                                ),
                                textAlign: TextAlign.center,
                              ),
                            ],
                          ),
                        ),
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
