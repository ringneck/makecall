import 'package:flutter/material.dart';
import '../../utils/dialog_utils.dart';
import 'package:flutter/services.dart';
import 'package:flutter/foundation.dart';
import 'package:provider/provider.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:io';
import '../../services/auth_service.dart';
import '../../services/api_service.dart';
import '../../services/database_service.dart';
import '../../models/my_extension_model.dart';
import 'api_settings_dialog.dart';
import 'active_sessions_screen.dart';
import '../../widgets/theme_settings_dialog.dart';

class ProfileTab extends StatefulWidget {
  const ProfileTab({super.key});

  @override
  State<ProfileTab> createState() => _ProfileTabState();
}

class _ProfileTabState extends State<ProfileTab> {
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
      // 등록된 단말번호 정보 업데이트
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
        await DialogUtils.showSuccess(
          context,
          '정보가 업데이트되었습니다',
          duration: const Duration(seconds: 2),
        );
      }
    } catch (e) {
      if (kDebugMode) {
        debugPrint('❌ 새로고침 실패: $e');
      }
      
      if (mounted) {
        await DialogUtils.showError(
          context,
          '업데이트 실패: $e',
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

  // 등록된 단말번호 정보 업데이트
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
      
      // 5. 등록된 단말번호 가져오기 (마이그레이션 후)
      final allSavedExtensions = await dbService.getMyExtensions(userId).first;

      if (allSavedExtensions.isEmpty) {
        return;
      }

      // API Service 생성
      // apiHttpPort가 3501이면 HTTPS 사용, 3500이면 HTTP 사용
      final useHttps = (userModel!.apiHttpPort ?? 3500) == 3501;
      
      final apiService = ApiService(
        baseUrl: userModel.getApiUrl(useHttps: useHttps),
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

      print('✅ 등록된 단말번호 정보 업데이트 완료 (${savedExtensions.length}개)');
    } catch (e) {
      print('⚠️ 단말번호 업데이트 실패: $e');
      // 에러가 발생해도 UI는 정상적으로 표시되도록 무시
    }
  }

  @override
  Widget build(BuildContext context) {
    final authService = context.watch<AuthService>();
    final userModel = authService.currentUserModel;
    final userId = authService.currentUser?.uid ?? '';

    final isDark = Theme.of(context).brightness == Brightness.dark;
    
    return Scaffold(
      appBar: AppBar(
        title: const Text('단말'),
      ),
      body: ListView(
        children: [
          const SizedBox(height: 24),
          // 사용자 정보
          Stack(
            alignment: Alignment.center,
            children: [
              GestureDetector(
                onTap: () => _showProfileImageOptions(context, authService),
                child: CircleAvatar(
                  radius: 50,
                  backgroundColor: isDark 
                      ? const Color(0xFF2196F3).withAlpha(100)
                      : const Color(0xFF2196F3).withAlpha(51),
                  backgroundImage: userModel?.profileImageUrl != null
                      ? NetworkImage(userModel!.profileImageUrl!)
                      : null,
                  child: userModel?.profileImageUrl == null
                      ? Icon(
                          Icons.person, 
                          size: 50, 
                          color: isDark ? Colors.blue[300] : const Color(0xFF2196F3),
                        )
                      : null,
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
                      color: isDark ? Colors.blue[700] : const Color(0xFF2196F3),
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: isDark ? Colors.grey[800]! : Colors.white, 
                        width: 2,
                      ),
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
            style: TextStyle(
              fontSize: 18, 
              fontWeight: FontWeight.bold,
              color: isDark ? Colors.grey[200] : Colors.black87,
            ),
          ),
          const SizedBox(height: 8),
          // 단말번호 제한 안내
          Text(
            '단말번호 저장 가능: 최대 ${userModel?.maxExtensions ?? 1}개',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: isDark ? Colors.blue[300] : const Color(0xFF2196F3),
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
                    color: isDark ? Colors.grey[500] : Colors.grey[600],
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
                          : Icon(
                              Icons.refresh,
                              size: 14,
                              color: const Color(0xFF2196F3),
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
          
          // 활성 세션 관리 (중복 로그인 방지)
          ListTile(
            leading: const Icon(Icons.devices, size: 22, color: Colors.orange),
            title: const Text('활성 세션 관리', style: TextStyle(fontSize: 15)),
            subtitle: const Text(
              '로그인된 기기 확인 및 원격 로그아웃',
              style: TextStyle(fontSize: 11),
            ),
            trailing: const Icon(Icons.chevron_right),
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => const ActiveSessionsScreen(),
                ),
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
                                  '등록된 단말번호가 없습니다.',
                                  style: TextStyle(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w600,
                                    color: Colors.grey,
                                  ),
                                ),
                                SizedBox(height: 4),
                                Text(
                                  '위의 전화번호를 입력하고 조회 버튼을 눌러주세요.',
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
                          }).toList(),
                        ],
                      );
                    },
                  ),
              ],
            ),
          ),
          
          const Divider(),
          
          // 화면 테마 (🎨 눈에 띄는 스타일로 표시)
          Container(
            color: Colors.amber.withValues(alpha: 0.1),
            child: ListTile(
              leading: Icon(
                Icons.brightness_6, 
                size: 24,
                color: isDark ? Colors.amber[300] : Colors.orange[700],
              ),
              title: Text(
                '화면 테마',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: isDark ? Colors.amber[300] : Colors.orange[800],
                ),
              ),
              subtitle: const Text(
                '라이트 모드, 다크 모드, 시스템 설정',
                style: TextStyle(fontSize: 11),
              ),
              trailing: Icon(
                Icons.chevron_right,
                color: isDark ? Colors.amber[300] : Colors.orange[700],
              ),
              onTap: () {
                if (kDebugMode) {
                  debugPrint('🎨 화면 테마 메뉴 탭됨!');
                }
                showDialog(
                  context: context,
                  builder: (context) => const ThemeSettingsDialog(),
                );
              },
            ),
          ),
          const Divider(),
        ],
      ),
    );
  }

  // 정보 행 위젯
  Widget _buildInfoRow(IconData icon, String label, String value, {bool highlight = false}) {
    return Row(
      children: [
        Icon(icon, size: 14, color: highlight ? Colors.orange : Colors.grey),
        const SizedBox(width: 8),
        Text(
          '$label:',
          style: TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w600,
            color: highlight ? Colors.orange[800] : Colors.grey[700],
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            value,
            style: TextStyle(
              fontSize: 11,
              color: highlight ? Colors.orange[900] : Colors.black87,
              fontWeight: highlight ? FontWeight.bold : FontWeight.normal,
            ),
          ),
        ),
      ],
    );
  }
  
  // 내 전화번호로 단말번호 조회 및 DB 저장
  Future<void> _searchMyExtensions(BuildContext context) async {
    final authService = context.read<AuthService>();
    final userModel = authService.currentUserModel;
    final userId = authService.currentUser?.uid ?? '';
    final userEmail = userModel?.email ?? '';

    if (userModel?.apiBaseUrl == null) {
      setState(() {
        _searchError = 'API 서버가 설정되지 않았습니다.';
      });
      return;
    }

    if (userEmail.isEmpty) {
      setState(() {
        _searchError = '사용자 이메일 정보가 없습니다.';
      });
      return;
    }

    setState(() {
      _isSearching = true;
      _searchError = null;
    });

    try {
      // API Service 생성
      // apiHttpPort가 3501이면 HTTPS 사용, 3500이면 HTTP 사용
      final useHttps = (userModel!.apiHttpPort ?? 3500) == 3501;
      
      final apiService = ApiService(
        baseUrl: userModel.getApiUrl(useHttps: useHttps),
        companyId: userModel.companyId,
        appKey: userModel.appKey,
      );

      // 사용자 이메일로 단말번호 조회
      final matchedExtensions = await apiService.getMyExtensionsFromInternalPhonebook(
        userEmail: userEmail,
      );

      setState(() {
        _isSearching = false;
      });

      // 키보드 숨기기
      if (context.mounted) {
        FocusScope.of(context).unfocus();
      }

      if (matchedExtensions.isEmpty) {
        if (context.mounted) {
          final isDark = Theme.of(context).brightness == Brightness.dark;
          
          showDialog(
            context: context,
            builder: (context) => AlertDialog(
              backgroundColor: isDark ? Colors.grey[900] : Colors.white,
              icon: Icon(
                Icons.info_outline, 
                color: isDark ? Colors.orange[300] : Colors.orange, 
                size: 48,
              ),
              title: Text(
                '단말번호 없음',
                style: TextStyle(
                  color: isDark ? Colors.grey[200] : Colors.black87,
                ),
              ),
              content: Text(
                '이메일이 "$userEmail"인 \n단말번호를 찾을 수 없습니다.\n\n'
                '관리자에게 단말번호 등록을 요청하세요.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 13,
                  color: isDark ? Colors.grey[300] : Colors.black87,
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: Text(
                    '확인',
                    style: TextStyle(
                      color: isDark ? Colors.blue[300] : const Color(0xFF2196F3),
                    ),
                  ),
                ),
              ],
            ),
          );
        }
        return;
      }

      // ✅ CRITICAL: maxExtensions 제한 확인 (다이얼로그 표시 전에 먼저 체크!)
      // 🔥 FIXED: my_extensions 컬렉션에서 실제 등록된 단말번호 개수 확인
      final myExtensionsSnapshot = await DatabaseService().getMyExtensions(userId).first;
      final currentExtensionCount = myExtensionsSnapshot.length;
      final maxExtensions = authService.currentUserModel?.maxExtensions ?? 1;
      
      if (kDebugMode) {
        debugPrint('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━');
        debugPrint('🔍 maxExtensions 제한 체크');
        debugPrint('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━');
        debugPrint('📊 UserModel 존재: ${authService.currentUserModel != null}');
        debugPrint('📊 my_extensions 컬렉션 조회 완료');
        debugPrint('📊 현재 등록된 단말번호 개수 (my_extensions): $currentExtensionCount');
        debugPrint('📊 등록된 단말번호 목록: ${myExtensionsSnapshot.map((e) => e.extension).toList()}');
        debugPrint('📊 최대 등록 가능 개수: $maxExtensions');
        debugPrint('📊 비교 결과: $currentExtensionCount >= $maxExtensions = ${currentExtensionCount >= maxExtensions}');
        debugPrint('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━');
      }
      
      if (currentExtensionCount >= maxExtensions) {
        if (kDebugMode) {
          debugPrint('❌ 단말번호 등록 한도 초과: 현재 $currentExtensionCount개, 최대 $maxExtensions개');
        }
        
        if (context.mounted) {
          final isDark = Theme.of(context).brightness == Brightness.dark;
          
          showDialog(
            context: context,
            builder: (context) => AlertDialog(
              backgroundColor: isDark ? Colors.grey[900] : Colors.white,
              title: Row(
                children: [
                  Icon(
                    Icons.warning_amber_rounded, 
                    color: isDark ? Colors.orange[300] : Colors.orange, 
                    size: 28,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    '등록 한도 초과', 
                    style: TextStyle(
                      fontSize: 18,
                      color: isDark ? Colors.grey[200] : Colors.black87,
                    ),
                  ),
                ],
              ),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '단말번호는 최대 $maxExtensions개까지 등록할 수 있습니다.',
                    style: TextStyle(
                      fontSize: 14,
                      color: isDark ? Colors.grey[300] : Colors.black87,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: isDark 
                          ? Colors.orange[900]!.withValues(alpha: 0.3)
                          : Colors.orange[50],
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        color: isDark ? Colors.orange[700]! : Colors.orange[200]!,
                      ),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Icon(
                              Icons.info_outline, 
                              size: 16, 
                              color: isDark ? Colors.orange[300] : Colors.orange,
                            ),
                            const SizedBox(width: 6),
                            Text(
                              '현재 등록된 단말번호: $currentExtensionCount개',
                              style: TextStyle(
                                fontSize: 13, 
                                fontWeight: FontWeight.bold,
                                color: isDark ? Colors.orange[200] : Colors.black87,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Text(
                          '더 많은 단말번호를 등록하려면 기존 단말번호를 삭제하거나 관리자에게 문의하세요.',
                          style: TextStyle(
                            fontSize: 12, 
                            color: isDark ? Colors.grey[400] : Colors.black87,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: Text(
                    '확인', 
                    style: TextStyle(
                      fontSize: 14,
                      color: isDark ? Colors.blue[300] : const Color(0xFF2196F3),
                    ),
                  ),
                ),
              ],
            ),
          );
        }
        return;
      }

      // 단말번호 선택 다이얼로그 표시
      if (context.mounted) {
        await _showExtensionSelectionDialog(
          context,
          matchedExtensions,
          userEmail,
          userId,
          authService,
        );
      }

    } catch (e) {
      setState(() {
        _isSearching = false;
        _searchError = '단말번호 조회 실패: ${e.toString()}';
      });
    }
  }

  // 단말번호 선택 다이얼로그
  Future<void> _showExtensionSelectionDialog(
    BuildContext context,
    List<Map<String, dynamic>> extensions,
    String userEmail,
    String userId,
    AuthService authService,
  ) async {
    // 각 단말번호의 등록 상태 확인
    final dbService = DatabaseService();
    final registrationStatus = <String, Map<String, dynamic>?>{};
    
    for (final ext in extensions) {
      final extension = ext['extension'] as String;
      registrationStatus[extension] = await dbService.checkExtensionRegistration(extension);
    }
    
    if (!context.mounted) return;
    
    final isDark = Theme.of(context).brightness == Brightness.dark;
    
    final selected = await showDialog<String>(
      context: context,
      builder: (context) {
        return AlertDialog(
          backgroundColor: isDark ? Colors.grey[900] : Colors.white,
          title: Text(
            '단말번호 선택', 
            style: TextStyle(
              fontSize: 18,
              color: isDark ? Colors.grey[200] : Colors.black87,
            ),
          ),
          content: SizedBox(
            width: double.maxFinite,
            child: ListView.builder(
              shrinkWrap: true,
              itemCount: extensions.length,
              itemBuilder: (context, index) {
                final ext = extensions[index];
                final extension = ext['extension'] as String;
                final name = ext['name'] as String? ?? '';
                final email = ext['email'] as String? ?? '';
                
                final registrationInfo = registrationStatus[extension];
                final isRegistered = registrationInfo != null;
                final registeredEmail = registrationInfo?['userEmail'] as String? ?? '';
                
                return ListTile(
                  leading: Icon(
                    isRegistered ? Icons.lock : Icons.phone_android,
                    color: isRegistered 
                        ? (isDark ? Colors.grey[600] : Colors.grey) 
                        : (isDark ? Colors.blue[300] : const Color(0xFF2196F3)),
                  ),
                  title: Row(
                    children: [
                      Text(
                        extension,
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.bold,
                          color: isRegistered 
                              ? (isDark ? Colors.grey[500] : Colors.grey) 
                              : (isDark ? Colors.grey[200] : Colors.black),
                        ),
                      ),
                      if (isRegistered) ...[
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: isDark ? Colors.grey[700] : Colors.grey[300],
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(
                            '사용중',
                            style: TextStyle(
                              fontSize: 10, 
                              color: isDark ? Colors.grey[400] : Colors.black54,
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                  subtitle: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (name.isNotEmpty) 
                        Text(
                          name, 
                          style: TextStyle(
                            fontSize: 13, 
                            color: isRegistered 
                                ? (isDark ? Colors.grey[600] : Colors.grey) 
                                : (isDark ? Colors.grey[400] : Colors.black87),
                          ),
                        ),
                      if (email.isNotEmpty) 
                        Text(
                          email, 
                          style: TextStyle(
                            fontSize: 12, 
                            color: isDark ? Colors.grey[500] : Colors.grey,
                          ),
                        ),
                      if (isRegistered && registeredEmail.isNotEmpty)
                        Text(
                          '🔒 등록자: $registeredEmail',
                          style: TextStyle(
                            fontSize: 11, 
                            color: isDark ? Colors.red[300] : Colors.redAccent,
                          ),
                        ),
                    ],
                  ),
                  enabled: !isRegistered,
                  onTap: isRegistered ? null : () => Navigator.pop(context, extension),
                );
              },
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text(
                '취소', 
                style: TextStyle(
                  fontSize: 14,
                  color: isDark ? Colors.blue[300] : const Color(0xFF2196F3),
                ),
              ),
            ),
          ],
        );
      },
    );

    if (selected != null && context.mounted) {
      if (kDebugMode) {
        debugPrint('🔍 선택된 단말번호: "$selected"');
      }
      
      // registered_extensions에서 등록 여부 확인 (내 계정 포함)
      try {
        final dbService = DatabaseService();
        final registrationInfo = await dbService.checkExtensionRegistration(selected);
        
        if (registrationInfo != null) {
          // 이미 등록되어 있음 - 내가 등록한 건지 확인
          final registeredUserId = registrationInfo['userId'] as String? ?? '';
          final registeredEmail = registrationInfo['userEmail'] as String? ?? '';
          final registeredName = registrationInfo['userName'] as String? ?? '';
          final currentUserId = authService.currentUser?.uid ?? '';
          
          if (registeredUserId == currentUserId) {
            // 내가 이미 등록한 단말번호
            if (kDebugMode) {
              debugPrint('⚠️ 내 계정에 이미 등록된 단말번호: $selected');
            }
            
            if (context.mounted) {
              await DialogUtils.showWarning(
                context,
                '이미 내 계정에 등록된 단말번호입니다.',
                duration: const Duration(seconds: 2),
              );
            }
            return;
          }
          
          // 다른 사용자가 이미 등록함
          if (kDebugMode) {
            debugPrint('❌ 단말번호 "$selected"는 다른 사용자가 사용 중: $registeredEmail');
          }
          
          if (context.mounted) {
            final isDark = Theme.of(context).brightness == Brightness.dark;
            
            showDialog(
              context: context,
              builder: (context) => AlertDialog(
                backgroundColor: isDark ? Colors.grey[900] : Colors.white,
                title: Text(
                  '등록 불가', 
                  style: TextStyle(
                    fontSize: 18,
                    color: isDark ? Colors.grey[200] : Colors.black87,
                  ),
                ),
                content: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '이 단말번호는 다른 사용자가 이미 등록했습니다.', 
                      style: TextStyle(
                        fontSize: 14,
                        color: isDark ? Colors.grey[300] : Colors.black87,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: isDark ? Colors.grey[850] : Colors.grey[100],
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            '📱 단말번호: $selected', 
                            style: TextStyle(
                              fontSize: 13, 
                              fontWeight: FontWeight.bold,
                              color: isDark ? Colors.grey[200] : Colors.black87,
                            ),
                          ),
                          if (registeredName.isNotEmpty)
                            Text(
                              '👤 사용자: $registeredName', 
                              style: TextStyle(
                                fontSize: 13,
                                color: isDark ? Colors.grey[300] : Colors.black87,
                              ),
                            ),
                          if (registeredEmail.isNotEmpty)
                            Text(
                              '📧 이메일: $registeredEmail', 
                              style: TextStyle(
                                fontSize: 13,
                                color: isDark ? Colors.grey[300] : Colors.black87,
                              ),
                            ),
                        ],
                      ),
                    ),
                  ],
                ),
                actions: [
                  TextButton(
                    onPressed: () => Navigator.pop(context),
                    child: Text(
                      '확인', 
                      style: TextStyle(
                        fontSize: 14,
                        color: isDark ? Colors.blue[300] : const Color(0xFF2196F3),
                      ),
                    ),
                  ),
                ],
              ),
            );
          }
          return;
        }
        
        // 사용 가능 - 등록 진행
        if (kDebugMode) {
          debugPrint('💾 단말번호 등록 시작: $selected');
        }
        
        final userId = authService.currentUser?.uid ?? '';
        final userEmail = authService.currentUser?.email ?? '';
        final userName = authService.currentUserModel?.phoneNumberName ?? '';
        final currentMyExtensions = authService.currentUserModel?.myExtensions ?? [];
        
        // 선택된 extension의 이름 가져오기
        final selectedExtData = extensions.firstWhere(
          (ext) => ext['extension'] == selected,
          orElse: () => {},
        );
        final selectedName = selectedExtData['name'] as String? ?? '';
        
        // 1. registered_extensions 컬렉션에 등록 (중복 방지용)
        await dbService.registerExtension(
          extension: selected,
          userId: userId,
          userEmail: userEmail,
          userName: userName,
        );
        
        // 2. my_extensions 컬렉션에 추가 (UI 표시용)
        final myExtension = MyExtensionModel(
          id: '', // DatabaseService.addMyExtension에서 자동 생성
          userId: userId,
          extensionId: '', // API에서 가져올 때까지 비워둠
          extension: selected,
          name: selectedName,
          classOfServicesId: '', // API에서 가져올 때까지 비워둠
          createdAt: DateTime.now(),
          // API 설정은 사용자 프로필에서 가져옴
          apiBaseUrl: authService.currentUserModel?.apiBaseUrl,
          companyId: authService.currentUserModel?.companyId,
          appKey: authService.currentUserModel?.appKey,
          apiHttpPort: authService.currentUserModel?.apiHttpPort,
          apiHttpsPort: authService.currentUserModel?.apiHttpsPort,
        );
        await dbService.addMyExtension(myExtension);
        
        // 3. users 문서 업데이트
        // myExtensions 배열에 추가 (중복 방지)
        List<String>? updatedExtensions;
        if (!currentMyExtensions.contains(selected)) {
          updatedExtensions = [...currentMyExtensions, selected];
        }
        
        // phoneNumber와 phoneNumberName도 함께 업데이트
        await authService.updateUserInfo(
          phoneNumber: selected,
          phoneNumberName: selectedName.isNotEmpty ? selectedName : selected,
          myExtensions: updatedExtensions ?? currentMyExtensions,
        );
        
        // 상태 업데이트 완료 대기
        await Future.delayed(const Duration(milliseconds: 500));
        
        if (kDebugMode) {
          debugPrint('✅ 단말번호 등록 완료: $selected');
          debugPrint('   - registered_extensions 등록');
          debugPrint('   - my_extensions 컬렉션 추가');
          debugPrint('   - users.myExtensions 배열 업데이트');
          debugPrint('   - users.phoneNumber: $selected');
          debugPrint('   - users.phoneNumberName: ${selectedName.isNotEmpty ? selectedName : selected}');
        }

        if (context.mounted) {
          await DialogUtils.showSuccess(
            context,
            '단말번호 "$selected"이(가) 등록되었습니다.',
            duration: const Duration(seconds: 2),
          );
        }
      } catch (e) {
        if (kDebugMode) {
          debugPrint('❌ 단말번호 등록 오류: $e');
        }
        
        if (context.mounted) {
          await DialogUtils.showError(
            context,
            '단말번호 등록 실패: $e',
          );
        }
      }
    }
  }

  // 단말번호 삭제
  Future<void> _deleteExtension(BuildContext context, MyExtensionModel extension) async {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: isDark ? Colors.grey[900] : Colors.white,
        title: Text(
          '단말번호 삭제',
          style: TextStyle(
            color: isDark ? Colors.grey[200] : Colors.black87,
          ),
        ),
        content: Text(
          '${extension.extension} (${extension.name})을(를) 삭제하시겠습니까?',
          style: TextStyle(
            color: isDark ? Colors.grey[300] : Colors.black87,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(
              '취소',
              style: TextStyle(
                color: isDark ? Colors.grey[400] : Colors.grey[600],
              ),
            ),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('삭제'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      try {
        final authService = context.read<AuthService>();
        final dbService = DatabaseService();
        
        // 1. my_extensions 컬렉션에서 삭제
        await dbService.deleteMyExtension(extension.id);
        
        // 2. users 문서의 myExtensions 배열에서 제거
        final currentMyExtensions = authService.currentUserModel?.myExtensions ?? [];
        final updatedExtensions = currentMyExtensions.where((e) => e != extension.extension).toList();
        await authService.updateUserInfo(myExtensions: updatedExtensions);
        
        // 3. registered_extensions 컬렉션에서 등록 해제
        await dbService.unregisterExtension(extension.extension);
        
        if (kDebugMode) {
          debugPrint('✅ 단말번호 삭제 완료: ${extension.extension}');
          debugPrint('   - my_extensions 컬렉션 삭제');
          debugPrint('   - users.myExtensions 배열 업데이트');
          debugPrint('   - registered_extensions 등록 해제');
        }
        
        if (context.mounted) {
          await DialogUtils.showSuccess(context, '단말번호가 삭제되었습니다.', duration: const Duration(seconds: 2));
        }
      } catch (e) {
        if (kDebugMode) {
          debugPrint('❌ 단말번호 삭제 실패: $e');
        }
        
        if (context.mounted) {
          await DialogUtils.showError(
            context,
            '삭제 실패: $e',
          );
        }
      }
    }
  }

  // 전체 삭제
  Future<void> _deleteAllExtensions(BuildContext context, String userId) async {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: isDark ? Colors.grey[900] : Colors.white,
        title: Text(
          '전체 삭제',
          style: TextStyle(
            color: isDark ? Colors.grey[200] : Colors.black87,
          ),
        ),
        content: Text(
          '저장된 모든 단말번호를 삭제하시겠습니까?\n\n이 작업은 되돌릴 수 없습니다.',
          style: TextStyle(
            color: isDark ? Colors.grey[300] : Colors.black87,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(
              '취소',
              style: TextStyle(
                color: isDark ? Colors.grey[400] : Colors.grey[600],
              ),
            ),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('전체 삭제'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      try {
        final authService = context.read<AuthService>();
        final dbService = DatabaseService();
        
        // 1. 현재 등록된 단말번호 목록 가져오기
        final currentMyExtensions = authService.currentUserModel?.myExtensions ?? [];
        
        // 2. my_extensions 컬렉션에서 전체 삭제
        await dbService.deleteAllMyExtensions(userId);
        
        // 3. users 문서의 myExtensions 배열 비우기
        await authService.updateUserInfo(myExtensions: []);
        
        // 4. registered_extensions에서 각 단말번호 등록 해제
        for (final extension in currentMyExtensions) {
          await dbService.unregisterExtension(extension);
        }
        
        if (kDebugMode) {
          debugPrint('✅ 모든 단말번호 삭제 완료 (${currentMyExtensions.length}개)');
          debugPrint('   - my_extensions 컬렉션 전체 삭제');
          debugPrint('   - users.myExtensions 배열 초기화');
          debugPrint('   - registered_extensions 등록 해제: $currentMyExtensions');
        }
        
        if (context.mounted) {
          await DialogUtils.showSuccess(context, '모든 단말번호가 삭제되었습니다.', duration: const Duration(seconds: 2));
        }
      } catch (e) {
        if (kDebugMode) {
          debugPrint('❌ 전체 삭제 실패: $e');
        }
        
        if (context.mounted) {
          await DialogUtils.showError(
            context,
            '삭제 실패: $e',
          );
        }
      }
    }
  }

  // 단말번호 상세 정보 표시
  void _showExtensionDetails(BuildContext context, MyExtensionModel extension) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: isDark ? Colors.grey[900] : Colors.white,
        title: Row(
          children: [
            Icon(
              Icons.phone_android, 
              color: isDark ? Colors.blue[300] : const Color(0xFF2196F3),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                extension.extension,
                style: TextStyle(
                  fontSize: 18,
                  color: isDark ? Colors.grey[200] : Colors.black87,
                ),
              ),
            ),
          ],
        ),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // 기본 정보
              _buildDetailRow('단말번호', extension.extension, isDark),
              _buildDetailRow('이름', extension.name, isDark),
              _buildDetailRow('계정코드', extension.accountCode, isDark),
              
              // 외부발신 정보
              if (extension.externalCidName != null && extension.externalCidName!.isNotEmpty)
                const Divider(height: 24),
              if (extension.externalCidName != null && extension.externalCidName!.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Text(
                    '외부발신 정보',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                      color: isDark ? Colors.green[300] : const Color(0xFF4CAF50),
                    ),
                  ),
                ),
              _buildDetailRow('외부발신 이름', extension.externalCidName, isDark),
              _buildDetailRow('외부발신 번호', extension.externalCidNumber, isDark),
              
              // SIP 정보
              if (extension.sipUserId != null && extension.sipUserId!.isNotEmpty)
                const Divider(height: 24),
              if (extension.sipUserId != null && extension.sipUserId!.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Text(
                    'SIP 정보',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                      color: isDark ? Colors.blue[300] : const Color(0xFF2196F3),
                    ),
                  ),
                ),
              _buildDetailRow('SIP user id', extension.sipUserId, isDark),
              _buildDetailRowWithCopy('SIP secret', extension.sipSecret, context, isDark),
              
              // 시스템 정보
              const Divider(height: 24),
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Text(
                  '시스템 정보',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    color: isDark ? Colors.grey[500] : Colors.grey,
                  ),
                ),
              ),
              _buildDetailRow('Extension ID', extension.extensionId, isDark),
              _buildDetailRow('COS ID', extension.classOfServicesId, isDark),
              _buildDetailRow('User ID', extension.userId, isDark),
              _buildDetailRow('저장 시간', extension.createdAt.toString().substring(0, 19), isDark),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(
              '닫기',
              style: TextStyle(
                color: isDark ? Colors.blue[300] : const Color(0xFF2196F3),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDetailRow(String label, String? value, bool isDark) {
    if (value == null || value.isEmpty) return const SizedBox.shrink();
    
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 100,
            child: Text(
              '$label:',
              style: TextStyle(
                fontWeight: FontWeight.w600,
                fontSize: 13,
                color: isDark ? Colors.grey[500] : Colors.grey,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: TextStyle(
                fontSize: 13,
                color: isDark ? Colors.grey[300] : Colors.black87,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDetailRowWithCopy(String label, String? value, BuildContext context, bool isDark) {
    if (value == null || value.isEmpty) return const SizedBox.shrink();
    
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 100,
            child: Text(
              '$label:',
              style: TextStyle(
                fontWeight: FontWeight.w600,
                fontSize: 13,
                color: isDark ? Colors.grey[500] : Colors.grey,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: TextStyle(
                fontSize: 13,
                color: isDark ? Colors.grey[300] : Colors.black87,
              ),
            ),
          ),
          IconButton(
            icon: Icon(
              Icons.copy, 
              size: 18,
              color: isDark ? Colors.grey[400] : Colors.grey[700],
            ),
            onPressed: () async {
              Clipboard.setData(ClipboardData(text: value));
              await DialogUtils.showSuccess(
                context,
                'SIP secret이 클립보드에 복사되었습니다',
                duration: const Duration(seconds: 2),
              );
            },
            tooltip: '복사',
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(),
          ),
        ],
      ),
    );
  }

  // 프로필 사진 옵션 다이얼로그
  void _showProfileImageOptions(BuildContext context, AuthService authService) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 16),
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.grey[300],
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 16),
            const Text(
              '프로필 사진',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 16),
            ListTile(
              leading: const Icon(Icons.camera_alt, color: Color(0xFF2196F3)),
              title: const Text('사진 촬영'),
              onTap: () {
                Navigator.pop(context);
                _pickImage(ImageSource.camera, authService);
              },
            ),
            ListTile(
              leading: const Icon(Icons.photo_library, color: Color(0xFF2196F3)),
              title: const Text('갤러리에서 선택'),
              onTap: () {
                Navigator.pop(context);
                _pickImage(ImageSource.gallery, authService);
              },
            ),
            if (authService.currentUserModel?.profileImageUrl != null)
              ListTile(
                leading: const Icon(Icons.delete, color: Colors.red),
                title: const Text('프로필 사진 삭제'),
                onTap: () {
                  Navigator.pop(context);
                  _deleteProfileImage(authService);
                },
              ),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }

  // 이미지 선택
  Future<void> _pickImage(ImageSource source, AuthService authService) async {
    try {
      if (kDebugMode) {
        debugPrint('🖼️ Starting image picker with source: $source');
      }
      
      final picker = ImagePicker();
      
      // iOS hang 방지: 약간의 지연을 추가하여 UI 스레드가 완전히 정리되도록 함
      await Future.delayed(const Duration(milliseconds: 100));
      
      final pickedFile = await picker.pickImage(
        source: source,
        maxWidth: 512,
        maxHeight: 512,
        imageQuality: 85,
        requestFullMetadata: false,  // iOS에서 메타데이터 요청을 건너뛰어 성능 향상
      );

      if (pickedFile == null) {
        if (kDebugMode) {
          debugPrint('⚠️ Image picker cancelled by user');
        }
        return;
      }

      if (kDebugMode) {
        debugPrint('✅ Image picked: ${pickedFile.path}');
      }

      // 로딩 다이얼로그 표시
      if (!mounted) return;
      
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => PopScope(
          canPop: false,  // 백버튼으로 닫기 방지
          child: const Center(
            child: Card(
              child: Padding(
                padding: EdgeInsets.all(24.0),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    CircularProgressIndicator(),
                    SizedBox(height: 16),
                    Text('프로필 사진 업로드 중...'),
                  ],
                ),
              ),
            ),
          ),
        ),
      );

      // Firebase Storage에 업로드 (비동기 처리)
      final imageFile = File(pickedFile.path);
      
      if (kDebugMode) {
        debugPrint('📤 Uploading image to Firebase Storage...');
      }
      
      await authService.uploadProfileImage(imageFile);

      if (kDebugMode) {
        debugPrint('✅ Image upload completed successfully');
      }

      if (!mounted) return;
      
      Navigator.pop(context); // 로딩 다이얼로그 닫기
      
      await DialogUtils.showSuccess(
        context,
        '프로필 사진이 업데이트되었습니다',
        duration: const Duration(seconds: 2),
      );
    } catch (e) {
      if (kDebugMode) {
        debugPrint('❌ Image upload error: $e');
      }
      
      if (!mounted) return;
      
      // 로딩 다이얼로그가 열려있으면 닫기
      Navigator.of(context, rootNavigator: true).popUntil((route) => route.isFirst);
      
      await DialogUtils.showError(
        context,
        '이미지 업로드 실패: ${e.toString()}',
      );
    }
  }

  // 프로필 사진 삭제
  Future<void> _deleteProfileImage(AuthService authService) async {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: isDark ? Colors.grey[900] : Colors.white,
        title: Text(
          '프로필 사진 삭제',
          style: TextStyle(
            color: isDark ? Colors.grey[200] : Colors.black87,
          ),
        ),
        content: Text(
          '프로필 사진을 삭제하시겠습니까?',
          style: TextStyle(
            color: isDark ? Colors.grey[300] : Colors.black87,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(
              '취소',
              style: TextStyle(
                color: isDark ? Colors.grey[400] : Colors.grey[600],
              ),
            ),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('삭제'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      try {
        await authService.deleteProfileImage();
        
        if (context.mounted) {
          await DialogUtils.showSuccess(context, '프로필 사진이 삭제되었습니다', duration: const Duration(seconds: 2));
        }
      } catch (e) {
        if (context.mounted) {
          await DialogUtils.showError(
            context,
            '삭제 실패: $e',
          );
        }
      }
    }
  }


}
