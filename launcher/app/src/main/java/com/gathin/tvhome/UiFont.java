package com.gathin.tvhome;

import android.content.Context;
import android.content.res.Resources;
import android.graphics.Typeface;
import android.os.Build;
import android.util.TypedValue;

/**
 * The typeface behind one of the font_* strings in res/values/fonts.xml, for views built in code. The string
 * points at a bundled font, or, in locales Outfit can't draw (values-vi), names a system family (#833).
 */
final class UiFont {
    private UiFont() {}

    static Typeface get(Context context, int fontString) {
        Resources res = context.getResources();
        TypedValue value = new TypedValue();
        res.getValue(fontString, value, true);
        String name = String.valueOf(value.string);
        if (!name.startsWith("res/")) return Typeface.create(name, Typeface.NORMAL);
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) return res.getFont(value.resourceId);
        // Font resources are API 26, and the res/font family XML they name cannot be read on 5.1: draw the text
        // in the system family of the same weight instead, as values-vi already does for the languages Outfit
        // cannot draw. The rest of the launcher's XML text falls back to the system font on this release too.
        return Typeface.create(systemFamily(value.resourceId), Typeface.NORMAL);
    }

    /** The system family standing in for one of the bundled weights before API 26. */
    private static String systemFamily(int fontResource) {
        if (fontResource == R.font.outfit_medium) return "sans-serif-medium";
        if (fontResource == R.font.outfit_light) return "sans-serif-light";
        if (fontResource == R.font.outfit_extralight) return "sans-serif-thin";
        return "sans-serif";
    }
}
