# 🎯 MaxDeviceLimit Issue 최종 해결 요약

## 📌 이슈 개요

**이슈 ID**: MaxDeviceLimitDialog fix  
**보고일**: 2025-12-04  
**보고자**: ringneck@naver.com  
**증상**: iOS 기기에서 로그인 시 MaxDeviceLimit 초과 시 기기 승인 플로우가 정상 작동하지 않음

---

## 🔍 문제 분석

### 1차 문제: Firestore Security Rules 권한 오류 (V6.1)

**증상**:
```
⚠️ device_approval_requests 쿼리 리슨 중 에러: [cloud_firestore/permission-denied] 
Missing or insufficient permissions.
```

**원인**:
- iOS 기기 승인 대기 화면에서 `.doc().snapshots()` 리스너 사용
- Firestore Rules에서 `resource.data.userId` 접근 시 `resource == null` 처리 누락
- V6.1 업데이트 시 `fcm_tokens`, `call_forward_info`만 수정하고 `device_approval_requests`는 누락

**영향**:
- iOS 기기에서 `ApprovalWaitingScreen` 표시되지 않음
- 로그인 화면으로 바로 돌아감
- 기기 승인 플로우 완전 중단

---

### 2차 문제: Web FCM 더미 토큰 생성

**증상**:
```json
{
  "error": "The registration token is not a valid FCM registration token",
  "errorCode": "messaging/invalid-argument",
  "targetToken": "web_dummy_token_1764856164056"
}
```

**원인**:
1. **VAPID Key 불일치**: Firebase Console의 VAPID Key와 코드의 VAPID Key 불일치
2. **브라우저 알림 권한 거부**: 사용자가 브라우저 알림 권한을 거부
3. **Service Worker 문제**: Flutter Web 빌드 시 Service Worker 등록 실패
4. **브라우저 호환성**: Safari 등 일부 브라우저의 제한적인 FCM 지원

**영향**:
- Web 플랫폼에서 FCM 알림 수신 불가
- iOS에서 승인 요청을 보내도 Web에서 알림을 받을 수 없음
- 기기 승인 플로우 작동하지 않음

---

## ✅ 해결 방안

### 해결 1: Firestore Security Rules V6.2 (FINAL) ✅

**수정 내용**:
```javascript
// firestore.rules - Line 91-93
match /device_approval_requests/{documentId} {
  allow read: if request.auth != null 
              && (resource == null || resource.data.userId == request.auth.uid);  // ← resource == null 추가
  allow write: if request.auth != null 
               && resource.data.userId == request.auth.uid;
  allow create: if request.auth != null 
                && request.resource.data.userId == request.auth.uid;
}
```

**변경 사항**:
- `resource == null` 체크 추가
- `.doc().snapshots()` 리스너 호출 시 문서가 아직 존재하지 않아도 권한 통과
- iOS 기기 승인 대기 리스너 정상 작동

**배포 상태**:
- ✅ 코드 수정 완료 (Commit: ff83437)
- ✅ Firebase Console 배포 완료 (2025-12-04)
- ✅ Git Push 완료 (e970e21)

**관련 문서**:
- `docs/FIRESTORE_SECURITY_RULES_V6.2_FINAL.md`
- `docs/FIREBASE_DEPLOY_GUIDE_V6.2.md`
- `docs/FIRESTORE_RULES_V6.2_DEPLOYED.md`

---

### 해결 2: Web FCM 디버그 로깅 강화 🔧

**수정 내용**:

**1) `lib/services/fcm/fcm_web_config.dart`**:
- VAPID Key 로그 출력 추가
- 토큰 획득 실패 시 상세 원인 진단 로그
- 알림 권한 거부 시 명확한 안내 메시지

**2) `lib/services/fcm_service.dart`**:
- Web FCM 토큰 획득 전 알림 권한 확인 로그
- 더미 토큰 생성 시 경고 메시지 강화
- 해결 방법 안내 추가

**배포 상태**:
- ✅ 코드 수정 완료 (Commit: bddd0f8)
- ✅ Git Push 완료

**관련 문서**:
- `docs/WEB_FCM_VAPID_KEY_GUIDE.md` (신규 작성)

---

### 해결 3: 검증 체크리스트 작성 📋

**목적**:
- MaxDeviceLimit 전체 플로우 검증을 위한 체계적인 체크리스트
- 단계별 예상 로그 및 검증 포인트 정리
- 문제 발생 시 빠른 진단을 위한 가이드

**배포 상태**:
- ✅ 문서 작성 완료 (Commit: 41d1150)
- ✅ Git Push 완료

**관련 문서**:
- `docs/MAXDEVICELIMIT_FLOW_VERIFICATION_CHECKLIST.md` (신규 작성)

---

## 📊 최종 상태

### ✅ 완료된 작업

1. **Firestore Security Rules V6.2 (FINAL)**
   - [x] `device_approval_requests` 규칙 수정
   - [x] `resource == null` 체크 추가
   - [x] Firebase Console 배포 완료
   - [x] Git 커밋 및 푸시 완료
   - [x] 관련 문서 3개 작성

2. **Web FCM 디버그 로깅 강화**
   - [x] `fcm_web_config.dart` 로깅 개선
   - [x] `fcm_service.dart` 로깅 개선
   - [x] VAPID Key 가이드 작성
   - [x] Git 커밋 및 푸시 완료

3. **검증 체크리스트**
   - [x] 전체 플로우 검증 체크리스트 작성
   - [x] 단계별 로그 및 확인 포인트 정리
   - [x] 문제 해결 가이드 포함
   - [x] Git 커밋 및 푸시 완료

### 🔧 진행 중 (사용자 조치 필요)

1. **Web VAPID Key 확인 및 업데이트**
   - [ ] Firebase Console에서 실제 VAPID Key 확인
   - [ ] `fcm_web_config.dart`의 VAPID Key와 비교
   - [ ] 불일치 시 VAPID Key 업데이트
   - [ ] Web 재빌드 및 배포

2. **Web 브라우저 알림 권한 설정**
   - [ ] Chrome 설정에서 알림 권한 허용
   - [ ] Web 로그아웃 후 재로그인
   - [ ] FCM 토큰 획득 확인 (더미 토큰 아닌 실제 토큰)

### ⏳ 대기 중

1. **iOS 전체 플로우 재검증**
   - [ ] Web FCM 정상화 후 테스트
   - [ ] ringneck@naver.com / iPhone 15 Pro
   - [ ] `docs/MAXDEVICELIMIT_FLOW_VERIFICATION_CHECKLIST.md` 참조하여 전체 플로우 검증

---

## 🎯 다음 단계

### Step 1: Web VAPID Key 확인 (즉시)

**Firebase Console 확인**:
1. https://console.firebase.google.com/ 접속
2. MAKECALL 프로젝트 선택
3. Project Settings > Cloud Messaging > Web Push certificates
4. Key pair 확인 또는 생성

**코드 비교**:
- Firebase Console의 VAPID Key
- `lib/services/fcm/fcm_web_config.dart`의 `vapidKey`
- 일치 여부 확인

**불일치 시 조치**:
- `fcm_web_config.dart`의 VAPID Key 업데이트
- Web 재빌드: `flutter build web --release`
- 서버 재시작

### Step 2: Web 재로그인 (즉시)

**브라우저 설정 확인**:
1. Chrome 주소창 왼쪽 자물쇠 아이콘 클릭
2. 사이트 설정 → 알림 → "허용"으로 변경

**재로그인**:
1. Web에서 로그아웃
2. 브라우저 캐시 삭제 (선택사항)
3. 다시 로그인
4. 알림 권한 요청 팝업에서 "허용" 클릭

**검증**:
- 브라우저 콘솔 (F12 → Console)에서 로그 확인
- `✅ [FCM-WEB] 웹 FCM 토큰 획득 성공` 확인
- Firestore `fcm_tokens` 컬렉션에서 실제 FCM 토큰 확인

### Step 3: iOS 전체 플로우 테스트 (Web FCM 정상화 후)

**테스트 시나리오**:
1. **Web 로그인**: ringneck@naver.com (기존 기기)
2. **iOS 로그인 시도**: iPhone 15 Pro (새 기기)
3. **MaxDeviceLimitDialog 확인**: 기기 제한 팝업 표시
4. **승인 요청 전송**: "승인 요청 보내기" 클릭
5. **Web 알림 수신**: FCM 알림 도착 확인
6. **승인 처리**: Web에서 승인 버튼 클릭
7. **iOS 자동 로그인**: 자동으로 MainScreen 표시

**검증 포인트**:
- `docs/MAXDEVICELIMIT_FLOW_VERIFICATION_CHECKLIST.md` 참조
- 각 단계별 콘솔 로그 확인
- Firestore 컬렉션 상태 확인

---

## 📚 관련 문서 및 파일

### 코드 파일

1. **Firestore Security Rules**:
   - `firestore.rules` (Line 91-93)

2. **Web FCM 관련**:
   - `lib/services/fcm/fcm_web_config.dart`
   - `lib/services/fcm_service.dart` (Line 320-336)

3. **기기 승인 플로우**:
   - `lib/services/fcm/fcm_device_approval_service.dart`
   - `lib/screens/auth/max_device_limit_dialog.dart`
   - `lib/screens/auth/approval_waiting_screen.dart`
   - `lib/screens/auth/device_approval_screen.dart`

### 문서 파일

1. **Firestore Rules 관련**:
   - `docs/FIRESTORE_SECURITY_RULES_V6.2_FINAL.md` (V6.2 규칙 상세)
   - `docs/FIREBASE_DEPLOY_GUIDE_V6.2.md` (배포 가이드)
   - `docs/FIRESTORE_RULES_V6.2_DEPLOYED.md` (배포 확인)
   - `FIRESTORE_RULES_V6.2_SUMMARY.md` (V6.2 요약)

2. **Web FCM 관련**:
   - `docs/WEB_FCM_VAPID_KEY_GUIDE.md` (VAPID Key 설정 가이드)

3. **검증 가이드**:
   - `docs/MAXDEVICELIMIT_FLOW_VERIFICATION_CHECKLIST.md` (전체 플로우 검증)

4. **요약 문서**:
   - `MAXDEVICELIMIT_ISSUE_FINAL_SUMMARY.md` (이 문서)

### Git 커밋 이력

```
41d1150 - Docs: MaxDeviceLimit 플로우 검증 체크리스트 추가 (2025-12-04)
bddd0f8 - Debug: Web FCM 초기화 실패 진단 로깅 강화 + VAPID Key 가이드 (2025-12-04)
e970e21 - Firestore Rules V6.2 deployment confirmed (2025-12-04)
b515b68 - Add Firestore Rules V6.2 최종 요약 문서 (2025-12-04)
727099b - Add Firebase Console 배포 가이드 V6.2 (2025-12-04)
ff83437 - Firestore Security Rules V6.2 (FINAL) - device_approval_requests 수정 (2025-12-04)
```

---

## 🚀 빠른 참조 (Quick Reference)

### Firestore Rules V6.2 핵심 변경

```javascript
// BEFORE (V6.1)
allow read: if request.auth != null 
            && resource.data.userId == request.auth.uid;

// AFTER (V6.2)
allow read: if request.auth != null 
            && (resource == null || resource.data.userId == request.auth.uid);
            //  ^^^^^^^^^^^^^^^^ 추가됨
```

### Web FCM 토큰 확인

```javascript
// 브라우저 콘솔 (F12 → Console)

// ✅ 정상 (실제 FCM 토큰)
✅ [FCM-WEB] 웹 FCM 토큰 획득 성공
   토큰 길이: 152
   토큰 일부: eKGjlw8xRqGm3F7j8Q9P2V...

// ❌ 비정상 (더미 토큰)
⚠️ [FCM-WEB] FCM 토큰 없음 - 더미 토큰으로 기기 정보 저장
⚠️ [FCM-WEB] ❌ 감지됨: 더미 토큰 사용 시 FCM 알림 수신 불가!
```

### 문제 해결 우선순위

1. **긴급**: Web VAPID Key 확인 및 업데이트
2. **긴급**: Web 브라우저 알림 권한 허용
3. **긴급**: Web 재로그인으로 실제 FCM 토큰 획득
4. **정상**: iOS 전체 플로우 재검증

---

## 📞 연락처

**GitHub Repository**: https://github.com/ringneck/makecall  
**테스트 계정**: ringneck@naver.com  
**테스트 기기**: iPhone 15 Pro (iOS 26.1)

---

**작성일**: 2025-12-04  
**작성자**: Ringneck Flutter Developer  
**버전**: V6.2 (FINAL)  
**상태**: ✅ 코드 수정 완료 / 🔧 사용자 조치 대기 (Web VAPID Key 및 알림 권한)
