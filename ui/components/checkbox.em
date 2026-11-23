#pragma once

namespace ui {

class Checkbox : public Component {
    bool m_bChecked;
    float64 m_fCheckBlend;
    BoolCallback m_fnOnChange = null;

    Rect boxBounds(UiContext& objUiContext) {
        float64 fBoxSize = objUiContext.metrics().fCheckboxSize;
        return Rect(m_objRectBounds.fX, m_objRectBounds.centerY() - fBoxSize * 0.5, fBoxSize, fBoxSize);
    }

    Rect labelBounds(UiContext& objUiContext) {
        const ThemeMetrics& objThemeMetrics = objUiContext.metrics();
        return rowBounds(objUiContext).withoutLeft(objThemeMetrics.fCheckboxSize + objThemeMetrics.fIconSpacing);
    }

    Rect clickableBounds(UiContext& objUiContext) {
        Rect objRectLabel = labelBounds(objUiContext);
        float64 fTextWidth = fmin(objUiContext.painter().measureText(m_strLabel, FontRole::Body).x, objRectLabel.fWidth);
        return Rect(m_objRectBounds.fX, m_objRectBounds.fY, objRectLabel.fX - m_objRectBounds.fX + fTextWidth, m_objRectBounds.fHeight);
    }

    void changeChecked(bool bChecked) {
        if (bChecked == m_bChecked) { return; }
        m_bChecked = bChecked;
        if (m_fnOnChange != null && callbacksAllowed()) { m_fnOnChange(m_bChecked); }
    }

public:
    Checkbox(const std::string& strLabel, bool bChecked)
        : Component(strLabel), m_bChecked(bChecked), m_fCheckBlend(bChecked ? 1.0 : 0.0) {}

    Checkbox* onChange(BoolCallback fnOnChange) {
        m_fnOnChange = fnOnChange;
        return this;
    }

    bool isChecked() const { return m_bChecked; }
    void setChecked(bool bChecked) { m_bChecked = bChecked; }

    std::string typeName() const override { return "checkbox"; }
    ComponentValue copyValue() const override { return ComponentValue::ofBoolean(m_bChecked); }

    bool pasteValue(UiContext& objUiContext, const ComponentValue& objValue, bool bApply) override {
        bool bPasted = false;
        if (!values::tryReadBoolean(objValue, bPasted)) { return false; }
        if (bApply) { changeChecked(bPasted); }
        return true;
    }

protected:
    float64 measureHeight(UiContext& objUiContext, float64 fWidth) override { return rowHeight(objUiContext); }

    void update(UiContext& objUiContext) override {
        bool bHoveredNow = isInteractive(objUiContext, clickableBounds(objUiContext));
        trackHover(objUiContext, bHoveredNow);
        updateKeybindButton(objUiContext, m_objRectBounds);
        m_fCheckBlend = approachValue(m_fCheckBlend, m_bChecked ? 1.0 : 0.0, objUiContext.animationStep());
        if (activationKeyPressed(objUiContext)) { changeChecked(!m_bChecked); }
        if (!bHoveredNow || !objUiContext.input().isMousePressed()) { return; }
        objUiContext.input().consumeMousePress();
        takeFocus(objUiContext);
        changeChecked(!m_bChecked);
    }

    void draw(UiContext& objUiContext) override {
        Painter& objPainter = objUiContext.painter();
        float64 fRounding = objUiContext.metrics().fWidgetRounding;
        WidgetVisuals objWidgetVisuals = stateVisuals(objUiContext, m_fHoverBlend, 0.0, 0.0);
        Rect objRectBox = boxBounds(objUiContext).expanded(objWidgetVisuals.fExpansion);
        objPainter.fillRect(objRectBox, objWidgetVisuals.objColorFill, fRounding);
        objPainter.strokeRect(objRectBox, objWidgetVisuals.objColorStroke, 1.0, fRounding);
        objPainter.drawCheckMark(boxBounds(objUiContext), objWidgetVisuals.objColorText, m_fCheckBlend);
        objPainter.drawTextInRect(m_strLabel, labelBounds(objUiContext), objWidgetVisuals.objColorText, FontRole::Body, HorizontalAlignment::Left);
        drawFocusRing(objUiContext, boxBounds(objUiContext));
        drawKeybindButton(objUiContext);
    }
};

}
