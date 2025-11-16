package com.olssoo.makecall_app

import io.flutter.embedding.android.FlutterActivity
import android.os.Bundle
import com.google.firebase.firestore.FirebaseFirestore
import com.google.firebase.firestore.FirebaseFirestoreSettings

class MainActivity : FlutterActivity() {
    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        
        // Firestore 로그 레벨 조정 (PERMISSION_DENIED 경고 억제)
        try {
            val firestore = FirebaseFirestore.getInstance()
            val settings = FirebaseFirestoreSettings.Builder()
                .build()
            firestore.firestoreSettings = settings
            
            // Firestore 로깅 비활성화 (권한 에러 로그 억제)
            FirebaseFirestore.setLoggingEnabled(false)
        } catch (e: Exception) {
            // Firestore 초기화 실패는 무시 (앱 실행에는 영향 없음)
        }
    }
}
