package dev.wzzc.moui.mobile;

import android.content.ClipData;
import android.content.ClipboardManager;
import android.content.Context;
import android.graphics.Matrix;
import android.graphics.Rect;
import android.net.Uri;
import android.os.Bundle;
import android.text.Editable;
import android.text.InputType;
import android.text.Selection;
import android.text.SpannableStringBuilder;
import android.util.Log;
import android.view.KeyEvent;
import android.view.SurfaceView;
import android.view.View;
import android.view.accessibility.AccessibilityEvent;
import android.view.accessibility.AccessibilityNodeInfo;
import android.view.accessibility.AccessibilityNodeProvider;
import android.view.inputmethod.BaseInputConnection;
import android.view.inputmethod.CursorAnchorInfo;
import android.view.inputmethod.EditorInfo;
import android.view.inputmethod.InputConnection;
import android.view.inputmethod.InputMethodManager;

import org.json.JSONArray;
import org.json.JSONException;
import org.json.JSONObject;

import java.io.ByteArrayOutputStream;
import java.io.InputStream;
import java.util.HashMap;
import java.util.Map;

final class MobileSurfaceView extends SurfaceView {
    private static final String LOG_TAG = "MoUIMobile";
    private static boolean a11ySmokeFired = false;
    private static boolean serviceSmokeFired = false;
    private final SpannableStringBuilder editable = new SpannableStringBuilder();
    private final Map<Integer, SemanticsNode> semantics = new HashMap<>();
    private final MobileAccessibilityProvider accessibilityProvider = new MobileAccessibilityProvider();
    private boolean imeEnabled;
    private boolean composing;
    private int semanticsRootId = View.NO_ID;

    MobileSurfaceView(Context context) {
        super(context);
        setFocusable(true);
        setFocusableInTouchMode(true);
        setImportantForAccessibility(View.IMPORTANT_FOR_ACCESSIBILITY_YES);
    }

    @Override
    public boolean onCheckIsTextEditor() {
        return imeEnabled;
    }

    @Override
    public InputConnection onCreateInputConnection(EditorInfo outAttrs) {
        outAttrs.inputType = InputType.TYPE_CLASS_TEXT | InputType.TYPE_TEXT_FLAG_MULTI_LINE;
        outAttrs.imeOptions = EditorInfo.IME_ACTION_DONE | EditorInfo.IME_FLAG_NO_EXTRACT_UI;
        outAttrs.initialSelStart = Math.max(0, Selection.getSelectionStart(editable));
        outAttrs.initialSelEnd = Math.max(0, Selection.getSelectionEnd(editable));
        return new MobileInputConnection();
    }

    void applyHostUpdates(String encoded) {
        if (encoded == null || encoded.isEmpty() || encoded.equals("[]")) {
            return;
        }
        try {
            JSONArray updates = new JSONArray(encoded);
            for (int index = 0; index < updates.length(); index++) {
                JSONObject update = updates.getJSONObject(index);
                String kind = update.optString("kind");
                if ("ime".equals(kind)) {
                    applyIme(update.getJSONObject("payload"));
                } else if ("semantics".equals(kind)) {
                    applySemantics(update.getJSONObject("payload"));
                } else if ("clipboard".equals(kind)) {
                    applyClipboard(update);
                } else if ("diagnostic".equals(kind)) {
                    Log.i(LOG_TAG, update.optString("payload", "moui-mobile diagnostic"));
                }
            }
        } catch (JSONException error) {
            Log.e(LOG_TAG, "invalid mobile host update", error);
        }
    }

    private void applyIme(JSONObject payload) throws JSONException {
        Log.i(LOG_TAG, "moui-mobile service ime state enabled=" + payload.optBoolean("enabled"));
        boolean nextEnabled = payload.optBoolean("enabled");
        String text = payload.optString("text", "");
        int caret = clamp(payload.optInt("caret", text.length()), 0, text.length());
        int selectionStart = caret;
        int selectionEnd = caret;
        JSONObject selection = payload.optJSONObject("selection");
        if (selection != null) {
            selectionStart = clamp(selection.optInt("start", caret), 0, text.length());
            selectionEnd = clamp(selection.optInt("end", caret), 0, text.length());
        }
        editable.replace(0, editable.length(), text);
        Selection.setSelection(editable, selectionStart, selectionEnd);
        composing = !payload.isNull("composition") && !payload.optString("composition").isEmpty();
        imeEnabled = nextEnabled;
        InputMethodManager manager = (InputMethodManager) getContext().getSystemService(Context.INPUT_METHOD_SERVICE);
        if (imeEnabled) {
            requestFocus();
            manager.restartInput(this);
            manager.showSoftInput(this, InputMethodManager.SHOW_IMPLICIT);
            updateCursorAnchor(manager, payload.optJSONObject("candidate_anchor"));
        } else {
            composing = false;
            manager.hideSoftInputFromWindow(getWindowToken(), 0);
            clearFocus();
        }
    }

    private void updateCursorAnchor(InputMethodManager manager, JSONObject anchor) {
        if (anchor == null) {
            return;
        }
        JSONObject origin = anchor.optJSONObject("origin");
        JSONObject size = anchor.optJSONObject("size");
        if (origin == null || size == null) {
            return;
        }
        float density = getResources().getDisplayMetrics().density;
        float x = (float) origin.optDouble("x") * density;
        float y = (float) origin.optDouble("y") * density;
        float height = Math.max(1.0f, (float) size.optDouble("height") * density);
        CursorAnchorInfo info = new CursorAnchorInfo.Builder()
                .setMatrix(new Matrix())
                .setSelectionRange(Selection.getSelectionStart(editable), Selection.getSelectionEnd(editable))
                .setInsertionMarkerLocation(x, y, y, y + height, CursorAnchorInfo.FLAG_HAS_VISIBLE_REGION)
                .build();
        manager.updateCursorAnchorInfo(this, info);
    }

    private void applyClipboard(JSONObject update) {
        int id = update.optInt("id");
        JSONObject payload = update.optJSONObject("payload");
        if (payload == null) {
            MobileActivity.nativeCompleteClipboard(id, 0, "invalid clipboard payload", new byte[0]);
            return;
        }
        String operation = payload.optString("operation");
        ClipboardManager manager = (ClipboardManager) getContext().getSystemService(Context.CLIPBOARD_SERVICE);
        try {
            if ("read-text".equals(operation)) {
                CharSequence value = "";
                if (manager.hasPrimaryClip() && manager.getPrimaryClip().getItemCount() > 0) {
                    value = manager.getPrimaryClip().getItemAt(0).coerceToText(getContext());
                }
                MobileActivity.nativeCompleteClipboard(id, 1, value == null ? "" : value.toString(), new byte[0]);
            } else if ("write-text".equals(operation)) {
                manager.setPrimaryClip(ClipData.newPlainText("MoUI", payload.optString("text")));
                MobileActivity.nativeCompleteClipboard(id, 3, "", new byte[0]);
            } else if ("read-image".equals(operation)) {
                byte[] bytes = readClipboardImage(manager);
                MobileActivity.nativeCompleteClipboard(id, bytes == null ? 0 : 2,
                        bytes == null ? "clipboard image is unavailable" : "", bytes == null ? new byte[0] : bytes);
            } else if ("write-image".equals(operation)) {
                JSONArray values = payload.optJSONArray("bytes");
                byte[] bytes = jsonBytes(values);
                Uri uri = MobileClipboardProvider.publish(getContext(), payload.optString("mime", "image/png"), bytes);
                ClipData clip = ClipData.newUri(getContext().getContentResolver(), "MoUI image", uri);
                manager.setPrimaryClip(clip);
                MobileActivity.nativeCompleteClipboard(id, 3, "", new byte[0]);
            }
            Log.i(LOG_TAG, "moui-mobile service clipboard complete operation=" + operation);
        } catch (Exception error) {
            MobileActivity.nativeCompleteClipboard(id, 0, error.getMessage(), new byte[0]);
        }
    }

    private byte[] readClipboardImage(ClipboardManager manager) throws Exception {
        if (!manager.hasPrimaryClip() || manager.getPrimaryClip().getItemCount() == 0) {
            return null;
        }
        Uri uri = manager.getPrimaryClip().getItemAt(0).getUri();
        if (uri == null) {
            return null;
        }
        try (InputStream input = getContext().getContentResolver().openInputStream(uri);
             ByteArrayOutputStream output = new ByteArrayOutputStream()) {
            if (input == null) {
                return null;
            }
            byte[] buffer = new byte[8192];
            int read;
            while ((read = input.read(buffer)) >= 0) {
                output.write(buffer, 0, read);
            }
            return output.toByteArray();
        }
    }

    private static byte[] jsonBytes(JSONArray values) throws JSONException {
        if (values == null) {
            return new byte[0];
        }
        byte[] result = new byte[values.length()];
        for (int index = 0; index < result.length; index++) {
            result[index] = (byte) values.getInt(index);
        }
        return result;
    }

    private void applySemantics(JSONObject payload) throws JSONException {
        semantics.clear();
        semanticsRootId = payload.optInt("root_id", View.NO_ID);
        JSONArray nodes = payload.getJSONArray("nodes");
        for (int index = 0; index < nodes.length(); index++) {
            SemanticsNode node = SemanticsNode.fromJson(nodes.getJSONObject(index));
            semantics.put(node.id, node);
        }
        accessibilityProvider.resetFocusIfMissing();
        sendAccessibilityEvent(AccessibilityEvent.TYPE_WINDOW_CONTENT_CHANGED);
        Log.i(LOG_TAG, "moui-mobile service accessibility tree nodes=" + nodes.length());
        logServiceProbePlan();
        maybeFireAccessibilitySmoke();
        maybeFireServiceSmoke();
    }

    // Emit probe coordinates from the MoUI semantics tree. uiautomator often
    // cannot see Canvas virtual nodes, so the recorder can parse this line as a
    // fallback when the accessibility dump lacks Service probe labels.
    private void logServiceProbePlan() {
        SemanticsNode textField = findSemanticsLabel("Service probe text", "TextField");
        SemanticsNode action = findSemanticsLabel("Activate service probe", "Button");
        if (textField == null || action == null) return;
        int[] location = new int[2];
        getLocationOnScreen(location);
        float density = density();
        int textX = location[0] + (int) ((textField.x + textField.width / 2.0) * density);
        int textY = location[1] + (int) ((textField.y + textField.height / 2.0) * density);
        int actionX = location[0] + (int) ((action.x + action.width / 2.0) * density);
        int actionY = location[1] + (int) ((action.y + action.height / 2.0) * density);
        Log.i(LOG_TAG, "moui-mobile service probe plan"
                + " textField=" + textX + "," + textY
                + " action=" + actionX + "," + actionY
                + " textFieldId=" + textField.id
                + " actionId=" + action.id
                + " density=" + density);
    }

    private SemanticsNode findSemanticsLabel(String label, String preferredRole) {
        SemanticsNode preferred = null;
        SemanticsNode any = null;
        for (SemanticsNode node : semantics.values()) {
            if (node.label == null) continue;
            if (!node.label.equals(label) && !node.label.contains(label)) continue;
            any = node;
            if (preferredRole == null || preferredRole.equals(node.role)) {
                preferred = node;
                break;
            }
        }
        return preferred != null ? preferred : any;
    }

    // Simulator/emulator smoke can request a deterministic focus/activate pair
    // without a live TalkBack gesture stream. Runs once per process when the
    // host sets MOUI_MOBILE_A11Y_SMOKE=1, mirroring the iOS once-fire path.
    private void maybeFireAccessibilitySmoke() {
        if (a11ySmokeFired || semantics.isEmpty()) return;
        if (!MobileActivity.a11ySmokeRequested) {
            String env = System.getenv("MOUI_MOBILE_A11Y_SMOKE");
            boolean enabled = env != null &&
                    (env.equals("1") || env.equalsIgnoreCase("true") || env.equalsIgnoreCase("yes"));
            if (!enabled) return;
        }
        SemanticsNode target = findSemanticsLabel("Activate service probe", "Button");
        if (target == null) {
            for (SemanticsNode node : semantics.values()) {
                if ("Button".equals(node.role)) {
                    target = node;
                    break;
                }
            }
        }
        if (target == null) return;
        a11ySmokeFired = true;
        Log.i(LOG_TAG, "moui-mobile service accessibility focus id=" + target.id);
        MobileActivity.nativeDispatchAccessibility(target.id, 1, "");
        Log.i(LOG_TAG, "moui-mobile service accessibility action=activate id=" + target.id);
        MobileActivity.nativeDispatchAccessibility(target.id, 0, "");
    }

    // Component Gallery matching-host smoke: drive IME + clipboard through the
    // native host channel once semantics expose the Service Probe controls.
    // This path does not depend on uiautomator seeing Canvas virtual nodes.
    private void maybeFireServiceSmoke() {
        if (serviceSmokeFired || semantics.isEmpty()) return;
        if (!MobileActivity.a11ySmokeRequested && !envFlagEnabled("MOUI_MOBILE_SERVICE_SMOKE")) {
            return;
        }
        SemanticsNode textField = findSemanticsLabel("Service probe text", "TextField");
        SemanticsNode action = findSemanticsLabel("Activate service probe", "Button");
        if (textField == null || action == null) return;
        serviceSmokeFired = true;
        post(() -> runServiceSmokeSequence(textField, action));
    }

    private void runServiceSmokeSequence(SemanticsNode textField, SemanticsNode action) {
        Log.i(LOG_TAG, "moui-mobile service smoke begin textFieldId=" + textField.id
                + " actionId=" + action.id);
        // Focus + SetText through accessibility so runtime owns the text field
        // session; then commit via the text-input bridge for IME edit markers.
        MobileActivity.nativeDispatchAccessibility(textField.id, 1, "");
        boolean setText = MobileActivity.nativeDispatchAccessibility(
                textField.id, 2, "ime-mobile-probe");
        Log.i(LOG_TAG, "moui-mobile service smoke set-text result=" + (setText ? 1 : 0));
        boolean inserted = MobileActivity.nativeDispatchTextInput(1, "ime-mobile-probe", 0, 0);
        Log.i(LOG_TAG, "moui-mobile service ime edit kind=commit smoke=1 result=" + (inserted ? 1 : 0));
        // Select-all + Copy/Cut/Paste through command intents so the host channel
        // issues write-text / read-text clipboard requests.
        int end = "ime-mobile-probe".length();
        MobileActivity.nativeDispatchTextInput(2, "", 0, end);
        boolean copied = MobileActivity.nativeDispatchCommand(0);
        Log.i(LOG_TAG, "moui-mobile service smoke copy result=" + (copied ? 1 : 0));
        // Seed the system clipboard and Paste so read-text is requested.
        try {
            ClipboardManager manager = (ClipboardManager) getContext()
                    .getSystemService(Context.CLIPBOARD_SERVICE);
            if (manager != null) {
                manager.setPrimaryClip(ClipData.newPlainText("MoUI", "clipboard-service-probe"));
            }
        } catch (Exception error) {
            Log.w(LOG_TAG, "moui-mobile service smoke seed clipboard failed", error);
        }
        boolean pasted = MobileActivity.nativeDispatchCommand(2);
        Log.i(LOG_TAG, "moui-mobile service smoke paste result=" + (pasted ? 1 : 0));
        // Cut after paste still exercises write-text when selection remains.
        boolean cut = MobileActivity.nativeDispatchCommand(1);
        Log.i(LOG_TAG, "moui-mobile service smoke cut result=" + (cut ? 1 : 0));
        MobileActivity.nativeDispatchAccessibility(action.id, 1, "");
        MobileActivity.nativeDispatchAccessibility(action.id, 0, "");
        Log.i(LOG_TAG, "moui-mobile service smoke end");
    }

    private static boolean envFlagEnabled(String name) {
        String env = System.getenv(name);
        return env != null
                && (env.equals("1") || env.equalsIgnoreCase("true") || env.equalsIgnoreCase("yes"));
    }

    @Override
    public AccessibilityNodeProvider getAccessibilityNodeProvider() {
        return accessibilityProvider;
    }

    private final class MobileInputConnection extends BaseInputConnection {
        MobileInputConnection() {
            super(MobileSurfaceView.this, true);
        }

        @Override
        public Editable getEditable() {
            return editable;
        }

        @Override
        public boolean commitText(CharSequence text, int newCursorPosition) {
            Log.i(LOG_TAG, "moui-mobile service ime edit kind=commit");
            int start = Math.max(0, Selection.getSelectionStart(editable));
            int end = Math.max(0, Selection.getSelectionEnd(editable));
            boolean handled = composing
                    ? MobileActivity.nativeDispatchTextInput(5, text.toString(), 0, 0)
                    : MobileActivity.nativeDispatchTextInput(1, text.toString(), start, end);
            composing = false;
            return super.commitText(text, newCursorPosition) && handled;
        }

        @Override
        public boolean setComposingText(CharSequence text, int newCursorPosition) {
            if (!composing) {
                MobileActivity.nativeDispatchTextInput(3, "", 0, 0);
                composing = true;
            }
            int cursor = Math.max(0, text.length());
            boolean handled = MobileActivity.nativeDispatchTextInput(4, text.toString(), cursor, cursor);
            return super.setComposingText(text, newCursorPosition) && handled;
        }

        @Override
        public boolean finishComposingText() {
            boolean handled = !composing || MobileActivity.nativeDispatchTextInput(5, "", 0, 0);
            composing = false;
            return super.finishComposingText() && handled;
        }

        @Override
        public boolean deleteSurroundingText(int beforeLength, int afterLength) {
            boolean handled = MobileActivity.nativeDispatchTextInput(6, "", beforeLength, afterLength);
            return super.deleteSurroundingText(beforeLength, afterLength) && handled;
        }

        @Override
        public boolean setSelection(int start, int end) {
            boolean handled = MobileActivity.nativeDispatchTextInput(2, "", start, end);
            return super.setSelection(start, end) && handled;
        }

        @Override
        public boolean performEditorAction(int actionCode) {
            return MobileActivity.nativeDispatchCommand(3);
        }

        @Override
        public boolean performContextMenuAction(int id) {
            if (id == android.R.id.copy) return MobileActivity.nativeDispatchCommand(0);
            if (id == android.R.id.cut) return MobileActivity.nativeDispatchCommand(1);
            if (id == android.R.id.paste) return MobileActivity.nativeDispatchCommand(2);
            return super.performContextMenuAction(id);
        }

        @Override
        public boolean sendKeyEvent(KeyEvent event) {
            if (event.getAction() == KeyEvent.ACTION_DOWN && event.getKeyCode() == KeyEvent.KEYCODE_DEL) {
                return deleteSurroundingText(1, 0);
            }
            if (event.getAction() == KeyEvent.ACTION_DOWN && event.getKeyCode() == KeyEvent.KEYCODE_ENTER) {
                return performEditorAction(EditorInfo.IME_ACTION_DONE);
            }
            return super.sendKeyEvent(event);
        }
    }

    private final class MobileAccessibilityProvider extends AccessibilityNodeProvider {
        private int accessibilityFocus = View.NO_ID;

        @Override
        public AccessibilityNodeInfo createAccessibilityNodeInfo(int virtualViewId) {
            if (virtualViewId == View.NO_ID) {
                AccessibilityNodeInfo root = AccessibilityNodeInfo.obtain(MobileSurfaceView.this);
                root.setClassName(MobileSurfaceView.class.getName());
                for (SemanticsNode node : semantics.values()) {
                    if (node.parentId == null) root.addChild(MobileSurfaceView.this, node.id);
                }
                return root;
            }
            SemanticsNode node = semantics.get(virtualViewId);
            if (node == null) return null;
            AccessibilityNodeInfo info = AccessibilityNodeInfo.obtain();
            info.setPackageName(getContext().getPackageName());
            info.setClassName(node.androidClassName());
            info.setSource(MobileSurfaceView.this, node.id);
            if (node.parentId == null) info.setParent(MobileSurfaceView.this);
            else info.setParent(MobileSurfaceView.this, node.parentId);
            for (SemanticsNode child : semantics.values()) {
                if (child.parentId != null && child.parentId == node.id) info.addChild(MobileSurfaceView.this, child.id);
            }
            info.setText(node.label.isEmpty() ? node.value : node.label);
            info.setContentDescription(node.description.isEmpty() ? node.label : node.description);
            info.setEnabled(!node.disabled);
            info.setSelected(node.selected);
            info.setCheckable(node.checkable);
            info.setChecked(node.checked);
            info.setFocusable(node.focusable);
            info.setFocused(node.focused);
            info.setAccessibilityFocused(accessibilityFocus == node.id);
            info.setBoundsInParent(node.bounds(density()));
            int[] location = new int[2];
            getLocationOnScreen(location);
            Rect screen = node.bounds(density());
            screen.offset(location[0], location[1]);
            info.setBoundsInScreen(screen);
            node.addActions(info);
            return info;
        }

        @Override
        public boolean performAction(int virtualViewId, int action, Bundle arguments) {
            SemanticsNode node = semantics.get(virtualViewId);
            if (node == null) return false;
            if (action == AccessibilityNodeInfo.ACTION_ACCESSIBILITY_FOCUS) {
                accessibilityFocus = virtualViewId;
                sendVirtualEvent(virtualViewId, AccessibilityEvent.TYPE_VIEW_ACCESSIBILITY_FOCUSED);
                Log.i(LOG_TAG, "moui-mobile service accessibility focus id=" + virtualViewId);
                return MobileActivity.nativeDispatchAccessibility(virtualViewId, 1, "");
            }
            if (action == AccessibilityNodeInfo.ACTION_CLEAR_ACCESSIBILITY_FOCUS) {
                accessibilityFocus = View.NO_ID;
                sendVirtualEvent(virtualViewId, AccessibilityEvent.TYPE_VIEW_ACCESSIBILITY_FOCUS_CLEARED);
                return true;
            }
            if (action == AccessibilityNodeInfo.ACTION_CLICK) {
                Log.i(LOG_TAG, "moui-mobile service accessibility action=activate id=" + virtualViewId);
                return MobileActivity.nativeDispatchAccessibility(virtualViewId, 0, "");
            }
            if (action == AccessibilityNodeInfo.ACTION_SET_TEXT) {
                CharSequence value = arguments == null ? "" : arguments.getCharSequence(AccessibilityNodeInfo.ACTION_ARGUMENT_SET_TEXT_CHARSEQUENCE, "");
                return MobileActivity.nativeDispatchAccessibility(virtualViewId, 2, value.toString());
            }
            if (action == AccessibilityNodeInfo.ACTION_SCROLL_FORWARD) return MobileActivity.nativeDispatchAccessibility(virtualViewId, 4, "forward");
            if (action == AccessibilityNodeInfo.ACTION_SCROLL_BACKWARD) return MobileActivity.nativeDispatchAccessibility(virtualViewId, 4, "backward");
            return false;
        }

        void resetFocusIfMissing() {
            if (!semantics.containsKey(accessibilityFocus)) accessibilityFocus = View.NO_ID;
        }

        private void sendVirtualEvent(int id, int type) {
            AccessibilityEvent event = AccessibilityEvent.obtain(type);
            event.setPackageName(getContext().getPackageName());
            event.setSource(MobileSurfaceView.this, id);
            if (getParent() != null) {
                getParent().requestSendAccessibilityEvent(MobileSurfaceView.this, event);
            }
        }
    }

    private float density() {
        return getResources().getDisplayMetrics().density;
    }

    private static int clamp(int value, int minimum, int maximum) {
        return Math.max(minimum, Math.min(maximum, value));
    }

    private static final class SemanticsNode {
        int id;
        Integer parentId;
        String role;
        String label;
        String value;
        String description;
        boolean disabled;
        boolean selected;
        boolean checked;
        boolean focused;
        boolean focusable;
        boolean checkable;
        double x;
        double y;
        double width;
        double height;
        JSONArray actions;

        static SemanticsNode fromJson(JSONObject json) throws JSONException {
            SemanticsNode node = new SemanticsNode();
            node.id = json.getInt("element_id");
            node.parentId = json.isNull("parent_id") ? null : json.getInt("parent_id");
            node.role = json.optString("role", "None");
            node.label = json.optString("label", "");
            node.value = json.optString("value", "");
            node.description = json.optString("description", "");
            JSONObject state = json.getJSONObject("state");
            node.disabled = state.optBoolean("disabled");
            node.selected = state.optBoolean("selected");
            node.checked = state.optBoolean("checked");
            node.focused = state.optBoolean("focused");
            node.actions = json.getJSONArray("actions");
            node.focusable = node.hasAction("Focus");
            node.checkable = "Checkbox".equals(node.role) || "Switch".equals(node.role) || "Radio".equals(node.role);
            JSONObject frame = json.getJSONObject("frame");
            JSONObject origin = frame.getJSONObject("origin");
            JSONObject size = frame.getJSONObject("size");
            node.x = origin.getDouble("x");
            node.y = origin.getDouble("y");
            node.width = size.getDouble("width");
            node.height = size.getDouble("height");
            return node;
        }

        boolean hasAction(String action) {
            for (int index = 0; index < actions.length(); index++) {
                if (action.equals(actions.optString(index))) return true;
            }
            return false;
        }

        Rect bounds(float density) {
            return new Rect((int) (x * density), (int) (y * density),
                    (int) ((x + width) * density), (int) ((y + height) * density));
        }

        String androidClassName() {
            if ("Button".equals(role)) return "android.widget.Button";
            if ("TextField".equals(role)) return "android.widget.EditText";
            if ("Checkbox".equals(role)) return "android.widget.CheckBox";
            if ("Switch".equals(role)) return "android.widget.Switch";
            if ("ScrollView".equals(role)) return "android.widget.ScrollView";
            if ("List".equals(role)) return "android.widget.ListView";
            return "android.view.View";
        }

        void addActions(AccessibilityNodeInfo info) {
            if (hasAction("Activate") || hasAction("Select")) info.addAction(AccessibilityNodeInfo.ACTION_CLICK);
            if (hasAction("Focus")) info.addAction(AccessibilityNodeInfo.ACTION_FOCUS);
            if (hasAction("SetText")) info.addAction(AccessibilityNodeInfo.ACTION_SET_TEXT);
            if (hasAction("Scroll")) {
                info.addAction(AccessibilityNodeInfo.ACTION_SCROLL_FORWARD);
                info.addAction(AccessibilityNodeInfo.ACTION_SCROLL_BACKWARD);
            }
        }
    }
}
