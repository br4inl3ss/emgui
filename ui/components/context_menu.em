#pragma once

namespace ui {

class ContextMenu : public Popup {
    static constexpr float64 fMenuWidth = 230.0;
    static constexpr int64 iCopyRow = 0;
    static constexpr int64 iPasteRow = 1;
    static constexpr int64 iHintRow = 2;
    static constexpr int64 iRowCount = 3;

    Component* m_pComponentTarget = null;
    vec2 m_objVec2Anchor = vec2(0.0, 0.0);
    ComponentValue m_objCopiedValue;
    std::string m_strMirroredClipboardText;

    Rect rowBounds(UiContext& objUiContext, int64 iRow) {
        Rect objRectMenu = popupBounds(objUiContext);
        float64 fPadding = objUiContext.metrics().fMenuPadding;
        float64 fRowHeight = objUiContext.metrics().fInteractHeight;
        return Rect(objRectMenu.fX + fPadding, objRectMenu.fY + fPadding + fRowHeight * static_cast<float64>(iRow), objRectMenu.fWidth - fPadding * 2.0, fRowHeight);
    }

    bool canCopy() const { return m_pComponentTarget != null && !m_pComponentTarget->copyValue().isEmpty(); }

    bool canPaste(UiContext& objUiContext) {
        ComponentValue objValue = clipboardValue(objUiContext);
        return m_pComponentTarget != null && !objValue.isEmpty() && m_pComponentTarget->pasteValue(objUiContext, objValue, false);
    }

    std::string pasteHint(UiContext& objUiContext) {
        ComponentValue objValue = clipboardValue(objUiContext);
        if (objValue.isEmpty()) { return "Clipboard is empty"; }
        if (!canPaste(objUiContext)) { return "Cannot paste " + objValue.kindName() + " into a " + m_pComponentTarget->typeName(); }
        return "Clipboard: " + objValue.displayText();
    }

    void drawRow(UiContext& objUiContext, int64 iRow, const std::string& strText, bool bEnabled) {
        Painter& objPainter = objUiContext.painter();
        const ThemeMetrics& objThemeMetrics = objUiContext.metrics();
        Rect objRectRow = rowBounds(objUiContext, iRow);
        bool bHovered = bEnabled && objUiContext.isMouseOver(objRectRow);
        WidgetVisuals objWidgetVisuals = m_pComponentTarget->widgetVisuals(objUiContext, bHovered ? 1.0 : 0.0, 0.0, 0.0);
        if (bHovered) {
            objPainter.fillRect(objRectRow, objWidgetVisuals.objColorFill, objThemeMetrics.fWidgetRounding);
            objPainter.strokeRect(objRectRow, objWidgetVisuals.objColorStroke, 1.0, objThemeMetrics.fWidgetRounding);
        }
        color objColorText = bEnabled ? objWidgetVisuals.objColorText : m_pComponentTarget->colorOf(objUiContext, ColorRole::TextWeak);
        objPainter.drawTextInRect(strText, objRectRow.withoutLeft(6.0).withoutRight(6.0), objColorText, FontRole::Body, HorizontalAlignment::Left);
    }

public:
    ComponentValue clipboardValue(UiContext& objUiContext) {
        std::string strSystemText = objUiContext.platform().clipboardText();
        if (!strSystemText.empty() && strSystemText != m_strMirroredClipboardText) { return ComponentValue::ofText(strSystemText); }
        return m_objCopiedValue;
    }

    bool copyFrom(UiContext& objUiContext, const Component* pComponent) {
        ComponentValue objValue = pComponent->copyValue();
        if (objValue.isEmpty()) { return false; }
        m_objCopiedValue = objValue;
        m_strMirroredClipboardText = objValue.displayText();
        objUiContext.platform().setClipboardText(m_strMirroredClipboardText);
        return true;
    }

    bool pasteInto(UiContext& objUiContext, Component* pComponent) {
        ComponentValue objValue = clipboardValue(objUiContext);
        return !objValue.isEmpty() && pComponent->pasteValue(objUiContext, objValue, true);
    }

    void openFor(UiContext& objUiContext, Component* pComponent, vec2 objVec2Anchor) {
        m_pComponentTarget = pComponent;
        m_objVec2Anchor = objVec2Anchor;
        objUiContext.openPopup(this);
    }

    Rect popupBounds(UiContext& objUiContext) override {
        const ThemeMetrics& objThemeMetrics = objUiContext.metrics();
        float64 fHeight = objThemeMetrics.fInteractHeight * static_cast<float64>(iRowCount) + objThemeMetrics.fMenuPadding * 2.0;
        const Rect& objRectView = objUiContext.viewBounds();
        float64 fX = fmin(m_objVec2Anchor.x, objRectView.right() - fMenuWidth);
        float64 fY = fmin(m_objVec2Anchor.y, objRectView.bottom() - fHeight);
        return Rect(fmax(objRectView.fX, fX), fmax(objRectView.fY, fY), fMenuWidth, fHeight);
    }

    void updatePopup(UiContext& objUiContext) override {
        if (m_pComponentTarget == null || !objUiContext.input().isMousePressed()) { return; }
        if (objUiContext.isMouseOver(rowBounds(objUiContext, iCopyRow)) && canCopy()) {
            objUiContext.input().consumeMousePress();
            copyFrom(objUiContext, m_pComponentTarget);
            objUiContext.closePopup();
        } else if (objUiContext.isMouseOver(rowBounds(objUiContext, iPasteRow)) && canPaste(objUiContext)) {
            objUiContext.input().consumeMousePress();
            pasteInto(objUiContext, m_pComponentTarget);
            objUiContext.closePopup();
        }
    }

    void drawPopup(UiContext& objUiContext) override {
        if (m_pComponentTarget == null) { return; }
        Painter& objPainter = objUiContext.painter();
        float64 fRounding = objUiContext.metrics().fMenuRounding;
        Rect objRectMenu = popupBounds(objUiContext);
        objPainter.drawShadow(objRectMenu, fRounding, m_pComponentTarget->colorOf(objUiContext, ColorRole::WindowShadow), 8.0, vec2(3.0, 5.0));
        objPainter.fillRect(objRectMenu, m_pComponentTarget->colorOf(objUiContext, ColorRole::WindowFill), fRounding);
        objPainter.strokeRect(objRectMenu, m_pComponentTarget->colorOf(objUiContext, ColorRole::WindowStroke), 1.0, fRounding);
        drawRow(objUiContext, iCopyRow, "Copy value", canCopy());
        drawRow(objUiContext, iPasteRow, "Paste value", canPaste(objUiContext));
        Rect objRectHint = rowBounds(objUiContext, iHintRow);
        objPainter.fillRect(Rect(objRectHint.fX, objRectHint.fY, objRectHint.fWidth, 1.0), m_pComponentTarget->colorOf(objUiContext, ColorRole::Separator), 0.0);
        objPainter.drawTextInRect(pasteHint(objUiContext), objRectHint.withoutLeft(6.0).withoutRight(6.0), m_pComponentTarget->colorOf(objUiContext, ColorRole::TextWeak),
            FontRole::Small, HorizontalAlignment::Left);
    }

    void onPopupClosed(UiContext& objUiContext) override { m_pComponentTarget = null; }
};

void Component::offerContextMenu(UiContext& objUiContext) {
    InputState& objInputState = objUiContext.input();
    if (objUiContext.contextMenu() == null || !objInputState.isSecondaryMousePressed()) { return; }
    if (!isInteractive(objUiContext, m_objRectBounds) || copyValue().isEmpty()) { return; }
    objInputState.consumeMousePress();
    objUiContext.contextMenu()->openFor(objUiContext, this, objInputState.mousePosition());
}

}
