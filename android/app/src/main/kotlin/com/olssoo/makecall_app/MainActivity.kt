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
                    Log.d("KAKAO_KEY_HASH", "Key Hash: $keyHash")
                    println("🔑 [KAKAO] Key Hash: $keyHash")
                }
            } ?: run {
                Log.w("KAKAO_KEY_HASH", "No signatures found")
            }
        } catch (e: Exception) {
            Log.e("KAKAO_KEY_HASH", "Error getting key hash", e)
        }
    }
}
