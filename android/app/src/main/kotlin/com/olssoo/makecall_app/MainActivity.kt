package com.olssoo.makecall_app

import android.content.pm.PackageManager
import android.os.Bundle
import android.util.Base64
import android.util.Log
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import com.nhn.android.naverlogin.OAuthLogin
import java.security.MessageDigest

class MainActivity : FlutterActivity() {
    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        
        // 카카오 로그인용 키 해시 출력
        printKakaoKeyHash()
        
        // 네이버 로그인 초기화
        initNaverLogin()
    }
    
    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        
        // 네이버 로그인 초기화 (Flutter Engine 준비 후)
        initNaverLogin()
    }
    
    private fun initNaverLogin() {
        try {
            val context = applicationContext
            val clientId = context.getString(R.string.naver_client_id)
            val clientSecret = context.getString(R.string.naver_client_secret)
            val clientName = context.getString(R.string.naver_client_name)
            
            println("=== Naver Login Initialization ===")
            println("ClientID: $clientId")
            println("ClientSecret: $clientSecret")
            println("ClientName: $clientName")
            println("===================================")
            
            // 네이버 로그인 인스턴스 초기화
            val mOAuthLoginInstance = OAuthLogin.getInstance()
            mOAuthLoginInstance.init(
                context,
                clientId,
                clientSecret,
                clientName
            )
            
            Log.d("NAVER_LOGIN", "Naver Login initialized successfully")
            println("✅ [NAVER] Login initialized successfully")
        } catch (e: Exception) {
            Log.e("NAVER_LOGIN", "Error initializing Naver Login", e)
            println("❌ [NAVER] Error: ${e.message}")
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
