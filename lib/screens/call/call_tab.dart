import 'dart:async';
import 'dart:io';
import '../../utils/dialog_utils.dart';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../services/auth_service.dart';
import '../../services/database_service.dart';
import '../../services/mobile_contacts_service.dart';
import '../../services/api_service.dart';
import '../../services/dcmiws_service.dart';
import '../../services/announcement_service.dart';
import '../../models/contact_model.dart';
import '../../models/call_history_model.dart';
import '../../models/phonebook_model.dart';
import '../../providers/selected_extension_provider.dart';
import 'dialpad_screen.dart';
import 'phonebook_tab.dart';

import '../../widgets/add_contact_dialog.dart';
import '../../widgets/call_detail_dialog.dart';
import '../../widgets/profile_drawer.dart';
import '../../widgets/extension_drawer.dart';
import '../../widgets/safe_circle_avatar.dart';
import '../../widgets/social_login_progress_overlay.dart';
import '../../widgets/announcement_bottom_sheet.dart';
import '../../theme/call_theme_extension.dart';
import 'call_tab/widgets/extension_info_widget.dart';
import 'services/settings_checker.dart';
import 'services/extension_initializer.dart';
import 'services/permission_handler.dart';
import 'services/contact_manager.dart';
import 'services/call_manager.dart';

class CallTab extends StatefulWidget {
  final bool autoOpenProfileForNewUser; // 신규 사용자 자동 ProfileDrawer 열기
  final int? initialTabIndex; // 초기 탭 인덱스 (FCM에서 지정 가능)
  final bool showWelcomeDialog; // 회원가입 완료 다이얼로그 표시 여부 (이벤트 기반)
  
  const CallTab({
    super.key,
    this.autoOpenProfileForNewUser = false,
    this.initialTabIndex,
    this.showWelcomeDialog = false, // 기본값: false
  });

  @override
  State<CallTab> createState() => _CallTabState();
}

class _CallTabState extends State<CallTab> {
  late int _currentTabIndex; // 현재 선택된 탭 인덱스
  final DatabaseService _databaseService = DatabaseService();
  final MobileContactsService _mobileContactsService = MobileContactsService();
  final TextEditingController _searchController = TextEditingController();
  final TextEditingController _favoritesSearchController = TextEditingController();
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();
  
  // 📞 최근통화 필터 상태
  String _callHistoryFilter = 'all'; // all, outgoing, incoming, incoming_confirmed, incoming_missed
  
  // ⭐ 즐겨찾기 검색 상태
  String _favoritesSearchQuery = ''; // 즐겨찾기 검색어
  Timer? _searchDebounceTimer; // 검색 디바운스 타이머
  
  // 🔧 RegExp 캐싱 (성능 최적화)
  static final _numericRegExp = RegExp(r'[^0-9]');
  
  // 🔔 배지/알림 제거 플러그인
  final FlutterLocalNotificationsPlugin _notificationsPlugin = FlutterLocalNotificationsPlugin();
  
  // Note: Device contacts state는 ContactManager에서 관리됨
  // Note: _hasCheckedNewUser는 ExtensionInitializer에서 관리됨
  
  // 🎯 이벤트 기반 플래그: 이메일 회원가입 이벤트 처리 완료 여부
  // 타이밍에 의존하지 않고 이벤트 발생 시 한 번만 처리하도록 보장
  bool _hasProcessedEmailSignupEvent = false;
  
  // 🔒 고급 개발자 패턴: AuthService 참조를 안전하게 저장
  // dispose()에서 context 사용을 피하기 위한 전략
  AuthService? _authService;
  
  // 설정 체크 서비스
  late SettingsChecker _settingsChecker;
  
  // 단말번호 초기화 서비스
  late ExtensionInitializer _extensionInitializer;
  
  // 권한 처리 서비스
  late PermissionHandler _permissionHandler;
  
  // 연락처 관리 서비스
  ContactManager? _contactManager;
  
  // 통화 관리 서비스
  CallManager? _callManager;
  
  // 🔔 DCMIWS 이벤트 구독
  StreamSubscription? _dcmiwsEventSubscription;

  // 영어 이름을 한글로 번역하는 매핑 테이블 (Feature Codes 이름 번역용)
  final Map<String, String> _nameTranslations = {
    'Echo Test': '에코테스트',
    'Call Forward Immediately - Toggle': '즉시 착신 전환 토글',
    'Set CF Immediately Number': '즉시 착신 전환 번호 설정',
  };

  @override
  void initState() {
    super.initState();
    
    // 🔄 CRITICAL: 소셜 로그인 오버레이 강제 제거 (화면 전환 안전장치)
    // 로그인 성공 후 화면 전환 시 오버레이가 남아있을 수 있으므로 강제 제거
    WidgetsBinding.instance.addPostFrameCallback((_) {
      try {
        // dynamic import to avoid direct dependency
        SocialLoginProgressHelper.forceHide();
      } catch (e) {
        // Ignore if helper is not available
      }
    });
    
    // ✅ FCM에서 지정한 탭 인덱스 또는 기본값 (키패드) 사용
    _currentTabIndex = widget.initialTabIndex ?? 2; // 기본값: 2 (키패드)
    
    // 🚀 고급 개발자 패턴: 순차적 초기화 체인
    // 1️⃣ 설정 확인 먼저 → 2️⃣ 설정 완료 시에만 단말번호 조회
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (!mounted) return;
      
      // 🔒 AuthService 참조를 안전하게 저장 (dispose에서 사용)
      _authService = context.read<AuthService>();
      
      // SettingsChecker 초기화
      _settingsChecker = SettingsChecker(
        authService: _authService!,
        databaseService: _databaseService,
        scaffoldKey: _scaffoldKey,
      );
      
      // Note: 플래그 리셋은 _initializeSequentially()에서 수행됨
      
      // ExtensionInitializer 초기화
      _extensionInitializer = ExtensionInitializer(
        authService: _authService!,
        databaseService: _databaseService,
        scaffoldKey: _scaffoldKey,
      );
      
      // PermissionHandler 초기화
      _permissionHandler = PermissionHandler(
        mobileContactsService: _mobileContactsService,
      );
      
      // ContactManager 초기화
      _contactManager = ContactManager(
        databaseService: _databaseService,
        mobileContactsService: _mobileContactsService,
        permissionHandler: _permissionHandler,
        onStateChanged: () => setState(() {}),
      );
      
      // CallManager 초기화
      _callManager = CallManager(
        databaseService: _databaseService,
        onTabChanged: (index) {
          setState(() {
            _currentTabIndex = index;
          });
        },
      );
      
      // 로그아웃 상태 체크
      if (_authService?.currentUser == null || !(_authService?.isAuthenticated ?? false)) {
        return;
      }
      
      // 🔒 CRITICAL: 이메일 회원가입 시 리스너 등록 지연 (MainScreen 렌더링 완료 후)
      // 이렇게 하면 모든 다이얼로그가 MainScreen context에서만 표시됨
      if (widget.showWelcomeDialog) {
        // 이메일 회원가입: addPostFrameCallback에서 리스너 등록 (다이얼로그 표시 후)
        if (kDebugMode) {
          debugPrint('⏱️ [INIT] 이메일 회원가입 - AuthService 리스너 등록 지연 (다이얼로그 표시 후)');
        }
      } else {
        // 일반 로그인/소셜 로그인: 즉시 리스너 등록
        _authService?.addListener(_onAuthServiceStateChanged);
        if (kDebugMode) {
          debugPrint('✅ [INIT] AuthService 리스너 등록 완료 (즉시)');
        }
      }
      
      // 🔔 DCMIWS 이벤트 스트림 구독 (IncomingCallScreen 결과 처리)
      _dcmiwsEventSubscription = DCMIWSService().events.listen((event) {
        if (!mounted) return;
        
        if (event['type'] == 'MOVE_TO_TAB') {
          final tabIndex = event['tabIndex'] as int?;
          
          if (tabIndex != null && kDebugMode) {
            debugPrint('');
            debugPrint('🔔 DCMIWS 이벤트 수신: MOVE_TO_TAB');
            debugPrint('  → 탭 이동: $tabIndex');
          }
          
          if (tabIndex != null) {
            setState(() {
              _currentTabIndex = tabIndex;
            });
            
            if (kDebugMode) {
              debugPrint('  ✅ 탭 이동 완료: $_currentTabIndex');
              debugPrint('');
            }
          }
        }
      });
      
      // 순차적 초기화 실행 (ExtensionInitializer 포함)
      await _initializeSequentially();
    });
  }
  
  /// 🔄 순차적 초기화 체인
  /// 고급 패턴: Early Return + Fail-Fast + Single Responsibility + Event-Based
  Future<void> _initializeSequentially() async {
    if (!mounted) return;
    
    // 🔄 CRITICAL: 매 로그인마다 설정 체크 플래그 리셋
    // initState에서 호출되는 것만으로는 부족 (위젯이 재생성되지 않을 수 있음)
    // 로그인 플로우가 시작될 때마다 명시적으로 리셋
    _settingsChecker.resetFlags();
    
    if (kDebugMode) {
      debugPrint('🔄 [CALL_TAB] _initializeSequentially 시작 - 플래그 리셋 완료');
    }
    
    // 🎯 STEP 1: 회원가입 완료 다이얼로그 표시 (이벤트 기반)
    // MainScreen 전환 후 렌더링 완료 시점에만 실행
    if (widget.showWelcomeDialog && mounted) {
      await DialogUtils.showSuccess(
        context,
        '🎉 회원가입이 완료되었습니다',
      );
      
      // 🔒 CRITICAL: 이메일 회원가입 다이얼로그 표시 완료 후 AuthService 리스너 등록
      // 이제부터 발생하는 모든 이벤트는 MainScreen context에서 처리됨
      if (_authService != null && !_authService!.hasListeners) {
        _authService?.addListener(_onAuthServiceStateChanged);
        if (kDebugMode) {
          debugPrint('✅ [CALL_TAB] AuthService 리스너 등록 완료 (다이얼로그 표시 후)');
        }
      }
    }
    
    if (!mounted) return;
    
    // 🎯 STEP 2: 공지사항 확인 및 표시 (모든 로그인 타입)
    await _checkAndShowAnnouncement();
    
    if (!mounted) return;
    
    // 🎯 STEP 3: 설정 체크 및 단말번호 등록 안내 (공지사항 이후)
    if (kDebugMode) {
      debugPrint('🔍 [CALL_TAB] 공지사항 처리 완료 - 설정 체크 시작');
    }
    
    // 🔥 CRITICAL: 설정 체크 및 '초기 등록 필요' 다이얼로그 표시
    await _checkSettingsAndShowGuide();
    
    // 🔒 이메일 회원가입 이벤트 처리 완료 플래그 설정
    if (widget.showWelcomeDialog) {
      _hasProcessedEmailSignupEvent = true;
    }
    
    if (!mounted) return;
    
    // 🎯 STEP 4: 신규 사용자 체크 및 ProfileDrawer 자동 열기 (ExtensionInitializer 사용)
    // 일반 로그인/소셜 로그인 시에만 실행
    if (widget.autoOpenProfileForNewUser && !widget.showWelcomeDialog) {
      await _extensionInitializer.checkAndOpenProfileDrawerForNewUser(
        context,
        () => _hasCheckedSettings,
        (value) => _hasCheckedSettings = value,
      );
    }
    
    if (!mounted) return;
    
    // 🎯 STEP 5: 단말번호 자동 초기화 (ExtensionInitializer 사용)
    // 클릭투콜 기능을 위해 로그인 즉시 단말번호 설정
    await _extensionInitializer.initializeExtensions(context);
  }
  
  /// 📢 공지사항 확인 및 표시
  Future<void> _checkAndShowAnnouncement() async {
    try {
      final announcementService = AnnouncementService();
      final announcement = await announcementService.getActiveAnnouncement();
      
      if (announcement == null) {
        if (kDebugMode) {
          debugPrint('📢 [ANNOUNCEMENT] 활성 공지사항 없음');
        }
        return;
      }
      
      // "다시 보지 않기" 체크 확인
      final prefs = await SharedPreferences.getInstance();
      final key = 'announcement_hidden_${announcement.id}';
      final isHidden = prefs.getBool(key) ?? false;
      
      if (isHidden) {
        if (kDebugMode) {
          debugPrint('📢 [ANNOUNCEMENT] 사용자가 "다시 보지 않기"를 선택한 공지: ${announcement.id}');
        }
        return;
      }
      
      if (kDebugMode) {
        debugPrint('📢 [ANNOUNCEMENT] 공지사항 표시');
        debugPrint('   ID: ${announcement.id}');
        debugPrint('   Title: ${announcement.title}');
      }
      
      // 공지사항 BottomSheet 표시
      if (mounted) {
        if (kDebugMode) {
          debugPrint('🔥 [ANNOUNCEMENT] showModalBottomSheet() 호출 시작');
        }
        
        // 🔥 EVENT-BASED: showModalBottomSheet()는 BottomSheet가 닫힐 때 Future 완료
        // Navigator.pop() 호출 시 자동으로 await가 완료되어 다음 단계 진행
        await AnnouncementBottomSheet.show(context, announcement);
        
        if (kDebugMode) {
          debugPrint('✅ [ANNOUNCEMENT] showModalBottomSheet() 완료 (사용자가 닫음)');
        }
        
        // 🎯 FRAME-BASED: 다음 프레임까지 대기 (애니메이션 완료 보장)
        if (mounted) {
          await WidgetsBinding.instance.endOfFrame;
          
          if (kDebugMode) {
            debugPrint('✅ [ANNOUNCEMENT] 공지사항 닫힘 + 애니메이션 완료 - 다음 단계 진행');
          }
        }
      } else {
        if (kDebugMode) {
          debugPrint('⚠️ [ANNOUNCEMENT] Widget이 mounted 상태가 아님 - 공지사항 표시 건너뛰기');
        }
      }
    } catch (e) {
      if (kDebugMode) {
        debugPrint('❌ [ANNOUNCEMENT] Error: $e');
      }
      // 에러 발생해도 다음 단계 진행
    }
  }
  
  @override
  void dispose() {
    // 🔒 고급 개발자 패턴: 저장된 참조를 사용하여 안전하게 리스너 제거
    // context.read()를 사용하지 않음 → deactivated widget 에러 방지
    _authService?.removeListener(_onAuthServiceStateChanged);
    _authService = null; // 메모리 누수 방지
    
    // 🔔 DCMIWS 이벤트 구독 취소
    _dcmiwsEventSubscription?.cancel();
    _dcmiwsEventSubscription = null;
    
    _searchController.dispose();
    _favoritesSearchController.dispose();
    _searchDebounceTimer?.cancel(); // 검색 디바운스 타이머 정리
    super.dispose();
  }
  
  // 🔔 최근통화 탭 진입 시 배지/알림 제거
  Future<void> _clearBadgeOnCallHistoryTab() async {
    // Web은 배지 미지원
    if (kIsWeb) return;
    
    try {
      // Android: 알림 제거 시 배지도 자동 제거
      await _notificationsPlugin.cancelAll();
      
      // iOS: 배지를 명시적으로 0으로 설정
      if (Platform.isIOS) {
        // 🔥 CRITICAL FIX: 배지를 명시적으로 0으로 설정
        await _notificationsPlugin.show(
          0, // notification ID
          null, // no title
          null, // no body
          const NotificationDetails(
            iOS: DarwinNotificationDetails(
              presentAlert: false,
              presentBadge: true,
              presentSound: false,
              badgeNumber: 0, // ← 배지를 0으로 명시적 설정
            ),
          ),
        );
        
        // 바로 알림 제거 (배지만 설정하고 알림은 표시 안 함)
        await _notificationsPlugin.cancel(0);
      }
      
      if (kDebugMode) {
        debugPrint('✅ [CallTab] 최근통화 탭 진입 - ${Platform.isAndroid ? 'Android' : 'iOS'} 배지/알림 제거 완료 (배지: 0)');
      }
    } catch (e) {
      if (kDebugMode) {
        debugPrint('❌ [CallTab] 배지 제거 실패: $e');
      }
    }
  }
  
  // 🔔 AuthService 상태 변경 감지 콜백 (완전한 이벤트 기반 패턴)
  // - FCM 초기화 완료 감지
  // - 승인 대기 상태 변경 감지
  // - 소셜 로그인 성공 메시지 완료 감지 (NEW)
  void _onAuthServiceStateChanged() {
    if (kDebugMode) {
      debugPrint('🔔 AuthService 리스너 트리거: 상태 변경 감지');
    }
    
    if (!mounted) return;
    if (_authService?.currentUser == null || !(_authService?.isAuthenticated ?? false)) {
      return;
    }
    
    // 🔒 CRITICAL: 이메일 회원가입 이벤트 처리 중이면 다른 모든 이벤트 무시 (Race Condition 완전 차단)
    if (_hasProcessedEmailSignupEvent && (_authService?.isInEmailSignupFlow ?? false)) {
      if (kDebugMode) {
        debugPrint('⏭️ [리스너] 이메일 회원가입 이벤트 처리 중 - 다른 이벤트 무시');
      }
      return;
    }
    
    // 1️⃣ FCM 초기화 완료 이벤트 감지
    // ⚠️ 이메일 회원가입 중이면 FCM 이벤트 무시 (중복 방지)
    if ((_authService?.isFcmInitialized ?? false) && !_extensionInitializer.hasCheckedNewUser && widget.autoOpenProfileForNewUser) {
      // 이메일 회원가입 플래그 또는 이벤트 처리 플래그가 있으면 FCM 이벤트 무시
      if ((_authService?.isInEmailSignupFlow ?? false) || _hasProcessedEmailSignupEvent) {
        if (kDebugMode) {
          debugPrint('🛑 [FCM-이벤트] 이메일 회원가입 중 또는 이벤트 처리 완료 - FCM 이벤트 무시');
        }
        return;
      }
      
      if (kDebugMode) {
        debugPrint('🚀 [이벤트] FCM 초기화 완료 감지됨 → 신규 사용자 체크 재실행');
      }
      
      Future.microtask(() {
        if (mounted) {
          _extensionInitializer.checkAndOpenProfileDrawerForNewUser(
            context,
            () => _hasCheckedSettings,
            (value) => _hasCheckedSettings = value,
          );
        }
      });
      return;
    }
    
    // 2️⃣ 승인 대기 상태 감지
    if ((_authService?.isWaitingForApproval ?? false) || _authService?.approvalRequestId != null) {
      if (kDebugMode) {
        debugPrint('🔔 [이벤트] 기기 승인 대기 상태 감지됨 → ProfileDrawer 자동 열기 취소');
      }
      _extensionInitializer.hasCheckedNewUser = true;
      return;
    }
    
    // 3️⃣ 이메일 회원가입 이벤트 처리는 CallTab initState에서 처리
    // (MainScreen 전환 후 addPostFrameCallback으로 다이얼로그 표시)
    // 여기서는 플래그만 체크하고 넘어감
    if ((_authService?.isInEmailSignupFlow ?? false) && !_hasProcessedEmailSignupEvent) {
      _hasProcessedEmailSignupEvent = true;
      _authService?.setInEmailSignupFlow(false);
      _hasCheckedSettings = true; // CallTab 로컬 플래그
      _settingsChecker.hasCheckedSettings = true; // 🔒 CRITICAL: SettingsChecker 플래그도 설정 (소셜 로그인 로직 실행 방지)
      if (kDebugMode) {
        debugPrint('✅ [리스너] 이메일 회원가입 이벤트 감지 → 플래그 설정 (initState가 다이얼로그 처리)');
      }
      return;  // 이벤트 플래그만 해제하고 리턴
    }
    
    // 4️⃣ 소셜 로그인 플래그 해제 이벤트 감지 (사용자가 "로그인/닫기" 버튼 클릭)
    // ⚠️ 이메일 회원가입 이벤트보다 낮은 우선순위 (이메일 회원가입이 먼저 처리됨)
    // 🚫 MaxDeviceLimit 차단 중에는 설정 체크 건너뛰기
    if (!(_authService?.isInSocialLoginFlow ?? true) && 
        !(_authService?.isBlockedByMaxDeviceLimit ?? false) &&  // ← MaxDeviceLimit 체크 추가
        !_hasCheckedSettings && 
        !_hasProcessedEmailSignupEvent) {  // 🔒 이메일 회원가입 이벤트 처리 완료 체크
      if (kDebugMode) {
        debugPrint('🔔 [이벤트] 소셜 로그인 완료 감지 → 설정 체크 실행');
      }
      
      // 설정 체크 실행 (API 설정 및 단말번호)
      Future.microtask(() async {
        if (mounted && !_hasProcessedEmailSignupEvent) {  // 🔒 한 번 더 체크 (Race Condition 방지)
          await _checkSettingsAndShowGuide();
        }
      });
    }
  }

  
  /// 🔍 설정 확인 및 안내 (선택적 실행)
  /// 
  /// **기능**: API/WebSocket 설정 및 단말번호 등록 상태 확인
  /// - 최초 1회만 실행 (중복 팝업 방지)
  /// - 설정 미완료 시 안내 다이얼로그 표시
  /// 
  /// **최적화**:
  /// - Idempotent: _hasCheckedSettings 플래그로 중복 실행 방지
  /// - Lazy Loading: userModel 로드 전에는 실행하지 않음
  Future<void> _checkSettingsAndShowGuide() async {
    await _settingsChecker.checkAndShowGuide(context);
  }

  /// 설정 체크 완료 여부 getter/setter (SettingsChecker 위임)
  bool get _hasCheckedSettings => _settingsChecker.hasCheckedSettings;
  set _hasCheckedSettings(bool value) => _settingsChecker.hasCheckedSettings = value;



  @override
  Widget build(BuildContext context) {
    final authService = context.watch<AuthService>();
    final isDark = Theme.of(context).brightness == Brightness.dark;
    
    return Scaffold(
      key: _scaffoldKey,
      appBar: AppBar(
        elevation: 0,
        backgroundColor: isDark ? Theme.of(context).scaffoldBackgroundColor : Colors.white,
        surfaceTintColor: isDark ? Theme.of(context).scaffoldBackgroundColor : Colors.white,
        shadowColor: Colors.black.withValues(alpha: isDark ? 0.3 : 0.1),
        leading: Builder(
          builder: (context) => Padding(
            padding: const EdgeInsets.all(8.0),
            child: InkWell(
              borderRadius: BorderRadius.circular(25),
              onTap: () {
                Scaffold.of(context).openDrawer();
              },
              child: Container(
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFF2196F3).withValues(alpha: 0.2),
                      blurRadius: 8,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: SafeCircleAvatar(
                  radius: 20,
                  backgroundColor: isDark ? Colors.grey[850] : Colors.white,
                  imageUrl: authService.currentUserModel?.profileImageUrl,
                ),
              ),
            ),
          ),
        ),
        title: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFF2196F3), Color(0xFF1976D2)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(20),
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFF2196F3).withValues(alpha: 0.3),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: const Text(
                'MAKECALL',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                  letterSpacing: 0.5,
                ),
              ),
            ),
          ],
        ),
        centerTitle: true,
        actions: [
          Builder(
            builder: (context) => Padding(
              padding: const EdgeInsets.all(8.0),
              child: InkWell(
                borderRadius: BorderRadius.circular(25),
                onTap: () {
                  Scaffold.of(context).openEndDrawer();
                },
                child: Container(
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: const LinearGradient(
                      colors: [Color(0xFF2196F3), Color(0xFF1976D2)],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: const Color(0xFF2196F3).withValues(alpha: 0.3),
                        blurRadius: 8,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: const CircleAvatar(
                    radius: 20,
                    backgroundColor: Colors.transparent,
                    child: Icon(
                      Icons.phone_in_talk_rounded,
                      size: 22,
                      color: Colors.white,
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
      drawer: const ProfileDrawer(),
      endDrawer: const ExtensionDrawer(),
      body: IndexedStack(
        index: _currentTabIndex,
        children: [
          PhonebookTab(                // 0: 단말번호
            onClickToCallSuccess: (bool isGridView) {
              if (mounted) {
                // 그리드뷰 모드일 때는 탭 전환하지 않음
                if (!isGridView) {
                  setState(() {
                    _currentTabIndex = 1; // 최근통화 탭
                  });
                  if (kDebugMode) {
                    debugPrint('✅ 단말번호 클릭투콜 성공 (리스트뷰) → 최근통화 탭으로 전환');
                  }
                } else {
                  if (kDebugMode) {
                    debugPrint('✅ 단말번호 클릭투콜 성공 (그리드뷰) → 단말번호 탭 유지');
                  }
                }
              }
            },
          ),
          _buildCallHistoryTab(),      // 1: 최근통화
          DialpadScreen(               // 2: 키패드
            onClickToCallSuccess: () {
              if (mounted) {
                setState(() {
                  _currentTabIndex = 1; // 최근통화 탭
                });
                if (kDebugMode) {
                  debugPrint('✅ 키패드 클릭투콜 성공 → 최근통화 탭으로 전환');
                }
              }
            },
          ),
          _buildFavoritesTab(),        // 3: 즐겨찾기
          _buildContactsTab(),         // 4: 연락처
        ],
      ),
      bottomNavigationBar: Container(
        decoration: BoxDecoration(
          color: isDark ? Colors.grey[900] : Colors.white,
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: isDark ? 0.3 : 0.08),
              blurRadius: 12,
              offset: const Offset(0, -2),
            ),
          ],
        ),
        child: SafeArea(
          child: BottomNavigationBar(
            currentIndex: _currentTabIndex,
            onTap: (index) {
              setState(() {
                _currentTabIndex = index;
              });
              
              // 🔔 최근통화 탭(index 1) 진입 시 배지/알림 제거
              if (index == 1) {
                _clearBadgeOnCallHistoryTab();
              }
            },
            type: BottomNavigationBarType.fixed,
            backgroundColor: Colors.transparent,
            elevation: 0,
            selectedItemColor: const Color(0xFF2196F3),
            unselectedItemColor: isDark ? Colors.grey[500] : Colors.grey[600],
            selectedLabelStyle: const TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.bold,
              letterSpacing: 0.2,
            ),
            unselectedLabelStyle: const TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w500,
            ),
            selectedFontSize: 11,
            unselectedFontSize: 10,
            items: const [
              BottomNavigationBarItem(
                icon: Padding(
                  padding: EdgeInsets.only(bottom: 4),
                  child: Icon(Icons.phone_android_rounded, size: 26),
                ),
                activeIcon: Padding(
                  padding: EdgeInsets.only(bottom: 4),
                  child: Icon(Icons.phone_android_rounded, size: 28),
                ),
                label: '단말번호',
              ),
              BottomNavigationBarItem(
                icon: Padding(
                  padding: EdgeInsets.only(bottom: 4),
                  child: Icon(Icons.history_rounded, size: 26),
                ),
                activeIcon: Padding(
                  padding: EdgeInsets.only(bottom: 4),
                  child: Icon(Icons.history_rounded, size: 28),
                ),
                label: '최근통화',
              ),
              BottomNavigationBarItem(
                icon: Padding(
                  padding: EdgeInsets.only(bottom: 4),
                  child: Icon(Icons.dialpad_rounded, size: 26),
                ),
                activeIcon: Padding(
                  padding: EdgeInsets.only(bottom: 4),
                  child: Icon(Icons.dialpad_rounded, size: 28),
                ),
                label: '키패드',
              ),
              BottomNavigationBarItem(
                icon: Padding(
                  padding: EdgeInsets.only(bottom: 4),
                  child: Icon(Icons.star_rounded, size: 26),
                ),
                activeIcon: Padding(
                  padding: EdgeInsets.only(bottom: 4),
                  child: Icon(Icons.star_rounded, size: 28),
                ),
                label: '즐겨찾기',
              ),
              BottomNavigationBarItem(
                icon: Padding(
                  padding: EdgeInsets.only(bottom: 4),
                  child: Icon(Icons.contacts_rounded, size: 26),
                ),
                activeIcon: Padding(
                  padding: EdgeInsets.only(bottom: 4),
                  child: Icon(Icons.contacts_rounded, size: 28),
                ),
                label: '연락처',
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildFavoritesTab() {
    final userId = context.watch<AuthService>().currentUser?.uid ?? '';
    final isDark = Theme.of(context).brightness == Brightness.dark;

    // 🔒 로그아웃 상태 체크
    if (userId.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.login, 
              size: 64, 
              color: isDark ? Colors.grey[600] : Colors.grey[400],
            ),
            const SizedBox(height: 16),
            Text(
              '로그인이 필요합니다',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: isDark ? Colors.grey[300] : Colors.grey[700],
              ),
            ),
          ],
        ),
      );
    }

    // 검색바를 최상위로 이동 (StreamBuilder 외부)
    return Column(
      children: [
        // 🔍 검색바
        _buildFavoritesSearchBar(isDark),
        
        // 연락처와 단말번호 즐겨찾기 목록
        Expanded(
          child: _buildFavoritesStreamContent(userId, isDark),
        ),
      ],
    );
  }

  // 🔍 즐겨찾기 검색바 위젯 (분리)
  Widget _buildFavoritesSearchBar(bool isDark) {
    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: TextField(
        controller: _favoritesSearchController,
        decoration: InputDecoration(
          hintText: '이름, 번호 검색...',
          prefixIcon: const Icon(Icons.search),
          suffixIcon: _favoritesSearchController.text.isNotEmpty
              ? IconButton(
                  icon: const Icon(Icons.clear),
                  onPressed: () {
                    _favoritesSearchController.clear();
                    setState(() {
                      _favoritesSearchQuery = '';
                    });
                  },
                )
              : null,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          filled: true,
          fillColor: isDark ? Colors.grey[850] : Colors.grey[50],
        ),
        onChanged: (value) {
          // 기존 타이머 취소
          _searchDebounceTimer?.cancel();
          
          // 300ms 후에 검색 실행 (빠른 타이핑 시 중간 글자 무시)
          _searchDebounceTimer = Timer(const Duration(milliseconds: 300), () {
            if (mounted) {
              setState(() {
                _favoritesSearchQuery = value;
              });
            }
          });
        },
      ),
    );
  }

  // 📋 즐겨찾기 스트림 컨텐츠 (분리)
  Widget _buildFavoritesStreamContent(String userId, bool isDark) {
    return StreamBuilder<List<ContactModel>>(
      stream: _databaseService.getFavoriteContacts(userId),
      builder: (context, contactSnapshot) {
        return StreamBuilder<List<PhonebookContactModel>>(
          stream: _databaseService.getFavoritePhonebookContacts(userId),
          builder: (context, phonebookSnapshot) {
            // 🔒 에러 처리
            if (contactSnapshot.hasError || phonebookSnapshot.hasError) {
              if (kDebugMode) {
                debugPrint('⚠️ [FAVORITES] Stream error ignored (likely logout)');
              }
              // 에러 시 빈 리스트로 처리
            }
            
            if (contactSnapshot.connectionState == ConnectionState.waiting ||
                phonebookSnapshot.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator());
            }

            final contactFavorites = contactSnapshot.data ?? [];
            final phonebookFavorites = phonebookSnapshot.data ?? [];
            
            // 🔍 검색 필터링 적용 (최적화: 쿼리 사전 처리)
            final query = _favoritesSearchQuery.toLowerCase();
            final numericQuery = query.replaceAll(_numericRegExp, '');
            final hasNumericQuery = numericQuery.isNotEmpty;
            
            final filteredContactFavorites = _favoritesSearchQuery.isEmpty
                ? contactFavorites
                : contactFavorites.where((contact) {
                    return contact.name.toLowerCase().contains(query) ||
                        (contact.company?.toLowerCase().contains(query) ?? false) ||
                        (contact.email?.toLowerCase().contains(query) ?? false) ||
                        (contact.notes?.toLowerCase().contains(query) ?? false) ||
                        (hasNumericQuery && contact.phoneNumber.replaceAll(_numericRegExp, '').contains(numericQuery));
                  }).toList();
            
            final filteredPhonebookFavorites = _favoritesSearchQuery.isEmpty
                ? phonebookFavorites
                : phonebookFavorites.where((contact) {
                    return contact.name.toLowerCase().contains(query) ||
                        (contact.company?.toLowerCase().contains(query) ?? false) ||
                        (contact.title?.toLowerCase().contains(query) ?? false) ||
                        (hasNumericQuery && contact.telephone.replaceAll(_numericRegExp, '').contains(numericQuery));
                  }).toList();
            
            final totalCount = filteredContactFavorites.length + filteredPhonebookFavorites.length;

            if (totalCount == 0 && _favoritesSearchQuery.isEmpty) {
              final isDark = Theme.of(context).brightness == Brightness.dark;
              return Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.star_border,
                      size: 80,
                      color: isDark ? Colors.grey[700] : Colors.grey[400],
                    ),
                    const SizedBox(height: 16),
                    Text(
                      '즐겨찾기가 없습니다',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w600,
                        color: isDark ? Colors.grey[400] : Colors.grey,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      '연락처나 단말번호에서 별 아이콘을 눌러\n즐겨찾기에 추가하세요',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 14,
                        color: isDark ? Colors.grey[500] : Colors.grey[600],
                      ),
                    ),
                  ],
                ),
              );
            }

            // 검색 결과 없음 표시
            if (totalCount == 0 && _favoritesSearchQuery.isNotEmpty) {
              return Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.search_off,
                      size: 80,
                      color: isDark ? Colors.grey[700] : Colors.grey[400],
                    ),
                    const SizedBox(height: 16),
                    Text(
                      '검색 결과가 없습니다',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w600,
                        color: isDark ? Colors.grey[400] : Colors.grey,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      '"$_favoritesSearchQuery"에 대한\n즐겨찾기를 찾을 수 없습니다',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 14,
                        color: isDark ? Colors.grey[500] : Colors.grey[600],
                      ),
                    ),
                  ],
                ),
              );
            }
            
            // 즐겨찾기 리스트
            return ListView(
                      children: [
                        // 단말번호 즐겨찾기 섹션
                        if (filteredPhonebookFavorites.isNotEmpty) ...[
                  Builder(
                    builder: (context) {
                      final isDark = Theme.of(context).brightness == Brightness.dark;
                      return Padding(
                        padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                        child: Row(
                          children: [
                            Icon(
                              Icons.phone_android,
                              size: 20,
                              color: isDark ? Colors.green[300] : Colors.green,
                            ),
                            const SizedBox(width: 8),
                            Text(
                              '단말번호 (${filteredPhonebookFavorites.length})',
                              style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w600,
                                color: isDark ? Colors.grey[400] : Colors.grey[700],
                              ),
                            ),
                          ],
                        ),
                      );
                    },
                  ),
                          ...filteredPhonebookFavorites.map((contact) => _buildPhonebookContactListTile(contact)),
                        ],
                        
                        // 연락처 즐겨찾기 섹션
                        if (filteredContactFavorites.isNotEmpty) ...[
                  Builder(
                    builder: (context) {
                      final isDark = Theme.of(context).brightness == Brightness.dark;
                      return Padding(
                        padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                        child: Row(
                          children: [
                            Icon(
                              Icons.contacts,
                              size: 20,
                              color: isDark ? Colors.blue[300] : Colors.blue,
                            ),
                            const SizedBox(width: 8),
                            Text(
                              '연락처 (${filteredContactFavorites.length})',
                              style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w600,
                                color: isDark ? Colors.grey[400] : Colors.grey[700],
                              ),
                            ),
                          ],
                        ),
                      );
                    },
                  ),
                          ...filteredContactFavorites.map((contact) => _buildContactListTile(contact)),
                        ],
                      ],
                    );
          },
        );
      },
    );
  }

  Widget _buildCallHistoryTab() {
    final userId = context.watch<AuthService>().currentUser?.uid ?? '';
    final isDark = Theme.of(context).brightness == Brightness.dark;

    // 🔒 로그아웃 상태 체크
    if (userId.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.login, 
              size: 64, 
              color: isDark ? Colors.grey[600] : Colors.grey[400],
            ),
            const SizedBox(height: 16),
            Text(
              '로그인이 필요합니다',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: isDark ? Colors.grey[300] : Colors.grey[700],
              ),
            ),
          ],
        ),
      );
    }

    return StreamBuilder<List<CallHistoryModel>>(
      stream: _databaseService.getUserCallHistory(userId),
      builder: (context, snapshot) {
        // 🔒 에러 처리: 권한 에러 시 빈 리스트 표시
        if (snapshot.hasError) {
          if (kDebugMode) {
            debugPrint('⚠️ [CALL-TAB] Stream error: ${snapshot.error}');
          }
          // 권한 에러는 로그아웃 상태이므로 빈 리스트 표시
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.history,
                  size: 80,
                  color: isDark ? Colors.grey[700] : Colors.grey[300],
                ),
                const SizedBox(height: 20),
                Text(
                  '통화 기록이 없습니다',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                    color: isDark ? Colors.grey[400] : Colors.grey,
                  ),
                ),
              ],
            ),
          );
        }
        
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        final allCallHistory = snapshot.data ?? [];
        
        // 📞 필터 적용
        final callHistory = allCallHistory.where((call) {
          switch (_callHistoryFilter) {
            case 'outgoing':
              return call.callType == CallType.outgoing;
            case 'incoming':
              return call.callType == CallType.incoming;
            case 'incoming_missed':
              return call.callType == CallType.incoming && call.status == 'missed';
            default:
              return true; // 'all'
          }
        }).toList();

        return Column(
          children: [
            // 🎯 필터 UI
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: isDark ? Colors.grey[900] : Colors.grey[50],
                border: Border(
                  bottom: BorderSide(
                    color: isDark ? Colors.grey[800]! : Colors.grey[200]!,
                    width: 1,
                  ),
                ),
              ),
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: [
                    _buildFilterChip('all', '전체', allCallHistory.length, isDark),
                    const SizedBox(width: 8),
                    _buildFilterChip('outgoing', '발신', 
                      allCallHistory.where((c) => c.callType == CallType.outgoing).length, isDark),
                    const SizedBox(width: 8),
                    _buildFilterChip('incoming', '수신', 
                      allCallHistory.where((c) => c.callType == CallType.incoming).length, isDark),
                    const SizedBox(width: 8),
                    _buildFilterChip('incoming_missed', '미확인', 
                      allCallHistory.where((c) => c.callType == CallType.incoming && c.status == 'missed').length, isDark),
                  ],
                ),
              ),
            ),
            
            // 📋 통화 기록 리스트
            if (callHistory.isEmpty)
              Expanded(
                child: Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.filter_list_off,
                        size: 80,
                        color: isDark ? Colors.grey[700] : Colors.grey[300],
                      ), 
                      const SizedBox(height: 20),
                      Text(
                        '필터 조건에 맞는 통화 기록이 없습니다',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w600,
                          color: isDark ? Colors.grey[400] : Colors.grey,
                        ),
                      ),
                    ],
                  ),
                ),
              )
            else
              Expanded(
                child: ListView.separated(
          padding: const EdgeInsets.symmetric(vertical: 8),
          itemCount: callHistory.length,
          separatorBuilder: (context, index) {
            final isDark = Theme.of(context).brightness == Brightness.dark;
            return Divider(
              height: 1,
              thickness: 0.5,
              color: isDark ? Colors.grey[800] : Colors.grey[200],
              indent: 76,
            );
          },
          itemBuilder: (context, index) {
            final call = callHistory[index];
            final isDark = Theme.of(context).brightness == Brightness.dark;
            final callTheme = CallThemeColors(context);
            final callTypeColor = _getCallTypeColor(call.callType, context);
            final callTypeIcon = _getCallTypeIcon(call.callType);
            
            return Container(
              margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: isDark ? Colors.grey[850] : Colors.white,
                borderRadius: BorderRadius.circular(12),
                boxShadow: [
                  BoxShadow(
                    color: isDark
                        ? Colors.black.withValues(alpha: 0.3)
                        : Colors.black.withValues(alpha: 0.03),
                    blurRadius: 4,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: InkWell(
                onTap: () => _showCallDetailDialog(call), // 통화 상세 다이얼로그
                borderRadius: BorderRadius.circular(12),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // 🎨 컬러풀한 아이콘 (원형 배경)
                      Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [
                        callTypeColor.withValues(alpha: 0.8),
                        callTypeColor,
                      ],
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: callTypeColor.withValues(alpha: 0.3),
                        blurRadius: 8,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: Icon(
                    callTypeIcon,
                    color: Colors.white,
                    size: 18,
                  ),
                ),
                const SizedBox(width: 12),
                // 📝 발신자 정보 및 상세 내용 (Expanded로 감싸서 가용 공간 최대 활용)
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // 이름 및 통화 시간 배지
                      Row(
                  children: [
                    Expanded(
                      child: Text(
                        call.contactName ?? call.phoneNumber,
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          // 🔴 미확인 수신 전화는 붉은색으로 강조
                          color: call.callType == CallType.incoming && call.status == 'missed'
                              ? const Color(0xFFE53935) // 붉은색 강조
                              : isDark ? Colors.grey[200] : const Color(0xFF1a1a1a),
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    // 통화 시간 배지
                    if (call.duration != null)
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: callTypeColor.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: callTypeColor.withValues(alpha: 0.3),
                            width: 1,
                          ),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              Icons.access_time,
                              size: 12,
                              color: callTypeColor,
                            ),
                            const SizedBox(width: 4),
                            Text(
                              call.formattedDuration,
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                                color: callTypeColor,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  // 📅 시간 및 단말번호 정보
                  const SizedBox(height: 6),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // 통화 시간
                      Row(
                        children: [
                          Icon(
                            Icons.schedule,
                            size: 14,
                            color: isDark ? Colors.grey[500] : Colors.grey[500],
                          ),
                          const SizedBox(width: 4),
                          Text(
                            _formatDateTime(call.callTime),
                            style: TextStyle(
                              fontSize: 12,
                              color: isDark ? Colors.grey[400] : Colors.grey[600],
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                      // 발신번호
                      Padding(
                        padding: const EdgeInsets.only(top: 4),
                        child: Row(
                          children: [
                            Icon(
                              Icons.phone,
                              size: 14,
                              color: isDark ? Colors.grey[500] : Colors.grey[500],
                            ),
                            const SizedBox(width: 4),
                            Text(
                              call.phoneNumber,
                              style: TextStyle(
                                fontSize: 12,
                                // 🔴 미확인 수신 전화는 전화번호도 붉은색으로 강조
                                color: call.callType == CallType.incoming && call.status == 'missed'
                                    ? const Color(0xFFE53935) // 붉은색 강조
                                    : isDark ? Colors.grey[400] : Colors.grey[700],
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                      ),
                      // 단말번호 정보 (클릭투콜 발신 통화만)
                      if (call.callType == CallType.outgoing && call.extensionUsed != null)
                        ExtensionInfoWidget(call: call),
                      // 수신번호 → 단말번호 배지 (착신 통화만)
                      if (call.callType == CallType.incoming && call.statusText.isNotEmpty)
                        Padding(
                          padding: const EdgeInsets.only(top: 4),
                          child: Row(
                            children: [
                              Expanded(
                                child: Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 8,
                                    vertical: 3,
                                  ),
                                  decoration: BoxDecoration(
                                    color: call.statusColor?.withValues(alpha: 0.15),
                                    borderRadius: BorderRadius.circular(10),
                                    border: Border.all(
                                      color: call.statusColor?.withValues(alpha: 0.5) ??
                                          CallThemeColors(context).fallbackBorderColor,
                                      width: 1,
                                    ),
                                  ),
                                  child: Row(
                                    children: [
                                      Icon(
                                        call.status == 'device_answered' 
                                          ? Icons.phone_in_talk_rounded 
                                          : Icons.notifications_active_rounded,
                                        size: 12,
                                        color: call.statusColor,
                                      ),
                                      const SizedBox(width: 4),
                                      // 수신번호 → 단말번호 형식으로 표시 (overflow 방지)
                                      Expanded(
                                        child: call.receiverNumber != null && call.receiverNumber!.isNotEmpty && call.extensionUsed != null
                                          ? Text(
                                              '${call.receiverNumber} → ${call.extensionUsed}',
                                              style: TextStyle(
                                                fontSize: 11,
                                                fontWeight: FontWeight.w700,
                                                color: call.statusColor,
                                                letterSpacing: -0.3,
                                              ),
                                              overflow: TextOverflow.ellipsis,
                                              maxLines: 1,
                                            )
                                          : call.receiverNumber != null && call.receiverNumber!.isNotEmpty
                                            ? Text(
                                                call.receiverNumber!,
                                                style: TextStyle(
                                                  fontSize: 11,
                                                  fontWeight: FontWeight.w700,
                                                  color: call.statusColor,
                                                  letterSpacing: -0.3,
                                                ),
                                                overflow: TextOverflow.ellipsis,
                                                maxLines: 1,
                                              )
                                            : Text(
                                                call.statusText,
                                                style: TextStyle(
                                                  fontSize: 11,
                                                  fontWeight: FontWeight.w700,
                                                  color: call.statusColor,
                                                  letterSpacing: -0.3,
                                                ),
                                                overflow: TextOverflow.ellipsis,
                                                maxLines: 1,
                                              ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              // 🎯 액션 버튼
              Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // 연락처 추가 버튼
                    Container(
                      decoration: BoxDecoration(
                        color: callTheme.addContactButtonBackgroundColor,
                        shape: BoxShape.circle,
                      ),
                      child: IconButton(
                        icon: const Icon(Icons.person_add_rounded, size: 16),
                        color: callTheme.addContactButtonColor,
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(
                          minWidth: 30,
                          minHeight: 30,
                        ),
                        onPressed: () => _showAddContactFromCallDialog(call),
                        tooltip: '연락처 추가',
                      ),
                    ),
                    const SizedBox(width: 4),
                    // 전화 걸기 버튼
                    Container(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                          colors: [
                            callTheme.callButtonGradientStart,
                            callTheme.callButtonGradientEnd,
                          ],
                        ),
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(
                            color: callTheme.callButtonShadowColor,
                            blurRadius: 8,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      child: IconButton(
                        icon: const Icon(Icons.phone, size: 16),
                        color: Colors.white,
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(
                          minWidth: 30,
                          minHeight: 30,
                        ),
                        onPressed: () => _showCallMethodDialog(call.phoneNumber),
                        tooltip: '전화 걸기',
                      ),
                      ),
                    ],
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
          },
                ),
              ),
          ],
        );
      },
    );
  }
  
  /// 📞 필터 Chip 빌더
  Widget _buildFilterChip(String filterValue, String label, int count, bool isDark) {
    final isSelected = _callHistoryFilter == filterValue;
    
    return FilterChip(
      label: Text(
        label,
        style: TextStyle(
          fontSize: 13,
          fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
          color: isSelected 
              ? Colors.white 
              : isDark ? Colors.grey[300] : Colors.grey[700],
        ),
      ),
      selected: isSelected,
      onSelected: (selected) {
        setState(() {
          _callHistoryFilter = filterValue;
        });
      },
      selectedColor: const Color(0xFF2196F3),
      backgroundColor: isDark ? Colors.grey[800] : Colors.white,
      checkmarkColor: Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
        side: BorderSide(
          color: isSelected 
              ? const Color(0xFF2196F3)
              : isDark ? Colors.grey[700]! : Colors.grey[300]!,
          width: 1.5,
        ),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
    );
  }

  Widget _buildContactsTab() {
    final userId = context.watch<AuthService>().currentUser?.uid ?? '';
    final isDark = Theme.of(context).brightness == Brightness.dark;

    // 🔒 로그아웃 상태 체크
    if (userId.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.login, 
              size: 64, 
              color: isDark ? Colors.grey[600] : Colors.grey[400],
            ),
            const SizedBox(height: 16),
            Text(
              '로그인이 필요합니다',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: isDark ? Colors.grey[300] : Colors.grey[700],
              ),
            ),
          ],
        ),
      );
    }

    return Column(
      children: [
        // 상단 컨트롤 바
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: isDark ? Colors.grey[850] : Colors.grey[100],
            border: Border(
              bottom: BorderSide(
                color: isDark ? Colors.grey[700]! : Colors.grey[300]!,
              ),
            ),
          ),
          child: Row(
            children: [
              // 장치 연락처 토글 버튼
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: (_contactManager?.isLoadingDeviceContacts ?? false) ? null : _toggleDeviceContacts,
                  icon: (_contactManager?.isLoadingDeviceContacts ?? false)
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : Icon((_contactManager?.showDeviceContacts ?? false) ? Icons.cloud_done : Icons.smartphone),
                  label: Text(
                    (_contactManager?.showDeviceContacts ?? false) ? '저장된 연락처' : '장치 연락처',
                    style: const TextStyle(fontSize: 13),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: (_contactManager?.showDeviceContacts ?? false)
                        ? const Color(0xFF2196F3)
                        : (isDark ? Colors.grey[800] : Colors.white),
                    foregroundColor: (_contactManager?.showDeviceContacts ?? false)
                        ? Colors.white
                        : const Color(0xFF2196F3),
                    elevation: 2,
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              // 연락처 추가 버튼
              ElevatedButton.icon(
                onPressed: () => _showAddContactDialog(userId),
                icon: const Icon(Icons.person_add, size: 20),
                label: const Text('추가', style: TextStyle(fontSize: 13)),
                style: ElevatedButton.styleFrom(
                  backgroundColor: isDark ? Colors.green[700] : Colors.green,
                  foregroundColor: Colors.white,
                  elevation: 2,
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                ),
              ),
            ],
          ),
        ),

        // 검색바
        Padding(
          padding: const EdgeInsets.all(16.0),
          child: TextField(
            controller: _searchController,
            decoration: InputDecoration(
              hintText: '연락처 검색',
              prefixIcon: const Icon(Icons.search),
              suffixIcon: _searchController.text.isNotEmpty
                  ? IconButton(
                      icon: const Icon(Icons.clear),
                      onPressed: () {
                        _searchController.clear();
                        setState(() {});
                      },
                    )
                  : null,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              filled: true,
              fillColor: isDark ? Colors.grey[850] : Colors.grey[50],
            ),
            onChanged: (value) {
              setState(() {});
            },
          ),
        ),

        // 연락처 목록
        Expanded(
          child: (_contactManager?.showDeviceContacts ?? false)
              ? _buildDeviceContactsList()
              : _buildSavedContactsList(userId),
        ),
      ],
    );
  }

  Widget _buildSavedContactsList(String userId) {
    return StreamBuilder<List<ContactModel>>(
      stream: _databaseService.getUserContacts(userId),
      builder: (context, snapshot) {
        // 🔒 에러 처리
        if (snapshot.hasError) {
          if (kDebugMode) {
            debugPrint('⚠️ [CONTACTS] Stream error ignored (likely logout)');
          }
          // 에러 시 빈 리스트
          return const Center(
            child: Text('연락처를 불러올 수 없습니다'),
          );
        }
        
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        var contacts = snapshot.data ?? [];

        // 검색 필터링
        if (_searchController.text.isNotEmpty) {
          final query = _searchController.text.toLowerCase();
          contacts = contacts.where((contact) {
            return contact.name.toLowerCase().contains(query) ||
                contact.phoneNumber.contains(query);
          }).toList();
        }

        if (contacts.isEmpty) {
          final isDark = Theme.of(context).brightness == Brightness.dark;
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.contacts,
                  size: 80,
                  color: isDark ? Colors.grey[700] : Colors.grey[400],
                ),
                const SizedBox(height: 16),
                Text(
                  _searchController.text.isNotEmpty
                      ? '검색 결과가 없습니다'
                      : '저장된 연락처가 없습니다',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                    color: isDark ? Colors.grey[400] : Colors.grey,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  '우측 상단 추가 버튼을 눌러 연락처를 추가하세요',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 14,
                    color: isDark ? Colors.grey[500] : Colors.grey[600],
                  ),
                ),
              ],
            ),
          );
        }

        return ListView.builder(
          itemCount: contacts.length,
          itemBuilder: (context, index) {
            final contact = contacts[index];
            return _buildContactListTile(contact, showActions: true);
          },
        );
      },
    );
  }

  Widget _buildDeviceContactsList() {
    // Early return if ContactManager is not initialized
    if (_contactManager == null) {
      return const Center(
        child: Text('연락처 관리자를 초기화하는 중...'),
      );
    }
    
    if (_contactManager!.deviceContacts.isEmpty) {
      return const Center(
        child: Text('장치 연락처를 불러오는 중...'),
      );
    }

    var contacts = _contactManager!.deviceContacts;

    // 검색 필터링
    if (_searchController.text.isNotEmpty) {
      final query = _searchController.text.toLowerCase();
      contacts = contacts.where((contact) {
        return contact.name.toLowerCase().contains(query) ||
            contact.phoneNumber.contains(query);
      }).toList();
    }

    if (contacts.isEmpty) {
      return const Center(
        child: Text('검색 결과가 없습니다'),
      );
    }

    return ListView.builder(
      itemCount: contacts.length,
      itemBuilder: (context, index) {
        final contact = contacts[index];
        return _buildContactListTile(contact, isDeviceContact: true);
      },
    );
  }

  Widget _buildContactListTile(
    ContactModel contact, {
    bool showActions = false,
    bool isDeviceContact = false,
  }) {
    // 장치 연락처는 스와이프 삭제 불가
    if (isDeviceContact) {
      return _buildContactListTileContent(contact, showActions: showActions, isDeviceContact: isDeviceContact);
    }
    
    // Firestore 연락처는 스와이프 삭제 가능
    return Dismissible(
      key: Key(contact.id),
      direction: DismissDirection.endToStart,
      background: Builder(
        builder: (context) {
          final isDark = Theme.of(context).brightness == Brightness.dark;
          return Container(
            alignment: Alignment.centerRight,
            padding: const EdgeInsets.only(right: 20),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: isDark
                    ? [Colors.red[900]!.withValues(alpha: 0.6), Colors.red[700]!]
                    : [Colors.red.withValues(alpha: 0.8), Colors.red],
                begin: Alignment.centerLeft,
                end: Alignment.centerRight,
              ),
            ),
            child: const Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                Icon(Icons.delete, color: Colors.white, size: 28),
                SizedBox(width: 8),
                Text(
                  '삭제',
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                  ),
                ),
              ],
            ),
          );
        },
      ),
      confirmDismiss: (direction) async {
        // 삭제 확인 다이얼로그
        return await showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('연락처 삭제'),
            content: Text('${contact.name} 연락처를 삭제하시겠습니까?'),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(false),
                child: const Text('취소'),
              ),
              Builder(
                builder: (context) {
                  final isDark = Theme.of(context).brightness == Brightness.dark;
                  return TextButton(
                    onPressed: () => Navigator.of(context).pop(true),
                    style: TextButton.styleFrom(
                      foregroundColor: isDark ? Colors.red[300] : Colors.red,
                    ),
                    child: const Text('삭제'),
                  );
                },
              ),
            ],
          ),
        );
      },
      onDismissed: (direction) async {
        // 연락처 삭제
        try {
          await _databaseService.deleteContact(contact.id);
          
          if (mounted) {
            await DialogUtils.showSuccess(
              context,
              '${contact.name} 연락처가 삭제되었습니다',
              duration: const Duration(seconds: 1),
            );
          }
        } catch (e) {
          if (mounted) {
            await DialogUtils.showError(
              context,
              '연락처 삭제 실패: $e',
            );
          }
        }
      },
      child: _buildContactListTileContent(contact, showActions: showActions, isDeviceContact: isDeviceContact),
    );
  }

  Widget _buildContactListTileContent(
    ContactModel contact, {
    bool showActions = false,
    bool isDeviceContact = false,
  }) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return ListTile(
      leading: CircleAvatar(
        backgroundColor: contact.isFavorite
            ? (isDark ? Colors.amber[900]!.withAlpha(128) : Colors.amber[100])
            : (isDark
                ? const Color(0xFF2196F3).withAlpha(77)
                : const Color(0xFF2196F3).withAlpha(51)),
        child: Icon(
          contact.isFavorite ? Icons.star : Icons.person,
          color: contact.isFavorite
              ? (isDark ? Colors.amber[300] : Colors.amber[700])
              : const Color(0xFF2196F3),
        ),
      ),
      title: Row(
        children: [
          Expanded(
            child: Text(
              contact.name,
              style: const TextStyle(fontWeight: FontWeight.w600),
            ),
          ),
          if (isDeviceContact)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: isDark ? Colors.blue[900]!.withAlpha(77) : Colors.blue[50],
                borderRadius: BorderRadius.circular(4),
                border: Border.all(
                  color: isDark ? Colors.blue[700]! : Colors.blue[200]!,
                ),
              ),
              child: Text(
                '장치',
                style: TextStyle(
                  fontSize: 10,
                  color: isDark ? Colors.blue[300] : Colors.blue,
                ),
              ),
            ),
        ],
      ),
      subtitle: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(contact.phoneNumber),
          if (contact.company != null)
            Text(
              contact.company!,
              style: TextStyle(
                fontSize: 12,
                color: isDark ? Colors.grey[500] : Colors.grey[600],
              ),
            ),
        ],
      ),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (showActions) ...[
            // 즐겨찾기 토글
            IconButton(
              icon: Icon(
                contact.isFavorite ? Icons.star : Icons.star_border,
                color: contact.isFavorite
                    ? (isDark ? Colors.amber[300] : Colors.amber)
                    : (isDark ? Colors.grey[600] : Colors.grey),
              ),
              onPressed: () => _toggleFavorite(contact),
              tooltip: contact.isFavorite ? '즐겨찾기 해제' : '즐겨찾기 추가',
            ),
            // 수정 버튼
            IconButton(
              icon: Icon(
                Icons.edit,
                color: isDark ? Colors.grey[500] : Colors.grey,
              ),
              onPressed: () => _showEditContactDialog(contact),
              tooltip: '수정',
            ),
          ],
          if (isDeviceContact)
            // 장치 연락처에서 즐겨찾기 토글 버튼 (이벤트 기반)
            IconButton(
              icon: Icon(
                contact.isFavorite ? Icons.star : Icons.star_border,
                color: contact.isFavorite
                    ? (isDark ? Colors.amber[400] : Colors.amber)
                    : (isDark ? Colors.grey[500] : Colors.grey),
              ),
              onPressed: () async {
                // ✅ ContactManager의 toggleFavorite 사용 (통일된 로직)
                await _contactManager?.toggleFavorite(context, contact);
              },
              tooltip: contact.isFavorite ? '즐겨찾기 제거' : '즐겨찾기에 추가',
            ),
          // 전화 버튼
          IconButton(
            icon: const Icon(Icons.phone, color: Color(0xFF2196F3)),
            onPressed: () => _showCallMethodDialog(contact.phoneNumber),
            tooltip: '전화 걸기',
          ),
        ],
      ),
      onTap: () => _showCallMethodDialog(contact.phoneNumber),
    );
  }

  IconData _getCallTypeIcon(CallType type) {
    switch (type) {
      case CallType.incoming:
        return Icons.call_received;
      case CallType.outgoing:
        return Icons.call_made;
      case CallType.missed:
        return Icons.call_missed;
    }
  }

  Color _getCallTypeColor(CallType type, BuildContext context) {
    final colors = CallThemeColors(context);
    switch (type) {
      case CallType.incoming:
        return colors.incomingCallColor;
      case CallType.outgoing:
        return colors.outgoingCallColor;
      case CallType.missed:
        return colors.missedCallColor;
    }
  }

  String _formatDateTime(DateTime dateTime) {
    // yyyy.MM.dd HH:mm:ss 형식
    return '${dateTime.year}.${dateTime.month.toString().padLeft(2, '0')}.${dateTime.day.toString().padLeft(2, '0')} '
           '${dateTime.hour.toString().padLeft(2, '0')}:${dateTime.minute.toString().padLeft(2, '0')}:${dateTime.second.toString().padLeft(2, '0')}';
  }

  // 기능번호 판별 (즐겨찾기, 최근통화 전용)
  /// 통화 방법 다이얼로그 (CallManager 위임)
  Future<void> _showCallMethodDialog(String phoneNumber) async {
    await _callManager?.showCallMethodDialog(context, _authService!, phoneNumber);
  }
  




  /// 기능번호 자동 발신 (CallManager 위임)
  Future<void> _handleFeatureCodeCall(String phoneNumber) async {
    await _callManager?.handleFeatureCodeCall(context, _authService!, phoneNumber);
  }

  /// 기능번호 자동 발신 (LEGACY - 삭제 예정)
  Future<void> _handleFeatureCodeCallLegacy(String phoneNumber) async {
    try {
      final authService = context.read<AuthService>();
      final userId = authService.currentUser?.uid ?? '';
      final userModel = authService.currentUserModel;

      if (userModel?.companyId == null || userModel?.appKey == null) {
        throw Exception('API 인증 정보가 설정되지 않았습니다. 내 정보에서 설정해주세요.');
      }

      if (userModel?.apiBaseUrl == null) {
        throw Exception('API 서버 주소가 설정되지 않았습니다. 내 정보 > API 설정에서 설정해주세요.');
      }

      // 홈 탭에서 선택된 단말번호 가져오기 (실시간 반영)
      final selectedExtension = context.read<SelectedExtensionProvider>().selectedExtension;
      
      if (selectedExtension == null) {
        throw Exception('선택된 단말번호가 없습니다.\n왼쪽 상단 프로필에서 단말번호를 등록해주세요.');
      }

      // 🔥 CRITICAL: DB에 단말번호가 실제로 존재하는지 확인
      final dbExtensions = await _databaseService.getMyExtensions(userId).first;
      final extensionExists = dbExtensions.any((ext) => ext.extension == selectedExtension.extension);
      
      if (!extensionExists) {
        if (kDebugMode) {
          debugPrint('❌ 단말번호가 DB에서 삭제됨: ${selectedExtension.extension}');
          debugPrint('🔄 착신전환 비활성화 시도');
        }
        
        // 착신전환 비활성화 시도 (DCMIWS 웹소켓으로 전송)
        try {
          if (userModel != null &&
              userModel.amiServerId != null && 
              userModel.tenantId != null && 
              selectedExtension.extension.isNotEmpty) {
            final dcmiws = DCMIWSService();
            await dcmiws.setCallForwardEnabled(
              amiServerId: userModel.amiServerId!,
              tenantId: userModel.tenantId!,
              extensionId: selectedExtension.extension,  // ← 단말번호 사용
              enabled: false,
              diversionType: 'CFI',
            );
            
            if (kDebugMode) {
              debugPrint('✅ 착신전환 비활성화 요청 전송 완료');
            }
          }
        } catch (e) {
          if (kDebugMode) {
            debugPrint('⚠️  착신전환 비활성화 실패: $e');
          }
        }
        
        throw Exception('등록된 단말번호가 없습니다.\n\n프로필 드로어에서 단말번호가 삭제되었습니다.\n다시 등록해주세요.');
      }

      if (kDebugMode) {
        debugPrint('🌟 즐곊/최근통화 기능번호 자동 발신 시작 (다이얼로그 건너뛰기)');
        debugPrint('📞 선택된 단말번호: ${selectedExtension.extension}');
        debugPrint('👤 단말 이름: ${selectedExtension.name}');
        debugPrint('🔑 COS ID: ${selectedExtension.classOfServicesId}');
        debugPrint('🎯 기능번호: $phoneNumber');
      }

      // 🔍 발신 대상 숫자 자릿수 확인
      final cleanNumber = phoneNumber.replaceAll(RegExp(r'[^0-9]'), '');
      final is5DigitsOrLess = cleanNumber.length > 0 && cleanNumber.length <= 5;
      
      // 📞 CID 설정: 발신 대상에 따라 다르게 설정
      String cidName;
      String cidNumber;
      
      if (is5DigitsOrLess) {
        // 5자리 이하: my_extensions의 name, extension 사용
        cidName = selectedExtension.name;
        cidNumber = selectedExtension.extension;
        
        if (kDebugMode) {
          debugPrint('📞 5자리 이하 발신');
          debugPrint('   CID Name: $cidName (my_extensions.name)');
          debugPrint('   CID Number: $cidNumber (my_extensions.extension)');
        }
      } else {
        // 5자리 초과: my_extensions의 externalCidName, externalCidNumber 사용
        cidName = selectedExtension.externalCidName ?? '클릭투콜';
        cidNumber = selectedExtension.externalCidNumber ?? phoneNumber;
        
        if (kDebugMode) {
          debugPrint('📞 5자리 초과 발신');
          debugPrint('   CID Name: $cidName (my_extensions.externalCidName)');
          debugPrint('   CID Number: $cidNumber (my_extensions.externalCidNumber)');
        }
      }

      // 로딩 표시 (DialogUtils로 변환)
      if (mounted) {
        await DialogUtils.showInfo(
          context,
          '기능번호 발신 중...',
          duration: const Duration(seconds: 1),
        );
      }

      // 🔥 Step 1: 착신전환 정보 먼저 조회 (API 호출 전)
      final callForwardInfo = await _databaseService
          .getCallForwardInfoOnce(userId, selectedExtension.extension);
      
      final isForwardEnabled = callForwardInfo?.isEnabled ?? false;
      final forwardDestination = (callForwardInfo?.destinationNumber ?? '').trim();

      if (kDebugMode) {
        debugPrint('');
        debugPrint('💾 ========== 통화 기록 준비 (착신전환 정보 포함) ==========');
        debugPrint('   📱 단말번호: ${selectedExtension.extension}');
        debugPrint('   📞 발신 대상: $phoneNumber');
        debugPrint('   🔄 착신전환 활성화: $isForwardEnabled');
        debugPrint('   ➡️  착신전환 목적지: ${isForwardEnabled ? forwardDestination : "비활성화"}');
        debugPrint('   📦 준비 데이터:');
        debugPrint('      - callForwardEnabled: $isForwardEnabled');
        debugPrint('      - callForwardDestination: ${(isForwardEnabled && forwardDestination.isNotEmpty) ? forwardDestination : "null"}');
        debugPrint('========================================================');
        debugPrint('');
      }

      // 🚀 Step 2: Pending Storage에 먼저 저장 (Race Condition 방지!)
      // ✅ API 호출 전에 저장하여 Newchannel 이벤트보다 항상 먼저 준비됨
      final dcmiws = DCMIWSService();
      dcmiws.storePendingClickToCallRecord(
        extensionNumber: selectedExtension.extension,
        phoneNumber: phoneNumber,
        userId: userId,
        mainNumberUsed: cidNumber,
        callForwardEnabled: isForwardEnabled,
        callForwardDestination: (isForwardEnabled && forwardDestination.isNotEmpty) ? forwardDestination : null,
      );

      // API 서비스 생성 (동적 API URL 사용)
      // apiHttpPort가 3501이면 HTTPS 사용, 3500이면 HTTP 사용
      final useHttps = (userModel!.apiHttpPort ?? 3500) == 3501;
      
      final apiService = ApiService(
        baseUrl: userModel.getApiUrl(useHttps: useHttps),
        companyId: userModel.companyId,
        appKey: userModel.appKey,
      );

      // 📞 Step 3: Click to Call API 호출 (Pending Storage 준비 완료 후)
      final result = await apiService.clickToCall(
        caller: selectedExtension.extension, // 선택된 단말번호 사용
        callee: phoneNumber,
        cosId: selectedExtension.classOfServicesId, // 선택된 COS ID 사용
        cidName: cidName,
        cidNumber: cidNumber,
        accountCode: userModel.phoneNumber ?? '',
      );

      if (kDebugMode) {
        debugPrint('✅ 즐곊/최근통화 기능번호 Click to Call 성공: $result');
        debugPrint('   → Newchannel 이벤트 대기 중... (Pending Storage 준비 완료)');
      }

      // 성공 메시지 (DialogUtils로 변환)
      if (mounted) {
        final extensionDisplay = selectedExtension.name.isEmpty 
            ? selectedExtension.extension 
            : selectedExtension.name;
        await DialogUtils.showSuccess(
          context,
          '🌟 기능번호 발신 완료\n\n단말: $extensionDisplay\n기능번호: $phoneNumber',
          duration: const Duration(seconds: 1),
        );
      }
      
      // 🔄 기능번호 발신 성공 시 최근통화 탭으로 전환
      if (mounted) {
        setState(() {
          _currentTabIndex = 1; // 최근통화 탭
        });
        if (kDebugMode) {
          debugPrint('✅ 기능번호 발신 성공 → 최근통화 탭으로 전환');
        }
      }
    } catch (e, stackTrace) {
      // 에러 메시지 (DialogUtils로 변환)
      if (mounted) {
        await DialogUtils.showError(
          context,
          '기능번호 발신 실패: $e',
        );
      }
      
      if (kDebugMode) {
        debugPrint('❌ [call_tab] 기능번호 발신 오류: $e');
      }
    }
  }

  /// 즐겨찾기 토글 (ContactManager 위임)
  Future<void> _toggleFavorite(ContactModel contact) async {
    await _contactManager?.toggleFavorite(context, contact);
  }

  /// 장치 연락처 토글 (ContactManager 위임)
  Future<void> _toggleDeviceContacts() async {
    await _contactManager?.toggleDeviceContacts(context, _authService!);
  }



  void _showAddContactDialog(String userId) {
    showDialog(
      context: context,
      builder: (context) => AddContactDialog(userId: userId),
    );
  }

  void _showEditContactDialog(ContactModel contact) {
    showDialog(
      context: context,
      builder: (context) => AddContactDialog(
        userId: contact.userId,
        contact: contact,
      ),
    );
  }

  /// 최근통화에서 연락처 추가 다이얼로그
  /// 통화 상세 내역 다이얼로그 표시
  Future<void> _showCallDetailDialog(CallHistoryModel call) async {
    // 🔍 디버그: 통화 기록 정보 확인
    if (kDebugMode) {
      debugPrint('');
      debugPrint('📞 통화 상세 다이얼로그 요청');
      debugPrint('  - 문서 ID: ${call.id}');  // 🔥 추가: 문서 ID 출력
      debugPrint('  - 전화번호: ${call.phoneNumber}');
      debugPrint('  - 통화 타입: ${call.callType}');
      debugPrint('  - 통화 시간: ${call.callTime}');
      debugPrint('  - Linkedid 존재: ${call.linkedid != null}');
      if (call.linkedid != null) {
        debugPrint('  - Linkedid: ${call.linkedid}');
        debugPrint('  - Linkedid 길이: ${call.linkedid!.length}');
      }
    }
    
    // linkedid가 없으면 안내 메시지 표시
    if (call.linkedid == null || call.linkedid!.isEmpty) {
      if (kDebugMode) {
        debugPrint('ℹ️ Linkedid가 없어 통화 상세를 조회할 수 없음');
      }
      
      await DialogUtils.showInfo(
        context,
        '통화 상세 내역이 없습니다.',
      );
      return;
    }

    if (kDebugMode) {
      debugPrint('✅ CallDetailDialog 열기 시작...');
    }

    showDialog(
      context: context,
      builder: (context) => CallDetailDialog(linkedid: call.linkedid!),
    );
  }

  Future<void> _showAddContactFromCallDialog(CallHistoryModel call) async {
    final userId = context.read<AuthService>().currentUser?.uid ?? '';
    
    // 이미 이름이 있는 경우 (연락처가 있음)
    if (call.contactName != null && call.contactName!.isNotEmpty) {
      await DialogUtils.showWarning(
        context,
        '${call.contactName}은(는) 이미 연락처에 등록되어 있습니다',
      );
      return;
    }

    // 전화번호만 있는 경우 - 연락처 추가 다이얼로그 표시
    showDialog(
      context: context,
      builder: (context) => AddContactDialog(
        userId: userId,
        initialPhoneNumber: call.phoneNumber, // 전화번호 미리 채우기
      ),
    );
  }

  Future<void> _addDeviceContactToFavorites(ContactModel contact) async {
    try {
      final userId = context.read<AuthService>().currentUser?.uid ?? '';
      
      if (kDebugMode) {
        debugPrint('');
        debugPrint('📱 ===== 장치 연락처 → 즐겨찾기 추가 START =====');
        debugPrint('  연락처: ${contact.name}');
        debugPrint('  전화번호: ${contact.phoneNumber}');
      }
      
      // 🔥 중복 체크: 전화번호 기준으로 이미 존재하는 연락처 확인
      final existingContact = await _databaseService.findContactByPhone(
        userId, 
        contact.phoneNumber,
      );
      
      if (existingContact != null) {
        // 중복된 연락처가 이미 존재하는 경우
        if (kDebugMode) {
          debugPrint('⚠️  중복된 연락처: ${contact.phoneNumber}');
          debugPrint('📱 ===== 장치 연락처 → 즐겨찾기 추가 END (중복) =====');
          debugPrint('');
        }
        
        if (mounted) {
          await DialogUtils.showInfo(
            context,
            '이미 추가된 연락처입니다',
            duration: const Duration(milliseconds: 1500),
          );
        }
        return; // 중복이므로 추가하지 않음
      }
      
      // 중복이 아니면 Firestore에 저장
      final newContact = contact.copyWith(
        userId: userId,
        isFavorite: true,
        isDeviceContact: false, // 이제 저장된 연락처
      );

      // 🔥 이벤트 기반 Firestore 업데이트: addContact → 변경 완료 대기
      // StreamBuilder가 새 문서를 감지한 후에만 함수 종료
      final docId = await _databaseService.addContact(newContact);
      
      // 🔄 Firestore 변경 확인: 새 문서가 스냅샷에 나타날 때까지 대기
      await _databaseService.waitForContactAdded(userId, docId);

      if (kDebugMode) {
        debugPrint('✅ Firestore 변경 감지 완료 (새 연락처 추가됨)');
        debugPrint('  StreamBuilder가 이미 연락처 탭 UI 업데이트 완료');
        debugPrint('  장치 연락처 목록은 변경 없음 (메모리에만 존재)');
        debugPrint('📱 ===== 장치 연락처 → 즐겨찾기 추가 END =====');
        debugPrint('');
      }

      // 🎯 다이얼로그 제거 - StreamBuilder가 자동으로 UI 업데이트
      // 사용자는 연락처 탭에서 추가된 항목을 확인 가능
      
    } catch (e, stackTrace) {
      if (kDebugMode) {
        debugPrint('❌ 장치 연락처 추가 실패: $e');
        debugPrint('스택 트레이스: $stackTrace');
        debugPrint('');
      }
      
      if (mounted) {
        await DialogUtils.showError(
          context,
          '즐겨찾기 추가 실패',
          duration: const Duration(milliseconds: 1500),
        );
      }
    }
  }

  // 이름 번역 함수
  String _translateName(String name) {
    return _nameTranslations[name] ?? name;
  }

  // 단말번호 연락처 리스트 타일
  Widget _buildPhonebookContactListTile(PhonebookContactModel contact) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    Color categoryColor = Colors.blue;
    IconData categoryIcon = Icons.phone;

    if (contact.category == 'Extensions') {
      categoryColor = isDark ? Colors.green[300]! : Colors.green;
      categoryIcon = Icons.phone_android;
    } else if (contact.category == 'Feature Codes') {
      categoryColor = isDark ? Colors.orange[300]! : Colors.orange;
      categoryIcon = Icons.star;
    } else {
      categoryColor = isDark ? Colors.blue[300]! : Colors.blue;
    }

    // 이름 번역 (Feature Codes 이름만)
    final translatedName = _translateName(contact.name);
    
    // categoryDisplay는 이미 DB에 한글로 저장되어 있음 (fromApi에서 변환됨)
    final categoryDisplay = contact.categoryDisplay;

    return ListTile(
      leading: CircleAvatar(
        backgroundColor: isDark
            ? Colors.amber[900]!.withAlpha(128)
            : Colors.amber[100],
        child: Icon(
          categoryIcon,
          color: isDark ? Colors.amber[300] : Colors.amber[700],
        ),
      ),
      title: Row(
        children: [
          Expanded(
            child: Text(
              translatedName,
              style: const TextStyle(fontWeight: FontWeight.w600),
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: categoryColor.withAlpha(26),
              borderRadius: BorderRadius.circular(4),
              border: Border.all(color: categoryColor.withAlpha(77)),
            ),
            child: Text(
              categoryDisplay,
              style: TextStyle(
                fontSize: 11,
                color: categoryColor,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
      subtitle: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            contact.telephone,
            style: const TextStyle(fontWeight: FontWeight.w500),
          ),
          if (contact.company != null)
            Text(
              contact.company!,
              style: TextStyle(
                fontSize: 12,
                color: isDark ? Colors.grey[500] : Colors.grey[600],
              ),
            ),
        ],
      ),
      trailing: IconButton(
        icon: const Icon(Icons.phone, color: Color(0xFF2196F3)),
        onPressed: () => _showCallMethodDialog(contact.telephone),
        tooltip: '전화 걸기',
      ),
      onTap: () => _showCallMethodDialog(contact.telephone),
    );
  }
}
