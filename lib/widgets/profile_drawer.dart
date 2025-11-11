import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:image_picker/image_picker.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:webview_flutter/webview_flutter.dart';
import 'dart:io';
import '../services/auth_service.dart';
import '../services/api_service.dart';
import '../services/database_service.dart';
import '../services/account_manager_service.dart';
import '../services/fcm_service.dart';
import '../services/dcmiws_service.dart';
import '../models/my_extension_model.dart';
import '../models/saved_account_model.dart';
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
  bool _keepLoginEnabled = true; // 자동 로그인 기본값: true
  final _phoneNumberController = TextEditingController();
  
  // FCM 알림 설정
  bool _pushEnabled = true;
  bool _soundEnabled = true;
  bool _vibrationEnabled = true;
  
  // 🎯 Premium 상태 캐싱 (성능 최적화)
  bool? _isPremiumCached;

  @override
  void initState() {
    super.initState();
    // 등록된 전화번호 불러오기 및 단말번호 업데이트
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final authService = context.read<AuthService>();
      if (authService.currentUserModel?.phoneNumber != null) {
        _phoneNumberController.text = authService.currentUserModel!.phoneNumber!;
      }
      // Premium 상태 캐싱
      _cachePremiumStatus();
      // 등록된 단말번호 정보 업데이트
      _updateSavedExtensions();
      // 자동 로그인 설정 불러오기 (Premium 전용)
      if (_isPremium) {
        _loadKeepLoginSetting();
      }
      // FCM 알림 설정 불러오기
      _loadNotificationSettings();
    });
  }
  
  /// 🎯 Premium 상태 캐싱 (성능 최적화)
  /// - AuthService에서 한 번만 읽어서 캐싱
  /// - 불필요한 반복 접근 방지
  void _cachePremiumStatus() {
    final authService = context.read<AuthService>();
    _isPremiumCached = authService.currentUserModel?.isPremium ?? false;
    
    if (kDebugMode) {
      debugPrint('🎯 Premium Status Cached: $_isPremiumCached');
    }
  }
  
  /// 🔒 Premium 상태 Getter (성능 최적화)
  /// - 캐시된 값 우선 사용
  /// - null인 경우에만 AuthService 접근
  bool get _isPremium {
    if (_isPremiumCached != null) {
      return _isPremiumCached!;
    }
    
    final authService = context.read<AuthService>();
    final isPremium = authService.currentUserModel?.isPremium ?? false;
    _isPremiumCached = isPremium; // 캐싱
    
    return isPremium;
  }

  // 자동 로그인 설정 불러오기
  Future<void> _loadKeepLoginSetting() async {
    if (kDebugMode) {
      debugPrint('📱 Loading Auto Login Setting...');
    }
    
    final enabled = await AccountManagerService().getKeepLoginEnabled();
    
    if (kDebugMode) {
      debugPrint('📱 Auto Login Setting loaded: $enabled');
    }
    
    if (mounted) {
      setState(() {
        _keepLoginEnabled = enabled;
      });
      
      if (kDebugMode) {
        debugPrint('📱 Auto Login UI updated: $_keepLoginEnabled');
      }
    }
  }

  // FCM 알림 설정 불러오기
  Future<void> _loadNotificationSettings() async {
    try {
      final authService = context.read<AuthService>();
      final userId = authService.currentUser?.uid;
      
      if (userId == null) return;
      
      final fcmService = FCMService();
      final settings = await fcmService.getUserNotificationSettings(userId);
      
      if (settings != null && mounted) {
        setState(() {
          _pushEnabled = settings['pushEnabled'] ?? true;
          _soundEnabled = settings['soundEnabled'] ?? true;
          _vibrationEnabled = settings['vibrationEnabled'] ?? true;
        });
        
        if (kDebugMode) {
          debugPrint('🔔 알림 설정 불러오기 완료');
          debugPrint('   - 푸시 알림: $_pushEnabled');
          debugPrint('   - 알림음: $_soundEnabled');
          debugPrint('   - 진동: $_vibrationEnabled');
        }
      }
    } catch (e) {
      if (kDebugMode) {
        debugPrint('❌ 알림 설정 불러오기 오류: $e');
      }
    }
  }

  // FCM 알림 설정 업데이트
  Future<void> _updateNotificationSetting(String key, bool value) async {
    try {
      final authService = context.read<AuthService>();
      final userId = authService.currentUser?.uid;
      
      if (userId == null) return;
      
      final fcmService = FCMService();
      await fcmService.updateSingleSetting(userId, key, value);
      
      if (kDebugMode) {
        debugPrint('✅ 알림 설정 업데이트: $key = $value');
      }
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('설정이 저장되었습니다'),
            duration: Duration(seconds: 1),
          ),
        );
      }
    } catch (e) {
      if (kDebugMode) {
        debugPrint('❌ 알림 설정 업데이트 오류: $e');
      }
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('설정 저장 실패: $e')),
        );
      }
    }
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

      // 등록된 각 단말번호에 대해 업데이트
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
        debugPrint('✅ 등록된 단말번호 정보 업데이트 완료 (${savedExtensions.length}개)');
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
          // 🎯 간결한 프로필 헤더 (한 줄)
          Container(
            padding: EdgeInsets.only(
              top: MediaQuery.of(context).padding.top + 12,
              left: 16,
              right: 16,
              bottom: 12,
            ),
            decoration: BoxDecoration(
              color: Colors.white,
              border: Border(
                bottom: BorderSide(color: Colors.grey[200]!, width: 1),
              ),
            ),
            child: InkWell(
              onTap: () => _showProfileDetailDialog(context, authService),
              borderRadius: BorderRadius.circular(8),
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 4),
                child: Row(
                  children: [
                    // 작은 썸네일
                    CircleAvatar(
                      radius: 20,
                      backgroundColor: Colors.transparent,
                      backgroundImage: userModel?.profileImageUrl != null
                          ? NetworkImage(userModel!.profileImageUrl!)
                          : const AssetImage('assets/icons/app_icon.png') as ImageProvider,
                    ),
                    const SizedBox(width: 12),
                    // 조직명 + 이메일 ID
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // 조직명 (있는 경우)
                          if (userModel?.companyName != null && userModel!.companyName!.isNotEmpty)
                            Text(
                              userModel.companyName!,
                              style: const TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.bold,
                                color: Colors.black87,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          // 이메일 ID
                          Text(
                            userModel?.email ?? '이메일 없음',
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.grey[600],
                              fontWeight: FontWeight.w500,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                    ),
                    // 상세보기 아이콘
                    Icon(Icons.chevron_right, size: 20, color: Colors.grey[400]),
                  ],
                ),
              ),
            ),
          ),
          
          // 기본 설정
          ListTile(
            leading: const Icon(Icons.settings, size: 20),
            title: const Text('기본 설정', style: TextStyle(fontSize: 13)),
            subtitle: const Text(
              'API 서버, WebSocket 설정',
              style: TextStyle(fontSize: 10),
            ),
            trailing: const Icon(Icons.chevron_right, size: 18),
            onTap: () {
              showDialog(
                context: context,
                builder: (context) => const ApiSettingsDialog(),
              );
            },
          ),
          const Divider(),
          
          // 🎯 간결한 내 단말번호 (한 줄)
          if (userId.isNotEmpty)
            StreamBuilder<List<MyExtensionModel>>(
              stream: DatabaseService().getMyExtensions(userId),
              builder: (context, snapshot) {
                final extensions = snapshot.data ?? [];
                final extensionCount = extensions.length;
                
                return ListTile(
                  leading: const Icon(Icons.phone_android, size: 20, color: Color(0xFF2196F3)),
                  title: const Text('내 단말번호', style: TextStyle(fontSize: 13)),
                  subtitle: Text(
                    extensionCount > 0 
                        ? '등록됨: ${extensions.map((e) => e.extension).join(", ")}'
                        : '등록된 단말번호가 없습니다',
                    style: TextStyle(
                      fontSize: 11,
                      color: extensionCount > 0 ? Colors.grey[700] : Colors.grey[500],
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (extensionCount > 0)
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: const Color(0xFF2196F3).withAlpha(26),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Text(
                            '$extensionCount개',
                            style: const TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                              color: Color(0xFF2196F3),
                            ),
                          ),
                        ),
                      const SizedBox(width: 8),
                      const Icon(Icons.chevron_right, size: 18),
                    ],
                  ),
                  onTap: () => _showExtensionsManagementDialog(context, extensions),
                );
              },
            ),
          const Divider(),
          // ============================================
          // 설정 섹션 시작
          // ============================================
          
          // 설정 섹션 헤더
          Container(
            padding: const EdgeInsets.fromLTRB(16, 20, 16, 12),
            color: Colors.grey[50],
            child: const Row(
              children: [
                Icon(Icons.settings, color: Color(0xFF2196F3), size: 20),
                SizedBox(width: 12),
                Text(
                  '설정',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: Colors.black87,
                  ),
                ),
              ],
            ),
          ),
          
          const Divider(height: 1),
          const SizedBox(height: 8),
          
          // 푸시 알림 설정
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Container(
              decoration: BoxDecoration(
                color: Colors.blue[50],
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.blue[100]!),
              ),
              child: const Column(
                children: [
                  ListTile(
                    leading: Icon(Icons.notifications, color: Color(0xFF2196F3)),
                    title: Text(
                      '푸시 알림',
                      style: TextStyle(fontWeight: FontWeight.w600),
                    ),
                    subtitle: Text('알림 수신 설정', style: TextStyle(fontSize: 12)),
                  ),
                  Divider(height: 1, indent: 72),
                ],
              ),
            ),
          ),
          
          _buildSwitchTile(
            icon: Icons.notifications_active,
            title: '푸시 알림 표시',
            subtitle: '새로운 통화 및 메시지 알림',
            value: _pushEnabled,
            onChanged: (value) {
              setState(() {
                _pushEnabled = value;
              });
              _updateNotificationSetting('pushEnabled', value);
            },
          ),
          
          _buildSwitchTile(
            icon: Icons.volume_up,
            title: '알림음',
            subtitle: '알림 수신 시 소리',
            value: _soundEnabled,
            onChanged: (value) {
              setState(() {
                _soundEnabled = value;
              });
              _updateNotificationSetting('soundEnabled', value);
            },
          ),
          
          _buildSwitchTile(
            icon: Icons.vibration,
            title: '진동',
            subtitle: '알림 수신 시 진동',
            value: _vibrationEnabled,
            onChanged: (value) {
              setState(() {
                _vibrationEnabled = value;
              });
              _updateNotificationSetting('vibrationEnabled', value);
            },
          ),
          
          const SizedBox(height: 16),
          const Divider(thickness: 1),
          const SizedBox(height: 8),
          
          // 🔔 알림 및 푸시 설정
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Container(
              decoration: BoxDecoration(
                color: Colors.orange[50],
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.orange[100]!),
              ),
              child: const ListTile(
                leading: Icon(Icons.notifications_active, color: Colors.orange),
                title: Text(
                  '알림 설정',
                  style: TextStyle(fontWeight: FontWeight.w600),
                ),
                subtitle: Text('푸시 알림 및 웹 알림 관리', style: TextStyle(fontSize: 12)),
              ),
            ),
          ),
          
          if (kIsWeb) ...[
            ListTile(
              contentPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 4),
              leading: const Icon(Icons.notifications, color: Colors.orange, size: 22),
              title: const Text('웹 푸시 알림 활성화', style: TextStyle(fontSize: 15)),
              subtitle: const Text(
                '브라우저 알림 권한 요청',
                style: TextStyle(fontSize: 11),
              ),
              trailing: const Icon(Icons.chevron_right, size: 20),
              onTap: () => _requestWebPushPermission(context),
            ),
            ListTile(
              contentPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 4),
              leading: const Icon(Icons.info_outline, size: 22),
              title: const Text('웹 푸시 정보', style: TextStyle(fontSize: 15)),
              subtitle: const Text(
                '웹 푸시 알림 사용 방법',
                style: TextStyle(fontSize: 11),
              ),
              trailing: const Icon(Icons.chevron_right, size: 20),
              onTap: () => _showWebPushInfo(context),
            ),
          ],
          
          const SizedBox(height: 16),
          const Divider(thickness: 1),
          const SizedBox(height: 8),
          
          // 약관 및 정책
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Container(
              decoration: BoxDecoration(
                color: Colors.purple[50],
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.purple[100]!),
              ),
              child: const ListTile(
                leading: Icon(Icons.description, color: Colors.purple),
                title: Text(
                  '약관 및 정책',
                  style: TextStyle(fontWeight: FontWeight.w600),
                ),
                subtitle: Text('이용약관, 개인정보처리방침', style: TextStyle(fontSize: 12)),
              ),
            ),
          ),
          
          ListTile(
            contentPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 4),
            leading: const Icon(Icons.description, size: 22),
            title: const Text('서비스 이용 약관', style: TextStyle(fontSize: 15)),
            trailing: const Icon(Icons.chevron_right, size: 20),
            onTap: () {
              _showWebViewPage(
                context,
                '서비스 이용 약관',
                'assets/html/terms_of_service.html',
              );
            },
          ),
          
          ListTile(
            contentPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 4),
            leading: const Icon(Icons.privacy_tip, size: 22),
            title: const Text('개인정보 처리방침', style: TextStyle(fontSize: 15)),
            trailing: const Icon(Icons.chevron_right, size: 20),
            onTap: () {
              _showWebViewPage(
                context,
                '개인정보 처리방침',
                'assets/html/privacy_policy.html',
              );
            },
          ),
          
          ListTile(
            contentPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 4),
            leading: const Icon(Icons.code, size: 22),
            title: const Text('오픈소스 라이선스', style: TextStyle(fontSize: 15)),
            trailing: const Icon(Icons.chevron_right, size: 20),
            onTap: () {
              _showLicensePage(context);
            },
          ),
          
          const SizedBox(height: 16),
          const Divider(thickness: 1),
          const SizedBox(height: 8),
          
          // 앱 정보
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Container(
              decoration: BoxDecoration(
                color: Colors.green[50],
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.green[100]!),
              ),
              child: FutureBuilder<PackageInfo>(
                future: PackageInfo.fromPlatform(),
                builder: (context, snapshot) {
                  final version = snapshot.data?.version ?? '1.0.0';
                  final buildNumber = snapshot.data?.buildNumber ?? '1';
                  return ListTile(
                    leading: const Icon(Icons.info, color: Colors.green),
                    title: const Text(
                      '앱 버전',
                      style: TextStyle(fontWeight: FontWeight.w600),
                    ),
                    subtitle: Text(
                      '$version ($buildNumber)',
                      style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w500),
                    ),
                  );
                },
              ),
            ),
          ),
          
          const SizedBox(height: 16),
          const Divider(thickness: 1),
          const SizedBox(height: 8),
          
          // 📱 계정 관리 섹션 (모든 사용자)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Container(
              decoration: BoxDecoration(
                color: Colors.orange[50],
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.orange[100]!),
              ),
              child: ListTile(
                leading: const Icon(Icons.account_circle, color: Colors.orange),
                title: Text(
                  _isPremium ? '계정 및 조직' : '내 계정',
                  style: const TextStyle(fontWeight: FontWeight.w600),
                ),
                subtitle: Text(
                  _isPremium 
                      ? '등록된 계정, 사용자 계정 추가 (Premium)' 
                      : '현재 로그인된 계정',
                  style: const TextStyle(fontSize: 12),
                ),
              ),
            ),
          ),
          
          // 📱 등록된 계정 목록 (모든 사용자)
          // Premium: 모든 계정 표시
          // 무료: 현재 계정만 표시
          // 🚫 멀티 계정 기능 비활성화
          FutureBuilder<List<SavedAccountModel>>(
            future: AccountManagerService().getSavedAccounts(),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Padding(
                  padding: EdgeInsets.all(16),
                  child: Center(child: CircularProgressIndicator()),
                );
              }
              
              final allAccounts = snapshot.data ?? [];
              
              // 🎯 Premium 여부에 따라 계정 목록 필터링
              // Premium: 모든 계정 표시
              // 무료: 현재 계정만 표시
              // 🚫 멀티 계정 기능 비활성화: 항상 현재 계정만 표시
              final accounts = /* _isPremium 
                  ? allAccounts 
                  : */ allAccounts.where((account) => account.isCurrentAccount).toList();
              
              if (accounts.isEmpty) {
                return Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
                  child: Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.grey[100],
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.grey[300]!),
                    ),
                    child: const Center(
                      child: Text(
                        '등록된 계정이 없습니다',
                        style: TextStyle(fontSize: 12, color: Colors.grey),
                      ),
                    ),
                  ),
                );
              }
              
              return Column(
                children: [
                  // 등록된 계정 제목
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
                    child: Row(
                      children: [
                        Icon(
                          _isPremium ? Icons.people : Icons.person,
                          size: 16,
                          color: Colors.grey,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          _isPremium 
                              ? '등록된 계정 (${accounts.length}개)' 
                              : '현재 계정',
                          style: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: Colors.grey,
                          ),
                        ),
                      ],
                    ),
                  ),
                  
                  // 계정 목록
                  ...accounts.map((account) {
                    return Container(
                      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                      decoration: BoxDecoration(
                        color: account.isCurrentAccount ? Colors.blue[50] : Colors.white,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: account.isCurrentAccount 
                              ? const Color(0xFF2196F3) 
                              : Colors.grey[300]!,
                          width: account.isCurrentAccount ? 2 : 1,
                        ),
                      ),
                      child: ListTile(
                        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                        leading: CircleAvatar(
                          radius: 20,
                          backgroundColor: Colors.transparent,
                          backgroundImage: account.profileImageUrl != null
                              ? NetworkImage(account.profileImageUrl!)
                              : const AssetImage('assets/icons/app_icon.png') as ImageProvider,
                        ),
                        title: Row(
                          children: [
                            Expanded(
                              child: Text(
                                account.displayName,
                                style: TextStyle(
                                  fontSize: 14,
                                  fontWeight: account.isCurrentAccount 
                                      ? FontWeight.bold 
                                      : FontWeight.w500,
                                ),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            if (account.companyName != null && account.companyName!.isNotEmpty)
                              Container(
                                margin: const EdgeInsets.only(left: 8),
                                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                decoration: BoxDecoration(
                                  color: Colors.blue[100],
                                  borderRadius: BorderRadius.circular(4),
                                ),
                                child: const Text(
                                  '조직',
                                  style: TextStyle(
                                    fontSize: 9,
                                    color: Colors.blue,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                          ],
                        ),
                        subtitle: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            if (account.companyName != null && account.companyName!.isNotEmpty)
                              Text(
                                account.email,
                                style: const TextStyle(fontSize: 11, color: Colors.grey),
                              ),
                            if (account.isCurrentAccount)
                              Container(
                                margin: const EdgeInsets.only(top: 4),
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                decoration: BoxDecoration(
                                  color: const Color(0xFF2196F3),
                                  borderRadius: BorderRadius.circular(4),
                                ),
                                child: const Text(
                                  '현재 계정',
                                  style: TextStyle(
                                    fontSize: 9,
                                    color: Colors.white,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                          ],
                        ),
                        trailing: account.isCurrentAccount
                            ? IconButton(
                                onPressed: () => _handleLogoutFromList(context),
                                icon: const Icon(Icons.logout),
                                color: Colors.orange,
                                tooltip: '로그아웃',
                                iconSize: 24,
                              )
                            : /* 🚫 멀티 계정 기능 비활성화 */ null,
                            /* : IconButton(
                                onPressed: () => _handleDeleteAccount(context, account),
                                icon: const Icon(Icons.delete_outline, size: 20),
                                color: Colors.red,
                                tooltip: '계정 삭제',
                              ), */
                        onTap: /* account.isCurrentAccount 
                            ? null 
                            : () => _handleSwitchAccount(context, account), */ null,
                      ),
                    );
                  }),
                  
                  const SizedBox(height: 8),
                ],
              );
            },
          ),
          
          // 구분선
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 24, vertical: 8),
            child: Divider(height: 1),
          ),
          
          // 🎯 Premium 전용: 자동 로그인 스위치
          // 🚫 멀티 계정 기능 비활성화
          /* if (_isPremium) ...[
            _buildSwitchTile(
              icon: Icons.lock_clock,
              title: '자동 로그인',
              subtitle: '계정 전환 시 비밀번호 없이 로그인 (Premium)',
              value: _keepLoginEnabled,
              onChanged: (value) async {
                await AccountManagerService().setKeepLoginEnabled(value);
                setState(() {
                  _keepLoginEnabled = value;
                });
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(
                        value 
                            ? '자동 로그인이 활성화되었습니다. 계정 전환 시 비밀번호 없이 로그인됩니다.' 
                            : '자동 로그인이 비활성화되었습니다. 계정 전환 시 확인 다이얼로그가 표시됩니다.',
                      ),
                      backgroundColor: value ? Colors.green : Colors.grey,
                    ),
                  );
                }
              },
            ),
            const SizedBox(height: 8),
          ], */
          
          // 🎯 Premium 전용: 사용자 계정 추가
          // 🚫 멀티 계정 기능 비활성화
          /* if (_isPremium)
            ListTile(
              contentPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 4),
              leading: const Icon(Icons.person_add, color: Colors.green, size: 22),
              title: const Text('사용자 계정 추가', style: TextStyle(fontSize: 15)),
              subtitle: const Text(
                '새로운 계정으로 로그인 (Premium)',
                style: TextStyle(fontSize: 11),
              ),
              trailing: const Icon(Icons.chevron_right, size: 20),
              onTap: () => _handleAddAccount(context),
            ), */
          
          // 🔒 무료 사용자: Premium 안내 메시지
          // 🚫 멀티 계정 기능 비활성화
          /* if (!_isPremium)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
              child: Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [Colors.amber[50]!, Colors.orange[50]!],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.orange[200]!),
                ),
                child: Row(
                  children: [
                    Icon(Icons.workspace_premium, color: Colors.orange[700], size: 32),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            '멀티 계정 로그인',
                            style: TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.bold,
                              color: Colors.orange[900],
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'Premium 사용자만 여러 계정을 동시에 사용할 수 있습니다',
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.orange[800],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ), */
          
          const SizedBox(height: 24),
          
          // 하단 여백
          const SizedBox(height: 16),
        ],
      ),
    );
  }
  
  // 스위치 타일 빌더 (가독성 향상)
  Widget _buildSwitchTile({
    required IconData icon,
    required String title,
    required String subtitle,
    required bool value,
    required ValueChanged<bool> onChanged,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.grey[200]!),
        ),
        child: SwitchListTile(
          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
          secondary: Icon(icon, color: const Color(0xFF2196F3), size: 22),
          title: Text(title, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500)),
          subtitle: Text(subtitle, style: const TextStyle(fontSize: 11)),
          value: value,
          onChanged: onChanged,
          activeTrackColor: const Color(0xFF2196F3).withAlpha(128),
          activeThumbColor: const Color(0xFF2196F3),
        ),
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
                      '등록 시간',
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
      // apiHttpPort가 3501이면 HTTPS 사용, 3500이면 HTTP 사용
      final useHttps = (userModel!.apiHttpPort ?? 3500) == 3501;
      
      if (kDebugMode) {
        debugPrint('📋 API 호출 설정:');
        debugPrint('  - apiHttpPort: ${userModel.apiHttpPort}');
        debugPrint('  - apiHttpsPort: ${userModel.apiHttpsPort}');
        debugPrint('  - useHttps: $useHttps');
        debugPrint('  - API URL: ${userModel.getApiUrl(useHttps: useHttps)}');
      }
      
      final apiService = ApiService(
        baseUrl: userModel.getApiUrl(useHttps: useHttps),
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
        
        // 에러 다이얼로그 표시 (자동으로 닫지 않음)
        if (!mounted) return;
        await showDialog(
          context: context,
          builder: (context) => AlertDialog(
            icon: const Icon(Icons.error_outline, color: Colors.orange, size: 48),
            title: const Text('단말번호 없음'),
            content: const Text('내 이메일과 일치하는 단말번호를 찾을 수 없습니다.\n\n관리자에게 단말번호 등록을 요청하세요.'),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('닫기'),
              ),
            ],
          ),
        );
        return;
      }

      // ✅ CRITICAL: maxExtensions 제한 확인 (다이얼로그 표시 전에 먼저 체크!)
      // 🔥 my_extensions 컬렉션에서 실제 등록된 단말번호 개수 확인
      final dbService = DatabaseService();
      final myExtensionsSnapshot = await dbService.getMyExtensions(userId).first;
      final currentExtensionCount = myExtensionsSnapshot.length;
      final maxExtensions = userModel.maxExtensions;
      
      if (kDebugMode) {
        debugPrint('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━');
        debugPrint('🔍 ProfileDrawer - maxExtensions 제한 체크');
        debugPrint('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━');
        debugPrint('📊 현재 등록된 단말번호 개수 (my_extensions): $currentExtensionCount');
        debugPrint('📊 등록된 단말번호 목록: ${myExtensionsSnapshot.map((e) => e.extension).toList()}');
        debugPrint('📊 최대 등록 가능 개수: $maxExtensions');
        debugPrint('📊 비교 결과: $currentExtensionCount >= $maxExtensions = ${currentExtensionCount >= maxExtensions}');
        debugPrint('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━');
      }
      
      if (currentExtensionCount >= maxExtensions) {
        if (kDebugMode) {
          debugPrint('❌ ProfileDrawer - 단말번호 등록 한도 초과: 현재 $currentExtensionCount개, 최대 $maxExtensions개');
        }
        
        setState(() {
          _isSearching = false;
        });
        
        if (!mounted) return;
        
        await showDialog(
          context: context,
          builder: (context) => AlertDialog(
            title: const Row(
              children: [
                Icon(Icons.warning_amber_rounded, color: Colors.orange, size: 28),
                SizedBox(width: 8),
                Text('등록 한도 초과', style: TextStyle(fontSize: 18)),
              ],
            ),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '단말번호는 최대 $maxExtensions개까지 등록할 수 있습니다.',
                  style: const TextStyle(fontSize: 14),
                ),
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.orange[50],
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.orange[200]!),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          const Icon(Icons.info_outline, size: 16, color: Colors.orange),
                          const SizedBox(width: 6),
                          Text(
                            '현재 등록된 단말번호: $currentExtensionCount개',
                            style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      const Text(
                        '더 많은 단말번호를 등록하려면 기존 단말번호를 삭제하거나 관리자에게 문의하세요.',
                        style: TextStyle(fontSize: 12, color: Colors.black87),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('확인', style: TextStyle(fontSize: 14)),
              ),
            ],
          ),
        );
        return; // 제한 초과 시 여기서 종료
      }
      
      // 단말번호 선택 다이얼로그 표시
      if (!mounted) return;
      
      await _showExtensionSelectionDialog(context, myExtensions, userId);
      
    } catch (e) {
      if (kDebugMode) {
        debugPrint('❌ 단말번호 조회 실패: $e');
      }
      setState(() {
        _searchError = 'API 조회 실패: $e';
        _isSearching = false;
      });
      
      // API 에러 다이얼로그 표시 (자동으로 닫지 않음)
      if (!mounted) return;
      await showDialog(
        context: context,
        builder: (context) => AlertDialog(
          icon: const Icon(Icons.error, color: Colors.red, size: 48),
          title: const Text('API 조회 실패'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  '단말번호 조회 중 오류가 발생했습니다:',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.red.shade50,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.red.shade200),
                  ),
                  child: Text(
                    e.toString(),
                    style: const TextStyle(
                      fontSize: 12,
                      fontFamily: 'monospace',
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                const Text(
                  '확인 사항:',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                ),
                const SizedBox(height: 8),
                const Text('• API 서버 주소가 올바른지 확인', style: TextStyle(fontSize: 12)),
                const Text('• SSL 설정이 올바른지 확인', style: TextStyle(fontSize: 12)),
                const Text('• Company ID와 App-Key 확인', style: TextStyle(fontSize: 12)),
                const Text('• 네트워크 연결 상태 확인', style: TextStyle(fontSize: 12)),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('닫기'),
            ),
            ElevatedButton(
              onPressed: () {
                Navigator.pop(context);
                // API 설정 다이얼로그 열기
                showDialog(
                  context: context,
                  builder: (context) => const ApiSettingsDialog(),
                );
              },
              child: const Text('설정 수정'),
            ),
          ],
        ),
      );
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
      final authService = context.read<AuthService>();
      final dbService = DatabaseService();
      
      final extension = apiData['extension']?.toString() ?? '';
      final name = apiData['name']?.toString() ?? '';
      final userEmail = authService.currentUser?.email ?? '';
      final userName = authService.currentUserModel?.phoneNumberName ?? '';
      
      // 1. registered_extensions 컬렉션에 등록 (중복 방지 및 다른 사용자 표시용)
      await dbService.registerExtension(
        extension: extension,
        userId: userId,
        userEmail: userEmail,
        userName: userName,
      );
      
      // 2. my_extensions 컬렉션에 추가 (UI 표시용)
      final myExtension = MyExtensionModel.fromApi(
        userId: userId,
        apiData: apiData,
      );

      await dbService.addMyExtension(myExtension);

      if (kDebugMode) {
        debugPrint('✅ ProfileDrawer - 단말번호 등록 완료: $extension');
        debugPrint('   - registered_extensions 등록');
        debugPrint('   - my_extensions 컬렉션 추가');
      }

      // ✅ CRITICAL FIX: context.mounted 체크로 위젯이 여전히 활성 상태인지 확인
      if (mounted && context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('단말번호가 등록되었습니다'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (kDebugMode) {
        debugPrint('❌ ProfileDrawer - 단말번호 등록 실패: $e');
      }
      // ✅ CRITICAL FIX: context.mounted 체크로 위젯이 여전히 활성 상태인지 확인
      if (mounted && context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('등록 실패: $e')),
        );
      }
    }
  }

  Future<void> _deleteExtension(BuildContext context, MyExtensionModel extension) async {
    // 🔥 CRITICAL: context 사용 전에 필요한 데이터 미리 추출 (위젯 dispose 방지)
    final authService = context.read<AuthService>();
    final userModel = authService.currentUserModel;
    
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
        final dbService = DatabaseService();
        
        if (kDebugMode) {
          debugPrint('');
          debugPrint('🗑️  ========== ProfileDrawer - 개별 삭제 시작 ==========');
          debugPrint('   📱 단말번호: ${extension.extension}');
          debugPrint('   🔑 Extension ID: ${extension.extensionId}');
          debugPrint('   🏢 AMI Server ID: ${userModel?.amiServerId}');
          debugPrint('   🏢 Tenant ID: ${userModel?.tenantId}');
          debugPrint('======================================================');
          debugPrint('');
        }
        
        // 🔥 1. 착신전환 비활성화 시도 (DCMIWS 웹소켓으로 전송)
        try {
          if (userModel != null &&
              userModel.amiServerId != null && 
              userModel.tenantId != null && 
              extension.extension.isNotEmpty) {
            
            if (kDebugMode) {
              debugPrint('🔄 ProfileDrawer - 착신전환 비활성화 요청 전송 중...');
            }
            
            final dcmiws = DCMIWSService();
            final result = await dcmiws.setCallForwardEnabled(
              amiServerId: userModel.amiServerId!,
              tenantId: userModel.tenantId!,
              extensionId: extension.extension,  // ← 단말번호 사용
              enabled: false,
              diversionType: 'CFI',
            );
            
            if (kDebugMode) {
              debugPrint('✅ ProfileDrawer - 착신전환 비활성화 요청 전송 완료: ${extension.extension}');
              debugPrint('   📊 결과: $result');
            }
          } else {
            if (kDebugMode) {
              debugPrint('⚠️  ProfileDrawer - 착신전환 비활성화 건너뜀 (조건 불충족)');
              debugPrint('   - userModel null: ${userModel == null}');
              debugPrint('   - amiServerId null: ${userModel?.amiServerId == null}');
              debugPrint('   - tenantId null: ${userModel?.tenantId == null}');
              debugPrint('   - extension empty: ${extension.extension.isEmpty}');
            }
          }
        } catch (e, stackTrace) {
          if (kDebugMode) {
            debugPrint('❌ ProfileDrawer - 착신전환 비활성화 실패: $e');
            debugPrint('   Stack trace: $stackTrace');
          }
          // 착신전환 비활성화 실패해도 삭제는 계속 진행
        }
        
        // 2. my_extensions 컬렉션에서 삭제
        await dbService.deleteMyExtension(extension.id);
        
        // 3. registered_extensions 컬렉션에서 등록 해제
        await dbService.unregisterExtension(extension.extension);
        
        if (kDebugMode) {
          debugPrint('✅ ProfileDrawer - 단말번호 삭제 완료: ${extension.extension}');
          debugPrint('   - my_extensions 컬렉션 삭제');
          debugPrint('   - registered_extensions 등록 해제');
        }
        
        // ✅ CRITICAL FIX: context.mounted 체크로 위젯이 여전히 활성 상태인지 확인
        if (mounted && context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('단말번호가 삭제되었습니다')),
          );
        }
      } catch (e) {
        if (kDebugMode) {
          debugPrint('❌ ProfileDrawer - 단말번호 삭제 실패: $e');
        }
        // ✅ CRITICAL FIX: context.mounted 체크로 위젯이 여전히 활성 상태인지 확인
        if (mounted && context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('삭제 실패: $e')),
          );
        }
      }
    }
  }

  Future<void> _deleteAllExtensions(BuildContext context, String userId) async {
    // 🔥 CRITICAL: context 사용 전에 필요한 데이터 미리 추출 (위젯 dispose 방지)
    final authService = context.read<AuthService>();
    final userModel = authService.currentUserModel;
    
    // 현재 등록된 단말번호 목록 가져오기
    final snapshot = await DatabaseService().getMyExtensions(userId).first;
    final extensionNumbers = snapshot.map((e) => e.extension).toList();
    
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('전체 삭제'),
        content: Text('모든 단말번호(${extensionNumbers.length}개)를 삭제하시겠습니까?'),
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
        final dbService = DatabaseService();
        
        if (kDebugMode) {
          debugPrint('');
          debugPrint('🗑️  ========== ProfileDrawer - 전체 삭제 시작 ==========');
          debugPrint('   📱 단말번호 개수: ${snapshot.length}');
          debugPrint('   🏢 AMI Server ID: ${userModel?.amiServerId}');
          debugPrint('   🏢 Tenant ID: ${userModel?.tenantId}');
          debugPrint('======================================================');
          debugPrint('');
        }
        
        // 🔥 1. 모든 단말번호의 착신전환 비활성화 시도 (DCMIWS 웹소켓으로 전송)
        if (userModel != null &&
            userModel.amiServerId != null && 
            userModel.tenantId != null) {
          final dcmiws = DCMIWSService();
          
          for (final ext in snapshot) {
            if (kDebugMode) {
              debugPrint('🔄 단말번호 ${ext.extension} 처리 중...');
              debugPrint('   - Extension: ${ext.extension}');
              debugPrint('   - Extension empty: ${ext.extension.isEmpty}');
            }
            
            if (ext.extension.isNotEmpty) {
              try {
                if (kDebugMode) {
                  debugPrint('   → 착신전환 비활성화 요청 전송 중...');
                }
                
                final result = await dcmiws.setCallForwardEnabled(
                  amiServerId: userModel.amiServerId!,
                  tenantId: userModel.tenantId!,
                  extensionId: ext.extension,  // ← 단말번호 사용
                  enabled: false,
                  diversionType: 'CFI',
                );
                
                if (kDebugMode) {
                  debugPrint('   ✅ 착신전환 비활성화 요청 전송 완료: ${ext.extension}');
                  debugPrint('      📊 결과: $result');
                }
              } catch (e, stackTrace) {
                if (kDebugMode) {
                  debugPrint('   ❌ 착신전환 비활성화 실패 (${ext.extension}): $e');
                  debugPrint('      Stack trace: $stackTrace');
                }
                // 착신전환 비활성화 실패해도 삭제는 계속 진행
              }
            } else {
              if (kDebugMode) {
                debugPrint('   ⚠️  Extension(단말번호)이 비어있어 건너뜀');
              }
            }
          }
        } else {
          if (kDebugMode) {
            debugPrint('⚠️  착신전환 비활성화 건너뜀 (조건 불충족)');
            debugPrint('   - userModel null: ${userModel == null}');
            debugPrint('   - amiServerId null: ${userModel?.amiServerId == null}');
            debugPrint('   - tenantId null: ${userModel?.tenantId == null}');
          }
        }
        
        // 2. my_extensions 컬렉션에서 전체 삭제
        await dbService.deleteAllMyExtensions(userId);
        
        // 3. registered_extensions에서 각 단말번호 등록 해제
        for (final extension in extensionNumbers) {
          await dbService.unregisterExtension(extension);
        }
        
        if (kDebugMode) {
          debugPrint('✅ ProfileDrawer - 모든 단말번호 삭제 완료 (${extensionNumbers.length}개)');
          debugPrint('   - my_extensions 컬렉션 전체 삭제');
          debugPrint('   - registered_extensions 등록 해제: $extensionNumbers');
        }
        
        // ✅ CRITICAL FIX: context.mounted 체크로 위젯이 여전히 활성 상태인지 확인
        if (mounted && context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('모든 단말번호가 삭제되었습니다')),
          );
        }
      } catch (e) {
        if (kDebugMode) {
          debugPrint('❌ ProfileDrawer - 전체 삭제 실패: $e');
        }
        // ✅ CRITICAL FIX: context.mounted 체크로 위젯이 여전히 활성 상태인지 확인
        if (mounted && context.mounted) {
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
            Text('등록 시간: ${extension.createdAt.toString().substring(0, 19)}'),
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
  
  // ============================================
  // 설정 섹션 메서드들
  // ============================================
  
  void _showTextDialog(BuildContext context, String title, String content) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(title),
        content: SingleChildScrollView(
          child: Text(content),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('닫기'),
          ),
        ],
      ),
    );
  }

  void _showLicensePage(BuildContext context) async {
    final packageInfo = await PackageInfo.fromPlatform();
    
    if (!context.mounted) return;
    
    // 라이선스 정보 직접 가져오기
    final licenses = await LicenseRegistry.licenses.toList();
    
    if (!context.mounted) return;
    
    // 패키지별로 그룹화
    final Map<String, List<LicenseEntry>> groupedLicenses = {};
    for (final license in licenses) {
      for (final package in license.packages) {
        if (!groupedLicenses.containsKey(package)) {
          groupedLicenses[package] = [];
        }
        groupedLicenses[package]!.add(license);
      }
    }
    
    // 패키지 이름 정렬
    final sortedPackages = groupedLicenses.keys.toList()..sort();
    
    Navigator.push(
      context,
      MaterialPageRoute<void>(
        builder: (context) => Scaffold(
          appBar: AppBar(
            title: const Text('오픈소스 라이선스'),
            backgroundColor: const Color(0xFF2196F3),
            foregroundColor: Colors.white,
          ),
          body: Column(
            children: [
              // 앱 정보 헤더
              Container(
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  color: Colors.blue[50],
                  border: Border(
                    bottom: BorderSide(color: Colors.blue[100]!),
                  ),
                ),
                child: Column(
                  children: [
                    Image.asset(
                      'assets/images/app_logo.png',
                      width: 60,
                      height: 60,
                    ),
                    const SizedBox(height: 12),
                    const Text(
                      'MAKECALL',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF2196F3),
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Version ${packageInfo.version}',
                      style: const TextStyle(
                        fontSize: 12,
                        color: Colors.grey,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      '사용된 오픈소스 패키지: ${sortedPackages.length}개',
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: Color(0xFF2196F3),
                      ),
                    ),
                  ],
                ),
              ),
              // 라이선스 목록
              Expanded(
                child: ListView.separated(
                  padding: const EdgeInsets.all(8),
                  itemCount: sortedPackages.length,
                  separatorBuilder: (context, index) => const Divider(height: 1),
                  itemBuilder: (context, index) {
                    final package = sortedPackages[index];
                    final packageLicenses = groupedLicenses[package]!;
                    
                    return ListTile(
                      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                      leading: Container(
                        width: 40,
                        height: 40,
                        decoration: BoxDecoration(
                          color: Colors.blue[100],
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: const Icon(
                          Icons.code,
                          color: Color(0xFF2196F3),
                          size: 24,
                        ),
                      ),
                      title: Text(
                        package,
                        style: const TextStyle(
                          fontWeight: FontWeight.w600,
                          fontSize: 15,
                        ),
                      ),
                      subtitle: Text(
                        '${packageLicenses.length}개의 라이선스',
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.grey[600],
                        ),
                      ),
                      trailing: const Icon(Icons.chevron_right, size: 20),
                      onTap: () {
                        _showLicenseDetail(context, package, packageLicenses);
                      },
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
  
  void _showLicenseDetail(BuildContext context, String package, List<LicenseEntry> licenses) {
    Navigator.push(
      context,
      MaterialPageRoute<void>(
        builder: (context) => Scaffold(
          appBar: AppBar(
            title: Text(package),
            backgroundColor: const Color(0xFF2196F3),
            foregroundColor: Colors.white,
          ),
          body: ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: licenses.length,
            itemBuilder: (context, index) {
              final license = licenses[index];
              final paragraphs = license.paragraphs.toList();
              
              return Card(
                margin: const EdgeInsets.only(bottom: 16),
                elevation: 2,
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (licenses.length > 1)
                        Padding(
                          padding: const EdgeInsets.only(bottom: 12),
                          child: Text(
                            '라이선스 ${index + 1}/${licenses.length}',
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              color: Color(0xFF2196F3),
                              fontSize: 14,
                            ),
                          ),
                        ),
                      ...paragraphs.map((paragraph) {
                        return Padding(
                          padding: const EdgeInsets.only(bottom: 8),
                          child: Text(
                            paragraph.text,
                            style: TextStyle(
                              fontSize: 13,
                              height: 1.5,
                              color: Colors.grey[800],
                            ),
                          ),
                        );
                      }),
                    ],
                  ),
                ),
              );
            },
          ),
        ),
      ),
    );
  }
  
  void _showWebViewPage(BuildContext context, String title, String assetPath) async {
    // HTML 파일 내용 로드
    final htmlContent = await rootBundle.loadString(assetPath);
    
    if (!context.mounted) return;
    
    Navigator.push(
      context,
      MaterialPageRoute<void>(
        builder: (context) => Scaffold(
          appBar: AppBar(
            title: Text(title),
            backgroundColor: title.contains('서비스') 
                ? const Color(0xFF2196F3) 
                : const Color(0xFF4CAF50),
            foregroundColor: Colors.white,
          ),
          body: WebViewWidget(
            controller: WebViewController()
              ..setJavaScriptMode(JavaScriptMode.unrestricted)
              ..loadHtmlString(htmlContent),
          ),
        ),
      ),
    );
  }

  // 🚫 멀티 계정 기능 비활성화
  /* Future<void> _handleAddAccount(BuildContext context) async {
    final authService = context.read<AuthService>();
    final currentEmail = authService.currentUserModel?.email ?? '없음';
    
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('계정 추가'),
        content: Text(
          '현재 계정에서 로그아웃하고 새로운 계정으로 로그인하시겠습니까?\n\n'
          '현재 로그인된 계정: $currentEmail',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('취소'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.green,
            ),
            child: const Text('계정 추가'),
          ),
        ],
      ),
    );

    if (confirmed == true && mounted) {
      try {
        await context.read<AuthService>().signOut();
        if (mounted) {
          Navigator.pop(context); // Drawer 닫기
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('로그아웃되었습니다. 새로운 계정으로 로그인해주세요.'),
              backgroundColor: Colors.green,
            ),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('오류 발생: $e'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    }
  } */

  // 🚫 멀티 계정 기능 비활성화
  /* Future<void> _handleSwitchAccount(BuildContext context, SavedAccountModel account) async {
    // 자동 로그인 옵션 확인
    final autoLoginEnabled = await AccountManagerService().getKeepLoginEnabled();
    
    if (kDebugMode) {
      debugPrint('🔄 Account Switch Request:');
      debugPrint('   - Target: ${account.email}');
      debugPrint('   - Auto Login Enabled: $autoLoginEnabled');
    }
    
    bool? confirmed;
    
    if (autoLoginEnabled) {
      // 자동 로그인이 활성화된 경우 - 자동으로 계정 전환
      confirmed = true;
      
      if (kDebugMode) {
        debugPrint('✅ Auto-switching account (Auto Login is ON)');
      }
      
      if (mounted) {
        // 안내 메시지만 표시 (확인 불필요)
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              '${account.displayName} 계정으로 자동 전환합니다...',
            ),
            backgroundColor: Colors.blue,
            duration: const Duration(seconds: 2),
          ),
        );
      }
    } else {
      if (kDebugMode) {
        debugPrint('❓ Showing confirmation dialog (Auto Login is OFF)');
      }
      // 자동 로그인이 비활성화된 경우 - 확인 다이얼로그 표시
      confirmed = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('계정 전환'),
          content: Text(
            '${account.displayName} 계정으로 전환하려면 현재 계정에서 로그아웃 후 다시 로그인해야 합니다.\n\n'
            '로그아웃 하시겠습니까?',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('취소'),
            ),
            ElevatedButton(
              onPressed: () => Navigator.pop(context, true),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF2196F3),
              ),
              child: const Text('로그아웃'),
            ),
          ],
        ),
      );
    }

    if (confirmed == true && mounted) {
      // 전환 대상 이메일 설정 (LoginScreen에서 자동으로 채워짐 + 비밀번호 자동 입력)
      await AccountManagerService().setSwitchTargetEmail(account.email);
      
      if (kDebugMode) {
        debugPrint('💾 Switch target email saved: ${account.email}');
      }
      
      await context.read<AuthService>().signOut();
      if (mounted) {
        Navigator.pop(context);
        
        // 메시지 변경: 자동 로그인 여부에 따라 다른 메시지 표시
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              autoLoginEnabled
                  ? '로그아웃되었습니다. ${account.email}로 자동 로그인 중...'
                  : '로그아웃되었습니다. ${account.email}로 다시 로그인해주세요.',
            ),
            backgroundColor: Colors.blue,
          ),
        );
      }
    }
  } */



  // 현재 로그인된 사용자의 조직명(회사명) 편집
  Future<void> _showEditCompanyNameDialog(BuildContext context, AuthService authService) async {
    final currentCompanyName = authService.currentUserModel?.companyName ?? '';
    final controller = TextEditingController(text: currentCompanyName);
    
    final result = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('조직명 설정'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '계정: ${authService.currentUserModel?.email ?? ""}',
              style: const TextStyle(fontSize: 12, color: Colors.grey),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: controller,
              decoration: const InputDecoration(
                labelText: '조직명',
                hintText: '예: 본사, 지사, 개인 등',
                border: OutlineInputBorder(),
                helperText: '소속된 조직 이름입니다',
              ),
              maxLength: 50,
              autofocus: true,
            ),
          ],
        ),
        actions: [
          if (currentCompanyName.isNotEmpty)
            TextButton(
              onPressed: () => Navigator.pop(context, ''), // 빈 문자열로 삭제
              style: TextButton.styleFrom(foregroundColor: Colors.red),
              child: const Text('삭제'),
            ),
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('취소'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, controller.text.trim()),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF2196F3),
            ),
            child: const Text('확인'),
          ),
        ],
      ),
    );

    if (result != null && mounted) {
      try {
        // Firestore 업데이트
        await authService.updateCompanyName(result.isEmpty ? null : result);
        
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                result.isEmpty 
                    ? '조직명이 삭제되었습니다' 
                    : '조직명이 업데이트되었습니다',
              ),
              backgroundColor: Colors.green,
            ),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('오류 발생: $e'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    }
  }

  // 등록된 계정 삭제 (로그인하지 않은 계정만)
  Future<void> _handleDeleteAccount(BuildContext context, SavedAccountModel account) async {
    // 현재 로그인된 계정인지 다시 확인 (안전장치)
    if (account.isCurrentAccount) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('현재 로그인된 계정은 삭제할 수 없습니다. 로그아웃 후 삭제해주세요.'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }
    
    // 삭제 확인 다이얼로그
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.warning_amber_rounded, color: Colors.orange, size: 28),
            SizedBox(width: 12),
            Text('계정 삭제'),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              '다음 계정을 목록에서 삭제하시겠습니까?',
              style: TextStyle(fontSize: 15, fontWeight: FontWeight.w500),
            ),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.grey[100],
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.grey[300]!),
              ),
              child: Row(
                children: [
                  CircleAvatar(
                    radius: 20,
                    backgroundColor: Colors.transparent,
                    backgroundImage: account.profileImageUrl != null
                        ? NetworkImage(account.profileImageUrl!)
                        : const AssetImage('assets/icons/app_icon.png') as ImageProvider,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          account.displayName,
                          style: const TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        Text(
                          account.email,
                          style: const TextStyle(
                            fontSize: 12,
                            color: Colors.grey,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.red[50],
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.red[200]!),
              ),
              child: const Row(
                children: [
                  Icon(Icons.info_outline, size: 20, color: Colors.red),
                  SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      '등록된 로그인 정보가 삭제됩니다.\n계정 자체는 삭제되지 않습니다.',
                      style: TextStyle(fontSize: 12, color: Colors.red),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('취소'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
            ),
            child: const Text('삭제'),
          ),
        ],
      ),
    );
    
    if (confirmed != true) return;
    
    // 계정 삭제 처리
    try {
      await AccountManagerService().removeAccount(account.uid);
      
      if (mounted) {
        // UI 새로고침을 위해 setState 호출
        setState(() {});
        
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('${account.displayName} 계정이 목록에서 삭제되었습니다'),
            backgroundColor: Colors.green,
            duration: const Duration(seconds: 2),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('계정 삭제 실패: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  // 등록된 계정 목록에서 로그아웃 (다이얼로그 없이 바로 로그아웃)
  Future<void> _handleLogoutFromList(BuildContext context) async {
    try {
      await context.read<AuthService>().signOut();
      if (mounted) {
        Navigator.pop(context); // Drawer 닫기
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('로그아웃되었습니다'),
            backgroundColor: Colors.orange,
            duration: Duration(seconds: 2),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('로그아웃 실패: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _handleLogout(BuildContext context) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('로그아웃'),
        content: const Text('로그아웃 하시겠습니까?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('취소'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF2196F3),
            ),
            child: const Text('로그아웃'),
          ),
        ],
      ),
    );

    if (confirmed == true && mounted) {
      await context.read<AuthService>().signOut();
      if (mounted) {
        Navigator.pop(context); // Drawer 닫기
      }
    }
  }

  /// 📋 프로필 상세 정보 다이얼로그
  void _showProfileDetailDialog(BuildContext context, AuthService authService) {
    final userModel = authService.currentUserModel;
    
    showDialog(
      context: context,
      builder: (context) => Dialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
        child: SingleChildScrollView(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // 헤더
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      '프로필 상세 정보',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close),
                      onPressed: () => Navigator.pop(context),
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(),
                    ),
                  ],
                ),
                const SizedBox(height: 24),
                
                // 프로필 이미지 (편집 가능)
                Stack(
                  alignment: Alignment.center,
                  children: [
                    GestureDetector(
                      onTap: () {
                        Navigator.pop(context);
                        _showProfileImageOptions(context, authService);
                      },
                      child: CircleAvatar(
                        radius: 50,
                        backgroundColor: Colors.transparent,
                        backgroundImage: userModel?.profileImageUrl != null
                            ? NetworkImage(userModel!.profileImageUrl!)
                            : const AssetImage('assets/icons/app_icon.png') as ImageProvider,
                      ),
                    ),
                    Positioned(
                      bottom: 0,
                      right: 0,
                      child: GestureDetector(
                        onTap: () {
                          Navigator.pop(context);
                          _showProfileImageOptions(context, authService);
                        },
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
                const SizedBox(height: 24),
                
                // 조직명
                _buildDetailRow(
                  icon: Icons.business,
                  label: '조직명',
                  value: userModel?.companyName?.isNotEmpty == true 
                      ? userModel!.companyName!
                      : '미설정',
                  onEdit: () {
                    Navigator.pop(context);
                    _showEditCompanyNameDialog(context, authService);
                  },
                ),
                const Divider(height: 24),
                
                // 이메일
                _buildDetailRow(
                  icon: Icons.email,
                  label: '이메일',
                  value: userModel?.email ?? '이메일 없음',
                ),
                const Divider(height: 24),
                
                // 단말번호 등록 가능 개수
                _buildDetailRow(
                  icon: Icons.phone_android,
                  label: '단말번호 등록 가능',
                  value: '최대 ${userModel?.maxExtensions ?? 1}개',
                  valueColor: const Color(0xFF2196F3),
                ),
                
                // 마지막 업데이트 시간
                if (userModel?.lastMaxExtensionsUpdate != null) ...[
                  const SizedBox(height: 8),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.update, size: 14, color: Colors.grey[600]),
                      const SizedBox(width: 4),
                      Text(
                        _formatUpdateTimestamp(userModel!.lastMaxExtensionsUpdate!),
                        style: TextStyle(
                          fontSize: 11,
                          color: Colors.grey[600],
                        ),
                      ),
                    ],
                  ),
                ],
                const SizedBox(height: 24),
                
                // 새로고침 버튼
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: _isRefreshing ? null : () async {
                      await _handleManualRefresh();
                      if (context.mounted) {
                        Navigator.pop(context);
                      }
                    },
                    icon: _isRefreshing
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                            ),
                          )
                        : const Icon(Icons.refresh, size: 18),
                    label: Text(_isRefreshing ? '업데이트 중...' : '정보 새로고침'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF2196F3),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
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

  /// 상세 정보 행 빌더
  Widget _buildDetailRow({
    required IconData icon,
    required String label,
    required String value,
    VoidCallback? onEdit,
    Color? valueColor,
  }) {
    return Row(
      children: [
        Icon(icon, size: 20, color: Colors.grey[600]),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.grey[600],
                  fontWeight: FontWeight.w500,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                value,
                style: TextStyle(
                  fontSize: 15,
                  color: valueColor ?? Colors.black87,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
        if (onEdit != null)
          IconButton(
            icon: const Icon(Icons.edit, size: 18),
            onPressed: onEdit,
            color: Colors.grey[600],
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(),
          ),
      ],
    );
  }

  /// 📋 단말번호 관리 상세 다이얼로그
  void _showExtensionsManagementDialog(BuildContext context, List<MyExtensionModel> extensions) {
    final authService = context.read<AuthService>();
    final userModel = authService.currentUserModel;
    final userId = authService.currentUser?.uid ?? '';
    
    showDialog(
      context: context,
      builder: (dialogContext) => Dialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
        child: Container(
          constraints: const BoxConstraints(maxHeight: 600),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // 헤더
              Padding(
                padding: const EdgeInsets.all(20),
                child: Row(
                  children: [
                    const Icon(Icons.phone_android, color: Color(0xFF2196F3)),
                    const SizedBox(width: 12),
                    const Expanded(
                      child: Text(
                        '내 단말번호 관리',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close),
                      onPressed: () => Navigator.pop(dialogContext),
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(),
                    ),
                  ],
                ),
              ),
              const Divider(height: 1),
              
              // 단말번호 조회 버튼
              Padding(
                padding: const EdgeInsets.all(16),
                child: SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: _isSearching || userModel?.apiBaseUrl == null
                        ? null
                        : () {
                            Navigator.pop(dialogContext);
                            _searchMyExtensions(context);
                          },
                    icon: _isSearching
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          )
                        : const Icon(Icons.search, size: 20),
                    label: Text(_isSearching ? '조회 중...' : '단말번호 조회 및 등록'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF2196F3),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                  ),
                ),
              ),
              
              // 에러 메시지
              if (_searchError != null)
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Container(
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
                            style: const TextStyle(fontSize: 12, color: Colors.red),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              
              const Divider(height: 24),
              
              // 등록된 단말번호 목록 헤더
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      '등록된 단말번호',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    if (extensions.isNotEmpty)
                      TextButton.icon(
                        onPressed: () {
                          Navigator.pop(dialogContext);
                          _deleteAllExtensions(context, userId);
                        },
                        icon: const Icon(Icons.delete_sweep, size: 16),
                        label: const Text('전체 삭제', style: TextStyle(fontSize: 12)),
                        style: TextButton.styleFrom(
                          foregroundColor: Colors.red,
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        ),
                      ),
                  ],
                ),
              ),
              
              // 단말번호 목록
              Flexible(
                child: extensions.isEmpty
                    ? Padding(
                        padding: const EdgeInsets.all(32),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.inbox_outlined, size: 64, color: Colors.grey[400]),
                            const SizedBox(height: 16),
                            Text(
                              '등록된 단말번호가 없습니다',
                              style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w600,
                                color: Colors.grey[600],
                              ),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              '위의 조회 버튼을 눌러주세요',
                              style: TextStyle(fontSize: 12, color: Colors.grey[500]),
                            ),
                          ],
                        ),
                      )
                    : ListView.separated(
                        shrinkWrap: true,
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                        itemCount: extensions.length,
                        separatorBuilder: (context, index) => const Divider(height: 1),
                        itemBuilder: (context, index) {
                          final ext = extensions[index];
                          return Container(
                            margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(color: Colors.grey[300]!, width: 1),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.grey.withAlpha(26),
                                  blurRadius: 4,
                                  offset: const Offset(0, 2),
                                ),
                              ],
                            ),
                            child: Padding(
                              padding: const EdgeInsets.all(12),
                              child: Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  // 작은 숫자 아이콘
                                  Container(
                                    width: 24,
                                    height: 24,
                                    decoration: BoxDecoration(
                                      color: const Color(0xFF2196F3).withAlpha(26),
                                      shape: BoxShape.circle,
                                    ),
                                    child: Center(
                                      child: Text(
                                        '${index + 1}',
                                        style: const TextStyle(
                                          color: Color(0xFF2196F3),
                                          fontWeight: FontWeight.bold,
                                          fontSize: 11,
                                        ),
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  
                                  // 정보 영역
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        // 이름 (첫 번째 줄)
                                        Text(
                                          ext.name,
                                          style: const TextStyle(
                                            fontSize: 15,
                                            fontWeight: FontWeight.bold,
                                            color: Colors.black87,
                                          ),
                                        ),
                                        const SizedBox(height: 4),
                                        // 단말번호 (두 번째 줄)
                                        Text(
                                          ext.extension,
                                          style: const TextStyle(
                                            fontSize: 14,
                                            fontWeight: FontWeight.w600,
                                            color: Color(0xFF2196F3),
                                          ),
                                        ),
                                        const SizedBox(height: 8),
                                        
                                        // 수신번호 (길게 누르면 복사)
                                        if (ext.accountCode != null && ext.accountCode!.isNotEmpty) ...[
                                          _buildLongPressCopyRow(
                                            context: context,
                                            label: '수신번호',
                                            value: ext.accountCode!,
                                          ),
                                          const SizedBox(height: 6),
                                        ],
                                        
                                        // SIP UserId (길게 누르면 복사)
                                        if (ext.sipUserId != null && ext.sipUserId!.isNotEmpty) ...[
                                          _buildLongPressCopyRow(
                                            context: context,
                                            label: 'SIP UserId',
                                            value: ext.sipUserId!,
                                          ),
                                          const SizedBox(height: 6),
                                        ],
                                        
                                        // SIP Secret (길게 누르면 복사)
                                        if (ext.sipSecret != null && ext.sipSecret!.isNotEmpty) ...[
                                          _buildLongPressCopyRow(
                                            context: context,
                                            label: 'SIP Secret',
                                            value: ext.sipSecret!,
                                          ),
                                        ],
                                      ],
                                    ),
                                  ),
                                  
                                  // 삭제 버튼
                                  IconButton(
                                    icon: const Icon(Icons.delete_outline, size: 20),
                                    color: Colors.red,
                                    padding: EdgeInsets.zero,
                                    constraints: const BoxConstraints(),
                                    onPressed: () {
                                      Navigator.pop(dialogContext);
                                      _deleteExtension(context, ext);
                                    },
                                    tooltip: '삭제',
                                  ),
                                ],
                              ),
                            ),
                          );
                        },
                      ),
              ),
              
              const SizedBox(height: 16),
            ],
          ),
        ),
      ),
    );
  }

  /// 길게 누르면 복사되는 정보 행 빌더 (박스 없이 텍스트만 표시)
  Widget _buildLongPressCopyRow({
    required BuildContext context,
    required String label,
    required String value,
  }) {
    return GestureDetector(
      onLongPress: () {
        // 클립보드에 복사
        Clipboard.setData(ClipboardData(text: value));
        
        // 🎉 다이얼로그 위에 표시되는 복사 완료 알림
        showDialog(
          context: context,
          barrierDismissible: true,
          barrierColor: Colors.black.withValues(alpha: 0.3),
          builder: (dialogContext) {
            // 2초 후 자동 닫기
            Future.delayed(const Duration(seconds: 2), () {
              if (Navigator.canPop(dialogContext)) {
                Navigator.pop(dialogContext);
              }
            });
            
            return Dialog(
              backgroundColor: Colors.transparent,
              elevation: 0,
              child: Container(
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  color: const Color(0xFF4CAF50),
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.3),
                      blurRadius: 20,
                      offset: const Offset(0, 10),
                    ),
                  ],
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // 체크 아이콘 애니메이션
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.2),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.check_circle,
                        color: Colors.white,
                        size: 48,
                      ),
                    ),
                    const SizedBox(height: 20),
                    // 복사 완료 메시지
                    const Text(
                      '✅ 복사 완료!',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      '$label 값이 클립보드에\n복사되었습니다',
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        fontSize: 14,
                        color: Colors.white70,
                        height: 1.4,
                      ),
                    ),
                    const SizedBox(height: 20),
                    // 복사된 값 표시
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: Colors.white.withValues(alpha: 0.3),
                          width: 1.5,
                        ),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            '📋 복사된 내용',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: Colors.white.withValues(alpha: 0.8),
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            value,
                            style: const TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                              fontFamily: 'monospace',
                              letterSpacing: 0.5,
                            ),
                            maxLines: 3,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),
                    // 닫기 안내
                    Text(
                      '2초 후 자동으로 닫힙니다',
                      style: TextStyle(
                        fontSize: 11,
                        color: Colors.white.withValues(alpha: 0.6),
                        fontStyle: FontStyle.italic,
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 라벨 (복사 힌트 추가)
          Row(
            children: [
              Text(
                label,
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.w600,
                  color: Colors.grey[600],
                  letterSpacing: 0.3,
                ),
              ),
              const SizedBox(width: 6),
              Icon(
                Icons.touch_app,
                size: 14,
                color: Colors.grey[500],
              ),
              const SizedBox(width: 2),
              Text(
                '길게 눌러 복사',
                style: TextStyle(
                  fontSize: 9,
                  color: Colors.grey[500],
                  fontStyle: FontStyle.italic,
                ),
              ),
            ],
          ),
          const SizedBox(height: 2),
          // 값 (박스 없이 텍스트만 표시, 길게 눌러서 복사 가능)
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(vertical: 2),
            child: Text(
              value,
              style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w500,
                color: Colors.black87,
                fontFamily: 'monospace',
              ),
              // 긴 텍스트도 여러 줄로 표시 가능
              softWrap: true,
            ),
          ),
        ],
      ),
    );
  }
  
  /// 웹 푸시 권한 요청
  Future<void> _requestWebPushPermission(BuildContext context) async {
    if (!kIsWeb) return;
    
    try {
      // FCM 서비스 가져오기
      final fcmService = FCMService();
      final userId = AuthService().currentUser?.uid;
      
      if (userId == null) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('로그인이 필요합니다'),
              backgroundColor: Colors.red,
            ),
          );
        }
        return;
      }
      
      // 로딩 다이얼로그 표시
      if (mounted) {
        showDialog(
          context: context,
          barrierDismissible: false,
          builder: (context) => const Center(
            child: Card(
              child: Padding(
                padding: EdgeInsets.all(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    CircularProgressIndicator(),
                    SizedBox(height: 16),
                    Text('웹 푸시 알림 권한 요청 중...'),
                  ],
                ),
              ),
            ),
          ),
        );
      }
      
      // FCM 초기화 및 권한 요청
      await fcmService.initialize(userId);
      
      // 로딩 다이얼로그 닫기
      if (mounted) {
        Navigator.pop(context);
      }
      
      // 결과 확인
      final token = fcmService.fcmToken;
      if (token != null) {
        if (mounted) {
          showDialog(
            context: context,
            builder: (context) => AlertDialog(
              icon: const Icon(Icons.check_circle, color: Colors.green, size: 48),
              title: const Text('웹 푸시 알림 활성화 완료'),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('브라우저 알림이 활성화되었습니다.'),
                  const SizedBox(height: 16),
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.green[50],
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.green[200]!),
                    ),
                    child: const Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Icon(Icons.info_outline, size: 16, color: Colors.green),
                            SizedBox(width: 8),
                            Text(
                              '이제 다음 알림을 받을 수 있습니다:',
                              style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
                            ),
                          ],
                        ),
                        SizedBox(height: 8),
                        Text('• 수신 전화 알림', style: TextStyle(fontSize: 12)),
                        Text('• 부재중 전화 알림', style: TextStyle(fontSize: 12)),
                        Text('• 시스템 알림', style: TextStyle(fontSize: 12)),
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),
                  const Text(
                    '💡 브라우저를 닫아도 알림을 받을 수 있습니다.',
                    style: TextStyle(fontSize: 11, color: Colors.grey),
                  ),
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
      } else {
        if (mounted) {
          showDialog(
            context: context,
            builder: (context) => AlertDialog(
              icon: const Icon(Icons.error, color: Colors.orange, size: 48),
              title: const Text('알림 권한 필요'),
              content: const Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('웹 푸시 알림을 받으려면 브라우저 알림 권한이 필요합니다.'),
                  SizedBox(height: 16),
                  Text(
                    '브라우저 설정에서 알림 권한을 허용해주세요:',
                    style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
                  ),
                  SizedBox(height: 8),
                  Text('1. 브라우저 주소창 왼쪽의 자물쇠 아이콘 클릭', style: TextStyle(fontSize: 11)),
                  Text('2. "알림" 또는 "Notifications" 찾기', style: TextStyle(fontSize: 11)),
                  Text('3. "허용" 또는 "Allow"로 변경', style: TextStyle(fontSize: 11)),
                  Text('4. 페이지 새로고침', style: TextStyle(fontSize: 11)),
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
    } catch (e) {
      if (kDebugMode) {
        debugPrint('❌ 웹 푸시 권한 요청 오류: $e');
      }
      
      // 로딩 다이얼로그가 열려있으면 닫기
      if (mounted && Navigator.canPop(context)) {
        Navigator.pop(context);
      }
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('알림 권한 요청 중 오류 발생: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }
  
  /// 웹 푸시 정보 표시
  void _showWebPushInfo(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.info_outline, color: Colors.blue),
            SizedBox(width: 8),
            Text('웹 푸시 알림 안내'),
          ],
        ),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                '웹 푸시 알림이란?',
                style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 8),
              const Text(
                '웹 브라우저에서도 모바일 앱처럼 실시간 알림을 받을 수 있는 기능입니다.',
                style: TextStyle(fontSize: 12),
              ),
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.blue[50],
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.blue[200]!),
                ),
                child: const Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(Icons.check_circle, size: 16, color: Colors.blue),
                        SizedBox(width: 8),
                        Text(
                          '주요 기능',
                          style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
                        ),
                      ],
                    ),
                    SizedBox(height: 8),
                    Text('• 브라우저를 최소화해도 알림 수신', style: TextStyle(fontSize: 11)),
                    Text('• 다른 탭에서 작업 중에도 알림 표시', style: TextStyle(fontSize: 11)),
                    Text('• 수신 전화, 부재중 전화 즉시 알림', style: TextStyle(fontSize: 11)),
                    Text('• 데스크톱 알림으로 놓치지 않음', style: TextStyle(fontSize: 11)),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.orange[50],
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.orange[200]!),
                ),
                child: const Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(Icons.lightbulb_outline, size: 16, color: Colors.orange),
                        SizedBox(width: 8),
                        Text(
                          '사용 방법',
                          style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
                        ),
                      ],
                    ),
                    SizedBox(height: 8),
                    Text('1. "웹 푸시 알림 활성화" 버튼 클릭', style: TextStyle(fontSize: 11)),
                    Text('2. 브라우저 알림 권한 허용', style: TextStyle(fontSize: 11)),
                    Text('3. 활성화 완료 메시지 확인', style: TextStyle(fontSize: 11)),
                    Text('4. 이제 실시간 알림을 받을 수 있습니다!', style: TextStyle(fontSize: 11)),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.grey[100],
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.grey[300]!),
                ),
                child: const Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(Icons.computer, size: 16, color: Colors.grey),
                        SizedBox(width: 8),
                        Text(
                          '지원 환경',
                          style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
                        ),
                      ],
                    ),
                    SizedBox(height: 8),
                    Text('• Chrome, Edge, Firefox (최신 버전)', style: TextStyle(fontSize: 11)),
                    Text('• Windows, macOS, Linux', style: TextStyle(fontSize: 11)),
                    Text('• HTTPS 연결 필요 (보안 연결)', style: TextStyle(fontSize: 11)),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              const Text(
                '💡 모바일 브라우저에서도 사용 가능합니다!',
                style: TextStyle(fontSize: 11, color: Colors.grey),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('확인'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              _requestWebPushPermission(context);
            },
            child: const Text('지금 활성화'),
          ),
        ],
      ),
    );
  }
}
