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
        
        // ========================================
        // ✅ CRITICAL: Android 15 Edge-to-Edge 지원
        // ========================================
        // Google Play Console 권장사항 완벽 준수:
        // "SDK 35를 타겟팅하는 앱은 Android 15 이상에서 
        //  앱이 올바르게 표시되도록 인셋을 처리해야 합니다."
        //
        // 1. EdgeToEdge.enable() - Google Play가 정적 분석으로 감지
        // 2. WindowCompat.setDecorFitsSystemWindows(false) - 시스템 바 뒤로 확장
        // 3. Display Cutout Mode 설정 - Android 15 권장 API 사용
        // 4. Flutter 앱에서 SafeArea와 MediaQuery.padding으로 인셋 처리
        // ========================================
        
        // ✅ METHOD 1: Java helper를 통한 EdgeToEdge.enable() 호출
        // Google Play Console의 정적 분석이 직접 감지 가능
        val edgeToEdgeEnabled = EdgeToEdgeHelper.enable(this)
        
        if (edgeToEdgeEnabled) {
            Log.i("MainActivity", "✅ EdgeToEdge.enable() 호출 성공 - Android 15 지원 완료")
        } else {
            Log.w("MainActivity", "⚠️ EdgeToEdge.enable() 실패 - WindowCompat 폴백 사용")
        }
        
        // ✅ METHOD 2: WindowCompat을 통한 추가 안전망
        // 시스템 바(상태바, 네비게이션 바) 뒤로 콘텐츠 확장 허용
        // false = 시스템이 자동으로 padding 추가하지 않음 (Flutter가 직접 처리)
        WindowCompat.setDecorFitsSystemWindows(window, false)
        Log.i("MainActivity", "✅ WindowCompat.setDecorFitsSystemWindows(false) 설정 완료")
        
        // ========================================
        // ✅ METHOD 3: Display Cutout Mode 명시적 설정 (Android 15 권장)
        // ========================================
        // Google Play Console 경고 해결:
        // "LAYOUT_IN_DISPLAY_CUTOUT_MODE_SHORT_EDGES는 Android 15에서 지원 중단"
        //
        // ❌ 지원 중단: LAYOUT_IN_DISPLAY_CUTOUT_MODE_SHORT_EDGES (1)
        // ✅ Android 15 권장: LAYOUT_IN_DISPLAY_CUTOUT_MODE_ALWAYS (3)
        //
        // Android P (API 28) 이상에서만 사용 가능
        // ========================================
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.P) {
            try {
                // ✅ LAYOUT_IN_DISPLAY_CUTOUT_MODE_ALWAYS 사용
                // 노치/펀치홀 영역까지 콘텐츠 확장 (권장)
                window.attributes.layoutInDisplayCutoutMode = 
                    android.view.WindowManager.LayoutParams.LAYOUT_IN_DISPLAY_CUTOUT_MODE_ALWAYS
                
                Log.i("MainActivity", "✅ Display Cutout Mode: ALWAYS (Android 15 권장)")
                Log.i("MainActivity", "   → 노치/펀치홀 영역까지 콘텐츠 확장")
                Log.i("MainActivity", "   → shortEdges 지원 중단 경고 해결")
            } catch (e: Exception) {
                Log.e("MainActivity", "❌ Display Cutout Mode 설정 실패", e)
            }
        } else {
            Log.i("MainActivity", "ℹ️ Display Cutout Mode: Android P 미만 버전 - 설정 건너뜀")
        }
        
        // ========================================
        // ℹ️ 참고사항:
        // - Android 15 (API 35) 이상에서는 기본적으로 Edge-to-Edge 모드 활성화
        // - Flutter 앱의 SafeArea 위젯이 자동으로 시스템 인셋 처리
        // - MediaQuery.of(context).padding을 사용하여 상태바/네비게이션바 높이 확인 가능
        // - Display Cutout Mode는 노치/펀치홀이 있는 기기에서 중요
        // ========================================
        
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
