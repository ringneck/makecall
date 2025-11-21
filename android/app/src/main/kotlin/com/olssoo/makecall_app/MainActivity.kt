package com.olssoo.makecall_app

import android.content.pm.PackageManager
import android.os.Bundle
import android.util.Base64
import android.util.Log
import io.flutter.embedding.android.FlutterActivity
import java.security.MessageDigest

class MainActivity : FlutterActivity() {
    
    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        
        // 카카오 로그인용 키 해시 출력
        printKakaoKeyHash()
    }
    
    private fun printKakaoKeyHash() {
        try {
            val info = packageManager.getPackageInfo(
                packageName,
                PackageManager.GET_SIGNATURES
            )
            
            // ✅ Null-safe 처리
            info.signatures?.let { signatures ->
                for (signature in signatures) {
                    val md = MessageDigest.getInstance("SHA")
                    md.update(signature.toByteArray())
                    val keyHash = Base64.encodeToString(md.digest(), Base64.NO_WRAP)
                    
                    // 🔑 카카오 Key Hash 출력 (개발자 콘솔 등록용)
                    Log.i("KAKAO_KEY_HASH", "========================================")
                    Log.i("KAKAO_KEY_HASH", "📱 Kakao Android Key Hash")
                    Log.i("KAKAO_KEY_HASH", "========================================")
                    Log.i("KAKAO_KEY_HASH", "Key Hash: $keyHash")
                    Log.i("KAKAO_KEY_HASH", "========================================")
                    Log.i("KAKAO_KEY_HASH", "🔗 등록 방법:")
                    Log.i("KAKAO_KEY_HASH", "1. https://developers.kakao.com 접속")
                    Log.i("KAKAO_KEY_HASH", "2. 내 애플리케이션 > 앱 설정 > 플랫폼")
                    Log.i("KAKAO_KEY_HASH", "3. Android 플랫폼 > 키 해시 등록")
                    Log.i("KAKAO_KEY_HASH", "4. 위의 Key Hash 값을 복사하여 등록")
                    Log.i("KAKAO_KEY_HASH", "========================================")
                    
                    println("🔑 [KAKAO] Key Hash: $keyHash")
                    println("🔗 [KAKAO] 카카오 개발자 콘솔에 위 Key Hash를 등록하세요!")
                }
            } ?: run {
                Log.w("KAKAO_KEY_HASH", "No signatures found")
            }
        } catch (e: Exception) {
            Log.e("KAKAO_KEY_HASH", "Error getting key hash", e)
        }
    }
}
