# 🔧 FCM 수신전화 푸시 수정 완료

## 📋 문제 상황

**증상:**
```
ERROR:404:No active FCM tokens
```

**원인:**
- 로그아웃 시 `fcm_tokens.isActive: false`로 변경
- Cloud Functions에서 `isActive == true` 조건으로 조회
- 로그아웃 상태에서 FCM 토큰 조회 실패 → 푸시 전송 불가

---

## ✅ 수정 내용

### **변경 파일:** `functions/index.js`

#### **1. sendIncomingCallNotification (Line 479-495)**

**변경 전:**
```javascript
const tokensSnapshot = await admin.firestore()
    .collection("fcm_tokens")
    .where("userId", "==", userId)
    .where("isActive", "==", true)  // ❌ 로그아웃 시 조회 실패
    .get();
```

**변경 후:**
```javascript
const tokensSnapshot = await admin.firestore()
    .collection("fcm_tokens")
    .where("userId", "==", userId)
    // ✅ isActive 조건 제거 - 로그아웃 상태에서도 수신전화 푸시 전송
    .get();
```

#### **2. cancelIncomingCallNotification (Line 652-660)**

**변경 전:**
```javascript
const tokensSnapshot = await admin.firestore()
    .collection("fcm_tokens")
    .where("userId", "==", userId)
    .where("isActive", "==", true)  // ❌ 로그아웃 시 조회 실패
    .get();
```

**변경 후:**
```javascript
const tokensSnapshot = await admin.firestore()
    .collection("fcm_tokens")
    .where("userId", "==", userId)
    // ✅ isActive 조건 제거
    .get();
```

---

## 🎯 수정 효과

### **변경 전:**
```
로그인 상태  → isActive: true  → 푸시 수신 ✅
로그아웃 상태 → isActive: false → 푸시 수신 ❌
```

### **변경 후:**
```
로그인 상태  → FCM 토큰 존재 → 푸시 수신 ✅
로그아웃 상태 → FCM 토큰 존재 → 푸시 수신 ✅
```

**핵심:**
- `my_extensions`에 번호가 등록되어 있으면
- 로그인/로그아웃 상태와 무관하게
- FCM 토큰이 Firestore에 존재하면 푸시 전송

---

## 🚀 배포 방법

### **옵션 1: 자동 배포 스크립트**

```bash
cd /home/user/flutter_app
./deploy_fcm_fix.sh
```

### **옵션 2: 수동 배포**

```bash
cd /home/user/flutter_app

# Firebase 로그인 (필요 시)
firebase login

# Functions 배포
firebase deploy --only functions:sendIncomingCallNotification,functions:cancelIncomingCallNotification
```

---

## 🧪 테스트 방법

### **1. 로그아웃 상태 테스트**

```bash
# 테스트 전 준비:
# 1. MAKECALL 앱에서 로그아웃
# 2. 앱 완전 종료 (백그라운드도 종료)

# 테스트 실행:
cd /home/user/flutter_app
./test_incoming_call_push.sh "07045144802" "16682471" "테스트발신자"

# 확인:
# - Android/iOS에서 푸시 알림 수신 확인
# - 알림 탭 시 앱 실행 및 수신전화 화면 표시 확인
```

### **2. Firebase Functions 로그 확인**

**배포 후 로그 확인:**
```
https://console.firebase.google.com/project/makecall-8c352/functions/logs
```

**정상 로그 예시:**
```
✅ [FCM-INCOMING] userId 확인: kakao_3812345678
🔍 [FCM-INCOMING] FCM 토큰 조회 중...
✅ [FCM-INCOMING] FCM 토큰 2개 발견
📤 [FCM-INCOMING] FCM 푸시 전송 중...
✅ [FCM-INCOMING] FCM 전송 완료
   성공: 2/2
```

---

## 📊 시스템 동작 방식

### **전체 흐름:**

```
1️⃣ 외부 전화 수신
   → PBX: receiverNumber = "07045144802"
   
2️⃣ Firebase Cloud Functions 호출
   → sendIncomingCallNotification
   
3️⃣ my_extensions 검증
   ✅ accountCode or extension = "07045144802" 확인
   ✅ userId 추출
   
4️⃣ fcm_tokens 조회 (isActive 무관)
   ✅ userId로 모든 FCM 토큰 조회
   ✅ 로그아웃 상태(isActive: false)에서도 조회됨
   
5️⃣ FCM 푸시 전송
   ✅ 모든 기기에 푸시 알림 전송
   
6️⃣ 앱 실행 (종료 상태에서도)
   ✅ 시스템 알림 표시
   ✅ 사용자가 알림 탭 → 앱 실행 → IncomingCallScreen
```

---

## 💡 주의사항

### **FCM 토큰 생성 시점:**
- **로그인 시:** FCM 토큰 자동 생성 및 Firestore 저장
- **로그아웃 시:** `isActive: false`로 변경 (토큰 삭제 안 됨)
- **앱 재설치:** 새 FCM 토큰 생성 (이전 토큰은 무효화)

### **FCM 토큰이 없는 경우:**
- 한 번도 로그인하지 않은 경우
- 앱을 삭제한 후 재설치 전
- Firestore에서 fcm_tokens 수동 삭제한 경우

→ 이 경우에만 "No FCM tokens found" 오류 발생

---

## 🔍 문제 해결

### **푸시가 여전히 안 오는 경우:**

**1. FCM 토큰 확인:**
```
Firebase Console → Firestore Database → fcm_tokens
userId로 검색 → 문서 존재 확인
```

**2. my_extensions 확인:**
```
Firebase Console → Firestore Database → my_extensions
accountCode = "07045144802" 검색 → userId 확인
```

**3. Firebase Functions 로그 확인:**
```
https://console.firebase.google.com/project/makecall-8c352/functions/logs
"FCM-INCOMING" 키워드로 검색
```

**4. 알림 권한 확인:**
```
Android: 설정 → 앱 → MAKECALL → 알림 → 허용
iOS: 설정 → MAKECALL → 알림 → 허용
```

---

## 📝 변경사항 요약

| 항목 | 변경 전 | 변경 후 |
|------|---------|---------|
| **조회 조건** | `userId + isActive: true` | `userId` (isActive 무관) |
| **로그인 상태** | 푸시 수신 ✅ | 푸시 수신 ✅ |
| **로그아웃 상태** | 푸시 수신 ❌ | 푸시 수신 ✅ |
| **앱 종료 상태** | 푸시 수신 ❌ | 푸시 수신 ✅ |
| **에러 메시지** | "No active FCM tokens" | "No FCM tokens found" |

---

## ✅ 결론

**수정 완료:**
- `isActive == true` 조건 제거
- 로그아웃 상태에서도 수신전화 푸시 전송 가능
- my_extensions에 등록된 번호면 항상 푸시 수신

**다음 단계:**
1. `./deploy_fcm_fix.sh` 실행하여 Firebase에 배포
2. 로그아웃 상태에서 테스트
3. Firebase Functions 로그 확인
