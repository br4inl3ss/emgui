#pragma once

namespace ui {

class PerceptionRenderBackend : public RenderBackend {
public:
    void fillRect(vec2 objVec2Position, vec2 objVec2Size, color objColorFill, float64 fRounding, uint8 uCornerFlags) override {
        render::draw_rect_filled(objVec2Position, objVec2Size, objColorFill, fRounding, uCornerFlags);
    }

    void strokeRect(vec2 objVec2Position, vec2 objVec2Size, color objColorStroke, float64 fThickness, float64 fRounding, uint8 uCornerFlags) override {
        render::draw_rect(objVec2Position, objVec2Size, objColorStroke, fThickness, fRounding, uCornerFlags);
    }

    void fillGradient(vec2 objVec2Position, vec2 objVec2Size, color objColorTopLeft, color objColorTopRight, color objColorBottomLeft, color objColorBottomRight) override {
        render::draw_four_corner_gradient(objVec2Position, objVec2Size, objColorTopLeft, objColorTopRight, objColorBottomLeft, objColorBottomRight, 0.0);
    }

    void drawLine(vec2 objVec2From, vec2 objVec2To, color objColorLine, float64 fThickness) override {
        render::draw_line(objVec2From, objVec2To, objColorLine, fThickness);
    }

    void fillCircle(vec2 objVec2Center, float64 fRadius, color objColorFill) override {
        render::draw_circle(objVec2Center, fRadius, objColorFill, 1.0, true);
    }

    void strokeCircle(vec2 objVec2Center, float64 fRadius, color objColorStroke, float64 fThickness) override {
        render::draw_circle(objVec2Center, fRadius, objColorStroke, fThickness, false);
    }

    void fillTriangle(vec2 objVec2First, vec2 objVec2Second, vec2 objVec2Third, color objColorFill) override {
        render::draw_triangle(objVec2First, objVec2Second, objVec2Third, objColorFill, 1.0, true);
    }

    void drawText(const std::string& strText, vec2 objVec2Position, color objColorText, int64 iFontHandle) override {
        render::draw_text(strText, objVec2Position, objColorText, iFontHandle, 0, color(0, 0, 0, 0), 0.0);
    }

    vec2 measureText(int64 iFontHandle, const std::string& strText) override {
        return render::get_text_size(iFontHandle, strText);
    }

    int64 fittingPrefixLength(int64 iFontHandle, float64 fMaximumWidth, const std::string& strText) override {
        return static_cast<int64>(render::get_max_text_length(iFontHandle, vec2(fMaximumWidth, 0.0), strText));
    }

    void pushClip(vec2 objVec2Position, vec2 objVec2Size) override {
        render::clip_push(objVec2Position, objVec2Size);
    }

    void popClip() override {
        render::clip_pop();
    }

    int64 createTexture(int64 iWidth, int64 iHeight, const std::vector<uint8>& vecRgbaPixels) override {
        return render::create_texture(static_cast<uint32>(iWidth), static_cast<uint32>(iHeight), vecRgbaPixels);
    }

    void destroyTexture(int64 iTextureHandle) override {
        if (iTextureHandle != 0) { render::destroy_texture(iTextureHandle); }
    }

    void drawTexture(int64 iTextureHandle, vec2 objVec2Position, vec2 objVec2Size, color objColorTint) override {
        render::draw_texture(iTextureHandle, 0, objVec2Position, objVec2Size, objColorTint);
    }

    int64 loadFontFromFile(const std::string& strPath, float64 fPixelSize) override {
        std::vector<uint32> vecDefaultGlyphRanges;
        return render::create_font(strPath, fPixelSize, true, false, vecDefaultGlyphRanges);
    }

    int64 loadFontFromMemory(const std::string& strLabel, const std::vector<uint8>& vecFontBytes, float64 fPixelSize) override {
        std::vector<uint32> vecDefaultGlyphRanges;
        return render::create_font_mem(strLabel, fPixelSize, vecFontBytes, true, false, vecDefaultGlyphRanges);
    }

    int64 builtinFont(float64 fPixelSize) override {
        if (fPixelSize < 19.0) { return render::get_font18(); }
        if (fPixelSize < 22.0) { return render::get_font20(); }
        if (fPixelSize < 26.0) { return render::get_font24(); }
        return render::get_font28();
    }

    vec2 viewSize() override {
        return render::get_view_size();
    }
};

class PerceptionPlatformBackend : public PlatformBackend {
public:
    vec2 mousePosition() override { return get_mouse_pos(); }
    std::vector<int32> keysDown() override { return get_keys_down(); }
    float64 scrollDelta() override { return get_scroll_delta(); }
    std::string takeTextInput() override { return get_recent_key_input(); }
    std::string keyName(int64 iVirtualKey) override { return get_key_name(iVirtualKey); }
    std::string clipboardText() override { return copy_from_clipboard(); }
    void setClipboardText(const std::string& strText) override { copy_to_clipboard(strText); }
    int64 timeMilliseconds() override { return time_ms(); }
    void log(const std::string& strMessage) override { println("[ui] " + strMessage); }
};

}
