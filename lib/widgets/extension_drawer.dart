import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../services/auth_service.dart';
import '../services/database_service.dart';
import '../models/my_extension_model.dart';
import '../providers/selected_extension_provider.dart';
import '../widgets/call_forward_settings_card.dart';
import '../widgets/call_state_indicator.dart';
import '../utils/phone_formatter.dart';

class ExtensionDrawer extends StatefulWidget {
  const ExtensionDrawer({super.key});

  @override
  State<ExtensionDrawer> createState() => _ExtensionDrawerState();
}

class _ExtensionDrawerState extends State<ExtensionDrawer> {
  final DatabaseService _databaseService = DatabaseService();
  final PageController _pageController = PageController();
  int _currentPage = 0;
  List<MyExtensionModel> _previousExtensions = [];
  bool _isInitialized = false;

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  // 마지막 선택된 단말번호 저장
  Future<void> _saveLastSelectedExtension(String extensionId) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final authService = context.read<AuthService>();
      final userId = authService.currentUser?.uid ?? '';
      
      if (userId.isNotEmpty) {
        await prefs.setString('last_selected_extension_$userId', extensionId);
        if (kDebugMode) {
          debugPrint('💾 마지막 선택 단말번호 저장: $extensionId (user: $userId)');
        }
      }
    } catch (e) {
      if (kDebugMode) {
        debugPrint('❌ 마지막 선택 단말번호 저장 실패: $e');
      }
    }
  }

  // 마지막 선택된 단말번호 불러오기
  Future<String?> _loadLastSelectedExtension() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final authService = context.read<AuthService>();
      final userId = authService.currentUser?.uid ?? '';
      
      if (userId.isNotEmpty) {
        final lastExtensionId = prefs.getString('last_selected_extension_$userId');
        if (kDebugMode) {
          debugPrint('📂 마지막 선택 단말번호 불러오기: $lastExtensionId (user: $userId)');
        }
        return lastExtensionId;
      }
    } catch (e) {
      if (kDebugMode) {
        debugPrint('❌ 마지막 선택 단말번호 불러오기 실패: $e');
      }
    }
    return null;
  }

  // 단말번호 목록에서 마지막 선택 단말번호 찾기
  int _findExtensionIndex(List<MyExtensionModel> extensions, String? lastExtensionId) {
    if (lastExtensionId == null || lastExtensionId.isEmpty) {
      return 0;
    }
    
    final index = extensions.indexWhere((ext) => ext.id == lastExtensionId);
    if (index != -1) {
      if (kDebugMode) {
        debugPrint('✅ 마지막 선택 단말번호 찾음: index=$index, id=$lastExtensionId');
      }
      return index;
    }
    
    if (kDebugMode) {
      debugPrint('⚠️ 마지막 선택 단말번호를 찾을 수 없음, 첫 번째 단말번호 선택');
    }
    return 0;
  }

  @override
  Widget build(BuildContext context) {
    final authService = context.watch<AuthService>();
    final userId = authService.currentUser?.uid ?? '';

    return Drawer(
      backgroundColor: const Color(0xFF263238), // 어두운 배경색
      child: SafeArea(
        child: Container(
          color: const Color(0xFF263238),
          child: StreamBuilder<List<MyExtensionModel>>(
                  stream: _databaseService.getMyExtensions(userId),
                  builder: (context, snapshot) {
                    if (snapshot.connectionState == ConnectionState.waiting) {
                      return const Center(
                        child: CircularProgressIndicator(color: Colors.white70),
                      );
                  }

                  if (snapshot.hasError) {
                    return Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(Icons.error_outline, size: 56, color: Colors.redAccent),
                          const SizedBox(height: 16),
                          Text(
                            '오류가 발생했습니다: ${snapshot.error}',
                            textAlign: TextAlign.center,
                            style: const TextStyle(color: Colors.white70),
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
                    WidgetsBinding.instance.addPostFrameCallback((_) async {
                      // 이전 목록 저장
                      _previousExtensions = List.from(extensions);
                      
                      // 첫 초기화 시 마지막 선택된 단말번호 불러오기
                      if (!_isInitialized && extensions.isNotEmpty) {
                        _isInitialized = true;
                        final lastExtensionId = await _loadLastSelectedExtension();
                        final initialIndex = _findExtensionIndex(extensions, lastExtensionId);
                        
                        if (initialIndex != _currentPage) {
                          setState(() {
                            _currentPage = initialIndex;
                          });
                          // PageController도 업데이트
                          if (_pageController.hasClients) {
                            _pageController.jumpToPage(_currentPage);
                          }
                        }
                        
                        // 선택된 단말번호 업데이트
                        if (_currentPage < extensions.length) {
                          context.read<SelectedExtensionProvider>().setSelectedExtension(
                                extensions[_currentPage],
                              );
                        }
                        
                        if (kDebugMode) {
                          debugPrint('🎯 초기화 완료: index=$_currentPage, extension=${extensions[_currentPage].extension}');
                        }
                      } else {
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
                                    const Icon(
                                      Icons.phone_disabled,
                                      size: 64,
                                      color: Colors.white54,
                                    ),
                                    const SizedBox(height: 24),
                                    const Text(
                                      '등록된 단말번호가 없습니다',
                                      style: TextStyle(
                                        fontSize: 16,
                                        fontWeight: FontWeight.w600,
                                        color: Colors.white70,
                                      ),
                                    ),
                                    const SizedBox(height: 12),
                                    const Text(
                                      '왼쪽 상단 프로필 설정에서 단말번호를 조회하고 등록해주세요.',
                                      textAlign: TextAlign.center,
                                      style: TextStyle(
                                        fontSize: 13,
                                        color: Colors.white60,
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
                                        color: const Color(0xFF37474F),
                                        borderRadius: BorderRadius.circular(12),
                                        border: Border.all(
                                          color: const Color(0xFF2196F3).withAlpha(128),
                                          width: 2,
                                        ),
                                      ),
                                      child: DropdownButtonHideUnderline(
                                        child: DropdownButton<int>(
                                          value: _currentPage,
                                          isExpanded: true,
                                          dropdownColor: const Color(0xFF37474F),
                                          icon: const Icon(Icons.arrow_drop_down, size: 24, color: Color(0xFF2196F3)),
                                          style: const TextStyle(
                                            fontSize: 13,
                                            fontWeight: FontWeight.w600,
                                            color: Colors.white,
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
                                              
                                              // 마지막 선택 단말번호 저장
                                              _saveLastSelectedExtension(extensions[newValue].id);
                                              
                                              if (kDebugMode) {
                                                debugPrint('📄 Dropdown changed to index: $newValue');
                                                debugPrint('   - Extension: ${extensions[newValue].extension}');
                                                debugPrint('   - Name: ${extensions[newValue].name}');
                                                debugPrint('   - ID: ${extensions[newValue].id}');
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
    
    return Card(
      key: key,
        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        elevation: 6,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
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
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                        // 외부발신 정보 카드
                        if ((extension.externalCidName != null && extension.externalCidName!.isNotEmpty) ||
                            (extension.externalCidNumber != null && extension.externalCidNumber!.isNotEmpty)) ...[
                          Container(
                            width: double.infinity,
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: const Color(0xFF4CAF50).withAlpha(26),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                color: const Color(0xFF4CAF50).withAlpha(77),
                                width: 1.5,
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
                                      size: 14,
                                      color: const Color(0xFF4CAF50),
                                    ),
                                    const SizedBox(width: 6),
                                    Text(
                                      '외부발신 표시정보',
                                      style: TextStyle(
                                        fontSize: 10,
                                        fontWeight: FontWeight.w600,
                                        color: const Color(0xFF4CAF50),
                                        letterSpacing: 0.5,
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 6),
                                
                                // 외부발신 이름
                                if (extension.externalCidName != null && extension.externalCidName!.isNotEmpty)
                                  Text(
                                    extension.externalCidName!,
                                    style: const TextStyle(
                                      fontSize: 13,
                                      fontWeight: FontWeight.bold,
                                      color: Colors.black87,
                                    ),
                                    textAlign: TextAlign.center,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                
                                if (extension.externalCidName != null && 
                                    extension.externalCidName!.isNotEmpty &&
                                    extension.externalCidNumber != null &&
                                    extension.externalCidNumber!.isNotEmpty)
                                  const SizedBox(height: 4),
                                
                                // 외부발신 번호
                                if (extension.externalCidNumber != null && extension.externalCidNumber!.isNotEmpty)
                                  Text(
                                    PhoneFormatter.format(extension.externalCidNumber!),
                                    style: const TextStyle(
                                      fontSize: 15,
                                      fontWeight: FontWeight.w600,
                                      color: Color(0xFF4CAF50),
                                      letterSpacing: 0.8,
                                    ),
                                    textAlign: TextAlign.center,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 12),
                        ],
                        
                        // 통화 상태 표시 (실시간)
                        CallStateIndicator(extension: extension.extension),
                        
                        // 단말 정보 카드
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: const Color(0xFF2196F3).withAlpha(26),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: const Color(0xFF2196F3).withAlpha(77),
                              width: 1.5,
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
                                    size: 14,
                                    color: const Color(0xFF2196F3),
                                  ),
                                  const SizedBox(width: 6),
                                  Text(
                                    '단말발신 표시정보',
                                    style: TextStyle(
                                      fontSize: 10,
                                      fontWeight: FontWeight.w600,
                                      color: const Color(0xFF2196F3),
                                      letterSpacing: 0.5,
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 6),
                              
                              // 단말 이름
                              if (extension.name.isNotEmpty)
                                Text(
                                  extension.name,
                                  style: const TextStyle(
                                    fontSize: 13,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.black87,
                                  ),
                                  textAlign: TextAlign.center,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              
                              if (extension.name.isNotEmpty)
                                const SizedBox(height: 4),
                              
                              // 단말번호
                              Text(
                                PhoneFormatter.format(extension.extension),
                                style: const TextStyle(
                                  fontSize: 15,
                                  fontWeight: FontWeight.w600,
                                  color: Color(0xFF2196F3),
                                  letterSpacing: 0.8,
                                ),
                                textAlign: TextAlign.center,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 12),
                        
                        // 착신전환 설정 카드 (사용자 전역 WebSocket 설정이 있는 경우 표시)
                        if (userWsServerUrl != null && 
                            userWsServerUrl.isNotEmpty &&
                            userCompanyId != null &&
                            userCompanyId.isNotEmpty) ...[
                          CallForwardSettingsCard(
                            extension: extension,
                            tenantId: userCompanyId,
                            wsServerAddress: userWsServerUrl,
                            wsServerPort: userWsPort,
                            useSSL: userUseSSL,
                            amiServerId: userAmiServerId,
                          ),
                          const SizedBox(height: 16),
                        ],
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
