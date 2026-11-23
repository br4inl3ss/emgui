#pragma once

namespace ui {

class Textfield : public Component {
    static constexpr float64 fTextInset = 5.0;

    TextEditBuffer m_objTextEditBuffer;
    std::string m_strPlaceholder;
    float64 m_fFocusBlend = 0.0;
    TextCallback m_fnOnChange = null;
    TextCallback m_fnOnSubmit = null;

    Rect boxBounds(UiContext& objUiContext) {
        Rect objRectControl = m_strLabel.empty() ? rowBounds(objUiContext) : controlBounds(objUiContext);
        float64 fHeight = rowHeight(objUiContext);
        return Rect(objRectControl.fX, objRectControl.centerY() - fHeight * 0.5, objRectControl.fWidth, fHeight);
    }

    Rect textViewport(UiContext& objUiContext) { return boxBounds(objUiContext).withoutLeft(fTextInset).withoutRight(fTextInset); }

    void notifyChanged() {
        if (m_fnOnChange != null && callbacksAllowed()) { m_fnOnChange(m_objTextEditBuffer.text()); }
    }

public:
    Textfield(const std::string& strLabel, const std::string& strPlaceholder) : Component(strLabel), m_strPlaceholder(strPlaceholder) {}

    Textfield* onChange(TextCallback fnOnChange) {
        m_fnOnChange = fnOnChange;
        return this;
    }

    Textfield* onSubmit(TextCallback fnOnSubmit) {
        m_fnOnSubmit = fnOnSubmit;
        return this;
    }

    Textfield* setMaximumLength(int64 iMaximumLength) {
        m_objTextEditBuffer.setMaximumLength(iMaximumLength);
        return this;
    }

    Textfield* setPlaceholder(const std::string& strPlaceholder) {
        m_strPlaceholder = strPlaceholder;
        return this;
    }

    const std::string& text() const { return m_objTextEditBuffer.text(); }
    void setText(const std::string& strText) { m_objTextEditBuffer.setText(strText); }

    std::string typeName() const override { return "text field"; }
    ComponentValue copyValue() const override { return ComponentValue::ofText(m_objTextEditBuffer.text()); }

    bool pasteValue(UiContext& objUiContext, const ComponentValue& objValue, bool bApply) override {
        std::string strPasted;
        if (!values::tryReadText(objValue, strPasted)) { return false; }
        if (!bApply) { return true; }
        m_objTextEditBuffer.setText(strPasted);
        notifyChanged();
        return true;
    }

protected:
    float64 measureHeight(UiContext& objUiContext, float64 fWidth) override { return rowHeight(objUiContext); }

    void update(UiContext& objUiContext) override {
        Rect objRectBox = boxBounds(objUiContext);
        bool bHoveredNow = isInteractive(objUiContext, objRectBox);
        trackHover(objUiContext, bHoveredNow);
        updateKeybindButton(objUiContext, m_objRectBounds);
        InputState& objInputState = objUiContext.input();

        bool bWasEditing = objUiContext.hasKeyboardFocus(this);
        if (bHoveredNow && objInputState.isMousePressed()) {
            objInputState.consumeMousePress();
            takeFocus(objUiContext);
            m_objTextEditBuffer.placeCaret(objUiContext, objInputState.mousePosition().x - textViewport(objUiContext).fX);
        }
        bool bFocused = m_bEnabled && isFocused(objUiContext);
        m_fFocusBlend = approachValue(m_fFocusBlend, bFocused ? 1.0 : 0.0, objUiContext.animationStep());
        if (!bFocused) {
            if (bWasEditing) {
                objUiContext.releaseKeyboard(this);
                m_objTextEditBuffer.resetScroll();
            }
            return;
        }
        if (!bWasEditing) { objUiContext.focusKeyboard(this, true); }

        bool bChanged = m_objTextEditBuffer.applyEditingKeys(objUiContext);
        m_objTextEditBuffer.keepCaretVisible(objUiContext, textViewport(objUiContext).fWidth);
        if (bChanged) { notifyChanged(); }

        if (objInputState.isKeyPressed(vk::enter)) {
            if (m_fnOnSubmit != null && callbacksAllowed()) { m_fnOnSubmit(m_objTextEditBuffer.text()); }
            objUiContext.clearFocus();
        } else if (objInputState.isKeyPressed(vk::escape)) {
            objUiContext.clearFocus();
        }
    }

    void draw(UiContext& objUiContext) override {
        Painter& objPainter = objUiContext.painter();
        float64 fRounding = objUiContext.metrics().fWidgetRounding;
        bool bEditing = objUiContext.hasKeyboardFocus(this);
        objPainter.drawTextInRect(m_strLabel, labelBesideControl(objUiContext), textColor(objUiContext, ColorRole::TextNormal), FontRole::Body, HorizontalAlignment::Left);
        drawKeybindButton(objUiContext);

        Rect objRectBox = boxBounds(objUiContext);
        color objColorBorder = textColor(objUiContext, ColorRole::WidgetStroke)
            .lerp(textColor(objUiContext, ColorRole::WidgetHoveredStroke), m_fHoverBlend)
            .lerp(textColor(objUiContext, ColorRole::SelectionStroke), m_fFocusBlend);
        objPainter.fillRect(objRectBox, textColor(objUiContext, ColorRole::ExtremeBackground), fRounding);
        objPainter.strokeRect(objRectBox, objColorBorder, 1.0, fRounding);

        Rect objRectViewport = textViewport(objUiContext);
        if (m_objTextEditBuffer.text().empty() && !bEditing) {
            objPainter.drawTextInRect(m_strPlaceholder, objRectViewport, textColor(objUiContext, ColorRole::TextWeak), FontRole::Body, HorizontalAlignment::Left);
            return;
        }
        m_objTextEditBuffer.draw(objUiContext, objRectViewport, textColor(objUiContext, ColorRole::WidgetText), textColor(objUiContext, ColorRole::SelectionStroke),
            textColor(objUiContext, ColorRole::SelectionFill), bEditing);
    }
};

}
