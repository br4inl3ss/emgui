#pragma once

namespace ui {

class DragValueBox {
    static constexpr float64 fClickDragThreshold = 3.0;
    static constexpr float64 fTextInset = 4.0;
    static constexpr float64 fDisabledOpacity = 0.45;

    Rect m_objRectBox;
    float64 m_fHoverBlend = 0.0;
    float64 m_fActiveBlend = 0.0;
    bool m_bDragged = false;
    float64 m_fPressMouseX = 0.0;
    float64 m_fDragValue = 0.0;
    bool m_bEditing = false;
    TextEditBuffer m_objTextEditBuffer;

    void stopEditing(UiContext& objUiContext) {
        m_bEditing = false;
        m_objTextEditBuffer.resetScroll();
        objUiContext.releaseKeyboard(this);
    }

    bool commitEditing(UiContext& objUiContext, float64& fValue, float64 fMinimum, float64 fMaximum) {
        float64 fTyped = 0.0;
        bool bParsed = values::tryParseNumber(m_objTextEditBuffer.text(), fTyped);
        stopEditing(objUiContext);
        if (!bParsed) { return false; }
        float64 fNewValue = clamp(fTyped, fMinimum, fMaximum);
        if (fNewValue == fValue) { return false; }
        fValue = fNewValue;
        return true;
    }

    static color withOpacity(color objColorValue, bool bEnabled) {
        if (bEnabled) { return objColorValue; }
        return objColorValue.with_alpha(static_cast<uint8>(static_cast<float64>(objColorValue.a) * fDisabledOpacity));
    }

public:
    bool isEditing() const { return m_bEditing; }
    const Rect& bounds() const { return m_objRectBox; }

    void cancelEditing(UiContext& objUiContext) {
        if (m_bEditing) { stopEditing(objUiContext); }
        objUiContext.releaseMouse(this);
    }

    void beginEditing(UiContext& objUiContext, const std::string& strCurrentValue) {
        m_bEditing = true;
        m_objTextEditBuffer.setMaximumLength(32);
        m_objTextEditBuffer.setText(strCurrentValue);
        m_objTextEditBuffer.selectAll(objUiContext);
        objUiContext.releaseMouse(this);
        objUiContext.focusKeyboard(this, true);
    }

    bool update(UiContext& objUiContext, const Rect& objRectBox, float64& fValue, float64 fMinimum, float64 fMaximum, float64 fValuePerPixel,
                const std::string& strEditText, bool bEnabled) {
        m_objRectBox = objRectBox;
        InputState& objInputState = objUiContext.input();
        bool bDragging = objUiContext.isMouseCapturedBy(this);
        bool bHovered = bEnabled && objUiContext.isMouseOver(objRectBox);
        float64 fStep = objUiContext.animationStep();
        m_fHoverBlend = approachValue(m_fHoverBlend, bHovered || bDragging || m_bEditing ? 1.0 : 0.0, fStep);
        m_fActiveBlend = approachValue(m_fActiveBlend, bDragging && m_bDragged ? 1.0 : 0.0, fStep);

        if (m_bEditing) {
            if (!bEnabled || objInputState.isKeyPressed(vk::escape)) {
                stopEditing(objUiContext);
                return false;
            }
            if (objInputState.isMousePressed() && !objRectBox.contains(objInputState.mousePosition())) {
                return commitEditing(objUiContext, fValue, fMinimum, fMaximum);
            }
            if (objInputState.isMousePressed()) {
                objInputState.consumeMousePress();
                m_objTextEditBuffer.placeCaret(objUiContext, objInputState.mousePosition().x - objRectBox.fX - fTextInset);
            }
            m_objTextEditBuffer.applyEditingKeys(objUiContext);
            m_objTextEditBuffer.keepCaretVisible(objUiContext, objRectBox.fWidth - fTextInset * 2.0);
            if (objInputState.isKeyPressed(vk::enter) || objInputState.isKeyPressed(vk::tab)) {
                return commitEditing(objUiContext, fValue, fMinimum, fMaximum);
            }
            return false;
        }

        if (bDragging) {
            float64 fMouseX = objInputState.mousePosition().x;
            if (fabs(fMouseX - m_fPressMouseX) >= fClickDragThreshold) { m_bDragged = true; }
            bool bChanged = false;
            if (m_bDragged) {
                m_fDragValue = clamp(m_fDragValue + objInputState.mouseDelta().x * fValuePerPixel, fMinimum, fMaximum);
                if (m_fDragValue != fValue) {
                    fValue = m_fDragValue;
                    bChanged = true;
                }
            }
            if (!objInputState.isMouseDown()) {
                objUiContext.releaseMouse(this);
                if (!m_bDragged) { beginEditing(objUiContext, strEditText); }
            }
            return bChanged;
        }

        if (!bHovered || !objInputState.isMousePressed()) { return false; }
        objInputState.consumeMousePress();
        if (objInputState.isControlDown()) {
            beginEditing(objUiContext, strEditText);
            return false;
        }
        objUiContext.captureMouse(this);
        m_bDragged = false;
        m_fPressMouseX = objInputState.mousePosition().x;
        m_fDragValue = fValue;
        return false;
    }

    void draw(UiContext& objUiContext, const Element* pElementOwner, const std::string& strDisplay, bool bEnabled) {
        Painter& objPainter = objUiContext.painter();
        float64 fRounding = objUiContext.metrics().fWidgetRounding;
        if (m_bEditing) {
            objPainter.fillRect(m_objRectBox, pElementOwner->colorOf(objUiContext, ColorRole::ExtremeBackground), fRounding);
            objPainter.strokeRect(m_objRectBox, pElementOwner->colorOf(objUiContext, ColorRole::SelectionStroke), 1.0, fRounding);
            m_objTextEditBuffer.draw(objUiContext, m_objRectBox.shrunk(fTextInset), pElementOwner->colorOf(objUiContext, ColorRole::WidgetText),
                pElementOwner->colorOf(objUiContext, ColorRole::SelectionStroke), pElementOwner->colorOf(objUiContext, ColorRole::SelectionFill), true);
            return;
        }
        WidgetVisuals objWidgetVisuals = pElementOwner->widgetVisuals(objUiContext, m_fHoverBlend, m_fActiveBlend, 0.0);
        Rect objRectExpanded = m_objRectBox.expanded(objWidgetVisuals.fExpansion);
        objPainter.fillRect(objRectExpanded, withOpacity(objWidgetVisuals.objColorFill, bEnabled), fRounding);
        objPainter.strokeRect(objRectExpanded, withOpacity(objWidgetVisuals.objColorStroke, bEnabled), 1.0, fRounding);
        objPainter.drawTextInRect(strDisplay, objRectExpanded.shrunk(2.0), withOpacity(objWidgetVisuals.objColorText, bEnabled), FontRole::Body, HorizontalAlignment::Center);
    }
};

}
