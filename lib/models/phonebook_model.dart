class PhonebookModel {
  final String id; // Firestore document ID
  final String userId; // 사용자 ID
  final String phonebookId; // API phonebook ID
  final String name; // Phonebook 이름
  final String sourceType; // internal, external 등
  final DateTime createdAt;

  PhonebookModel({
    required this.id,
    required this.userId,
    required this.phonebookId,
    required this.name,
    required this.sourceType,
    required this.createdAt,
  });

  // Firestore에서 데이터 읽기
  factory PhonebookModel.fromFirestore(Map<String, dynamic> data, String id) {
    return PhonebookModel(
      id: id,
      userId: data['userId'] as String? ?? '',
      phonebookId: data['phonebookId'] as String? ?? '',
      name: data['name'] as String? ?? '',
      sourceType: data['sourceType'] as String? ?? '',
      createdAt: (data['createdAt'] as dynamic)?.toDate() ?? DateTime.now(),
    );
  }

  // Firestore에 저장할 데이터
  Map<String, dynamic> toFirestore() {
    return {
      'userId': userId,
      'phonebookId': phonebookId,
      'name': name,
      'sourceType': sourceType,
      'createdAt': createdAt,
    };
  }

  // API 응답에서 생성
  factory PhonebookModel.fromApi(Map<String, dynamic> apiData, String userId) {
    return PhonebookModel(
      id: '',
      userId: userId,
      phonebookId: apiData['id']?.toString() ?? '',
      name: apiData['name']?.toString() ?? '',
      sourceType: apiData['source_type']?.toString() ?? '',
      createdAt: DateTime.now(),
    );
  }
}

class PhonebookContactModel {
  final String id; // Firestore document ID
  final String userId; // 사용자 ID
  final String phonebookId; // 상위 Phonebook ID
  final String contactId; // API contact ID
  final String name; // 이름
  final String telephone; // 전화번호
  final String category; // Extensions, Feature Codes 등
  final String categoryDisplay; // 화면 표시용 (단말번호, 기능번호)
  final String? email;
  final String? company;
  final String? title;
  final String? mobileNumber;
  final String? home;
  final String? fax;
  final String? businessAddress;
  final String? homeAddress;
  final bool isFavorite; // 즐겨찾기 여부
  final DateTime createdAt;

  PhonebookContactModel({
    required this.id,
    required this.userId,
    required this.phonebookId,
    required this.contactId,
    required this.name,
    required this.telephone,
    required this.category,
    required this.categoryDisplay,
    this.email,
    this.company,
    this.title,
    this.mobileNumber,
    this.home,
    this.fax,
    this.businessAddress,
    this.homeAddress,
    this.isFavorite = false, // 기본값: false
    required this.createdAt,
  });

  // Firestore에서 데이터 읽기
  factory PhonebookContactModel.fromFirestore(Map<String, dynamic> data, String id) {
    return PhonebookContactModel(
      id: id,
      userId: data['userId'] as String? ?? '',
      phonebookId: data['phonebookId'] as String? ?? '',
      contactId: data['contactId'] as String? ?? '',
      name: data['name'] as String? ?? '',
      telephone: data['telephone'] as String? ?? '',
      category: data['category'] as String? ?? '',
      categoryDisplay: data['categoryDisplay'] as String? ?? '',
      email: data['email'] as String?,
      company: data['company'] as String?,
      title: data['title'] as String?,
      mobileNumber: data['mobileNumber'] as String? ?? data['mobile'] as String?, // 기존 'mobile' 필드도 지원
      home: data['home'] as String?,
      fax: data['fax'] as String?,
      businessAddress: data['businessAddress'] as String?,
      homeAddress: data['homeAddress'] as String?,
      isFavorite: data['isFavorite'] as bool? ?? false, // 기본값: false
      createdAt: (data['createdAt'] as dynamic)?.toDate() ?? DateTime.now(),
    );
  }

  // Firestore에 저장할 데이터
  Map<String, dynamic> toFirestore() {
    return {
      'userId': userId,
      'phonebookId': phonebookId,
      'contactId': contactId,
      'name': name,
      'telephone': telephone,
      'category': category,
      'categoryDisplay': categoryDisplay,
      'email': email,
      'company': company,
      'title': title,
      'mobileNumber': mobileNumber,
      'home': home,
      'fax': fax,
      'businessAddress': businessAddress,
      'homeAddress': homeAddress,
      'isFavorite': isFavorite,
      'createdAt': createdAt,
    };
  }

  // API 응답에서 생성
  factory PhonebookContactModel.fromApi(
    Map<String, dynamic> apiData,
    String userId,
    String phonebookId,
  ) {
    final category = apiData['category']?.toString() ?? '';
    String categoryDisplay = category;
    
    // category를 한글로 변환
    if (category == 'Extensions') {
      categoryDisplay = '단말번호';
    } else if (category == 'Feature Codes') {
      categoryDisplay = '기능번호';
    } else if (category == 'Ring Groups') {
      categoryDisplay = '링그룹';
    } else if (category == 'Conferences') {
      categoryDisplay = '음성회의';
    } else if (category == 'Speed Dialing') {
      categoryDisplay = '단축발신';
    }

    // contactId 생성: API id가 있으면 사용, 없으면 전화번호 기반으로 생성
    final apiId = apiData['id']?.toString() ?? '';
    final telephone = apiData['telephone']?.toString() ?? '';
    
    // 고유 contactId 생성: phonebookId + telephone 조합 (전화번호는 고유함)
    final contactId = apiId.isNotEmpty 
        ? apiId 
        : '${phonebookId}_$telephone';

    return PhonebookContactModel(
      id: '',
      userId: userId,
      phonebookId: phonebookId,
      contactId: contactId,
      name: apiData['name']?.toString() ?? '',
      telephone: telephone,
      category: category,
      categoryDisplay: categoryDisplay,
      email: apiData['email']?.toString(),
      company: apiData['company']?.toString(),
      title: apiData['title']?.toString(),
      mobileNumber: apiData['mobile_number']?.toString(),
      home: apiData['home']?.toString(),
      fax: apiData['fax']?.toString(),
      businessAddress: apiData['business_address']?.toString(),
      homeAddress: apiData['home_address']?.toString(),
      isFavorite: false, // API에서 불러올 때는 기본값 false
      createdAt: DateTime.now(),
    );
  }
}
