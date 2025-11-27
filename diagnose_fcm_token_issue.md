# 🔍 FCM 토큰 404 오류 진단 가이드

## 📋 오류 메시지
```
ERROR:404:No active FCM tokens
```

## 🎯 원인
`fcm_tokens` 컬렉션에 해당 사용자의 활성 토큰이 없음

---

## ✅ 진단 단계

### **Step 1: receiverNumber 확인**
콜서버 로그에서 확인:
```
Receiver=07045144802
```

### **Step 2: my_extensions에서 userId 찾기**

**Firebase Console 접속:**
1. https://console.firebase.google.com/project/makecall-8c352
2. Firestore Database 선택
3. `my_extensions` 컬렉션 열기

**검색 조건:**
- `accountCode == "07045144802"` OR
- `extension == "07045144802"`

**예상 결과:**
```json
{
  "userId": "kakao_3812345678",
  "accountCode": "07045144802",
  "extension": "203",
  "name": "홍길동",
  ...
}
```

**userId 값을 복사:** `kakao_3812345678`

---

### **Step 3: fcm_tokens에서 활성 토큰 확인**

**Firebase Console:**
1. `fcm_tokens` 컬렉션 열기
2. 필터 추가:
   - `userId == "kakao_3812345678"` (Step 2에서 확인한 값)
   - `isActive == true`

**결과 1: 문서 있음 ✅**
```json
{
  "userId": "kakao_3812345678",
  "fcmToken": "f1234567890abcdef...",
  "isActive": true,
  "deviceName": "Galaxy S21",
  "platform": "Android",
  "createdAt": "2024-12-27T10:30:00Z",
  ...
}
```
→ **FCM 토큰 정상!** 다른 문제일 가능성 있음

**결과 2: 문서 없음 ❌**
→ **FCM 토큰이 없거나 비활성화됨**

---

### **Step 4: 문제 해결**

#### **해결 방법 1: 앱에서 재로그인 (권장)**
```
1. MAKECALL 앱 실행
2. 설정 → 로그아웃
3. 다시 로그인 (카카오/Apple/이메일)
4. FCM 토큰 자동 생성
5. Firestore에 자동 저장
6. 수신전화 푸시 테스트
```

#### **해결 방법 2: 앱 재설치**
```
1. MAKECALL 앱 삭제
2. Play Store / App Store에서 재설치
3. 로그인
4. 수신전화 푸시 테스트
```

#### **해결 방법 3: 알림 권한 확인**
```
Android:
  설정 → 앱 → MAKECALL → 알림 → 허용

iOS:
  설정 → MAKECALL → 알림 → 허용
```

---

## 🧪 테스트 스크립트

재로그인 후 FCM 토큰이 생성되었는지 확인:

```bash
# 1. Firebase Console → Firestore Database
# 2. fcm_tokens 컬렉션 열기
# 3. 최신 문서 확인 (createdAt 기준 정렬)
# 4. 해당 userId와 isActive: true 확인
```

---

## 📊 Firebase Functions 로그 확인

**Firebase Console → Functions → Logs:**

**정상 로그 예시:**
```
✅ [FCM-INCOMING] userId 확인: kakao_3812345678
   내선번호: 203
🔍 [FCM-INCOMING] FCM 토큰 조회 중...
✅ [FCM-INCOMING] FCM 토큰 2개 발견
📤 [FCM-INCOMING] FCM 푸시 전송 중...
✅ [FCM-INCOMING] FCM 전송 완료
   성공: 2/2
```

**오류 로그 예시:**
```
✅ [FCM-INCOMING] userId 확인: kakao_3812345678
   내선번호: 203
🔍 [FCM-INCOMING] FCM 토큰 조회 중...
❌ [FCM-INCOMING] 활성 FCM 토큰 없음: kakao_3812345678
```

---

## 💡 추가 확인 사항

### **Q1: my_extensions에 번호가 없으면?**
```
ERROR:404:Extension not found
```
→ 앱에서 단말번호 등록 필요

### **Q2: userId는 있는데 fcm_tokens가 없으면?**
```
ERROR:404:No active FCM tokens
```
→ 앱에서 재로그인 필요

### **Q3: 여러 기기에서 로그인했는데 푸시가 안 오면?**
→ 모든 기기의 fcm_tokens가 isActive: true인지 확인

---

## 🎯 결론

**오류 원인:** `fcm_tokens` 컬렉션에 해당 사용자(userId)의 활성 토큰이 없음

**해결 방법:** 앱에서 재로그인하여 FCM 토큰 재생성

**확인 방법:** Firebase Console → Firestore → fcm_tokens → userId + isActive 필터
