# 📞 연락처 조회 가이드

## 📋 개요

**ContactHelper**는 수신 전화 시 발신자 번호로 기기 연락처를 자동 조회하여 이름을 표시하는 유틸리티입니다.

---

## ✨ 주요 기능

### **1. 자동 연락처 조회**
- CallerIDName이 없을 때 자동으로 기기 연락처 조회
- 연락처에서 이름을 찾으면 자동 표시

### **2. 스마트 전화번호 매칭**
- 전화번호 정규화 (하이픈, 공백, 괄호 제거)
- 국가 코드 자동 변환 (+82, 82 → 0)
- 끝 8자리 매칭 (국가 코드 변형 대응)

### **3. 권한 관리**
- 연락처 권한 자동 요청
- 권한 상태 캐싱으로 성능 최적화
- 권한 거부 시 graceful fallback

---

## 🔍 조회 우선순위

### **1단계: CallerIDName 확인**
```
WebSocket Event → CallerIDName 존재?
  ↓ Yes
✅ CallerIDName 사용
```

### **2단계: 기기 연락처 조회**
```
CallerIDName 없음 or 비어있음
  ↓
🔍 기기 연락처에서 CallerIDNum 조회
  ↓
연락처 찾음? → ✅ 연락처 이름 사용
```

### **3단계: 전화번호 사용**
```
연락처에도 없음
  ↓
📞 CallerIDNum을 callerName으로 사용
```

---

## 📊 사용 예시

### **시나리오 1: CallerIDName 있음 (PBX에서 제공)**

**WebSocket Event**:
```json
{
  "CallerIDName": "김철수",
  "CallerIDNum": "01026132471"
}
```

**결과**:
```
✅ CallerIDName 존재: 김철수
📞 수신 전화 화면 표시:
  발신자: 김철수
  발신번호: 01026132471
```

---

### **시나리오 2: CallerIDName 없음 + 연락처 존재**

**WebSocket Event**:
```json
{
  "CallerIDName": "",
  "CallerIDNum": "010-2613-2471"
}
```

**기기 연락처**:
```
이름: 홍길동
전화번호: 010-2613-2471
```

**결과**:
```
🔍 CallerIDName 없음, 기기 연락처에서 조회 중...
🔍 ContactHelper: 연락처 조회 중...
  원본 번호: 010-2613-2471
  정규화 번호: 01026132471
📱 ContactHelper: 총 350개 연락처 검색
  📞 번호 매칭 (끝 8자리): 26132471
✅ ContactHelper: 연락처 찾음!
  이름: 홍길동
  연락처 번호: 010-2613-2471
✅ 연락처에서 이름 찾음: 홍길동
📞 수신 전화 화면 표시:
  발신자: 홍길동
  발신번호: 010-2613-2471
```

---

### **시나리오 3: CallerIDName 없음 + 연락처 없음**

**WebSocket Event**:
```json
{
  "CallerIDName": null,
  "CallerIDNum": "01099999999"
}
```

**기기 연락처**: 해당 번호 없음

**결과**:
```
🔍 CallerIDName 없음, 기기 연락처에서 조회 중...
🔍 ContactHelper: 연락처 조회 중...
  원본 번호: 01099999999
  정규화 번호: 01099999999
📱 ContactHelper: 총 350개 연락처 검색
❌ ContactHelper: 연락처를 찾지 못함
📞 연락처에 없음, 전화번호 사용: 01099999999
📞 수신 전화 화면 표시:
  발신자: 01099999999
  발신번호: 01099999999
```

---

## 🎯 전화번호 정규화 및 매칭

### **정규화 규칙**

| 입력 | 정규화 결과 |
|-----|-----------|
| `010-2613-2471` | `01026132471` |
| `010 2613 2471` | `01026132471` |
| `(010) 2613-2471` | `01026132471` |
| `+82-10-2613-2471` | `01026132471` |
| `82-10-2613-2471` | `01026132471` |

### **매칭 로직**

```dart
// 1. 정확히 일치
"01026132471" == "01026132471" → ✅ 매칭

// 2. 끝 8자리 일치 (국가 코드 변형 대응)
"01026132471" vs "+821026132471"
  끝 8자리: "26132471" == "26132471" → ✅ 매칭
```

---

## 🔐 연락처 권한 처리

### **권한 요청 흐름**

```dart
ContactHelper().getContactNameByPhone(phoneNumber)
  ↓
_checkPermission()
  ↓
FlutterContacts.requestPermission()
  ↓
사용자 승인? → ✅ 권한 캐싱 → 연락처 조회
사용자 거부? → ❌ null 반환 → 전화번호 사용
```

### **권한 캐싱**

```dart
// 최초 1회만 권한 요청
bool? _hasPermission; // 캐시

Future<bool> _checkPermission() async {
  if (_hasPermission != null) {
    return _hasPermission!; // 캐시 사용
  }
  
  final granted = await FlutterContacts.requestPermission();
  _hasPermission = granted; // 캐시 저장
  return granted;
}
```

---

## 📱 UI 표시 예시

### **수신 전화 화면**

```
┌─────────────────────────────────┐
│                                 │
│        📞 수신 전화              │
│                                 │
│      👤 홍길동                   │  ← 연락처에서 가져온 이름
│      010-2613-2471              │  ← 발신 번호
│                                 │
│   ┌─────────┐   ┌─────────┐   │
│   │ ✅ 수락 │   │ ❌ 거절 │   │
│   └─────────┘   └─────────┘   │
│                                 │
└─────────────────────────────────┘
```

**연락처 없는 경우**:
```
┌─────────────────────────────────┐
│                                 │
│        📞 수신 전화              │
│                                 │
│      👤 01099999999             │  ← 전화번호 그대로 표시
│      01099999999                │
│                                 │
│   ┌─────────┐   ┌─────────┐   │
│   │ ✅ 수락 │   │ ❌ 거절 │   │
│   └─────────┘   └─────────┘   │
│                                 │
└─────────────────────────────────┘
```

---

## 🛠️ 코드 사용 예시

### **기본 사용 (자동)**

```dart
// DCMIWSService에서 자동으로 처리됨
// 별도 호출 불필요

// _showIncomingCallScreen()에서 자동 실행:
// 1. CallerIDName 확인
// 2. 없으면 연락처 조회
// 3. 없으면 전화번호 사용
```

### **수동 사용**

```dart
// 특정 전화번호로 연락처 이름 조회
final contactName = await ContactHelper().getContactNameByPhone('010-2613-2471');

if (contactName != null) {
  print('연락처 이름: $contactName');
} else {
  print('연락처를 찾을 수 없음');
}
```

---

## 🐛 트러블슈팅

### **문제 1: 연락처 조회가 작동하지 않음**

**원인**: 연락처 권한이 거부됨

**해결**:
```
1. 기기 설정 → 앱 → MAKECALL → 권한 → 연락처 허용
2. 앱 재시작
3. 로그 확인:
   ⚠️ ContactHelper: 연락처 권한 없음
```

---

### **문제 2: 연락처가 있는데 찾지 못함**

**원인 1**: 전화번호 형식이 다름

**해결**:
```dart
// 연락처: 010-2613-2471
// 수신 번호: +82-10-2613-2471

// 정규화 후 비교되므로 정상 매칭되어야 함
// 로그 확인:
🔍 ContactHelper: 연락처 조회 중...
  원본 번호: +82-10-2613-2471
  정규화 번호: 01026132471
```

**원인 2**: 연락처가 iCloud 등 동기화 중

**해결**: 기기 연락처 앱에서 해당 연락처가 로컬에 있는지 확인

---

### **문제 3: 연락처 조회가 느림**

**원인**: 연락처가 너무 많음 (1000개 이상)

**성능 개선**:
```dart
// 현재 구현: O(n) 전체 검색
// 개선 방안: 전화번호 인덱싱 캐시

// 예상 성능:
// 100개 연락처: ~50ms
// 500개 연락처: ~200ms
// 1000개 연락처: ~400ms
```

---

## 📈 성능 메트릭

| 연락처 수 | 조회 시간 | 메모리 | 비고 |
|----------|---------|--------|-----|
| 100개 | ~50ms | ~2MB | 빠름 |
| 500개 | ~200ms | ~5MB | 보통 |
| 1000개 | ~400ms | ~10MB | 느림 |
| 5000개+ | ~2s | ~50MB | 매우 느림 |

**권한 캐싱 효과**:
- 최초 조회: ~100ms (권한 요청 포함)
- 이후 조회: ~50ms (권한 캐시 사용)

---

## 🔍 디버깅 로그

### **정상 흐름 (연락처 찾음)**

```
🔍 CallerIDName 없음, 기기 연락처에서 조회 중...
📋 ContactHelper: 연락처 권한 허용됨
🔍 ContactHelper: 연락처 조회 중...
  원본 번호: 010-2613-2471
  정규화 번호: 01026132471
📱 ContactHelper: 총 350개 연락처 검색
  📞 번호 매칭 (끝 8자리): 26132471
✅ ContactHelper: 연락처 찾음!
  이름: 홍길동
  연락처 번호: 010-2613-2471
✅ 연락처에서 이름 찾음: 홍길동
```

### **연락처 없음**

```
🔍 CallerIDName 없음, 기기 연락처에서 조회 중...
📋 ContactHelper: 연락처 권한 허용됨
🔍 ContactHelper: 연락처 조회 중...
  원본 번호: 01099999999
  정규화 번호: 01099999999
📱 ContactHelper: 총 350개 연락처 검색
❌ ContactHelper: 연락처를 찾지 못함
📞 연락처에 없음, 전화번호 사용: 01099999999
```

### **권한 거부**

```
🔍 CallerIDName 없음, 기기 연락처에서 조회 중...
📋 ContactHelper: 연락처 권한 거부됨
⚠️ ContactHelper: 연락처 권한 없음
❌ 연락처 조회 실패, 전화번호 사용: java.lang.SecurityException: Permission denied
📞 연락처에 없음, 전화번호 사용: 010-2613-2471
```

---

## 🎯 베스트 프랙티스

### **1. 권한 요청 타이밍**

```dart
// ✅ GOOD: 수신 전화 시 자동 요청 (필요할 때만)
if (callerName.isEmpty) {
  final contactName = await ContactHelper().getContactNameByPhone(callerNumber);
}

// ❌ BAD: 앱 시작 시 미리 요청 (불필요한 권한 요청)
void initState() {
  ContactHelper().getContactNameByPhone('dummy');
}
```

### **2. 에러 핸들링**

```dart
try {
  final contactName = await ContactHelper().getContactNameByPhone(callerNumber);
  callerName = contactName ?? callerNumber;
} catch (e) {
  // Graceful fallback
  callerName = callerNumber;
  debugPrint('연락처 조회 실패: $e');
}
```

### **3. 권한 캐시 활용**

```dart
// 권한 상태는 자동으로 캐싱됨
// 여러 번 호출해도 권한 요청은 1회만 발생
await ContactHelper().getContactNameByPhone('010-1111-1111'); // 권한 요청
await ContactHelper().getContactNameByPhone('010-2222-2222'); // 캐시 사용
await ContactHelper().getContactNameByPhone('010-3333-3333'); // 캐시 사용
```

---

## 📚 관련 파일

- `/lib/utils/contact_helper.dart` - 연락처 조회 유틸리티
- `/lib/services/dcmiws_service.dart` - 수신 전화 처리 (연락처 조회 통합)

---

## 🔄 변경 이력

### **v1.0.0** (2024-11-04)
- 🎉 **초기 릴리스**: 연락처 자동 조회 기능
- ✅ CallerIDName 우선순위 처리
- ✅ 스마트 전화번호 매칭
- ✅ 권한 관리 및 캐싱
- ✅ Graceful fallback

---

**최종 업데이트**: 2024-11-04  
**버전**: 1.0.0
