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

  // 영어 이름을 한글로 번역하는 매핑 테이블
  final Map<String, String> _nameTranslations = {
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

  @override
  void initState() {
    super.initState();
    // 화면 진입 시 자동으로 phonebook 목록 불러오기
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadPhonebooks();
    });
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
      for (final phonebookData in internalPhonebooks) {
        final phonebook = PhonebookModel.fromApi(phonebookData, userId);
        await _databaseService.addOrUpdatePhonebook(phonebook);

        // 4. 각 phonebook의 연락처 불러오기
        await _loadPhonebookContacts(
          phonebook.phonebookId,
          userId,
          apiService,
        );
      }

      if (mounted) {
        setState(() {
          _isLoading = false;
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
  Future<void> _loadPhonebookContacts(
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
        debugPrint('📞 ${contacts.length}개 연락처 발견');
      }

      // Firestore에 저장
      for (final contactData in contacts) {
        final contact = PhonebookContactModel.fromApi(
          contactData,
          userId,
          phonebookId,
        );
        await _databaseService.addOrUpdatePhonebookContact(contact);
        
        if (kDebugMode) {
          debugPrint('✅ 연락처 저장: ${contact.name} (${contact.telephone}) - ${contact.categoryDisplay}');
        }
      }
    } catch (e) {
      if (kDebugMode) {
        debugPrint('❌ Phonebook 연락처 로드 오류: $e');
      }
      // 개별 phonebook 연락처 로드 실패는 전체 프로세스를 중단하지 않음
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
          child: Row(
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

              // 검색 필터링
              if (_searchController.text.isNotEmpty) {
                final query = _searchController.text.toLowerCase();
                contacts = contacts.where((contact) {
                  final translatedName = _translateName(contact.name);
                  return contact.name.toLowerCase().contains(query) ||
                      translatedName.toLowerCase().contains(query) ||
                      contact.telephone.contains(query);
                }).toList();
              }

              if (contacts.isEmpty) {
                return Center(
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
                        '새로고침 버튼을 눌러 목록을 불러오세요',
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
                  return _buildContactListTile(contact);
                },
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
              _buildDetailRow('전화번호', contact.telephone, isPrimary: true),
              if (contact.mobile != null) _buildDetailRow('휴대전화', contact.mobile),
              if (contact.home != null) _buildDetailRow('집 전화', contact.home),
              if (contact.fax != null) _buildDetailRow('팩스', contact.fax),
              if (contact.email != null) _buildDetailRow('이메일', contact.email),
              if (contact.company != null) _buildDetailRow('회사', contact.company),
              if (contact.title != null) _buildDetailRow('직책', contact.title),
              if (contact.businessAddress != null)
                _buildDetailRow('회사 주소', contact.businessAddress),
              if (contact.homeAddress != null) _buildDetailRow('집 주소', contact.homeAddress),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('닫기'),
          ),
          ElevatedButton.icon(
            onPressed: () {
              Navigator.pop(context);
              _quickCall(contact.telephone);
            },
            icon: const Icon(Icons.phone),
            label: const Text('전화 걸기'),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF2196F3),
              foregroundColor: Colors.white,
            ),
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
}
