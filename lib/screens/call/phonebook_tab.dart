import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../services/auth_service.dart';
import '../../services/api_service.dart';
import '../../services/database_service.dart';
import '../../models/phonebook_model.dart';
import '../../widgets/call_method_dialog.dart';

class PhonebookTab extends StatefulWidget {
  const PhonebookTab({super.key});

  @override
  State<PhonebookTab> createState() => _PhonebookTabState();
}

class _PhonebookTabState extends State<PhonebookTab> {
  final DatabaseService _databaseService = DatabaseService();
  bool _isLoading = false;
  String? _error;
  final TextEditingController _searchController = TextEditingController();
  DateTime? _lastUpdateTime; // 마지막 업데이트 시간

  // 영어 이름을 한글로 번역하는 매핑 테이블
  final Map<String, String> _nameTranslations = {
    // 기능 코드 (Feature Codes)
    'Echo Test': '에코테스트',
    'Call Forward Immediately': '즉시 착신 전환 토글',
    'Set CF Immediately Number': '즉시 전환 번호 설정',
    
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

      final apiService = ApiService(
        baseUrl: userModel!.getApiUrl(useHttps: false),
        companyId: userModel.companyId,
        appKey: userModel.appKey,
      );

      if (kDebugMode) {
        debugPrint('🔍 Phonebook 목록 조회 시작...');
      }

      // 1. Phonebook 목록 조회
      final phonebooks = await apiService.getPhonebooks();

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

        // 4. 각 phonebook의 연락처 불러오기
        final contactCount = await _loadPhonebookContacts(
          phonebook.phonebookId,
          userId,
          apiService,
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

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('${internalPhonebooks.length}개 phonebook, 연락처 목록을 불러왔습니다'),
            backgroundColor: Colors.green,
            duration: const Duration(seconds: 2),
          ),
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

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Phonebook 로드 실패: $e'),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 3),
          ),
        );
      }
    }
  }

  // 특정 Phonebook의 연락처 불러오기
  Future<int> _loadPhonebookContacts(
    String phonebookId,
    String userId,
    ApiService apiService,
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

      // Firestore에 저장
      int savedCount = 0;
      for (final contactData in contacts) {
        if (kDebugMode) {
          debugPrint('  🔍 API 원본 데이터 [$savedCount]: ${contactData.toString()}');
        }

        final contact = PhonebookContactModel.fromApi(
          contactData,
          userId,
          phonebookId,
        );

        if (kDebugMode) {
          debugPrint('  📦 변환된 Contact: contactId=${contact.contactId}, name=${contact.name}, tel=${contact.telephone}');
        }

        final docId = await _databaseService.addOrUpdatePhonebookContact(contact);
        savedCount++;
        
        if (kDebugMode) {
          debugPrint('  ✅ [$savedCount/${contacts.length}] Firestore docId=$docId - ${contact.name} (${contact.telephone}) - ${contact.categoryDisplay}');
        }
      }

      if (kDebugMode) {
        debugPrint('✅ Phonebook $phonebookId: 총 $savedCount개 연락처 저장 완료');
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
            const Icon(Icons.error, size: 64, color: Colors.red),
            const SizedBox(height: 16),
            Text(
              _error!,
              textAlign: TextAlign.center,
              style: const TextStyle(color: Colors.red),
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
            color: Colors.grey[100],
            border: Border(
              bottom: BorderSide(color: Colors.grey[300]!),
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
                        backgroundColor: const Color(0xFF2196F3),
                        foregroundColor: Colors.white,
                        elevation: 2,
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                      ),
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
                      Icon(Icons.schedule, size: 14, color: Colors.grey[600]),
                      const SizedBox(width: 4),
                      Text(
                        '마지막 업데이트: ${_formatLastUpdateTime()}',
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
              fillColor: Colors.grey[50],
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

              // 정렬: 기능번호(Feature Codes)를 맨 위에, 그 다음 단말번호(Extensions)
              contacts.sort((a, b) {
                // Feature Codes를 우선 정렬
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
                return RefreshIndicator(
                  onRefresh: _loadPhonebooks,
                  child: SingleChildScrollView(
                    physics: const AlwaysScrollableScrollPhysics(),
                    child: SizedBox(
                      height: MediaQuery.of(context).size.height * 0.6,
                      child: Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.contact_phone, size: 80, color: Colors.grey[400]),
                            const SizedBox(height: 16),
                            Text(
                              _searchController.text.isNotEmpty
                                  ? '검색 결과가 없습니다'
                                  : '단말번호 목록이 없습니다',
                              style: const TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.w600,
                                color: Colors.grey,
                              ),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              '아래로 당겨서 새로고침하거나\n새로고침 버튼을 눌러 목록을 불러오세요',
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                fontSize: 14,
                                color: Colors.grey[600],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                );
              }

              if (kDebugMode) {
                debugPrint('🎨 ListView.builder 렌더링 시작 - itemCount: ${contacts.length}');
              }

              // RefreshIndicator로 당겨서 새로고침 기능 추가
              return RefreshIndicator(
                onRefresh: _loadPhonebooks,
                child: ListView.builder(
                  physics: const AlwaysScrollableScrollPhysics(), // 항목이 적어도 스크롤 가능
                  itemCount: contacts.length,
                  itemBuilder: (context, index) {
                    final contact = contacts[index];
                    
                    if (kDebugMode && index < 5) {
                      debugPrint('  [$index] ${contact.name} (${contact.telephone}) - ${contact.category}');
                    }
                    
                    return _buildContactListTile(contact);
                  },
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildContactListTile(PhonebookContactModel contact) {
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

    return ListTile(
      leading: CircleAvatar(
        backgroundColor: categoryColor.withAlpha(51),
        child: Icon(categoryIcon, color: categoryColor),
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
      trailing: IconButton(
        icon: const Icon(Icons.phone, color: Color(0xFF2196F3)),
        onPressed: () => _quickCall(contact.telephone),
        tooltip: '빠른 발신',
      ),
      onTap: () => _showContactDetail(contact),
    );
  }

  // 빠른 발신
  void _quickCall(String phoneNumber) {
    showDialog(
      context: context,
      builder: (context) => CallMethodDialog(phoneNumber: phoneNumber),
    );
  }

  // 상세 정보 보기
  void _showContactDetail(PhonebookContactModel contact) {
    // 이름 번역
    final translatedName = _translateName(contact.name);
    
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Row(
          children: [
            Expanded(
              child: Text(translatedName),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: (contact.category == 'Extensions' ? Colors.green : Colors.orange)
                    .withAlpha(26),
                borderRadius: BorderRadius.circular(4),
              ),
              child: Text(
                contact.categoryDisplay,
                style: TextStyle(
                  fontSize: 12,
                  color: contact.category == 'Extensions' ? Colors.green : Colors.orange,
                  fontWeight: FontWeight.w600,
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
              // 전화번호 정보 (우선 표시) - 통화 아이콘 포함
              _buildDetailRowWithCall('전화번호', contact.telephone, context, isPrimary: true),
              if (contact.mobile != null && contact.mobile!.isNotEmpty) 
                _buildDetailRowWithCall('휴대전화', contact.mobile, context),
              if (contact.home != null && contact.home!.isNotEmpty) 
                _buildDetailRowWithCall('집 전화', contact.home, context),
              if (contact.fax != null && contact.fax!.isNotEmpty) 
                _buildDetailRow('팩스', contact.fax),
              
              // 이메일
              if (contact.email != null && contact.email!.isNotEmpty) 
                _buildDetailRow('이메일', contact.email),
              
              // 회사 정보
              if (contact.company != null && contact.company!.isNotEmpty) 
                _buildDetailRow('회사', contact.company),
              if (contact.title != null && contact.title!.isNotEmpty) 
                _buildDetailRow('직책', contact.title),
              if (contact.businessAddress != null && contact.businessAddress!.isNotEmpty)
                _buildDetailRow('회사 주소', contact.businessAddress),
              if (contact.homeAddress != null && contact.homeAddress!.isNotEmpty) 
                _buildDetailRow('집 주소', contact.homeAddress),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('닫기'),
          ),
          // 전화 걸기 아이콘 버튼 (텍스트 제거)
          IconButton(
            onPressed: () {
              Navigator.pop(context);
              _quickCall(contact.telephone);
            },
            icon: const Icon(Icons.phone),
            color: const Color(0xFF2196F3),
            tooltip: '전화 걸기',
            iconSize: 28,
          ),
        ],
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
                color: isPrimary ? const Color(0xFF2196F3) : Colors.grey[700],
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

  // 전화번호 필드 (통화 아이콘 포함)
  Widget _buildDetailRowWithCall(String label, String? value, BuildContext context, {bool isPrimary = false}) {
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
                color: isPrimary ? const Color(0xFF2196F3) : Colors.grey[700],
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
}
