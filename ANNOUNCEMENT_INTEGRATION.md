# 📢 공지사항 기능 통합 가이드

## 개요

MAKECALL 앱의 공지사항 시스템이 완전히 통합되었습니다.

### 주요 기능
- ✅ Firebase Firestore에서 공지사항 조회
- ✅ "다시 보지 않기" 체크박스 (SharedPreferences 저장)
- ✅ 오른쪽 상단 닫기 버튼 (X)
- ✅ 다크모드 최적화
- ✅ 우선순위 표시 (high/normal/low)
- ✅ 공지 기간 관리 (start_date ~ end_date)

---

## 📁 구현 파일

### 1. 서비스
- `lib/services/announcement_service.dart`: Firestore 공지사항 조회

### 2. 위젯
- `lib/widgets/announcement_bottom_sheet.dart`: 공지사항 ModalBottomSheet

### 3. 화면
- `lib/screens/home/main_screen.dart`: MainScreen에서 자동 공지사항 체크

### 4. 스크립트
- `scripts/setup_announcement.py`: Firestore 공지사항 샘플 데이터 생성

---

## 🔧 Firestore 데이터 구조

```
app_config (collection)
└── announcements (document)
    └── items (collection)
        └── {announcement_id} (document)
            ├── title: "공지사항 제목"
            ├── message: "공지사항 내용"
            ├── priority: "high" | "normal" | "low"
            ├── is_active: true | false
            ├── start_date: Timestamp (공지 시작일)
            ├── end_date: Timestamp (공지 종료일)
            └── created_at: Timestamp
```

### 필드 설명

| 필드 | 타입 | 설명 | 예시 |
|------|------|------|------|
| `title` | String | 공지사항 제목 | "새로운 기능 추가 🎉" |
| `message` | String | 공지사항 내용 (줄바꿈 지원) | "• 다크모드 지원\n• 성능 개선" |
| `priority` | String | 우선순위 | "high", "normal", "low" |
| `is_active` | Boolean | 활성 상태 | true, false |
| `start_date` | Timestamp | 공지 시작일 | 2025-12-04 |
| `end_date` | Timestamp | 공지 종료일 | 2026-01-04 |
| `created_at` | Timestamp | 생성 시각 | SERVER_TIMESTAMP |

---

## 🚀 공지사항 표시 흐름

### MainScreen 진입 시

```
1. 사용자가 MainScreen 진입
   ↓
2. initState()에서 화면 렌더링 완료 대기
   ↓
3. _checkAnnouncement() 실행
   ↓
4. Firestore에서 활성 공지사항 조회
   - is_active = true
   - start_date ≤ 현재 시각
   - end_date ≥ 현재 시각
   - priority 높은 순 정렬
   ↓
5. "다시 보지 않기" 체크 확인
   - SharedPreferences에서 'announcement_hidden_{id}' 확인
   - true이면 표시 안 함
   ↓
6. AnnouncementBottomSheet 표시
```

### 사용자 액션

```
[닫기 버튼 (X) 클릭]
   ↓
"다시 보지 않기" 체크 여부 확인
   ↓
체크된 경우: SharedPreferences 저장
체크 안 된 경우: 저장하지 않음
   ↓
BottomSheet 닫기
```

---

## 📝 테스트 시나리오

### 1. 공지사항 자동 표시 테스트
```
1. 앱 재시작
2. 로그인
3. MainScreen 진입
4. ✅ 공지사항 BottomSheet 자동 표시 확인
```

### 2. "다시 보지 않기" 테스트
```
1. 공지사항 BottomSheet에서 "다시 보지 않기" 체크
2. 닫기 버튼 클릭
3. 앱 재시작 후 다시 로그인
4. ✅ 동일한 공지사항이 표시되지 않음 확인
```

### 3. 닫기 버튼 테스트
```
1. 공지사항 BottomSheet에서 닫기 버튼 (X) 클릭
2. ✅ BottomSheet가 즉시 닫힘 확인
```

### 4. 다크모드 테스트
```
1. 시스템 다크모드 설정
2. 공지사항 BottomSheet 확인
3. ✅ 다크모드에 맞는 UI 색상 확인
```

### 5. 우선순위 테스트
```
Firebase Console에서:
1. priority를 'high'로 변경
2. ✅ 빨간색 배지 (⚠️ 중요) 확인

priority를 'normal'로 변경
3. ✅ 파란색 배지 (📢 공지) 확인

priority를 'low'로 변경
4. ✅ 초록색 배지 (ℹ️ 일반) 확인
```

---

## 💡 공지사항 관리

### Firebase Console에서 관리

#### 새 공지사항 추가
```
1. Firebase Console 접속
2. Firestore Database 선택
3. app_config/announcements/items 경로로 이동
4. 새 문서 추가
5. 필드 입력:
   - title: "공지사항 제목"
   - message: "공지사항 내용"
   - priority: "normal"
   - is_active: true
   - start_date: 시작일 선택
   - end_date: 종료일 선택
   - created_at: 현재 시각
```

#### 공지사항 비활성화
```
1. Firebase Console에서 해당 공지사항 문서 선택
2. is_active를 false로 변경
3. ✅ 즉시 앱에서 표시되지 않음
```

#### 공지사항 기간 연장
```
1. Firebase Console에서 해당 공지사항 문서 선택
2. end_date를 새로운 날짜로 변경
3. ✅ 연장된 기간 동안 계속 표시됨
```

#### 공지사항 우선순위 변경
```
1. Firebase Console에서 해당 공지사항 문서 선택
2. priority를 'high', 'normal', 'low' 중 선택
3. ✅ 변경된 우선순위로 표시됨
   - high: ⚠️ 중요 (빨간색)
   - normal: 📢 공지 (파란색)
   - low: ℹ️ 일반 (초록색)
```

---

## 🔍 로그 확인

### 공지사항 조회 성공
```
📢 [ANNOUNCEMENT] 공지사항 조회 성공
   ID: vrFhQrcTdQzt4or5cjD8
   Title: 새로운 기능이 추가되었습니다! 🎉
   Priority: normal
```

### 활성 공지사항 없음
```
📢 [ANNOUNCEMENT] 활성 공지사항 없음
```

### "다시 보지 않기" 저장
```
📢 [ANNOUNCEMENT] 다시 보지 않기 설정: vrFhQrcTdQzt4or5cjD8
```

### "다시 보지 않기"로 숨겨진 공지
```
📢 [ANNOUNCEMENT] 사용자가 "다시 보지 않기"를 선택한 공지: vrFhQrcTdQzt4or5cjD8
```

---

## 🛠️ 개발자용

### 공지사항 프로그래밍 방식으로 생성

```bash
# 샘플 공지사항 생성
cd /home/user/flutter_app
python3 scripts/setup_announcement.py
```

### "다시 보지 않기" 초기화 (테스트용)

```dart
// SharedPreferences에서 특정 공지사항 숨김 상태 제거
final prefs = await SharedPreferences.getInstance();
await prefs.remove('announcement_hidden_vrFhQrcTdQzt4or5cjD8');
```

### 모든 공지사항 숨김 상태 초기화

```dart
final prefs = await SharedPreferences.getInstance();
final keys = prefs.getKeys();
for (final key in keys) {
  if (key.startsWith('announcement_hidden_')) {
    await prefs.remove(key);
  }
}
```

---

## 📊 Firestore 쿼리 최적화

### 현재 쿼리 방식

```dart
// AnnouncementService의 쿼리
final querySnapshot = await _firestore
    .collection('app_config')
    .document('announcements')
    .collection('items')
    .where('is_active', isEqualTo: true)
    .where('start_date', isLessThanOrEqualTo: now)
    .where('end_date', isGreaterThanOrEqualTo: now)
    .orderBy('start_date')
    .orderBy('priority', descending: true)
    .limit(1)
    .get();
```

### 필요한 복합 인덱스

Firebase Console에서 다음 복합 인덱스 생성 필요:
- Collection: `app_config/announcements/items`
- Fields:
  1. `is_active` (Ascending)
  2. `start_date` (Ascending)
  3. `end_date` (Ascending)
  4. `priority` (Descending)

**자동 생성**: 앱 실행 시 Firebase Console에서 자동으로 인덱스 생성 링크 제공

---

## ✅ 체크리스트

### 구현 완료
- [x] AnnouncementService 구현
- [x] AnnouncementBottomSheet 위젯 구현
- [x] MainScreen 통합
- [x] "다시 보지 않기" 기능
- [x] 닫기 버튼 구현
- [x] 다크모드 최적화
- [x] 우선순위 표시
- [x] 공지 기간 관리
- [x] Firestore 샘플 데이터 생성 스크립트

### 테스트 완료
- [ ] 공지사항 자동 표시
- [ ] "다시 보지 않기" 동작
- [ ] 닫기 버튼 동작
- [ ] 다크모드 UI
- [ ] 우선순위 표시

---

## 📦 관련 파일

- **서비스**: `lib/services/announcement_service.dart`
- **위젯**: `lib/widgets/announcement_bottom_sheet.dart`
- **화면**: `lib/screens/home/main_screen.dart`
- **스크립트**: `scripts/setup_announcement.py`

---

## 🌐 Git Repository

Repository: https://github.com/ringneck/makecall

---

## 📞 문의

문제가 발생하거나 추가 기능이 필요한 경우 GitHub Issues에 문의해 주세요.
