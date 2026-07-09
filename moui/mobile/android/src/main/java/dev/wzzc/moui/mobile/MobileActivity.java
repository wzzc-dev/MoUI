package dev.wzzc.moui.mobile;

import android.app.Activity;
import android.content.pm.ActivityInfo;
import android.content.pm.PackageManager;
import android.graphics.Color;
import android.os.Build;
import android.os.Bundle;
import android.util.Log;
import android.view.MotionEvent;
import android.view.Surface;
import android.view.SurfaceHolder;
import android.view.SurfaceView;
import android.view.View;
import android.view.Window;
import android.view.WindowManager;

public final class MobileActivity extends Activity implements SurfaceHolder.Callback {
    private static final String LOG_TAG = "MoUIMobile";
    private static final String META_NATIVE_LIBRARY = "dev.wzzc.moui.NATIVE_LIBRARY";
    private static final String META_SUPPORTS_SCROLL = "dev.wzzc.moui.SUPPORTS_SCROLL";
    private static final String META_FULLSCREEN = "dev.wzzc.moui.FULLSCREEN";

    private SurfaceView surfaceView;
    private boolean attached;
    private boolean supportsScroll;
    private boolean fullscreen;
    private boolean hasLastTouchPoint;
    private float lastTouchX;
    private float lastTouchY;

    private static native boolean nativeAttachSurface(Surface surface, int width, int height, double density);
    private static native boolean nativeResize(int width, int height, double density);
    private static native boolean nativeDispatchPointer(int phase, double x, double y, double timeMs);
    private static native boolean nativeDispatchScroll(double x, double y, double deltaX, double deltaY, int phase);
    private static native boolean nativeRenderFrame();
    private static native void nativeDetachSurface();

    @Override
    protected void onCreate(Bundle savedInstanceState) {
        super.onCreate(savedInstanceState);
        loadNativeLibraryFromManifest();
        supportsScroll = manifestBoolean(META_SUPPORTS_SCROLL, false);
        fullscreen = manifestBoolean(META_FULLSCREEN, false);
        if (fullscreen) {
            configureFullscreenWindow();
        }
        surfaceView = new SurfaceView(this);
        surfaceView.getHolder().addCallback(this);
        surfaceView.setFocusable(true);
        surfaceView.setFocusableInTouchMode(true);
        surfaceView.setOnTouchListener(new View.OnTouchListener() {
            @Override
            public boolean onTouch(View view, MotionEvent event) {
                if (!attached) {
                    return true;
                }
                dispatchMotionEvent(event);
                nativeRenderFrame();
                return true;
            }
        });
        setContentView(surfaceView);
    }

    @Override
    public void onWindowFocusChanged(boolean hasFocus) {
        super.onWindowFocusChanged(hasFocus);
        if (hasFocus && fullscreen) {
            configureFullscreenWindow();
        }
    }

    @Override
    protected void onDestroy() {
        nativeDetachSurface();
        attached = false;
        Log.i(LOG_TAG, "moui-mobile lifecycle detach reason=destroy");
        super.onDestroy();
    }

    @Override
    public void surfaceCreated(SurfaceHolder holder) {
        Surface surface = holder.getSurface();
        int width = Math.max(1, surfaceView.getWidth());
        int height = Math.max(1, surfaceView.getHeight());
        attached = nativeAttachSurface(surface, width, height, density());
        Log.i(LOG_TAG, "moui-mobile lifecycle attach width=" + width + " height=" + height + " attached=" + attached);
        nativeRenderFrame();
    }

    @Override
    public void surfaceChanged(SurfaceHolder holder, int format, int width, int height) {
        int surfaceWidth = Math.max(1, width);
        int surfaceHeight = Math.max(1, height);
        if (attached) {
            nativeResize(surfaceWidth, surfaceHeight, density());
            Log.i(LOG_TAG, "moui-mobile resize width=" + surfaceWidth + " height=" + surfaceHeight);
            nativeRenderFrame();
        }
    }

    @Override
    public void surfaceDestroyed(SurfaceHolder holder) {
        nativeDetachSurface();
        attached = false;
        Log.i(LOG_TAG, "moui-mobile lifecycle detach reason=surface-destroyed");
    }

    private void dispatchMotionEvent(MotionEvent event) {
        int action = event.getActionMasked();
        int phase = pointerPhase(action);
        int pointerIndex = event.getActionIndex();
        double timeMs = event.getEventTime();
        double x = event.getX(pointerIndex);
        double y = event.getY(pointerIndex);
        if (supportsScroll) {
            dispatchScrollPhase(phase, x, y);
        }
        nativeDispatchPointer(phase, x, y, timeMs);
        Log.i(LOG_TAG, "moui-mobile input pointer phase=" + phase + " x=" + x + " y=" + y);
    }

    private void dispatchScrollPhase(int phase, double x, double y) {
        if (phase == 0) {
            hasLastTouchPoint = true;
            lastTouchX = (float) x;
            lastTouchY = (float) y;
            nativeDispatchScroll(x, y, 0.0, 0.0, 0);
        } else if (phase == 1 && hasLastTouchPoint) {
            double deltaX = x - lastTouchX;
            double deltaY = y - lastTouchY;
            lastTouchX = (float) x;
            lastTouchY = (float) y;
            nativeDispatchScroll(x, y, deltaX, deltaY, 1);
            Log.i(LOG_TAG, "moui-mobile input scroll dx=" + deltaX + " dy=" + deltaY);
        } else if (phase == 2 || phase == 3) {
            nativeDispatchScroll(x, y, 0.0, 0.0, phase == 2 ? 2 : 3);
            hasLastTouchPoint = false;
        }
    }

    private static int pointerPhase(int action) {
        switch (action) {
            case MotionEvent.ACTION_DOWN:
            case MotionEvent.ACTION_POINTER_DOWN:
                return 0;
            case MotionEvent.ACTION_MOVE:
                return 1;
            case MotionEvent.ACTION_UP:
            case MotionEvent.ACTION_POINTER_UP:
                return 2;
            case MotionEvent.ACTION_CANCEL:
                return 3;
            default:
                return 1;
        }
    }

    private double density() {
        return getResources().getDisplayMetrics().density;
    }

    private void loadNativeLibraryFromManifest() {
        String library = manifestString(META_NATIVE_LIBRARY);
        if (library == null || library.length() == 0) {
            throw new IllegalStateException("missing manifest metadata " + META_NATIVE_LIBRARY);
        }
        System.loadLibrary(library);
    }

    private String manifestString(String key) {
        try {
            ActivityInfo info = getPackageManager().getActivityInfo(getComponentName(), PackageManager.GET_META_DATA);
            if (info.metaData == null) {
                return null;
            }
            return info.metaData.getString(key);
        } catch (PackageManager.NameNotFoundException error) {
            throw new IllegalStateException("activity metadata unavailable", error);
        }
    }

    private boolean manifestBoolean(String key, boolean fallback) {
        try {
            ActivityInfo info = getPackageManager().getActivityInfo(getComponentName(), PackageManager.GET_META_DATA);
            if (info.metaData == null) {
                return fallback;
            }
            Object value = info.metaData.get(key);
            if (value instanceof Boolean) {
                return (Boolean) value;
            }
            if (value instanceof String) {
                return Boolean.parseBoolean((String) value);
            }
            return info.metaData.getBoolean(key, fallback);
        } catch (PackageManager.NameNotFoundException error) {
            throw new IllegalStateException("activity metadata unavailable", error);
        }
    }

    private void configureFullscreenWindow() {
        Window window = getWindow();
        window.setFlags(WindowManager.LayoutParams.FLAG_FULLSCREEN, WindowManager.LayoutParams.FLAG_FULLSCREEN);
        if (Build.VERSION.SDK_INT >= 28) {
            WindowManager.LayoutParams params = window.getAttributes();
            params.layoutInDisplayCutoutMode = WindowManager.LayoutParams.LAYOUT_IN_DISPLAY_CUTOUT_MODE_SHORT_EDGES;
            window.setAttributes(params);
        }
        if (Build.VERSION.SDK_INT >= 21) {
            window.setStatusBarColor(Color.TRANSPARENT);
            window.setNavigationBarColor(Color.TRANSPARENT);
        }
        window.getDecorView().setSystemUiVisibility(
                View.SYSTEM_UI_FLAG_LAYOUT_STABLE
                        | View.SYSTEM_UI_FLAG_LAYOUT_FULLSCREEN
                        | View.SYSTEM_UI_FLAG_LAYOUT_HIDE_NAVIGATION
                        | View.SYSTEM_UI_FLAG_FULLSCREEN
                        | View.SYSTEM_UI_FLAG_HIDE_NAVIGATION
                        | View.SYSTEM_UI_FLAG_IMMERSIVE_STICKY);
    }
}
