import 'package:flutter/foundation.dart';
import '../../utils/dialog_utils.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../services/auth_service.dart';
import '../../services/api_service.dart';
import '../../services/database_service.dart';
import '../../services/dcmiws_service.dart';
import '../../models/phonebook_model.dart';
import '../../models/my_extension_model.dart';
import '../../models/user_model.dart';
import '../../providers/selected_extension_provider.dart';
import '../../widgets/call_method_dialog.dart';

class PhonebookTab extends StatefulWidget {
  final VoidCallback? onClickToCallSuccess; // 클릭투콜 성공 콜백
  
  const PhonebookTab({
    super.key,
    this.onClickToCallSuccess,
  });

  @override
  State<PhonebookTab> createState() => _PhonebookTabState();
}

class _PhonebookTabState extends State<PhonebookTab> {
  final DatabaseService _databaseService = DatabaseService();
  bool _isLoading = false;
  String? _error;
  final TextEditingController _searchController = TextEditingController();
  DateTime? _lastUpdateTime; // 마지막 업데이트 시간
  bool _isGridView = false; // false: 리스트뷰, true: 그리드뷰

  // 영어 이름을 한글로 번역하는 매핑 테이블
  final Map<String, String> _nameTranslations = {
    // 기능 코드 (Feature Codes) 이름 번역
    'Echo Test': '에코테스트',
    'Call Forward Immediately - Toggle': '즉시 착신 전환 토글',
    'Set CF Immediately Number': '즉시 착신 전환 번호 설정',

    // 일반 직책 및 부서
    'CEO': '대표이사',
    'CTO': '기술이사',
    'CFO': '재무이사',
    'COO': '운영이사',
    'Manager': '매니저',
    'Director': '이사',
    'President': '사장',
    'Vice President': '부사장',
    'Team Leader': '팀장',
    'Staff': '직원',
    'Employee': '직원',
    'Intern': '인턴',
    'Assistant': '보조',
    'Secretary': '비서',
    'Accountant': '회계사',
    'Engineer': '엔지니어',
    'Developer': '개발자',
    'Designer': '디자이너',
    'Sales': '영업',
    'Marketing': '마케팅',
    'HR': '인사',
    'Finance': '재무',
    'IT': '정보기술',
    'Support': '지원',
    'Service': '서비스',
    'Customer': '고객',
    'Admin': '관리자',
    'Administrator': '관리자',
    'Operator': '운영자',
    'Receptionist': '안내원',
    'Front Desk': '프론트',
    
    // 부서명
    'Sales Team': '영업팀',
    'Marketing Team': '마케팅팀',
    'Development Team': '개발팀',
    'HR Team': '인사팀',
    'Finance Team': '재무팀',
    'IT Team': 'IT팀',
    'Support Team': '지원팀',
    'Customer Service': '고객서비스',
    
    // 시설 및 공용
    'Main Office': '본사',
    'Branch Office': '지사',
    'Headquarters': '본부',
    'Reception': '안내데스크',
    'Conference Room': '회의실',
    'Meeting Room': '회의실',
    'Emergency': '긴급',
    'Security': '보안',
    'Parking': '주차',
    'Lobby': '로비',
  };

  // 영어 이름을 한글로 번역
  String _translateName(String name) {
    // 이미 한글이 포함되어 있으면 그대로 반환
    if (RegExp(r'[ㄱ-ㅎ가-힣]').hasMatch(name)) {
      return name;
    }

    // 정확히 일치하는 번역이 있는지 확인
    if (_nameTranslations.containsKey(name)) {
      return _nameTranslations[name]!;
    }

    // 부분 일치 번역 (대소문자 무시)
    final nameLower = name.toLowerCase();
    for (final entry in _nameTranslations.entries) {
      if (nameLower.contains(entry.key.toLowerCase())) {
        return name.replaceAll(
          RegExp(entry.key, caseSensitive: false),
          entry.value,
        );
      }
    }

    // 번역이 없으면 원본 반환
    return name;
  }

  // 마지막 업데이트 시간을 포맷팅
  String _formatLastUpdateTime() {
    if (_lastUpdateTime == null) return '업데이트 기록 없음';

    final now = DateTime.now();
    final difference = now.difference(_lastUpdateTime!);

    if (difference.inSeconds < 60) {
      return '방금 전';
    } else if (difference.inMinutes < 60) {
      return '${difference.inMinutes}분 전';
    } else if (difference.inHours < 24) {
      return '${difference.inHours}시간 전';
    } else if (difference.inDays < 7) {
      return '${difference.inDays}일 전';
    } else {
      // 날짜 포맷: MM월 DD일 HH:mm
      return '${_lastUpdateTime!.month}월 ${_lastUpdateTime!.day}일 ${_lastUpdateTime!.hour.toString().padLeft(2, '0')}:${_lastUpdateTime!.minute.toString().padLeft(2, '0')}';
    }
  }

  @override
  void initState() {
    super.initState();
    // 화면 진입 시 DB에 데이터가 없으면 자동으로 API 호출
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _checkAndLoadPhonebooks();
    });
  }

  // DB에 데이터가 있는지 확인하고, 없으면 API 호출
  Future<void> _checkAndLoadPhonebooks() async {
    try {
      final userId = context.read<AuthService>().currentUser?.uid ?? '';
      if (userId.isEmpty) return;

      // Firestore에서 연락처 개수 확인
      final snapshot = await _databaseService
          .getAllPhonebookContacts(userId)
          .first;

      if (kDebugMode) {
        debugPrint('📊 Firestore에 저장된 연락처 수: ${snapshot.length}');
      }

      // 데이터가 없으면 API 호출
      if (snapshot.isEmpty) {
        if (kDebugMode) {
          debugPrint('📭 데이터가 없습니다. API 호출을 시작합니다...');
        }
        await _loadPhonebooks();
      } else {
        if (kDebugMode) {
          debugPrint('✅ 기존 데이터 사용 (${snapshot.length}개)');
        }
      }
    } catch (e) {
      if (kDebugMode) {
        debugPrint('❌ 데이터 확인 오류: $e');
      }
    }
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  // Phonebook 목록 불러오기 및 저장
  Future<void> _loadPhonebooks() async {
    if (_isLoading) return;

    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final authService = context.read<AuthService>();
      final userModel = authService.currentUserModel;
      final userId = authService.currentUser?.uid ?? '';

      if (userModel?.apiBaseUrl == null) {
        throw Exception('API 서버 설정이 필요합니다.\nProfile 탭에서 API 서버를 설정해주세요.');
      }

      // 0. my_extensions 등록된 단말번호 확인
      final myExtensionNumbers = await _databaseService.getMyExtensionNumbers(userId);
      
      if (kDebugMode) {
        debugPrint('📱 등록된 단말번호 개수: ${myExtensionNumbers.length}');
        debugPrint('📱 등록된 단말번호 목록: $myExtensionNumbers');
      }

      if (myExtensionNumbers.isEmpty) {
        throw Exception(
          '⚠️ 등록된 단말번호가 없습니다\n\n'
          '📋 단말번호 등록 방법:\n'
          '1. 우측 상단 프로필 아이콘 클릭\n'
          '2. "설정 및 단말 등록" 섹션에서 단말번호 등록\n'
          '3. Phonebook 새로고침 버튼 클릭\n\n'
          '💡 단말번호를 먼저 등록해야 Phonebook을 사용할 수 있습니다.'
        );
      }

      // API Service 생성
      // apiHttpPort가 3501이면 HTTPS 사용, 3500이면 HTTP 사용
      final useHttps = (userModel!.apiHttpPort ?? 3500) == 3501;
      
      if (kDebugMode) {
        debugPrint('📋 Phonebook API 호출 설정:');
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

      if (kDebugMode) {
        debugPrint('🔍 Phonebook API 연결 확인 중...');
      }

      // 1. Phonebook 목록 조회 (API 연결 확인)
      final phonebooks = await apiService.getPhonebooks();

      if (kDebugMode) {
        debugPrint('✅ API 연결 성공! 기존 데이터 삭제 시작...');
      }

      // 🗑️ API 연결 성공 후에만 기존 Phonebook 데이터 삭제
      await _databaseService.deleteAllPhonebookData(userId);
      
      if (kDebugMode) {
        debugPrint('🔄 기존 Phonebook 데이터 삭제 완료, 새로운 데이터 저장 시작...');
      }

      if (kDebugMode) {
        debugPrint('📋 총 ${phonebooks.length}개 phonebook 발견');
      }

      // 2. source_type이 internal인 것만 필터링
      final internalPhonebooks = phonebooks.where((pb) {
        final sourceType = pb['source_type']?.toString() ?? '';
        return sourceType == 'internal';
      }).toList();

      if (kDebugMode) {
        debugPrint('📋 Internal phonebook ${internalPhonebooks.length}개 필터링됨');
      }

      // 3. Firestore에 저장
      int totalContactsSaved = 0;
      for (final phonebookData in internalPhonebooks) {
        final phonebook = PhonebookModel.fromApi(phonebookData, userId);
        await _databaseService.addOrUpdatePhonebook(phonebook);

        if (kDebugMode) {
          debugPrint('📚 Phonebook 저장: ${phonebook.name} (ID: ${phonebook.phonebookId})');
        }

        // 4. 각 phonebook의 연락처 불러오기 (등록된 단말번호 제외)
        final contactCount = await _loadPhonebookContacts(
          phonebook.phonebookId,
          userId,
          apiService,
          myExtensionNumbers, // 등록된 단말번호 목록 전달
        );
        totalContactsSaved += contactCount;
      }

      if (kDebugMode) {
        debugPrint('✅ 총 저장된 연락처 수: $totalContactsSaved');
      }

      if (mounted) {
        setState(() {
          _isLoading = false;
          _lastUpdateTime = DateTime.now(); // 업데이트 시간 기록
        });

        await DialogUtils.showSuccess(
          context,
          '${internalPhonebooks.length}개 phonebook, 연락처 목록을 불러왔습니다',
          duration: const Duration(seconds: 2),
        );
      }
    } catch (e) {
      if (kDebugMode) {
        debugPrint('❌ Phonebook 로드 오류: $e');
      }

      if (mounted) {
        setState(() {
          _isLoading = false;
          _error = e.toString();
        });

        await DialogUtils.showError(
          context,
          'Phonebook 로드 실패: $e',
          duration: const Duration(seconds: 3),
        );
      }
    }
  }

  // 특정 Phonebook의 연락처 불러오기
  Future<int> _loadPhonebookContacts(
    String phonebookId,
    String userId,
    ApiService apiService,
    List<String> myExtensionNumbers, // 등록된 단말번호 목록
  ) async {
    try {
      if (kDebugMode) {
        debugPrint('🔍 Phonebook $phonebookId 연락처 조회 중...');
      }

      final contacts = await apiService.getPhonebookContacts(phonebookId);

      if (kDebugMode) {
        debugPrint('📞 API에서 ${contacts.length}개 연락처 발견');
        debugPrint('📋 API 전체 응답: ${contacts.toString()}');
      }

      // Firestore에 저장 (my_extensions 단말번호 제외)
      int savedCount = 0;
      int filteredCount = 0;
      
      for (final contactData in contacts) {
        if (kDebugMode) {
          debugPrint('  🔍 API 원본 데이터 [$savedCount]: ${contactData.toString()}');
        }

        final contact = PhonebookContactModel.fromApi(
          contactData,
          userId,
          phonebookId,
        );

        // my_extensions에 등록된 단말번호는 제외
        if (myExtensionNumbers.contains(contact.telephone)) {
          filteredCount++;
          if (kDebugMode) {
            debugPrint('  ⏭️  제외됨 (등록된 단말번호): ${contact.name} (${contact.telephone})');
          }
          continue;
        }

        if (kDebugMode) {
          debugPrint('  📦 변환된 Contact: contactId=${contact.contactId}, name=${contact.name}, tel=${contact.telephone}');
        }

        final docId = await _databaseService.addOrUpdatePhonebookContact(contact);
        savedCount++;
        
        if (kDebugMode) {
          debugPrint('  ✅ [$savedCount/${contacts.length - filteredCount}] Firestore docId=$docId - ${contact.name} (${contact.telephone}) - ${contact.categoryDisplay}');
        }
      }

      if (kDebugMode) {
        debugPrint('✅ Phonebook $phonebookId: 총 $savedCount개 연락처 저장, ${filteredCount}개 제외됨 (등록된 단말번호)');
      }

      return savedCount;
    } catch (e) {
      if (kDebugMode) {
        debugPrint('❌ Phonebook 연락처 로드 오류: $e');
      }
      // 개별 phonebook 연락처 로드 실패는 전체 프로세스를 중단하지 않음
      return 0;
    }
  }

  @override
  Widget build(BuildContext context) {
    final userId = context.watch<AuthService>().currentUser?.uid ?? '';
    final isDark = Theme.of(context).brightness == Brightness.dark;

    if (_isLoading) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircularProgressIndicator(),
            SizedBox(height: 16),
            Text('Phonebook 목록을 불러오는 중...'),
          ],
        ),
      );
    }

    if (_error != null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.error, 
              size: 64, 
              color: isDark ? Colors.red[300] : Colors.red,
            ),
            const SizedBox(height: 16),
            Text(
              _error!,
              textAlign: TextAlign.center,
              style: TextStyle(color: isDark ? Colors.red[300] : Colors.red),
            ),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: _loadPhonebooks,
              icon: const Icon(Icons.refresh),
              label: const Text('다시 시도'),
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
          child: Column(
            children: [
              Row(
                children: [
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: _isLoading ? null : _loadPhonebooks,
                      icon: _isLoading
                          ? const SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Icon(Icons.refresh),
                      label: const Text('새로고침', style: TextStyle(fontSize: 13)),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: isDark 
                            ? Colors.blue[700] 
                            : const Color(0xFF2196F3),
                        foregroundColor: Colors.white,
                        elevation: 2,
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  // 뷰 모드 전환 버튼
                  Container(
                    decoration: BoxDecoration(
                      color: isDark
                          ? (_isGridView ? Colors.green[900] : Colors.blue[900])
                          : (_isGridView ? Colors.green[100] : Colors.blue[100]),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: IconButton(
                      icon: Icon(
                        _isGridView ? Icons.view_list : Icons.grid_view,
                        color: isDark
                            ? (_isGridView ? Colors.green[300] : Colors.blue[300])
                            : (_isGridView ? Colors.green[700] : Colors.blue[700]),
                      ),
                      onPressed: () {
                        setState(() {
                          _isGridView = !_isGridView;
                        });
                      },
                      tooltip: _isGridView ? '리스트뷰로 전환' : '그리드뷰로 전환',
                    ),
                  ),
                ],
              ),
              // 마지막 업데이트 시간
              if (_lastUpdateTime != null)
                Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.schedule, 
                        size: 14, 
                        color: isDark ? Colors.grey[500] : Colors.grey[600],
                      ),
                      const SizedBox(width: 4),
                      Text(
                        '마지막 업데이트: ${_formatLastUpdateTime()}',
                        style: TextStyle(
                          fontSize: 12,
                          color: isDark ? Colors.grey[500] : Colors.grey[600],
                        ),
                      ),
                    ],
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
              hintText: '이름 또는 전화번호 검색',
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
          child: StreamBuilder<List<PhonebookContactModel>>(
            stream: _databaseService.getAllPhonebookContacts(userId),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator());
              }

              var contacts = snapshot.data ?? [];

              if (kDebugMode) {
                debugPrint('📋 Firestore에서 가져온 총 연락처 수: ${contacts.length}');
              }

              return StreamBuilder<List<MyExtensionModel>>(
                stream: _databaseService.getMyExtensions(userId),
                builder: (context, myExtensionsSnapshot) {
                  // 내가 저장한 단말번호 목록 가져오기 (my_extensions 컬렉션)
                  final myExtensions = myExtensionsSnapshot.data ?? [];
                  final myExtensionNumbers = myExtensions.map((e) => e.extension).toList();
                  
                  if (kDebugMode && myExtensionNumbers.isNotEmpty) {
                    debugPrint('📝 my_extensions 컬렉션에서 가져온 단말번호: ${myExtensionNumbers.length}개 - $myExtensionNumbers');
                  }
                  
                  return FutureBuilder<UserModel?>(
                    future: _databaseService.getUserById(userId),
                    builder: (context, userSnapshot) {
                      // users 문서에서 myExtensions 필드 가져오기
                      final userMyExtensions = userSnapshot.data?.myExtensions ?? [];
                      
                      if (kDebugMode && userMyExtensions.isNotEmpty) {
                        debugPrint('👤 users.myExtensions에서 가져온 단말번호: ${userMyExtensions.length}개 - $userMyExtensions');
                      }
                      
                      // 내 단말번호 = my_extensions 컬렉션 + users.myExtensions (합집합)
                      final allMyExtensions = <String>{
                        ...myExtensionNumbers,
                        if (userMyExtensions.isNotEmpty) ...userMyExtensions,
                      }.toList();
                      
                      if (kDebugMode) {
                        debugPrint('🎯 필터링할 내 단말번호 전체: ${allMyExtensions.length}개 - $allMyExtensions');
                      }
                      
                      // Phonebook 연락처에서 내 단말번호 제외
                      contacts = contacts.where((contact) {
                        final shouldExclude = allMyExtensions.contains(contact.telephone);
                        if (shouldExclude && kDebugMode) {
                          debugPrint('⏭️  Phonebook에서 제외: ${contact.name} (${contact.telephone}) - 내 단말번호');
                        }
                        return !shouldExclude;
                      }).toList();
                      
                      if (kDebugMode) {
                        debugPrint('✅ 내 단말번호 제외 후 연락처 수: ${contacts.length}');
                      }
                      
                      return FutureBuilder<List<String>>(
                        future: _databaseService.getAllRegisteredExtensions(),
                        builder: (context, registeredSnapshot) {
                          // 모든 사용자의 등록된 단말번호 (registered_extensions 컬렉션 전체)
                          final allRegisteredExtensions = registeredSnapshot.data ?? [];
                          
                          // 다른 사람이 등록한 단말번호 = 전체 등록 번호 - 내 단말번호
                          final otherUsersExtensions = allRegisteredExtensions
                              .where((ext) => !allMyExtensions.contains(ext))
                              .toList();
                          
                          if (kDebugMode) {
                            debugPrint('🔒 전체 등록된 단말번호 (모든 사용자): ${allRegisteredExtensions.length}개');
                            debugPrint('📱 내 단말번호: ${allMyExtensions.length}개 - $allMyExtensions');
                            debugPrint('👥 다른 사람이 등록한 단말번호: ${otherUsersExtensions.length}개 - $otherUsersExtensions');
                          }

                      // 검색 필터링
                      if (_searchController.text.isNotEmpty) {
                        final query = _searchController.text.toLowerCase();
                        contacts = contacts.where((contact) {
                          final translatedName = _translateName(contact.name);
                          return contact.name.toLowerCase().contains(query) ||
                              translatedName.toLowerCase().contains(query) ||
                              contact.telephone.contains(query);
                        }).toList();
                        
                        if (kDebugMode) {
                          debugPrint('🔍 검색 후 연락처 수: ${contacts.length}');
                        }
                      }

                      // telephone 중복 제거 (같은 번호는 하나만 표시)
                      final seenTelephones = <String>{};
                      final uniqueContacts = <PhonebookContactModel>[];
                      
                      for (final contact in contacts) {
                        if (!seenTelephones.contains(contact.telephone)) {
                          seenTelephones.add(contact.telephone);
                          uniqueContacts.add(contact);
                        } else {
                          if (kDebugMode) {
                            debugPrint('🔁 중복 제거: ${contact.telephone} (${contact.name})');
                          }
                        }
                      }
                      
                      contacts = uniqueContacts;
                      
                      if (kDebugMode) {
                        debugPrint('🎯 중복 제거 후: ${contacts.length}개 (고유 telephone 개수)');
                      }

                      // 정렬: 에코테스트 최우선, 그 다음 기능번호(Feature Codes), 마지막 단말번호(Extensions)
                      contacts.sort((a, b) {
                        // 에코테스트 이름 확인 (영어/한글 모두 고려)
                        final aIsEchoTest = a.name.toLowerCase().contains('echo test') || 
                                           a.name.contains('에코테스트');
                        final bIsEchoTest = b.name.toLowerCase().contains('echo test') || 
                                           b.name.contains('에코테스트');
                        
                        // 에코테스트를 최우선 정렬
                        if (aIsEchoTest && !bIsEchoTest) {
                          return -1; // a를 맨 앞으로
                        }
                        if (!aIsEchoTest && bIsEchoTest) {
                          return 1; // b를 맨 앞으로
                        }
                        
                        // 둘 다 에코테스트가 아닌 경우, Feature Codes 우선 정렬
                        if (a.category == 'Feature Codes' && b.category != 'Feature Codes') {
                          return -1; // a를 앞으로
                        }
                        if (a.category != 'Feature Codes' && b.category == 'Feature Codes') {
                          return 1; // b를 앞으로
                        }
                        
                        // 같은 카테고리 내에서는 이름순 정렬
                        return a.name.compareTo(b.name);
                      });

                      if (kDebugMode) {
                        debugPrint('✅ 정렬 완료 - 표시할 연락처 수: ${contacts.length}');
                        if (contacts.isNotEmpty) {
                          debugPrint('📌 첫 번째 연락처: ${contacts.first.name} (${contacts.first.category})');
                          debugPrint('📌 마지막 연락처: ${contacts.last.name} (${contacts.last.category})');
                        }
                      }

                      if (contacts.isEmpty) {
                        return SingleChildScrollView(
                          physics: const AlwaysScrollableScrollPhysics(),
                          child: SizedBox(
                            height: MediaQuery.of(context).size.height * 0.6,
                            child: Center(
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(
                                    Icons.contact_phone, 
                                    size: 80, 
                                    color: isDark ? Colors.grey[700] : Colors.grey[400],
                                  ),
                                  const SizedBox(height: 16),
                                  Text(
                                    _searchController.text.isNotEmpty
                                        ? '검색 결과가 없습니다'
                                        : '단말번호 목록이 없습니다',
                                    style: TextStyle(
                                      fontSize: 18,
                                      fontWeight: FontWeight.w600,
                                      color: isDark ? Colors.grey[400] : Colors.grey,
                                    ),
                                  ),
                                  const SizedBox(height: 8),
                                  Text(
                                    '새로고침 버튼을 눌러 목록을 불러오세요',
                                    textAlign: TextAlign.center,
                                    style: TextStyle(
                                      fontSize: 14,
                                      color: isDark ? Colors.grey[500] : Colors.grey[600],
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        );
                      }

                      if (kDebugMode) {
                        debugPrint('🎨 ListView.builder 렌더링 시작 - itemCount: ${contacts.length}');
                      }

                      // 스크롤 새로고침 기능 제거됨
                      // 뷰 모드에 따라 ListView 또는 GridView 렌더링
                      return _isGridView
                          ? GridView.builder(
                              physics: const AlwaysScrollableScrollPhysics(),
                              padding: EdgeInsets.all(_getResponsiveSize(context, 4)),
                              gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                                crossAxisCount: _getGridColumnCount(context),
                                crossAxisSpacing: _getResponsiveSize(context, 4),
                                mainAxisSpacing: _getResponsiveSize(context, 4),
                                childAspectRatio: _getGridChildAspectRatio(context), // 화면 방향에 따라 동적 조정
                              ),
                              itemCount: contacts.length,
                              itemBuilder: (context, index) {
                                final contact = contacts[index];
                                return _buildContactGridItem(contact, registeredExtensions: otherUsersExtensions);
                              },
                            )
                          : ListView.builder(
                              physics: const AlwaysScrollableScrollPhysics(), // 항목이 적어도 스크롤 가능
                              itemCount: contacts.length,
                              itemBuilder: (context, index) {
                                final contact = contacts[index];
                                
                                if (kDebugMode && index < 5) {
                                  debugPrint('  [$index] ${contact.name} (${contact.telephone}) - ${contact.category}');
                                }
                                
                                // 다른 사람이 등록한 단말번호 리스트를 전달
                                return _buildContactListTile(contact, registeredExtensions: otherUsersExtensions);
                              },
                            );
                    },
                  );
                      },
                    );
                },
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildContactListTile(PhonebookContactModel contact, {List<String>? registeredExtensions}) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    
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
    
    // 등록 여부 확인
    final isRegistered = registeredExtensions?.contains(contact.telephone) ?? false;
    
    // 다른 사용자의 단말번호 여부 (Extensions 카테고리이면서 본인이 등록하지 않은 경우)
    final isOtherUserExtension = contact.category == 'Extensions' && !isRegistered;

    return ListTile(
      leading: Stack(
        children: [
          CircleAvatar(
            backgroundColor: contact.isFavorite
                ? (isDark ? Colors.amber[900]!.withAlpha(128) : Colors.amber[100])
                : (isDark 
                    ? categoryColor.withAlpha(77) 
                    : categoryColor.withAlpha(51)),
            child: Icon(
              contact.isFavorite ? Icons.star : categoryIcon,
              color: contact.isFavorite 
                  ? (isDark ? Colors.amber[300] : Colors.amber[700])
                  : (isDark 
                      ? (categoryColor == Colors.blue 
                          ? Colors.blue[300] 
                          : (categoryColor == Colors.green 
                              ? Colors.green[300] 
                              : Colors.orange[300]))
                      : categoryColor),
            ),
          ),
          // 등록된 단말번호 표시 (우측 하단에 초록색 로고 배지)
          if (isRegistered)
            Positioned(
              right: 0,
              bottom: 0,
              child: Container(
                width: 20,
                height: 20,
                decoration: BoxDecoration(
                  color: isDark ? Colors.grey[850] : Colors.white,
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: isDark ? Colors.green[400]! : Colors.green, 
                    width: 1.5,
                  ),
                ),
                child: ClipOval(
                  child: Image.asset(
                    'assets/images/app_logo.png',
                    fit: BoxFit.cover,
                  ),
                ),
              ),
            ),
          // 다른 사용자의 단말번호 표시 (우측 하단에 회색 아이콘 배지)
          if (isOtherUserExtension)
            Positioned(
              right: 0,
              bottom: 0,
              child: Container(
                width: 18,
                height: 18,
                decoration: BoxDecoration(
                  color: isDark ? Colors.grey[700] : Colors.grey[300],
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: isDark ? Colors.grey[600]! : Colors.grey[500]!, 
                    width: 1,
                  ),
                ),
                child: Icon(
                  Icons.person,
                  size: 12,
                  color: isDark ? Colors.grey[400] : Colors.grey[700],
                ),
              ),
            ),
        ],
      ),
      title: Row(
        children: [
          // 즐겨찾기 별 아이콘 (이름 앞)
          if (contact.isFavorite)
            const Padding(
              padding: EdgeInsets.only(right: 4),
              child: Icon(Icons.star, size: 16, color: Colors.amber),
            ),
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
              contact.categoryDisplay,
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
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          // 즐겨찾기 토글 버튼
          IconButton(
            icon: Icon(
              contact.isFavorite ? Icons.star : Icons.star_border,
              color: contact.isFavorite ? Colors.amber : Colors.grey,
            ),
            onPressed: () => _toggleFavorite(contact),
            tooltip: contact.isFavorite ? '즐겨찾기 해제' : '즐겨찾기 추가',
          ),
          // 전화 걸기 버튼
          IconButton(
            icon: const Icon(Icons.phone, color: Color(0xFF2196F3)),
            onPressed: () => _quickCall(
              contact.telephone,
              category: contact.category,
              name: contact.name,
            ),
            tooltip: '빠른 발신',
          ),
        ],
      ),
      onTap: () => _showContactDetail(contact),
    );
  }

  // 반응형 크기 계산 헬퍼 메서드
  double _getResponsiveSize(BuildContext context, double baseSize) {
    final screenWidth = MediaQuery.of(context).size.width;
    // 기준: 360px (일반 스마트폰 너비)
    // 태블릿: ~600px 이상
    final scaleFactor = screenWidth / 360.0;
    return baseSize * scaleFactor.clamp(0.8, 2.0); // 최소 0.8배, 최대 2배로 제한
  }

  // 화면 크기에 따라 그리드 컬럼 수 결정
  int _getGridColumnCount(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    
    if (screenWidth >= 1024) {
      return 6; // 대형 태블릿/데스크톱: 6열
    } else if (screenWidth >= 768) {
      return 5; // 일반 태블릿: 5열
    } else if (screenWidth >= 600) {
      return 4; // 소형 태블릿: 4열
    } else {
      return 3; // 스마트폰: 3열
    }
  }

  // 화면 방향에 따라 그리드 childAspectRatio 결정
  double _getGridChildAspectRatio(BuildContext context) {
    final orientation = MediaQuery.of(context).orientation;
    final screenWidth = MediaQuery.of(context).size.width;
    
    if (orientation == Orientation.landscape) {
      // 랜드스케이프 모드: 더 넓은 비율 (높이를 더 확보)
      if (screenWidth >= 1024) {
        return 1.15; // 대형 화면 (1.1에서 증가)
      } else if (screenWidth >= 768) {
        return 1.05; // 태블릿 (1.0에서 증가)
      } else {
        return 1.0; // 스마트폰 (0.95에서 증가)
      }
    } else {
      // 포트레이트 모드: 높이 여유 확보
      return 0.9; // 0.85에서 0.9로 증가
    }
  }

  // 그리드 아이템 빌더
  Widget _buildContactGridItem(PhonebookContactModel contact, {List<String>? registeredExtensions}) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    
    Color categoryColor = Colors.blue;
    IconData categoryIcon = Icons.phone;

    if (contact.category == 'Extensions') {
      categoryColor = Colors.green;
      categoryIcon = Icons.phone_android;
    } else if (contact.category == 'Feature Codes') {
      categoryColor = Colors.orange;
      categoryIcon = Icons.star;
    }

    final translatedName = _translateName(contact.name);
    final isRegistered = registeredExtensions?.contains(contact.telephone) ?? false;
    final isOtherUserExtension = contact.category == 'Extensions' && !isRegistered;

    return Card(
      elevation: 1,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(_getResponsiveSize(context, 8)),
        side: BorderSide(
          color: contact.isFavorite ? Colors.amber.withAlpha(128) : categoryColor.withAlpha(77),
          width: contact.isFavorite ? 1.5 : 0.5,
        ),
      ),
      child: InkWell(
        onTap: () => _showContactDetail(contact),
        onLongPress: () => _quickCall(
          contact.telephone,
          category: contact.category,
          name: contact.name,
        ),
        borderRadius: BorderRadius.circular(_getResponsiveSize(context, 8)),
        child: Padding(
          padding: EdgeInsets.all(_getResponsiveSize(context, 3)), // 4에서 3으로 감소
          child: Column(
            mainAxisSize: MainAxisSize.min, // ✅ 추가: 콘텐츠 크기에 맞춤
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // 아이콘 (즐겨찾기 별 표시 포함)
              Stack(
                children: [
                  Container(
                    width: _getResponsiveSize(context, 36), // 40에서 36으로 감소
                    height: _getResponsiveSize(context, 36), // 40에서 36으로 감소
                    decoration: BoxDecoration(
                      color: contact.isFavorite
                          ? Colors.amber[100]
                          : categoryColor.withAlpha(51),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      contact.isFavorite ? Icons.star : categoryIcon,
                      size: _getResponsiveSize(context, 18), // 20에서 18로 감소
                      color: contact.isFavorite ? Colors.amber[700] : categoryColor,
                    ),
                  ),
                  // 등록된 단말번호 배지
                  if (isRegistered)
                    Positioned(
                      right: 0,
                      bottom: 0,
                      child: Container(
                        width: _getResponsiveSize(context, 12),
                        height: _getResponsiveSize(context, 12),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          shape: BoxShape.circle,
                          border: Border.all(color: Colors.green, width: 1),
                        ),
                        child: ClipOval(
                          child: Image.asset(
                            'assets/images/app_logo.png',
                            fit: BoxFit.cover,
                          ),
                        ),
                      ),
                    ),
                  // 다른 사용자 배지
                  if (isOtherUserExtension)
                    Positioned(
                      right: 0,
                      bottom: 0,
                      child: Container(
                        width: _getResponsiveSize(context, 10),
                        height: _getResponsiveSize(context, 10),
                        decoration: BoxDecoration(
                          color: Colors.grey[300],
                          shape: BoxShape.circle,
                          border: Border.all(color: Colors.grey[500]!, width: 0.5),
                        ),
                        child: Icon(
                          Icons.person,
                          size: _getResponsiveSize(context, 6),
                          color: Colors.grey[700],
                        ),
                      ),
                    ),
                ],
              ),
              SizedBox(height: _getResponsiveSize(context, 3)), // 4에서 3으로 감소
              
              // 이름
              Flexible(
                child: Text(
                  translatedName,
                  style: TextStyle(
                    fontSize: _getResponsiveSize(context, 10), // 11에서 10으로 감소
                    fontWeight: FontWeight.bold,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  textAlign: TextAlign.center,
                ),
              ),
              
              SizedBox(height: _getResponsiveSize(context, 1)), // 추가: 이름과 번호 사이 간격
              
              // 전화번호 (더 크게 표시)
              Flexible(
                child: Text(
                  contact.telephone,
                  style: TextStyle(
                    fontSize: _getResponsiveSize(context, 13), // 14에서 13으로 감소
                    fontWeight: FontWeight.w700,
                    color: Colors.black87,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  textAlign: TextAlign.center,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // 즐겨찾기 토글 (연락처와 동일한 동작)
  Future<void> _toggleFavorite(PhonebookContactModel contact) async {
    try {
      await _databaseService.togglePhonebookContactFavorite(
        contact.id,
        contact.isFavorite,
      );

      if (mounted) {
        await DialogUtils.showSuccess(
          context,
          contact.isFavorite
              ? '즐겨찾기에서 제거되었습니다'
              : '즐겨찾기에 추가되었습니다',
          duration: const Duration(seconds: 2),
        );
      }
    } catch (e) {
      if (mounted) {
        await DialogUtils.showError(
          context,
          '즐겨찾기 변경 실패: $e',
        );
      }
    }
  }

  // 기능번호 판별 헬퍼 메서드
  bool _isFeatureCode(String phoneNumber, String? category, String? name) {
    // 1. Category가 'Feature Codes'인 경우
    if (category == 'Feature Codes') {
      return true;
    }
    
    // 2. 전화번호가 *로 시작하는 경우
    if (phoneNumber.startsWith('*')) {
      return true;
    }
    
    // 3. 이름에 '에코테스트' 또는 'Echo Test' 포함
    if (name != null) {
      final nameLower = name.toLowerCase();
      if (nameLower.contains('echo test') || nameLower.contains('에코테스트')) {
        return true;
      }
      
      // 4. 이름에 '기능번호' 또는 'feature code' 포함
      if (nameLower.contains('기능번호') || nameLower.contains('feature code')) {
        return true;
      }
    }
    
    return false;
  }
  
  // 빠른 발신
  Future<void> _quickCall(String phoneNumber, {String? category, String? name}) async {
    // 기능번호 판별: category, 전화번호, 이름을 종합적으로 확인
    if (_isFeatureCode(phoneNumber, category, name)) {
      if (kDebugMode) {
        debugPrint('🌟 기능번호 감지: $phoneNumber (category: $category, name: $name)');
      }
      await _handleFeatureCodeCall(phoneNumber);
      return;
    }
    
    // 5자리 이하 숫자만 있는 단말번호는 자동으로 클릭투콜 실행 (다이얼로그 없음)
    final cleanNumber = phoneNumber.replaceAll(RegExp(r'[^0-9]'), '');
    if (cleanNumber.length > 0 && cleanNumber.length <= 5 && cleanNumber == phoneNumber) {
      if (kDebugMode) {
        debugPrint('🔥 5자리 이하 내선번호 감지: $phoneNumber');
        debugPrint('📞 자동으로 클릭투콜 실행 (다이얼로그 건너뛰기)');
      }
      await _handleFeatureCodeCall(phoneNumber);
      return;
    }
    
    // 일반 전화번호는 발신 방법 선택 다이얼로그 표시
    showDialog(
      context: context,
      builder: (context) => CallMethodDialog(
        phoneNumber: phoneNumber, 
        autoCallShortExtension: false,
        onClickToCallSuccess: widget.onClickToCallSuccess, // 부모에게 콜백 전달
      ),
    );
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
        debugPrint('🌟 기능번호 자동 발신 시작 (다이얼로그 건너뛰기)');
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

      // 로딩 표시
      if (mounted) {
        await DialogUtils.showInfo(
          context,
          '기능번호 발신 중...',
          duration: const Duration(seconds: 2),
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
        debugPrint('✅ 기능번호 Click to Call 성공: $result');
        debugPrint('   → Newchannel 이벤트 대기 중... (Pending Storage 준비 완료)');
      }

      if (mounted) {
        final extensionDisplay = selectedExtension.name.isEmpty 
            ? selectedExtension.extension 
            : selectedExtension.name;

        await DialogUtils.showSuccess(
          context,
          '🌟 기능번호 발신 완료\n\n단말: $extensionDisplay\n기능번호: $phoneNumber',
          duration: const Duration(seconds: 3),
        );
        
        // 🔄 기능번호 발신 성공 시 콜백 호출 (최근통화 탭으로 전환)
        widget.onClickToCallSuccess?.call();
        
        if (kDebugMode) {
          debugPrint('✅ 단말번호 기능번호 발신 성공 → 최근통화 탭 전환 콜백 호출');
        }
      }
    } catch (e) {
      if (mounted) {
        await DialogUtils.showError(
          context,
          '기능번호 발신 실패: $e',
          duration: const Duration(seconds: 4),
        );
      }
      
      if (kDebugMode) {
        debugPrint('❌ 기능번호 발신 오류: $e');
      }
    }
  }

  // 상세 정보 보기 - Modal Bottom Sheet (Material Design 3)
  void _showContactDetail(PhonebookContactModel contact) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    
    // 이름 번역
    final translatedName = _translateName(contact.name);
    
    // 디버그: 데이터 확인
    if (kDebugMode) {
      debugPrint('📋 Contact Detail - Name: ${contact.name}');
      debugPrint('   📞 telephone: ${contact.telephone}');
      debugPrint('   📱 mobileNumber: ${contact.mobileNumber}');
      debugPrint('   📧 email: ${contact.email}');
      debugPrint('   🏢 company: ${contact.company}');
      debugPrint('   📋 title: ${contact.title}');
    }
    
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => DraggableScrollableSheet(
        initialChildSize: 0.7,
        minChildSize: 0.5,
        maxChildSize: 0.95,
        builder: (context, scrollController) => Container(
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
          ),
          child: Column(
            children: [
              // Handle bar
              Container(
                margin: const EdgeInsets.only(top: 12, bottom: 8),
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.grey[300],
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              
              // Header
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            translatedName,
                            style: const TextStyle(
                              fontSize: 24,
                              fontWeight: FontWeight.bold,
                              color: Colors.black87,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                            decoration: BoxDecoration(
                              color: (contact.category == 'Extensions' ? Colors.green : Colors.orange).withAlpha(26),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              contact.categoryDisplay,
                              style: TextStyle(
                                fontSize: 13,
                                color: contact.category == 'Extensions' ? Colors.green : Colors.orange,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    // 즐겨찾기 버튼
                    IconButton(
                      onPressed: () async {
                        try {
                          await _databaseService.togglePhonebookContactFavorite(
                            contact.id,
                            contact.isFavorite,
                          );
                          if (mounted) {
                            await DialogUtils.showSuccess(
                              context,
                              contact.isFavorite ? '즐겨찾기에서 제거되었습니다' : '즐겨찾기에 추가되었습니다',
                              duration: const Duration(seconds: 2),
                            );
                          }
                        } catch (e) {
                          if (mounted) {
                            await DialogUtils.showError(
                              context,
                              '즐겨찾기 변경 실패: $e',
                            );
                          }
                        }
                      },
                      icon: Icon(contact.isFavorite ? Icons.star : Icons.star_border),
                      color: Colors.amber,
                      iconSize: 28,
                    ),
                  ],
                ),
              ),
              
              const Divider(height: 1),
              
              // Content
              Expanded(
                child: ListView(
                  controller: scrollController,
                  padding: const EdgeInsets.all(20),
                  children: [
                    // 전화번호
                    _buildDetailCard(
                      icon: Icons.phone,
                      label: '전화번호',
                      value: contact.telephone,
                      isPrimary: true,
                      onTap: () => _quickCall(
                        contact.telephone,
                        category: contact.category,
                        name: contact.name,
                      ),
                      onCopy: () => _copyToClipboard(contact.telephone),
                    ),
                    
                    // 휴대전화
                    if (contact.mobileNumber != null && contact.mobileNumber!.isNotEmpty)
                      _buildDetailCard(
                        icon: Icons.smartphone,
                        label: '휴대전화',
                        value: contact.mobileNumber!,
                        onTap: () => _quickCall(contact.mobileNumber!),
                        onCopy: () => _copyToClipboard(contact.mobileNumber!),
                        onSms: () => _sendSms(contact.mobileNumber!),
                      ),
                    
                    // 집 전화
                    if (contact.home != null && contact.home!.isNotEmpty)
                      _buildDetailCard(
                        icon: Icons.home,
                        label: '집 전화',
                        value: contact.home!,
                        onTap: () => _quickCall(contact.home!),
                        onCopy: () => _copyToClipboard(contact.home!),
                      ),
                    
                    // 팩스
                    if (contact.fax != null && contact.fax!.isNotEmpty)
                      _buildDetailCard(
                        icon: Icons.print,
                        label: '팩스',
                        value: contact.fax!,
                        onCopy: () => _copyToClipboard(contact.fax!),
                      ),
                    
                    // 이메일
                    if (contact.email != null && contact.email!.isNotEmpty)
                      _buildDetailCard(
                        icon: Icons.email,
                        label: '이메일',
                        value: contact.email!,
                        onTap: () => _sendEmail(contact.email!),
                        onCopy: () => _copyToClipboard(contact.email!),
                      ),
                    
                    // 회사
                    if (contact.company != null && contact.company!.isNotEmpty)
                      _buildDetailCard(
                        icon: Icons.business,
                        label: '회사',
                        value: contact.company!,
                        onCopy: () => _copyToClipboard(contact.company!),
                      ),
                    
                    // 직책
                    if (contact.title != null && contact.title!.isNotEmpty)
                      _buildDetailCard(
                        icon: Icons.badge,
                        label: '직책',
                        value: contact.title!,
                        onCopy: () => _copyToClipboard(contact.title!),
                      ),
                    
                    // 회사 주소
                    if (contact.businessAddress != null && contact.businessAddress!.isNotEmpty)
                      _buildDetailCard(
                        icon: Icons.location_on,
                        label: '회사 주소',
                        value: contact.businessAddress!,
                        onCopy: () => _copyToClipboard(contact.businessAddress!),
                      ),
                    
                    // 집 주소
                    if (contact.homeAddress != null && contact.homeAddress!.isNotEmpty)
                      _buildDetailCard(
                        icon: Icons.home_work,
                        label: '집 주소',
                        value: contact.homeAddress!,
                        onCopy: () => _copyToClipboard(contact.homeAddress!),
                      ),
                  ],
                ),
              ),
              
              // Bottom action button
              SafeArea(
                child: Padding(
                  padding: const EdgeInsets.all(20),
                  child: SizedBox(
                    width: double.infinity,
                    height: 56,
                    child: ElevatedButton.icon(
                      onPressed: () {
                        Navigator.pop(context);
                        _quickCall(
                          contact.telephone,
                          category: contact.category,
                          name: contact.name,
                        );
                      },
                      icon: const Icon(Icons.phone, size: 24),
                      label: const Text(
                        '전화 걸기',
                        style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF2196F3),
                        foregroundColor: Colors.white,
                        elevation: 2,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
  
  // Material Design 3 스타일 카드
  Widget _buildDetailCard({
    required IconData icon,
    required String label,
    required String value,
    bool isPrimary = false,
    VoidCallback? onTap,
    VoidCallback? onCopy,
    VoidCallback? onSms,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.grey[50],
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey[200]!),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(12),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                // Icon
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: isPrimary ? const Color(0xFF2196F3).withAlpha(26) : Colors.grey[200],
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(
                    icon,
                    size: 24,
                    color: isPrimary ? const Color(0xFF2196F3) : Colors.grey[700],
                  ),
                ),
                const SizedBox(width: 16),
                // Text
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        label,
                        style: TextStyle(
                          fontSize: 13,
                          color: Colors.grey[600],
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        value,
                        style: TextStyle(
                          fontSize: 16,
                          color: Colors.black87,
                          fontWeight: isPrimary ? FontWeight.w600 : FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),
                // Actions
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (onCopy != null)
                      IconButton(
                        onPressed: onCopy,
                        icon: const Icon(Icons.content_copy, size: 20),
                        color: Colors.grey[600],
                        tooltip: '복사',
                      ),
                    if (onSms != null)
                      IconButton(
                        onPressed: onSms,
                        icon: const Icon(Icons.sms, size: 20),
                        color: Colors.green,
                        tooltip: 'SMS',
                      ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildDetailRow(String label, String? value, {bool isPrimary = false}) {
    if (value == null || value.isEmpty) return const SizedBox.shrink();

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 90,
            child: Text(
              '$label:',
              style: TextStyle(
                fontWeight: FontWeight.w600,
                fontSize: 14,
                color: isPrimary ? const Color(0xFF2196F3) : const Color(0xFF424242),
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: TextStyle(
                fontSize: 14,
                color: Colors.black87,
                fontWeight: isPrimary ? FontWeight.w600 : FontWeight.normal,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // 전화번호 필드 (통화, 복사, SMS 아이콘 포함)
  Widget _buildDetailRowWithActions(String label, String? value, BuildContext context, {bool isPrimary = false, bool showSms = false}) {
    if (value == null || value.isEmpty) return const SizedBox.shrink();

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 90,
            child: Text(
              '$label:',
              style: TextStyle(
                fontWeight: FontWeight.w600,
                fontSize: 14,
                color: isPrimary ? const Color(0xFF2196F3) : const Color(0xFF424242),
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: TextStyle(
                fontSize: 14,
                color: Colors.black87,
                fontWeight: isPrimary ? FontWeight.w600 : FontWeight.normal,
              ),
            ),
          ),
          // 복사 아이콘
          IconButton(
            icon: const Icon(Icons.content_copy, size: 16, color: Colors.grey),
            onPressed: () => _copyToClipboard(value),
            tooltip: '복사',
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(),
          ),
          const SizedBox(width: 4),
          // SMS 아이콘 (휴대전화만)
          if (showSms) ...[
            IconButton(
              icon: const Icon(Icons.sms, size: 16, color: Colors.green),
              onPressed: () => _sendSms(value),
              tooltip: 'SMS 보내기',
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(),
            ),
            const SizedBox(width: 4),
          ],
          // 전화 걸기 아이콘
          IconButton(
            icon: const Icon(Icons.phone, size: 18, color: Color(0xFF2196F3)),
            onPressed: () => _quickCall(value),
            tooltip: '전화 걸기',
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(),
          ),
        ],
      ),
    );
  }

  // 팩스 필드 (복사 아이콘만 포함)
  Widget _buildDetailRowWithCopy(String label, String? value) {
    if (value == null || value.isEmpty) return const SizedBox.shrink();

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 90,
            child: Text(
              '$label:',
              style: const TextStyle(
                fontWeight: FontWeight.w600,
                fontSize: 14,
                color: Color(0xFF424242),
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(
                fontSize: 14,
                color: Colors.black87,
              ),
            ),
          ),
          // 복사 아이콘
          IconButton(
            icon: const Icon(Icons.content_copy, size: 16, color: Colors.grey),
            onPressed: () => _copyToClipboard(value),
            tooltip: '복사',
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(),
          ),
        ],
      ),
    );
  }

  // 이메일 필드 (메일 보내기 아이콘 포함)
  Widget _buildDetailRowWithEmail(String label, String? value) {
    if (value == null || value.isEmpty) return const SizedBox.shrink();

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 90,
            child: Text(
              '$label:',
              style: const TextStyle(
                fontWeight: FontWeight.w600,
                fontSize: 14,
                color: Color(0xFF424242),
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(
                fontSize: 14,
                color: Colors.black87,
              ),
            ),
          ),
          // 복사 아이콘
          IconButton(
            icon: const Icon(Icons.content_copy, size: 16, color: Colors.grey),
            onPressed: () => _copyToClipboard(value),
            tooltip: '복사',
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(),
          ),
          const SizedBox(width: 4),
          // 이메일 보내기 아이콘
          IconButton(
            icon: const Icon(Icons.email, size: 18, color: Color(0xFF2196F3)),
            onPressed: () => _sendEmail(value),
            tooltip: '이메일 보내기',
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(),
          ),
        ],
      ),
    );
  }

  // 클립보드 복사
  Future<void> _copyToClipboard(String text) async {
    Clipboard.setData(ClipboardData(text: text));
    if (mounted) {
      await DialogUtils.showSuccess(
        context,
        '복사됨: $text',
        duration: const Duration(seconds: 2),
      );
    }
  }

  // SMS 보내기
  Future<void> _sendSms(String phoneNumber) async {
    final uri = Uri.parse('sms:$phoneNumber');
    try {
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri);
      } else {
        if (mounted) {
          await DialogUtils.showError(context, 'SMS 앱을 실행할 수 없습니다', duration: const Duration(seconds: 3));
        }
      }
    } catch (e) {
      if (kDebugMode) {
        debugPrint('SMS 실행 오류: $e');
      }
      if (mounted) {
        await DialogUtils.showError(
          context,
          'SMS 실행 실패: $e',
        );
      }
    }
  }

  // 이메일 보내기
  Future<void> _sendEmail(String email) async {
    final uri = Uri.parse('mailto:$email');
    try {
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri);
      } else {
        if (mounted) {
          await DialogUtils.showError(context, '이메일 앱을 실행할 수 없습니다', duration: const Duration(seconds: 3));
        }
      }
    } catch (e) {
      if (kDebugMode) {
        debugPrint('이메일 실행 오류: $e');
      }
      if (mounted) {
        await DialogUtils.showError(
          context,
          '이메일 실행 실패: $e',
        );
      }
    }
  }
}
