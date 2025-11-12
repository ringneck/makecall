// ✅ dotenv를 사용하여 .env 파일 로드 (배포 시 필수)
require("dotenv").config();

const functions = require("firebase-functions");
const admin = require("firebase-admin");
const nodemailer = require("nodemailer");

// ✅ 마이그레이션: functions.config() → process.env (dotenv)
const gmailEmail = process.env.GMAIL_EMAIL;
const gmailPassword = process.env.GMAIL_PASSWORD;

// 환경 변수 검증 (배포 시 오류 방지)
if (!gmailEmail || !gmailPassword) {
  throw new Error(
      "❌ Gmail 환경 변수가 설정되지 않았습니다. " +
    "functions/.env 파일에 GMAIL_EMAIL과 GMAIL_PASSWORD를 설정하세요.",
  );
}

admin.initializeApp();

const transporter = nodemailer.createTransport({
  service: "gmail",
  auth: {
    user: gmailEmail,
    pass: gmailPassword,
  },
});

/**
 * 이메일 인증 코드 전송 Cloud Function
 *
 * Firestore 'email_verification_requests' 컬렉션에 새 문서가 생성되면
 * 자동으로 이메일을 전송합니다.
 */
exports.sendVerificationEmail = functions.firestore
    .document("email_verification_requests/{requestId}")
    .onCreate(async (snap, context) => {
      try {
        const requestId = context.params.requestId;
        const data = snap.data();

        const userId = data.userId;
        const code = data.code;
        // const createdAt = data.createdAt; // 현재 미사용

        console.log(`📧 이메일 인증 요청 수신: ${requestId}`);
        console.log(`   User ID: ${userId}`);
        console.log(`   인증 코드: ${code}`);

        // Firestore에서 사용자 이메일 가져오기
        const userDoc = await admin.firestore().collection("users").doc(userId).get();

        if (!userDoc.exists) {
          console.error(`❌ 사용자 문서 없음: ${userId}`);
          return;
        }

        const userData = userDoc.data();
        const userEmail = userData.email;

        if (!userEmail) {
          console.error(`❌ 사용자 이메일 없음: ${userId}`);
          return;
        }

        console.log(`   받는 사람: ${userEmail}`);

        // 이메일 전송
        const mailOptions = {
          from: `MAKECALL <${gmailEmail}>`,
          to: userEmail,
          subject: "🔐 MAKECALL 새 기기 로그인 인증 코드",
          html: `
          <!DOCTYPE html>
          <html>
          <head>
            <meta charset="utf-8">
            <style>
              body { font-family: Arial, sans-serif; line-height: 1.6; color: #333; }
              .container { max-width: 600px; margin: 0 auto; padding: 20px; }
              .header {
                background: #2196F3;
                color: white;
                padding: 20px;
                text-align: center;
                border-radius: 8px 8px 0 0;
              }
              .content { padding: 30px; background: #f9f9f9; }
              .code-box { 
                background: white; 
                border: 2px solid #2196F3; 
                padding: 20px; 
                text-align: center; 
                margin: 20px 0;
                border-radius: 8px;
              }
              .code { 
                font-size: 32px; 
                font-weight: bold; 
                letter-spacing: 8px; 
                color: #2196F3; 
              }
              .footer { padding: 20px; text-align: center; color: #666; font-size: 12px; }
              .warning {
                background: #fff3cd;
                border: 1px solid #ffc107;
                padding: 15px;
                margin: 15px 0;
                border-radius: 8px;
              }
            </style>
          </head>
          <body>
            <div class="container">
              <div class="header">
                <h1>🔐 새 기기 로그인 인증</h1>
              </div>
              
              <div class="content">
                <p>안녕하세요,</p>
                <p>새 기기에서 로그인을 시도하고 있습니다. 본인이 맞다면 아래 인증 코드를 입력하세요.</p>
                
                <div class="code-box">
                  <p style="margin: 0; font-size: 14px; color: #666;">인증 코드</p>
                  <div class="code">${code}</div>
                </div>
                
                <div class="warning">
                  <strong>⚠️ 주의사항:</strong>
                  <ul style="margin: 10px 0;">
                    <li>이 코드는 <strong>5분간</strong> 유효합니다.</li>
                    <li>본인이 아닌 경우 이 이메일을 무시하세요.</li>
                    <li>MAKECALL은 절대 이메일로 비밀번호를 요청하지 않습니다.</li>
                  </ul>
                </div>
                
                <p style="margin-top: 20px; color: #666;">
                  문제가 있으신가요? help@makecall.io로 문의하세요.
                </p>
              </div>
              
              <div class="footer">
                <p>© 2024 MAKECALL. All rights reserved.</p>
                <p>이 이메일은 MAKECALL 새 기기 로그인 인증을 위해 자동으로 발송되었습니다.</p>
              </div>
            </div>
          </body>
          </html>
        `,
          text: `
MAKECALL 새 기기 로그인 인증 코드

인증 코드: ${code}

이 코드는 5분간 유효합니다.
본인이 아닌 경우 이 이메일을 무시하세요.

문의: help@makecall.io
        `.trim(),
        };

        await transporter.sendMail(mailOptions);

        console.log(`✅ 이메일 전송 완료: ${userEmail}`);

        // 전송 완료 표시 (선택사항)
        await snap.ref.update({
          emailSent: true,
          emailSentAt: admin.firestore.FieldValue.serverTimestamp(),
        });
      } catch (error) {
        console.error("❌ 이메일 전송 오류:", error);
        throw error;
      }
    });

/**
 * FCM 기기 승인 알림 전송 Cloud Function
 *
 * Firestore 'fcm_approval_notification_queue' 컬렉션에 새 문서가 생성되면
 * 자동으로 FCM 푸시 알림을 전송합니다.
 */
exports.sendApprovalNotification = functions.firestore
    .document("fcm_approval_notification_queue/{queueId}")
    .onCreate(async (snap, context) => {
      try {
        const queueId = context.params.queueId;
        const data = snap.data();

        const targetToken = data.targetToken;
        const message = data.message;
        const approvalRequestId = data.approvalRequestId;
        const newDeviceName = data.newDeviceName;
        const newPlatform = data.newPlatform;

        console.log(`🔔 FCM 승인 알림 요청 수신: ${queueId}`);
        console.log(`   Target Token: ${targetToken.substring(0, 20)}...`);
        console.log(`   New Device: ${newDeviceName} (${newPlatform})`);

        // FCM 푸시 알림 전송
        const fcmMessage = {
          token: targetToken,
          notification: {
            title: message.title,
            body: message.body,
          },
          data: {
            type: message.type,
            approvalRequestId: approvalRequestId,
            newDeviceName: newDeviceName,
            newPlatform: newPlatform,
          },
          android: {
            priority: "high",
            notification: {
              channelId: "high_importance_channel",
              priority: "high",
              sound: "default",
            },
          },
          apns: {
            payload: {
              aps: {
                sound: "default",
                contentAvailable: true,
              },
            },
          },
        };

        await admin.messaging().send(fcmMessage);

        console.log(`✅ FCM 알림 전송 완료: ${targetToken.substring(0, 20)}...`);

        // 처리 완료 표시
        await snap.ref.update({
          processed: true,
          processedAt: admin.firestore.FieldValue.serverTimestamp(),
        });
      } catch (error) {
        console.error("❌ FCM 알림 전송 오류:", error);

        // data 객체 가져오기 (catch 블록에서 접근)
        const data = snap.data();
        const targetToken = data.targetToken;

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

        // 오류 정보 저장
        await snap.ref.update({
          processed: false,
          error: error.message,
          errorCode: error.code || "unknown",
          errorAt: admin.firestore.FieldValue.serverTimestamp(),
        });
      }
    });

/**
 * 만료된 인증 요청 정리 Cloud Function (스케줄링)
 *
 * 매시간 실행되어 5분 이상 경과한 미처리 인증 요청을 삭제합니다.
 */
exports.cleanupExpiredRequests = functions.pubsub
    .schedule("every 1 hours")
    .onRun(async (context) => {
      try {
        console.log("🧹 만료된 인증 요청 정리 시작");

        const now = admin.firestore.Timestamp.now();
        const fiveMinutesAgo = new Date(now.toDate().getTime() - 5 * 60 * 1000);

        // 만료된 이메일 인증 요청 삭제
        const expiredEmailRequests = await admin.firestore()
            .collection("email_verification_requests")
            .where("createdAt", "<", fiveMinutesAgo)
            .where("used", "==", false)
            .get();

        const emailBatch = admin.firestore().batch();
        expiredEmailRequests.docs.forEach((doc) => {
          emailBatch.delete(doc.ref);
        });
        await emailBatch.commit();

        console.log(`✅ 만료된 이메일 인증 요청 ${expiredEmailRequests.size}개 삭제`);

        // 만료된 기기 승인 요청 정리
        const expiredApprovalRequests = await admin.firestore()
            .collection("device_approval_requests")
            .where("expiresAt", "<", now)
            .where("status", "==", "pending")
            .get();

        const approvalBatch = admin.firestore().batch();
        expiredApprovalRequests.docs.forEach((doc) => {
          approvalBatch.update(doc.ref, {status: "expired"});
        });
        await approvalBatch.commit();

        console.log(`✅ 만료된 기기 승인 요청 ${expiredApprovalRequests.size}개 업데이트`);
      } catch (error) {
        console.error("❌ 정리 작업 오류:", error);
      }
    });

/**
 * FCM 수신전화 푸시 알림 전송 Cloud Function
 *
 * HTTP POST 요청으로 호출됩니다.
 * DCMIWS에서 Newchannel 이벤트 발생 시 호출하여 FCM 푸시를 전송합니다.
 *
 * Request Body:
 * {
 *   "callerNumber": "16682471",
 *   "callerName": "얼쑤팩토리",
 *   "receiverNumber": "07045144801",
 *   "linkedid": "1762843210.1787",
 *   "channel": "PJSIP/DKCT-00000460",
 *   "callType": "external"
 * }
 */
exports.sendIncomingCallNotification = functions.https.onRequest(
    async (req, res) => {
      // CORS 헤더 설정 (Flutter 앱에서 호출 가능하도록)
      res.set("Access-Control-Allow-Origin", "*");
      res.set("Access-Control-Allow-Methods", "POST");
      res.set("Access-Control-Allow-Headers", "Content-Type");

      // OPTIONS 요청 처리 (CORS preflight)
      if (req.method === "OPTIONS") {
        res.status(204).send("");
        return;
      }

      // POST 요청만 허용
      if (req.method !== "POST") {
        res.status(405).json({error: "Method Not Allowed"});
        return;
      }

      try {
        const {
          callerNumber,
          callerName,
          receiverNumber,
          linkedid,
          channel,
          callType,
        } = req.body;

        console.log("📞 [FCM-INCOMING] 수신전화 FCM 요청 수신");
        console.log(`   발신번호: ${callerNumber}`);
        console.log(`   발신자: ${callerName}`);
        console.log(`   수신번호: ${receiverNumber}`);
        console.log(`   Linkedid: ${linkedid}`);
        console.log(`   통화타입: ${callType}`);

        // 필수 파라미터 검증
        if (!callerNumber || !receiverNumber || !linkedid) {
          console.error("❌ [FCM-INCOMING] 필수 파라미터 누락");
          res.status(400).json({
            error: "Missing required parameters",
            required: ["callerNumber", "receiverNumber", "linkedid"],
          });
          return;
        }

        // 1. receiverNumber로 my_extensions 조회 → userId 찾기
        console.log("🔍 [FCM-INCOMING] my_extensions 조회 중...");

        // 외부 수신: accountCode로 조회
        let extensionSnapshot = await admin.firestore()
            .collection("my_extensions")
            .where("accountCode", "==", receiverNumber)
            .limit(1)
            .get();

        // 내부 수신: extension으로 조회
        if (extensionSnapshot.empty) {
          extensionSnapshot = await admin.firestore()
              .collection("my_extensions")
              .where("extension", "==", receiverNumber)
              .limit(1)
              .get();
        }

        if (extensionSnapshot.empty) {
          console.error(`❌ [FCM-INCOMING] 내선번호 없음: ${receiverNumber}`);
          res.status(404).json({
            error: "Extension not found",
            receiverNumber: receiverNumber,
          });
          return;
        }

        const userId = extensionSnapshot.docs[0].data().userId;
        const extensionUsed = extensionSnapshot.docs[0].data().extension;

        console.log(`✅ [FCM-INCOMING] userId 확인: ${userId}`);
        console.log(`   내선번호: ${extensionUsed}`);

        // 2. 해당 사용자의 활성 FCM 토큰 조회
        console.log("🔍 [FCM-INCOMING] FCM 토큰 조회 중...");

        const tokensSnapshot = await admin.firestore()
            .collection("fcm_tokens")
            .where("userId", "==", userId)
            .where("isActive", "==", true)
            .get();

        if (tokensSnapshot.empty) {
          console.error(`❌ [FCM-INCOMING] 활성 FCM 토큰 없음: ${userId}`);
          res.status(404).json({
            error: "No active FCM tokens",
            userId: userId,
          });
          return;
        }

        const tokens = tokensSnapshot.docs.map((doc) => doc.data().fcmToken);

        console.log(`✅ [FCM-INCOMING] FCM 토큰 ${tokens.length}개 발견`);

        // 3. Firestore call_history 컬렉션에 통화 기록 생성
        console.log("💾 [FCM-INCOMING] call_history 생성 중...");

        const callHistoryRef = admin.firestore()
            .collection("call_history")
            .doc(linkedid);

        // 기존 통화 기록 확인 (중복 방지)
        const existingHistory = await callHistoryRef.get();

        if (existingHistory.exists) {
          console.log(`⚠️ [FCM-INCOMING] 이미 존재하는 linkedid: ${linkedid}`);
          console.log("   → FCM 푸시만 전송하고 통화 기록은 생성하지 않음");
        } else {
          // 새 통화 기록 생성
          await callHistoryRef.set({
            userId: userId,
            callerNumber: callerNumber,
            callerName: callerName || callerNumber,
            receiverNumber: receiverNumber,
            channel: channel || "",
            linkedid: linkedid,
            callType: "incoming",
            callSubType: callType || "external",
            status: "fcm_notification", // FCM으로 받은 알림
            extensionUsed: extensionUsed,
            timestamp: admin.firestore.FieldValue.serverTimestamp(),
            createdAt: admin.firestore.FieldValue.serverTimestamp(),
          });

          console.log(`✅ [FCM-INCOMING] call_history 생성 완료`);
          console.log(`   문서 ID: ${linkedid}`);
        }

        // 4. FCM 푸시 메시지 구성
        console.log("📤 [FCM-INCOMING] FCM 푸시 전송 중...");

        const message = {
          notification: {
            title: "수신전화",
            body: `${callerName || callerNumber}`,
          },
          data: {
            type: "incoming_call",
            caller_number: callerNumber,
            caller_name: callerName || callerNumber,
            receiver_number: receiverNumber,
            linkedid: linkedid,
            channel: channel || "",
            call_type: callType || "external",
            timestamp: new Date().toISOString(),
          },
          android: {
            priority: "high",
            notification: {
              channelId: "incoming_call_channel",
              sound: "default",
              priority: "high",
            },
          },
          apns: {
            payload: {
              aps: {
                sound: "default",
                badge: 1,
              },
            },
          },
        };

        // 5. FCM 멀티캐스트 전송
        const response = await admin.messaging().sendEachForMulticast({
          tokens: tokens,
          ...message,
        });

        console.log(`✅ [FCM-INCOMING] FCM 전송 완료`);
        console.log(`   성공: ${response.successCount}/${tokens.length}`);

        if (response.failureCount > 0) {
          console.error(`⚠️ [FCM-INCOMING] 실패: ${response.failureCount}개`);
          response.responses.forEach((resp, idx) => {
            if (!resp.success) {
              console.error(`   토큰 ${idx + 1}: ${resp.error}`);
            }
          });
        }

        res.status(200).json({
          success: true,
          linkedid: linkedid,
          userId: userId,
          sentCount: response.successCount,
          failureCount: response.failureCount,
          totalTokens: tokens.length,
          callHistoryCreated: !existingHistory.exists,
        });
      } catch (error) {
        console.error("❌ [FCM-INCOMING] FCM 전송 오류:", error);
        res.status(500).json({
          error: error.message,
          stack: error.stack,
        });
      }
    },
);
