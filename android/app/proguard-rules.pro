# ============================================================
# Android 15 (SDK 35+) 호환성 규칙
# 외부 라이브러리의 지원 중단된 API 사용 경고 억제
# ============================================================

# 지원 중단된 Window API 메서드 유지 (외부 라이브러리 호환성)
-dontwarn android.view.Window
-keep class android.view.Window {
    public void setStatusBarColor(int);
    public void setNavigationBarColor(int);
    public void setNavigationBarDividerColor(int);
}

# ============================================================
# UCrop 라이브러리 호환성 (image_cropper 플러그인)
# setStatusBarColor 사용으로 인한 경고 억제
# ============================================================
-dontwarn com.yalantis.ucrop.**
-keep class com.yalantis.ucrop.** { *; }
-keep class com.yalantis.ucrop.UCrop { *; }
-keep class com.yalantis.ucrop.UCrop$Options { *; }
-keep class com.yalantis.ucrop.UCropActivity { *; }

# UCrop의 지원 중단된 API 호출 억제
-dontnote com.yalantis.ucrop.UCropActivity
-dontnote com.yalantis.ucrop.UCrop$Options

# ============================================================
# reCAPTCHA 호환성
# ============================================================
-dontwarn com.google.android.recaptcha.**
-keep class com.google.android.recaptcha.** { *; }
-dontnote com.google.android.recaptcha.**

# ============================================================
# Firebase 호환성
# ============================================================
-dontwarn com.google.firebase.**
-keep class com.google.firebase.** { *; }
-dontnote com.google.firebase.**

# ============================================================
# Flutter 플랫폼 채널 호환성
# ============================================================
-dontwarn io.flutter.plugin.platform.**
-keep class io.flutter.plugin.platform.** { *; }
-dontnote io.flutter.plugin.platform.**

# ============================================================
# 일반 지원 중단 API 경고 억제
# ============================================================
-dontwarn android.app.Notification
-dontwarn android.support.**
-dontwarn androidx.core.app.NotificationCompat$*

# R8 최적화 설정
-optimizations !code/simplification/arithmetic,!code/simplification/cast,!field/*,!class/merging/*
-optimizationpasses 5
-allowaccessmodification
-dontpreverify

# 난독화 유지 (디버깅 가능)
-keepattributes *Annotation*
-keepattributes SourceFile,LineNumberTable
-keepattributes Signature
-keepattributes Exceptions
