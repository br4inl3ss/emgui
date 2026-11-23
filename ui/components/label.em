#pragma once

namespace ui {

class Label : public Component {
    ClickCallback m_fnOnClick = null;
    FontRole m_eFontRole = FontRole::Body;

    Rect textBounds(UiContext& objUiContext) {
        Rect objRectRow = rowBounds(objUiContext);
        float64 fTextWidth = objUiContext.painter().measureText(m_strLabel, m_eFontRole).x;
        return objRectRow.takeLeft(fTextWidth);
    }

    void click() {
        if (m_fnOnClick != null && callbacksAllowed()) { m_fnOnClick(); }
    }

public:
    Label(const std::string& strText) : Component(strText) {}

    Label* onClick(ClickCallback fnOnClick) {
        m_fnOnClick = fnOnClick;
        return this;
    }

    Label* setText(const std::string& strText) {
        m_strLabel = strText;
        return this;
    }

    Label* setFontRole(FontRole eFontRole) {
        m_eFontRole = eFontRole;
        return this;
    }

    const std::string& text() const { return m_strLabel; }

    bool acceptsKeyboardFocus() const override { return m_bEnabled && m_fnOnClick != null; }
    std::string typeName() const override { return "label"; }
    ComponentValue copyValue() const override { return ComponentValue::ofText(m_strLabel); }

protected:
    float64 measureHeight(UiContext& objUiContext, float64 fWidth) override {
        return fmax(rowHeight(objUiContext), objUiContext.painter().lineHeight(m_eFontRole));
    }

    void update(UiContext& objUiContext) override {
        bool bHoveredNow = m_fnOnClick != null && isInteractive(objUiContext, textBounds(objUiContext));
        trackHover(objUiContext, bHoveredNow);
        updateKeybindButton(objUiContext, m_objRectBounds);
        if (activationKeyPressed(objUiContext)) { click(); }
        if (!bHoveredNow || !objUiContext.input().isMousePressed()) { return; }
        objUiContext.input().consumeMousePress();
        takeFocus(objUiContext);
        click();
    }

    void draw(UiContext& objUiContext) override {
        Painter& objPainter = objUiContext.painter();
        Rect objRectRow = rowBounds(objUiContext);
        color objColorText = textColor(objUiContext, m_fnOnClick != null ? ColorRole::Hyperlink : ColorRole::TextNormal);
        objPainter.drawTextInRect(m_strLabel, objRectRow, objColorText, m_eFontRole, HorizontalAlignment::Left);
        float64 fUnderlineStrength = fmax(m_fHoverBlend, isFocused(objUiContext) ? 1.0 : 0.0);
        if (m_fnOnClick != null && fUnderlineStrength > 0.0) {
            Rect objRectText = textBounds(objUiContext);
            float64 fUnderlineY = objRectText.centerY() + objPainter.lineHeight(m_eFontRole) * 0.5 - 1.0;
            objPainter.drawLine(vec2(objRectText.fX, fUnderlineY), vec2(objRectText.right(), fUnderlineY),
                objColorText.with_alpha(static_cast<uint8>(static_cast<float64>(objColorText.a) * fUnderlineStrength)), 1.0);
        }
        drawKeybindButton(objUiContext);
    }
};

}
