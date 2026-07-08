package dev.wzzc.moui.counter;

import android.app.Activity;
import android.os.Bundle;
import android.view.MotionEvent;
import android.view.Surface;
import android.view.SurfaceHolder;
import android.view.SurfaceView;
import android.view.View;

public final class MainActivity extends Activity implements SurfaceHolder.Callback {
    static {
        System.loadLibrary("moui_counter_android");
    }

    private SurfaceView surfaceView;
    private boolean attached;
    private int surfaceWidth;
    private int surfaceHeight;

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

    private static native boolean nativeRenderFrame();

    private static native void nativeDetachSurface();

    @Override
    protected void onCreate(Bundle savedInstanceState) {
        super.onCreate(savedInstanceState);
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
        nativeDispatchPointer(
                phase,
                event.getX(pointerIndex),
                event.getY(pointerIndex),
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
}
