#pragma once

namespace ui {

class ColorPicker : public Component, public Popup {
    enum class DragArea : int32 { None, SaturationValue, Hue, Alpha };

    static constexpr float64 fSwatchWidth = 40.0;
    static constexpr float64 fPopupWidth = 240.0;
    static constexpr float64 fPopupPadding = 8.0;
    static constexpr float64 fSquareHeight = 150.0;
    static constexpr float64 fBarHeight = 14.0;
    static constexpr float64 fSpacing = 6.0;
    static constexpr float64 fCheckerCellSize = 5.0;
    static constexpr float64 fPopupGap = 4.0;
    static constexpr float64 fHexInset = 5.0;
    static constexpr int64 iChannelCount = 4;

    color m_objColor;
    float64 m_fHue = 0.0;
    float64 m_fSaturation = 0.0;
    float64 m_fBrightness = 0.0;
    bool m_bAlphaEditable = true;
    ColorCallback m_fnOnChange = null;
    DragArea m_eDragArea = DragArea::None;
    float64 m_fOpenBlend = 0.0;
    std::vector<DragValueBox> m_vecChannelBoxes;
    TextEditBuffer m_objHexBuffer;

    static color hsvToColor(float64 fHue, float64 fSaturation, float64 fBrightness, uint8 uAlpha) {
        float64 fSector = fract(fHue) * 6.0;
        float64 fChroma = fBrightness * fSaturation;
        float64 fSecondary = fChroma * (1.0 - fabs(fmod(fSector, 2.0) - 1.0));
        float64 fRed = 0.0;
        float64 fGreen = 0.0;
        float64 fBlue = 0.0;
        if (fSector < 1.0) { fRed = fChroma; fGreen = fSecondary; }
        else if (fSector < 2.0) { fRed = fSecondary; fGreen = fChroma; }
        else if (fSector < 3.0) { fGreen = fChroma; fBlue = fSecondary; }
        else if (fSector < 4.0) { fGreen = fSecondary; fBlue = fChroma; }
        else if (fSector < 5.0) { fRed = fSecondary; fBlue = fChroma; }
        else { fRed = fChroma; fBlue = fSecondary; }
        float64 fLift = fBrightness - fChroma;
        return color(static_cast<uint8>(round((fRed + fLift) * 255.0)), static_cast<uint8>(round((fGreen + fLift) * 255.0)),
            static_cast<uint8>(round((fBlue + fLift) * 255.0)), uAlpha);
    }

    void syncHsvFromColor() {
        float64 fRed = static_cast<float64>(m_objColor.r) / 255.0;
        float64 fGreen = static_cast<float64>(m_objColor.g) / 255.0;
        float64 fBlue = static_cast<float64>(m_objColor.b) / 255.0;
        float64 fMaximum = fmax(fRed, fmax(fGreen, fBlue));
        float64 fMinimum = fmin(fRed, fmin(fGreen, fBlue));
        float64 fDelta = fMaximum - fMinimum;
        m_fBrightness = fMaximum;
        m_fSaturation = fMaximum <= 0.0 ? 0.0 : fDelta / fMaximum;
        if (fDelta <= 0.0) { return; }
        float64 fHueSector = 0.0;
        if (fMaximum == fRed) { fHueSector = fmod((fGreen - fBlue) / fDelta + 6.0, 6.0); }
        else if (fMaximum == fGreen) { fHueSector = (fBlue - fRed) / fDelta + 2.0; }
        else { fHueSector = (fRed - fGreen) / fDelta + 4.0; }
        m_fHue = fHueSector / 6.0;
    }

    void changeColor(color objColorNew) {
        if (objColorNew == m_objColor) { return; }
        m_objColor = objColorNew;
        if (m_fnOnChange != null && callbacksAllowed()) { m_fnOnChange(m_objColor); }
    }

    void changeFromHsv() { changeColor(hsvToColor(m_fHue, m_fSaturation, m_fBrightness, m_objColor.a)); }

    void changeColorKeepingHue(color objColorNew) {
        changeColor(objColorNew);
        float64 fHueBefore = m_fHue;
        syncHsvFromColor();
        if (m_fSaturation <= 0.0 || m_fBrightness <= 0.0) { m_fHue = fHueBefore; }
    }

    float64 channelValue(int64 iChannel) const {
        if (iChannel == 0) { return static_cast<float64>(m_objColor.r); }
        if (iChannel == 1) { return static_cast<float64>(m_objColor.g); }
        if (iChannel == 2) { return static_cast<float64>(m_objColor.b); }
        return static_cast<float64>(m_objColor.a);
    }

    color withChannel(int64 iChannel, float64 fValue) const {
        uint8 uValue = static_cast<uint8>(clamp(round(fValue), 0.0, 255.0));
        if (iChannel == 0) { return color(uValue, m_objColor.g, m_objColor.b, m_objColor.a); }
        if (iChannel == 1) { return color(m_objColor.r, uValue, m_objColor.b, m_objColor.a); }
        if (iChannel == 2) { return color(m_objColor.r, m_objColor.g, uValue, m_objColor.a); }
        return color(m_objColor.r, m_objColor.g, m_objColor.b, uValue);
    }

    static std::string channelName(int64 iChannel) {
        if (iChannel == 0) { return "R"; }
        if (iChannel == 1) { return "G"; }
        if (iChannel == 2) { return "B"; }
        return "A";
    }

    int64 visibleChannelCount() const { return m_bAlphaEditable ? iChannelCount : iChannelCount - 1; }

    Rect swatchBounds(UiContext& objUiContext) {
        float64 fHeight = rowHeight(objUiContext);
        return Rect(m_objRectBounds.fX, m_objRectBounds.centerY() - fHeight * 0.5, fSwatchWidth, fHeight);
    }

    Rect labelBounds(UiContext& objUiContext) { return rowBounds(objUiContext).withoutLeft(fSwatchWidth + objUiContext.metrics().fIconSpacing); }

    float64 popupHeight(UiContext& objUiContext) const {
        float64 fInteractHeight = objUiContext.metrics().fInteractHeight;
        float64 fBars = m_bAlphaEditable ? fBarHeight * 2.0 + fSpacing : fBarHeight;
        return fPopupPadding * 2.0 + fSquareHeight + fSpacing + fBars + fSpacing + fInteractHeight + fSpacing + fInteractHeight;
    }

    Rect contentBounds(UiContext& objUiContext) { return popupBounds(objUiContext).shrunk(fPopupPadding); }
    Rect squareBounds(UiContext& objUiContext) { return contentBounds(objUiContext).takeTop(fSquareHeight); }

    Rect hueBarBounds(UiContext& objUiContext) {
        Rect objRectSquare = squareBounds(objUiContext);
        return Rect(objRectSquare.fX, objRectSquare.bottom() + fSpacing, objRectSquare.fWidth, fBarHeight);
    }

    Rect alphaBarBounds(UiContext& objUiContext) {
        Rect objRectHue = hueBarBounds(objUiContext);
        return Rect(objRectHue.fX, objRectHue.bottom() + fSpacing, objRectHue.fWidth, m_bAlphaEditable ? fBarHeight : 0.0);
    }

    Rect channelRowBounds(UiContext& objUiContext) {
        Rect objRectBars = m_bAlphaEditable ? alphaBarBounds(objUiContext) : hueBarBounds(objUiContext);
        return Rect(objRectBars.fX, objRectBars.bottom() + fSpacing, objRectBars.fWidth, objUiContext.metrics().fInteractHeight);
    }

    Rect channelBoxBounds(UiContext& objUiContext, int64 iChannel) {
        Rect objRectRow = channelRowBounds(objUiContext);
        float64 fGap = 4.0;
        float64 fCount = static_cast<float64>(visibleChannelCount());
        float64 fWidth = (objRectRow.fWidth - fGap * (fCount - 1.0)) / fCount;
        return Rect(objRectRow.fX + (fWidth + fGap) * static_cast<float64>(iChannel), objRectRow.fY, fWidth, objRectRow.fHeight);
    }

    Rect hexBounds(UiContext& objUiContext) {
        Rect objRectChannels = channelRowBounds(objUiContext);
        return Rect(objRectChannels.fX, objRectChannels.bottom() + fSpacing, objRectChannels.fWidth, objUiContext.metrics().fInteractHeight);
    }

    std::string hexText() const {
        std::string strHex = ComponentValue::colorToHex(m_objColor);
        return m_bAlphaEditable ? strHex : strHex.substr(0, 7);
    }

    bool isEditingHex(const UiContext& objUiContext) const { return objUiContext.hasKeyboardFocus(&m_objHexBuffer); }

    void stopEditingHex(UiContext& objUiContext) {
        objUiContext.releaseKeyboard(&m_objHexBuffer);
        m_objHexBuffer.resetScroll();
    }

    void commitHex(UiContext& objUiContext) {
        color objColorParsed;
        if (values::tryParseHexColor(m_objHexBuffer.text(), objColorParsed)) {
            if (!m_bAlphaEditable) { objColorParsed = objColorParsed.with_alpha(m_objColor.a); }
            changeColorKeepingHue(objColorParsed);
        }
        stopEditingHex(objUiContext);
    }

    void applyDrag(UiContext& objUiContext) {
        vec2 objVec2Mouse = objUiContext.input().mousePosition();
        if (m_eDragArea == DragArea::SaturationValue) {
            Rect objRectSquare = squareBounds(objUiContext);
            m_fSaturation = clamp((objVec2Mouse.x - objRectSquare.fX) / objRectSquare.fWidth, 0.0, 1.0);
            m_fBrightness = 1.0 - clamp((objVec2Mouse.y - objRectSquare.fY) / objRectSquare.fHeight, 0.0, 1.0);
            changeFromHsv();
        } else if (m_eDragArea == DragArea::Hue) {
            Rect objRectHue = hueBarBounds(objUiContext);
            m_fHue = clamp((objVec2Mouse.x - objRectHue.fX) / objRectHue.fWidth, 0.0, 0.9999);
            changeFromHsv();
        } else if (m_eDragArea == DragArea::Alpha) {
            Rect objRectAlpha = alphaBarBounds(objUiContext);
            float64 fAlpha = clamp((objVec2Mouse.x - objRectAlpha.fX) / objRectAlpha.fWidth, 0.0, 1.0);
            changeColor(m_objColor.with_alpha(static_cast<uint8>(round(fAlpha * 255.0))));
        }
    }

    void beginAreaDrag(UiContext& objUiContext, DragArea eDragArea) {
        objUiContext.input().consumeMousePress();
        objUiContext.captureMouse(this);
        m_eDragArea = eDragArea;
        applyDrag(objUiContext);
    }

    void updateHexField(UiContext& objUiContext) {
        InputState& objInputState = objUiContext.input();
        Rect objRectHex = hexBounds(objUiContext);
        if (!isEditingHex(objUiContext)) {
            if (!objUiContext.isMouseOver(objRectHex) || !objInputState.isMousePressed()) { return; }
            objInputState.consumeMousePress();
            m_objHexBuffer.setMaximumLength(9);
            m_objHexBuffer.setText(hexText());
            m_objHexBuffer.selectAll(objUiContext);
            objUiContext.focusKeyboard(&m_objHexBuffer, true);
            return;
        }
        if (objInputState.isMousePressed() && !objRectHex.contains(objInputState.mousePosition())) {
            commitHex(objUiContext);
            return;
        }
        if (objInputState.isMousePressed()) {
            objInputState.consumeMousePress();
            m_objHexBuffer.placeCaret(objUiContext, objInputState.mousePosition().x - objRectHex.fX - fHexInset);
        }
        m_objHexBuffer.applyEditingKeys(objUiContext);
        m_objHexBuffer.keepCaretVisible(objUiContext, objRectHex.fWidth - fHexInset * 2.0);
        if (objInputState.isKeyPressed(vk::enter) || objInputState.isKeyPressed(vk::tab)) { commitHex(objUiContext); }
        else if (objInputState.isKeyPressed(vk::escape)) { stopEditingHex(objUiContext); }
    }

    void drawSaturationValueSquare(UiContext& objUiContext) {
        Painter& objPainter = objUiContext.painter();
        Rect objRectSquare = squareBounds(objUiContext);
        color objColorHue = hsvToColor(m_fHue, 1.0, 1.0, 255);
        objPainter.fillGradient(objRectSquare, color(255, 255, 255, 255), objColorHue, color(0, 0, 0, 255), color(0, 0, 0, 255));
        vec2 objVec2Marker = vec2(objRectSquare.fX + objRectSquare.fWidth * m_fSaturation, objRectSquare.fY + objRectSquare.fHeight * (1.0 - m_fBrightness));
        objPainter.strokeCircle(objVec2Marker, 5.0, color(0, 0, 0, 200), 2.0);
        objPainter.strokeCircle(objVec2Marker, 4.0, color(255, 255, 255, 255), 1.5);
    }

    void drawBarMarker(UiContext& objUiContext, const Rect& objRectBar, float64 fFraction) {
        Painter& objPainter = objUiContext.painter();
        float64 fX = objRectBar.fX + objRectBar.fWidth * clamp(fFraction, 0.0, 1.0);
        Rect objRectMarker = Rect(fX - 2.0, objRectBar.fY - 2.0, 4.0, objRectBar.fHeight + 4.0);
        objPainter.fillRect(objRectMarker.expanded(1.0), color(0, 0, 0, 200), 2.0);
        objPainter.fillRect(objRectMarker, color(255, 255, 255, 255), 1.5);
    }

    void drawHueBar(UiContext& objUiContext) {
        Rect objRectHue = hueBarBounds(objUiContext);
        float64 fSegmentWidth = objRectHue.fWidth / 6.0;
        for (int64 iSegment = 0; iSegment < 6; iSegment++) {
            float64 fStart = static_cast<float64>(iSegment) / 6.0;
            float64 fEnd = static_cast<float64>(iSegment + 1) / 6.0;
            Rect objRectSegment = Rect(objRectHue.fX + fSegmentWidth * static_cast<float64>(iSegment), objRectHue.fY, fSegmentWidth, objRectHue.fHeight);
            objUiContext.painter().fillHorizontalGradient(objRectSegment, hsvToColor(fStart, 1.0, 1.0, 255), hsvToColor(fEnd >= 1.0 ? 0.0 : fEnd, 1.0, 1.0, 255));
        }
        drawBarMarker(objUiContext, objRectHue, m_fHue);
    }

    void drawAlphaBar(UiContext& objUiContext) {
        if (!m_bAlphaEditable) { return; }
        Painter& objPainter = objUiContext.painter();
        Rect objRectAlpha = alphaBarBounds(objUiContext);
        objPainter.drawCheckerboard(objRectAlpha, fCheckerCellSize, color(150, 150, 150, 255), color(95, 95, 95, 255));
        objPainter.fillHorizontalGradient(objRectAlpha, m_objColor.with_alpha(0), m_objColor.with_alpha(255));
        drawBarMarker(objUiContext, objRectAlpha, static_cast<float64>(m_objColor.a) / 255.0);
    }

    void drawHexField(UiContext& objUiContext) {
        Painter& objPainter = objUiContext.painter();
        float64 fRounding = objUiContext.metrics().fWidgetRounding;
        Rect objRectHex = hexBounds(objUiContext);
        bool bEditing = isEditingHex(objUiContext);
        bool bHovered = objUiContext.isMouseOver(objRectHex);
        color objColorBorder = colorOf(objUiContext, bEditing ? ColorRole::SelectionStroke : (bHovered ? ColorRole::WidgetHoveredStroke : ColorRole::WidgetStroke));
        objPainter.fillRect(objRectHex, colorOf(objUiContext, ColorRole::ExtremeBackground), fRounding);
        objPainter.strokeRect(objRectHex, objColorBorder, 1.0, fRounding);
        Rect objRectViewport = objRectHex.shrunk(fHexInset);
        if (bEditing) {
            m_objHexBuffer.draw(objUiContext, objRectViewport, colorOf(objUiContext, ColorRole::WidgetText), colorOf(objUiContext, ColorRole::SelectionStroke),
                colorOf(objUiContext, ColorRole::SelectionFill), true);
            return;
        }
        objPainter.drawTextInRect(hexText(), objRectViewport, colorOf(objUiContext, ColorRole::WidgetText), FontRole::Body, HorizontalAlignment::Left);
    }

    void cancelPopupEditing(UiContext& objUiContext) {
        for (DragValueBox& objDragValueBox : m_vecChannelBoxes) { objDragValueBox.cancelEditing(objUiContext); }
        stopEditingHex(objUiContext);
        objUiContext.releaseMouse(this);
        m_eDragArea = DragArea::None;
    }

public:
    ColorPicker(const std::string& strLabel, color objColorInitial) : Component(strLabel), m_objColor(objColorInitial) {
        m_vecChannelBoxes.resize(iChannelCount);
        syncHsvFromColor();
    }

    ColorPicker* onChange(ColorCallback fnOnChange) {
        m_fnOnChange = fnOnChange;
        return this;
    }

    ColorPicker* setAlphaEditable(bool bAlphaEditable) {
        m_bAlphaEditable = bAlphaEditable;
        return this;
    }

    color value() const { return m_objColor; }

    void setValue(color objColorValue) {
        m_objColor = objColorValue;
        syncHsvFromColor();
    }

    std::string typeName() const override { return "color picker"; }
    ComponentValue copyValue() const override { return ComponentValue::ofColor(m_objColor); }

    bool pasteValue(UiContext& objUiContext, const ComponentValue& objValue, bool bApply) override {
        color objColorPasted;
        if (!values::tryReadColor(objValue, objColorPasted)) { return false; }
        if (!m_bAlphaEditable) { objColorPasted = objColorPasted.with_alpha(m_objColor.a); }
        if (bApply) { changeColorKeepingHue(objColorPasted); }
        return true;
    }

    Rect popupBounds(UiContext& objUiContext) override {
        Rect objRectSwatch = swatchBounds(objUiContext);
        const Rect& objRectView = objUiContext.viewBounds();
        float64 fHeight = popupHeight(objUiContext);
        float64 fX = clamp(objRectSwatch.fX, objRectView.fX, fmax(objRectView.fX, objRectView.right() - fPopupWidth));
        float64 fY = objRectSwatch.bottom() + fPopupGap;
        if (fY + fHeight > objRectView.bottom()) { fY = objRectSwatch.fY - fPopupGap - fHeight; }
        return Rect(fX, fY, fPopupWidth, fHeight);
    }

    void updatePopup(UiContext& objUiContext) override {
        InputState& objInputState = objUiContext.input();
        if (objUiContext.isMouseCapturedBy(this)) {
            applyDrag(objUiContext);
            if (!objInputState.isMouseDown()) {
                objUiContext.releaseMouse(this);
                m_eDragArea = DragArea::None;
            }
            return;
        }
        for (int64 iChannel = 0; iChannel < visibleChannelCount(); iChannel++) {
            float64 fChannelValue = channelValue(iChannel);
            bool bChanged = m_vecChannelBoxes[iChannel].update(objUiContext, channelBoxBounds(objUiContext, iChannel), fChannelValue, 0.0, 255.0, 1.0,
                std::to_string(static_cast<int64>(fChannelValue)), m_bEnabled);
            if (bChanged) { changeColorKeepingHue(withChannel(iChannel, fChannelValue)); }
        }
        updateHexField(objUiContext);
        if (!objInputState.isMousePressed()) { return; }
        if (objUiContext.isMouseOver(squareBounds(objUiContext))) { beginAreaDrag(objUiContext, DragArea::SaturationValue); }
        else if (objUiContext.isMouseOver(hueBarBounds(objUiContext).expanded(2.0))) { beginAreaDrag(objUiContext, DragArea::Hue); }
        else if (m_bAlphaEditable && objUiContext.isMouseOver(alphaBarBounds(objUiContext).expanded(2.0))) { beginAreaDrag(objUiContext, DragArea::Alpha); }
    }

    void drawPopup(UiContext& objUiContext) override {
        Painter& objPainter = objUiContext.painter();
        float64 fRounding = objUiContext.metrics().fMenuRounding;
        Rect objRectPopup = popupBounds(objUiContext);
        objPainter.drawShadow(objRectPopup, fRounding, colorOf(objUiContext, ColorRole::WindowShadow), 8.0, vec2(3.0, 5.0));
        objPainter.fillRect(objRectPopup, colorOf(objUiContext, ColorRole::WindowFill), fRounding);
        objPainter.strokeRect(objRectPopup, colorOf(objUiContext, ColorRole::WindowStroke), 1.0, fRounding);
        drawSaturationValueSquare(objUiContext);
        drawHueBar(objUiContext);
        drawAlphaBar(objUiContext);
        for (int64 iChannel = 0; iChannel < visibleChannelCount(); iChannel++) {
            std::string strDisplay = channelName(iChannel) + " " + std::to_string(static_cast<int64>(channelValue(iChannel)));
            m_vecChannelBoxes[iChannel].draw(objUiContext, this, strDisplay, m_bEnabled);
        }
        drawHexField(objUiContext);
    }

    void onPopupClosed(UiContext& objUiContext) override { cancelPopupEditing(objUiContext); }

protected:
    float64 measureHeight(UiContext& objUiContext, float64 fWidth) override { return rowHeight(objUiContext); }

    void update(UiContext& objUiContext) override {
        Rect objRectSwatch = swatchBounds(objUiContext);
        bool bHoveredNow = isInteractive(objUiContext, objRectSwatch);
        trackHover(objUiContext, bHoveredNow);
        updateKeybindButton(objUiContext, m_objRectBounds);
        m_fOpenBlend = approachValue(m_fOpenBlend, objUiContext.isPopupOpen(this) ? 1.0 : 0.0, objUiContext.animationStep());
        bool bToggle = activationKeyPressed(objUiContext);
        if (bHoveredNow && objUiContext.input().isMousePressed()) {
            objUiContext.input().consumeMousePress();
            takeFocus(objUiContext);
            bToggle = true;
        }
        if (!bToggle) { return; }
        if (objUiContext.isPopupOpen(this)) { objUiContext.closePopup(); }
        else { objUiContext.openPopup(this); }
    }

    void draw(UiContext& objUiContext) override {
        Painter& objPainter = objUiContext.painter();
        float64 fRounding = objUiContext.metrics().fWidgetRounding;
        WidgetVisuals objWidgetVisuals = stateVisuals(objUiContext, m_fHoverBlend, 0.0, m_fOpenBlend);
        Rect objRectSwatch = swatchBounds(objUiContext).expanded(objWidgetVisuals.fExpansion);
        objPainter.drawCheckerboard(objRectSwatch, fCheckerCellSize, color(150, 150, 150, 255), color(95, 95, 95, 255));
        objPainter.fillRect(objRectSwatch.takeLeft(objRectSwatch.fWidth * 0.5), faded(m_objColor.with_alpha(255)), 0.0);
        objPainter.fillRect(objRectSwatch.withoutLeft(objRectSwatch.fWidth * 0.5), faded(m_objColor), 0.0);
        objPainter.strokeRect(objRectSwatch, objWidgetVisuals.objColorStroke.a > 0 ? objWidgetVisuals.objColorStroke : colorOf(objUiContext, ColorRole::WindowStroke), 1.0, fRounding);
        drawFocusRing(objUiContext, swatchBounds(objUiContext));
        objPainter.drawTextInRect(m_strLabel, labelBounds(objUiContext), objWidgetVisuals.objColorText, FontRole::Body, HorizontalAlignment::Left);
        drawKeybindButton(objUiContext);
    }
};

}
