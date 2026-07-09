package dev.wzzc.moui.componentgallery;

import android.app.Activity;
import android.graphics.Color;
import android.os.Bundle;
import android.os.Build;
import android.view.MotionEvent;
import android.view.Surface;
import android.view.SurfaceHolder;
import android.view.SurfaceView;
import android.view.View;
import android.view.Window;
import android.view.WindowManager;

public final class MainActivity extends Activity implements SurfaceHolder.Callback {
    static {
        System.loadLibrary("component_gallery_android");
    }

    private SurfaceView surfaceView;
    private boolean attached;
    private int surfaceWidth;
    private int surfaceHeight;
    private boolean hasLastTouchPoint;
    private float lastTouchX;
    private float lastTouchY;

    private static native boolean nativeAttachSurface(
            Surface surface,
            int width,
            int height,
            double density);

    private static native boolean nativeResize(int width, int height, double density);

    private static native boolean nativeDispatchPointer(
            int phase,
            double x,
            double y,
            double timeMs);

    private static native boolean nativeDispatchScroll(
            double x,
            double y,
            double deltaX,
            double deltaY,
            int phase);

    private static native boolean nativeRenderFrame();

    private static native void nativeDetachSurface();

    @Override
    protected void onCreate(Bundle savedInstanceState) {
        super.onCreate(savedInstanceState);
        configureFullscreenWindow();
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
        if (hasFocus) {
            configureFullscreenWindow();
        }
    }

    @Override
    protected void onDestroy() {
        nativeDetachSurface();
        attached = false;
        super.onDestroy();
    }

    @Override
    public void surfaceCreated(SurfaceHolder holder) {
        Surface surface = holder.getSurface();
        surfaceWidth = Math.max(1, surfaceView.getWidth());
        surfaceHeight = Math.max(1, surfaceView.getHeight());
        attached = nativeAttachSurface(surface, surfaceWidth, surfaceHeight, density());
        nativeRenderFrame();
    }

    @Override
    public void surfaceChanged(SurfaceHolder holder, int format, int width, int height) {
        surfaceWidth = Math.max(1, width);
        surfaceHeight = Math.max(1, height);
        if (attached) {
            nativeResize(surfaceWidth, surfaceHeight, density());
            nativeRenderFrame();
        }
    }

    @Override
    public void surfaceDestroyed(SurfaceHolder holder) {
        nativeDetachSurface();
        attached = false;
    }

    private void dispatchMotionEvent(MotionEvent event) {
        int action = event.getActionMasked();
        int phase = pointerPhase(action);
        int pointerIndex = event.getActionIndex();
        double timeMs = event.getEventTime();
        double x = event.getX(pointerIndex);
        double y = event.getY(pointerIndex);
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
        } else if (phase == 2 || phase == 3) {
            nativeDispatchScroll(x, y, 0.0, 0.0, phase == 2 ? 2 : 3);
            hasLastTouchPoint = false;
        }
        nativeDispatchPointer(
                phase,
                x,
                y,
                timeMs);
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

    private void configureFullscreenWindow() {
        Window window = getWindow();
        window.setFlags(
                WindowManager.LayoutParams.FLAG_FULLSCREEN,
                WindowManager.LayoutParams.FLAG_FULLSCREEN);
        if (Build.VERSION.SDK_INT >= 28) {
            WindowManager.LayoutParams params = window.getAttributes();
            params.layoutInDisplayCutoutMode =
                    WindowManager.LayoutParams.LAYOUT_IN_DISPLAY_CUTOUT_MODE_SHORT_EDGES;
            window.setAttributes(params);
        }
        if (Build.VERSION.SDK_INT >= 21) {
            window.setStatusBarColor(Color.TRANSPARENT);
            window.setNavigationBarColor(Color.TRANSPARENT);
        }
        surfaceViewSystemUi(window.getDecorView());
    }

    private static void surfaceViewSystemUi(View decorView) {
        decorView.setSystemUiVisibility(
                View.SYSTEM_UI_FLAG_LAYOUT_STABLE
                        | View.SYSTEM_UI_FLAG_LAYOUT_FULLSCREEN
                        | View.SYSTEM_UI_FLAG_LAYOUT_HIDE_NAVIGATION
                        | View.SYSTEM_UI_FLAG_FULLSCREEN
                        | View.SYSTEM_UI_FLAG_HIDE_NAVIGATION
                        | View.SYSTEM_UI_FLAG_IMMERSIVE_STICKY);
    }
}
