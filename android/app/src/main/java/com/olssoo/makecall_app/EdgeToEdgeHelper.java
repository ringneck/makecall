package com.olssoo.makecall_app;

import android.app.Activity;
import android.util.Log;
import androidx.activity.ComponentActivity;

/**
 * EdgeToEdge Helper for Google Play Console detection
 * 
 * This Java class directly calls androidx.activity.EdgeToEdge.enable()
 * which allows Google Play Console's static analysis to detect the API call.
 */
public class EdgeToEdgeHelper {
    
    private static final String TAG = "EdgeToEdgeHelper";
    
    /**
     * Enable edge-to-edge display for the given activity
     * 
     * @param activity The activity to enable edge-to-edge for (will be cast to ComponentActivity)
     * @return true if successful, false if EdgeToEdge API is not available
     */
    public static boolean enable(Activity activity) {
        try {
            // Try to cast to ComponentActivity
            if (activity instanceof ComponentActivity) {
                ComponentActivity componentActivity = (ComponentActivity) activity;
                
                // Direct call to EdgeToEdge.enable()
                // Google Play Console can detect this static call
                androidx.activity.EdgeToEdge.enable(componentActivity);
                
                Log.i(TAG, "✅ EdgeToEdge.enable() called successfully");
                return true;
            } else {
                Log.w(TAG, "⚠️ Activity is not a ComponentActivity - using fallback");
                return false;
            }
            
        } catch (NoClassDefFoundError e) {
            Log.w(TAG, "⚠️ EdgeToEdge class not available - using fallback");
            return false;
            
        } catch (Exception e) {
            Log.e(TAG, "❌ Failed to enable EdgeToEdge", e);
            return false;
        }
    }
}
