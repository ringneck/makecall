import 'package:flutter/material.dart';
import '../../utils/dialog_utils.dart';
import 'package:provider/provider.dart';
import '../../services/auth_service.dart';
import '../../services/database_service.dart';
import '../../services/api_service.dart';
import '../../models/extension_model.dart';

class ExtensionManagementScreen extends StatefulWidget {
  const ExtensionManagementScreen({super.key});

  @override
  State<ExtensionManagementScreen> createState() =>
      _ExtensionManagementScreenState();
}

class _ExtensionManagementScreenState extends State<ExtensionManagementScreen> {
  final DatabaseService _databaseService = DatabaseService();
  bool _isLoading = false;
  final ScrollController _scrollController = ScrollController();
  bool _isGridView = false; // false: 리스트뷰, true: 그리드뷰

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
  }

  @override
  void dispose() {
    _scrollController.removeListener(_onScroll);
    _scrollController.dispose();
    super.dispose();
  }

  // 스크롤 위치에 따라 뷰 모드 변경
  void _onScroll() {
    // 스크롤이 최하단에 도달하면 뷰 전환
    if (_scrollController.position.pixels >= _scrollController.position.maxScrollExtent - 50) {
      if (!_isGridView) {
        setState(() {
          _isGridView = true;
        });
      }
    } else if (_scrollController.position.pixels <= 50) {
      if (_isGridView) {
        setState(() {
          _isGridView = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final authService = context.watch<AuthService>();
    final userId = authService.currentUser?.uid ?? '';

    return Scaffold(
      appBar: AppBar(
        title: const Text('단말번호 관리'),
        actions: [
          // 현재 보기 모드 표시
          Center(
            child: Container(
              margin: const EdgeInsets.only(right: 8),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: Colors.white.withAlpha(51),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    _isGridView ? Icons.grid_view : Icons.view_list,
                    size: 16,
                    color: Colors.white,
                  ),
                  const SizedBox(width: 4),
                  Text(
                    _isGridView ? '그리드' : '리스트',
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: Colors.white,
                    ),
                  ),
                ],
              ),
            ),
          ),
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () => _fetchExtensionsFromApi(context),
            tooltip: 'API에서 단말번호 조회',
          ),
        ],
      ),
      body: StreamBuilder<List<ExtensionModel>>(
        stream: _databaseService.getUserExtensions(userId),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (snapshot.hasError) {
            return Center(child: Text('오류 발생: ${snapshot.error}'));
          }

          final extensions = snapshot.data ?? [];

          if (extensions.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.phone_android, size: 64, color: Colors.grey),
                  const SizedBox(height: 16),
                  const Text(
                    '등록된 단말번호가 없습니다',
                    style: TextStyle(color: Colors.grey),
                  ),
                  const SizedBox(height: 24),
                  ElevatedButton.icon(
                    onPressed: _isLoading
                        ? null
                        : () => _fetchExtensionsFromApi(context),
                    icon: const Icon(Icons.download),
                    label: const Text('API에서 조회'),
                  ),
                ],
              ),
            );
          }

          return SingleChildScrollView(
            controller: _scrollController,
            child: Column(
              children: [
                // 리스트뷰 섹션
                if (!_isGridView) ...[
                  _buildListView(extensions),
                  
                  // 하단 안내 텍스트 (리스트뷰)
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 16),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.arrow_downward, size: 16, color: Colors.grey[600]),
                        const SizedBox(width: 8),
                        Text(
                          '아래로 스크롤하여 그리드뷰로 전환',
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.grey[600],
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
                
                // 그리드뷰 섹션
                if (_isGridView) ...[
                  // 상단 안내 텍스트 (그리드뷰)
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 16),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.arrow_upward, size: 16, color: Colors.grey[600]),
                        const SizedBox(width: 8),
                        Text(
                          '위로 스크롤하여 리스트뷰로 전환',
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.grey[600],
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  ),
                  
                  _buildGridView(extensions),
                ],
              ],
            ),
          );
        },
      ),
    );
  }

  // 리스트뷰 빌더
  Widget _buildListView(List<ExtensionModel> extensions) {
    return Column(
      children: [
        // 상단 안내 텍스트
        Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
          decoration: BoxDecoration(
            color: Colors.blue[50],
            border: Border(
              bottom: BorderSide(color: Colors.blue[200]!, width: 1),
            ),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.view_list, size: 16, color: Colors.blue[700]),
              const SizedBox(width: 8),
              Text(
                '리스트뷰',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: Colors.blue[700],
                ),
              ),
            ],
          ),
        ),
        
        // 리스트 아이템들
        ...extensions.map((extension) {
          return _buildListItem(extension, extensions);
        }),
      ],
    );
  }

  // 리스트 아이템 빌더
  Widget _buildListItem(ExtensionModel extension, List<ExtensionModel> allExtensions) {
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(
          color: extension.isSelected 
              ? const Color(0xFF2196F3).withAlpha(128)
              : Colors.grey.withAlpha(51),
          width: extension.isSelected ? 2 : 1,
        ),
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        leading: CircleAvatar(
          backgroundColor: extension.isSelected
              ? const Color(0xFF2196F3)
              : Colors.grey,
          child: Icon(
            extension.isSelected ? Icons.check : Icons.phone_android,
            color: Colors.white,
          ),
        ),
        title: Text(
          '단말번호: ${extension.extensionNumber}',
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 4),
            if (extension.deviceId != null)
              Text('Device ID: ${extension.deviceId}'),
            if (extension.cosId != null)
              Text('COS ID: ${extension.cosId}'),
          ],
        ),
        trailing: extension.isSelected
            ? const Chip(
                label: Text('선택됨'),
                backgroundColor: Color(0xFFE3F2FD),
              )
            : null,
        onTap: () => _selectExtension(extension, allExtensions),
      ),
    );
  }



  // 그리드뷰 빌더
  Widget _buildGridView(List<ExtensionModel> extensions) {
    return Column(
      children: [
        // 상단 안내 텍스트
        Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
          decoration: BoxDecoration(
            color: Colors.green[50],
            border: Border(
              bottom: BorderSide(color: Colors.green[200]!, width: 1),
            ),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.grid_view, size: 16, color: Colors.green[700]),
              const SizedBox(width: 8),
              Text(
                '그리드뷰',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: Colors.green[700],
                ),
              ),
            ],
          ),
        ),
        
        // 그리드 아이템들
        Padding(
          padding: const EdgeInsets.all(16),
          child: Wrap(
            spacing: 12,
            runSpacing: 12,
            children: extensions.map((extension) {
              return _buildGridItem(extension, extensions);
            }).toList(),
          ),
        ),
      ],
    );
  }

  // 그리드 아이템 빌더
  Widget _buildGridItem(ExtensionModel extension, List<ExtensionModel> allExtensions) {
    final screenWidth = MediaQuery.of(context).size.width;
    final itemWidth = (screenWidth - 44) / 2; // 16 padding left + 16 padding right + 12 spacing
    
    return SizedBox(
      width: itemWidth,
      child: Card(
        elevation: 3,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: BorderSide(
            color: extension.isSelected 
                ? const Color(0xFF2196F3)
                : Colors.grey.withAlpha(77),
            width: extension.isSelected ? 3 : 1,
          ),
        ),
        child: InkWell(
          onTap: () => _selectExtension(extension, allExtensions),
          borderRadius: BorderRadius.circular(16),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              mainAxisSize: MainAxisSize.min,
              children: [
                // 아이콘
                Container(
                  width: 60,
                  height: 60,
                  decoration: BoxDecoration(
                    color: extension.isSelected
                        ? const Color(0xFF2196F3).withAlpha(51)
                        : Colors.grey.withAlpha(51),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    extension.isSelected ? Icons.check_circle : Icons.phone_android,
                    size: 32,
                    color: extension.isSelected
                        ? const Color(0xFF2196F3)
                        : Colors.grey[600],
                  ),
                ),
                const SizedBox(height: 12),
                
                // 단말번호
                Text(
                  extension.extensionNumber,
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: extension.isSelected
                        ? const Color(0xFF2196F3)
                        : Colors.black87,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 8),
                
                // Device ID (있는 경우)
                if (extension.deviceId != null) ...[
                  Text(
                    'Device ID',
                    style: TextStyle(
                      fontSize: 10,
                      color: Colors.grey[600],
                    ),
                  ),
                  Text(
                    extension.deviceId!,
                    style: const TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w500,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    textAlign: TextAlign.center,
                  ),
                ],
                
                const SizedBox(height: 8),
                
                // 선택됨 배지
                if (extension.isSelected)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                    decoration: BoxDecoration(
                      color: const Color(0xFF2196F3),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Text(
                      '선택됨',
                      style: TextStyle(
                        fontSize: 11,
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _fetchExtensionsFromApi(BuildContext context) async {
    setState(() => _isLoading = true);

    try {
      final authService = context.read<AuthService>();
      final userModel = authService.currentUserModel;
      final userId = authService.currentUser?.uid ?? '';

      if (userModel?.companyId == null || userModel?.appKey == null) {
        throw Exception('API 인증 정보를 먼저 설정해주세요');
      }

      if (userModel?.apiBaseUrl == null) {
        throw Exception('API 서버 주소가 설정되지 않았습니다.\n내 정보 > API 설정에서 설정해주세요.');
      }

      // API 서비스 생성 (사용자 설정에서 HTTPS URL 사용)
      final apiService = ApiService(
        baseUrl: userModel!.getApiUrl(useHttps: true),
        companyId: userModel.companyId,
        appKey: userModel.appKey,
      );

      // 단말 목록 조회
      final extensionsList = await apiService.getExtensions();

      if (extensionsList.isEmpty) {
        throw Exception('조회된 단말번호가 없습니다');
      }

      // 첫 번째 단말의 상세 정보 조회
      for (final ext in extensionsList) {
        final extId = ext['id'] as String?;
        if (extId != null) {
          final devices = await apiService.getExtensionDevices(extId);

          // Firestore에 저장
          final extension = ExtensionModel(
            id: '',
            userId: userId,
            extensionNumber: ext['extension_number'] as String? ?? extId,
            deviceId: devices['device_id'] as String?,
            cosId: devices['cos_id'] as String?,
            user: devices['user'] as String?,
            secret: devices['secret'] as String?,
            createdAt: DateTime.now(),
          );

          await _databaseService.addExtension(extension);
        }
      }

      if (mounted) {
        await DialogUtils.showInfo(context, '단말번호를 불러왔습니다', duration: const Duration(seconds: 2));
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

  Future<void> _selectExtension(
    ExtensionModel extension,
    List<ExtensionModel> allExtensions,
  ) async {
    try {
      // 모든 단말번호의 선택 상태를 해제
      for (final ext in allExtensions) {
        if (ext.id != extension.id && ext.isSelected) {
          await _databaseService.updateExtension(ext.id, {'isSelected': false});
        }
      }

      // 선택한 단말번호의 상태를 토글
      await _databaseService.updateExtension(
        extension.id,
        {'isSelected': !extension.isSelected},
      );

      if (mounted) {
        await DialogUtils.showSuccess(
          context,
          extension.isSelected
              ? '선택이 해제되었습니다'
              : '${extension.extensionNumber}이(가) 선택되었습니다',
        );
      }
    } catch (e) {
      if (mounted) {
        await DialogUtils.showError(
          context,
          '오류 발생: $e',
        );
      }
    }
  }
}
