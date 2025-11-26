import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:provider/provider.dart';
import '../services/auth_service.dart';
import '../services/extension_management_service.dart';
import '../services/account_manager_service.dart';
import 'profile_drawer/profile_header_section.dart';  // 👤 프로필 헤더 섹션
import 'profile_drawer/notification_settings_section.dart';  // 📱 알림 설정 섹션
import 'profile_drawer/extension_management_section.dart';  // 📱 단말번호 관리 섹션
import 'profile_drawer/dcmiws_settings_section.dart';  // 📡 DCMIWS 설정 섹션
import 'profile_drawer/terms_and_policies_section.dart';  // 📜 약관 및 정책 섹션
import 'profile_drawer/general_settings_section.dart';  // 🎯 일반 설정 섹션
import 'profile_drawer/app_info_section.dart';  // 📱 앱 정보 섹션
import 'profile_drawer/service_suspension_section.dart';  // 🛑 서비스 이용 중지 섹션

class ProfileDrawer extends StatefulWidget {
  const ProfileDrawer({super.key});

  @override
  State<ProfileDrawer> createState() => _ProfileDrawerState();
}

class _ProfileDrawerState extends State<ProfileDrawer> {
  bool _keepLoginEnabled = true; // 자동 로그인 기본값: true
  final _phoneNumberController = TextEditingController();
  
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
    
    if (context.mounted) {
      setState(() {
        _keepLoginEnabled = enabled;
      });
      
      if (kDebugMode) {
        debugPrint('📱 Auto Login UI updated: $_keepLoginEnabled');
      }
    }
  }



  // DCMIWS 착신전화 수신 설정 불러오기
  @override
  void dispose() {
    _phoneNumberController.dispose();
    super.dispose();
  }

  // ✅ 리팩토링: ExtensionManagementService 사용
  // 등록된 단말번호 정보 업데이트
  Future<void> _updateSavedExtensions() async {
    final authService = context.read<AuthService>();
    final extensionService = ExtensionManagementService(authService);
    await extensionService.updateSavedExtensions();
  }

  @override
  Widget build(BuildContext context) {
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
            // 👤 프로필 헤더 섹션 (리팩토링: 별도 위젯으로 분리)
            const ProfileHeaderSection(),
            
            // 🎯 일반 설정 섹션 (리팩토링: 별도 위젯으로 분리)
            const GeneralSettingsSection(),
          
            // 🎯 단말번호 관리 섹션 (리팩토링: 별도 위젯으로 분리)
            const ExtensionManagementSection(),
          
          // 📱 알림 설정 섹션 (리팩토링: 별도 위젯으로 분리)
          const NotificationSettingsSection(),

          
          // 📡 DCMIWS 설정 섹션 (리팩토링: 별도 위젯으로 분리)
          // Premium 전용 기능
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
            const DcmiwsSettingsSection(),
          ],
          
          // 📜 약관 및 정책 섹션 (리팩토링: 별도 위젯으로 분리)
          const TermsAndPoliciesSection(),
          
          // 📱 앱 정보 섹션 (리팩토링: 별도 위젯으로 분리)
          const AppInfoSection(),
          
          // 🛑 서비스 이용 중지 섹션
          const ServiceSuspensionSection(),

          
          const SizedBox(height: 24),
          
          // 하단 여백
          const SizedBox(height: 16),
        ],
      ),
    ),
    );
  }
  
  // 스위치 타일 빌더 (가독성 향상)
}
