/// 단말번호 이름 번역 서비스
/// 
/// 영어 직책/부서명을 한글로 번역합니다.
class PhonebookTranslationService {
  // 영어 이름을 한글로 번역하는 매핑 테이블
  static final Map<String, String> _translations = {
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

  /// 영어 이름을 한글로 번역
  /// 
  /// - 이미 한글이 포함된 경우 원본 반환
  /// - 정확히 일치하는 번역이 있으면 번역본 반환
  /// - 부분 일치하는 번역이 있으면 부분 치환
  /// - 번역이 없으면 원본 반환
  static String translate(String name) {
    // 이미 한글이 포함되어 있으면 그대로 반환
    if (RegExp(r'[ㄱ-ㅎ가-힣]').hasMatch(name)) {
      return name;
    }

    // 정확히 일치하는 번역이 있는지 확인
    if (_translations.containsKey(name)) {
      return _translations[name]!;
    }

    // 부분 일치 번역 (대소문자 무시)
    final nameLower = name.toLowerCase();
    for (final entry in _translations.entries) {
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
}
