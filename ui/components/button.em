#pragma once

namespace ui {

class Button : public Component {
    ClickCallback m_fnOnClick = null;
    bool m_bPressStartedInside = false;
    float64 m_fPressBlend = 0.0;

    Rect buttonBounds(UiContext& objUiContext) {
        const ThemeMetrics& objThemeMetrics = objUiContext.metrics();
        Rect objRectRow = rowBounds(objUiContext);
        float64 fTextWidth = objUiContext.painter().measureText(m_strLabel, FontRole::Body).x;
        float64 fWidth = clamp(fTextWidth + objThemeMetrics.fButtonPadding * 2.0, objThemeMetrics.fInteractHeight * 2.0, objRectRow.fWidth);
        return Rect(objRectRow.fX, objRectRow.centerY() - objThemeMetrics.fInteractHeight * 0.5, fWidth, objThemeMetrics.fInteractHeight);
    }

    void click() {
        if (m_fnOnClick != null && callbacksAllowed()) { m_fnOnClick(); }
    }

public:
    Button(const std::string& strLabel) : Component(strLabel) {}

    Button* onClick(ClickCallback fnOnClick) {
        m_fnOnClick = fnOnClick;
        return this;
    }

    std::string typeName() const override { return "button"; }

protected:
    float64 measureHeight(UiContext& objUiContext, float64 fWidth) override { return rowHeight(objUiContext); }

    void update(UiContext& objUiContext) override {
        Rect objRectButton = buttonBounds(objUiContext);
        bool bHoveredNow = isInteractive(objUiContext, objRectButton);
        trackHover(objUiContext, bHoveredNow);
        updateKeybindButton(objUiContext, m_objRectBounds);
        InputState& objInputState = objUiContext.input();
        if (activationKeyPressed(objUiContext)) { click(); }

        if (bHoveredNow && objInputState.isMousePressed()) {
            objInputState.consumeMousePress();
            takeFocus(objUiContext);
            m_bPressStartedInside = true;
        }
        if (m_bPressStartedInside && objInputState.isMouseReleased()) {
            m_bPressStartedInside = false;
            if (bHoveredNow) { click(); }
        }
        if (!objInputState.isMouseDown() && !objInputState.isMouseReleased()) { m_bPressStartedInside = false; }
        m_fPressBlend = approachValue(m_fPressBlend, m_bPressStartedInside && bHoveredNow ? 1.0 : 0.0, objUiContext.animationStep() * 2.0);
    }

    void draw(UiContext& objUiContext) override {
        Painter& objPainter = objUiContext.painter();
        float64 fRounding = objUiContext.metrics().fWidgetRounding;
        WidgetVisuals objWidgetVisuals = stateVisuals(objUiContext, m_fHoverBlend, m_fPressBlend, 0.0);
        Rect objRectButton = buttonBounds(objUiContext).expanded(objWidgetVisuals.fExpansion);
        objPainter.fillRect(objRectButton, objWidgetVisuals.objColorFill, fRounding);
        objPainter.strokeRect(objRectButton, objWidgetVisuals.objColorStroke, 1.0, fRounding);
        objPainter.drawTextInRect(m_strLabel, objRectButton.shrunk(4.0), objWidgetVisuals.objColorText, FontRole::Body, HorizontalAlignment::Center);
        drawFocusRing(objUiContext, buttonBounds(objUiContext));
        drawKeybindButton(objUiContext);
    }
};

}
