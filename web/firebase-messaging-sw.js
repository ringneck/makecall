// Firebase Cloud Messaging 서비스 워커
// 백그라운드 알림 수신을 위한 서비스 워커

importScripts('https://www.gstatic.com/firebasejs/10.7.0/firebase-app-compat.js');
importScripts('https://www.gstatic.com/firebasejs/10.7.0/firebase-messaging-compat.js');

// Firebase 설정 (firebase_options.dart의 web 설정과 동일)
const firebaseConfig = {
  apiKey: 'AIzaSyCB4mI5Kj61f6E532vg46GnmnnCfsI9XIM',
  appId: '1:793164633643:android:c2f267d67b908274ccfc6e',
  messagingSenderId: '793164633643',
  projectId: 'makecallio',
  authDomain: 'makecallio.firebaseapp.com',
  storageBucket: 'makecallio.firebasestorage.app',
};

// Firebase 초기화
firebase.initializeApp(firebaseConfig);

// Firebase Messaging 인스턴스 생성
const messaging = firebase.messaging();

// 백그라운드 메시지 핸들러
messaging.onBackgroundMessage((payload) => {
  console.log('[firebase-messaging-sw.js] 백그라운드 메시지 수신:', payload);

  const notificationTitle = payload.notification?.title || payload.data?.title || 'MakeCall 알림';
  const notificationOptions = {
    body: payload.notification?.body || payload.data?.body || '새로운 알림이 있습니다.',
    icon: payload.notification?.icon || payload.data?.icon || '/icons/Icon-192.png',
    badge: '/icons/Icon-192.png',
    tag: payload.data?.tag || 'makecall-notification',
    requireInteraction: true,
    data: payload.data,
    actions: [
      {
        action: 'open',
        title: '열기'
      },
      {
        action: 'close',
        title: '닫기'
      }
    ]
  };

  // 알림 표시
  return self.registration.showNotification(notificationTitle, notificationOptions);
});

// 알림 클릭 이벤트 핸들러
self.addEventListener('notificationclick', (event) => {
  console.log('[firebase-messaging-sw.js] 알림 클릭:', event);
  
  event.notification.close();

  if (event.action === 'close') {
    return;
  }

  // 앱 열기
  event.waitUntil(
    clients.matchAll({ type: 'window', includeUncontrolled: true })
      .then((clientList) => {
        // 이미 열린 창이 있으면 포커스
        for (const client of clientList) {
          if (client.url.includes(self.location.origin) && 'focus' in client) {
            return client.focus();
          }
        }
        // 열린 창이 없으면 새 창 열기
        if (clients.openWindow) {
          return clients.openWindow('/');
        }
      })
  );
});

// 서비스 워커 설치 이벤트
self.addEventListener('install', (event) => {
  console.log('[firebase-messaging-sw.js] 서비스 워커 설치됨');
  self.skipWaiting();
});

// 서비스 워커 활성화 이벤트
self.addEventListener('activate', (event) => {
  console.log('[firebase-messaging-sw.js] 서비스 워커 활성화됨');
  event.waitUntil(clients.claim());
});
