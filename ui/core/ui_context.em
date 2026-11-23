#pragma once

namespace ui {

class UiContext;

class Popup {
public:
    virtual ~Popup() {}
    virtual Rect popupBounds(UiContext& objUiContext) = 0;
    virtual void updatePopup(UiContext& objUiContext) = 0;
    virtual void drawPopup(UiContext& objUiContext) = 0;
    virtual void onPopupClosed(UiContext& objUiContext) {}
};

class ContextMenu;

class UiContext {
    Painter* m_pPainter;
    InputState* m_pInputState;
    Theme* m_pTheme;
    PlatformBackend* m_pPlatformBackend;

    const void* m_pMouseOwner = null;
    const void* m_pKeyboardOwner = null;
    bool m_bKeyboardOwnerAllowsTabNavigation = false;
    const void* m_pFocusedComponent = null;
    ContextMenu* m_pContextMenu = null;
    Popup* m_pPopupOpen = null;
    bool m_bMouseBlocked = false;
    bool m_bKeyboardReleasedThisFrame = false;
    std::vector<Rect> m_vecHitClipStack;
    Rect m_objRectView;

public:
    UiContext(Painter* pPainter, InputState* pInputState, Theme* pTheme, PlatformBackend* pPlatformBackend)
        : m_pPainter(pPainter), m_pInputState(pInputState), m_pTheme(pTheme), m_pPlatformBackend(pPlatformBackend) {}

    Painter& painter() { return *m_pPainter; }
    InputState& input() { return *m_pInputState; }
    const Theme& theme() const { return *m_pTheme; }
    const ThemeMetrics& metrics() const { return m_pTheme->metrics(); }
    PlatformBackend& platform() { return *m_pPlatformBackend; }

    float64 animationStep() const { return m_pInputState->deltaSeconds() * m_pTheme->metrics().fAnimationSpeed; }

    void beginFrame(const Rect& objRectView) {
        m_vecHitClipStack.clear();
        m_bMouseBlocked = false;
        m_bKeyboardReleasedThisFrame = false;
        m_objRectView = objRectView;
    }

    const Rect& viewBounds() const { return m_objRectView; }

    void setMouseBlocked(bool bBlocked) { m_bMouseBlocked = bBlocked; }

    bool isMouseOver(const Rect& objRect) const {
        if (m_bMouseBlocked || m_pMouseOwner != null) { return false; }
        vec2 objVec2Mouse = m_pInputState->mousePosition();
        if (!m_vecHitClipStack.empty() && !m_vecHitClipStack.back().contains(objVec2Mouse)) { return false; }
        return objRect.contains(objVec2Mouse);
    }

    void pushHitClip(const Rect& objRect) {
        m_vecHitClipStack.push_back(m_vecHitClipStack.empty() ? objRect : objRect.intersection(m_vecHitClipStack.back()));
    }

    void popHitClip() {
        if (!m_vecHitClipStack.empty()) { m_vecHitClipStack.pop_back(); }
    }

    bool isMouseCaptured() const { return m_pMouseOwner != null; }
    bool isMouseCapturedBy(const void* pOwner) const { return m_pMouseOwner == pOwner; }
    void captureMouse(const void* pOwner) { m_pMouseOwner = pOwner; }
    void releaseMouse(const void* pOwner) {
        if (m_pMouseOwner == pOwner) { m_pMouseOwner = null; }
    }

    bool isKeyboardCaptured() const { return m_pKeyboardOwner != null; }
    bool hasKeyboardFocus(const void* pOwner) const { return m_pKeyboardOwner == pOwner; }
    bool allowsTabNavigation() const { return m_pKeyboardOwner == null || m_bKeyboardOwnerAllowsTabNavigation; }

    void focusKeyboard(const void* pOwner, bool bAllowsTabNavigation) {
        m_pKeyboardOwner = pOwner;
        m_bKeyboardOwnerAllowsTabNavigation = bAllowsTabNavigation;
    }

    void releaseKeyboard(const void* pOwner) {
        if (m_pKeyboardOwner != pOwner || pOwner == null) { return; }
        m_pKeyboardOwner = null;
        m_bKeyboardReleasedThisFrame = true;
    }

    bool wasKeyboardReleasedThisFrame() const { return m_bKeyboardReleasedThisFrame; }

    const void* focusedComponent() const { return m_pFocusedComponent; }
    bool isFocused(const void* pComponent) const { return m_pFocusedComponent != null && m_pFocusedComponent == pComponent; }
    void setFocus(const void* pComponent) { m_pFocusedComponent = pComponent; }
    void clearFocus() { m_pFocusedComponent = null; }

    ContextMenu* contextMenu() const { return m_pContextMenu; }
    void setContextMenu(ContextMenu* pContextMenu) { m_pContextMenu = pContextMenu; }

    Popup* openPopupInstance() const { return m_pPopupOpen; }
    bool isPopupOpen(const Popup* pPopup) const { return m_pPopupOpen != null && m_pPopupOpen == pPopup; }

    void openPopup(Popup* pPopup) {
        if (m_pPopupOpen == pPopup) { return; }
        closePopup();
        m_pPopupOpen = pPopup;
    }

    void closePopup() {
        if (m_pPopupOpen == null) { return; }
        Popup* pPopupClosing = m_pPopupOpen;
        m_pPopupOpen = null;
        pPopupClosing->onPopupClosed(*this);
    }

    void releaseAll() {
        closePopup();
        m_pMouseOwner = null;
        m_pKeyboardOwner = null;
        m_pFocusedComponent = null;
    }
};

}
