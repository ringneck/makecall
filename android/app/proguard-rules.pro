# Android 15 (SDK 35) 호환성 규칙
# 지원 중단된 API 경고 억제

# Keep deprecated API methods for compatibility
-dontwarn android.view.Window
-keep class android.view.Window {
    public void setStatusBarColor(int);
    public void setNavigationBarColor(int);
    public void setNavigationBarDividerColor(int);
}

# UCrop library compatibility
-dontwarn com.yalantis.ucrop.**
-keep class com.yalantis.ucrop.** { *; }

# Firebase compatibility
-dontwarn com.google.firebase.**
-keep class com.google.firebase.** { *; }
