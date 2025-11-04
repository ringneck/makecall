import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:provider/provider.dart';
import 'package:permission_handler/permission_handler.dart';
import '../../services/auth_service.dart';
import '../../services/database_service.dart';
import '../../services/mobile_contacts_service.dart';
import '../../services/api_service.dart';
import '../../models/contact_model.dart';
import '../../models/call_history_model.dart';
import '../../models/phonebook_model.dart';
import '../../providers/selected_extension_provider.dart';
import 'dialpad_screen.dart';
import 'phonebook_tab.dart';
import '../../widgets/call_method_dialog.dart';
import '../../widgets/add_contact_dialog.dart';
import '../../widgets/profile_drawer.dart';
import '../../widgets/extension_drawer.dart';

class CallTab extends StatefulWidget {
  const CallTab({super.key});

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

  // 영어 이름을 한글로 번역하는 매핑 테이블
  final Map<String, String> _nameTranslations = {
    'Echo Test': '에코테스트',
    'Call Forward Immediately - Toggle': '즉시 착신 전환 토글',
    'Set CF Immediately Number': '즉시 착신 전환 번호 설정',
    'Ring Groups': '링그룹',
    'Conferences': '음성회의',
  };

  @override
  void initState() {
    super.initState();
    
    // 🚀 고급 개발자 패턴: 순차적 초기화 체인
    // 1️⃣ 설정 확인 먼저 → 2️⃣ 설정 완료 시에만 단말번호 조회
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      // AuthService 리스너 등록 (사용자 전환 감지)
      final authService = context.read<AuthService>();
      authService.addListener(_onUserModelChanged);
      
      // 순차적 초기화 실행
      await _initializeSequentially();
    });
  }
  
  /// 🔄 순차적 초기화 체인
  /// 고급 패턴: Early Return + Fail-Fast + Single Responsibility
  Future<void> _initializeSequentially() async {
    if (!mounted) return;
    
    // 1️⃣ STEP 1: 설정 확인 (최우선)
    await _checkSettingsAndShowGuide();
    
    if (!mounted) return;
    
    // 2️⃣ STEP 2: 설정이 완료된 경우에만 단말번호 조회
    final authService = context.read<AuthService>();
    final userModel = authService.currentUserModel;
    
    // Early Return: 설정 미완료 시 단말번호 조회 스킵
    if (userModel == null) return;
    if (userModel.apiBaseUrl == null || userModel.apiBaseUrl!.isEmpty) return;
    if (userModel.companyId == null || userModel.companyId!.isEmpty) return;
    if (userModel.appKey == null || userModel.appKey!.isEmpty) return;
    
    // 설정 완료 → 단말번호 초기화 실행
    await _initializeExtensions();
  }
  
  @override
  void dispose() {
    // AuthService 리스너 제거
    final authService = context.read<AuthService>();
    authService.removeListener(_onUserModelChanged);
    
    _searchController.dispose();
    super.dispose();
  }
  
  // userModel 변경 감지 콜백
  void _onUserModelChanged() {
    if (kDebugMode) {
      debugPrint('🔔 AuthService 리스너 트리거: userModel 변경 감지');
    }
    
    // userModel이 로드되면 설정 체크 재실행
    final authService = context.read<AuthService>();
    if (authService.currentUserModel != null && !_hasCheckedSettings) {
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
  
  /// 🎯 단말번호 초기화 (고급 개발자 패턴: 간결성 + 가독성)
  /// 
  /// Click to Call 기능을 위해 사용자의 첫 번째 단말번호를 Provider에 설정
  /// - Early Return: 조건 미충족 시 즉시 반환
  /// - Single Responsibility: 단말번호 로드 및 Provider 설정만 담당
  /// - Fail Silent: 에러 발생 시 조용히 처리 (사용자 경험 저해 방지)
  Future<void> _initializeExtensions() async {
    // Early Return: userId 검증
    final userId = context.read<AuthService>().currentUser?.uid;
    if (userId == null || userId.isEmpty) return;
    
    try {
      // 단말번호 조회
      final extensions = await _databaseService.getMyExtensions(userId).first;
      if (extensions.isEmpty || !mounted) return;
      
      // Provider 상태 업데이트 (선택된 단말번호가 없는 경우만)
      final provider = context.read<SelectedExtensionProvider>();
      if (provider.selectedExtension == null) {
        provider.setSelectedExtension(extensions.first);
        if (kDebugMode) {
          debugPrint('✅ 단말번호 초기화: ${extensions.first.extension}');
        }
      }
    } catch (e) {
      // Fail Silent: 단말번호 초기화 실패는 치명적이지 않음
      if (kDebugMode) debugPrint('⚠️ 단말번호 초기화 실패: $e');
    }
  }
  
  // 설정 확인 및 안내 다이얼로그 표시
  Future<void> _checkSettingsAndShowGuide() async {
    if (kDebugMode) {
      debugPrint('🔍 _checkSettingsAndShowGuide() 호출됨');
      debugPrint('   - _hasCheckedSettings: $_hasCheckedSettings');
    }
    
    // 이미 체크를 완료했으면 다시 하지 않음
    if (_hasCheckedSettings) {
      if (kDebugMode) {
        debugPrint('✅ 설정 체크 이미 완료됨 - 건너뛰기');
      }
      return;
    }
    
    final authService = context.read<AuthService>();
    final userModel = authService.currentUserModel;
    final userId = authService.currentUser?.uid ?? '';
    
    if (kDebugMode) {
      debugPrint('👤 현재 상태 확인:');
      debugPrint('   - userModel: ${userModel != null ? "존재" : "null"}');
      debugPrint('   - userId: $userId');
    }
    
    // userModel이 없으면 아직 로드 중이므로 대기
    if (userModel == null) {
      if (kDebugMode) {
        debugPrint('⏳ userModel 로딩 중 - 설정 체크 건너뛰기');
        debugPrint('💡 userModel 로드 완료 시 AuthService 리스너가 자동으로 재시도합니다');
      }
      return;
    }
    
    // 디버그: 사용자 정보 로깅
    if (kDebugMode) {
      debugPrint('👤 사용자 정보 확인:');
      debugPrint('   - userModel: 존재');
      debugPrint('   - email: "${userModel.email}" (길이: ${userModel.email.length})');
      debugPrint('   - organizationName: "${userModel.organizationName}"');
      debugPrint('   - userId: $userId');
    }
    
    // 필수 설정 항목 확인
    final hasWebSocketSettings = userModel.websocketServerUrl != null && 
                                  userModel.websocketServerUrl!.isNotEmpty;
    final hasApiBaseUrl = userModel.apiBaseUrl != null && 
                         userModel.apiBaseUrl!.isNotEmpty;
    final hasCompanyId = userModel.companyId != null && 
                        userModel.companyId!.isNotEmpty;
    final hasAppKey = userModel.appKey != null && 
                     userModel.appKey!.isNotEmpty;
    
    // 등록된 단말번호 확인
    final extensionsSnapshot = await _databaseService.getMyExtensions(userId).first;
    final hasSavedExtensions = extensionsSnapshot.isNotEmpty;
    
    if (kDebugMode) {
      debugPrint('🔍 설정 체크 시작');
      debugPrint('  - WebSocket 설정: $hasWebSocketSettings (${userModel.websocketServerUrl ?? "없음"})');
      debugPrint('  - API BaseURL 설정: $hasApiBaseUrl (${userModel.apiBaseUrl ?? "없음"})');
      debugPrint('  - 회사ID 설정: $hasCompanyId (${userModel.companyId ?? "없음"})');
      debugPrint('  - AppKey 설정: $hasAppKey (${userModel.appKey ?? "없음"})');
      debugPrint('  - 등록된 단말번호: $hasSavedExtensions (${extensionsSnapshot.length}개)');
    }
    
    // 모든 설정이 완료되었으면 체크 플래그 설정
    if (hasWebSocketSettings && hasApiBaseUrl && hasCompanyId && hasAppKey && hasSavedExtensions) {
      _hasCheckedSettings = true;
      if (kDebugMode) {
        debugPrint('✅ 모든 설정 완료 - 더 이상 팝업 표시 안 함');
      }
      return;
    }
    
    // 1. WebSocket/REST API 설정이 없는 경우
    if (!hasWebSocketSettings || !hasApiBaseUrl || !hasCompanyId || !hasAppKey) {
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
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              (userModel.organizationName?.isNotEmpty ?? false)
                                  ? userModel.organizationName!
                                  : userModel.email.isNotEmpty
                                      ? userModel.email
                                      : authService.currentUser?.email ?? '사용자',
                              style: const TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            if (userModel.email.isNotEmpty)
                              Text(
                                userModel.email,
                                style: TextStyle(
                                  fontSize: 12,
                                  color: Colors.grey[600],
                                ),
                              )
                            else if (authService.currentUser?.email != null)
                              Text(
                                authService.currentUser!.email!,
                                style: TextStyle(
                                  fontSize: 12,
                                  color: Colors.grey[600],
                                ),
                              ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                const Text(
                  '통화 기능을 사용하기 위해서는\n다음 설정이 필요합니다:',
                  style: TextStyle(fontSize: 15, fontWeight: FontWeight.w500),
                ),
                const SizedBox(height: 16),
                if (!hasWebSocketSettings) ...[
                  Row(
                    children: const [
                      Icon(Icons.cloud_outlined, size: 20, color: Colors.orange),
                      SizedBox(width: 8),
                      Expanded(
                        child: Text('WebSocket 서버 주소'),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                ],
                if (!hasApiBaseUrl) ...[
                  Row(
                    children: const [
                      Icon(Icons.http, size: 20, color: Colors.orange),
                      SizedBox(width: 8),
                      Expanded(
                        child: Text('REST API 서버 주소'),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                ],
                if (!hasCompanyId) ...[
                  Row(
                    children: const [
                      Icon(Icons.business, size: 20, color: Colors.orange),
                      SizedBox(width: 8),
                      Expanded(
                        child: Text('회사 ID (Company ID)'),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                ],
                if (!hasAppKey) ...[
                  Row(
                    children: const [
                      Icon(Icons.key, size: 20, color: Colors.orange),
                      SizedBox(width: 8),
                      Expanded(
                        child: Text('앱 키 (App Key)'),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                ],
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
                  child: Row(
                    children: const [
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
    
    // 2. 등록된 단말번호가 없는 경우
    if (!hasSavedExtensions) {
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
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              (userModel.organizationName?.isNotEmpty ?? false)
                                  ? userModel.organizationName!
                                  : userModel.email.isNotEmpty
                                      ? userModel.email
                                      : authService.currentUser?.email ?? '사용자',
                              style: const TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            if (userModel.email.isNotEmpty)
                              Text(
                                userModel.email,
                                style: TextStyle(
                                  fontSize: 12,
                                  color: Colors.grey[600],
                                ),
                              )
                            else if (authService.currentUser?.email != null)
                              Text(
                                authService.currentUser!.email!,
                                style: TextStyle(
                                  fontSize: 12,
                                  color: Colors.grey[600],
                                ),
                              ),
                          ],
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
          const PhonebookTab(),        // 0: 단말번호
          _buildCallHistoryTab(),      // 1: 최근통화
          const DialpadScreen(),       // 2: 키패드
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
          return const Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.history, size: 64, color: Colors.grey),
                SizedBox(height: 16),
                Text('통화 기록이 없습니다', style: TextStyle(color: Colors.grey)),
              ],
            ),
          );
        }

        return ListView.builder(
          itemCount: callHistory.length,
          itemBuilder: (context, index) {
            final call = callHistory[index];
            return ListTile(
              leading: Icon(
                _getCallTypeIcon(call.callType),
                color: _getCallTypeColor(call.callType),
              ),
              title: Text(call.contactName ?? call.phoneNumber),
              subtitle: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '${_formatDateTime(call.callTime)}${call.duration != null ? ' · ${call.formattedDuration}' : ''}',
                  ),
                  if (call.extensionUsed != null)
                    Padding(
                      padding: const EdgeInsets.only(top: 2),
                      child: Row(
                        children: [
                          Icon(
                            Icons.phone_android,
                            size: 14,
                            color: Colors.grey[600],
                          ),
                          const SizedBox(width: 4),
                          Text(
                            '단말번호: ${call.extensionUsed}',
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.grey[600],
                            ),
                          ),
                        ],
                      ),
                    ),
                ],
              ),
              trailing: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // 연락처 추가 버튼
                  IconButton(
                    icon: const Icon(Icons.person_add, size: 20),
                    color: Colors.green,
                    onPressed: () => _showAddContactFromCallDialog(call),
                    tooltip: '연락처 추가',
                  ),
                  // 전화 걸기 버튼
                  IconButton(
                    icon: const Icon(Icons.phone),
                    color: const Color(0xFF2196F3),
                    onPressed: () => _showCallMethodDialog(call.phoneNumber),
                    tooltip: '전화 걸기',
                  ),
                ],
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
    final now = DateTime.now();
    final difference = now.difference(dateTime);

    if (difference.inDays == 0) {
      return '${dateTime.hour}:${dateTime.minute.toString().padLeft(2, '0')}';
    } else if (difference.inDays == 1) {
      return '어제';
    } else if (difference.inDays < 7) {
      return '${difference.inDays}일 전';
    } else {
      return '${dateTime.month}/${dateTime.day}';
    }
  }

  // 기능번호 판별 (즐겨찾기, 최근통화 전용)
  bool _isFeatureCode(String phoneNumber) {
    // *로 시작하는 번호는 기능번호로 판별
    return phoneNumber.startsWith('*');
  }

  void _showCallMethodDialog(String phoneNumber) {
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

    // 일반 전화번호는 발신 방법 선택 다이얼로그 표시
    showDialog(
      context: context,
      builder: (context) => CallMethodDialog(phoneNumber: phoneNumber, autoCallShortExtension: false),
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
        throw Exception('선택된 단말번호가 없습니다.\n홈 탭에서 단말번호를 확인해주세요.');
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

      // API 서비스 생성 (동적 API URL 사용)
      final apiService = ApiService(
        baseUrl: userModel!.getApiUrl(useHttps: false), // HTTP 사용
        companyId: userModel.companyId,
        appKey: userModel.appKey,
      );

      // Click to Call API 호출
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
      }

      // 통화 기록 저장
      await _databaseService.addCallHistory(
        CallHistoryModel(
          id: '',
          userId: userId,
          phoneNumber: phoneNumber,
          callType: CallType.outgoing,
          callMethod: CallMethod.extension,
          callTime: DateTime.now(),
          mainNumberUsed: cidNumber,
          extensionUsed: selectedExtension.extension,
        ),
      );

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
    } catch (e) {
      // 에러 메시지 (안전한 헬퍼 사용)
      _safeClearSnackBars();
      _safeShowSnackBar(
        SnackBar(
          content: Text('기능번호 발신 실패: $e'),
          backgroundColor: Colors.red,
          duration: const Duration(seconds: 4),
        ),
      );
      
      if (kDebugMode) {
        debugPrint('❌ 즐곊/최근통화 기능번호 발신 오류: $e');
      }
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
      // 1단계: 권한 상태 확인
      final hasPermission = await _mobileContactsService.hasContactsPermission();
      
      if (!hasPermission) {
        // 권한이 없으면 권한 요청
        if (mounted) {
          setState(() => _isLoadingDeviceContacts = false);
          
          final shouldRequest = await _showPermissionRequestDialog();
          if (shouldRequest != true) {
            return;
          }
          
          setState(() => _isLoadingDeviceContacts = true);
          
          // 권한 요청 실행
          final permissionStatus = await _mobileContactsService.requestContactsPermission();
          
          if (!permissionStatus.isGranted) {
            setState(() => _isLoadingDeviceContacts = false);
            
            if (mounted) {
              // 권한 거부 시 설정으로 이동 제안
              _showPermissionDeniedDialog();
            }
            return;
          }
        } else {
          setState(() => _isLoadingDeviceContacts = false);
          return;
        }
      }

      // 2단계: 연락처 가져오기
      if (mounted) {
        final userId = context.read<AuthService>().currentUser?.uid ?? '';
        
        final contacts = await _mobileContactsService.getDeviceContacts(userId);

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
      
      // Firestore에 저장
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

    // 이름 번역
    final translatedName = _translateName(contact.name);
    
    // 카테고리 번역 (영어면 한글로 변환)
    final translatedCategory = _translateName(contact.categoryDisplay);

    return ListTile(
      leading: CircleAvatar(
        backgroundColor: Colors.amber[100],
        child: Icon(Icons.star, color: Colors.amber[700]),
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
              translatedCategory,
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
