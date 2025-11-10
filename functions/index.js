/**
 * Firebase Cloud Functions for MAKECALL App
 * 고급 웹푸시 알림 시스템
 *
 * 주요 기능:
 * 1. 중복 로그인 방지 - FCM 푸시 알림 전송
 * 2. 원격 로그아웃 - 특정 기기 강제 로그아웃
 * 3. 만료된 FCM 토큰 정리
 * 4. 착신 전화 알림 (실시간)
 * 5. 통화 상태 변경 알림
 * 6. 그룹 메시지 브로드캐스트
 * 7. 예약 알림 전송
 * 8. 사용자 지정 알림
 */

const {onDocumentCreated, onDocumentUpdated} = require("firebase-functions/v2/firestore");
const {onCall, HttpsError, onRequest} = require("firebase-functions/v2/https");
const {logger} = require("firebase-functions/v2");
const admin = require("firebase-admin");

// Firebase Admin 초기화
admin.initializeApp();

// ============================================================================
// 1. 강제 로그아웃 FCM 메시지 전송 (기존 함수)
// ============================================================================

/**
 * 강제 로그아웃 FCM 메시지 전송
 *
 * fcm_force_logout_queue 컬렉션에 새 문서가 생성되면 자동 실행됩니다.
 * 중복 로그인 감지 시 기존 기기에 강제 로그아웃 알림을 전송합니다.
 */
exports.sendForceLogoutNotification = onDocumentCreated(
    {
      document: "fcm_force_logout_queue/{queueId}",
      region: "asia-east1",
    },
    async (event) => {
      const snapshot = event.data;
      if (!snapshot) {
        logger.error("No data associated with the event");
        return;
      }

      const data = snapshot.data();

      // 이미 처리된 메시지는 스킵
      if (data.processed) {
        logger.info("Message already processed, skipping...");
        return;
      }

      logger.info("=".repeat(60));
      logger.info("📤 강제 로그아웃 FCM 메시지 전송 시작");
      logger.info("=".repeat(60));
      logger.info(`Target Token: ${data.targetToken.substring(0, 30)}...`);
      logger.info(`New Device: ${data.newDeviceName} (${data.newPlatform})`);

      try {
        // FCM 메시지 구성
        const message = {
          token: data.targetToken,
          notification: {
            title: data.message.title,
            body: data.message.body,
          },
          data: {
            type: "force_logout",
            newDeviceName: data.newDeviceName,
            newPlatform: data.newPlatform,
          },
          // 높은 우선순위 설정 (즉시 전달)
          android: {
            priority: "high",
          },
          apns: {
            headers: {
              "apns-priority": "10",
            },
          },
          webpush: {
            headers: {
              Urgency: "high",
            },
            notification: {
              icon: "/icons/app_icon.png",
              badge: "/icons/badge.png",
              requireInteraction: true,
            },
          },
        };

        // FCM 메시지 전송
        const response = await admin.messaging().send(message);
        logger.info(`✅ FCM 메시지 전송 성공: ${response}`);

        // 처리 완료 플래그 업데이트
        await snapshot.ref.update({
          processed: true,
          sentAt: admin.firestore.FieldValue.serverTimestamp(),
          response: response,
        });

        logger.info("✅ 강제 로그아웃 알림 전송 완료");
        logger.info("=".repeat(60));
      } catch (error) {
        logger.error("❌ FCM 메시지 전송 실패:", error);

        // 에러 정보 저장
        await snapshot.ref.update({
          processed: true,
          error: error.message,
          errorCode: error.code,
          failedAt: admin.firestore.FieldValue.serverTimestamp(),
        });

        // 토큰이 유효하지 않은 경우 fcm_tokens에서 제거
        if (error.code === "messaging/invalid-registration-token" ||
            error.code === "messaging/registration-token-not-registered") {
          logger.warn("⚠️  유효하지 않은 FCM 토큰 감지, 자동 삭제 처리");

          // fcm_tokens 컬렉션에서 해당 토큰 검색 및 삭제
          const tokensSnapshot = await admin.firestore()
              .collection("fcm_tokens")
              .where("fcmToken", "==", data.targetToken)
              .get();

          const batch = admin.firestore().batch();
          tokensSnapshot.docs.forEach((doc) => {
            batch.delete(doc.ref);
          });
          await batch.commit();

          logger.info("✅ 유효하지 않은 FCM 토큰 삭제 완료");
        }
      }
    },
);

// ============================================================================
// 2. 원격 로그아웃 함수 (기존 함수)
// ============================================================================

/**
 * 원격 로그아웃 함수 (Callable Function)
 *
 * 클라이언트에서 호출하여 특정 기기를 원격으로 로그아웃시킵니다.
 * 활성 세션 관리 UI에서 사용됩니다.
 *
 * @param {Object} data - 요청 데이터
 * @param {string} data.targetDeviceId - 로그아웃할 기기 ID
 * @param {string} data.targetUserId - 대상 사용자 ID
 * @return {Promise<Object>} 결과 객체
 */
exports.remoteLogout = onCall(
    {region: "asia-east1"},
    async (request) => {
      const {data, auth} = request;

      // 인증 확인
      if (!auth) {
        throw new HttpsError("unauthenticated", "인증이 필요합니다.");
      }

      logger.info("=".repeat(60));
      logger.info("🔐 원격 로그아웃 요청 수신");
      logger.info("=".repeat(60));
      logger.info(`Caller UID: ${auth.uid}`);
      logger.info(`Target User ID: ${data.targetUserId}`);
      logger.info(`Target Device ID: ${data.targetDeviceId}`);

      // 권한 확인: 본인의 기기만 로그아웃 가능
      if (auth.uid !== data.targetUserId) {
        logger.warn("❌ 권한 없음: 다른 사용자의 기기를 로그아웃할 수 없습니다.");
        throw new HttpsError(
            "permission-denied",
            "본인의 기기만 로그아웃할 수 있습니다.",
        );
      }

      try {
        // 대상 기기의 FCM 토큰 조회
        const tokenDoc = await admin.firestore()
            .collection("fcm_tokens")
            .doc(`${data.targetUserId}_${data.targetDeviceId}`)
            .get();

        if (!tokenDoc.exists) {
          logger.warn("⚠️  대상 기기를 찾을 수 없습니다.");
          throw new HttpsError(
              "not-found",
              "대상 기기를 찾을 수 없습니다.",
          );
        }

        const tokenData = tokenDoc.data();
        logger.info(`Target Device: ${tokenData.deviceName} (${tokenData.platform})`);
        logger.info(`Target Token: ${tokenData.fcmToken.substring(0, 30)}...`);

        // FCM 메시지 전송
        const message = {
          token: tokenData.fcmToken,
          notification: {
            title: "원격 로그아웃",
            body: "다른 위치에서 이 기기를 로그아웃했습니다.",
          },
          data: {
            type: "force_logout",
            reason: "remote_logout",
            newDeviceName: "다른 기기",
            newPlatform: "unknown",
          },
          android: {
            priority: "high",
          },
          apns: {
            headers: {
              "apns-priority": "10",
            },
          },
          webpush: {
            headers: {
              Urgency: "high",
            },
            notification: {
              icon: "/icons/app_icon.png",
              requireInteraction: true,
            },
          },
        };

        const response = await admin.messaging().send(message);
        logger.info(`✅ FCM 메시지 전송 성공: ${response}`);

        // FCM 토큰 삭제
        await tokenDoc.ref.delete();
        logger.info("✅ FCM 토큰 삭제 완료");

        logger.info("✅ 원격 로그아웃 완료");
        logger.info("=".repeat(60));

        return {
          success: true,
          message: "원격 로그아웃이 완료되었습니다.",
          deviceName: tokenData.deviceName,
        };
      } catch (error) {
        logger.error("❌ 원격 로그아웃 실패:", error);

        // Firebase 에러가 아닌 경우 일반 에러로 변환
        if (error instanceof HttpsError) {
          throw error;
        }

        throw new HttpsError(
            "internal",
            `원격 로그아웃 처리 중 오류가 발생했습니다: ${error.message}`,
        );
      }
    },
);

// ============================================================================
// 3. 만료된 FCM 토큰 정리 (Callable Function으로 변경)
// ============================================================================

/**
 * 만료된 FCM 토큰 정리 함수
 *
 * Cloud Scheduler 권한 문제로 인해 Scheduled Function에서 Callable Function으로 변경
 * 외부 크론 서비스(예: GitHub Actions, Cloud Run Jobs)에서 주기적으로 호출 가능
 *
 * @param {Object} data - 요청 데이터
 * @param {number} data.daysThreshold - 토큰 만료 기준 일수 (기본값: 30)
 * @param {boolean} data.testMode - 테스트 모드 (삭제하지 않고 개수만 반환)
 * @return {Promise<Object>} 결과 객체
 */
exports.cleanupExpiredTokens = onCall(
    {region: "asia-east1"},
    async (request) => {
      const {data, auth} = request;

      // 인증 확인 (선택적 - 공개 엔드포인트로 사용하려면 제거)
      if (!auth) {
        logger.warn("⚠️  인증되지 않은 요청으로 토큰 정리 실행");
      }

      logger.info("=".repeat(60));
      logger.info("🧹 만료된 FCM 토큰 정리 시작");
      logger.info("=".repeat(60));

      try {
        const daysThreshold = data?.daysThreshold || 30;
        const testMode = data?.testMode || false;

        const expiryDate = new Date();
        expiryDate.setDate(expiryDate.getDate() - daysThreshold);

        logger.info(`기준 날짜: ${expiryDate.toISOString()}`);
        logger.info(`테스트 모드: ${testMode}`);

        const expiredTokens = await admin.firestore()
            .collection("fcm_tokens")
            .where("lastActiveAt", "<", admin.firestore.Timestamp.fromDate(expiryDate))
            .get();

        logger.info(`발견된 만료 토큰: ${expiredTokens.size}개`);

        if (expiredTokens.empty) {
          logger.info("✅ 만료된 토큰이 없습니다.");
          return {
            success: true,
            deletedCount: 0,
            totalTokens: 0,
            testMode: testMode,
          };
        }

        if (testMode) {
          logger.info("⚠️  테스트 모드: 삭제하지 않음");
          return {
            success: true,
            deletedCount: 0,
            totalTokens: expiredTokens.size,
            testMode: true,
          };
        }

        // 배치 삭제 (500개씩)
        const batches = [];
        let batch = admin.firestore().batch();
        let batchCount = 0;

        expiredTokens.docs.forEach((doc, index) => {
          batch.delete(doc.ref);
          batchCount++;

          // 500개마다 새 배치 생성
          if (batchCount === 500 || index === expiredTokens.docs.length - 1) {
            batches.push(batch.commit());
            batch = admin.firestore().batch();
            batchCount = 0;
          }
        });

        await Promise.all(batches);

        logger.info(`✅ ${expiredTokens.size}개의 만료된 토큰 삭제 완료`);
        logger.info("=".repeat(60));

        return {
          success: true,
          deletedCount: expiredTokens.size,
          totalTokens: expiredTokens.size,
          testMode: false,
        };
      } catch (error) {
        logger.error("❌ 토큰 정리 실패:", error);
        throw new HttpsError("internal", `토큰 정리 실패: ${error.message}`);
      }
    },
);

/**
 * 수동 토큰 정리 함수 (별칭 - cleanupExpiredTokens와 동일)
 * 기존 코드 호환성을 위해 유지
 */
exports.manualCleanupTokens = onCall(
    {region: "asia-east1"},
    async (request) => {
      const {auth} = request;

      if (!auth) {
        throw new HttpsError("unauthenticated", "인증이 필요합니다.");
      }

      logger.info("=".repeat(60));
      logger.info("🧹 만료된 FCM 토큰 정리 시작 (수동)");
      logger.info("=".repeat(60));

      try {
        const thirtyDaysAgo = new Date();
        thirtyDaysAgo.setDate(thirtyDaysAgo.getDate() - 30);

        const expiredTokens = await admin.firestore()
            .collection("fcm_tokens")
            .where("lastActiveAt", "<", admin.firestore.Timestamp.fromDate(thirtyDaysAgo))
            .get();

        logger.info(`발견된 만료 토큰: ${expiredTokens.size}개`);

        if (expiredTokens.empty) {
          logger.info("✅ 만료된 토큰이 없습니다.");
          return {success: true, deletedCount: 0};
        }

        // 배치 삭제
        const batch = admin.firestore().batch();
        expiredTokens.docs.forEach((doc) => {
          batch.delete(doc.ref);
        });
        await batch.commit();

        logger.info(`✅ ${expiredTokens.size}개의 만료된 토큰 삭제 완료`);
        logger.info("=".repeat(60));

        return {
          success: true,
          deletedCount: expiredTokens.size,
        };
      } catch (error) {
        logger.error("❌ 토큰 정리 실패:", error);
        throw new HttpsError(
            "internal",
            `토큰 정리 중 오류가 발생했습니다: ${error.message}`,
        );
      }
    },
);

// ============================================================================
// 4. 착신 전화 알림 (실시간)
// ============================================================================

/**
 * 착신 전화 알림
 *
 * incoming_calls 컬렉션에 새 문서가 생성되면 자동으로 알림 전송
 */
exports.sendIncomingCallNotification = onDocumentCreated(
    {
      document: "incoming_calls/{callId}",
      region: "asia-east1",
    },
    async (event) => {
      const snapshot = event.data;
      if (!snapshot) {
        logger.error("No data associated with the event");
        return;
      }

      const callData = snapshot.data();

      logger.info("=".repeat(60));
      logger.info("📞 착신 전화 알림 전송");
      logger.info("=".repeat(60));
      logger.info(`User ID: ${callData.userId}`);
      logger.info(`Caller: ${callData.callerNumber}`);
      logger.info(`Extension: ${callData.extension}`);

      try {
        // 사용자의 모든 활성 기기에 알림 전송
        const tokensSnapshot = await admin.firestore()
            .collection("fcm_tokens")
            .where("userId", "==", callData.userId)
            .get();

        if (tokensSnapshot.empty) {
          logger.warn("⚠️  사용자의 활성 기기가 없습니다.");
          return;
        }

        const tokens = tokensSnapshot.docs.map((doc) => doc.data().fcmToken);
        logger.info(`발견된 활성 기기: ${tokens.length}개`);

        // 멀티캐스트 메시지 구성
        const message = {
          tokens: tokens,
          notification: {
            title: "📞 착신 전화",
            body: `${callData.callerName || callData.callerNumber}님의 전화`,
          },
          data: {
            type: "incoming_call",
            callId: snapshot.id,
            callerNumber: callData.callerNumber,
            callerName: callData.callerName || "",
            extension: callData.extension,
            timestamp: new Date().toISOString(),
          },
          android: {
            priority: "high",
            notification: {
              sound: "default",
              channelId: "incoming_calls",
            },
          },
          apns: {
            headers: {
              "apns-priority": "10",
            },
            payload: {
              aps: {
                sound: "default",
                category: "INCOMING_CALL",
              },
            },
          },
          webpush: {
            headers: {
              Urgency: "high",
            },
            notification: {
              icon: "/icons/call_icon.png",
              badge: "/icons/badge.png",
              vibrate: [200, 100, 200],
              requireInteraction: true,
              actions: [
                {action: "answer", title: "응답"},
                {action: "reject", title: "거부"},
              ],
            },
          },
        };

        const response = await admin.messaging().sendEachForMulticast(message);
        logger.info(`✅ 알림 전송 완료 - 성공: ${response.successCount}, 실패: ${response.failureCount}`);

        // 실패한 토큰 처리
        if (response.failureCount > 0) {
          const failedTokens = [];
          response.responses.forEach((resp, idx) => {
            if (!resp.success) {
              failedTokens.push(tokens[idx]);
            }
          });
          logger.warn(`⚠️  실패한 토큰: ${failedTokens.length}개`);
        }

        logger.info("=".repeat(60));
      } catch (error) {
        logger.error("❌ 착신 전화 알림 전송 실패:", error);
      }
    },
);

// ============================================================================
// 5. 통화 상태 변경 알림
// ============================================================================

/**
 * 통화 상태 변경 알림
 *
 * call_history 문서가 업데이트되면 상태 변경 알림 전송
 */
exports.sendCallStatusNotification = onDocumentUpdated(
    {
      document: "call_history/{historyId}",
      region: "asia-east1",
    },
    async (event) => {
      const beforeData = event.data.before.data();
      const afterData = event.data.after.data();

      // 통화 상태가 변경된 경우만 처리
      if (beforeData.status === afterData.status) {
        return;
      }

      logger.info("=".repeat(60));
      logger.info("📱 통화 상태 변경 알림");
      logger.info("=".repeat(60));
      logger.info(`이전 상태: ${beforeData.status} → 새 상태: ${afterData.status}`);

      // 통화 종료 시 알림
      if (afterData.status === "ended" || afterData.status === "missed") {
        try {
          const tokensSnapshot = await admin.firestore()
              .collection("fcm_tokens")
              .where("userId", "==", afterData.userId)
              .get();

          if (tokensSnapshot.empty) {
            logger.warn("⚠️  사용자의 활성 기기가 없습니다.");
            return;
          }

          const tokens = tokensSnapshot.docs.map((doc) => doc.data().fcmToken);

          const statusText = afterData.status === "ended" ? "종료되었습니다" : "부재중 전화입니다";

          const message = {
            tokens: tokens,
            notification: {
              title: "통화 알림",
              body: `${afterData.phoneNumber}와의 통화가 ${statusText}`,
            },
            data: {
              type: "call_status_update",
              status: afterData.status,
              phoneNumber: afterData.phoneNumber,
              duration: afterData.duration?.toString() || "0",
            },
            android: {
              priority: "default",
            },
            webpush: {
              notification: {
                icon: "/icons/call_icon.png",
              },
            },
          };

          const response = await admin.messaging().sendEachForMulticast(message);
          logger.info(`✅ 상태 변경 알림 전송 완료 - 성공: ${response.successCount}`);
        } catch (error) {
          logger.error("❌ 통화 상태 알림 전송 실패:", error);
        }
      }

      logger.info("=".repeat(60));
    },
);

// ============================================================================
// 6. 그룹 메시지 브로드캐스트
// ============================================================================

/**
 * 그룹 메시지 브로드캐스트 (Callable Function)
 *
 * 특정 사용자 그룹에게 메시지를 일괄 전송합니다.
 *
 * @param {Object} data - 요청 데이터
 * @param {Array<string>} data.userIds - 수신자 ID 목록
 * @param {string} data.title - 알림 제목
 * @param {string} data.body - 알림 내용
 * @param {Object} data.data - 추가 데이터
 */
exports.sendGroupMessage = onCall(
    {region: "asia-east1"},
    async (request) => {
      const {data, auth} = request;

      if (!auth) {
        throw new HttpsError("unauthenticated", "인증이 필요합니다.");
      }

      logger.info("=".repeat(60));
      logger.info("📢 그룹 메시지 브로드캐스트");
      logger.info("=".repeat(60));
      logger.info(`발신자: ${auth.uid}`);
      logger.info(`수신자 수: ${data.userIds.length}`);

      try {
        // 수신자들의 FCM 토큰 수집
        const allTokens = [];

        for (const userId of data.userIds) {
          const tokensSnapshot = await admin.firestore()
              .collection("fcm_tokens")
              .where("userId", "==", userId)
              .get();

          tokensSnapshot.docs.forEach((doc) => {
            allTokens.push(doc.data().fcmToken);
          });
        }

        if (allTokens.length === 0) {
          logger.warn("⚠️  활성 기기가 없습니다.");
          return {success: false, message: "수신 가능한 기기가 없습니다."};
        }

        logger.info(`수집된 토큰: ${allTokens.length}개`);

        // 메시지 전송 (500개씩 배치)
        const batchSize = 500;
        let successCount = 0;
        let failureCount = 0;

        for (let i = 0; i < allTokens.length; i += batchSize) {
          const tokenBatch = allTokens.slice(i, i + batchSize);

          const message = {
            tokens: tokenBatch,
            notification: {
              title: data.title,
              body: data.body,
            },
            data: {
              type: "group_message",
              senderId: auth.uid,
              timestamp: new Date().toISOString(),
              ...data.data,
            },
            android: {
              priority: "high",
            },
            webpush: {
              headers: {
                Urgency: "high",
              },
              notification: {
                icon: "/icons/message_icon.png",
              },
            },
          };

          const response = await admin.messaging().sendEachForMulticast(message);
          successCount += response.successCount;
          failureCount += response.failureCount;
        }

        logger.info(`✅ 전송 완료 - 성공: ${successCount}, 실패: ${failureCount}`);
        logger.info("=".repeat(60));

        return {
          success: true,
          successCount,
          failureCount,
          totalTokens: allTokens.length,
        };
      } catch (error) {
        logger.error("❌ 그룹 메시지 전송 실패:", error);
        throw new HttpsError(
            "internal",
            `그룹 메시지 전송 중 오류가 발생했습니다: ${error.message}`,
        );
      }
    },
);

// ============================================================================
// 7. 예약 알림 전송 (Callable Function으로 변경)
// ============================================================================

/**
 * 예약 알림 처리 함수
 *
 * Cloud Scheduler 권한 문제로 인해 Scheduled Function에서 Callable Function으로 변경
 * 외부 크론 서비스(예: GitHub Actions, Cloud Run Jobs)에서 주기적으로 호출 가능
 *
 * scheduled_notifications 컬렉션을 확인하여 예약된 알림을 전송합니다.
 *
 * @param {Object} data - 요청 데이터
 * @param {number} data.limit - 한 번에 처리할 알림 개수 (기본값: 100)
 * @return {Promise<Object>} 처리 결과
 */
exports.processScheduledNotifications = onCall(
    {region: "asia-east1"},
    async (request) => {
      const {data, auth} = request;

      // 인증 확인 (선택적 - 공개 엔드포인트로 사용하려면 제거)
      if (!auth) {
        logger.warn("⚠️  인증되지 않은 요청으로 예약 알림 처리 실행");
      }

      logger.info("=".repeat(60));
      logger.info("📅 예약 알림 처리 시작");
      logger.info("=".repeat(60));

      const now = admin.firestore.Timestamp.now();
      const limit = data?.limit || 100;

      try {
        // 전송 시각이 지난 미처리 알림 조회
        const scheduledNotifs = await admin.firestore()
            .collection("scheduled_notifications")
            .where("scheduledAt", "<=", now)
            .where("processed", "==", false)
            .limit(limit)
            .get();

        if (scheduledNotifs.empty) {
          logger.info("✅ 처리할 예약 알림이 없습니다.");
          return {
            success: true,
            processedCount: 0,
            totalFound: 0,
          };
        }

        logger.info(`발견된 예약 알림: ${scheduledNotifs.size}개`);

        const batch = admin.firestore().batch();
        let successCount = 0;
        let failureCount = 0;

        for (const doc of scheduledNotifs.docs) {
          const notifData = doc.data();

          try {
            // 사용자의 FCM 토큰 조회
            const tokensSnapshot = await admin.firestore()
                .collection("fcm_tokens")
                .where("userId", "==", notifData.userId)
                .get();

            if (!tokensSnapshot.empty) {
              const tokens = tokensSnapshot.docs.map((d) => d.data().fcmToken);

              const message = {
                tokens: tokens,
                notification: {
                  title: notifData.title,
                  body: notifData.body,
                },
                data: {
                  type: "scheduled_notification",
                  notificationId: doc.id,
                  ...notifData.data,
                },
                webpush: {
                  notification: {
                    icon: "/icons/notification_icon.png",
                  },
                },
              };

              await admin.messaging().sendEachForMulticast(message);
              logger.info(`✅ 예약 알림 전송: ${doc.id}`);
              successCount++;
            }

            // 처리 완료 표시
            batch.update(doc.ref, {
              processed: true,
              sentAt: admin.firestore.FieldValue.serverTimestamp(),
            });
          } catch (error) {
            logger.error(`❌ 예약 알림 전송 실패 (${doc.id}):`, error);
            failureCount++;

            // 에러 정보 저장
            batch.update(doc.ref, {
              processed: true,
              error: error.message,
              failedAt: admin.firestore.FieldValue.serverTimestamp(),
            });
          }
        }

        await batch.commit();
        logger.info(`✅ 예약 알림 처리 완료 - 성공: ${successCount}, 실패: ${failureCount}`);
        logger.info("=".repeat(60));

        return {
          success: true,
          processedCount: scheduledNotifs.size,
          totalFound: scheduledNotifs.size,
          successCount: successCount,
          failureCount: failureCount,
        };
      } catch (error) {
        logger.error("❌ 예약 알림 처리 실패:", error);
        throw new HttpsError("internal", `예약 알림 처리 실패: ${error.message}`);
      }
    },
);

// ============================================================================
// 8. 사용자 지정 알림 전송 (Callable Function)
// ============================================================================

/**
 * 사용자 지정 알림 전송
 *
 * 클라이언트에서 호출하여 특정 사용자에게 커스텀 알림을 전송합니다.
 *
 * @param {Object} data - 요청 데이터
 * @param {string} data.userId - 수신자 ID
 * @param {string} data.title - 알림 제목
 * @param {string} data.body - 알림 내용
 * @param {Object} data.data - 추가 데이터
 * @param {string} data.priority - 우선순위 (high/normal)
 * @param {Object} data.webpush - 웹푸시 옵션
 */
exports.sendCustomNotification = onCall(
    {region: "asia-east1"},
    async (request) => {
      const {data, auth} = request;

      if (!auth) {
        throw new HttpsError("unauthenticated", "인증이 필요합니다.");
      }

      logger.info("=".repeat(60));
      logger.info("🔔 사용자 지정 알림 전송");
      logger.info("=".repeat(60));
      logger.info(`발신자: ${auth.uid}`);
      logger.info(`수신자: ${data.userId}`);
      logger.info(`제목: ${data.title}`);

      try {
        // 수신자의 FCM 토큰 조회
        const tokensSnapshot = await admin.firestore()
            .collection("fcm_tokens")
            .where("userId", "==", data.userId)
            .get();

        if (tokensSnapshot.empty) {
          logger.warn("⚠️  수신자의 활성 기기가 없습니다.");
          return {success: false, message: "수신 가능한 기기가 없습니다."};
        }

        const tokens = tokensSnapshot.docs.map((doc) => doc.data().fcmToken);
        logger.info(`활성 기기: ${tokens.length}개`);

        // 메시지 구성
        const message = {
          tokens: tokens,
          notification: {
            title: data.title,
            body: data.body,
          },
          data: {
            type: "custom_notification",
            senderId: auth.uid,
            timestamp: new Date().toISOString(),
            ...data.data,
          },
          android: {
            priority: data.priority === "high" ? "high" : "normal",
          },
          apns: {
            headers: {
              "apns-priority": data.priority === "high" ? "10" : "5",
            },
          },
          webpush: {
            headers: {
              Urgency: data.priority === "high" ? "high" : "normal",
            },
            notification: {
              icon: data.webpush?.icon || "/icons/notification_icon.png",
              badge: data.webpush?.badge || "/icons/badge.png",
              vibrate: data.webpush?.vibrate || [200, 100, 200],
              requireInteraction: data.webpush?.requireInteraction || false,
              ...data.webpush,
            },
          },
        };

        const response = await admin.messaging().sendEachForMulticast(message);
        logger.info(`✅ 알림 전송 완료 - 성공: ${response.successCount}, 실패: ${response.failureCount}`);
        logger.info("=".repeat(60));

        return {
          success: true,
          successCount: response.successCount,
          failureCount: response.failureCount,
        };
      } catch (error) {
        logger.error("❌ 사용자 지정 알림 전송 실패:", error);
        throw new HttpsError(
            "internal",
            `알림 전송 중 오류가 발생했습니다: ${error.message}`,
        );
      }
    },
);

// ============================================================================
// 9. 웹푸시 구독 관리
// ============================================================================

/**
 * 웹푸시 구독 등록/업데이트
 */
exports.subscribeWebPush = onCall(
    {region: "asia-east1"},
    async (request) => {
      const {data, auth} = request;

      if (!auth) {
        throw new HttpsError("unauthenticated", "인증이 필요합니다.");
      }

      logger.info("🌐 웹푸시 구독 등록");

      try {
        const tokenDoc = admin.firestore()
            .collection("fcm_tokens")
            .doc(`${auth.uid}_${data.deviceId}`);

        await tokenDoc.set({
          userId: auth.uid,
          fcmToken: data.fcmToken,
          deviceId: data.deviceId,
          deviceName: data.deviceName || "Web Browser",
          platform: "web",
          createdAt: admin.firestore.FieldValue.serverTimestamp(),
          lastActiveAt: admin.firestore.FieldValue.serverTimestamp(),
        }, {merge: true});

        logger.info("✅ 웹푸시 구독 등록 완료");

        return {success: true};
      } catch (error) {
        logger.error("❌ 웹푸시 구독 등록 실패:", error);
        throw new HttpsError(
            "internal",
            `구독 등록 중 오류가 발생했습니다: ${error.message}`,
        );
      }
    },
);

// ============================================================================
// 10. 알림 통계 API
// ============================================================================

/**
 * 알림 통계 조회 (HTTP 함수)
 */
exports.getNotificationStats = onRequest(
    {region: "asia-east1"},
    async (req, res) => {
      // CORS 헤더 설정
      res.set("Access-Control-Allow-Origin", "*");
      res.set("Access-Control-Allow-Methods", "GET, POST");
      res.set("Access-Control-Allow-Headers", "Content-Type");

      if (req.method === "OPTIONS") {
        res.status(204).send("");
        return;
      }

      try {
        // 활성 토큰 수
        const activeTokens = await admin.firestore()
            .collection("fcm_tokens")
            .count()
            .get();

        // 처리된 강제 로그아웃 수
        const processedLogouts = await admin.firestore()
            .collection("fcm_force_logout_queue")
            .where("processed", "==", true)
            .count()
            .get();

        // 예약된 알림 수
        const scheduledNotifs = await admin.firestore()
            .collection("scheduled_notifications")
            .where("processed", "==", false)
            .count()
            .get();

        const stats = {
          activeTokens: activeTokens.data().count,
          processedLogouts: processedLogouts.data().count,
          pendingScheduledNotifications: scheduledNotifs.data().count,
          timestamp: new Date().toISOString(),
        };

        logger.info("📊 알림 통계 조회:", stats);

        res.status(200).json(stats);
      } catch (error) {
        logger.error("❌ 통계 조회 실패:", error);
        res.status(500).json({error: error.message});
      }
    },
);

// ============================================================================
// 11. 일괄 토큰 갱신 (관리자용)
// ============================================================================

/**
 * FCM 토큰 일괄 갱신 확인
 *
 * 모든 토큰의 유효성을 확인하고 무효한 토큰을 삭제합니다.
 */
exports.validateAllTokens = onCall(
    {region: "asia-east1"},
    async (request) => {
      const {auth} = request;

      if (!auth) {
        throw new HttpsError("unauthenticated", "인증이 필요합니다.");
      }

      logger.info("=".repeat(60));
      logger.info("🔍 모든 FCM 토큰 유효성 검사 시작");
      logger.info("=".repeat(60));

      try {
        const tokensSnapshot = await admin.firestore()
            .collection("fcm_tokens")
            .get();

        logger.info(`총 토큰 수: ${tokensSnapshot.size}개`);

        let validCount = 0;
        let invalidCount = 0;
        const invalidTokenRefs = [];

        // 토큰 유효성 검사 (배치 처리)
        const batchSize = 100;
        for (let i = 0; i < tokensSnapshot.docs.length; i += batchSize) {
          const batch = tokensSnapshot.docs.slice(i, i + batchSize);
          const tokens = batch.map((doc) => doc.data().fcmToken);

          try {
            // 더미 메시지로 토큰 유효성 확인
            const response = await admin.messaging().sendEachForMulticast({
              tokens: tokens,
              data: {type: "validation_test"},
              dryRun: true, // 실제로 전송하지 않음
            });

            response.responses.forEach((resp, idx) => {
              if (resp.success) {
                validCount++;
              } else {
                invalidCount++;
                invalidTokenRefs.push(batch[idx].ref);
              }
            });
          } catch (error) {
            logger.error(`배치 ${i}-${i + batchSize} 처리 실패:`, error);
          }
        }

        // 무효한 토큰 삭제
        if (invalidTokenRefs.length > 0) {
          const deleteBatch = admin.firestore().batch();
          invalidTokenRefs.forEach((ref) => {
            deleteBatch.delete(ref);
          });
          await deleteBatch.commit();
        }

        logger.info(`✅ 검사 완료 - 유효: ${validCount}개, 무효: ${invalidCount}개`);
        logger.info("=".repeat(60));

        return {
          success: true,
          validCount,
          invalidCount,
          deletedCount: invalidTokenRefs.length,
        };
      } catch (error) {
        logger.error("❌ 토큰 검사 실패:", error);
        throw new HttpsError(
            "internal",
            `토큰 검사 중 오류가 발생했습니다: ${error.message}`,
        );
      }
    },
);
