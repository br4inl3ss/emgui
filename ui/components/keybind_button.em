#pragma once

namespace ui {

class KeybindButton : public Popup {
    static constexpr float64 fMinimumWidth = 26.0;
    static constexpr float64 fMaximumWidth = 76.0;
    static constexpr float64 fHorizontalPadding = 6.0;
    static constexpr float64 fMenuWidth = 118.0;
    static constexpr float64 fMenuGap = 4.0;
    static constexpr int64 iModeCount = 3;

    Keybind* m_pKeybind;
    const Element* m_pElementOwner;
    Rect m_objRectButton;
    bool m_bListening = false;
    float64 m_fHoverBlend = 0.0;
    float64 m_fListeningBlend = 0.0;

    std::string keyLabel(UiContext& objUiContext) const {
        if (m_bListening) { return "..."; }
        if (m_pKeybind->key() == 0) { return "None"; }
        std::string strKeyName = objUiContext.platform().keyName(m_pKeybind->key());
        if (strKeyName.empty()) { return std::format("0x{:02X}", m_pKeybind->key()); }
        return strKeyName.size() == 1 ? std::to_upper(strKeyName) : strKeyName;
    }

    void stopListening(UiContext& objUiContext) {
        m_bListening = false;
        objUiContext.releaseKeyboard(this);
    }

    void listenForKey(UiContext& objUiContext, bool bHovered) {
        InputState& objInputState = objUiContext.input();
        int64 iPressedKey = objInputState.firstPressedKey();
        if (iPressedKey == 0) { return; }
        if (iPressedKey == vk::lbutton && !bHovered) {
            stopListening(objUiContext);
            return;
        }
        m_pKeybind->setKey(iPressedKey == vk::escape ? 0 : iPressedKey);
        if (iPressedKey == vk::lbutton) { objInputState.consumeMousePress(); }
        stopListening(objUiContext);
    }

    static KeybindMode modeAt(int64 iIndex) {
        if (iIndex == 1) { return KeybindMode::OnToggle; }
        if (iIndex == 2) { return KeybindMode::OffHotkey; }
        return KeybindMode::AlwaysOn;
    }

    Rect menuItemBounds(UiContext& objUiContext, int64 iIndex) {
        Rect objRectMenu = popupBounds(objUiContext);
        float64 fPadding = objUiContext.metrics().fMenuPadding;
        float64 fItemHeight = objUiContext.metrics().fInteractHeight;
        return Rect(objRectMenu.fX + fPadding, objRectMenu.fY + fPadding + fItemHeight * static_cast<float64>(iIndex), objRectMenu.fWidth - fPadding * 2.0, fItemHeight);
    }

public:
    KeybindButton(Keybind* pKeybind, const Element* pElementOwner) : m_pKeybind(pKeybind), m_pElementOwner(pElementOwner) {}

    float64 preferredWidth(UiContext& objUiContext) {
        float64 fTextWidth = objUiContext.painter().measureText(keyLabel(objUiContext), FontRole::Small).x;
        return clamp(fTextWidth + fHorizontalPadding * 2.0, fMinimumWidth, fMaximumWidth);
    }

    float64 height(const UiContext& objUiContext) const { return objUiContext.metrics().fInteractHeight - 4.0; }

    void update(UiContext& objUiContext, const Rect& objRectButton) {
        m_objRectButton = objRectButton;
        bool bHovered = objUiContext.isMouseOver(m_objRectButton);
        m_fHoverBlend = approachValue(m_fHoverBlend, bHovered ? 1.0 : 0.0, objUiContext.animationStep());
        m_fListeningBlend = approachValue(m_fListeningBlend, m_bListening ? 1.0 : 0.0, objUiContext.animationStep());

        if (m_bListening) {
            listenForKey(objUiContext, bHovered);
            return;
        }
        if (!bHovered) { return; }
        if (objUiContext.input().isMousePressed()) {
            objUiContext.input().consumeMousePress();
            m_bListening = true;
            objUiContext.focusKeyboard(this, false);
        } else if (objUiContext.input().isSecondaryMousePressed()) {
            objUiContext.input().consumeMousePress();
            objUiContext.openPopup(this);
        }
    }

    void draw(UiContext& objUiContext) {
        Painter& objPainter = objUiContext.painter();
        WidgetVisuals objWidgetVisuals = m_pElementOwner->widgetVisuals(objUiContext, m_fHoverBlend, 0.0, 0.0);
        float64 fRounding = objUiContext.metrics().fWidgetRounding;
        objPainter.fillRect(m_objRectButton, objWidgetVisuals.objColorFill, fRounding);
        color objColorSelection = m_pElementOwner->colorOf(objUiContext, ColorRole::SelectionStroke);
        color objColorStroke = objWidgetVisuals.objColorStroke.lerp(objColorSelection, m_fListeningBlend);
        objPainter.strokeRect(m_objRectButton, objColorStroke, 1.0, fRounding);
        color objColorText = objWidgetVisuals.objColorText.lerp(objColorSelection, m_fListeningBlend);
        objPainter.drawTextInRect(keyLabel(objUiContext), m_objRectButton.shrunk(2.0), objColorText, FontRole::Small, HorizontalAlignment::Center);
    }

    Rect popupBounds(UiContext& objUiContext) override {
        float64 fHeight = objUiContext.metrics().fInteractHeight * static_cast<float64>(iModeCount) + objUiContext.metrics().fMenuPadding * 2.0;
        return Rect(m_objRectButton.right() - fMenuWidth, m_objRectButton.bottom() + fMenuGap, fMenuWidth, fHeight);
    }

    void updatePopup(UiContext& objUiContext) override {
        if (!objUiContext.input().isMousePressed()) { return; }
        for (int64 iIndex = 0; iIndex < iModeCount; iIndex++) {
            if (!objUiContext.isMouseOver(menuItemBounds(objUiContext, iIndex))) { continue; }
            objUiContext.input().consumeMousePress();
            m_pKeybind->setMode(modeAt(iIndex));
            objUiContext.closePopup();
            return;
        }
    }

    void drawPopup(UiContext& objUiContext) override {
        Painter& objPainter = objUiContext.painter();
        const ThemeMetrics& objThemeMetrics = objUiContext.metrics();
        Rect objRectMenu = popupBounds(objUiContext);
        objPainter.drawShadow(objRectMenu, objThemeMetrics.fMenuRounding, m_pElementOwner->colorOf(objUiContext, ColorRole::WindowShadow), 8.0, vec2(3.0, 5.0));
        objPainter.fillRect(objRectMenu, m_pElementOwner->colorOf(objUiContext, ColorRole::WindowFill), objThemeMetrics.fMenuRounding);
        objPainter.strokeRect(objRectMenu, m_pElementOwner->colorOf(objUiContext, ColorRole::WindowStroke), 1.0, objThemeMetrics.fMenuRounding);
        for (int64 iIndex = 0; iIndex < iModeCount; iIndex++) {
            Rect objRectItem = menuItemBounds(objUiContext, iIndex);
            KeybindMode eMode = modeAt(iIndex);
            bool bSelected = m_pKeybind->mode() == eMode;
            bool bHovered = objUiContext.isMouseOver(objRectItem);
            color objColorText = m_pElementOwner->colorOf(objUiContext, ColorRole::WidgetText);
            if (bSelected) {
                objPainter.fillRect(objRectItem, m_pElementOwner->colorOf(objUiContext, ColorRole::SelectionFill), objThemeMetrics.fWidgetRounding);
                objColorText = m_pElementOwner->colorOf(objUiContext, ColorRole::SelectionStroke);
            } else if (bHovered) {
                objPainter.fillRect(objRectItem, m_pElementOwner->colorOf(objUiContext, ColorRole::WidgetHoveredFill), objThemeMetrics.fWidgetRounding);
                objPainter.strokeRect(objRectItem, m_pElementOwner->colorOf(objUiContext, ColorRole::WidgetHoveredStroke), 1.0, objThemeMetrics.fWidgetRounding);
                objColorText = m_pElementOwner->colorOf(objUiContext, ColorRole::WidgetHoveredText);
            }
            objPainter.drawTextInRect(Keybind::modeName(eMode), objRectItem.withoutLeft(6.0), objColorText, FontRole::Body, HorizontalAlignment::Left);
        }
    }
};

}
