# Click-to-Call 아키텍처 문서

## 📋 목차
- [개요](#개요)
- [아키텍처 원칙](#아키텍처-원칙)
- [데이터 흐름](#데이터-흐름)
- [핵심 컴포넌트](#핵심-컴포넌트)
- [시나리오별 처리](#시나리오별-처리)
- [디버깅 가이드](#디버깅-가이드)

---

## 🎯 개요

MAKECALL 앱의 클릭투콜 기능은 **WebSocket 이벤트 기반 아키텍처**를 사용하여 통화 기록을 생성합니다.

### 핵심 원칙

**🔒 Linkedid 불변성 (Immutability)**
- Linkedid는 **생성 시점에만 설정**
- **절대 업데이트하지 않음** (UPDATE 금지)
- 변경 필요 시 **DELETE + CREATE** 패턴 사용

**⏱️ 이벤트 기반 처리**
- 통화 기록은 **Newchannel 이벤트 도착 시** 생성
- API 호출 즉시 생성하지 않음
- 10초 타임아웃으로 안정성 보장

---

## 🏗️ 아키텍처 원칙

### 1. Pending Storage 패턴

```dart
// 임시 저장소: Map<extensionNumber, callData>
final Map<String, Map<String, dynamic>> _pendingClickToCallRecords = {};
```

**목적**: 
- Newchannel 이벤트가 도착할 때까지 통화 정보를 임시 저장
- 이벤트와 API 응답 사이의 타이밍 차이 처리

**특징**:
- Key: 단말번호 (extensionNumber)
- Value: 통화 정보 (phoneNumber, userId, callForwardInfo 등)
- 자동 타임아웃: 10초 후 자동 생성

### 2. Linkedid 불변성

**❌ 잘못된 패턴 (UPDATE)**:
```dart
// 🚫 절대 사용 금지!
await doc.reference.update({
  'linkedid': linkedid,  // UPDATE 연산
});
```

**✅ 올바른 패턴 (DELETE + CREATE)**:
```dart
// 1. 기존 데이터 복사
final Map<String, dynamic> newDocData = Map.from(data);

// 2. Linkedid 추가
newDocData['linkedid'] = linkedid;

// 3. 기존 문서 삭제
await doc.reference.delete();

// 4. 새 문서 생성
await firestore.collection('call_history').add(newDocData);
```

**이유**:
- Firestore 쿼리 최적화
- 데이터 무결성 보장
- 이벤트 순서 문제 방지

### 3. 중복 방지 시스템

**3단계 중복 체크**:
1. **Pending Storage 진입 전**: Linkedid로 기존 기록 확인
2. **Fallback 모드 진입 전**: 다시 한번 Linkedid로 확인
3. **실제 생성 전**: 최종 중복 확인

```dart
// 중복 확인 쿼리
final duplicateCheck = await firestore
    .collection('call_history')
    .where('userId', isEqualTo: userId)
    .where('linkedid', isEqualTo: linkedid)
    .limit(1)
    .get();

if (duplicateCheck.docs.isNotEmpty) {
  // 중복 발견 → 건너뛰기
  return;
}
```

---

## 📊 데이터 흐름

### 정상 시나리오 (Newchannel 이벤트 정상 수신)

```
1. 사용자 클릭
   ↓
2. Click-to-Call API 호출
   ↓
3. storePendingClickToCallRecord()
   - Pending Storage에 임시 저장
   - 10초 타임아웃 예약
   ↓
4. Newchannel 이벤트 도착 (3초 이내)
   ↓
5. _saveClickToCallLinkedId() 호출
   - Pending Storage에서 데이터 조회
   - 중복 확인
   - Linkedid와 함께 Firestore 생성
   ↓
6. ✅ 통화 기록 생성 완료 (Linkedid 포함)
```

### 타임아웃 시나리오 (Newchannel 이벤트 지연)

```
1. 사용자 클릭
   ↓
2. Click-to-Call API 호출
   ↓
3. storePendingClickToCallRecord()
   - Pending Storage에 임시 저장
   - 10초 타임아웃 예약
   ↓
4. ⏰ 10초 경과 (이벤트 미도착)
   ↓
5. _createCallHistoryFromPending() 호출
   - Linkedid 없이 Firestore 생성
   ↓
6. ⚠️ 통화 기록 생성 완료 (Linkedid 없음)
   ↓
7. Newchannel 이벤트 도착 (10초 이후)
   ↓
8. Fallback Mode 진입
   - Firestore에서 linkedid 없는 기록 검색
   - 기존 문서 DELETE
   - Linkedid와 함께 새 문서 CREATE
   ↓
9. ✅ 통화 기록 재생성 완료 (Linkedid 포함)
```

---

## 🔧 핵심 컴포넌트

### 1. storePendingClickToCallRecord()

**위치**: `lib/services/dcmiws_service.dart:1641`

**역할**: 
- Click-to-Call API 호출 직후 통화 정보를 임시 저장
- 10초 타임아웃 설정

**호출 지점**:
- `lib/screens/call/dialpad_screen.dart` (키패드)
- `lib/screens/call/call_tab.dart` (즐겨찾기/최근통화)
- `lib/screens/call/phonebook_tab.dart` (연락처)
- `lib/widgets/call_method_dialog.dart` (통화 방법 선택)

**파라미터**:
```dart
void storePendingClickToCallRecord({
  required String extensionNumber,      // 단말번호
  required String phoneNumber,          // 발신번호
  required String userId,                // 사용자 ID
  required String mainNumberUsed,        // 대표번호
  required bool callForwardEnabled,      // 착신전환 활성화 여부
  String? callForwardDestination,        // 착신전환 목적지
})
```

**로그 예시**:
```
============================================================
📝 클릭투콜 임시 저장 (Pending Storage)
============================================================
  단말번호: 60001
  발신번호: 01012345678
  대표번호: 028001234
  착신전환 활성화: true
  착신전환 목적지: 01099998888
  → Newchannel 이벤트 대기 중... (타임아웃: 10초)
============================================================
```

### 2. _saveClickToCallLinkedId()

**위치**: `lib/services/dcmiws_service.dart:699`

**역할**:
- Newchannel 이벤트 도착 시 호출
- Pending Storage 또는 Firestore에서 데이터 조회
- Linkedid와 함께 통화 기록 생성

**처리 흐름**:
1. **Step 1**: Pending Storage 확인
   - 데이터 있음 → 즉시 생성
   - 데이터 없음 → Fallback Mode
2. **Step 2**: Fallback Mode (Firestore 검색)
   - 최근 1분 이내 기록 검색
   - linkedid 없는 기록 찾기
   - DELETE + CREATE 패턴으로 재생성

**파라미터**:
```dart
Future<void> _saveClickToCallLinkedId(
  String linkedid,  // Newchannel 이벤트의 Linkedid
  String exten,     // 단말번호
)
```

**로그 예시 (정상)**:
```
============================================================
📞 Newchannel 이벤트 감지 (Click-to-Call)
============================================================
  Channel: Local/60001@click-to-call-123;1
  Context: from-internal-click-to-call
  Linkedid: 1234567890.123
  Exten (단말번호): 60001
  → Pending Storage에서 데이터 조회 후 Firestore 생성
============================================================

🔍 통화 기록 생성 프로세스 시작
  Exten (단말번호): 60001
  Linkedid: 1234567890.123
  → Step 1: Pending Storage 확인
  ✅ Pending Storage에서 발견!
  → Step 2: 중복 확인 후 Firestore 생성

✅ 클릭투콜 기록 생성 완료 - 정상 모드 (Linkedid 포함)
   단말번호: 60001
   발신번호: 01012345678
   Linkedid: 1234567890.123
   착신전환: true
   착신전환 목적지: 01099998888
```

**로그 예시 (Fallback)**:
```
🔍 통화 기록 생성 프로세스 시작
  Exten (단말번호): 60001
  Linkedid: 1234567890.123
  → Step 1: Pending Storage 확인
  ⚠️ Pending Storage에 데이터 없음
  단말번호: 60001
  원인: 10초 타임아웃으로 이미 Firestore에 저장됨
  → Fallback Mode: Firestore에서 linkedid 없는 기록 검색

📋 Fallback 조회 결과: 3개
✅ 매칭된 기록 발견! (Fallback 모드)
   - 문서 ID: abc123xyz
   - 발신번호: 01012345678
   - 통화 시간: 2024-01-15 14:30:25
   → 기존 문서 삭제 후 Linkedid와 함께 재생성

✅ 통화 기록 재생성 완료! (Fallback - Linkedid 포함)
   - 기존 문서 ID (삭제됨): abc123xyz
   - Linkedid: 1234567890.123
   - 발신번호: 01012345678
   → Linkedid는 최초 생성 시 포함되어 업데이트 불필요
```

### 3. _createCallHistoryFromPending()

**위치**: `lib/services/dcmiws_service.dart:1720`

**역할**:
- Pending Storage의 데이터를 Firestore에 생성
- 정상 모드(Linkedid 있음) 또는 타임아웃 모드(Linkedid 없음)

**호출 시점**:
1. **정상 모드**: `_saveClickToCallLinkedId()`에서 Linkedid와 함께 호출
2. **타임아웃 모드**: 10초 타임아웃 시 Linkedid 없이 호출

**파라미터**:
```dart
Future<void> _createCallHistoryFromPending(
  String extensionNumber,  // 단말번호
  String? linkedid,        // Linkedid (없으면 null)
)
```

**로그 예시**:
```
✅ 클릭투콜 기록 생성 완료 - 타임아웃 모드 (Linkedid 없음)
   단말번호: 60001
   발신번호: 01012345678
   Linkedid: (없음 - 나중에 추가 가능)
   착신전환: true
   착신전환 목적지: 01099998888
```

---

## 🎬 시나리오별 처리

### 시나리오 1: 정상 케이스 (빠른 이벤트)

**타임라인**:
- 0초: API 호출 + Pending Storage 저장
- 2초: Newchannel 이벤트 도착
- 2초: Linkedid와 함께 Firestore 생성
- ✅ 완료

**특징**:
- 가장 이상적인 시나리오
- Fallback 없이 한 번에 완료
- Linkedid 포함 보장

### 시나리오 2: 타임아웃 케이스 (느린 이벤트)

**타임라인**:
- 0초: API 호출 + Pending Storage 저장
- 10초: 타임아웃 → Linkedid 없이 생성
- 12초: Newchannel 이벤트 도착
- 12초: Fallback Mode → DELETE + CREATE
- ✅ 완료

**특징**:
- 네트워크 지연 시 발생
- 두 번의 Firestore 작업
- 최종적으로 Linkedid 포함

### 시나리오 3: 이벤트 누락 케이스

**타임라인**:
- 0초: API 호출 + Pending Storage 저장
- 10초: 타임아웃 → Linkedid 없이 생성
- ∞: 이벤트 도착하지 않음
- ⚠️ Linkedid 없는 상태로 유지

**특징**:
- WebSocket 연결 문제
- Linkedid 영구 누락
- 통화 상세 조회 불가

**해결책**:
- WebSocket 연결 상태 모니터링
- 재연결 로직 강화
- 사용자에게 연결 상태 표시

### 시나리오 4: 중복 이벤트 케이스

**타임라인**:
- 0초: API 호출 + Pending Storage 저장
- 2초: Newchannel 이벤트 도착 (첫 번째)
- 2초: Linkedid와 함께 생성
- 3초: Newchannel 이벤트 도착 (중복)
- 3초: 중복 감지 → 건너뛰기
- ✅ 완료

**특징**:
- 네트워크 재전송으로 발생
- 3단계 중복 체크로 방지
- 데이터 무결성 보장

---

## 🐛 디버깅 가이드

### 문제 1: 통화 기록이 생성되지 않음

**증상**:
- Click-to-Call API 호출 성공
- 통화는 정상적으로 연결됨
- call_history 컬렉션에 기록 없음

**확인 사항**:
1. Pending Storage 저장 로그 확인
   ```
   📝 클릭투콜 임시 저장 (Pending Storage)
   ```
2. 10초 타임아웃 로그 확인
   ```
   ⏰ Newchannel 이벤트 타임아웃 (10초 경과)
   ```
3. Firestore 저장 성공 로그 확인
   ```
   ✅ 클릭투콜 기록 생성 완료
   ```

**해결 방법**:
- Firebase Auth 로그인 상태 확인
- Firestore 보안 규칙 확인
- 네트워크 연결 상태 확인

### 문제 2: Linkedid가 항상 null

**증상**:
- 통화 기록은 생성됨
- linkedid 필드가 항상 null
- 통화 상세 조회 불가

**확인 사항**:
1. WebSocket 연결 상태
   ```dart
   final isConnected = DCMIWSService().isConnected;
   ```
2. Newchannel 이벤트 수신 로그
   ```
   📞 Newchannel 이벤트 감지 (Click-to-Call)
   ```
3. Fallback Mode 실행 여부
   ```
   → Fallback Mode: Firestore에서 linkedid 없는 기록 검색
   ```

**해결 방법**:
- WebSocket 재연결: `DCMIWSService().connect(...)`
- 이벤트 필터 확인: Context에 "click-to-call" 포함 여부
- 타임아웃 시간 조정 (필요 시 10초 → 15초)

### 문제 3: 중복 통화 기록 생성

**증상**:
- 동일한 통화에 대해 여러 기록 생성
- 동일한 Linkedid를 가진 기록 중복

**확인 사항**:
1. 중복 체크 로그
   ```
   ⚠️ 이미 동일한 Linkedid로 처리된 기록이 있습니다
   ```
2. Pending Storage 중복 저장 여부
3. 이벤트 중복 수신 로그

**해결 방법**:
- 3단계 중복 체크가 정상 작동하는지 확인
- WebSocket 이벤트 중복 필터링 강화
- Firestore 복합 인덱스 확인

### 문제 4: Fallback Mode 계속 실행

**증상**:
- 모든 통화 기록이 Fallback으로 처리
- "Pending Storage에 데이터 없음" 로그 반복

**확인 사항**:
1. Pending Storage 저장 로그 확인
2. 타임아웃 시간 확인 (10초)
3. Newchannel 이벤트 도착 시간

**해결 방법**:
- 네트워크 지연 확인
- WebSocket 서버 응답 시간 측정
- 타임아웃 시간 증가 (10초 → 15초)

---

## 📈 성능 최적화

### 1. Pending Storage 관리

**메모리 누수 방지**:
```dart
// dispose()에서 정리
void dispose() {
  disconnect();
  _pendingClickToCallRecords.clear();
}
```

**타임아웃 후 자동 정리**:
```dart
Future.delayed(const Duration(seconds: 10), () {
  if (_pendingClickToCallRecords.containsKey(extensionNumber)) {
    _createCallHistoryFromPending(extensionNumber, null);
    // Pending Storage에서 자동 제거됨
  }
});
```

### 2. Firestore 쿼리 최적화

**Fallback 검색 제한**:
```dart
.limit(5)  // 최근 5개만 검색
```

**시간 범위 제한**:
```dart
final oneMinuteAgo = DateTime.now().subtract(const Duration(minutes: 1));
```

**필요 시 복합 인덱스 생성**:
```json
{
  "collectionGroup": "call_history",
  "queryScope": "COLLECTION",
  "fields": [
    { "fieldPath": "userId", "order": "ASCENDING" },
    { "fieldPath": "callType", "order": "ASCENDING" },
    { "fieldPath": "callMethod", "order": "ASCENDING" },
    { "fieldPath": "extensionUsed", "order": "ASCENDING" },
    { "fieldPath": "callTime", "order": "DESCENDING" }
  ]
}
```

### 3. 로그 최적화

**프로덕션 빌드에서 자동 비활성화**:
```dart
if (kDebugMode) {
  debugPrint('...');
}
```

**구조화된 로그로 가독성 향상**:
```dart
debugPrint('');
debugPrint('='*60);
debugPrint('📝 제목');
debugPrint('='*60);
debugPrint('  내용');
debugPrint('='*60);
debugPrint('');
```

---

## 🚀 향후 개선 방향

### 1. 실시간 연결 상태 모니터링

```dart
// WebSocket 연결 상태를 UI에 표시
StreamBuilder<bool>(
  stream: DCMIWSService().connectionState,
  builder: (context, snapshot) {
    final isConnected = snapshot.data ?? false;
    return Icon(
      isConnected ? Icons.wifi : Icons.wifi_off,
      color: isConnected ? Colors.green : Colors.red,
    );
  },
)
```

### 2. 타임아웃 시간 동적 조정

```dart
// 네트워크 상태에 따라 타임아웃 조정
final timeout = _isSlowNetwork ? 15 : 10;
Future.delayed(Duration(seconds: timeout), () {
  // ...
});
```

### 3. 재시도 로직

```dart
// Fallback 실패 시 재시도
int retryCount = 0;
const maxRetries = 3;

while (retryCount < maxRetries) {
  try {
    await _saveClickToCallLinkedId(linkedid, exten);
    break;
  } catch (e) {
    retryCount++;
    await Future.delayed(Duration(seconds: 2 * retryCount));
  }
}
```

### 4. 통계 및 모니터링

```dart
// 통화 기록 생성 통계
class CallHistoryStats {
  int normalModeCount = 0;   // 정상 모드
  int timeoutModeCount = 0;  // 타임아웃 모드
  int fallbackModeCount = 0; // Fallback 모드
  int failureCount = 0;      // 실패
  
  double get fallbackRate => 
      fallbackModeCount / (normalModeCount + timeoutModeCount + fallbackModeCount);
}
```

---

## ✅ 체크리스트

### 개발자 체크리스트

- [x] Linkedid는 생성 시점에만 설정
- [x] UPDATE 연산 완전 제거
- [x] DELETE + CREATE 패턴 적용
- [x] 3단계 중복 체크 구현
- [x] Pending Storage 패턴 적용
- [x] 10초 타임아웃 구현
- [x] Fallback Mode 구현
- [x] 구조화된 로그 시스템
- [x] 모든 클릭투콜 경로 통합
- [x] WebSocket 이벤트 필터링

### 테스트 체크리스트

- [ ] 정상 케이스 (빠른 이벤트)
- [ ] 타임아웃 케이스 (느린 이벤트)
- [ ] 이벤트 누락 케이스
- [ ] 중복 이벤트 케이스
- [ ] WebSocket 재연결 시나리오
- [ ] 네트워크 지연 시나리오
- [ ] 착신전환 활성화/비활성화
- [ ] 여러 내선번호 동시 사용

---

**문서 버전**: 2.0  
**최종 수정일**: 2024-01-15  
**작성자**: MAKECALL Development Team
