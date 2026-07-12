package dev.wzzc.moui.mobile;

import android.content.ContentProvider;
import android.content.ContentValues;
import android.content.Context;
import android.database.Cursor;
import android.net.Uri;
import android.os.ParcelFileDescriptor;

import java.io.File;
import java.io.FileNotFoundException;
import java.io.FileOutputStream;
import java.io.IOException;

public final class MobileClipboardProvider extends ContentProvider {
    private static final String FILE_NAME = "moui-mobile-clipboard-image";
    private static volatile String mimeType = "image/png";

    static Uri publish(Context context, String mime, byte[] bytes) throws IOException {
        File file = new File(context.getCacheDir(), FILE_NAME);
        try (FileOutputStream output = new FileOutputStream(file, false)) {
            output.write(bytes);
        }
        mimeType = mime == null || mime.isEmpty() ? "image/png" : mime;
        return Uri.parse("content://" + context.getPackageName() + ".moui.clipboard/image");
    }

    @Override public boolean onCreate() { return true; }
    @Override public String getType(Uri uri) { return mimeType; }

    @Override
    public ParcelFileDescriptor openFile(Uri uri, String mode) throws FileNotFoundException {
        if (!"r".equals(mode) || getContext() == null) throw new FileNotFoundException("read-only clipboard image");
        return ParcelFileDescriptor.open(new File(getContext().getCacheDir(), FILE_NAME), ParcelFileDescriptor.MODE_READ_ONLY);
    }

    @Override public Cursor query(Uri uri, String[] projection, String selection, String[] selectionArgs, String sortOrder) { return null; }
    @Override public Uri insert(Uri uri, ContentValues values) { return null; }
    @Override public int delete(Uri uri, String selection, String[] selectionArgs) { return 0; }
    @Override public int update(Uri uri, ContentValues values, String selection, String[] selectionArgs) { return 0; }
}
