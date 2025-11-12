# Cloud Functions 수정 및 배포 가이드

## ✅ 수정 완료 상태

**`functions/index.js` 파일이 이미 수정되었습니다!**

다음 두 가지 개선사항이 적용되었습니다:
1. ✅ **notification 필드 추가** - 포그라운드/백그라운드 알림 표시 (이미 있었음)
2. ✅ **토큰 정리 로직 추가** - 유효하지 않은 토큰 자동 삭제 (새로 추가됨)

---

## 🔍 적용된 수정사항

### `sendApprovalNotification` 함수 (lines 184-282)

**추가된 토큰 정리 로직**:
```javascript
} catch (error) {
  console.error("❌ FCM 알림 전송 오류:", error);

  // 🧹 토큰 정리: registration-token-not-registered 오류 처리
  if (error.code === "messaging/registration-token-not-registered") {
    console.log("🧹 [TOKEN-CLEANUP] 무효 토큰 감지 - 자동 삭제 시작");
    console.log(`   무효 토큰: ${targetToken.substring(0, 20)}...`);

    try {
      // fcm_tokens 컬렉션에서 무효 토큰 찾기
      const tokenQuery = await admin.firestore()
          .collection("fcm_tokens")
          .where("fcmToken", "==", targetToken)
          .get();

      if (!tokenQuery.empty) {
        // 무효 토큰 삭제
        const deletePromises = tokenQuery.docs.map((doc) => {
          console.log(`   삭제 중: ${doc.id}`);
          return doc.ref.delete();
        });

        await Promise.all(deletePromises);

        console.log(`✅ [TOKEN-CLEANUP] 무효 토큰 ${tokenQuery.size}개 삭제 완료`);
      } else {
        console.log("⚠️ [TOKEN-CLEANUP] fcm_tokens에서 토큰을 찾을 수 없음");
      }
    } catch (cleanupError) {
      console.error("❌ [TOKEN-CLEANUP] 토큰 정리 실패:", cleanupError);
    }
  }

  // 오류 정보 저장 (errorCode 필드 추가)
  await snap.ref.update({
    processed: false,
    error: error.message,
    errorCode: error.code || "unknown",  // ✅ 새로 추가
    errorAt: admin.firestore.FieldValue.serverTimestamp(),
  });
}
```

**기능**:
- `messaging/registration-token-not-registered` 오류 발생 시 자동으로 감지
- Firestore `fcm_tokens` 컬렉션에서 무효 토큰 검색
- 일치하는 모든 토큰 문서 자동 삭제
- 정리 과정 및 결과를 Cloud Functions 로그에 기록
- 오류 문서에 `errorCode` 필드 추가로 더 정확한 오류 추적

---

## 🚀 배포 방법

### **Option A: Firebase CLI 사용 (권장)**

1. **Firebase CLI 설치 확인**
   ```bash
   firebase --version
   # 없으면: npm install -g firebase-tools
   ```

2. **Firebase 로그인**
   ```bash
   firebase login
   ```

3. **프로젝트 디렉토리로 이동**
   ```bash
   cd /path/to/flutter_app
   ```

4. **Firebase 프로젝트 연결 확인**
   ```bash
   firebase use
   # 프로젝트가 연결되지 않았다면:
   # firebase use --add
   # 프로젝트 선택 후 alias 설정 (예: default)
   ```

5. **단일 함수 배포 (권장)**
   ```bash
   firebase deploy --only functions:sendApprovalNotification
   ```

6. **또는 모든 함수 배포**
   ```bash
   firebase deploy --only functions
   ```

7. **배포 로그 확인**
   ```bash
   firebase functions:log --only sendApprovalNotification
   ```

### **Option B: Firebase Console에서 직접 수정**

⚠️ **주의**: Console에서는 소스 코드를 직접 보고 수정할 수 없습니다.
Firebase CLI 배포를 권장합니다.

---

## 📂 프로젝트 구조

현재 프로젝트의 Cloud Functions 구조:

```
flutter_app/
├── functions/
│   ├── index.js ✅ (수정 완료)
│   ├── package.json
│   ├── package-lock.json
│   ├── .env.example
│   ├── .eslintrc.js
│   ├── node_modules/
│   └── [문서들]
├── firebase.json
└── .firebaserc
```

---

## 🧪 테스트

### **테스트 1: 배포 성공 확인**
```bash
firebase deploy --only functions:sendApprovalNotification

# 예상 출력:
# ✔  functions[sendApprovalNotification(us-central1)] Successful update operation.
# ✔  Deploy complete!
```

### **테스트 2: Cloud Functions 로그 모니터링**
```bash
# 실시간 로그 확인
firebase functions:log --only sendApprovalNotification

# 또는 Firebase Console에서:
# Build → Functions → sendApprovalNotification → Logs 탭
```

### **테스트 3: 실제 알림 테스트**

1. **새 기기에서 로그인 시도**
2. **기존 기기에서 알림 수신 확인**
   - 포그라운드: 알림 팝업 표시
   - 백그라운드: 시스템 알림 트레이
3. **Cloud Functions 로그 확인 (예상 로그)**:
   ```
   🔔 FCM 승인 알림 요청 수신: [queueId]
      Target Token: [token의 처음 20자]...
      New Device: [deviceName] ([platform])
   ✅ FCM 알림 전송 완료: [token의 처음 20자]...
   ```

### **테스트 4: 토큰 정리 로직 테스트 (무효 토큰 시나리오)**

1. **의도적으로 무효 토큰 생성** (앱 재설치 또는 토큰 강제 삭제)
2. **로그인 시도 → 승인 알림 전송**
3. **Cloud Functions 로그 확인 (예상 로그)**:
   ```
   ❌ FCM 알림 전송 오류: [error message]
   🧹 [TOKEN-CLEANUP] 무효 토큰 감지 - 자동 삭제 시작
      무효 토큰: [token의 처음 20자]...
      삭제 중: [document_id]
   ✅ [TOKEN-CLEANUP] 무효 토큰 1개 삭제 완료
   ```
4. **Firestore Console 확인**:
   - `fcm_tokens` 컬렉션에서 해당 토큰이 삭제되었는지 확인

---

## ❓ 자주 묻는 질문

### **Q1: 배포 권한이 없다면?**
**A**: Firebase 프로젝트 소유자나 관리자에게 요청:
1. Firebase Console → 프로젝트 설정 → 사용자 및 권한
2. 계정에 "Firebase Admin" 또는 "Editor" 역할 부여
3. 또는 수정된 코드가 포함된 GitHub 저장소 공유하여 배포 요청

### **Q2: 이미 배포된 함수를 수정하면?**
**A**: 
- 기존 함수가 새 코드로 완전히 교체됨
- Firestore 트리거 설정은 유지됨
- 다운타임 없음 (Firebase가 자동으로 처리)
- 기존 실행 중인 함수 인스턴스는 완료 후 교체

### **Q3: 배포 후 즉시 적용되나요?**
**A**: 
- 일반적으로 **30초~2분** 내 적용
- Cold start 시 첫 실행이 느릴 수 있음 (이후 정상)
- Firebase Console Logs에서 배포 완료 확인 가능

### **Q4: 롤백하려면?**
**A**:
```bash
# Git으로 이전 버전 복구
git checkout HEAD~1 -- functions/index.js
firebase deploy --only functions:sendApprovalNotification

# 또는 함수 삭제 후 재배포
firebase functions:delete sendApprovalNotification
firebase deploy --only functions:sendApprovalNotification
```

### **Q5: 환경 변수(.env)는 어떻게 설정하나요?**
**A**:
```bash
# functions/.env 파일 생성 (이미 .env.example 참고)
cd functions
cp .env.example .env
nano .env  # 또는 vi, code 등 편집기 사용

# 내용:
# GMAIL_EMAIL=your-email@gmail.com
# GMAIL_PASSWORD=your-app-password

# 배포 시 자동으로 업로드됨
firebase deploy --only functions
```

---

## 📋 배포 체크리스트

### 배포 전:
- [ ] Firebase CLI 설치 확인 (`firebase --version`)
- [ ] Firebase 로그인 확인 (`firebase login`)
- [ ] 프로젝트 연결 확인 (`firebase use`)
- [ ] 함수 코드 검토 (`functions/index.js`)
- [ ] 환경 변수 설정 확인 (`functions/.env`)

### 배포 중:
- [ ] 배포 명령 실행 (`firebase deploy --only functions:sendApprovalNotification`)
- [ ] 배포 성공 메시지 확인
- [ ] 오류 없이 완료 확인

### 배포 후:
- [ ] Firebase Console Functions 탭에서 함수 상태 확인
- [ ] 로그 확인 (`firebase functions:log`)
- [ ] 실제 알림 테스트 (새 기기 로그인)
- [ ] 포그라운드 알림 확인
- [ ] 백그라운드 알림 확인
- [ ] 토큰 정리 로직 테스트 (무효 토큰 시나리오)

---

## 🔗 참고 자료

- Firebase Functions 문서: https://firebase.google.com/docs/functions
- Firebase CLI 문서: https://firebase.google.com/docs/cli
- FCM 메시지 구조: https://firebase.google.com/docs/cloud-messaging/concept-options
- Firestore 트리거: https://firebase.google.com/docs/functions/firestore-events

---

## 💡 간단 요약

**배포 3단계**:

1. **로그인**
   ```bash
   firebase login
   ```

2. **프로젝트 이동**
   ```bash
   cd /path/to/flutter_app
   ```

3. **배포**
   ```bash
   firebase deploy --only functions:sendApprovalNotification
   ```

**완료!** 🎉

배포 후 Flutter 앱에서 새 기기 로그인 시 정상적으로 알림이 표시되고, 무효 토큰은 자동으로 정리됩니다.

---

## 📊 기대 효과

### 배포 전 문제:
- ❌ 무효 FCM 토큰 축적 (4개 중 3개 무효)
- ❌ `messaging/registration-token-not-registered` 오류 반복
- ❌ 수동으로 토큰 정리 필요

### 배포 후 개선:
- ✅ 무효 토큰 자동 감지 및 삭제
- ✅ Firestore `fcm_tokens` 컬렉션 자동 정리
- ✅ 오류 로그에 `errorCode` 추가로 디버깅 용이
- ✅ 알림 시스템 안정성 향상

---

**필요한 것**: Firebase 배포 권한만 있으면 됩니다!

배포 중 문제가 발생하면 Firebase Console Logs를 확인하세요. 🚀
