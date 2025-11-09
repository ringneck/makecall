import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:provider/provider.dart';
import 'package:permission_handler/permission_handler.dart';
import '../../services/auth_service.dart';
import '../../services/database_service.dart';
import '../../services/mobile_contacts_service.dart';
import '../../services/api_service.dart';
import '../../services/dcmiws_service.dart';
import '../../models/contact_model.dart';
import '../../models/call_history_model.dart';
import '../../models/phonebook_model.dart';
import '../../providers/selected_extension_provider.dart';
import 'dialpad_screen.dart';
import 'phonebook_tab.dart';
import '../../widgets/call_method_dialog.dart';
import '../../widgets/add_contact_dialog.dart';
import '../../widgets/call_detail_dialog.dart';
import '../../widgets/profile_drawer.dart';
import '../../widgets/extension_drawer.dart';

class CallTab extends StatefulWidget {
  final bool autoOpenProfileForNewUser; // 신규 사용자 자동 ProfileDrawer 열기
  
  const CallTab({
    super.key,
    this.autoOpenProfileForNewUser = false,
  });

  @override
  State<CallTab> createState() => _CallTabState();
}

class _CallTabState extends State<CallTab> {
  int _currentTabIndex = 2; // 현재 선택된 탭 인덱스 (초기값: 키패드)
  final DatabaseService _databaseService = DatabaseService();
  final MobileContactsService _mobileContactsService = MobileContactsService();
  final TextEditingController _searchController = TextEditingController();
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();
  
  bool _isLoadingDeviceContacts = false;
  bool _showDeviceContacts = false;
  List<ContactModel> _deviceContacts = [];
  bool _hasCheckedSettings = false; // 설정 체크 완료 플래그
  bool _hasCheckedNewUser = false; // 신규 사용자 체크 완료 플래그
  
  // 🔒 고급 개발자 패턴: AuthService 참조를 안전하게 저장
  // dispose()에서 context 사용을 피하기 위한 전략
  AuthService? _authService;
  
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
    
    // 🚀 고급 개발자 패턴: 순차적 초기화 체인
    // 1️⃣ 설정 확인 먼저 → 2️⃣ 설정 완료 시에만 단말번호 조회
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (!mounted) return;
      
      // 🔒 AuthService 참조를 안전하게 저장 (dispose에서 사용)
      _authService = context.read<AuthService>();
      
      // AuthService 리스너 등록 (사용자 전환 감지)
      _authService?.addListener(_onUserModelChanged);
      
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
      
      // 🎉 신규 사용자 체크 및 ProfileDrawer 자동 열기
      if (widget.autoOpenProfileForNewUser) {
        await _checkAndOpenProfileDrawerForNewUser();
      }
      
      // 순차적 초기화 실행
      await _initializeSequentially();
    });
  }
  
  /// 🔄 순차적 초기화 체인
  /// 고급 패턴: Early Return + Fail-Fast + Single Responsibility
  Future<void> _initializeSequentially() async {
    if (!mounted) return;
    
    // 🎯 STEP 1: 단말번호 자동 초기화 (최우선)
    // 클릭투콜 기능을 위해 로그인 즉시 단말번호 설정
    await _initializeExtensions();
    
    if (!mounted) return;
    
    // 🎯 STEP 2: 설정 확인 (선택적 안내)
    await _checkSettingsAndShowGuide();
  }
  
  @override
  void dispose() {
    // 🔒 고급 개발자 패턴: 저장된 참조를 사용하여 안전하게 리스너 제거
    // context.read()를 사용하지 않음 → deactivated widget 에러 방지
    _authService?.removeListener(_onUserModelChanged);
    _authService = null; // 메모리 누수 방지
    
    // 🔔 DCMIWS 이벤트 구독 취소
    _dcmiwsEventSubscription?.cancel();
    _dcmiwsEventSubscription = null;
    
    _searchController.dispose();
    super.dispose();
  }
  
  // 🔔 userModel 변경 감지 콜백 (고급 패턴: 안전한 비동기 처리)
  void _onUserModelChanged() {
    if (kDebugMode) {
      debugPrint('🔔 AuthService 리스너 트리거: userModel 변경 감지');
    }
    
    // 🔒 mounted 체크 최우선 (Widget이 dispose되었을 수 있음)
    if (!mounted) {
      if (kDebugMode) {
        debugPrint('⚠️ Widget이 이미 dispose됨 - 리스너 콜백 무시');
      }
      return;
    }
    
    // 🔒 저장된 AuthService 참조 사용 (context 사용 안함)
    if (_authService?.currentUserModel != null && !_hasCheckedSettings) {
      if (kDebugMode) {
        debugPrint('✅ userModel 로드 완료 - 설정 체크 재실행');
      }
      
      // 다음 프레임에서 실행 (비동기 안전)
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          _checkSettingsAndShowGuide();
        }
      });
    }
  }
  
  /// 🎯 단말번호 자동 초기화 (로그인 직후 실행)
  /// 
  /// **핵심 기능**: 클릭투콜을 위한 단말번호 자동 설정
  /// - 로그인 즉시 첫 번째 단말번호를 SelectedExtensionProvider에 설정
  /// - ExtensionDrawer 열기 전에도 클릭투콜 사용 가능
  /// 
  /// **최적화 전략**:
  /// - Early Return: 조건 미충족 시 즉시 반환
  /// - Idempotent: 이미 설정된 경우 재설정하지 않음
  /// - Fail Silent: 에러 시 조용히 처리 (사용자 경험 저해 방지)
  Future<void> _initializeExtensions() async {
    // 🔒 Early Return: userId 검증
    final userId = _authService?.currentUser?.uid;
    if (userId == null || userId.isEmpty) {
      if (kDebugMode) debugPrint('⚠️ 단말번호 초기화 스킵: userId 없음');
      return;
    }
    
    try {
      if (kDebugMode) debugPrint('🔄 단말번호 자동 초기화 시작...');
      
      // 🔒 단말번호 조회 (Firestore Stream)
      final extensions = await _databaseService.getMyExtensions(userId).first;
      
      if (extensions.isEmpty) {
        if (kDebugMode) {
          debugPrint('ℹ️ 등록된 단말번호 없음 - 설정에서 단말번호를 조회하세요');
        }
        return;
      }
      
      if (!mounted) return;
      
      // 🔒 Provider 상태 업데이트 (Idempotent)
      final provider = context.read<SelectedExtensionProvider>();
      
      // 이미 설정된 경우 재설정하지 않음 (성능 최적화)
      if (provider.selectedExtension == null) {
        provider.setSelectedExtension(extensions.first);
        if (kDebugMode) {
          debugPrint('✅ 단말번호 자동 초기화 완료: ${extensions.first.extension}');
          debugPrint('   - 이름: ${extensions.first.name}');
          debugPrint('   - 총 ${extensions.length}개 단말번호 중 첫 번째 선택');
        }
      } else {
        if (kDebugMode) {
          debugPrint('ℹ️ 단말번호 이미 설정됨: ${provider.selectedExtension!.extension}');
        }
      }
    } catch (e) {
      // 🔒 Fail Silent: 단말번호 초기화 실패는 치명적이지 않음
      // ExtensionDrawer에서 수동으로 선택 가능
      if (kDebugMode) {
        debugPrint('⚠️ 단말번호 자동 초기화 실패: $e');
        debugPrint('   → ExtensionDrawer에서 수동 선택 필요');
      }
    }
  }
  
  /// 🎉 신규 사용자 감지 및 ProfileDrawer 자동 열기
  /// 
  /// **기능**: 회원가입 직후 기본 설정이 필요한 신규 사용자를 감지하고 ProfileDrawer를 자동으로 엽니다
  /// - API 설정, WebSocket 설정, 단말번호 모두 완료된 경우 ProfileDrawer 열지 않음
  /// - 설정이 부족한 경우에만 ProfileDrawer 자동 열기
  /// - 안내 메시지 없이 바로 ProfileDrawer 열기
  /// - 최초 1회만 실행 (중복 열기 방지)
  Future<void> _checkAndOpenProfileDrawerForNewUser() async {
    if (_hasCheckedNewUser) return;
    _hasCheckedNewUser = true;

    try {
      final userId = _authService?.currentUser?.uid;
      if (userId == null) return;

      // 🔒 userModel 로드 대기
      final userModel = _authService?.currentUserModel;
      if (userModel == null) {
        if (kDebugMode) debugPrint('⏳ userModel 로딩 중 - 신규 사용자 체크 대기');
        return;
      }

      // 🔒 필수 설정 확인
      final hasApiSettings = (userModel.apiBaseUrl?.isNotEmpty ?? false) &&
                            (userModel.companyId?.isNotEmpty ?? false) &&
                            (userModel.appKey?.isNotEmpty ?? false);
      
      final hasWebSocketSettings = userModel.websocketServerUrl?.isNotEmpty ?? false;
      
      // 🔒 등록된 단말번호 확인
      final extensions = await _databaseService.getMyExtensions(userId).first;
      final hasExtensions = extensions.isNotEmpty;

      if (kDebugMode) {
        debugPrint('');
        debugPrint('='*60);
        debugPrint('🔍 신규 사용자 체크');
        debugPrint('='*60);
        debugPrint('   사용자 ID: $userId');
        debugPrint('   - API 설정: $hasApiSettings');
        debugPrint('   - WebSocket: $hasWebSocketSettings');
        debugPrint('   - 단말번호: $hasExtensions (${extensions.length}개)');
        debugPrint('='*60);
      }

      if (!mounted) return;

      // 🔒 모든 설정 완료 시 ProfileDrawer 열지 않음
      if (hasApiSettings && hasWebSocketSettings && hasExtensions) {
        if (kDebugMode) {
          debugPrint('✅ 모든 설정 완료 - ProfileDrawer 열지 않고 키패드 화면 유지');
        }
        _hasCheckedSettings = true; // 안내 팝업도 표시하지 않음
        return;
      }

      // 🔒 설정이 부족한 경우 ProfileDrawer 자동 열기
      if (kDebugMode) {
        debugPrint('');
        debugPrint('='*60);
        debugPrint('⚠️ 설정 미완료 감지!');
        debugPrint('='*60);
        debugPrint('   → ProfileDrawer 자동 열기 실행');
        debugPrint('   → 초기 등록 안내 팝업 비활성화');
        debugPrint('='*60);
        debugPrint('');
      }

      // 🔒 설정 미완료 사용자는 초기 등록 안내 팝업을 표시하지 않음
      _hasCheckedSettings = true;

      // 약간의 지연 후 ProfileDrawer 자동 열기 (UI가 완전히 로드된 후)
      await Future.delayed(const Duration(milliseconds: 500));
      
      if (!mounted) return;
      
      // ProfileDrawer 열기
      _scaffoldKey.currentState?.openDrawer();
      
      if (kDebugMode) {
        debugPrint('✅ ProfileDrawer 자동 열기 완료');
      }
    } catch (e) {
      if (kDebugMode) {
        debugPrint('❌ 신규 사용자 체크 오류: $e');
      }
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
    // 🔒 중복 실행 방지
    if (_hasCheckedSettings) {
      if (kDebugMode) debugPrint('✅ 설정 체크 이미 완료됨');
      return;
    }
    
    // 🔒 userModel 로드 대기
    final userModel = _authService?.currentUserModel;
    if (userModel == null) {
      if (kDebugMode) debugPrint('⏳ userModel 로딩 중 - 설정 체크 대기');
      return;
    }
    
    final userId = _authService?.currentUser?.uid ?? '';
    
    // 🔒 필수 설정 확인
    final hasApiSettings = (userModel.apiBaseUrl?.isNotEmpty ?? false) &&
                          (userModel.companyId?.isNotEmpty ?? false) &&
                          (userModel.appKey?.isNotEmpty ?? false);
    
    final hasWebSocketSettings = userModel.websocketServerUrl?.isNotEmpty ?? false;
    
    // 🔒 등록된 단말번호 확인
    final extensions = await _databaseService.getMyExtensions(userId).first;
    final hasExtensions = extensions.isNotEmpty;
    
    if (kDebugMode) {
      debugPrint('🔍 설정 체크:');
      debugPrint('   - API 설정: $hasApiSettings');
      debugPrint('   - WebSocket: $hasWebSocketSettings');
      debugPrint('   - 단말번호: $hasExtensions (${extensions.length}개)');
    }
    
    // 🔒 모든 설정 완료 시 체크 종료
    if (hasApiSettings && hasWebSocketSettings && hasExtensions) {
      _hasCheckedSettings = true;
      if (kDebugMode) debugPrint('✅ 모든 설정 완료');
      return;
    }
    
    // 🔒 설정 미완료 시 안내 다이얼로그
    if (!hasApiSettings || !hasWebSocketSettings) {
      _hasCheckedSettings = true; // 1회만 표시
      
      if (mounted) {
        await showDialog(
          context: context,
          barrierDismissible: false,
          builder: (context) => AlertDialog(
            title: Row(
              children: const [
                Icon(Icons.info_outline, color: Color(0xFF2196F3), size: 28),
                SizedBox(width: 12),
                Text('초기 등록 필요'),
              ],
            ),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // 계정 정보 표시
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.grey[100],
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.grey[300]!),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.account_circle, size: 24, color: Colors.grey[700]),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          userModel.email.isNotEmpty ? userModel.email : (_authService?.currentUser?.email ?? '사용자'),
                          style: const TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                const Text(
                  '통화 기능을 사용하기 위해서는\nAPI 서버 및 WebSocket 설정이 필요합니다.',
                  style: TextStyle(fontSize: 15, fontWeight: FontWeight.w500),
                ),
                const SizedBox(height: 16),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: const Color(0xFF2196F3).withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: const Color(0xFF2196F3).withValues(alpha: 0.3),
                    ),
                  ),
                  child: const Row(
                    children: [
                      Icon(Icons.touch_app, size: 20, color: Color(0xFF2196F3)),
                      SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          '왼쪽 상단 프로필 아이콘을 눌러\n설정 정보를 입력해주세요.',
                          style: TextStyle(fontSize: 13, color: Color(0xFF1976D2)),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () {
                  _hasCheckedSettings = true; // 나중에 버튼 누르면 더 이상 표시 안 함
                  Navigator.pop(context);
                },
                child: const Text('나중에'),
              ),
              ElevatedButton.icon(
                onPressed: () async {
                  _hasCheckedSettings = true; // 설정하기 누르면 더 이상 표시 안 함
                  Navigator.pop(context);
                  // 다이얼로그가 완전히 닫힌 후 ProfileDrawer 열기
                  await Future.delayed(const Duration(milliseconds: 300));
                  if (mounted && _scaffoldKey.currentState != null) {
                    _scaffoldKey.currentState!.openDrawer();
                  }
                },
                icon: const Icon(Icons.settings, size: 18),
                label: const Text('설정하기'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF2196F3),
                  foregroundColor: Colors.white,
                ),
              ),
            ],
          ),
        );
      }
      return;
    }
    
    // 🔒 단말번호 미등록 시 안내 다이얼로그
    if (!hasExtensions) {
      _hasCheckedSettings = true; // 1회만 표시
      if (mounted) {
        await showDialog(
          context: context,
          barrierDismissible: false,
          builder: (context) => AlertDialog(
            title: Row(
              children: const [
                Icon(Icons.phone_disabled, color: Colors.orange, size: 28),
                SizedBox(width: 12),
                Text('단말번호 등록 필요'),
              ],
            ),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // 계정 정보 표시
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.grey[100],
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.grey[300]!),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.account_circle, size: 24, color: Colors.grey[700]),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          userModel.email.isNotEmpty ? userModel.email : (_authService?.currentUser?.email ?? '사용자'),
                          style: const TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                const Text(
                  '등록된 단말번호가 없습니다.',
                  style: TextStyle(fontSize: 15, fontWeight: FontWeight.w500),
                ),
                const SizedBox(height: 16),
                const Text(
                  '통화 기능을 사용하려면 단말번호를 조회하고 등록해야 합니다.',
                  style: TextStyle(fontSize: 14, color: Colors.black87),
                ),
                const SizedBox(height: 16),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.orange.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: Colors.orange.withValues(alpha: 0.3),
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: const [
                      Row(
                        children: [
                          Icon(Icons.info_outline, size: 20, color: Colors.orange),
                          SizedBox(width: 8),
                          Text(
                            '등록 방법:',
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.bold,
                              color: Colors.orange,
                            ),
                          ),
                        ],
                      ),
                      SizedBox(height: 8),
                      Text(
                        '1. 왼쪽 상단 프로필 아이콘 클릭\n'
                        '2. 단말번호 조회 및 등록\n',
                        style: TextStyle(fontSize: 12, color: Colors.black87),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () {
                  _hasCheckedSettings = true; // 나중에 버튼 누르면 더 이상 표시 안 함
                  Navigator.pop(context);
                },
                child: const Text('나중에'),
              ),
              ElevatedButton.icon(
                onPressed: () async {
                  _hasCheckedSettings = true; // 설정하기 누르면 더 이상 표시 안 함
                  Navigator.pop(context);
                  // 다이얼로그가 완전히 닫힌 후 ProfileDrawer 열기
                  await Future.delayed(const Duration(milliseconds: 300));
                  if (mounted && _scaffoldKey.currentState != null) {
                    _scaffoldKey.currentState!.openDrawer();
                  }
                },
                icon: const Icon(Icons.phone_in_talk, size: 18),
                label: const Text('등록하기'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.orange,
                  foregroundColor: Colors.white,
                ),
              ),
            ],
          ),
        );
      }
    }
  }



  @override
  Widget build(BuildContext context) {
    final authService = context.watch<AuthService>();
    
    return Scaffold(
      key: _scaffoldKey,
      appBar: AppBar(
        leading: Builder(
          builder: (context) => IconButton(
            icon: CircleAvatar(
              radius: 18,
              backgroundColor: Colors.transparent,
              backgroundImage: authService.currentUserModel?.profileImageUrl != null
                  ? NetworkImage(authService.currentUserModel!.profileImageUrl!)
                  : const AssetImage('assets/icons/app_icon.png') as ImageProvider,
            ),
            onPressed: () {
              Scaffold.of(context).openDrawer();
            },
            tooltip: '계정 정보',
          ),
        ),
        title: const Text('MAKECALL'),
        actions: [
          Builder(
            builder: (context) => IconButton(
              icon: CircleAvatar(
                radius: 18,
                backgroundColor: Colors.black,
                child: const Icon(
                  Icons.phone_in_talk,
                  size: 24,
                  color: Colors.white,
                ),
              ),
              onPressed: () {
                Scaffold.of(context).openEndDrawer();
              },
              tooltip: '내 단말정보',
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
            onClickToCallSuccess: () {
              if (mounted) {
                setState(() {
                  _currentTabIndex = 1; // 최근통화 탭
                });
                if (kDebugMode) {
                  debugPrint('✅ 단말번호 클릭투콜 성공 → 최근통화 탭으로 전환');
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
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _currentTabIndex,
        onTap: (index) {
          setState(() {
            _currentTabIndex = index;
          });
        },
        type: BottomNavigationBarType.fixed,
        selectedItemColor: const Color(0xFF2196F3),
        unselectedItemColor: Colors.grey,
        selectedLabelStyle: const TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w600,
        ),
        unselectedLabelStyle: const TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.normal,
        ),
        selectedFontSize: 11,
        unselectedFontSize: 11,
        items: const [
          BottomNavigationBarItem(
            icon: Icon(Icons.phone_android, size: 24),
            label: '단말번호',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.history, size: 24),
            label: '최근통화',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.dialpad, size: 24),
            label: '키패드',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.star, size: 24),
            label: '즐겨찾기',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.contacts, size: 24),
            label: '연락처',
          ),
        ],
      ),
    );
  }

  Widget _buildFavoritesTab() {
    final userId = context.watch<AuthService>().currentUser?.uid ?? '';

    // 연락처와 단말번호 즐겨찾기를 모두 표시
    return StreamBuilder<List<ContactModel>>(
      stream: _databaseService.getFavoriteContacts(userId),
      builder: (context, contactSnapshot) {
        return StreamBuilder<List<PhonebookContactModel>>(
          stream: _databaseService.getFavoritePhonebookContacts(userId),
          builder: (context, phonebookSnapshot) {
            if (contactSnapshot.connectionState == ConnectionState.waiting ||
                phonebookSnapshot.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator());
            }

            final contactFavorites = contactSnapshot.data ?? [];
            final phonebookFavorites = phonebookSnapshot.data ?? [];
            
            final totalCount = contactFavorites.length + phonebookFavorites.length;

            if (totalCount == 0) {
              return Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.star_border, size: 80, color: Colors.grey[400]),
                    const SizedBox(height: 16),
                    const Text(
                      '즐겨찾기가 없습니다',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w600,
                        color: Colors.grey,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      '연락처나 단말번호에서 별 아이콘을 눌러\n즐겨찾기에 추가하세요',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 14,
                        color: Colors.grey[600],
                      ),
                    ),
                  ],
                ),
              );
            }

            return ListView(
              children: [
                // 단말번호 즐겨찾기 섹션
                if (phonebookFavorites.isNotEmpty) ...[
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                    child: Row(
                      children: [
                        const Icon(Icons.phone_android, size: 20, color: Colors.green),
                        const SizedBox(width: 8),
                        Text(
                          '단말번호 (${phonebookFavorites.length})',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: Colors.grey[700],
                          ),
                        ),
                      ],
                    ),
                  ),
                  ...phonebookFavorites.map((contact) => _buildPhonebookContactListTile(contact)),
                ],
                
                // 연락처 즐겨찾기 섹션
                if (contactFavorites.isNotEmpty) ...[
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                    child: Row(
                      children: [
                        const Icon(Icons.contacts, size: 20, color: Colors.blue),
                        const SizedBox(width: 8),
                        Text(
                          '연락처 (${contactFavorites.length})',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: Colors.grey[700],
                          ),
                        ),
                      ],
                    ),
                  ),
                  ...contactFavorites.map((contact) => _buildContactListTile(contact)),
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

    return StreamBuilder<List<CallHistoryModel>>(
      stream: _databaseService.getUserCallHistory(userId),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        final callHistory = snapshot.data ?? [];

        if (callHistory.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.history, size: 80, color: Colors.grey[300]),
                const SizedBox(height: 20),
                const Text(
                  '통화 기록이 없습니다',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                    color: Colors.grey,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  '첫 통화를 시작해보세요',
                  style: TextStyle(
                    fontSize: 14,
                    color: Colors.grey[500],
                  ),
                ),
              ],
            ),
          );
        }

        return ListView.separated(
          padding: const EdgeInsets.symmetric(vertical: 8),
          itemCount: callHistory.length,
          separatorBuilder: (context, index) => Divider(
            height: 1,
            thickness: 0.5,
            color: Colors.grey[200],
            indent: 76,
          ),
          itemBuilder: (context, index) {
            final call = callHistory[index];
            final callTypeColor = _getCallTypeColor(call.callType);
            final callTypeIcon = _getCallTypeIcon(call.callType);
            
            return Container(
              margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.03),
                    blurRadius: 4,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: ListTile(
                contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                onTap: () => _showCallDetailDialog(call), // 통화 상세 다이얼로그
                // 🎨 컬러풀한 아이콘 (원형 배경)
                leading: Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [
                        callTypeColor.withOpacity(0.8),
                        callTypeColor,
                      ],
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: callTypeColor.withOpacity(0.3),
                        blurRadius: 8,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: Icon(
                    callTypeIcon,
                    color: Colors.white,
                    size: 24,
                  ),
                ),
                // 📝 발신자 정보
                title: Row(
                  children: [
                    Expanded(
                      child: Text(
                        call.contactName ?? call.phoneNumber,
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          color: Color(0xFF1a1a1a),
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    // 통화 시간 배지
                    if (call.duration != null)
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: callTypeColor.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: callTypeColor.withOpacity(0.3),
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
                subtitle: Padding(
                  padding: const EdgeInsets.only(top: 6),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // 통화 시간
                      Row(
                        children: [
                          Icon(
                            Icons.schedule,
                            size: 14,
                            color: Colors.grey[500],
                          ),
                          const SizedBox(width: 4),
                          Text(
                            _formatDateTime(call.callTime),
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.grey[600],
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
                              color: Colors.grey[500],
                            ),
                            const SizedBox(width: 4),
                            Text(
                              call.phoneNumber,
                              style: TextStyle(
                                fontSize: 12,
                                color: Colors.grey[700],
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                      ),
                      // 단말번호 정보 (클릭투콜 발신 시 착신전환 정보 포함)
                      if (call.extensionUsed != null)
                        _buildExtensionInfo(call),
                      // 수신번호 → 단말번호 배지 (착신 통화만)
                      if (call.callType == CallType.incoming && call.statusText.isNotEmpty)
                        Padding(
                          padding: const EdgeInsets.only(top: 4),
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 3,
                            ),
                            decoration: BoxDecoration(
                              color: call.statusColor?.withOpacity(0.15),
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(
                                color: call.statusColor?.withOpacity(0.5) ?? Colors.grey,
                                width: 1,
                              ),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  call.status == 'device_answered' 
                                    ? Icons.phone_in_talk_rounded 
                                    : Icons.notifications_active_rounded,
                                  size: 12,
                                  color: call.statusColor,
                                ),
                                const SizedBox(width: 4),
                                // 수신번호 → 단말번호 형식으로 표시
                                if (call.receiverNumber != null && call.receiverNumber!.isNotEmpty && call.extensionUsed != null)
                                  Text(
                                    '${call.receiverNumber} → ${call.extensionUsed}',
                                    style: TextStyle(
                                      fontSize: 11,
                                      fontWeight: FontWeight.w700,
                                      color: call.statusColor,
                                      letterSpacing: -0.3,
                                    ),
                                  )
                                else if (call.receiverNumber != null && call.receiverNumber!.isNotEmpty)
                                  Text(
                                    call.receiverNumber!,
                                    style: TextStyle(
                                      fontSize: 11,
                                      fontWeight: FontWeight.w700,
                                      color: call.statusColor,
                                      letterSpacing: -0.3,
                                    ),
                                  )
                                else
                                  Text(
                                    call.statusText,
                                    style: TextStyle(
                                      fontSize: 11,
                                      fontWeight: FontWeight.w700,
                                      color: call.statusColor,
                                      letterSpacing: -0.3,
                                    ),
                                  ),
                              ],
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
                // 🎯 액션 버튼
                trailing: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // 연락처 추가 버튼
                    Container(
                      decoration: BoxDecoration(
                        color: Colors.green.withOpacity(0.1),
                        shape: BoxShape.circle,
                      ),
                      child: IconButton(
                        icon: const Icon(Icons.person_add_rounded, size: 20),
                        color: Colors.green[700],
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
                            const Color(0xFF2196F3).withOpacity(0.8),
                            const Color(0xFF2196F3),
                          ],
                        ),
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(
                            color: const Color(0xFF2196F3).withOpacity(0.3),
                            blurRadius: 8,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      child: IconButton(
                        icon: const Icon(Icons.phone, size: 20),
                        color: Colors.white,
                        onPressed: () => _showCallMethodDialog(call.phoneNumber),
                        tooltip: '전화 걸기',
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildContactsTab() {
    final userId = context.watch<AuthService>().currentUser?.uid ?? '';

    return Column(
      children: [
        // 상단 컨트롤 바
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Colors.grey[100],
            border: Border(
              bottom: BorderSide(color: Colors.grey[300]!),
            ),
          ),
          child: Row(
            children: [
              // 장치 연락처 토글 버튼
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: _isLoadingDeviceContacts ? null : _toggleDeviceContacts,
                  icon: _isLoadingDeviceContacts
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : Icon(_showDeviceContacts ? Icons.cloud_done : Icons.smartphone),
                  label: Text(
                    _showDeviceContacts ? '저장된 연락처' : '장치 연락처',
                    style: const TextStyle(fontSize: 13),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _showDeviceContacts
                        ? const Color(0xFF2196F3)
                        : Colors.white,
                    foregroundColor: _showDeviceContacts
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
                  backgroundColor: Colors.green,
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
              fillColor: Colors.grey[50],
            ),
            onChanged: (value) {
              setState(() {});
            },
          ),
        ),

        // 연락처 목록
        Expanded(
          child: _showDeviceContacts
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
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.contacts, size: 80, color: Colors.grey[400]),
                const SizedBox(height: 16),
                Text(
                  _searchController.text.isNotEmpty
                      ? '검색 결과가 없습니다'
                      : '저장된 연락처가 없습니다',
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                    color: Colors.grey,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  '우측 상단 추가 버튼을 눌러 연락처를 추가하세요',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 14,
                    color: Colors.grey[600],
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
    if (_deviceContacts.isEmpty) {
      return const Center(
        child: Text('장치 연락처를 불러오는 중...'),
      );
    }

    var contacts = _deviceContacts;

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
      background: Container(
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 20),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [Colors.red.withOpacity(0.8), Colors.red],
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
              TextButton(
                onPressed: () => Navigator.of(context).pop(true),
                style: TextButton.styleFrom(foregroundColor: Colors.red),
                child: const Text('삭제'),
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
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('${contact.name} 연락처가 삭제되었습니다'),
                backgroundColor: Colors.green,
                duration: const Duration(seconds: 2),
              ),
            );
          }
        } catch (e) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('연락처 삭제 실패: $e'),
                backgroundColor: Colors.red,
                duration: const Duration(seconds: 3),
              ),
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
    return ListTile(
      leading: CircleAvatar(
        backgroundColor: contact.isFavorite
            ? Colors.amber[100]
            : const Color(0xFF2196F3).withAlpha(51),
        child: Icon(
          contact.isFavorite ? Icons.star : Icons.person,
          color: contact.isFavorite ? Colors.amber[700] : const Color(0xFF2196F3),
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
                color: Colors.blue[50],
                borderRadius: BorderRadius.circular(4),
                border: Border.all(color: Colors.blue[200]!),
              ),
              child: const Text(
                '장치',
                style: TextStyle(fontSize: 10, color: Colors.blue),
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
              style: TextStyle(fontSize: 12, color: Colors.grey[600]),
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
                color: contact.isFavorite ? Colors.amber : Colors.grey,
              ),
              onPressed: () => _toggleFavorite(contact),
              tooltip: contact.isFavorite ? '즐겨찾기 해제' : '즐겨찾기 추가',
            ),
            // 수정 버튼
            IconButton(
              icon: const Icon(Icons.edit, color: Colors.grey),
              onPressed: () => _showEditContactDialog(contact),
              tooltip: '수정',
            ),
          ],
          if (isDeviceContact)
            // 장치 연락처에서 즐겨찾기 추가 버튼
            IconButton(
              icon: const Icon(Icons.star_border, color: Colors.amber),
              onPressed: () => _addDeviceContactToFavorites(contact),
              tooltip: '즐겨찾기에 추가',
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

  /// 🔥 단말번호 및 착신전환 정보 표시
  /// 클릭투콜 발신 시 저장된 착신전환 정보만 표시
  Widget _buildExtensionInfo(CallHistoryModel call) {
    final isForwardEnabled = call.callForwardEnabled == true;
    final destinationNumber = call.callForwardDestination ?? '';
    
    // 상태에 따른 색상 결정
    Color badgeColor;
    Color textColor;
    if (isForwardEnabled) {
      // 착신전환 활성화: 주황색
      badgeColor = Colors.orange.withOpacity(0.1);
      textColor = Colors.orange[700]!;
    } else if (call.status == 'device_answered') {
      // 단말수신: 녹색
      badgeColor = Colors.green.withOpacity(0.1);
      textColor = Colors.green[700]!;
    } else if (call.status == 'confirmed') {
      // 알림확인: 파란색
      badgeColor = Colors.blue.withOpacity(0.1);
      textColor = Colors.blue[700]!;
    } else {
      // 기본: 파란색
      badgeColor = Colors.blue.withOpacity(0.1);
      textColor = Colors.blue[700]!;
    }
    
    return Padding(
      padding: const EdgeInsets.only(top: 4),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.symmetric(
              horizontal: 6,
              vertical: 2,
            ),
            decoration: BoxDecoration(
              color: badgeColor,
              borderRadius: BorderRadius.circular(8),
              border: isForwardEnabled
                  ? Border.all(color: Colors.orange.withOpacity(0.3), width: 1)
                  : null,
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.phone_android,
                  size: 10,
                  color: textColor,
                ),
                const SizedBox(width: 3),
                Text(
                  call.extensionUsed ?? '',
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w600,
                    color: textColor,
                  ),
                ),
                
                // 착신전환 활성화 시에만 화살표와 착신번호 표시
                if (isForwardEnabled && destinationNumber.isNotEmpty) ...[
                  const SizedBox(width: 3),
                  Icon(
                    Icons.arrow_forward_rounded,
                    size: 11,
                    color: Colors.orange[700],
                  ),
                  const SizedBox(width: 3),
                  Text(
                    destinationNumber,
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w600,
                      color: Colors.orange[700],
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
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

  Color _getCallTypeColor(CallType type) {
    switch (type) {
      case CallType.incoming:
        return Colors.green;
      case CallType.outgoing:
        return Colors.blue;
      case CallType.missed:
        return Colors.red;
    }
  }

  String _formatDateTime(DateTime dateTime) {
    // yyyy.MM.dd HH:mm:ss 형식
    return '${dateTime.year}.${dateTime.month.toString().padLeft(2, '0')}.${dateTime.day.toString().padLeft(2, '0')} '
           '${dateTime.hour.toString().padLeft(2, '0')}:${dateTime.minute.toString().padLeft(2, '0')}:${dateTime.second.toString().padLeft(2, '0')}';
  }

  // 기능번호 판별 (즐겨찾기, 최근통화 전용)
  bool _isFeatureCode(String phoneNumber) {
    // *로 시작하는 번호는 기능번호로 판별
    return phoneNumber.startsWith('*');
  }

  /// 🔥 착신전환 상태를 확인하여 발신 방법 결정
  /// - 착신전환 비활성화: 즉시 클릭투콜 실행
  /// - 착신전환 활성화: 발신 방법 선택 다이얼로그 표시
  Future<void> _showCallMethodDialog(String phoneNumber) async {
    // 기능번호는 다이얼로그 없이 바로 Click to Call
    if (_isFeatureCode(phoneNumber)) {
      if (kDebugMode) {
        debugPrint('🌟 즐곊/최근통화 기능번호 감지: $phoneNumber');
      }
      _handleFeatureCodeCall(phoneNumber);
      return;
    }

    // 5자리 이하 숫자만 있는 단말번호는 자동으로 클릭투콜 실행 (다이얼로그 없음)
    final cleanNumber = phoneNumber.replaceAll(RegExp(r'[^0-9]'), '');
    if (cleanNumber.length > 0 && cleanNumber.length <= 5 && cleanNumber == phoneNumber) {
      if (kDebugMode) {
        debugPrint('🔥 5자리 이하 내선번호 감지: $phoneNumber');
        debugPrint('📞 자동으로 클릭투콜 실행 (다이얼로그 건너뛰기)');
      }
      _handleFeatureCodeCall(phoneNumber);
      return;
    }

    // 🔍 착신전환 상태 확인 (현재 선택된 단말번호 기준)
    try {
      final userId = context.read<AuthService>().currentUser?.uid ?? '';
      final selectedExtension = context.read<SelectedExtensionProvider>().selectedExtension;
      
      if (selectedExtension == null) {
        throw Exception('선택된 단말번호가 없습니다.\n왼쪽 상단 프로필에서 단말번호를 등록해주세요.');
      }

      final callForwardInfo = await _databaseService
          .getCallForwardInfoOnce(userId, selectedExtension.extension);
      
      final isForwardEnabled = callForwardInfo?.isEnabled ?? false;

      if (kDebugMode) {
        debugPrint('');
        debugPrint('🔍 ========== 최근통화 발신 방법 결정 ==========');
        debugPrint('   📞 발신 대상: $phoneNumber');
        debugPrint('   📱 단말번호: ${selectedExtension.extension}');
        debugPrint('   🔄 착신전환 상태: ${isForwardEnabled ? "활성화" : "비활성화"}');
        if (isForwardEnabled) {
          debugPrint('   ➡️  착신번호: ${callForwardInfo?.destinationNumber ?? "미설정"}');
        }
        debugPrint('================================================');
        debugPrint('');
      }

      // 🎯 착신전환 비활성화 시: 즉시 클릭투콜 실행
      if (!isForwardEnabled) {
        if (kDebugMode) {
          debugPrint('✅ 착신전환 비활성화 → 즉시 클릭투콜 실행');
        }
        _handleFeatureCodeCall(phoneNumber);
        return;
      }

      // 🎯 착신전환 활성화 시: 발신 방법 선택 다이얼로그 표시
      if (kDebugMode) {
        debugPrint('⚠️  착신전환 활성화 → 발신 방법 선택 다이얼로그 표시');
      }

    } catch (e) {
      if (kDebugMode) {
        debugPrint('❌ 착신전환 상태 확인 실패: $e');
        debugPrint('   → 기본 동작: 발신 방법 선택 다이얼로그 표시');
      }
    }

    // 일반 전화번호는 발신 방법 선택 다이얼로그 표시
    showDialog(
      context: context,
      builder: (context) => CallMethodDialog(
        phoneNumber: phoneNumber, 
        autoCallShortExtension: false,
        onClickToCallSuccess: () {
          // 🔄 클릭투콜 성공 시 최근통화 탭으로 전환
          if (mounted) {
            setState(() {
              _currentTabIndex = 1; // 최근통화 탭
            });
            if (kDebugMode) {
              debugPrint('✅ 클릭투콜 성공 → 최근통화 탭으로 전환');
            }
          }
        },
      ),
    );
  }

  // 안전한 SnackBar 표시 헬퍼 (위젯이 dispose되어도 에러 없음)
  void _safeShowSnackBar(SnackBar snackBar) {
    if (!mounted) return;
    
    try {
      ScaffoldMessenger.of(context).showSnackBar(snackBar);
    } catch (e) {
      // 위젯이 이미 dispose된 경우 무시
      if (kDebugMode) {
        debugPrint('⚠️ SnackBar 표시 건너뜀 (위젯 비활성화): $e');
      }
    }
  }
  
  // 안전한 SnackBar 클리어 헬퍼
  void _safeClearSnackBars() {
    if (!mounted) return;
    
    try {
      ScaffoldMessenger.of(context).clearSnackBars();
    } catch (e) {
      // 위젯이 이미 dispose된 경우 무시
      if (kDebugMode) {
        debugPrint('⚠️ SnackBar 클리어 건너뜀 (위젯 비활성화): $e');
      }
    }
  }

  // 기능번호 자동 발신 (Click to Call API 직접 호출)
  Future<void> _handleFeatureCodeCall(String phoneNumber) async {
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

      if (kDebugMode) {
        debugPrint('🌟 즐곊/최근통화 기능번호 자동 발신 시작 (다이얼로그 건너뛰기)');
        debugPrint('📞 선택된 단말번호: ${selectedExtension.extension}');
        debugPrint('👤 단말 이름: ${selectedExtension.name}');
        debugPrint('🔑 COS ID: ${selectedExtension.classOfServicesId}');
        debugPrint('🎯 기능번호: $phoneNumber');
      }

      // CID 설정: 고정값 사용
      String cidName = '클릭투콜';                // 고정값: "클릭투콜"
      String cidNumber = phoneNumber;      // callee 값 사용

      if (kDebugMode) {
        debugPrint('📞 CID Name: $cidName (고정값)');
        debugPrint('📞 CID Number: $cidNumber (callee 값)');
      }

      // 로딩 표시 (안전한 헬퍼 사용)
      _safeShowSnackBar(
        const SnackBar(
          content: Row(
            children: [
              SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                ),
              ),
              SizedBox(width: 16),
              Text('기능번호 발신 중...'),
            ],
          ),
          duration: Duration(seconds: 2),
        ),
      );

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

      // 성공 메시지 (안전한 헬퍼 사용)
      _safeClearSnackBars();
      _safeShowSnackBar(
        SnackBar(
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                '🌟 기능번호 발신 완료',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 4),
              Text('단말: ${selectedExtension.name.isEmpty ? selectedExtension.extension : selectedExtension.name}'),
              Text('기능번호: $phoneNumber'),
            ],
          ),
          backgroundColor: Colors.orange,
          duration: const Duration(seconds: 3),
          behavior: SnackBarBehavior.floating,
        ),
      );
      
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
      // 에러 메시지 (안전한 헬퍼 사용)
      _safeClearSnackBars();
      _safeShowSnackBar(
        SnackBar(
          content: Text('기능번호 발신 실패: $e'),
          backgroundColor: Colors.red,
          duration: const Duration(seconds: 4),
        ),
      );
      
      // ignore: avoid_print
      print('❌ [call_tab 기능번호] 발신 오류 발생');
      // ignore: avoid_print
      print('   에러: $e');
      // ignore: avoid_print
      print('   스택 트레이스: $stackTrace');
    }
  }

  Future<void> _toggleFavorite(ContactModel contact) async {
    try {
      await _databaseService.updateContact(
        contact.id,
        {'isFavorite': !contact.isFavorite},
      );

      // 성공 메시지 (안전한 헬퍼 사용)
      _safeShowSnackBar(
        SnackBar(
          content: Row(
            children: [
              Icon(
                contact.isFavorite ? Icons.star_border : Icons.star,
                color: Colors.white,
                size: 20,
              ),
              const SizedBox(width: 12),
              Text(
                contact.isFavorite
                    ? '즐겨찾기에서 제거되었습니다'
                    : '즐겨찾기에 추가되었습니다',
              ),
            ],
          ),
          backgroundColor: contact.isFavorite ? Colors.grey[700] : Colors.amber[700],
          behavior: SnackBarBehavior.floating,
          duration: const Duration(seconds: 2),
        ),
      );
    } catch (e) {
      // 에러 메시지 (안전한 헬퍼 사용)
      _safeShowSnackBar(
        SnackBar(content: Text('오류 발생: $e')),
      );
    }
  }

  Future<void> _toggleDeviceContacts() async {
    // 이미 장치 연락처를 표시 중이면 숨김
    if (_showDeviceContacts) {
      setState(() {
        _showDeviceContacts = false;
        _deviceContacts = [];
      });
      return;
    }

    setState(() => _isLoadingDeviceContacts = true);

    try {
      if (kDebugMode) {
        debugPrint('');
        debugPrint('🔍 ===== _toggleDeviceContacts START =====');
      }
      
      // 🎯 STEP 1: 현재 권한 상태 확인 (flutter_contacts 사용)
      final hasPermission = await _mobileContactsService.hasContactsPermission();
      
      if (kDebugMode) {
        debugPrint('🔍 _toggleDeviceContacts: hasPermission = $hasPermission');
      }
      
      // 🎯 STEP 2: 권한이 없으면 권한 요청
      if (!hasPermission) {
        if (kDebugMode) {
          debugPrint('⚠️ _toggleDeviceContacts: 권한 없음 - 사용자에게 권한 요청');
        }
        
        if (mounted) {
          setState(() => _isLoadingDeviceContacts = false);
          
          // 사용자에게 권한 요청 의사 확인
          final shouldRequest = await _showPermissionRequestDialog();
          if (shouldRequest != true) {
            return;
          }
          
          setState(() => _isLoadingDeviceContacts = true);
          
          // 시스템 권한 다이얼로그 표시 (flutter_contacts 사용)
          final permissionStatus = await _mobileContactsService.requestContactsPermission();
          
          if (kDebugMode) {
            debugPrint('📱 _toggleDeviceContacts: requestContactsPermission 결과');
            debugPrint('   - permissionStatus: $permissionStatus');
            debugPrint('   - isGranted: ${permissionStatus.isGranted}');
          }
          
          // 권한 거부 시 설정으로 이동 안내
          if (!permissionStatus.isGranted) {
            if (kDebugMode) {
              debugPrint('❌ _toggleDeviceContacts: 권한 거부됨');
            }
            setState(() => _isLoadingDeviceContacts = false);
            
            if (mounted) {
              _showPermissionDeniedDialog();
            }
            return;
          }
        } else {
          setState(() => _isLoadingDeviceContacts = false);
          return;
        }
      }

      // 🎯 STEP 3: 연락처 가져오기
      if (mounted) {
        if (kDebugMode) {
          debugPrint('✅ _toggleDeviceContacts: 권한 확인 완료 - 연락처 가져오기 시작');
        }
        
        final userId = context.read<AuthService>().currentUser?.uid ?? '';
        final contacts = await _mobileContactsService.getDeviceContacts(userId);
        
        if (kDebugMode) {
          debugPrint('📱 _toggleDeviceContacts: 연락처 ${contacts.length}개 가져옴');
          debugPrint('🔍 ===== _toggleDeviceContacts END =====');
          debugPrint('');
        }

        if (mounted) {
          setState(() {
            _deviceContacts = contacts;
            _showDeviceContacts = true;
            _isLoadingDeviceContacts = false;
          });

          if (contacts.isEmpty) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('장치에 저장된 연락처가 없습니다.'),
                backgroundColor: Colors.orange,
                duration: Duration(seconds: 2),
              ),
            );
          } else {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('${contacts.length}개의 연락처를 불러왔습니다.'),
                backgroundColor: Colors.green,
                duration: const Duration(seconds: 2),
              ),
            );
          }
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoadingDeviceContacts = false);
        
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('연락처 불러오기 실패: ${e.toString().split(':').last.trim()}'),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 3),
          ),
        );
      }
    }
  }

  /// 권한 요청 다이얼로그 표시 (초기 요청)
  Future<bool?> _showPermissionRequestDialog() {
    return showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.contacts, color: Color(0xFF2196F3)),
            SizedBox(width: 12),
            Expanded(child: Text('연락처 권한 필요')),
          ],
        ),
        content: const Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '장치 연락처를 불러오려면 연락처 접근 권한이 필요합니다.',
              style: TextStyle(fontSize: 15),
            ),
            SizedBox(height: 12),
            Text(
              '다음 화면에서 "허용"을 선택해주세요.',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: Color(0xFF2196F3),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('취소'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF2196F3),
              foregroundColor: Colors.white,
            ),
            child: const Text('권한 요청'),
          ),
        ],
      ),
    );
  }

  /// 권한 거부 다이얼로그 표시 (설정으로 이동)
  void _showPermissionDeniedDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.warning_amber_rounded, color: Colors.orange),
            SizedBox(width: 12),
            Expanded(child: Text('연락처 권한 거부됨')),
          ],
        ),
        content: const Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '연락처 권한이 거부되었습니다.',
              style: TextStyle(fontSize: 15),
            ),
            SizedBox(height: 12),
            Text(
              '장치 연락처를 사용하려면 설정에서 권한을 허용해주세요.',
              style: TextStyle(fontSize: 14),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('취소'),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.of(context).pop();
              // permission_handler의 openAppSettings 사용
              await openAppSettings();
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.orange,
              foregroundColor: Colors.white,
            ),
            child: const Text('설정 열기'),
          ),
        ],
      ),
    );
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
    
    // linkedid가 없으면 에러 표시
    if (call.linkedid == null || call.linkedid!.isEmpty) {
      if (kDebugMode) {
        debugPrint('❌ Linkedid가 없어 통화 상세를 조회할 수 없음');
      }
      
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('통화 상세 정보를 불러올 수 없습니다\n(Linkedid가 저장되지 않았습니다)'),
          backgroundColor: Colors.red,
          duration: Duration(seconds: 3),
        ),
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

  void _showAddContactFromCallDialog(CallHistoryModel call) {
    final userId = context.read<AuthService>().currentUser?.uid ?? '';
    
    // 이미 이름이 있는 경우 (연락처가 있음)
    if (call.contactName != null && call.contactName!.isNotEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('${call.contactName}은(는) 이미 연락처에 등록되어 있습니다'),
          backgroundColor: Colors.orange,
        ),
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
      
      // 🔥 중복 체크: 전화번호 기준으로 이미 존재하는 연락처 확인
      final existingContact = await _databaseService.findContactByPhone(
        userId, 
        contact.phoneNumber,
      );
      
      if (existingContact != null) {
        // 중복된 연락처가 이미 존재하는 경우
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Row(
                children: [
                  const Icon(Icons.info_outline, color: Colors.white, size: 20),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          '이미 추가된 연락처입니다',
                          style: TextStyle(fontWeight: FontWeight.bold),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          '${contact.phoneNumber}는 이미 즐겨찾기에 저장되어 있습니다.',
                          style: const TextStyle(fontSize: 12),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              backgroundColor: Colors.orange[700],
              behavior: SnackBarBehavior.floating,
              duration: const Duration(seconds: 4),
              action: SnackBarAction(
                label: '보기',
                textColor: Colors.white,
                onPressed: () {
                  setState(() {
                    _currentTabIndex = 3; // 즐겨찾기 탭으로 이동
                  });
                },
              ),
            ),
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

      await _databaseService.addContact(newContact);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const Icon(Icons.star, color: Colors.white, size: 20),
                const SizedBox(width: 12),
                Expanded(
                  child: Text('${contact.name}을(를) 즐겨찾기에 추가했습니다'),
                ),
              ],
            ),
            backgroundColor: Colors.amber[700],
            behavior: SnackBarBehavior.floating,
            action: SnackBarAction(
              label: '보기',
              textColor: Colors.white,
              onPressed: () {
                setState(() {
                  _currentTabIndex = 3; // 즐겨찾기 탭으로 이동
                });
              },
            ),
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

  // 이름 번역 함수
  String _translateName(String name) {
    return _nameTranslations[name] ?? name;
  }

  // 단말번호 연락처 리스트 타일
  Widget _buildPhonebookContactListTile(PhonebookContactModel contact) {
    Color categoryColor = Colors.blue;
    IconData categoryIcon = Icons.phone;

    if (contact.category == 'Extensions') {
      categoryColor = Colors.green;
      categoryIcon = Icons.phone_android;
    } else if (contact.category == 'Feature Codes') {
      categoryColor = Colors.orange;
      categoryIcon = Icons.star;
    }

    // 이름 번역 (Feature Codes 이름만)
    final translatedName = _translateName(contact.name);
    
    // categoryDisplay는 이미 DB에 한글로 저장되어 있음 (fromApi에서 변환됨)
    final categoryDisplay = contact.categoryDisplay;

    return ListTile(
      leading: CircleAvatar(
        backgroundColor: Colors.amber[100],
        child: Icon(categoryIcon, color: Colors.amber[700]),
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
              style: TextStyle(fontSize: 12, color: Colors.grey[600]),
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
