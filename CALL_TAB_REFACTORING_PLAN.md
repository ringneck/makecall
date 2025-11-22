# CallTab 리팩토링 계획

## 📊 현재 상태 분석

### 파일 크기
- **라인 수**: 2,898 라인
- **파일 크기**: 107KB
- **메서드 수**: 31개 이상

### 주요 문제점
1. 🔴 **단일 책임 원칙(SRP) 위반**: 하나의 파일이 너무 많은 책임을 가짐
2. 🔴 **가독성 저하**: 2,000+ 라인의 코드는 유지보수가 어려움
3. 🔴 **재사용성 부족**: 위젯들이 단일 파일에 묶여있어 재사용 불가
4. 🔴 **테스트 어려움**: 모든 로직이 한 곳에 있어 단위 테스트 불가능
5. 🔴 **협업 충돌**: 여러 개발자가 동시에 수정 시 Git 충돌 가능성 높음

### 주요 책임 분석
```dart
_CallTabState {
  // 1. 탭 관리 (4개 탭)
  - 즐겨찾기 탭 (160 라인)
  - 통화 기록 탭 (428 라인)
  - 연락처 탭 (128 라인)
  - 키패드 탭 (별도 파일)
  
  // 2. 초기화 로직
  - AuthService 리스너 등록
  - 단말번호 자동 초기화
  - 설정 체크
  - FCM 초기화 확인
  
  // 3. 연락처 관리
  - 저장된 연락처 표시
  - 기기 연락처 로드
  - 연락처 추가/수정/삭제
  
  // 4. 통화 관리
  - 통화 기록 표시
  - 통화 방식 선택
  - 클릭투콜 실행
  
  // 5. UI 컴포넌트
  - AppBar
  - BottomNavigationBar
  - Drawer (Profile, Extension)
  - 다이얼로그들
}
```

## 🎯 리팩토링 목표

### 1차 목표: 파일 분리
- **현재**: 1개 파일 2,898 라인
- **목표**: 10-15개 파일, 각 200-300 라인

### 2차 목표: 코드 품질 향상
- 단일 책임 원칙 준수
- 높은 재사용성
- 쉬운 테스트
- 명확한 의존성

### 3차 목표: 성능 최적화
- 불필요한 리빌드 방지
- 메모리 사용 최적화
- 로딩 속도 개선

## 📁 새로운 파일 구조

```
lib/screens/call/
├── call_tab.dart (메인 - 300 라인)
│
├── tabs/ (탭별 위젯)
│   ├── favorites_tab.dart (즐겨찾기 - 200 라인)
│   ├── call_history_tab.dart (통화 기록 - 300 라인)
│   ├── contacts_tab.dart (연락처 - 250 라인)
│   └── dialpad_screen.dart (기존)
│
├── widgets/ (재사용 가능한 UI 컴포넌트)
│   ├── contact_list_tile.dart (연락처 타일 - 150 라인)
│   ├── call_history_tile.dart (통화 기록 타일 - 200 라인)
│   ├── favorite_contact_card.dart (즐겨찾기 카드 - 100 라인)
│   └── extension_info_widget.dart (기존)
│
├── services/ (비즈니스 로직)
│   ├── call_tab_initializer.dart (초기화 로직 - 200 라인)
│   └── settings_checker.dart (설정 체크 - 150 라인)
│
└── models/ (데이터 모델 - 필요시)
    └── call_tab_state.dart (상태 관리)
```

## 🔧 단계별 리팩토링 계획

### Phase 1: 탭 위젯 분리 (가장 큰 영향)

#### 1.1. Favorites Tab 분리
**파일**: `lib/screens/call/tabs/favorites_tab.dart`

**라인**: 1035-1194 (160 라인)

**책임**:
- Favorite Codes 표시
- 즐겨찾기 그리드 레이아웃
- 클릭투콜 실행
- Feature Codes 번역

**필요한 Props**:
```dart
class FavoritesTab extends StatelessWidget {
  final String userId;
  final Function(PhonebookContactModel) onContactTap;
  final Map<String, String> nameTranslations;
  
  const FavoritesTab({
    required this.userId,
    required this.onContactTap,
    required this.nameTranslations,
  });
}
```

#### 1.2. Call History Tab 분리
**파일**: `lib/screens/call/tabs/call_history_tab.dart`

**라인**: 1195-1622 (428 라인)

**책임**:
- 통화 기록 스트림 리스닝
- 날짜별 그룹핑
- 통화 기록 타일 표시
- 상세 정보 다이얼로그

**필요한 Props**:
```dart
class CallHistoryTab extends StatefulWidget {
  final String userId;
  final Function(CallHistoryModel) onCallTap;
  final Function(CallHistoryModel) onCallDetailTap;
}
```

#### 1.3. Contacts Tab 분리
**파일**: `lib/screens/call/tabs/contacts_tab.dart`

**라인**: 1623-1750 (128 라인)

**책임**:
- 저장된 연락처 표시
- 기기 연락처 로드
- 검색 기능
- 연락처 추가/수정 다이얼로그

**필요한 Props**:
```dart
class ContactsTab extends StatefulWidget {
  final String userId;
  final TextEditingController searchController;
  final Function(ContactModel) onContactTap;
  final Function(ContactModel) onEditContact;
  final Function onAddContact;
}
```

### Phase 2: UI 컴포넌트 분리

#### 2.1. Contact List Tile
**파일**: `lib/screens/call/widgets/contact_list_tile.dart`

**라인**: 1861-2625 (765 라인!)

**책임**:
- 연락처 타일 UI
- 스와이프 액션 (수정/삭제)
- 통화 방식 선택
- 클릭투콜 실행

**리팩토링 필요**:
```dart
// Before: 거대한 단일 위젯
Widget _buildContactListTile(...) {
  return Slidable(
    // 700+ 라인의 복잡한 로직
  );
}

// After: 여러 작은 위젯으로 분리
class ContactListTile extends StatelessWidget {
  // 핵심 UI만
}

class ContactSwipeActions extends StatelessWidget {
  // 스와이프 액션만
}

class CallMethodSelector extends StatelessWidget {
  // 통화 방식 선택만
}
```

#### 2.2. Call History Tile
**파일**: `lib/screens/call/widgets/call_history_tile.dart`

**새로 생성**

**책임**:
- 통화 기록 타일 UI
- 통화 타입 아이콘 (수신/발신/부재중)
- 날짜 포맷팅
- 탭 액션

#### 2.3. Favorite Contact Card
**파일**: `lib/screens/call/widgets/favorite_contact_card.dart`

**새로 생성**

**책임**:
- 즐겨찾기 그리드 카드 UI
- Feature Code 아이콘
- 이름 번역
- 탭 액션

### Phase 3: 비즈니스 로직 분리

#### 3.1. Call Tab Initializer
**파일**: `lib/screens/call/services/call_tab_initializer.dart`

**라인**: 71-161 (초기화 로직)

**책임**:
```dart
class CallTabInitializer {
  final AuthService authService;
  final DatabaseService databaseService;
  
  // 초기화 체인 실행
  Future<void> initialize({
    required BuildContext context,
    required VoidCallback onAuthStateChanged,
  });
  
  // 단말번호 자동 초기화
  Future<void> initializeExtensions(String userId);
  
  // 설정 체크
  Future<void> checkSettings(String userId);
  
  // 신규 사용자 체크
  Future<void> checkNewUser(String userId);
}
```

#### 3.2. Settings Checker
**파일**: `lib/screens/call/services/settings_checker.dart`

**라인**: 395-780 (설정 체크 로직)

**책임**:
```dart
class SettingsChecker {
  // REST API 설정 확인
  Future<bool> hasApiSettings(UserModel user);
  
  // 단말번호 확인
  Future<bool> hasExtensions(String userId);
  
  // 설정 안내 다이얼로그 표시
  Future<void> showSettingsGuideDialog(BuildContext context);
}
```

### Phase 4: 메인 파일 정리

#### call_tab.dart (최종 구조)
```dart
class CallTab extends StatefulWidget { }

class _CallTabState extends State<CallTab> {
  // 1. State 변수들 (50 라인)
  late int _currentTabIndex;
  final _scaffoldKey = GlobalKey<ScaffoldState>();
  // ...
  
  // 2. Lifecycle (100 라인)
  @override
  void initState() {
    // CallTabInitializer 사용
  }
  
  @override
  void dispose() { }
  
  // 3. Event Handlers (50 라인)
  void _onAuthServiceStateChanged() { }
  void _onTabTapped(int index) { }
  
  // 4. Build Method (100 라인)
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: _buildAppBar(),
      drawer: ProfileDrawer(),
      endDrawer: ExtensionDrawer(),
      body: _buildBody(),
      bottomNavigationBar: _buildBottomNav(),
    );
  }
  
  // 5. Private Build Methods (100 라인)
  Widget _buildAppBar() { }
  Widget _buildBody() {
    // 탭별 위젯 반환
    return [
      FavoritesTab(...),
      CallHistoryTab(...),
      DialpadScreen(),
      ContactsTab(...),
      PhonebookTab(),
    ][_currentTabIndex];
  }
  Widget _buildBottomNav() { }
}

// 총 약 300-400 라인으로 축소!
```

## 📊 예상 효과

### Before (현재)
```
call_tab.dart: 2,898 라인, 107KB
- 가독성: ⭐
- 재사용성: ⭐
- 테스트 용이성: ⭐
- 유지보수성: ⭐
- 협업 편의성: ⭐
```

### After (리팩토링 후)
```
총 라인 수: ~3,000 라인 (비슷하지만 10-15개 파일로 분산)

call_tab.dart: 300 라인
tabs/: 750 라인 (3개 파일)
widgets/: 550 라인 (3개 파일)
services/: 350 라인 (2개 파일)
기타: 1,050 라인

- 가독성: ⭐⭐⭐⭐⭐
- 재사용성: ⭐⭐⭐⭐⭐
- 테스트 용이성: ⭐⭐⭐⭐⭐
- 유지보수성: ⭐⭐⭐⭐⭐
- 협업 편의성: ⭐⭐⭐⭐⭐
```

## ⚠️ 주의사항

### 1. 점진적 리팩토링
- 한 번에 모두 변경하지 않기
- 단계별로 테스트하며 진행
- 각 단계마다 Git 커밋

### 2. 기능 유지
- 리팩토링은 기능 변경이 아님
- 모든 기존 기능이 정상 작동해야 함
- UI/UX 변경 없음

### 3. 의존성 관리
- Provider 패턴 유지
- AuthService, DatabaseService 등 기존 서비스 활용
- 새로운 의존성 최소화

### 4. 테스트
- 각 단계마다 충분한 테스트
- 특히 통화 기능은 반드시 검증
- 다양한 시나리오 테스트

## 📅 실행 일정 (제안)

### Day 1: Phase 1 (탭 분리)
- Favorites Tab 분리
- Call History Tab 분리
- Contacts Tab 분리
- 테스트 및 검증

### Day 2: Phase 2 (UI 컴포넌트)
- Contact List Tile 분리
- Call History Tile 생성
- Favorite Contact Card 생성
- 테스트 및 검증

### Day 3: Phase 3 (비즈니스 로직)
- Call Tab Initializer 분리
- Settings Checker 분리
- 테스트 및 검증

### Day 4: Phase 4 (통합 및 최적화)
- 메인 파일 정리
- 전체 통합 테스트
- 성능 최적화
- 문서화

## ✅ 체크리스트

- [ ] Phase 1: 탭 위젯 분리
  - [ ] FavoritesTab 생성 및 테스트
  - [ ] CallHistoryTab 생성 및 테스트
  - [ ] ContactsTab 생성 및 테스트

- [ ] Phase 2: UI 컴포넌트 분리
  - [ ] ContactListTile 분리
  - [ ] CallHistoryTile 생성
  - [ ] FavoriteContactCard 생성

- [ ] Phase 3: 비즈니스 로직 분리
  - [ ] CallTabInitializer 생성
  - [ ] SettingsChecker 생성

- [ ] Phase 4: 메인 파일 정리
  - [ ] call_tab.dart 간소화
  - [ ] 불필요한 코드 제거
  - [ ] Import 정리

- [ ] 최종 검증
  - [ ] 전체 기능 테스트
  - [ ] 성능 측정
  - [ ] 코드 리뷰
  - [ ] 문서 업데이트

## 🚀 시작하시겠습니까?

리팩토링을 시작하려면 다음 중 선택해주세요:

1. **전체 자동 리팩토링** - 위의 계획대로 모든 단계를 자동으로 실행
2. **단계별 리팩토링** - Phase 1부터 시작하여 단계별로 진행
3. **특정 부분만 리팩토링** - 예: "Contact List Tile만 먼저 분리"
4. **계획 수정** - 리팩토링 계획을 먼저 논의

어떤 방식으로 진행하시겠습니까?
