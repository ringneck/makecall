package com.olssoo.makecall_app

import android.content.pm.PackageInfo
import android.content.pm.PackageManager
import android.content.pm.Signature
import android.os.Build
import android.os.Bundle
import android.util.Base64
import android.util.Log
import io.flutter.embedding.android.FlutterActivity
import java.security.MessageDigest
import androidx.core.view.WindowCompat

class MainActivity : FlutterActivity() {
    
    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        
        // ✅ Google Play Store 권장사항: Edge-to-Edge 지원 (Android 15+)
        // WindowCompat.setDecorFitsSystemWindows(false)를 호출하여
        // 시스템 바 뒤로 콘텐츠가 확장되도록 설정
        // Flutter의 SafeArea와 함께 사용하여 인셋 처리
        WindowCompat.setDecorFitsSystemWindows(window, false)
        
        super.onCreate(savedInstanceState)
        
        // 카카오 로그인용 키 해시 출력
        printKakaoKeyHash()
    }
    
    /**
     * 카카오 Key Hash 추출 및 출력
     * Android API 28+ 호환 (GET_SIGNING_CERTIFICATES 사용)
     */
    private fun printKakaoKeyHash() {
        try {
            // 🔧 Android API 레벨에 따라 다른 방식 사용
            val signatures: Array<Signature> = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.P) {
                // Android 9 (API 28) 이상: GET_SIGNING_CERTIFICATES 사용
                val packageInfo = packageManager.getPackageInfo(
                    packageName,
                    PackageManager.GET_SIGNING_CERTIFICATES
                )
                packageInfo.signingInfo?.let { signingInfo ->
                    if (signingInfo.hasMultipleSigners()) {
                        // 다중 서명자가 있는 경우
                        signingInfo.apkContentsSigners
                    } else {
                        // 단일 서명자
                        signingInfo.signingCertificateHistory
                    }
                } ?: emptyArray()
            } else {
                // Android 8.1 (API 27) 이하: GET_SIGNATURES 사용 (deprecated)
                @Suppress("DEPRECATION")
                val packageInfo = packageManager.getPackageInfo(
                    packageName,
                    PackageManager.GET_SIGNATURES
                )
                @Suppress("DEPRECATION")
                packageInfo.signatures ?: emptyArray()
            }
            
            // 서명 정보가 있는 경우 Key Hash 생성
            if (signatures.isNotEmpty()) {
                Log.i("KAKAO_KEY_HASH", "========================================")
                Log.i("KAKAO_KEY_HASH", "📱 Kakao Android Key Hash")
                Log.i("KAKAO_KEY_HASH", "========================================")
                Log.i("KAKAO_KEY_HASH", "Package: $packageName")
                Log.i("KAKAO_KEY_HASH", "Android Version: ${Build.VERSION.SDK_INT}")
                Log.i("KAKAO_KEY_HASH", "========================================")
                
                signatures.forEachIndexed { index, signature ->
                    val md = MessageDigest.getInstance("SHA")
                    md.update(signature.toByteArray())
                    val keyHash = Base64.encodeToString(md.digest(), Base64.NO_WRAP)
                    
                    Log.i("KAKAO_KEY_HASH", "Key Hash #${index + 1}: $keyHash")
                    println("🔑 [KAKAO] Key Hash #${index + 1}: $keyHash")
                }
                
                Log.i("KAKAO_KEY_HASH", "========================================")
                Log.i("KAKAO_KEY_HASH", "🔗 등록 방법:")
                Log.i("KAKAO_KEY_HASH", "1. https://developers.kakao.com 접속")
                Log.i("KAKAO_KEY_HASH", "2. 내 애플리케이션 > 앱 설정 > 플랫폼")
                Log.i("KAKAO_KEY_HASH", "3. Android 플랫폼 > 키 해시 등록")
                Log.i("KAKAO_KEY_HASH", "4. 위의 Key Hash 값을 복사하여 등록")
                Log.i("KAKAO_KEY_HASH", "   (여러 개가 있으면 모두 등록)")
                Log.i("KAKAO_KEY_HASH", "========================================")
                
                println("🔗 [KAKAO] 카카오 개발자 콘솔에 위 Key Hash를 등록하세요!")
            } else {
                Log.w("KAKAO_KEY_HASH", "⚠️ No signatures found")
                Log.w("KAKAO_KEY_HASH", "Package: $packageName")
                Log.w("KAKAO_KEY_HASH", "Android Version: ${Build.VERSION.SDK_INT}")
                println("⚠️ [KAKAO] 서명 정보를 찾을 수 없습니다")
            }
        } catch (e: Exception) {
            Log.e("KAKAO_KEY_HASH", "❌ Error getting key hash", e)
            Log.e("KAKAO_KEY_HASH", "Package: $packageName")
            Log.e("KAKAO_KEY_HASH", "Android Version: ${Build.VERSION.SDK_INT}")
            Log.e("KAKAO_KEY_HASH", "Error message: ${e.message}")
            println("❌ [KAKAO] Key Hash 추출 실패: ${e.message}")
        }
    }
}
