package com.olssoo.makecall_app;

import android.app.Activity;
import android.util.Log;
import androidx.activity.ComponentActivity;

/**
 * ========================================
 * EdgeToEdge Helper for Android 15 Support
 * ========================================
 * 
 * Google Play Console 권장사항 완벽 준수:
 * "SDK 35를 타겟팅하는 앱은 Android 15 이상에서 
 *  앱이 올바르게 표시되도록 인셋을 처리해야 합니다."
 * 
 * 이 Java 클래스는 androidx.activity.EdgeToEdge.enable()을 
 * 직접 호출하여 Google Play Console의 정적 분석이 
 * API 호출을 명확하게 감지할 수 있도록 합니다.
 * 
 * ========================================
 * 작동 원리:
 * ========================================
 * 1. MainActivity.kt에서 EdgeToEdgeHelper.enable() 호출
 * 2. 이 클래스가 androidx.activity.EdgeToEdge.enable() 실행
 * 3. Google Play Console이 정적 분석으로 API 호출 확인
 * 4. 시스템 바(상태바, 네비게이션바) 뒤로 콘텐츠 확장
 * 5. Flutter의 SafeArea가 자동으로 인셋 처리
 * 
 * ========================================
 * 참고사항:
 * ========================================
 * - Android 15 (API 35)부터 필수
 * - FlutterActivity는 ComponentActivity를 상속
 * - 실패 시 WindowCompat 폴백 사용
 * ========================================
 */
public class EdgeToEdgeHelper {
    
    private static final String TAG = "EdgeToEdgeHelper";
    
    /**
     * Enable edge-to-edge display for the given activity
     * 
     * ✅ CRITICAL: Google Play Console 권장사항 핵심 구현
     * 
     * Android 15 (SDK 35)에서 더 넓은 화면 지원을 위해
     * androidx.activity.EdgeToEdge.enable()을 직접 호출합니다.
     * 
     * @param activity The activity to enable edge-to-edge for 
     *                 (FlutterActivity는 ComponentActivity를 상속)
     * @return true if successful, false if EdgeToEdge API is not available
     */
    public static boolean enable(Activity activity) {
        try {
            // FlutterActivity는 ComponentActivity를 상속하므로 캐스팅 가능
            if (activity instanceof ComponentActivity) {
                ComponentActivity componentActivity = (ComponentActivity) activity;
                
                // ========================================
                // ✅ CRITICAL: EdgeToEdge.enable() 직접 호출
                // ========================================
                // Google Play Console의 정적 분석이 이 호출을 감지하여
                // "Android 15 Edge-to-Edge 지원" 권장사항 해결
                // 
                // 내부적으로 다음을 수행:
                // 1. WindowCompat.setDecorFitsSystemWindows(window, false)
                // 2. 시스템 바 색상을 투명하게 설정
                // 3. 라이트/다크 모드에 따라 아이콘 색상 자동 조정
                // ========================================
                androidx.activity.EdgeToEdge.enable(componentActivity);
                
                Log.i(TAG, "✅ EdgeToEdge.enable() 호출 성공");
                Log.i(TAG, "   → Android 15 Edge-to-Edge 지원 활성화");
                Log.i(TAG, "   → 시스템 바 뒤로 콘텐츠 확장 허용");
                Log.i(TAG, "   → Flutter SafeArea가 인셋 자동 처리");
                return true;
            } else {
                Log.w(TAG, "⚠️ Activity가 ComponentActivity가 아님");
                Log.w(TAG, "   → MainActivity.kt에서 WindowCompat 폴백 사용");
                return false;
            }
            
        } catch (NoClassDefFoundError e) {
            Log.w(TAG, "⚠️ EdgeToEdge 클래스를 찾을 수 없음");
            Log.w(TAG, "   → androidx.activity:activity 의존성 확인 필요");
            Log.w(TAG, "   → MainActivity.kt에서 WindowCompat 폴백 사용");
            return false;
            
        } catch (Exception e) {
            Log.e(TAG, "❌ EdgeToEdge.enable() 실행 실패", e);
            Log.e(TAG, "   → MainActivity.kt에서 WindowCompat 폴백 사용");
            return false;
        }
    }
}
