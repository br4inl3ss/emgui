#pragma once

namespace ui {

class RenderBackend {
public:
    virtual ~RenderBackend() {}

    virtual void fillRect(vec2 objVec2Position, vec2 objVec2Size, color objColorFill, float64 fRounding, uint8 uCornerFlags) = 0;
    virtual void strokeRect(vec2 objVec2Position, vec2 objVec2Size, color objColorStroke, float64 fThickness, float64 fRounding, uint8 uCornerFlags) = 0;
    virtual void fillGradient(vec2 objVec2Position, vec2 objVec2Size, color objColorTopLeft, color objColorTopRight, color objColorBottomLeft, color objColorBottomRight) = 0;
    virtual void drawLine(vec2 objVec2From, vec2 objVec2To, color objColorLine, float64 fThickness) = 0;
    virtual void fillCircle(vec2 objVec2Center, float64 fRadius, color objColorFill) = 0;
    virtual void strokeCircle(vec2 objVec2Center, float64 fRadius, color objColorStroke, float64 fThickness) = 0;
    virtual void fillTriangle(vec2 objVec2First, vec2 objVec2Second, vec2 objVec2Third, color objColorFill) = 0;

    virtual void drawText(const std::string& strText, vec2 objVec2Position, color objColorText, int64 iFontHandle) = 0;
    virtual vec2 measureText(int64 iFontHandle, const std::string& strText) = 0;
    virtual int64 fittingPrefixLength(int64 iFontHandle, float64 fMaximumWidth, const std::string& strText) = 0;

    virtual void pushClip(vec2 objVec2Position, vec2 objVec2Size) = 0;
    virtual void popClip() = 0;

    virtual int64 createTexture(int64 iWidth, int64 iHeight, const std::vector<uint8>& vecRgbaPixels) = 0;
    virtual void destroyTexture(int64 iTextureHandle) = 0;
    virtual void drawTexture(int64 iTextureHandle, vec2 objVec2Position, vec2 objVec2Size, color objColorTint) = 0;

    virtual int64 loadFontFromFile(const std::string& strPath, float64 fPixelSize) = 0;
    virtual int64 loadFontFromMemory(const std::string& strLabel, const std::vector<uint8>& vecFontBytes, float64 fPixelSize) = 0;
    virtual int64 builtinFont(float64 fPixelSize) = 0;

    virtual vec2 viewSize() = 0;
};

class InputCapture {
public:
    virtual ~InputCapture() {}
    virtual void captureRegions(const std::vector<Rect>& vecPixelRegions) = 0;
};

class PlatformBackend {
public:
    virtual ~PlatformBackend() {}

    virtual vec2 mousePosition() = 0;
    virtual std::vector<int32> keysDown() = 0;
    virtual float64 scrollDelta() = 0;
    virtual std::string takeTextInput() = 0;
    virtual std::string keyName(int64 iVirtualKey) = 0;
    virtual std::string clipboardText() = 0;
    virtual void setClipboardText(const std::string& strText) = 0;
    virtual int64 timeMilliseconds() = 0;
    virtual void log(const std::string& strMessage) = 0;
};

}
