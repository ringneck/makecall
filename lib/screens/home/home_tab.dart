import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../services/auth_service.dart';
import '../../services/database_service.dart';
import '../../models/my_extension_model.dart';
import '../../providers/selected_extension_provider.dart';

class HomeTab extends StatefulWidget {
  const HomeTab({super.key});

  @override
  State<HomeTab> createState() => _HomeTabState();
}

class _HomeTabState extends State<HomeTab> {
  final DatabaseService _databaseService = DatabaseService();
  final PageController _pageController = PageController();
  int _currentPage = 0;

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
                      // 내 정보 탭으로 이동 (인덱스 3)
                      DefaultTabController.of(context).animateTo(3);
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

          // 페이지 변경 시 선택된 단말번호 업데이트
          WidgetsBinding.instance.addPostFrameCallback((_) {
            // 현재 페이지가 범위를 벗어나면 마지막 페이지로 이동
            if (_currentPage >= extensions.length && extensions.isNotEmpty) {
              setState(() {
                _currentPage = extensions.length - 1;
              });
              // PageController도 업데이트
              if (_pageController.hasClients) {
                _pageController.jumpToPage(_currentPage);
              }
            }
            
            // 선택된 단말번호 업데이트
            if (extensions.isNotEmpty && _currentPage < extensions.length) {
              context.read<SelectedExtensionProvider>().setSelectedExtension(
                    extensions[_currentPage],
                  );
            }
          });

          return Column(
            children: [
              // 상단 안내 메시지
              Container(
                margin: const EdgeInsets.all(16),
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      const Color(0xFF2196F3).withAlpha(26),
                      const Color(0xFF2196F3).withAlpha(13),
                    ],
                  ),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: const Color(0xFF2196F3).withAlpha(51),
                  ),
                ),
                child: Row(
                  children: [
                    const Icon(
                      Icons.info_outline,
                      color: Color(0xFF2196F3),
                      size: 24,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            '현재 선택된 단말번호',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: Color(0xFF1976D2),
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            extensions.length > 1
                                ? '좌우로 슬라이드하여 단말번호를 변경할 수 있습니다'
                                : '클릭투콜 발신 시 이 단말번호가 사용됩니다',
                            style: TextStyle(
                              fontSize: 11,
                              color: Colors.grey[700],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),

              // 단말번호 슬라이드 카드
              Expanded(
                child: PageView.builder(
                  controller: _pageController,
                  onPageChanged: (index) {
                    setState(() {
                      _currentPage = index;
                    });
                    // 선택된 단말번호 업데이트
                    context.read<SelectedExtensionProvider>().setSelectedExtension(
                          extensions[index],
                        );
                  },
                  itemCount: extensions.length,
                  itemBuilder: (context, index) {
                    final extension = extensions[index];
                    return _buildExtensionCard(extension, index);
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

  Widget _buildExtensionCard(MyExtensionModel extension, int index) {
    return Center(
      child: Card(
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
          child: Padding(
            padding: const EdgeInsets.all(32.0),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // 아이콘
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: LinearGradient(
                      colors: [
                        const Color(0xFF2196F3).withAlpha(51),
                        const Color(0xFF2196F3).withAlpha(26),
                      ],
                    ),
                  ),
                  child: const Icon(
                    Icons.phone_android,
                    size: 64,
                    color: Color(0xFF2196F3),
                  ),
                ),
                const SizedBox(height: 32),

                // 단말 이름
                if (extension.name.isNotEmpty) ...[
                  Text(
                    extension.name,
                    style: const TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                      color: Colors.black87,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 8),
                ],

                // 단말번호
                Text(
                  extension.extension,
                  style: const TextStyle(
                    fontSize: 36,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF2196F3),
                    letterSpacing: 2,
                  ),
                ),
                const SizedBox(height: 24),

                // 구분선
                Divider(color: Colors.grey[300], thickness: 1),
                const SizedBox(height: 16),

                // 상세 정보
                _buildInfoChip(
                  Icons.vpn_key,
                  'Extension ID',
                  extension.extensionId,
                ),
                const SizedBox(height: 24),

                // 안내 메시지
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.green[50],
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.green[200]!),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.check_circle, color: Colors.green[700], size: 20),
                      const SizedBox(width: 12),
                      const Expanded(
                        child: Text(
                          '클릭투콜 발신 시 이 단말번호가 사용됩니다',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: Colors.green,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildInfoChip(IconData icon, String label, String value,
      {bool highlight = false}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: highlight ? Colors.orange[50] : Colors.grey[100],
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: highlight ? Colors.orange[200]! : Colors.grey[300]!,
        ),
      ),
      child: Row(
        children: [
          Icon(
            icon,
            size: 18,
            color: highlight ? Colors.orange[700] : Colors.grey[600],
          ),
          const SizedBox(width: 12),
          Text(
            '$label: ',
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: highlight ? Colors.orange[800] : Colors.grey[700],
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: TextStyle(
                fontSize: 13,
                fontWeight: highlight ? FontWeight.bold : FontWeight.normal,
                color: highlight ? Colors.orange[900] : Colors.black87,
              ),
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }
}
