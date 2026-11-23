#pragma once

namespace ui {

class Child;

class Component : public Element {
    friend class Child;

    std::unique_ptr<KeybindButton> m_upKeybindButton;
    int64 m_iTabOrder = -1;

    void arrange(const Rect& objRectBounds) { m_objRectBounds = objRectBounds; }
    void offerContextMenu(UiContext& objUiContext);

protected:
    static constexpr float64 fDisabledOpacity = 0.45;

    bool m_bEnabled = true;
    Keybind* m_pKeybind = null;

    bool callbacksAllowed() const { return m_bEnabled && (m_pKeybind == null || m_pKeybind->isActive()); }

    float64 keybindReservedWidth(UiContext& objUiContext) {
        if (m_upKeybindButton == null) { return 0.0; }
        return m_upKeybindButton->preferredWidth(objUiContext) + objUiContext.metrics().fIconSpacing;
    }

    void updateKeybindButton(UiContext& objUiContext, const Rect& objRectRow) {
        if (m_upKeybindButton == null) { return; }
        float64 fWidth = m_upKeybindButton->preferredWidth(objUiContext);
        float64 fHeight = m_upKeybindButton->height(objUiContext);
        Rect objRectButton = Rect(objRectRow.right() - fWidth, objRectRow.centerY() - fHeight * 0.5, fWidth, fHeight);
        m_upKeybindButton->update(objUiContext, objRectButton);
    }

    void drawKeybindButton(UiContext& objUiContext) {
        if (m_upKeybindButton != null) { m_upKeybindButton->draw(objUiContext); }
    }

    float64 rowHeight(const UiContext& objUiContext) const { return objUiContext.metrics().fInteractHeight; }

    Rect rowBounds(UiContext& objUiContext) { return m_objRectBounds.withoutRight(keybindReservedWidth(objUiContext)); }

    Rect controlBounds(UiContext& objUiContext) {
        Rect objRectRow = rowBounds(objUiContext);
        return objRectRow.takeLeft(round(objRectRow.fWidth * objUiContext.metrics().fControlWidthRatio));
    }

    Rect labelBesideControl(UiContext& objUiContext) {
        Rect objRectRow = rowBounds(objUiContext);
        return objRectRow.withoutLeft(controlBounds(objUiContext).fWidth + objUiContext.metrics().fIconSpacing);
    }

    color faded(color objColorValue) const {
        if (m_bEnabled) { return objColorValue; }
        return objColorValue.with_alpha(static_cast<uint8>(static_cast<float64>(objColorValue.a) * fDisabledOpacity));
    }

    color textColor(const UiContext& objUiContext, ColorRole eRole) const { return faded(colorOf(objUiContext, eRole)); }

    WidgetVisuals stateVisuals(const UiContext& objUiContext, float64 fHoverBlend, float64 fActiveBlend, float64 fOpenBlend) const {
        WidgetVisuals objWidgetVisuals = widgetVisuals(objUiContext, fHoverBlend, fActiveBlend, fOpenBlend);
        objWidgetVisuals.objColorFill = faded(objWidgetVisuals.objColorFill);
        objWidgetVisuals.objColorStroke = faded(objWidgetVisuals.objColorStroke);
        objWidgetVisuals.objColorText = faded(objWidgetVisuals.objColorText);
        return objWidgetVisuals;
    }

    bool isInteractive(UiContext& objUiContext, const Rect& objRectHit) const {
        return m_bEnabled && objUiContext.isMouseOver(objRectHit);
    }

    bool isFocused(const UiContext& objUiContext) const { return objUiContext.isFocused(this); }

    void takeFocus(UiContext& objUiContext) {
        if (acceptsKeyboardFocus()) { objUiContext.setFocus(this); }
    }

    bool acceptsKeyboardInput(const UiContext& objUiContext) const {
        return m_bEnabled && isFocused(objUiContext) && !objUiContext.isKeyboardCaptured() && !objUiContext.wasKeyboardReleasedThisFrame();
    }

    bool activationKeyPressed(UiContext& objUiContext) const {
        return acceptsKeyboardInput(objUiContext) && (objUiContext.input().isKeyPressed(vk::enter) || objUiContext.input().isKeyPressed(vk::space));
    }

    void drawFocusRing(UiContext& objUiContext, const Rect& objRectFocused) {
        if (!isFocused(objUiContext)) { return; }
        objUiContext.painter().strokeRect(objRectFocused.expanded(2.0), colorOf(objUiContext, ColorRole::SelectionStroke), 1.0, objUiContext.metrics().fWidgetRounding + 1.0);
    }

    virtual float64 measureHeight(UiContext& objUiContext, float64 fWidth) = 0;
    virtual void update(UiContext& objUiContext) = 0;
    virtual void draw(UiContext& objUiContext) = 0;

public:
    Component(const std::string& strLabel) : Element(strLabel) {}

    bool isEnabled() const { return m_bEnabled; }
    void setEnabled(bool bEnabled) { m_bEnabled = bEnabled; }

    Keybind* bindKey(int64 iVirtualKey, KeybindMode eMode) {
        if (m_pKeybind == null) {
            m_pKeybind = m_pKeybindRegistry->create(m_strLabel, iVirtualKey, eMode);
            m_upKeybindButton = std::make_unique<KeybindButton>(m_pKeybind, this);
        } else {
            m_pKeybind->setKey(iVirtualKey);
            m_pKeybind->setMode(eMode);
        }
        return m_pKeybind;
    }

    Keybind* keybind() const { return m_pKeybind; }
    bool isKeybindActive() const { return m_pKeybind == null || m_pKeybind->isActive(); }

    void setTabOrder(int64 iTabOrder) { m_iTabOrder = iTabOrder; }
    int64 tabOrder() const { return m_iTabOrder; }
    bool hasTabOrder() const { return m_iTabOrder >= 0; }

    virtual bool acceptsKeyboardFocus() const { return m_bEnabled; }
    virtual std::string typeName() const = 0;
    virtual ComponentValue copyValue() const { return ComponentValue(); }
    virtual bool pasteValue(UiContext& objUiContext, const ComponentValue& objValue, bool bApply) { return false; }
};

}
