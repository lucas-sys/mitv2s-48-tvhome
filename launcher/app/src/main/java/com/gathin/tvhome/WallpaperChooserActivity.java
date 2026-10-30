package com.gathin.tvhome;

import android.app.Activity;
import android.content.Context;
import android.content.SharedPreferences;
import android.graphics.Bitmap;
import android.graphics.BitmapFactory;
import android.os.Bundle;
import android.util.LruCache;
import android.view.Gravity;
import android.view.View;
import android.view.ViewGroup;
import android.widget.BaseAdapter;
import android.widget.GridView;
import android.widget.ImageView;
import android.widget.TextView;
import android.widget.Toast;

import java.io.File;
import java.util.ArrayList;
import java.util.List;

/**
 * The on-TV wallpaper chooser: a grid of thumbnails from the theme's {@code wallpapers/} folder (plus a single
 * {@code wallpaper.jpg}), with "theme default" (the theme's own rotation) and "none" as the first two tiles.
 *
 * Opened from the Wallpaper tile on Home (config.xml wallpaper_button) or from Launcher settings' Wallpaper
 * row keeps the same pick: the choice goes into {@link Config#WALLPAPER_CHOICE_KEY} in the launcher_settings
 * preferences, and the settings revision is bumped so Home rebuilds with the new picture when this closes.
 */
public class WallpaperChooserActivity extends Activity {

    private static final String THEME_DEFAULT = "theme-default";
    private static final String NONE = "none";
    private static final int THUMB_WIDTH = 360;

    private final List<File> images = new ArrayList<>();

    @Override
    protected void onCreate(Bundle savedInstanceState) {
        super.onCreate(savedInstanceState);
        setContentView(R.layout.activity_wallpaper);

        File dir = Config.dir(this);
        if (dir != null) {
            images.addAll(WallpaperRotation.images(new File(dir, "wallpapers")));
            File single = new File(dir, Config.WALLPAPER_NAME);
            if (single.isFile()) images.add(0, single);
        }

        SharedPreferences choices = getSharedPreferences(Config.SETTINGS_NAME, MODE_PRIVATE);
        String current = choices.getString(Config.WALLPAPER_CHOICE_KEY, null);
        int index = current == null || NONE.equals(current) ? -1 : imageIndex(current);
        // A stored name that is no longer there falls back to the theme's rotation, exactly like Config does,
        // so the grid must not claim "none" (index 1) is in force.
        int selected = current == null ? 0 : NONE.equals(current) ? 1 : index >= 0 ? index + 2 : 0;

        GridView grid = findViewById(R.id.wallpaperGrid);
        grid.setAdapter(new Thumbs(selected));
        grid.setSelection(Math.max(0, selected));
        grid.setOnItemClickListener((parent, view, position, id) -> apply(position, choices));
        // This page has no other focus target: without this the D-pad and OK reach nothing at all.
        grid.setFocusableInTouchMode(true);
        grid.requestFocus();
        grid.post(() -> {
            grid.requestFocus();
            grid.setSelection(Math.max(0, selected));
        });

        findViewById(R.id.wallpaperTitle);
        TextView hint = findViewById(R.id.wallpaperHint);
        hint.setText(getString(R.string.wallpaper_count, images.size()));
    }

    private int imageIndex(String name) {
        for (int i = 0; i < images.size(); i++) if (images.get(i).getName().equals(name)) return i;
        return -1;
    }

    private void apply(int position, SharedPreferences choices) {
        SharedPreferences.Editor edit = choices.edit();
        if (position == 0) {
            edit.remove(Config.WALLPAPER_CHOICE_KEY);           // the theme's own rotation again
        } else if (position == 1) {
            edit.putString(Config.WALLPAPER_CHOICE_KEY, NONE);
        } else {
            int index = position - 2;
            if (index < 0 || index >= images.size()) return;
            edit.putString(Config.WALLPAPER_CHOICE_KEY, images.get(index).getName());
        }
        edit.apply();
        // Same change counter Launcher settings uses: Home rebuilds in onResume with the new picture.
        choices.edit().putLong(Config.SETTINGS_REVISION_KEY,
                choices.getLong(Config.SETTINGS_REVISION_KEY, 0) + 1).apply();
        Toast.makeText(this, R.string.wallpaper_applied, Toast.LENGTH_SHORT).show();
        finish();
    }

    /** GridView is enough here: it is a framework widget and needs no dependency on the API 22 set. */
    private final class Thumbs extends BaseAdapter {
        private final int selected;
        private final LruCache<String, Bitmap> cache = new LruCache<>(8);

        Thumbs(int selected) {
            this.selected = selected;
        }

        @Override
        public int getCount() {
            return images.size() + 2;
        }

        @Override
        public Object getItem(int position) {
            return position;
        }

        @Override
        public long getItemId(int position) {
            return position;
        }

        @Override
        public View getView(int position, View convertView, ViewGroup parent) {
            View view = convertView != null ? convertView : getLayoutInflater().inflate(R.layout.item_wallpaper, parent, false);
            ImageView thumb = view.findViewById(R.id.wallpaperThumb);
            TextView label = view.findViewById(R.id.wallpaperName);
            boolean chosen = position == selected;
            thumb.setImageBitmap(bitmapFor(position));
            thumb.setAlpha(chosen ? 1f : 0.72f);
            String name;
            if (position == 0) name = getString(R.string.wallpaper_theme_default);
            else if (position == 1) name = getString(R.string.wallpaper_none);
            else name = images.get(position - 2).getName();
            label.setText(chosen ? "\u2713 " + name : name);
            label.setTextColor(chosen ? 0xFFFFFFFF : 0x99FFFFFF);
            view.setBackgroundResource(chosen ? R.drawable.wallpaper_chosen : 0);
            return view;
        }

        /** The two control tiles get a dark placeholder; pictures are decoded small, so 36 thumbnails stay cheap. */
        private Bitmap bitmapFor(int position) {
            if (position == 0) return placeholder(0xFF1E2A38);
            if (position == 1) return placeholder(0xFF101010);
            File file = images.get(position - 2);
            Bitmap cached = cache.get(file.getAbsolutePath());
            if (cached != null) return cached;
            BitmapFactory.Options bounds = new BitmapFactory.Options();
            bounds.inJustDecodeBounds = true;
            BitmapFactory.decodeFile(file.getAbsolutePath(), bounds);
            BitmapFactory.Options options = new BitmapFactory.Options();
            options.inSampleSize = sampleSize(bounds.outWidth);
            Bitmap bitmap = BitmapFactory.decodeFile(file.getAbsolutePath(), options);
            if (bitmap != null) cache.put(file.getAbsolutePath(), bitmap);
            return bitmap;
        }

        private int sampleSize(int width) {
            int sample = 1;
            while (width / sample > THUMB_WIDTH * 2) sample *= 2;
            return sample;
        }

        private Bitmap placeholder(int colour) {
            Bitmap bitmap = Bitmap.createBitmap(THUMB_WIDTH, THUMB_WIDTH * 9 / 16, Bitmap.Config.ARGB_8888);
            bitmap.eraseColor(colour);
            return bitmap;
        }
    }
}
