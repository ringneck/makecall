import 'package:flutter/material.dart';
import '../utils/dialog_utils.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:image_picker/image_picker.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:webview_flutter/webview_flutter.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'dart:io';
import '../services/auth_service.dart';
import '../services/api_service.dart';
import '../services/database_service.dart';
import '../services/account_manager_service.dart';
import '../services/fcm_service.dart';
import '../services/dcmiws_service.dart';
import '../services/dcmiws_connection_manager.dart';
import '../models/my_extension_model.dart';
import '../models/saved_account_model.dart';
import '../models/user_model.dart';  // ✅ DCMIWS 설정 업데이트를 위해 필요
import '../screens/profile/api_settings_dialog.dart';
import '../main.dart' show navigatorKey;  // ✅ 전역 Navigator key (로그아웃 에러 표시용)
import 'theme_settings_dialog.dart';  // 🎨 화면 테마 설정

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
  
  // DCMIWS 착신전화 수신 설정
  bool _dcmiwsEnabled = false;
  
  // 🎯 Premium 상태 캐싱 (성능 최적화)
  bool? _isPremiumCached;

  @override
  void initState() {
    super.initState();
    // 등록된 전화번호 불러오기 및 단말번호 업데이트
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final authService = context.read<AuthService>();
      
      // 🔒 로그아웃 상태 체크 - userId가 없으면 모든 초기화 건너뛰기
      if (authService.currentUser?.uid == null) {
        if (kDebugMode) {
          debugPrint('⏭️ [ProfileDrawer] 로그아웃 상태 - 초기화 건너뜀');
        }
        return;
      }
      
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
      // DCMIWS 설정 불러오기
      _loadDcmiwsSettings();
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
      debugPrint('📥 [iOS-알림설정] 로드 시작');
      
      final authService = context.read<AuthService>();
      final userId = authService.currentUser?.uid;
      
      if (userId == null) {
        debugPrint('❌ [iOS-알림설정] userId가 null입니다');
        return;
      }
      
      debugPrint('✓ [iOS-알림설정] userId: $userId');
      
      final fcmService = FCMService();
      final settings = await fcmService.getUserNotificationSettings(userId);
      
      debugPrint('📦 [iOS-알림설정] Firestore에서 가져온 설정: $settings');
      
      if (settings != null && mounted) {
        setState(() {
          _pushEnabled = settings['pushEnabled'] ?? true;
          _soundEnabled = settings['soundEnabled'] ?? true;
          _vibrationEnabled = settings['vibrationEnabled'] ?? true;
        });
        
        debugPrint('✅ [iOS-알림설정] 로드 완료 및 UI 업데이트:');
        debugPrint('   - 푸시 알림: $_pushEnabled');
        debugPrint('   - 알림음: $_soundEnabled');
        debugPrint('   - 진동: $_vibrationEnabled');
      } else {
        debugPrint('⚠️ [iOS-알림설정] settings가 null이거나 widget이 unmounted됨');
      }
    } catch (e, stackTrace) {
      debugPrint('❌ [iOS-알림설정] 로드 오류: $e');
      debugPrint('   스택 트레이스: $stackTrace');
    }
  }

  // FCM 알림 설정 업데이트
  Future<void> _updateNotificationSetting(String key, bool value) async {
    try {
      debugPrint('🔧 [iOS-알림설정] 업데이트 시작: $key = $value');
      
      final authService = context.read<AuthService>();
      final userId = authService.currentUser?.uid;
      
      if (userId == null) {
        debugPrint('❌ [iOS-알림설정] userId가 null입니다');
        return;
      }
      
      debugPrint('✓ [iOS-알림설정] userId: $userId');
      
      final fcmService = FCMService();
      await fcmService.updateSingleSetting(userId, key, value);
      
      debugPrint('✅ [iOS-알림설정] Firestore 업데이트 성공: $key = $value');
      
      if (mounted) {
        await DialogUtils.showSuccess(
          context,
          '설정이 저장되었습니다',
          duration: const Duration(seconds: 1),
        );
      }
    } catch (e, stackTrace) {
      debugPrint('❌ [iOS-알림설정] 업데이트 오류: $e');
      debugPrint('   스택 트레이스: $stackTrace');
      
      if (mounted) {
        await DialogUtils.showError(
          context,
          '설정 저장 실패: $e',
        );
      }
    }
  }

  // DCMIWS 착신전화 수신 설정 불러오기
  Future<void> _loadDcmiwsSettings() async {
    try {
      if (kDebugMode) {
        debugPrint('📥 [DCMIWS설정] 로드 시작');
      }
      
      final authService = context.read<AuthService>();
      final userId = authService.currentUser?.uid;
      
      if (userId == null) {
        if (kDebugMode) {
          debugPrint('❌ [DCMIWS설정] userId가 null입니다');
        }
        return;
      }
      
      // 🔄 CRITICAL: Firestore에서 직접 최신 값 읽기
      // AuthService의 currentUserModel이 업데이트 안 될 수 있으므로
      // Firestore에서 직접 읽어서 확실하게 최신 값 사용
      if (kDebugMode) {
        debugPrint('🔄 [DCMIWS설정] Firestore에서 직접 최신 값 읽기...');
      }
      
      final userDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(userId)
          .get();
      
      if (userDoc.exists && userDoc.data() != null) {
        final dcmiwsEnabled = userDoc.data()!['dcmiwsEnabled'] as bool? ?? false;
        
        if (mounted) {
          setState(() {
            _dcmiwsEnabled = dcmiwsEnabled;
          });
          
          if (kDebugMode) {
            debugPrint('✅ [DCMIWS설정] Firestore에서 로드 완료: dcmiwsEnabled=$_dcmiwsEnabled');
          }
        }
      } else {
        if (kDebugMode) {
          debugPrint('❌ [DCMIWS설정] Firestore 문서가 없습니다');
        }
      }
    } catch (e) {
      if (kDebugMode) {
        debugPrint('❌ [DCMIWS설정] 로드 오류: $e');
      }
    }
  }

  // DCMIWS 착신전화 수신 설정 업데이트
  Future<void> _updateDcmiwsEnabled(bool value) async {
    try {
      if (kDebugMode) {
        debugPrint('🔧 [DCMIWS설정] 업데이트 시작: $_dcmiwsEnabled -> $value');
      }
      
      final authService = context.read<AuthService>();
      final userId = authService.currentUser?.uid;
      
      if (userId == null) {
        throw Exception('사용자 인증 정보가 없습니다');
      }
      
      final databaseService = DatabaseService();
      await databaseService.updateUserField(userId, 'dcmiwsEnabled', value);
      
      // 🔍 DEBUG: Firestore 업데이트 확인
      if (kDebugMode) {
        debugPrint('✅ [DCMIWS설정] Firestore 업데이트 완료: dcmiwsEnabled=$value');
        // 실제 Firestore 값 재확인
        final userDoc = await FirebaseFirestore.instance
            .collection('users')
            .doc(userId)
            .get();
        final actualValue = userDoc.data()?['dcmiwsEnabled'];
        debugPrint('🔍 [DCMIWS설정] Firestore 실제 값 확인: $actualValue (타입: ${actualValue.runtimeType})');
      }
      
      if (mounted) {
        setState(() {
          _dcmiwsEnabled = value;
        });
        
        if (kDebugMode) {
          debugPrint('✅ [DCMIWS설정] UI 상태 업데이트 완료: dcmiwsEnabled=$value');
        }
        
        // DCMIWS 웹소켓 연결 상태 관리
        // ConnectionManager를 통해 설정 변경 반영
        final connectionManager = DCMIWSConnectionManager();
        
        if (value) {
          // DCMIWS 활성화 시: ConnectionManager가 자동으로 연결 시도
          await connectionManager.refreshSettings();
          
          if (kDebugMode) {
            debugPrint('✅ [DCMIWS설정] ConnectionManager 설정 갱신 완료');
          }
          
          await DialogUtils.showSuccess(
            context,
            'DCMIWS 착신전화 수신이 활성화되었습니다\n\n웹소켓 연결이 시작됩니다',
            duration: const Duration(seconds: 2),
          );
        } else {
          // DCMIWS 비활성화 시: ConnectionManager가 자동으로 연결 해제
          await connectionManager.refreshSettings();
          
          if (kDebugMode) {
            debugPrint('✅ [DCMIWS설정] ConnectionManager 연결 해제 완료');
          }
          
          await DialogUtils.showSuccess(
            context,
            'DCMIWS 착신전화 수신이 비활성화되었습니다\n\nPUSH(FCM) 방식으로 착신전화를 수신합니다',
            duration: const Duration(seconds: 2),
          );
        }
      }
    } catch (e) {
      if (kDebugMode) {
        debugPrint('❌ [DCMIWS설정] 업데이트 오류: $e');
      }
      
      if (mounted) {
        await DialogUtils.showError(
          context,
          'DCMIWS 설정 변경 실패: $e',
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
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Drawer(
      child: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: isDark
                ? [
                    Theme.of(context).scaffoldBackgroundColor,
                    Colors.grey[900]!,
                  ]
                : [
                    Colors.white,
                    Colors.grey[50]!,
                  ],
          ),
        ),
        child: ListView(
          padding: EdgeInsets.zero,
          children: [
            // 🎯 모던한 프로필 헤더 (그라데이션 배경)
            Container(
              padding: EdgeInsets.only(
                top: MediaQuery.of(context).padding.top + 20,
                left: 20,
                right: 20,
                bottom: 20,
              ),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFF2196F3), Color(0xFF1976D2)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFF2196F3).withValues(alpha: 0.3),
                    blurRadius: 12,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Row(
                children: [
                  // 프로필 아바타 (그림자 효과)
                  InkWell(
                    onTap: () => _showProfileDetailDialog(context, authService),
                    borderRadius: BorderRadius.circular(30),
                    child: Container(
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.3),
                            blurRadius: 8,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      child: CircleAvatar(
                        radius: 28,
                        backgroundColor: Colors.white,
                        backgroundImage: userModel?.profileImageUrl != null
                            ? NetworkImage(userModel!.profileImageUrl!)
                            : const AssetImage('assets/icons/app_icon.png') as ImageProvider,
                      ),
                    ),
                  ),
                  const SizedBox(width: 16),
                  // 조직명 + 이메일
                  Expanded(
                    child: InkWell(
                      onTap: () => _showProfileDetailDialog(context, authService),
                      borderRadius: BorderRadius.circular(8),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // 조직명
                          if (userModel?.companyName != null && userModel!.companyName!.isNotEmpty)
                            Text(
                              userModel.companyName!,
                              style: const TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                                color: Colors.white,
                                letterSpacing: 0.2,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          const SizedBox(height: 4),
                          // 이메일
                          Text(
                            userModel?.email ?? '이메일 없음',
                            style: TextStyle(
                              fontSize: 13,
                              color: Colors.white.withValues(alpha: 0.9),
                              fontWeight: FontWeight.w500,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                    ),
                  ),
                  // 로그아웃 아이콘 (흰색)
                  Container(
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.2),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: IconButton(
                      onPressed: () => _handleLogoutFromList(context),
                      icon: const Icon(Icons.logout_rounded),
                      color: Colors.white,
                      tooltip: '로그아웃',
                      iconSize: 22,
                    ),
                  ),
                ],
              ),
            ),
            
            // 🎯 모던한 설정 섹션
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // 설정 서브 텍스트
                  Padding(
                    padding: const EdgeInsets.only(left: 4, bottom: 8),
                    child: Text(
                      '설정',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: isDark ? Colors.grey[400] : Colors.grey[600],
                        letterSpacing: 0.5,
                      ),
                    ),
                  ),

                  // 기본 API 설정 카드
                  Container(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: isDark 
                            ? [Colors.blue[900]!.withValues(alpha: 0.3), Colors.blue[800]!.withValues(alpha: 0.3)]
                            : [Colors.blue[50]!, Colors.blue[100]!],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: isDark ? Colors.blue[700]! : Colors.blue[200]!, 
                        width: 1.5,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.blue.withValues(alpha: isDark ? 0.2 : 0.1),
                          blurRadius: 8,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: ListTile(
                      leading: Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: isDark ? Colors.blue[900]!.withValues(alpha: 0.5) : Colors.white,
                          shape: BoxShape.circle,
                        ),
                        child: Icon(
                          Icons.settings_rounded,
                          size: 20,
                          color: isDark ? Colors.blue[300] : const Color(0xFF2196F3),
                        ),
                      ),
                      title: Text(
                        '기본 API 설정',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: isDark ? Colors.blue[200] : Colors.blue[900],
                        ),
                      ),
                      subtitle: Text(
                        'API 서버, WebSocket 설정',
                        style: TextStyle(
                          fontSize: 12,
                          color: isDark ? Colors.blue[300] : Colors.blue[700],
                        ),
                      ),
                      trailing: Icon(
                        Icons.chevron_right_rounded,
                        size: 20,
                        color: isDark ? Colors.blue[400] : Colors.blue[600],
                      ),
                      onTap: () {
                        showDialog(
                          context: context,
                          builder: (context) => const ApiSettingsDialog(),
                        );
                      },
                    ),
                  ),
                ],
              ),
            ),
          
            // 🎯 모던한 내 단말번호 섹션
            if (userId.isNotEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                child: StreamBuilder<List<MyExtensionModel>>(
                  stream: DatabaseService().getMyExtensions(userId),
                  builder: (context, snapshot) {
                    final extensions = snapshot.data ?? [];
                    final extensionCount = extensions.length;
                    
                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [

                        // 단말번호 카드
                        Container(
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              colors: isDark 
                                  ? [Colors.cyan[900]!.withValues(alpha: 0.3), Colors.cyan[800]!.withValues(alpha: 0.3)]
                                  : [Colors.cyan[50]!, Colors.cyan[100]!],
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                            ),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: isDark ? Colors.cyan[700]! : Colors.cyan[200]!, 
                              width: 1.5,
                            ),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.cyan.withValues(alpha: isDark ? 0.2 : 0.1),
                                blurRadius: 8,
                                offset: const Offset(0, 2),
                              ),
                            ],
                          ),
                          child: ListTile(
                            leading: Container(
                              padding: const EdgeInsets.all(8),
                              decoration: BoxDecoration(
                                color: isDark ? Colors.cyan[900]!.withValues(alpha: 0.5) : Colors.white,
                                shape: BoxShape.circle,
                              ),
                              child: Icon(
                                Icons.phone_android_rounded,
                                size: 20,
                                color: isDark ? Colors.cyan[300] : Colors.cyan[700],
                              ),
                            ),
                            title: Text(
                              '내 단말번호',
                              style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w600,
                                color: isDark ? Colors.cyan[200] : Colors.cyan[900],
                              ),
                            ),
                            subtitle: Text(
                              extensionCount > 0 
                                  ? '등록됨: ${extensions.map((e) => e.extension).join(", ")}'
                                  : '등록된 단말번호가 없습니다',
                              style: TextStyle(
                                fontSize: 12,
                                color: isDark 
                                    ? (extensionCount > 0 ? Colors.cyan[300] : Colors.cyan[400])
                                    : (extensionCount > 0 ? Colors.cyan[700] : Colors.cyan[600]),
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
                            color: isDark 
                                ? Colors.cyan[900]!.withValues(alpha: 0.5)
                                : Colors.cyan[700]!.withAlpha(26),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Text(
                            '$extensionCount개',
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                              color: isDark ? Colors.cyan[300] : Colors.cyan[700],
                            ),
                          ),
                        ),
                              const SizedBox(width: 8),
                              Icon(
                                Icons.chevron_right_rounded,
                                size: 20,
                                color: isDark ? Colors.cyan[400] : Colors.cyan[600],
                              ),
                            ],
                          ),
                          onTap: () => _showExtensionsManagementDialog(context, extensions),
                        ),
                      ),
                    ],
                  );
                },
              ),
            ),
          
          // 🎨 화면 테마
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [

                // 화면 테마 카드
                Container(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: isDark 
                          ? [Colors.amber[900]!.withValues(alpha: 0.3), Colors.orange[900]!.withValues(alpha: 0.3)]
                          : [Colors.amber[50]!, Colors.orange[100]!],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: isDark ? Colors.amber[700]! : Colors.orange[200]!, 
                      width: 1.5,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.orange.withValues(alpha: isDark ? 0.2 : 0.1),
                        blurRadius: 8,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: ListTile(
                    leading: Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: isDark ? Colors.amber[900]!.withValues(alpha: 0.5) : Colors.white,
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        Icons.brightness_6,
                        size: 20,
                        color: isDark ? Colors.amber[300] : Colors.orange[700],
                      ),
                    ),
                    title: Text(
                      '화면 테마',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: isDark ? Colors.amber[200] : Colors.orange[900],
                      ),
                    ),
                    subtitle: Text(
                      '라이트 모드, 다크 모드, 시스템 설정',
                      style: TextStyle(
                        fontSize: 12,
                        color: isDark ? Colors.amber[300] : Colors.orange[700],
                      ),
                    ),
                    trailing: Icon(
                      Icons.chevron_right_rounded,
                      size: 20,
                      color: isDark ? Colors.amber[400] : Colors.orange[600],
                    ),
                    onTap: () {
                      showDialog(
                        context: context,
                        builder: (context) => const ThemeSettingsDialog(),
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
          
          // 📱 통합 알림 설정 (하나의 메뉴로 통합)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: isDark 
                      ? [Colors.blue[900]!.withValues(alpha: 0.3), Colors.blue[800]!.withValues(alpha: 0.3)]
                      : [Colors.blue[50]!, Colors.blue[100]!],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: isDark ? Colors.blue[700]! : Colors.blue[200]!, 
                  width: 1.5,
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.blue.withValues(alpha: isDark ? 0.2 : 0.1),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: ListTile(
                leading: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: isDark ? Colors.blue[900]!.withValues(alpha: 0.5) : Colors.white,
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    Icons.notifications_active, 
                    color: isDark ? Colors.blue[300] : const Color(0xFF2196F3), 
                    size: 24,
                  ),
                ),
                title: Text(
                  '앱 알림 설정',
                  style: TextStyle(
                    fontWeight: FontWeight.w700,
                    fontSize: 16,
                    color: isDark ? Colors.blue[300] : const Color(0xFF1976D2),
                  ),
                ),
                subtitle: Text(
                  _pushEnabled 
                    ? '푸시 알림 활성화 • ${_soundEnabled ? "소리 켜짐" : "소리 꺼짐"}' 
                    : '푸시 알림 비활성화',
                  style: TextStyle(
                    fontSize: 12,
                    color: isDark ? Colors.blue[200] : Colors.blue[900],
                    fontWeight: FontWeight.w500,
                  ),
                ),
                trailing: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      _pushEnabled ? Icons.check_circle : Icons.cancel,
                      color: _pushEnabled 
                          ? (isDark ? Colors.green[300] : Colors.green) 
                          : (isDark ? Colors.grey[600] : Colors.grey),
                      size: 22,
                    ),
                    const SizedBox(width: 4),
                    Icon(
                      Icons.chevron_right, 
                      color: isDark ? Colors.blue[300] : const Color(0xFF1976D2),
                    ),
                  ],
                ),
                onTap: () => _showNotificationSettingsDialog(context),
              ),
            ),
          ),

          
          // 📡 착신전화 수신 설정 (Premium 전용)
          if (_isPremium) ...[
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Container(
                decoration: BoxDecoration(
                  color: isDark ? Colors.teal[900]!.withValues(alpha: 0.3) : Colors.teal[50],
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: isDark ? Colors.teal[700]! : Colors.teal[100]!),
                ),
                child: ListTile(
                  leading: Icon(
                    Icons.settings_input_antenna, 
                    color: isDark ? Colors.teal[300] : Colors.teal,
                  ),
                  title: Text(
                    '착신전화 수신 방식',
                    style: TextStyle(
                      fontWeight: FontWeight.w600,
                      color: isDark ? Colors.white : Colors.black87,
                    ),
                  ),
                  subtitle: Text(
                    'PUSH(기본) 또는 DCMIWS 선택', 
                    style: TextStyle(
                      fontSize: 12,
                      color: isDark ? Colors.grey[400] : Colors.black54,
                    ),
                  ),
                ),
              ),
            ),
            
            // DCMIWS 착신전화 수신 설정
            _buildSwitchTile(
              icon: Icons.wifi_tethering,
              title: 'DCMIWS 실시간 수신',
              subtitle: _dcmiwsEnabled 
                  ? '웹소켓으로 실시간 착신전화 수신 중' 
                  : 'PUSH(FCM)로 착신전화 수신 (기본)',
              value: _dcmiwsEnabled,
              onChanged: (value) => _updateDcmiwsEnabled(value),
            ),
            
            // DCMIWS 설명
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
              child: Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: isDark ? Colors.grey[850] : Colors.grey[100],
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: isDark ? Colors.grey[700]! : Colors.grey[300]!),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(
                          Icons.info_outline, 
                          size: 16, 
                          color: isDark ? Colors.grey[400] : Colors.grey[600],
                        ),
                        const SizedBox(width: 6),
                        Text(
                          '착신전화 수신 방식 안내',
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: isDark ? Colors.grey[300] : Colors.grey[800],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text(
                      '• PUSH(기본): FCM을 통해 착신전화 알림 수신\n'
                      '  배터리 효율적, 안정적인 방식\n\n'
                      '• DCMIWS: 웹소켓으로 실시간 수신\n'
                      '  더 빠른 응답, 배터리 사용량 증가',
                      style: TextStyle(
                        fontSize: 11,
                        color: isDark ? Colors.grey[400] : Colors.grey[700],
                        height: 1.4,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
          
          // 약관 및 정책 (펼침/접힘)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Container(
              decoration: BoxDecoration(
                color: isDark ? Colors.purple[900]!.withValues(alpha: 0.3) : Colors.purple[50],
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: isDark ? Colors.purple[700]! : Colors.purple[100]!),
              ),
              child: ExpansionTile(
                leading: Icon(
                  Icons.description, 
                  color: isDark ? Colors.purple[300] : Colors.purple,
                ),
                title: Text(
                  '약관 및 정책',
                  style: TextStyle(
                    fontWeight: FontWeight.w600,
                    fontSize: 15,
                    color: isDark ? Colors.white : Colors.black87,
                  ),
                ),
                subtitle: Text(
                  '이용약관, 개인정보처리방침, 라이선스', 
                  style: TextStyle(
                    fontSize: 12,
                    color: isDark ? Colors.grey[400] : Colors.black54,
                  ),
                ),
                iconColor: isDark ? Colors.purple[300] : Colors.purple,
                collapsedIconColor: isDark ? Colors.purple[300] : Colors.purple,
                children: [
                  // 서비스 이용 약관
                  ListTile(
                    contentPadding: const EdgeInsets.only(left: 56, right: 16),
                    leading: Icon(
                      Icons.description, 
                      size: 20, 
                      color: isDark ? Colors.grey[400] : Colors.black54,
                    ),
                    title: Text(
                      '서비스 이용 약관', 
                      style: TextStyle(
                        fontSize: 14,
                        color: isDark ? Colors.grey[200] : Colors.black87,
                      ),
                    ),
                    trailing: Icon(
                      Icons.open_in_new, 
                      size: 18,
                      color: isDark ? Colors.grey[500] : Colors.grey,
                    ),
                    onTap: () {
                      _openExternalUrl('https://makecall.io/mcuc/terms_of_service.html');
                    },
                  ),
                  
                  // 개인정보 처리방침
                  ListTile(
                    contentPadding: const EdgeInsets.only(left: 56, right: 16),
                    leading: Icon(
                      Icons.privacy_tip, 
                      size: 20,
                      color: isDark ? Colors.grey[400] : Colors.black54,
                    ),
                    title: Text(
                      '개인정보 처리방침', 
                      style: TextStyle(
                        fontSize: 14,
                        color: isDark ? Colors.grey[200] : Colors.black87,
                      ),
                    ),
                    trailing: Icon(
                      Icons.open_in_new, 
                      size: 18,
                      color: isDark ? Colors.grey[500] : Colors.grey,
                    ),
                    onTap: () {
                      _openExternalUrl('https://makecall.io/mcuc/privacy_policy.html');
                    },
                  ),
                  
                  // 오픈소스 라이선스
                  ListTile(
                    contentPadding: const EdgeInsets.only(left: 56, right: 16),
                    leading: Icon(
                      Icons.code, 
                      size: 20,
                      color: isDark ? Colors.grey[400] : Colors.black54,
                    ),
                    title: Text(
                      '오픈소스 라이선스', 
                      style: TextStyle(
                        fontSize: 14,
                        color: isDark ? Colors.grey[200] : Colors.black87,
                      ),
                    ),
                    trailing: Icon(
                      Icons.chevron_right, 
                      size: 18,
                      color: isDark ? Colors.grey[500] : Colors.grey,
                    ),
                    onTap: () {
                      _showLicensePage(context);
                    },
                  ),
                  
                  const SizedBox(height: 8),
                ],
              ),
            ),
          ),
          
          // 앱 정보
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Container(
              decoration: BoxDecoration(
                color: isDark ? Colors.green[900]!.withValues(alpha: 0.3) : Colors.green[50],
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: isDark ? Colors.green[700]! : Colors.green[100]!,
                ),
              ),
              child: FutureBuilder<PackageInfo>(
                future: PackageInfo.fromPlatform(),
                builder: (context, snapshot) {
                  final version = snapshot.data?.version ?? '1.0.0';
                  final buildNumber = snapshot.data?.buildNumber ?? '1';
                  return ListTile(
                    leading: Icon(
                      Icons.info, 
                      color: isDark ? Colors.green[300] : Colors.green,
                    ),
                    title: Text(
                      '앱 버전',
                      style: TextStyle(
                        fontWeight: FontWeight.w600,
                        color: isDark ? Colors.grey[200] : Colors.black87,
                      ),
                    ),
                    subtitle: Text(
                      '$version ($buildNumber)',
                      style: TextStyle(
                        fontSize: 12, 
                        fontWeight: FontWeight.w500,
                        color: isDark ? Colors.grey[400] : Colors.black54,
                      ),
                    ),
                  );
                },
              ),
            ),
          ),

          
          const SizedBox(height: 24),
          
          // 하단 여백
          const SizedBox(height: 16),
        ],
      ),
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
    final isDark = Theme.of(context).brightness == Brightness.dark;
    
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      child: Container(
        decoration: BoxDecoration(
          color: isDark ? Colors.grey[850] : Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isDark ? Colors.grey[700]! : Colors.grey[200]!,
          ),
        ),
        child: SwitchListTile(
          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
          secondary: Icon(
            icon, 
            color: isDark ? Colors.blue[300] : const Color(0xFF2196F3), 
            size: 22,
          ),
          title: Text(
            title, 
            style: TextStyle(
              fontSize: 14, 
              fontWeight: FontWeight.w500,
              color: isDark ? Colors.grey[200] : Colors.black87,
            ),
          ),
          subtitle: Text(
            subtitle, 
            style: TextStyle(
              fontSize: 11,
              color: isDark ? Colors.grey[400] : Colors.black54,
            ),
          ),
          value: value,
          onChanged: onChanged,
          activeTrackColor: isDark 
              ? Colors.blue[700]!.withValues(alpha: 0.5)
              : const Color(0xFF2196F3).withAlpha(128),
          activeThumbColor: isDark ? Colors.blue[400] : const Color(0xFF2196F3),
        ),
      ),
    );
  }

  Widget _buildExtensionsList(List<MyExtensionModel> extensions) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    
    return Column(
      children: [
        // 총 개수 표시
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: isDark ? Colors.green[900]!.withAlpha(77) : Colors.green[50],
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
              color: isDark ? Colors.green[700]! : Colors.green[200]!,
            ),
          ),
          child: Row(
            children: [
              Icon(
                Icons.check_circle, 
                color: isDark ? Colors.green[300] : Colors.green, 
                size: 18,
              ),
              const SizedBox(width: 8),
              Text(
                '총 ${extensions.length}개의 단말번호',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: isDark ? Colors.green[300] : Colors.green,
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
                color: ext.hasApiConfig 
                    ? (isDark ? Colors.green[700]! : Colors.green.withAlpha(102))
                    : (isDark ? Colors.grey[700]! : Colors.grey.withAlpha(51)),
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
                          backgroundColor: isDark 
                              ? Colors.blue[900]!.withAlpha(128)
                              : const Color(0xFF2196F3).withAlpha(51),
                          child: Icon(
                            Icons.phone_android,
                            color: isDark ? Colors.blue[300] : const Color(0xFF2196F3),
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
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 16,
                                  color: isDark ? Colors.blue[300] : const Color(0xFF2196F3),
                                ),
                              ),
                              if (ext.name.isNotEmpty)
                                Text(
                                  ext.name,
                                  style: TextStyle(
                                    fontSize: 13,
                                    color: isDark ? Colors.grey[300] : Colors.black87,
                                  ),
                                ),
                            ],
                          ),
                        ),
                        const Spacer(),
                        IconButton(
                          icon: Icon(
                            Icons.delete, 
                            color: isDark ? Colors.red[300] : Colors.red, 
                            size: 22,
                          ),
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
            await DialogUtils.showInfo(context, '프로필 사진이 업데이트되었습니다', duration: const Duration(seconds: 2));
          } else {
            await DialogUtils.showInfo(context, '이미지 업로드에 실패했습니다', duration: const Duration(seconds: 2));
          }
        }
      }
    } catch (e) {
      if (mounted) {
        await DialogUtils.showError(context, '오류: $e');
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
        await DialogUtils.showInfo(context, '프로필 사진이 삭제되었습니다', duration: const Duration(seconds: 2));
      }
    } catch (e) {
      if (mounted) {
        Navigator.pop(context);
        await DialogUtils.showError(context, '오류: $e');
      }
    }
  }

  Future<void> _searchMyExtensions(BuildContext context) async {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    
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
            backgroundColor: isDark ? Colors.grey[900] : Colors.white,
            icon: Icon(
              Icons.error_outline, 
              color: isDark ? Colors.orange[300] : Colors.orange, 
              size: 48,
            ),
            title: Text(
              '단말번호 없음',
              style: TextStyle(color: isDark ? Colors.grey[200] : Colors.black87),
            ),
            content: Text(
              '내 이메일과 일치하는 단말번호를 찾을 수 없습니다.\n\n관리자에게 단말번호 등록을 요청하세요.',
              style: TextStyle(color: isDark ? Colors.grey[300] : Colors.black87),
            ),
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
                    color: isDark ? Colors.orange[900]!.withAlpha(77) : Colors.orange[50],
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
                              color: isDark ? Colors.grey[300] : Colors.black87,
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
          backgroundColor: isDark ? Colors.grey[900] : Colors.white,
          icon: Icon(
            Icons.error, 
            color: isDark ? Colors.red[300] : Colors.red, 
            size: 48,
          ),
          title: Text(
            'API 조회 실패',
            style: TextStyle(color: isDark ? Colors.grey[200] : Colors.black87),
          ),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '단말번호 조회 중 오류가 발생했습니다:',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: isDark ? Colors.grey[200] : Colors.black87,
                  ),
                ),
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: isDark ? Colors.red[900]!.withAlpha(77) : Colors.red.shade50,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: isDark ? Colors.red[700]! : Colors.red.shade200,
                    ),
                  ),
                  child: Text(
                    e.toString(),
                    style: TextStyle(
                      fontSize: 12,
                      fontFamily: 'monospace',
                      color: isDark ? Colors.red[300] : Colors.black87,
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  '확인 사항:',
                  style: TextStyle(
                    fontWeight: FontWeight.bold, 
                    fontSize: 13,
                    color: isDark ? Colors.grey[200] : Colors.black87,
                  ),
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
        await DialogUtils.showSuccess(context, '단말번호가 등록되었습니다', duration: const Duration(seconds: 2));
      }
    } catch (e) {
      if (kDebugMode) {
        debugPrint('❌ ProfileDrawer - 단말번호 등록 실패: $e');
      }
      // ✅ CRITICAL FIX: context.mounted 체크로 위젯이 여전히 활성 상태인지 확인
      if (mounted && context.mounted) {
        await DialogUtils.showError(context, '등록 실패: $e');
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
          await DialogUtils.showInfo(context, '단말번호가 삭제되었습니다', duration: const Duration(seconds: 2));
        }
      } catch (e) {
        if (kDebugMode) {
          debugPrint('❌ ProfileDrawer - 단말번호 삭제 실패: $e');
        }
        // ✅ CRITICAL FIX: context.mounted 체크로 위젯이 여전히 활성 상태인지 확인
        if (mounted && context.mounted) {
          await DialogUtils.showError(context, '삭제 실패: $e');
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
          await DialogUtils.showInfo(context, '모든 단말번호가 삭제되었습니다', duration: const Duration(seconds: 2));
        }
      } catch (e) {
        if (kDebugMode) {
          debugPrint('❌ ProfileDrawer - 전체 삭제 실패: $e');
        }
        // ✅ CRITICAL FIX: context.mounted 체크로 위젯이 여전히 활성 상태인지 확인
        if (mounted && context.mounted) {
          await DialogUtils.showError(context, '삭제 실패: $e');
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
  
  /// 외부 URL을 기본 브라우저에서 열기
  Future<void> _openExternalUrl(String url) async {
    try {
      final uri = Uri.parse(url);
      
      if (await canLaunchUrl(uri)) {
        await launchUrl(
          uri,
          mode: LaunchMode.externalApplication, // 외부 브라우저에서 열기
        );
      } else {
        if (mounted) {
          await DialogUtils.showError(
            context,
            'URL을 열 수 없습니다: $url',
          );
        }
      }
    } catch (e) {
      if (kDebugMode) {
        debugPrint('❌ URL 열기 실패: $e');
      }
      if (mounted) {
        await DialogUtils.showError(
          context,
          'URL 열기 실패: $e',
        );
      }
    }
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
          await DialogUtils.showSuccess(context, '로그아웃되었습니다. 새로운 계정으로 로그인해주세요.', duration: const Duration(seconds: 2));
        }
      } catch (e) {
        if (mounted) {
          await DialogUtils.showError(context, '오류 발생: $e');
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
        await DialogUtils.showInfo(
          context,
          '${account.displayName} 계정으로 자동 전환합니다...',
          duration: const Duration(seconds: 2),
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
        await DialogUtils.showInfo(
          context,
          autoLoginEnabled
              ? '로그아웃되었습니다. ${account.email}로 자동 로그인 중...'
              : '로그아웃되었습니다. ${account.email}로 다시 로그인해주세요.',
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
          await DialogUtils.showSuccess(
            context,
            result.isEmpty 
                ? '조직명이 삭제되었습니다' 
                : '조직명이 업데이트되었습니다',
            duration: const Duration(seconds: 2),
          );
        }
      } catch (e) {
        if (mounted) {
          await DialogUtils.showError(context, '오류 발생: $e');
        }
      }
    }
  }

  // 등록된 계정 삭제 (로그인하지 않은 계정만)
  Future<void> _handleDeleteAccount(BuildContext context, SavedAccountModel account) async {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    
    // 현재 로그인된 계정인지 다시 확인 (안전장치)
    if (account.isCurrentAccount) {
      await DialogUtils.showWarning(context, '현재 로그인된 계정은 삭제할 수 없습니다. 로그아웃 후 삭제해주세요.', duration: const Duration(seconds: 2));
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
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                            color: isDark ? Colors.grey[200] : Colors.black87,
                          ),
                        ),
                        Text(
                          account.email,
                          style: TextStyle(
                            fontSize: 12,
                            color: isDark ? Colors.grey[400] : Colors.grey,
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
        
        await DialogUtils.showSuccess(
          context,
          '${account.displayName} 계정이 목록에서 삭제되었습니다',
          duration: const Duration(seconds: 2),
        );
      }
    } catch (e) {
      if (mounted) {
        await DialogUtils.showError(context, '계정 삭제 실패: $e');
      }
    }
  }

  // 등록된 계정 목록에서 로그아웃 (다이얼로그 없이 바로 로그아웃)
  Future<void> _handleLogoutFromList(BuildContext context) async {
    // 🔹 확인 다이얼로그 먼저 표시
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
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
            ),
            child: const Text('로그아웃'),
          ),
        ],
      ),
    );
    
    // 사용자가 취소를 선택한 경우
    if (confirmed != true) return;
    
    // 🔑 CRITICAL: AuthService를 먼저 가져오기 (context가 유효할 때)
    final authService = context.read<AuthService>();
    
    // Drawer 닫기
    if (mounted) {
      Navigator.pop(context);
    }
    
    // 🔑 Drawer 닫기 애니메이션 완료까지 대기 (350ms)
    await Future.delayed(const Duration(milliseconds: 350));
    
    try {
      // 로그아웃 실행 (미리 가져온 AuthService 사용)
      await authService.signOut();
      
      if (kDebugMode) {
        debugPrint('✅ [LOGOUT] 로그아웃 완료');
      }
      
    } catch (e) {
      if (kDebugMode) {
        debugPrint('❌ [LOGOUT] 로그아웃 실패: $e');
      }
      
      // 로그아웃 실패 시 에러 표시
      // navigatorKey를 사용하여 전역 context로 Dialog 표시
      if (navigatorKey.currentContext != null) {
        await DialogUtils.showError(
          navigatorKey.currentContext!,
          '로그아웃 실패: $e',
        );
      }
    }
  }

  Future<void> _handleLogout(BuildContext context) async {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: isDark ? Colors.grey[900] : Colors.white,
        title: Text(
          '로그아웃',
          style: TextStyle(
            color: isDark ? Colors.grey[200] : Colors.black87,
          ),
        ),
        content: Text(
          '로그아웃 하시겠습니까?',
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
            style: ElevatedButton.styleFrom(
              backgroundColor: isDark 
                  ? Colors.blue[700]
                  : const Color(0xFF2196F3),
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
    final isDark = Theme.of(context).brightness == Brightness.dark;
    
    showDialog(
      context: context,
      builder: (context) => Dialog(
        backgroundColor: isDark ? Colors.grey[900] : Colors.white,
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
                    Text(
                      '프로필 상세 정보',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: isDark ? Colors.grey[200] : Colors.black87,
                      ),
                    ),
                    IconButton(
                      icon: Icon(
                        Icons.close,
                        color: isDark ? Colors.grey[400] : Colors.black54,
                      ),
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
                      Icon(
                        Icons.update, 
                        size: 14, 
                        color: isDark ? Colors.grey[500] : Colors.grey[600],
                      ),
                      const SizedBox(width: 4),
                      Text(
                        _formatUpdateTimestamp(userModel!.lastMaxExtensionsUpdate!),
                        style: TextStyle(
                          fontSize: 11,
                          color: isDark ? Colors.grey[500] : Colors.grey[600],
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
                      backgroundColor: isDark 
                          ? Colors.blue[700]
                          : const Color(0xFF2196F3),
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
    final isDark = Theme.of(context).brightness == Brightness.dark;
    
    return Row(
      children: [
        Icon(
          icon, 
          size: 20, 
          color: isDark ? Colors.grey[500] : Colors.grey[600],
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: TextStyle(
                  fontSize: 12,
                  color: isDark ? Colors.grey[500] : Colors.grey[600],
                  fontWeight: FontWeight.w500,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                value,
                style: TextStyle(
                  fontSize: 15,
                  color: valueColor ?? (isDark ? Colors.grey[200] : Colors.black87),
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
        if (onEdit != null)
          IconButton(
            icon: Icon(
              Icons.edit, 
              size: 18,
              color: isDark ? Colors.grey[500] : Colors.grey[600],
            ),
            onPressed: onEdit,
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
    final isDark = Theme.of(context).brightness == Brightness.dark;
    
    showDialog(
      context: context,
      builder: (dialogContext) => Dialog(
        backgroundColor: isDark ? Colors.grey[900] : Colors.white,
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
                    Icon(
                      Icons.phone_android, 
                      color: isDark ? Colors.blue[300] : const Color(0xFF2196F3),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        '내 단말번호 관리',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: isDark ? Colors.grey[200] : Colors.black87,
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
                      color: isDark ? Colors.red[900]!.withAlpha(77) : Colors.red[50],
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        color: isDark ? Colors.red[700]! : Colors.red[200]!,
                      ),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          Icons.error_outline, 
                          color: isDark ? Colors.red[300] : Colors.red, 
                          size: 20,
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            _searchError!,
                            style: TextStyle(
                              fontSize: 12, 
                              color: isDark ? Colors.red[300] : Colors.red,
                            ),
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
                            Icon(
                              Icons.inbox_outlined, 
                              size: 64, 
                              color: isDark ? Colors.grey[700] : Colors.grey[400],
                            ),
                            const SizedBox(height: 16),
                            Text(
                              '등록된 단말번호가 없습니다',
                              style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w600,
                                color: isDark ? Colors.grey[400] : Colors.grey[600],
                              ),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              '위의 조회 버튼을 눌러주세요',
                              style: TextStyle(
                                fontSize: 12, 
                                color: isDark ? Colors.grey[500] : Colors.grey[500],
                              ),
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
                              color: isDark ? Colors.grey[850] : Colors.white,
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                color: isDark ? Colors.grey[700]! : Colors.grey[300]!, 
                                width: 1,
                              ),
                              boxShadow: [
                                BoxShadow(
                                  color: isDark 
                                      ? Colors.black.withAlpha(51)
                                      : Colors.grey.withAlpha(26),
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
                                      color: isDark 
                                          ? Colors.blue[900]!.withAlpha(128)
                                          : const Color(0xFF2196F3).withAlpha(26),
                                      shape: BoxShape.circle,
                                    ),
                                    child: Center(
                                      child: Text(
                                        '${index + 1}',
                                        style: TextStyle(
                                          color: isDark 
                                              ? Colors.blue[300] 
                                              : const Color(0xFF2196F3),
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
                                          style: TextStyle(
                                            fontSize: 15,
                                            fontWeight: FontWeight.bold,
                                            color: isDark ? Colors.grey[200] : Colors.black87,
                                          ),
                                        ),
                                        const SizedBox(height: 4),
                                        // 단말번호 (두 번째 줄)
                                        Text(
                                          ext.extension,
                                          style: TextStyle(
                                            fontSize: 14,
                                            fontWeight: FontWeight.w600,
                                            color: isDark ? Colors.blue[300] : const Color(0xFF2196F3),
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
                                    icon: Icon(
                                      Icons.delete_outline, 
                                      size: 20,
                                      color: isDark ? Colors.red[300] : Colors.red,
                                    ),
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

  /// 복사 버튼이 있는 정보 행 빌더
  Widget _buildLongPressCopyRow({
    required BuildContext context,
    required String label,
    required String value,
  }) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          // 라벨 (60px로 축소하여 값 표시 공간 확보)
          SizedBox(
            width: 60,
            child: Text(
              label,
              style: TextStyle(
                fontSize: 9,
                fontWeight: FontWeight.w600,
                color: isDark ? Colors.grey[500] : Colors.grey[600],
              ),
            ),
          ),
          // 값 (더 많은 문자 표시 가능)
          Expanded(
            child: Text(
              value,
              style: TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.w500,
                color: isDark ? Colors.grey[300] : Colors.black87,
                fontFamily: 'monospace',
                letterSpacing: 0.2,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          const SizedBox(width: 2),
          // 복사 버튼 (최소 크기로 더 많은 텍스트 공간 확보)
          IconButton(
            icon: const Icon(Icons.content_copy, size: 14),
            onPressed: () async {
              Clipboard.setData(ClipboardData(text: value));
              await DialogUtils.showCopySuccess(context, label, value);
            },
            tooltip: '복사',
            padding: const EdgeInsets.all(2),
            constraints: const BoxConstraints(
              minWidth: 28,
              minHeight: 28,
            ),
            visualDensity: VisualDensity.compact,
          ),
        ],
      ),
    );
  }
  
  /// 웹 푸시 권한 요청
  Future<void> _requestWebPushPermission(BuildContext context) async {
    if (!kIsWeb) return;
    
    final isDark = Theme.of(context).brightness == Brightness.dark;
    
    try {
      // FCM 서비스 가져오기
      final fcmService = FCMService();
      final userId = AuthService().currentUser?.uid;
      
      if (userId == null) {
        if (mounted) {
          await DialogUtils.showError(context, '로그인이 필요합니다', duration: const Duration(seconds: 3));
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
              backgroundColor: isDark ? Colors.grey[900] : Colors.white,
              icon: Icon(
                Icons.check_circle, 
                color: isDark ? Colors.green[300] : Colors.green, 
                size: 48,
              ),
              title: Text(
                '웹 푸시 알림 활성화 완료',
                style: TextStyle(color: isDark ? Colors.grey[200] : Colors.black87),
              ),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '브라우저 알림이 활성화되었습니다.',
                    style: TextStyle(color: isDark ? Colors.grey[300] : Colors.black87),
                  ),
                  const SizedBox(height: 16),
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: isDark ? Colors.green[900]!.withAlpha(77) : Colors.green[50],
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        color: isDark ? Colors.green[700]! : Colors.green[200]!,
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
                              color: isDark ? Colors.green[300] : Colors.green,
                            ),
                            const SizedBox(width: 8),
                            Text(
                              '이제 다음 알림을 받을 수 있습니다:',
                              style: TextStyle(
                                fontSize: 12, 
                                fontWeight: FontWeight.w600,
                                color: isDark ? Colors.grey[300] : Colors.black87,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Text(
                          '• 수신 전화 알림', 
                          style: TextStyle(
                            fontSize: 12,
                            color: isDark ? Colors.grey[400] : Colors.black87,
                          ),
                        ),
                        Text(
                          '• 부재중 전화 알림', 
                          style: TextStyle(
                            fontSize: 12,
                            color: isDark ? Colors.grey[400] : Colors.black87,
                          ),
                        ),
                        Text(
                          '• 시스템 알림', 
                          style: TextStyle(
                            fontSize: 12,
                            color: isDark ? Colors.grey[400] : Colors.black87,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    '💡 브라우저를 닫아도 알림을 받을 수 있습니다.',
                    style: TextStyle(
                      fontSize: 11, 
                      color: isDark ? Colors.grey[500] : Colors.grey,
                    ),
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
              backgroundColor: isDark ? Colors.grey[900] : Colors.white,
              icon: Icon(
                Icons.error, 
                color: isDark ? Colors.orange[300] : Colors.orange, 
                size: 48,
              ),
              title: Text(
                '알림 권한 필요',
                style: TextStyle(color: isDark ? Colors.grey[200] : Colors.black87),
              ),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '웹 푸시 알림을 받으려면 브라우저 알림 권한이 필요합니다.',
                    style: TextStyle(color: isDark ? Colors.grey[300] : Colors.black87),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    '브라우저 설정에서 알림 권한을 허용해주세요:',
                    style: TextStyle(
                      fontSize: 12, 
                      fontWeight: FontWeight.w600,
                      color: isDark ? Colors.grey[300] : Colors.black87,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    '1. 브라우저 주소창 왼쪽의 자물쇠 아이콘 클릭', 
                    style: TextStyle(
                      fontSize: 11,
                      color: isDark ? Colors.grey[400] : Colors.black87,
                    ),
                  ),
                  Text(
                    '2. "알림" 또는 "Notifications" 찾기', 
                    style: TextStyle(
                      fontSize: 11,
                      color: isDark ? Colors.grey[400] : Colors.black87,
                    ),
                  ),
                  Text(
                    '3. "허용" 또는 "Allow"로 변경', 
                    style: TextStyle(
                      fontSize: 11,
                      color: isDark ? Colors.grey[400] : Colors.black87,
                    ),
                  ),
                  Text(
                    '4. 페이지 새로고침', 
                    style: TextStyle(
                      fontSize: 11,
                      color: isDark ? Colors.grey[400] : Colors.black87,
                    ),
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
        await DialogUtils.showError(context, '알림 권한 요청 중 오류 발생: $e');
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
  
  /// 📱 모바일/태블릿 푸시 알림 정보 다이얼로그
  void _showMobilePushInfo(BuildContext context) {
    final isIOS = Platform.isIOS;
    
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Row(
          children: [
            Icon(
              isIOS ? Icons.apple : Icons.android, 
              color: Colors.blue
            ),
            const SizedBox(width: 8),
            Text(isIOS ? 'iOS 푸시 알림 안내' : 'Android 푸시 알림 안내'),
          ],
        ),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                isIOS ? 'APNs 기반 푸시 알림' : 'FCM 기반 푸시 알림',
                style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 8),
              Text(
                isIOS
                    ? 'Apple Push Notification service(APNs)를 통해 실시간 알림을 받을 수 있습니다.'
                    : 'Firebase Cloud Messaging(FCM)을 통해 실시간 알림을 받을 수 있습니다.',
                style: const TextStyle(fontSize: 12),
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
                    Text('• 수신 전화 실시간 알림', style: TextStyle(fontSize: 11)),
                    Text('• 기기 승인 요청 알림', style: TextStyle(fontSize: 11)),
                    Text('• 포그라운드/백그라운드 모두 지원', style: TextStyle(fontSize: 11)),
                    Text('• 배터리 효율적인 알림 수신', style: TextStyle(fontSize: 11)),
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
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Row(
                      children: [
                        Icon(Icons.settings, size: 16, color: Colors.orange),
                        SizedBox(width: 8),
                        Text(
                          '알림 설정 방법',
                          style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text(
                      isIOS
                          ? '1. 설정 앱 실행\n2. MAKECALL 찾기\n3. 알림 메뉴 선택\n4. 알림 허용 활성화'
                          : '1. 설정 앱 실행\n2. 앱 → MAKECALL 선택\n3. 알림 메뉴 선택\n4. 알림 허용 활성화',
                      style: const TextStyle(fontSize: 11, height: 1.5),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.green[50],
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.green[200]!),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Row(
                      children: [
                        Icon(Icons.battery_charging_full, size: 16, color: Colors.green),
                        SizedBox(width: 8),
                        Text(
                          '배터리 최적화',
                          style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text(
                      isIOS
                          ? 'APNs는 Apple 서버를 통해 효율적으로 알림을 전달하여 배터리 소모를 최소화합니다.'
                          : 'FCM은 Google 서버를 통해 효율적으로 알림을 전달하여 배터리 소모를 최소화합니다.',
                      style: const TextStyle(fontSize: 11, height: 1.5),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('닫기'),
          ),
          if (isIOS)
            ElevatedButton.icon(
              onPressed: () async {
                Navigator.pop(context);
                await openAppSettings();
              },
              icon: const Icon(Icons.settings, size: 18),
              label: const Text('iOS 설정 열기'),
            ),
        ],
      ),
    );
  }

  /// 📱 통합 알림 설정 다이얼로그 (UI/UX 최적화)
  void _showNotificationSettingsDialog(BuildContext context) {
    final authService = context.read<AuthService>();
    final userId = authService.currentUser?.uid;
    final fcmService = FCMService();
    final isDark = Theme.of(context).brightness == Brightness.dark;
    
    if (userId == null) {
      DialogUtils.showError(context, '사용자 정보를 찾을 수 없습니다.');
      return;
    }

    showDialog(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setDialogState) {
          return AlertDialog(
            backgroundColor: isDark ? Colors.grey[900] : Colors.white,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(20),
            ),
            title: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: isDark 
                        ? Colors.blue[900]!.withValues(alpha: 0.5)
                        : Colors.blue[50],
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    Icons.notifications_active,
                    color: isDark ? Colors.blue[300] : const Color(0xFF2196F3),
                    size: 28,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    '앱 알림 설정',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w700,
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
                  // 📱 플랫폼 정보 배너
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: isDark
                          ? (kIsWeb 
                              ? [Colors.orange[900]!.withValues(alpha: 0.3), Colors.orange[800]!.withValues(alpha: 0.3)]
                              : [Colors.blue[900]!.withValues(alpha: 0.3), Colors.blue[800]!.withValues(alpha: 0.3)])
                          : (kIsWeb 
                              ? [Colors.orange[50]!, Colors.orange[100]!]
                              : [Colors.blue[50]!, Colors.blue[100]!]),
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: isDark
                          ? (kIsWeb ? Colors.orange[700]! : Colors.blue[700]!)
                          : (kIsWeb ? Colors.orange[200]! : Colors.blue[200]!),
                      ),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          kIsWeb 
                            ? Icons.web 
                            : (Platform.isIOS ? Icons.apple : Icons.android),
                          color: isDark
                            ? (kIsWeb ? Colors.orange[300] : Colors.blue[300])
                            : (kIsWeb ? Colors.orange[700] : Colors.blue[700]),
                          size: 24,
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                kIsWeb 
                                  ? '웹 브라우저'
                                  : (Platform.isIOS ? 'iOS 기기' : 'Android 기기'),
                                style: TextStyle(
                                  fontWeight: FontWeight.w700,
                                  fontSize: 14,
                                  color: isDark
                                    ? (kIsWeb ? Colors.orange[200] : Colors.blue[200])
                                    : (kIsWeb ? Colors.orange[900] : Colors.blue[900]),
                                ),
                              ),
                              Text(
                                kIsWeb 
                                  ? '브라우저 푸시 알림'
                                  : (Platform.isIOS ? 'APNs 푸시 알림' : 'FCM 푸시 알림'),
                                style: TextStyle(
                                  fontSize: 11,
                                  color: isDark
                                    ? (kIsWeb ? Colors.orange[400] : Colors.blue[400])
                                    : (kIsWeb ? Colors.orange[700] : Colors.blue[700]),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  
                  const SizedBox(height: 20),
                  
                  // 🔔 푸시 알림 ON/OFF
                  Container(
                    decoration: BoxDecoration(
                      color: _pushEnabled 
                          ? (isDark ? Colors.green[900]!.withValues(alpha: 0.3) : Colors.green[50])
                          : (isDark ? Colors.grey[850] : Colors.grey[100]),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: _pushEnabled 
                            ? (isDark ? Colors.green[700]! : Colors.green[200]!)
                            : (isDark ? Colors.grey[700]! : Colors.grey[300]!),
                        width: 2,
                      ),
                    ),
                    child: SwitchListTile(
                      value: _pushEnabled,
                      onChanged: (value) async {
                        setDialogState(() {
                          _pushEnabled = value;
                        });
                        setState(() {
                          _pushEnabled = value;
                        });
                        
                        try {
                          await fcmService.updateSingleSetting(userId, 'pushEnabled', value);
                          if (kDebugMode) {
                            debugPrint('✅ [알림설정] pushEnabled 업데이트: $value');
                          }
                        } catch (e) {
                          if (kDebugMode) {
                            debugPrint('❌ [알림설정] 업데이트 실패: $e');
                          }
                        }
                      },
                      title: Row(
                        children: [
                          Icon(
                            _pushEnabled ? Icons.notifications_active : Icons.notifications_off,
                            color: _pushEnabled 
                                ? (isDark ? Colors.green[300] : Colors.green[700])
                                : (isDark ? Colors.grey[500] : Colors.grey[600]),
                            size: 24,
                          ),
                          const SizedBox(width: 12),
                          Text(
                            '푸시 알림',
                            style: TextStyle(
                              fontWeight: FontWeight.w700,
                              fontSize: 16,
                              color: isDark ? Colors.grey[200] : Colors.black87,
                            ),
                          ),
                        ],
                      ),
                      subtitle: Padding(
                        padding: const EdgeInsets.only(left: 36, top: 4),
                        child: Text(
                          _pushEnabled 
                            ? '모든 푸시 알림을 받습니다'
                            : '푸시 알림을 받지 않습니다',
                          style: TextStyle(
                            fontSize: 12,
                            color: _pushEnabled 
                                ? (isDark ? Colors.green[400] : Colors.green[900])
                                : (isDark ? Colors.grey[500] : Colors.grey[600]),
                          ),
                        ),
                      ),
                      activeColor: isDark ? Colors.green[400] : Colors.green[600],
                    ),
                  ),
                  
                  const SizedBox(height: 16),
                  
                  // 🔊 알림음 & 진동 (푸시 알림이 켜져 있을 때만 활성화)
                  Opacity(
                    opacity: _pushEnabled ? 1.0 : 0.5,
                    child: AbsorbPointer(
                      absorbing: !_pushEnabled,
                      child: Container(
                        decoration: BoxDecoration(
                          color: isDark 
                              ? Colors.blue[900]!.withValues(alpha: 0.3)
                              : Colors.blue[50],
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: isDark ? Colors.blue[700]! : Colors.blue[200]!,
                          ),
                        ),
                        child: Column(
                          children: [
                            SwitchListTile(
                              value: _soundEnabled,
                              onChanged: _pushEnabled ? (value) async {
                                setDialogState(() {
                                  _soundEnabled = value;
                                });
                                setState(() {
                                  _soundEnabled = value;
                                });
                                
                                try {
                                  await fcmService.updateSingleSetting(userId, 'soundEnabled', value);
                                  if (kDebugMode) {
                                    debugPrint('✅ [알림설정] soundEnabled 업데이트: $value');
                                  }
                                } catch (e) {
                                  if (kDebugMode) {
                                    debugPrint('❌ [알림설정] 업데이트 실패: $e');
                                  }
                                }
                              } : null,
                              title: Row(
                                children: [
                                  Icon(
                                    _soundEnabled ? Icons.volume_up : Icons.volume_off,
                                    color: isDark ? Colors.blue[300] : Colors.blue[700],
                                    size: 20,
                                  ),
                                  const SizedBox(width: 12),
                                  Text(
                                    '알림음',
                                    style: TextStyle(
                                      fontWeight: FontWeight.w600,
                                      fontSize: 15,
                                      color: isDark ? Colors.grey[200] : Colors.black87,
                                    ),
                                  ),
                                ],
                              ),
                              subtitle: Padding(
                                padding: const EdgeInsets.only(left: 32, top: 2),
                                child: Text(
                                  '알림 수신 시 소리 재생',
                                  style: TextStyle(
                                    fontSize: 11,
                                    color: isDark ? Colors.grey[400] : Colors.black54,
                                  ),
                                ),
                              ),
                              activeColor: isDark ? Colors.blue[400] : Colors.blue[600],
                            ),
                            Divider(
                              height: 1, 
                              indent: 16, 
                              endIndent: 16,
                              color: isDark ? Colors.grey[700] : Colors.grey[300],
                            ),
                            SwitchListTile(
                              value: _vibrationEnabled,
                              onChanged: _pushEnabled ? (value) async {
                                setDialogState(() {
                                  _vibrationEnabled = value;
                                });
                                setState(() {
                                  _vibrationEnabled = value;
                                });
                                
                                try {
                                  await fcmService.updateSingleSetting(userId, 'vibrationEnabled', value);
                                  if (kDebugMode) {
                                    debugPrint('✅ [알림설정] vibrationEnabled 업데이트: $value');
                                  }
                                } catch (e) {
                                  if (kDebugMode) {
                                    debugPrint('❌ [알림설정] 업데이트 실패: $e');
                                  }
                                }
                              } : null,
                              title: Row(
                                children: [
                                  Icon(
                                    _vibrationEnabled ? Icons.vibration : Icons.mobile_off,
                                    color: isDark ? Colors.blue[300] : Colors.blue[700],
                                    size: 20,
                                  ),
                                  const SizedBox(width: 12),
                                  Text(
                                    '진동',
                                    style: TextStyle(
                                      fontWeight: FontWeight.w600,
                                      fontSize: 15,
                                      color: isDark ? Colors.grey[200] : Colors.black87,
                                    ),
                                  ),
                                ],
                              ),
                              subtitle: Padding(
                                padding: const EdgeInsets.only(left: 32, top: 2),
                                child: Text(
                                  '알림 수신 시 진동',
                                  style: TextStyle(
                                    fontSize: 11,
                                    color: isDark ? Colors.grey[400] : Colors.black54,
                                  ),
                                ),
                              ),
                              activeColor: isDark ? Colors.blue[400] : Colors.blue[600],
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                  
                  const SizedBox(height: 20),
                  
                  // 💡 시스템 설정 안내 (웹이 아닐 때만)
                  if (!kIsWeb)
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: isDark 
                            ? Colors.amber[900]!.withValues(alpha: 0.3)
                            : Colors.amber[50],
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                          color: isDark ? Colors.amber[700]! : Colors.amber[200]!,
                        ),
                      ),
                      child: Row(
                        children: [
                          Icon(
                            Icons.info_outline, 
                            color: isDark ? Colors.amber[300] : Colors.amber[800], 
                            size: 20,
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              Platform.isIOS
                                ? '시스템 푸시 권한은\niOS 설정에서 관리됩니다'
                                : '시스템 푸시 권한은\nAndroid 설정에서 관리됩니다',
                              style: TextStyle(
                                fontSize: 11,
                                color: isDark ? Colors.amber[200] : Colors.amber[900],
                                height: 1.4,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                ],
              ),
            ),
            actions: [
              if (!kIsWeb)
                TextButton.icon(
                  onPressed: () async {
                    await openAppSettings();
                  },
                  icon: Icon(
                    Icons.settings, 
                    size: 18,
                    color: isDark ? Colors.blue[300] : Colors.blue[700],
                  ),
                  label: Text(
                    Platform.isIOS ? 'iOS 설정' : 'Android 설정',
                    style: TextStyle(
                      color: isDark ? Colors.blue[300] : Colors.blue[700],
                    ),
                  ),
                  style: TextButton.styleFrom(
                    foregroundColor: isDark ? Colors.blue[300] : Colors.blue[700],
                  ),
                ),
              const SizedBox(width: 8),
              ElevatedButton(
                onPressed: () {
                  Navigator.pop(context);
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: isDark 
                      ? Colors.blue[700]
                      : const Color(0xFF2196F3),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
                child: const Text(
                  '완료',
                  style: TextStyle(fontWeight: FontWeight.w600),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}
