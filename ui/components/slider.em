#pragma once

namespace ui {

class SliderBase : public Component {
    static constexpr float64 fRailHeight = 8.0;
    static constexpr float64 fHandleRadius = 7.0;
    static constexpr float64 fValueBoxMinimumWidth = 48.0;
    static constexpr float64 fValueBoxPadding = 8.0;

    float64 m_fRailActiveBlend = 0.0;
    DragValueBox m_objDragValueBox;

    Rect valueBoxBounds(UiContext& objUiContext) {
        Rect objRectControl = controlBounds(objUiContext);
        float64 fTextWidth = objUiContext.painter().measureText(formatValue() + m_strSuffix, FontRole::Body).x;
        float64 fWidth = clamp(fTextWidth + fValueBoxPadding * 2.0, fValueBoxMinimumWidth, fmax(fValueBoxMinimumWidth, objRectControl.fWidth * 0.5));
        float64 fHeight = rowHeight(objUiContext);
        return Rect(objRectControl.right() - fWidth, objRectControl.centerY() - fHeight * 0.5, fWidth, fHeight);
    }

    Rect railAreaBounds(UiContext& objUiContext) {
        return controlBounds(objUiContext).withoutRight(valueBoxBounds(objUiContext).fWidth + objUiContext.metrics().fIconSpacing);
    }

    float64 usableRailWidth(UiContext& objUiContext) { return fmax(1.0, railAreaBounds(objUiContext).fWidth - fHandleRadius * 2.0); }

    float64 fraction() const {
        if (m_fMaximum <= m_fMinimum) { return 0.0; }
        return clamp((m_fValue - m_fMinimum) / (m_fMaximum - m_fMinimum), 0.0, 1.0);
    }

    void applyRailDrag(UiContext& objUiContext) {
        Rect objRectRail = railAreaBounds(objUiContext);
        float64 fMouseFraction = clamp((objUiContext.input().mousePosition().x - objRectRail.fX - fHandleRadius) / usableRailWidth(objUiContext), 0.0, 1.0);
        changeValue(lerp(m_fMinimum, m_fMaximum, fMouseFraction));
    }

    void updateValueBox(UiContext& objUiContext) {
        Rect objRectValueBox = valueBoxBounds(objUiContext);
        if (isInteractive(objUiContext, objRectValueBox) && objUiContext.input().isMousePressed()) { takeFocus(objUiContext); }
        float64 fBoxValue = m_fValue;
        float64 fValuePerPixel = (m_fMaximum - m_fMinimum) / usableRailWidth(objUiContext);
        if (m_objDragValueBox.update(objUiContext, objRectValueBox, fBoxValue, m_fMinimum, m_fMaximum, fValuePerPixel, formatValue(), m_bEnabled)) {
            changeValue(fBoxValue);
        }
    }

    void updateKeyboard(UiContext& objUiContext) {
        if (!acceptsKeyboardInput(objUiContext)) { return; }
        InputState& objInputState = objUiContext.input();
        if (objInputState.isKeyPressedRepeating(vk::left)) { changeValue(m_fValue - keyboardStep()); }
        if (objInputState.isKeyPressedRepeating(vk::right)) { changeValue(m_fValue + keyboardStep()); }
        if (objInputState.isKeyPressed(vk::enter)) { m_objDragValueBox.beginEditing(objUiContext, formatValue()); }
    }

    void updateRail(UiContext& objUiContext) {
        InputState& objInputState = objUiContext.input();
        bool bDragging = objUiContext.isMouseCapturedBy(this);
        bool bRailHovered = isInteractive(objUiContext, railAreaBounds(objUiContext));
        trackHover(objUiContext, bRailHovered || bDragging);
        m_fRailActiveBlend = approachValue(m_fRailActiveBlend, bDragging ? 1.0 : 0.0, objUiContext.animationStep());
        if (!bDragging && bRailHovered && objInputState.isMousePressed()) {
            objInputState.consumeMousePress();
            takeFocus(objUiContext);
            if (objInputState.isControlDown()) {
                m_objDragValueBox.beginEditing(objUiContext, formatValue());
                return;
            }
            objUiContext.captureMouse(this);
            bDragging = true;
        }
        if (!bDragging) { return; }
        applyRailDrag(objUiContext);
        if (!objInputState.isMouseDown()) { objUiContext.releaseMouse(this); }
    }

protected:
    float64 m_fMinimum;
    float64 m_fMaximum;
    float64 m_fValue;
    std::string m_strSuffix;

    virtual float64 snapToStep(float64 fRawValue) const = 0;
    virtual std::string formatValue() const = 0;
    virtual void notifyValueChanged() = 0;
    virtual float64 keyboardStep() const = 0;

    void assignValue(float64 fValue) { m_fValue = snapToStep(clamp(fValue, m_fMinimum, m_fMaximum)); }

    void changeValue(float64 fRawValue) {
        float64 fNewValue = snapToStep(clamp(fRawValue, m_fMinimum, m_fMaximum));
        if (fNewValue == m_fValue) { return; }
        m_fValue = fNewValue;
        if (callbacksAllowed()) { notifyValueChanged(); }
    }

    float64 measureHeight(UiContext& objUiContext, float64 fWidth) override { return rowHeight(objUiContext); }

    void update(UiContext& objUiContext) override {
        updateKeybindButton(objUiContext, m_objRectBounds);
        updateKeyboard(objUiContext);
        updateValueBox(objUiContext);
        updateRail(objUiContext);
    }

    void draw(UiContext& objUiContext) override {
        Painter& objPainter = objUiContext.painter();
        Rect objRectArea = railAreaBounds(objUiContext);
        Rect objRectRail = Rect(objRectArea.fX, objRectArea.centerY() - fRailHeight * 0.5, objRectArea.fWidth, fRailHeight);
        float64 fHandleX = objRectArea.fX + fHandleRadius + (objRectArea.fWidth - fHandleRadius * 2.0) * fraction();
        objPainter.fillRect(objRectRail, textColor(objUiContext, ColorRole::WidgetFill), fRailHeight * 0.5);
        objPainter.fillRect(objRectRail.takeLeft(fHandleX - objRectRail.fX), textColor(objUiContext, ColorRole::SelectionFill), fRailHeight * 0.5);

        WidgetVisuals objHandleVisuals = stateVisuals(objUiContext, m_fHoverBlend, m_fRailActiveBlend, 0.0);
        vec2 objVec2HandleCenter = vec2(fHandleX, objRectArea.centerY());
        float64 fRadius = fHandleRadius + objHandleVisuals.fExpansion;
        objPainter.fillCircle(objVec2HandleCenter, fRadius, objHandleVisuals.objColorFill);
        objPainter.strokeCircle(objVec2HandleCenter, fRadius, objHandleVisuals.objColorText, 1.0);

        m_objDragValueBox.draw(objUiContext, this, formatValue() + m_strSuffix, m_bEnabled);
        drawFocusRing(objUiContext, controlBounds(objUiContext));
        objPainter.drawTextInRect(m_strLabel, labelBesideControl(objUiContext), textColor(objUiContext, ColorRole::TextNormal), FontRole::Body, HorizontalAlignment::Left);
        drawKeybindButton(objUiContext);
    }

public:
    SliderBase(const std::string& strLabel, float64 fMinimum, float64 fMaximum)
        : Component(strLabel), m_fMinimum(fmin(fMinimum, fMaximum)), m_fMaximum(fmax(fMinimum, fMaximum)), m_fValue(fmin(fMinimum, fMaximum)) {}

    bool isEditingValue() const { return m_objDragValueBox.isEditing(); }
};

class SliderInt : public SliderBase {
    IntCallback m_fnOnChange = null;

protected:
    float64 snapToStep(float64 fRawValue) const override { return round(fRawValue); }
    std::string formatValue() const override { return std::to_string(value()); }
    float64 keyboardStep() const override { return 1.0; }
    void notifyValueChanged() override {
        if (m_fnOnChange != null) { m_fnOnChange(value()); }
    }

public:
    SliderInt(const std::string& strLabel, int64 iMinimum, int64 iMaximum, int64 iValue)
        : SliderBase(strLabel, static_cast<float64>(iMinimum), static_cast<float64>(iMaximum)) {
        assignValue(static_cast<float64>(iValue));
    }

    SliderInt* onChange(IntCallback fnOnChange) {
        m_fnOnChange = fnOnChange;
        return this;
    }

    SliderInt* setSuffix(const std::string& strSuffix) {
        m_strSuffix = strSuffix;
        return this;
    }

    int64 value() const { return static_cast<int64>(m_fValue); }
    void setValue(int64 iValue) { assignValue(static_cast<float64>(iValue)); }

    std::string typeName() const override { return "integer slider"; }
    ComponentValue copyValue() const override { return ComponentValue::ofInteger(value()); }

    bool pasteValue(UiContext& objUiContext, const ComponentValue& objValue, bool bApply) override {
        int64 iPasted = 0;
        if (!values::tryReadInteger(objValue, iPasted)) { return false; }
        if (bApply) { changeValue(static_cast<float64>(iPasted)); }
        return true;
    }
};

class SliderFloat : public SliderBase {
    FloatCallback m_fnOnChange = null;
    int64 m_iDecimals = 2;

protected:
    float64 snapToStep(float64 fRawValue) const override {
        float64 fStep = pow(10.0, static_cast<float64>(m_iDecimals));
        return round(fRawValue * fStep) / fStep;
    }

    std::string formatValue() const override {
        float64 fDisplayedValue = m_fValue;
        int64 iDisplayedDecimals = m_iDecimals;
        return std::format("{:.{}f}", fDisplayedValue, iDisplayedDecimals);
    }

    float64 keyboardStep() const override {
        return fmax(pow(10.0, -static_cast<float64>(m_iDecimals)), snapToStep((m_fMaximum - m_fMinimum) / 100.0));
    }

    void notifyValueChanged() override {
        if (m_fnOnChange != null) { m_fnOnChange(m_fValue); }
    }

public:
    SliderFloat(const std::string& strLabel, float64 fMinimum, float64 fMaximum, float64 fValue)
        : SliderBase(strLabel, fMinimum, fMaximum) {
        assignValue(fValue);
    }

    SliderFloat* onChange(FloatCallback fnOnChange) {
        m_fnOnChange = fnOnChange;
        return this;
    }

    SliderFloat* setSuffix(const std::string& strSuffix) {
        m_strSuffix = strSuffix;
        return this;
    }

    SliderFloat* setDecimals(int64 iDecimals) {
        m_iDecimals = clamp(iDecimals, static_cast<int64>(0), static_cast<int64>(6));
        assignValue(m_fValue);
        return this;
    }

    float64 value() const { return m_fValue; }
    void setValue(float64 fValue) { assignValue(fValue); }

    std::string typeName() const override { return "decimal slider"; }
    ComponentValue copyValue() const override { return ComponentValue::ofFloat(m_fValue); }

    bool pasteValue(UiContext& objUiContext, const ComponentValue& objValue, bool bApply) override {
        float64 fPasted = 0.0;
        if (!values::tryReadFloat(objValue, fPasted)) { return false; }
        if (bApply) { changeValue(fPasted); }
        return true;
    }
};

}
