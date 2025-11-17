# 🔔 웹 푸시 알림 문제 해결 가이드

## 📋 문제 진단

웹 푸시 알림이 작동하지 않을 때 다음 순서로 확인하세요.

---

## 1️⃣ 브라우저 콘솔 확인 (F12)

### ✅ **Service Worker 등록 확인**

브라우저 콘솔에서 다음 명령어 실행:

```javascript
navigator.serviceWorker.getRegistrations().then(registrations => {
  console.log('📋 등록된 Service Worker:', registrations.length);
  registrations.forEach((reg, i) => {
    console.log(`  ${i+1}. ${reg.active?.scriptURL || 'pending'}`);
    console.log(`     scope: ${reg.scope}`);
    console.log(`     state: ${reg.active?.state || 'N/A'}`);
  });
});
```

**정상 출력:**
```
📋 등록된 Service Worker: 1개 이상
  1. https://your-domain.com/firebase-messaging-sw.js
     scope: https://your-domain.com/firebase-cloud-messaging-push-scope
     state: activated
```

### ✅ **알림 권한 확인**

```javascript
console.log('🔔 알림 권한:', Notification.permission);
// 출력: "granted", "denied", 또는 "default"
```

**권한 상태:**
- ✅ `"granted"`: 알림 허용됨 (정상)
- ❌ `"denied"`: 알림 거부됨 (브라우저 설정에서 수동으로 허용 필요)
- ⏳ `"default"`: 아직 요청하지 않음 (앱에서 요청 예정)

### ✅ **FCM 토큰 확인**

앱 로그인 후 콘솔에서 `"FCM"` 검색:

```
🔑 [FCM] 토큰 생성 완료: eK7Xz...
💾 [FCM-SAVE] 토큰 저장 시작
✅ [FCM-SAVE] Firestore 저장 완료!
```

---

## 2️⃣ 자동 진단 도구 사용

앱 로딩 3초 후 자동으로 진단이 실행됩니다:

```
🔍 ===== 웹 푸시 진단 시작 =====
📋 Service Worker: 2개 등록됨
  1. https://your-domain.com/flutter_service_worker.js?vsn=...
  2. https://your-domain.com/firebase-messaging-sw.js
🔔 알림 권한: granted
✅ HTTPS 환경 확인
🔍 ===== 웹 푸시 진단 완료 =====
```

---

## 3️⃣ 일반적인 문제 및 해결 방법

### ❌ **문제 1: Service Worker 등록 실패**

**증상:**
```
❌ Firebase Messaging Service Worker 등록 실패: TypeError
```

**원인:**
- `firebase-messaging-sw.js` 파일이 없음
- 파일 경로 오류
- HTTPS가 아닌 환경

**해결 방법:**
1. `web/firebase-messaging-sw.js` 파일 존재 확인
2. HTTPS 환경 확인 (localhost는 예외)
3. 브라우저 캐시 삭제: `Ctrl+Shift+Del` → "캐시된 이미지 및 파일" 삭제

---

### ❌ **문제 2: 알림 권한 거부됨 (Denied)**

**증상:**
```
🔔 알림 권한: denied
```

**해결 방법:**

#### **Chrome/Edge:**
1. 주소창 왼쪽 🔒 아이콘 클릭
2. "사이트 설정" 클릭
3. "알림" → "허용" 선택
4. 페이지 새로고침

#### **Firefox:**
1. 주소창 왼쪽 🔒 아이콘 클릭
2. "연결 안전" → "추가 정보"
3. "권한" 탭 → "알림" → "허용" 선택
4. 페이지 새로고침

#### **Safari:**
1. Safari 메뉴 → "환경설정" → "웹사이트"
2. "알림" 선택
3. 해당 사이트 → "허용" 선택
4. 페이지 새로고침

---

### ❌ **문제 3: FCM 토큰 생성 실패**

**증상:**
```
❌ [FCM] 토큰 생성 실패
```

**원인:**
1. VAPID 키 불일치
2. Firebase 설정 오류
3. Service Worker 미등록
4. 네트워크 오류

**해결 방법:**

#### **A. VAPID 키 확인**

1. **Firebase Console** 접속:
   https://console.firebase.google.com/

2. 프로젝트 선택 → **Project settings** (⚙️)

3. **Cloud Messaging** 탭 선택

4. **Web Push certificates** 섹션에서 **Key pair** 복사

5. `lib/services/fcm_service.dart` 파일에서 VAPID 키 비교:
   ```dart
   const vapidKey = 'BM2qgTRR...'; // 이 값이 Firebase Console과 일치해야 함
   ```

6. 불일치하면 코드 수정:
   ```dart
   const vapidKey = 'YOUR_FIREBASE_VAPID_KEY_HERE';
   ```

#### **B. Firebase 설정 확인**

`web/firebase-messaging-sw.js` 파일의 Firebase Config가 올바른지 확인:

```javascript
const firebaseConfig = {
  apiKey: 'AIzaSyCB4mI5Kj61f6E532vg46GnmnnCfsI9XIM',
  appId: '1:793164633643:android:c2f267d67b908274ccfc6e',
  messagingSenderId: '793164633643',
  projectId: 'makecallio',
  authDomain: 'makecallio.firebaseapp.com',
  storageBucket: 'makecallio.firebasestorage.app',
};
```

---

### ❌ **문제 4: Service Worker 충돌 (Multiple SWs)**

**증상:**
```
📋 Service Worker: 3개 등록됨
  1. flutter_service_worker.js
  2. firebase-messaging-sw.js
  3. flutter_service_worker.js (중복)
```

**해결 방법:**

#### **Step 1: 기존 Service Worker 모두 제거**

브라우저 콘솔에서:

```javascript
navigator.serviceWorker.getRegistrations().then(function(registrations) {
  for (let registration of registrations) {
    console.log('제거:', registration.scope);
    registration.unregister();
  }
  console.log('✅ 모든 Service Worker 제거 완료');
  console.log('페이지를 새로고침하세요.');
});
```

#### **Step 2: 브라우저 캐시 삭제**

`Ctrl+Shift+Del` → "캐시된 이미지 및 파일" + "사이트 설정" 삭제

#### **Step 3: 페이지 새로고침**

`Ctrl+F5` (강력 새로고침)

---

### ❌ **문제 5: 백그라운드 알림이 오지 않음**

**증상:**
- 포그라운드(앱 열려 있을 때)는 알림 옴
- 백그라운드(앱 닫혀 있을 때)는 알림 안 옴

**원인:**
- `firebase-messaging-sw.js`의 `onBackgroundMessage` 핸들러 오류
- Service Worker가 제대로 활성화되지 않음

**해결 방법:**

#### **A. Service Worker 활성화 확인**

```javascript
navigator.serviceWorker.getRegistrations().then(registrations => {
  registrations.forEach(reg => {
    console.log('State:', reg.active?.state);
    // "activated" 상태여야 함
  });
});
```

#### **B. Service Worker 강제 업데이트**

```javascript
navigator.serviceWorker.getRegistrations().then(registrations => {
  registrations.forEach(reg => {
    reg.update().then(() => {
      console.log('✅ SW 업데이트 완료:', reg.scope);
    });
  });
});
```

---

## 4️⃣ 프로덕션 환경 체크리스트

### ✅ **배포 전 확인 사항**

- [ ] **HTTPS 사용**: 웹 푸시는 HTTPS 환경 필수 (localhost 제외)
- [ ] **VAPID 키**: Firebase Console과 코드의 VAPID 키 일치 확인
- [ ] **Firebase Config**: `firebase-messaging-sw.js`의 설정이 올바른지 확인
- [ ] **Service Worker 파일**: `build/web/firebase-messaging-sw.js` 존재 확인
- [ ] **알림 권한**: 첫 로그인 시 알림 권한 요청 구현 확인
- [ ] **테스트**: Chrome, Firefox, Safari에서 각각 테스트

---

## 5️⃣ 수동 테스트 방법

### **A. 포그라운드 알림 테스트**

1. 앱 로그인
2. Firebase Console → **Cloud Messaging**
3. **Send test message** 클릭
4. FCM 토큰 입력 (앱 콘솔에서 복사)
5. 메시지 작성 후 전송
6. 브라우저에서 알림 수신 확인

### **B. 백그라운드 알림 테스트**

1. 앱 로그인
2. **브라우저 탭 닫기** (완전히 종료하지 말고 다른 탭으로 이동)
3. Firebase Console에서 테스트 메시지 전송
4. 브라우저 우측 하단에 알림 팝업 확인

---

## 6️⃣ Firebase Console 설정 확인

### ✅ **Cloud Messaging 설정**

1. **Firebase Console** 접속
2. 프로젝트 선택 → **Cloud Messaging**
3. **Web Push certificates** 확인:
   - Key pair가 생성되어 있어야 함
   - 없으면 "Generate key pair" 클릭

---

## 7️⃣ 브라우저별 지원 상황

| 브라우저 | 포그라운드 | 백그라운드 | 비고 |
|---------|-----------|-----------|------|
| Chrome | ✅ | ✅ | 완벽 지원 |
| Edge | ✅ | ✅ | 완벽 지원 |
| Firefox | ✅ | ✅ | 완벽 지원 |
| Safari (macOS) | ✅ | ⚠️ | macOS 13+ 필요 |
| Safari (iOS) | ❌ | ❌ | 미지원 |

---

## 8️⃣ 개발자 도구

### **Service Worker 상태 확인**

Chrome DevTools:
1. `F12` → **Application** 탭
2. **Service Workers** 선택
3. 등록된 SW 목록 및 상태 확인

### **알림 디버깅**

Chrome DevTools:
1. `F12` → **Console** 탭
2. "FCM" 검색하여 로그 확인
3. 오류 메시지 분석

---

## 9️⃣ 최종 체크리스트

문제가 해결되지 않으면 다음 순서로 재확인:

1. [ ] 브라우저 캐시 삭제 (`Ctrl+Shift+Del`)
2. [ ] Service Worker 모두 제거 (위 스크립트 사용)
3. [ ] 페이지 강력 새로고침 (`Ctrl+F5`)
4. [ ] 알림 권한 확인 (브라우저 설정)
5. [ ] VAPID 키 일치 확인 (Firebase Console vs 코드)
6. [ ] Firebase Config 일치 확인 (`firebase-messaging-sw.js`)
7. [ ] HTTPS 환경 확인
8. [ ] 다른 브라우저에서 테스트 (Chrome 권장)

---

## 🆘 여전히 문제가 해결되지 않나요?

다음 정보를 포함하여 문의하세요:

1. **브라우저 및 버전**: (예: Chrome 120)
2. **OS**: (예: Windows 11, macOS 14)
3. **콘솔 로그**: 브라우저 콘솔의 "FCM" 관련 로그 전체
4. **Service Worker 상태**: 위 진단 스크립트 실행 결과
5. **알림 권한 상태**: `Notification.permission` 값
6. **오류 메시지**: 정확한 에러 메시지 전체

---

**마지막 업데이트**: 2024-11-14  
**버전**: 1.0.0  
**리전**: asia-northeast3 (서울)
