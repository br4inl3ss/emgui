#pragma once

namespace ui {

class Painter {
    static constexpr int64 iRoundAllCorners = 0;

    RenderBackend* m_pRenderBackend;
    FontLibrary* m_pFontLibrary;
    float64 m_fScale = 1.0;
    std::vector<Rect> m_vecClipStack;
    std::vector<float64> m_vecLineHeightCache;

    float64 toPixel(float64 fLogical) const { return round(fLogical * m_fScale); }
    vec2 toPixelPoint(vec2 objVec2Logical) const { return vec2(toPixel(objVec2Logical.x), toPixel(objVec2Logical.y)); }
    vec2 toPixelPosition(const Rect& objRect) const { return vec2(toPixel(objRect.fX), toPixel(objRect.fY)); }
    vec2 toPixelSize(const Rect& objRect) const {
        return vec2(toPixel(objRect.right()) - toPixel(objRect.fX), toPixel(objRect.bottom()) - toPixel(objRect.fY));
    }
    float64 toPixelThickness(float64 fLogical) const { return fmax(1.0, round(fLogical * m_fScale)); }
    float64 toPixelRounding(float64 fLogical) const { return fmax(0.0, fLogical * m_fScale); }

    static int64 utf8SafeLength(const std::string& strText, int64 iLength) {
        int64 iSafeLength = clamp(iLength, static_cast<int64>(0), strText.size());
        while (iSafeLength > 0 && iSafeLength < strText.size() && (static_cast<uint8>(strText[iSafeLength]) & 0xC0) == 0x80) { iSafeLength--; }
        return iSafeLength;
    }

public:
    Painter(RenderBackend* pRenderBackend, FontLibrary* pFontLibrary)
        : m_pRenderBackend(pRenderBackend), m_pFontLibrary(pFontLibrary) {
        m_vecLineHeightCache.resize(static_cast<int64>(FontRole::Count), 0.0);
    }

    void beginFrame(float64 fScale) {
        m_fScale = fScale;
        m_vecClipStack.clear();
        for (int64 iRole = 0; iRole < m_vecLineHeightCache.size(); iRole++) { m_vecLineHeightCache[iRole] = 0.0; }
    }

    void endFrame() {
        while (!m_vecClipStack.empty()) { popClip(); }
    }

    float64 scale() const { return m_fScale; }
    RenderBackend* renderBackend() const { return m_pRenderBackend; }

    void fillRect(const Rect& objRect, color objColorFill, float64 fRounding, uint8 uCornerFlags) {
        if (objRect.isEmpty() || objColorFill.a == 0) { return; }
        m_pRenderBackend->fillRect(toPixelPosition(objRect), toPixelSize(objRect), objColorFill, toPixelRounding(fRounding), uCornerFlags);
    }

    void fillRect(const Rect& objRect, color objColorFill, float64 fRounding) {
        fillRect(objRect, objColorFill, fRounding, static_cast<uint8>(iRoundAllCorners));
    }

    void strokeRect(const Rect& objRect, color objColorStroke, float64 fThickness, float64 fRounding) {
        if (objRect.isEmpty() || objColorStroke.a == 0) { return; }
        m_pRenderBackend->strokeRect(toPixelPosition(objRect), toPixelSize(objRect), objColorStroke, toPixelThickness(fThickness),
            toPixelRounding(fRounding), static_cast<uint8>(iRoundAllCorners));
    }

    void fillGradient(const Rect& objRect, color objColorTopLeft, color objColorTopRight, color objColorBottomLeft, color objColorBottomRight) {
        if (objRect.isEmpty()) { return; }
        m_pRenderBackend->fillGradient(toPixelPosition(objRect), toPixelSize(objRect), objColorTopLeft, objColorTopRight, objColorBottomLeft, objColorBottomRight);
    }

    void fillHorizontalGradient(const Rect& objRect, color objColorLeft, color objColorRight) {
        fillGradient(objRect, objColorLeft, objColorRight, objColorLeft, objColorRight);
    }

    void drawCheckerboard(const Rect& objRect, float64 fCellSize, color objColorLight, color objColorDark) {
        fillRect(objRect, objColorLight, 0.0);
        int64 iColumns = static_cast<int64>(ceil(objRect.fWidth / fCellSize));
        int64 iRows = static_cast<int64>(ceil(objRect.fHeight / fCellSize));
        for (int64 iRow = 0; iRow < iRows; iRow++) {
            for (int64 iColumn = iRow % 2; iColumn < iColumns; iColumn += 2) {
                Rect objRectCell = Rect(objRect.fX + fCellSize * static_cast<float64>(iColumn), objRect.fY + fCellSize * static_cast<float64>(iRow), fCellSize, fCellSize);
                fillRect(objRectCell.intersection(objRect), objColorDark, 0.0);
            }
        }
    }

    void drawLine(vec2 objVec2From, vec2 objVec2To, color objColorLine, float64 fThickness) {
        if (objColorLine.a == 0) { return; }
        m_pRenderBackend->drawLine(vec2(objVec2From.x * m_fScale, objVec2From.y * m_fScale), vec2(objVec2To.x * m_fScale, objVec2To.y * m_fScale),
            objColorLine, fmax(1.0, fThickness * m_fScale));
    }

    void fillCircle(vec2 objVec2Center, float64 fRadius, color objColorFill) {
        if (objColorFill.a == 0 || fRadius <= 0.0) { return; }
        m_pRenderBackend->fillCircle(vec2(objVec2Center.x * m_fScale, objVec2Center.y * m_fScale), fRadius * m_fScale, objColorFill);
    }

    void strokeCircle(vec2 objVec2Center, float64 fRadius, color objColorStroke, float64 fThickness) {
        if (objColorStroke.a == 0 || fRadius <= 0.0) { return; }
        m_pRenderBackend->strokeCircle(vec2(objVec2Center.x * m_fScale, objVec2Center.y * m_fScale), fRadius * m_fScale, objColorStroke, fmax(1.0, fThickness * m_fScale));
    }

    void drawShadow(const Rect& objRect, float64 fRounding, color objColorShadow, float64 fBlur, vec2 objVec2Offset) {
        int64 iLayers = 6;
        Rect objRectOffset = objRect.translated(objVec2Offset.x, objVec2Offset.y);
        for (int64 iLayer = iLayers; iLayer >= 1; iLayer--) {
            float64 fProgress = static_cast<float64>(iLayer) / static_cast<float64>(iLayers);
            float64 fLayerAlpha = static_cast<float64>(objColorShadow.a) / static_cast<float64>(iLayers) * (1.15 - fProgress);
            fillRect(objRectOffset.expanded(fBlur * fProgress - fBlur * 0.35), objColorShadow.with_alpha(static_cast<uint8>(fLayerAlpha)), fRounding + fBlur * fProgress);
        }
    }

    void drawCheckMark(const Rect& objRectBox, color objColorMark, float64 fProgress) {
        Rect objRectInner = objRectBox.shrunk(objRectBox.fWidth * 0.22);
        vec2 objVec2Start = vec2(objRectInner.fX, objRectInner.centerY());
        vec2 objVec2Corner = vec2(objRectInner.centerX(), objRectInner.bottom());
        vec2 objVec2End = vec2(objRectInner.right(), objRectInner.fY);
        float64 fFirstLeg = clamp(fProgress * 2.0, 0.0, 1.0);
        float64 fSecondLeg = clamp(fProgress * 2.0 - 1.0, 0.0, 1.0);
        if (fFirstLeg > 0.0) {
            drawLine(objVec2Start, vec2(lerp(objVec2Start.x, objVec2Corner.x, fFirstLeg), lerp(objVec2Start.y, objVec2Corner.y, fFirstLeg)), objColorMark, 1.6);
        }
        if (fSecondLeg > 0.0) {
            drawLine(objVec2Corner, vec2(lerp(objVec2Corner.x, objVec2End.x, fSecondLeg), lerp(objVec2Corner.y, objVec2End.y, fSecondLeg)), objColorMark, 1.6);
        }
    }

    void fillTriangle(vec2 objVec2First, vec2 objVec2Second, vec2 objVec2Third, color objColorFill) {
        if (objColorFill.a == 0) { return; }
        m_pRenderBackend->fillTriangle(vec2(objVec2First.x * m_fScale, objVec2First.y * m_fScale), vec2(objVec2Second.x * m_fScale, objVec2Second.y * m_fScale),
            vec2(objVec2Third.x * m_fScale, objVec2Third.y * m_fScale), objColorFill);
    }

    void drawDropdownTriangle(vec2 objVec2Center, float64 fWidth, bool bPointsUp, color objColorTriangle) {
        float64 fHalfWidth = fWidth * 0.5;
        float64 fHalfHeight = fWidth * 0.3 * (bPointsUp ? -1.0 : 1.0);
        fillTriangle(vec2(objVec2Center.x - fHalfWidth, objVec2Center.y - fHalfHeight), vec2(objVec2Center.x + fHalfWidth, objVec2Center.y - fHalfHeight),
            vec2(objVec2Center.x, objVec2Center.y + fHalfHeight), objColorTriangle);
    }

    vec2 measureText(const std::string& strText, FontRole eFontRole) {
        if (strText.empty()) { return vec2(0.0, lineHeight(eFontRole)); }
        vec2 objVec2Pixels = m_pRenderBackend->measureText(m_pFontLibrary->handleFor(eFontRole), strText);
        return vec2(objVec2Pixels.x / m_fScale, objVec2Pixels.y / m_fScale);
    }

    float64 lineHeight(FontRole eFontRole) {
        int64 iRoleIndex = static_cast<int64>(eFontRole);
        if (m_vecLineHeightCache[iRoleIndex] <= 0.0) {
            vec2 objVec2Pixels = m_pRenderBackend->measureText(m_pFontLibrary->handleFor(eFontRole), "Ag");
            m_vecLineHeightCache[iRoleIndex] = fmax(1.0, objVec2Pixels.y / m_fScale);
        }
        return m_vecLineHeightCache[iRoleIndex];
    }

    std::string ellipsize(const std::string& strText, FontRole eFontRole, float64 fMaximumWidth) {
        if (strText.empty() || measureText(strText, eFontRole).x <= fMaximumWidth) { return strText; }
        std::string strEllipsis = "...";
        float64 fAvailablePixels = (fMaximumWidth - measureText(strEllipsis, eFontRole).x) * m_fScale;
        if (fAvailablePixels <= 0.0) { return ""; }
        int64 iPrefixLength = m_pRenderBackend->fittingPrefixLength(m_pFontLibrary->handleFor(eFontRole), fAvailablePixels, strText);
        return strText.substr(0, utf8SafeLength(strText, iPrefixLength)) + strEllipsis;
    }

    void drawText(const std::string& strText, vec2 objVec2Position, color objColorText, FontRole eFontRole) {
        if (strText.empty() || objColorText.a == 0) { return; }
        m_pRenderBackend->drawText(strText, toPixelPoint(objVec2Position), objColorText, m_pFontLibrary->handleFor(eFontRole));
    }

    void drawTextInRect(const std::string& strText, const Rect& objRect, color objColorText, FontRole eFontRole, HorizontalAlignment eAlignment) {
        std::string strFitted = ellipsize(strText, eFontRole, objRect.fWidth);
        if (strFitted.empty()) { return; }
        vec2 objVec2TextSize = measureText(strFitted, eFontRole);
        float64 fX = objRect.fX;
        if (eAlignment == HorizontalAlignment::Center) { fX = objRect.centerX() - objVec2TextSize.x * 0.5; }
        if (eAlignment == HorizontalAlignment::Right) { fX = objRect.right() - objVec2TextSize.x; }
        drawText(strFitted, vec2(fX, objRect.centerY() - objVec2TextSize.y * 0.5), objColorText, eFontRole);
    }

    void pushClip(const Rect& objRect) {
        Rect objRectClip = m_vecClipStack.empty() ? objRect : objRect.intersection(m_vecClipStack.back());
        m_vecClipStack.push_back(objRectClip);
        m_pRenderBackend->pushClip(toPixelPosition(objRectClip), toPixelSize(objRectClip));
    }

    void popClip() {
        if (m_vecClipStack.empty()) { return; }
        m_vecClipStack.pop_back();
        m_pRenderBackend->popClip();
    }

    void drawSvgIcon(SvgIcon& objSvgIcon, const Rect& objRect, color objColorTint) {
        int64 iPixelSize = static_cast<int64>(round(fmin(objRect.fWidth, objRect.fHeight) * m_fScale));
        int64 iTextureHandle = objSvgIcon.textureForPixelSize(m_pRenderBackend, iPixelSize);
        if (iTextureHandle == 0) { return; }
        color objColorEffectiveTint = objSvgIcon.colorMode() == SvgColorMode::Tinted ? objColorTint : color(255, 255, 255, objColorTint.a);
        float64 fPixelX = toPixel(objRect.centerX()) - static_cast<float64>(iPixelSize / 2);
        float64 fPixelY = toPixel(objRect.centerY()) - static_cast<float64>(iPixelSize / 2);
        m_pRenderBackend->drawTexture(iTextureHandle, vec2(fPixelX, fPixelY), vec2(static_cast<float64>(iPixelSize), static_cast<float64>(iPixelSize)), objColorEffectiveTint);
    }
};

}
