# Pending Storage 조회 로그 개선

**날짜**: 2024-01-15  
**커밋**: 2ef6ac0  
**버전**: 1.0

---

## 📋 사용자 요청

**요청 내용:**
```
"로그에 단말번호도 추가해주고, 수신이벤트 감지시에 data.Linkedid 를 pending storage 저장하는 로직이 있는지?"
```

**의미:**
1. **로그에 비교하는 단말번호 추가**: Pending Storage 조회 시 비교 단말번호를 명확히 출력
2. **수신 이벤트 Pending Storage 확인**: 수신 이벤트에서 Linkedid를 Pending Storage에 저장하는 로직 확인

---

## 🎯 구현 목표

1. **Pending Storage 조회 로그 개선**
   - 조회한 단말번호 명확히 표시
   - 저장된 단말번호와 비교 대상 표시
   - 매칭 여부 (✅ 일치 / ❌ 불일치) 표시
   - 저장 시간 정보 추가

2. **수신 이벤트 로직 확인**
   - 수신 이벤트는 Pending Storage 사용하지 않음
   - `_activeIncomingCalls`에 직접 저장 (정상)

---

## ✅ 구현한 해결책

### 1. Pending Storage 조회 성공 시 로그 개선

**파일**: `lib/services/dcmiws_service.dart`

**변경 전:**
```dart
if (_pendingClickToCallRecords.containsKey(exten)) {
  if (kDebugMode) {
    debugPrint('  ✅ Pending Storage에서 발견!');
    debugPrint('  → Step 2: 중복 확인 후 Firestore 생성');
  }
}
```

**변경 후:**
```dart
if (_pendingClickToCallRecords.containsKey(exten)) {
  if (kDebugMode) {
    debugPrint('  ✅ Pending Storage에서 발견!');
    debugPrint('  📋 저장된 단말번호: $exten');
    debugPrint('  📋 조회한 단말번호: $exten');
    debugPrint('  ✅ 매칭 성공!');
    debugPrint('  → Step 2: 중복 확인 후 Firestore 생성');
  }
}
```

### 2. Pending Storage 조회 실패 시 로그 개선

**변경 전:**
```dart
if (kDebugMode) {
  debugPrint('  ⚠️ Pending Storage에 데이터 없음');
  debugPrint('  단말번호: $exten');
  debugPrint('  원인 1: 10초 타임아웃으로 이미 Firestore에 저장됨');
  debugPrint('  원인 2: storePendingClickToCallRecord() 호출 누락');
  debugPrint('  원인 3: 단말번호 불일치');
  
  if (_pendingClickToCallRecords.isNotEmpty) {
    debugPrint('  📋 현재 Pending Storage 내용:');
    _pendingClickToCallRecords.forEach((key, value) {
      debugPrint('     - 단말번호: $key, 발신번호: ${value['phoneNumber']}');
    });
  } else {
    debugPrint('  📋 Pending Storage가 비어있음');
  }
}
```

**변경 후:**
```dart
if (kDebugMode) {
  debugPrint('  ⚠️ Pending Storage에 데이터 없음');
  debugPrint('  🔍 조회한 단말번호: $exten');
  debugPrint('  원인 1: 10초 타임아웃으로 이미 Firestore에 저장됨');
  debugPrint('  원인 2: storePendingClickToCallRecord() 호출 누락');
  debugPrint('  원인 3: 단말번호 불일치');
  debugPrint('');
  
  if (_pendingClickToCallRecords.isNotEmpty) {
    debugPrint('  📋 현재 Pending Storage 내용:');
    _pendingClickToCallRecords.forEach((key, value) {
      debugPrint('     - 저장된 단말번호: $key (비교 대상: $exten)');
      debugPrint('       발신번호: ${value['phoneNumber']}');
      debugPrint('       저장시간: ${value['timestamp']}');
      final match = key == exten;
      debugPrint('       매칭 여부: ${match ? '✅ 일치' : '❌ 불일치'}');
    });
  } else {
    debugPrint('  📋 Pending Storage가 비어있음');
  }
  debugPrint('');
  debugPrint('  → Fallback Mode: Firestore에서 linkedid 없는 기록 검색');
}
```

### 3. 조회 시작 로그 개선

**변경 전:**
```dart
if (kDebugMode) {
  debugPrint('🔍 통화 기록 생성 프로세스 시작');
  debugPrint('  Exten (단말번호): $exten');
  debugPrint('  Linkedid: $linkedid');
  debugPrint('  → Step 1: Pending Storage 확인');
}
```

**변경 후:**
```dart
if (kDebugMode) {
  debugPrint('');
  debugPrint('🔍 통화 기록 생성 프로세스 시작');
  debugPrint('  Exten (단말번호): $exten');
  debugPrint('  Linkedid: $linkedid');
  debugPrint('  → Step 1: Pending Storage 확인');
  debugPrint('  🔍 조회 키: $exten');
}
```

---

## 📊 개선된 로그 출력 예시

### 시나리오 1: Pending Storage 조회 성공

```
🔍 통화 기록 생성 프로세스 시작
  Exten (단말번호): 1010
  Linkedid: 1762576122.1409
  → Step 1: Pending Storage 확인
  🔍 조회 키: 1010
  ✅ Pending Storage에서 발견!
  📋 저장된 단말번호: 1010
  📋 조회한 단말번호: 1010
  ✅ 매칭 성공!
  → Step 2: 중복 확인 후 Firestore 생성
```

### 시나리오 2: Pending Storage 조회 실패 (비어있음)

```
🔍 통화 기록 생성 프로세스 시작
  Exten (단말번호): 1010
  Linkedid: 1762576122.1409
  → Step 1: Pending Storage 확인
  🔍 조회 키: 1010
  ⚠️ Pending Storage에 데이터 없음
  🔍 조회한 단말번호: 1010
  원인 1: 10초 타임아웃으로 이미 Firestore에 저장됨
  원인 2: storePendingClickToCallRecord() 호출 누락
  원인 3: 단말번호 불일치

  📋 Pending Storage가 비어있음

  → Fallback Mode: Firestore에서 linkedid 없는 기록 검색
```

### 시나리오 3: Pending Storage 조회 실패 (단말번호 불일치)

```
🔍 통화 기록 생성 프로세스 시작
  Exten (단말번호): 1010
  Linkedid: 1762576122.1409
  → Step 1: Pending Storage 확인
  🔍 조회 키: 1010
  ⚠️ Pending Storage에 데이터 없음
  🔍 조회한 단말번호: 1010
  원인 1: 10초 타임아웃으로 이미 Firestore에 저장됨
  원인 2: storePendingClickToCallRecord() 호출 누락
  원인 3: 단말번호 불일치

  📋 현재 Pending Storage 내용:
     - 저장된 단말번호: 1011 (비교 대상: 1010)
       발신번호: 07045144801
       저장시간: 2024-01-15T05:20:30.123Z
       매칭 여부: ❌ 불일치

  → Fallback Mode: Firestore에서 linkedid 없는 기록 검색
```

---

## 🔍 수신 이벤트 로직 확인

### 질문: 수신 이벤트 감지 시 Linkedid를 Pending Storage에 저장하는 로직이 있는지?

**답변**: ❌ **없음** (정상 동작)

**이유:**
- **Click-to-Call 이벤트**: Pending Storage 사용 ✅
  - 사용자가 발신 → `storePendingClickToCallRecord()` 호출
  - Newchannel 이벤트 대기 → Pending Storage 조회
  - Linkedid 추가하여 Firestore 저장

- **수신 이벤트**: Pending Storage 사용 안 함 ✅
  - 외부에서 수신 → 사용자 액션 없음
  - Newchannel 이벤트에서 직접 `_activeIncomingCalls`에 저장
  - 수신 화면 표시 → 수락/거절 후 Hangup 이벤트에서 Firestore 저장

**수신 이벤트 플로우:**
```
1. Newchannel 이벤트 (ChannelStateDesc=Ring)
   └─ CallerIDNum (발신번호) 확인
   └─ Exten (수신번호) 확인
   └─ Linkedid 확인
   └─ _activeIncomingCalls[linkedid] 저장
   └─ 수신 화면 표시

2. 사용자 수락/거절

3. Hangup 이벤트
   └─ _activeIncomingCalls[linkedid] 조회
   └─ Firestore에 통화 기록 저장
```

**결론**: 수신 이벤트는 Pending Storage를 사용하지 않으며, 이는 **정상적인 설계**입니다.

---

## 🎯 달성한 목표

### 기능적 목표
- ✅ Pending Storage 조회 시 비교 단말번호 명확히 표시
- ✅ 저장된 단말번호와 조회한 단말번호 비교 출력
- ✅ 매칭 여부 (✅ 일치 / ❌ 불일치) 표시
- ✅ 저장 시간 정보 추가
- ✅ 수신 이벤트 로직 확인 및 문서화

### 디버깅 개선
- ✅ 단말번호 불일치 문제 즉시 파악 가능
- ✅ Pending Storage 조회 실패 원인 명확히 확인
- ✅ 타이밍 문제 추적 가능
- ✅ 저장 시간 정보로 10초 타임아웃 여부 확인

---

## 📝 코드 변경 요약

### 파일: `lib/services/dcmiws_service.dart`

**수정된 로직:**
1. Pending Storage 조회 성공 시 (line 740-755)
2. Pending Storage 조회 실패 시 (line 777-800)
3. 조회 시작 로그 (line 740-746)

**총 변경 라인**: ~15 줄

---

## 🚀 배포 정보

**커밋 해시**: 2ef6ac0  
**브랜치**: main  
**푸시 완료**: ✅  
**Flutter 빌드**: ✅ 완료  
**웹 서버**: ✅ 실행 중  
**웹 프리뷰 URL**: https://5060-ijpqhzty575rh093zweuw-583b4d74.sandbox.novita.ai

---

## 🎉 결과

**로그 개선으로 디버깅 능력 대폭 향상!**

**핵심 성과:**
- 🔍 **단말번호 비교 명확화**: 저장된 단말번호와 조회한 단말번호 명시
- ✅ **매칭 여부 즉시 확인**: 일치/불일치를 바로 알 수 있음
- ⏱️ **저장 시간 정보**: 타이밍 문제 파악 가능
- 📋 **Pending Storage 내용 상세 출력**: 디버깅 정보 풍부

**추가 확인 사항:**
- ✅ 수신 이벤트는 Pending Storage 사용 안 함 (정상)
- ✅ Click-to-Call만 Pending Storage 사용 (정상)
- ✅ 각 이벤트 타입에 적합한 처리 방식 (정상)

---

**작성자**: MAKECALL Development Team  
**문서 버전**: 1.0
