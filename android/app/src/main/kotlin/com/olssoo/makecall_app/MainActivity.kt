package com.olssoo.makecall_app

import android.content.pm.PackageManager
import android.os.Bundle
import android.util.Base64
import android.util.Log
import android.webkit.CookieManager
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import java.security.MessageDigest

class MainActivity : FlutterActivity() {
    private val CHANNEL = "com.olssoo.makecall_app/webview"
    
    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        
        // 카카오 로그인용 키 해시 출력
        printKakaoKeyHash()
    }
    
    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        
        // Flutter와 네이티브 통신 채널 설정
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL).setMethodCallHandler { call, result ->
            when (call.method) {
                "clearNaverCookies" -> {
                    try {
                        val success = clearNaverWebViewCookies()
                        result.success(success)
                    } catch (e: Exception) {
                        Log.e("NAVER_COOKIES", "Failed to clear cookies", e)
                        result.success(false)
                    }
                }
                else -> {
                    result.notImplemented()
                }
            }
        }
    }
    
    /**
     * 네이버 도메인 관련 WebView 쿠키 삭제
     * 
     * 무한 동의 화면 방지를 위해 네이버 로그인 관련 쿠키를 삭제합니다.
     * Android WebView의 CookieManager를 사용하여 전역 쿠키를 삭제합니다.
     */
    private fun clearNaverWebViewCookies(): Boolean {
        return try {
            val cookieManager = CookieManager.getInstance()
            
            Log.d("NAVER_COOKIES", "🧹 Clearing ALL WebView cookies and data...")
            
            // 🔥 CRITICAL FIX: 모든 쿠키 삭제 (도메인별이 아닌 전체)
            cookieManager.removeAllCookies { success ->
                if (success) {
                    Log.d("NAVER_COOKIES", "   ✅ All cookies removed")
                } else {
                    Log.d("NAVER_COOKIES", "   ⚠️ Failed to remove all cookies")
                }
            }
            
            // WebView 캐시 및 저장소 삭제
            try {
                val webViewDir = applicationContext.getDir("webview", MODE_PRIVATE)
                if (webViewDir.exists()) {
                    webViewDir.deleteRecursively()
                    Log.d("NAVER_COOKIES", "   ✅ WebView directory deleted")
                }
            } catch (e: Exception) {
                Log.w("NAVER_COOKIES", "   ⚠️ Failed to delete WebView dir: ${e.message}")
            }
            
            // 쿠키 즉시 적용
            cookieManager.flush()
            
            // SharedPreferences에서 네이버 관련 데이터 삭제
            try {
                val prefs = applicationContext.getSharedPreferences("NaverIdLogin", MODE_PRIVATE)
                prefs.edit().clear().apply()
                Log.d("NAVER_COOKIES", "   ✅ NaverIdLogin SharedPreferences cleared")
            } catch (e: Exception) {
                Log.w("NAVER_COOKIES", "   ⚠️ Failed to clear preferences: ${e.message}")
            }
            
            Log.d("NAVER_COOKIES", "✅ Complete cleanup finished")
            
            true
        } catch (e: Exception) {
            Log.e("NAVER_COOKIES", "❌ Failed to clear Naver data: ${e.message}", e)
            false
        }
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
