import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:provider/provider.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:io';
import '../services/auth_service.dart';
import '../services/api_service.dart';
import '../services/database_service.dart';
import '../models/my_extension_model.dart';
import '../screens/profile/api_settings_dialog.dart';

class ProfileDrawer extends StatefulWidget {
  const ProfileDrawer({super.key});

  @override
  State<ProfileDrawer> createState() => _ProfileDrawerState();
}

class _ProfileDrawerState extends State<ProfileDrawer> {
  bool _isSearching = false;
  bool _isRefreshing = false;
  String? _searchError;
  final _phoneNumberController = TextEditingController();

  @override
  void initState() {
    super.initState();
    // 저장된 전화번호 불러오기 및 단말번호 업데이트
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final authService = context.read<AuthService>();
      if (authService.currentUserModel?.phoneNumber != null) {
        _phoneNumberController.text = authService.currentUserModel!.phoneNumber!;
      }
      // 저장된 단말번호 정보 업데이트
      _updateSavedExtensions();
    });
  }

  @override
  void dispose() {
    _phoneNumberController.dispose();
    super.dispose();
  }

  // 수동 업데이트 핸들러 (Firestore에서 사용자 데이터 새로고침)
  Future<void> _handleManualRefresh() async {
    if (_isRefreshing) return;
    
    setState(() {
      _isRefreshing = true;
    });

    try {
      final authService = context.read<AuthService>();
      final userId = authService.currentUser?.uid;
      
      if (userId == null) {
        if (kDebugMode) {
          debugPrint('⚠️ 사용자 ID가 없어서 새로고침을 건너뜁니다');
        }
        return;
      }

      // Firestore에서 사용자 데이터 강제 새로고침
      await authService.refreshUserModel();
      
      if (kDebugMode) {
        debugPrint('✅ 사용자 데이터 새로고침 완료');
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Row(
              children: [
                Icon(Icons.check_circle, color: Colors.white, size: 20),
                SizedBox(width: 12),
                Text('정보가 업데이트되었습니다'),
              ],
            ),
            backgroundColor: Colors.green,
            behavior: SnackBarBehavior.floating,
            duration: Duration(seconds: 2),
          ),
        );
      }
    } catch (e) {
      if (kDebugMode) {
        debugPrint('❌ 새로고침 실패: $e');
      }
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const Icon(Icons.error_outline, color: Colors.white, size: 20),
                const SizedBox(width: 12),
                Expanded(child: Text('업데이트 실패: $e')),
              ],
            ),
            backgroundColor: Colors.red,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isRefreshing = false;
        });
      }
    }
  }

  // 타임스탬프 포맷 함수 (한국어 형식)
  String _formatUpdateTimestamp(DateTime timestamp) {
    final now = DateTime.now();
    final difference = now.difference(timestamp);

    // 1분 이내
    if (difference.inSeconds < 60) {
      return '방금 업데이트됨';
    }
    // 1시간 이내
    else if (difference.inMinutes < 60) {
      return '${difference.inMinutes}분 전 업데이트';
    }
    // 24시간 이내
    else if (difference.inHours < 24) {
      return '${difference.inHours}시간 전 업데이트';
    }
    // 그 외 - 전체 날짜 표시
    else {
      final year = timestamp.year;
      final month = timestamp.month;
      final day = timestamp.day;
      final hour = timestamp.hour;
      final minute = timestamp.minute;
      final period = hour >= 12 ? '오후' : '오전';
      final displayHour = hour > 12 ? hour - 12 : (hour == 0 ? 12 : hour);
      
      return '$year년 $month월 $day일 $period $displayHour:${minute.toString().padLeft(2, '0')} 업데이트';
    }
  }

  // 저장된 단말번호 정보 업데이트
  Future<void> _updateSavedExtensions() async {
    final authService = context.read<AuthService>();
    final userModel = authService.currentUserModel;
    final userId = authService.currentUser?.uid ?? '';

    // API 설정이 없으면 종료
    if (userModel?.apiBaseUrl == null) {
      return;
    }

    try {
      final dbService = DatabaseService();
      
      // 1. registered_extensions에서 내가 등록한 단말번호 가져오기
      final registeredExtensions = await dbService.getUserRegisteredExtensions(userId);
      
      // 2. my_extensions에서 이미 있는 단말번호 목록 가져오기
      final savedExtensions = await dbService.getMyExtensions(userId).first;
      final existingExtensionNumbers = savedExtensions.map((e) => e.extension).toSet();
      
      // 3. registered_extensions에는 있지만 my_extensions에는 없는 단말번호 찾기
      final missingExtensions = registeredExtensions
          .where((ext) => !existingExtensionNumbers.contains(ext))
          .toList();
      
      // 4. 누락된 단말번호를 my_extensions에 추가 (마이그레이션)
      if (missingExtensions.isNotEmpty) {
        if (kDebugMode) {
          debugPrint('🔄 마이그레이션 시작: ${missingExtensions.length}개 단말번호를 my_extensions에 추가');
        }
        
        for (final extension in missingExtensions) {
          final myExtension = MyExtensionModel(
            id: '',
            userId: userId,
            extensionId: '',
            extension: extension,
            name: extension, // 이름을 모르므로 단말번호를 이름으로 사용
            classOfServicesId: '',
            createdAt: DateTime.now(),
            apiBaseUrl: userModel?.apiBaseUrl,
            companyId: userModel?.companyId,
            appKey: userModel?.appKey,
            apiHttpPort: userModel?.apiHttpPort,
            apiHttpsPort: userModel?.apiHttpsPort,
          );
          
          await dbService.addMyExtension(myExtension);
          
          if (kDebugMode) {
            debugPrint('   ✅ $extension 추가 완료');
          }
        }
      }
      
      // 5. 저장된 단말번호 가져오기 (마이그레이션 후)
      final allSavedExtensions = await dbService.getMyExtensions(userId).first;

      if (allSavedExtensions.isEmpty) {
        return;
      }

      // API Service 생성
      final apiService = ApiService(
        baseUrl: userModel!.getApiUrl(useHttps: false),
        companyId: userModel.companyId,
        appKey: userModel.appKey,
      );

      // API에서 전체 단말번호 목록 가져오기
      final dataList = await apiService.getExtensions();

      // 저장된 각 단말번호에 대해 업데이트
      for (final savedExtension in allSavedExtensions) {
        // API 데이터에서 매칭되는 단말번호 찾기
        final matchedData = dataList.firstWhere(
          (item) => item['extension']?.toString() == savedExtension.extension,
          orElse: () => <String, dynamic>{},
        );

        if (matchedData.isNotEmpty) {
          // 새로운 정보로 업데이트
          final updatedExtension = MyExtensionModel.fromApi(
            userId: userId,
            apiData: matchedData,
          );

          // DB 업데이트 (addMyExtension은 중복 시 업데이트 수행)
          await dbService.addMyExtension(updatedExtension);
        }
      }

      if (kDebugMode) {
        debugPrint('✅ 저장된 단말번호 정보 업데이트 완료 (${savedExtensions.length}개)');
      }
    } catch (e) {
      if (kDebugMode) {
        debugPrint('⚠️ 단말번호 업데이트 실패: $e');
      }
      // 에러가 발생해도 UI는 정상적으로 표시되도록 무시
    }
  }

  @override
  Widget build(BuildContext context) {
    final authService = context.watch<AuthService>();
    final userModel = authService.currentUserModel;
    final userId = authService.currentUser?.uid ?? '';

    return Drawer(
      child: ListView(
        padding: EdgeInsets.zero,
        children: [
          // Drawer Header
          DrawerHeader(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  const Color(0xFF2196F3),
                  const Color(0xFF2196F3).withAlpha(204),
                ],
              ),
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Text(
                  '단말',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  userModel?.email ?? '이메일 없음',
                  style: const TextStyle(
                    color: Colors.white70,
                    fontSize: 14,
                  ),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),
          
          const SizedBox(height: 24),
          // 사용자 정보
          Stack(
            alignment: Alignment.center,
            children: [
              GestureDetector(
                onTap: () => _showProfileImageOptions(context, authService),
                child: CircleAvatar(
                  radius: 50,
                  backgroundColor: Colors.transparent,
                  backgroundImage: userModel?.profileImageUrl != null
                      ? NetworkImage(userModel!.profileImageUrl!)
                      : const AssetImage('assets/images/app_logo.png') as ImageProvider,
                ),
              ),
              Positioned(
                bottom: 0,
                right: 0,
                child: GestureDetector(
                  onTap: () => _showProfileImageOptions(context, authService),
                  child: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: const Color(0xFF2196F3),
                      shape: BoxShape.circle,
                      border: Border.all(color: Colors.white, width: 2),
                    ),
                    child: const Icon(
                      Icons.camera_alt,
                      size: 20,
                      color: Colors.white,
                    ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Text(
            userModel?.email ?? '이메일 없음',
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          // 단말번호 제한 안내
          Text(
            '단말번호 저장 가능: 최대 ${userModel?.maxExtensions ?? 1}개',
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: Color(0xFF2196F3),
            ),
          ),
          const SizedBox(height: 4),
          // 마지막 업데이트 타임스탬프 표시 및 수동 업데이트 버튼
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              if (userModel?.lastMaxExtensionsUpdate != null)
                Text(
                  _formatUpdateTimestamp(userModel!.lastMaxExtensionsUpdate!),
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 11,
                    color: Colors.grey[600],
                  ),
                ),
              const SizedBox(width: 8),
              // 수동 업데이트 버튼
              InkWell(
                onTap: _isRefreshing ? null : _handleManualRefresh,
                borderRadius: BorderRadius.circular(20),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: _isRefreshing 
                        ? Colors.grey[300] 
                        : const Color(0xFF2196F3).withAlpha(26),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: _isRefreshing 
                          ? Colors.grey[400]! 
                          : const Color(0xFF2196F3).withAlpha(77),
                      width: 1,
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      _isRefreshing
                          ? SizedBox(
                              width: 14,
                              height: 14,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                valueColor: AlwaysStoppedAnimation<Color>(
                                  Colors.grey[600]!,
                                ),
                              ),
                            )
                          : const Icon(
                              Icons.refresh,
                              size: 14,
                              color: Color(0xFF2196F3),
                            ),
                      const SizedBox(width: 4),
                      Text(
                        _isRefreshing ? '업데이트 중...' : '새로고침',
                        style: TextStyle(
                          fontSize: 11,
                          color: _isRefreshing 
                              ? Colors.grey[600] 
                              : const Color(0xFF2196F3),
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),
          const Divider(),
          
          // 기본 설정
          ListTile(
            leading: const Icon(Icons.settings, size: 22),
            title: const Text('기본 설정', style: TextStyle(fontSize: 15)),
            subtitle: const Text(
              'API 서버, WebSocket 설정',
              style: TextStyle(fontSize: 11),
            ),
            trailing: const Icon(Icons.chevron_right),
            onTap: () {
              showDialog(
                context: context,
                builder: (context) => const ApiSettingsDialog(),
              );
            },
          ),
          const Divider(),
          
          // 내 단말번호 조회 및 관리 (통합 UI)
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Row(
                  children: [
                    Icon(Icons.phone_android, color: Color(0xFF2196F3), size: 20),
                    SizedBox(width: 8),
                    Text(
                      '내 단말번호',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                
                // 단말번호 조회 버튼
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.blue[50],
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.blue[200]!),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton.icon(
                          onPressed: _isSearching || userModel?.apiBaseUrl == null
                              ? null
                              : () => _searchMyExtensions(context),
                          icon: _isSearching
                              ? const SizedBox(
                                  width: 20,
                                  height: 20,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    color: Colors.white,
                                  ),
                                )
                              : const Icon(Icons.search),
                          label: Text(_isSearching ? '조회 중...' : '단말번호 조회 및 등록'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF2196F3),
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 16),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8),
                            ),
                          ),
                        ),
                      ),
                      
                      // 에러 메시지 표시
                      if (_searchError != null) ...[
                        const SizedBox(height: 12),
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: Colors.red[50],
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: Colors.red[200]!),
                          ),
                          child: Row(
                            children: [
                              const Icon(Icons.error_outline, color: Colors.red, size: 20),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  _searchError!,
                                  style: const TextStyle(
                                    fontSize: 12,
                                    color: Colors.red,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                
                const SizedBox(height: 24),
                
                // 저장된 내 단말번호 목록
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      '저장된 내 단말번호',
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    if (userId.isNotEmpty)
                      TextButton.icon(
                        onPressed: () => _deleteAllExtensions(context, userId),
                        icon: const Icon(Icons.delete_sweep, size: 18),
                        label: const Text('전체 삭제'),
                        style: TextButton.styleFrom(
                          foregroundColor: Colors.red,
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 12),
                
                // StreamBuilder로 실시간 목록 표시
                if (userId.isNotEmpty)
                  StreamBuilder<List<MyExtensionModel>>(
                    stream: DatabaseService().getMyExtensions(userId),
                    builder: (context, snapshot) {
                      if (snapshot.connectionState == ConnectionState.waiting) {
                        return const Center(
                          child: Padding(
                            padding: EdgeInsets.all(24),
                            child: CircularProgressIndicator(),
                          ),
                        );
                      }
                      
                      if (snapshot.hasError) {
                        return Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: Colors.red[50],
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: Colors.red[200]!),
                          ),
                          child: Row(
                            children: [
                              const Icon(Icons.error_outline, color: Colors.red),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Text(
                                  '오류: ${snapshot.error}',
                                  style: const TextStyle(color: Colors.red),
                                ),
                              ),
                            ],
                          ),
                        );
                      }
                      
                      final extensions = snapshot.data ?? [];
                      
                      if (extensions.isEmpty) {
                        return Container(
                          padding: const EdgeInsets.all(24),
                          decoration: BoxDecoration(
                            color: Colors.grey[100],
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: Colors.grey[300]!),
                          ),
                          child: const Center(
                            child: Column(
                              children: [
                                Icon(Icons.inbox_outlined, size: 44, color: Colors.grey),
                                SizedBox(height: 10),
                                Text(
                                  '저장된 단말번호가 없습니다.',
                                  style: TextStyle(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w600,
                                    color: Colors.grey,
                                  ),
                                ),
                                SizedBox(height: 4),
                                Text(
                                  '위의 조회 버튼을 눌러주세요.',
                                  textAlign: TextAlign.center,
                                  style: TextStyle(
                                    fontSize: 11,
                                    color: Colors.grey,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        );
                      }
                      
                      // 단말번호 목록 표시
                      return _buildExtensionsList(extensions);
                    },
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildExtensionsList(List<MyExtensionModel> extensions) {
    return Column(
      children: [
        // 총 개수 표시
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Colors.green[50],
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: Colors.green[200]!),
          ),
          child: Row(
            children: [
              const Icon(Icons.check_circle, color: Colors.green, size: 18),
              const SizedBox(width: 8),
              Text(
                '총 ${extensions.length}개의 단말번호',
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: Colors.green,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        
        // 단말번호 카드 목록
        ...extensions.map((ext) {
          return Card(
            margin: const EdgeInsets.only(bottom: 12),
            elevation: 2,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
              side: BorderSide(
                color: ext.hasApiConfig ? Colors.green.withAlpha(102) : Colors.grey.withAlpha(51),
                width: ext.hasApiConfig ? 2 : 1,
              ),
            ),
            child: InkWell(
              onTap: () => _showExtensionDetails(context, ext),
              borderRadius: BorderRadius.circular(12),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // 헤더: 단말번호 및 액션 버튼
                    Row(
                      children: [
                        CircleAvatar(
                          radius: 20,
                          backgroundColor: const Color(0xFF2196F3).withAlpha(51),
                          child: const Icon(
                            Icons.phone_android,
                            color: Color(0xFF2196F3),
                            size: 20,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                ext.extension,
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 16,
                                  color: Color(0xFF2196F3),
                                ),
                              ),
                              if (ext.name.isNotEmpty)
                                Text(
                                  ext.name,
                                  style: const TextStyle(
                                    fontSize: 13,
                                    color: Colors.black87,
                                  ),
                                ),
                            ],
                          ),
                        ),
                        const Spacer(),
                        IconButton(
                          icon: const Icon(Icons.delete, color: Colors.red, size: 22),
                          onPressed: () => _deleteExtension(context, ext),
                          tooltip: '삭제',
                        ),
                      ],
                    ),
                    const Divider(height: 24),
                    
                    // 기본 정보
                    _buildInfoRow(
                      Icons.access_time,
                      '저장 시간',
                      ext.createdAt.toString().substring(0, 19),
                    ),
                  ],
                ),
              ),
            ),
          );
        }),
      ],
    );
  }

  Widget _buildInfoRow(IconData icon, String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Icon(icon, size: 16, color: Colors.grey[600]),
          const SizedBox(width: 8),
          Text(
            label,
            style: TextStyle(
              fontSize: 12,
              color: Colors.grey[600],
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(
                fontSize: 12,
                color: Colors.black87,
              ),
              textAlign: TextAlign.end,
            ),
          ),
        ],
      ),
    );
  }

  // ProfileTab의 메서드들을 복제
  void _showProfileImageOptions(BuildContext context, AuthService authService) {
    showModalBottomSheet(
      context: context,
      builder: (context) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                leading: const Icon(Icons.photo_library),
                title: const Text('갤러리에서 선택'),
                onTap: () {
                  Navigator.pop(context);
                  _pickImage(ImageSource.gallery, authService);
                },
              ),
              ListTile(
                leading: const Icon(Icons.photo_camera),
                title: const Text('카메라로 촬영'),
                onTap: () {
                  Navigator.pop(context);
                  _pickImage(ImageSource.camera, authService);
                },
              ),
              if (authService.currentUserModel?.profileImageUrl != null)
                ListTile(
                  leading: const Icon(Icons.delete, color: Colors.red),
                  title: const Text('프로필 사진 삭제', style: TextStyle(color: Colors.red)),
                  onTap: () {
                    Navigator.pop(context);
                    _deleteProfileImage(authService);
                  },
                ),
            ],
          ),
        );
      },
    );
  }

  Future<void> _pickImage(ImageSource source, AuthService authService) async {
    try {
      final ImagePicker picker = ImagePicker();
      final XFile? image = await picker.pickImage(
        source: source,
        maxWidth: 512,
        maxHeight: 512,
        imageQuality: 85,
      );

      if (image != null) {
        if (!mounted) return;
        
        // 로딩 표시
        showDialog(
          context: context,
          barrierDismissible: false,
          builder: (context) => const Center(
            child: CircularProgressIndicator(),
          ),
        );

        // 이미지 업로드
        final imageUrl = await authService.uploadProfileImage(File(image.path));
        
        if (mounted) {
          Navigator.pop(context); // 로딩 다이얼로그 닫기
          
          if (imageUrl != null) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('프로필 사진이 업데이트되었습니다')),
            );
          } else {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('이미지 업로드에 실패했습니다')),
            );
          }
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('오류: $e')),
        );
      }
    }
  }

  Future<void> _deleteProfileImage(AuthService authService) async {
    try {
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => const Center(
          child: CircularProgressIndicator(),
        ),
      );

      await authService.deleteProfileImage();
      
      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('프로필 사진이 삭제되었습니다')),
        );
      }
    } catch (e) {
      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('오류: $e')),
        );
      }
    }
  }

  Future<void> _searchMyExtensions(BuildContext context) async {
    // ProfileTab의 _searchMyExtensions 메서드 구현을 복제
    // 이 메서드는 매우 길기 때문에 ProfileTab에서 가져와야 합니다
    if (kDebugMode) {
      debugPrint('🔍 단말번호 조회 시작');
    }
    
    setState(() {
      _isSearching = true;
      _searchError = null;
    });

    try {
      final authService = context.read<AuthService>();
      final userModel = authService.currentUserModel;
      final userId = authService.currentUser?.uid ?? '';

      if (userModel?.apiBaseUrl == null) {
        setState(() {
          _searchError = 'API 서버를 먼저 설정해주세요.';
          _isSearching = false;
        });
        return;
      }

      // API Service 생성
      final apiService = ApiService(
        baseUrl: userModel!.getApiUrl(useHttps: false),
        companyId: userModel.companyId,
        appKey: userModel.appKey,
      );

      // 단말번호 조회
      final dataList = await apiService.getExtensions();
      final userEmail = userModel.email ?? '';
      
      // 내 이메일과 일치하는 단말번호 필터링
      final myExtensions = dataList.where((item) {
        final email = item['email']?.toString() ?? '';
        return email.toLowerCase() == userEmail.toLowerCase();
      }).toList();

      if (myExtensions.isEmpty) {
        setState(() {
          _searchError = '내 이메일과 일치하는 단말번호를 찾을 수 없습니다.';
          _isSearching = false;
        });
        return;
      }

      // 단말번호 선택 다이얼로그 표시
      if (!mounted) return;
      
      await _showExtensionSelectionDialog(context, myExtensions, userId);
      
    } catch (e) {
      if (kDebugMode) {
        debugPrint('❌ 단말번호 조회 실패: $e');
      }
      setState(() {
        _searchError = '조회 실패: $e';
      });
    } finally {
      if (mounted) {
        setState(() {
          _isSearching = false;
        });
      }
    }
  }

  Future<void> _showExtensionSelectionDialog(
    BuildContext context,
    List<Map<String, dynamic>> extensions,
    String userId,
  ) async {
    // ProfileTab의 다이얼로그 구현을 복제
    // 간단한 구현으로 대체
    await showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('단말번호 선택'),
          content: SizedBox(
            width: double.maxFinite,
            child: ListView.builder(
              shrinkWrap: true,
              itemCount: extensions.length,
              itemBuilder: (context, index) {
                final ext = extensions[index];
                final extension = ext['extension']?.toString() ?? '';
                final name = ext['name']?.toString() ?? '';
                
                return ListTile(
                  leading: const Icon(Icons.phone_android),
                  title: Text(extension),
                  subtitle: Text(name.isNotEmpty ? name : '이름 없음'),
                  onTap: () async {
                    Navigator.pop(context);
                    await _saveExtension(ext, userId);
                  },
                );
              },
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('취소'),
            ),
          ],
        );
      },
    );
  }

  Future<void> _saveExtension(Map<String, dynamic> apiData, String userId) async {
    try {
      final myExtension = MyExtensionModel.fromApi(
        userId: userId,
        apiData: apiData,
      );

      await DatabaseService().addMyExtension(myExtension);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('단말번호가 저장되었습니다'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('저장 실패: $e')),
        );
      }
    }
  }

  Future<void> _deleteExtension(BuildContext context, MyExtensionModel extension) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('단말번호 삭제'),
        content: Text('${extension.extension}을(를) 삭제하시겠습니까?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('취소'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('삭제'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      try {
        await DatabaseService().deleteMyExtension(extension.id);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('단말번호가 삭제되었습니다')),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('삭제 실패: $e')),
          );
        }
      }
    }
  }

  Future<void> _deleteAllExtensions(BuildContext context, String userId) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('전체 삭제'),
        content: const Text('모든 단말번호를 삭제하시겠습니까?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('취소'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('전체 삭제'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      try {
        await DatabaseService().deleteAllMyExtensions(userId);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('모든 단말번호가 삭제되었습니다')),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('삭제 실패: $e')),
          );
        }
      }
    }
  }

  void _showExtensionDetails(BuildContext context, MyExtensionModel extension) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(extension.extension),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (extension.name.isNotEmpty)
              Text('이름: ${extension.name}'),
            Text('저장 시간: ${extension.createdAt.toString().substring(0, 19)}'),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('확인'),
          ),
        ],
      ),
    );
  }
}
