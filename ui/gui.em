#pragma once

namespace ui {

class Gui {
    static constexpr float64 fMinimumScale = 0.5;
    static constexpr float64 fMaximumScale = 4.0;
    static constexpr float64 fReferenceWidth = 1920.0;
    static constexpr float64 fReferenceHeight = 1080.0;

    std::unique_ptr<RenderBackend> m_upRenderBackend;
    std::unique_ptr<PlatformBackend> m_upPlatformBackend;
    std::unique_ptr<InputCapture> m_upInputCapture;
    Theme m_objTheme;
    FontLibrary m_objFontLibrary;
    InputState m_objInputState;
    KeybindRegistry m_objKeybindRegistry;
    Painter m_objPainter;
    UiContext m_objUiContext;
    ContextMenu m_objContextMenu;
    std::vector<std::unique_ptr<Frame>> m_vecFrames;
    std::vector<Frame*> m_vecFramesBackToFront;
    bool m_bVisible = true;
    int64 m_iToggleKey = vk::insert;
    float64 m_fUserScale = 1.0;
    BoolCallback m_fnOnVisibilityChange = null;

    Frame* frameUnderMouse() const {
        vec2 objVec2Mouse = m_objInputState.mousePosition();
        for (int64 iIndex = m_vecFramesBackToFront.size() - 1; iIndex >= 0; iIndex--) {
            Frame* pFrame = m_vecFramesBackToFront[iIndex];
            if (pFrame->isVisible() && pFrame->bounds().contains(objVec2Mouse)) { return pFrame; }
        }
        return null;
    }

    Frame* frontVisibleFrame() const {
        for (int64 iIndex = m_vecFramesBackToFront.size() - 1; iIndex >= 0; iIndex--) {
            if (m_vecFramesBackToFront[iIndex]->isVisible()) { return m_vecFramesBackToFront[iIndex]; }
        }
        return null;
    }

    void bringToFront(Frame* pFrame) {
        for (int64 iIndex = 0; iIndex < m_vecFramesBackToFront.size(); iIndex++) {
            if (m_vecFramesBackToFront[iIndex] != pFrame) { continue; }
            m_vecFramesBackToFront.erase(m_vecFramesBackToFront.begin() + iIndex);
            m_vecFramesBackToFront.push_back(pFrame);
            return;
        }
    }

    Rect logicalViewBounds(float64 fScale) const {
        vec2 objVec2ViewPixels = m_upRenderBackend->viewSize();
        return Rect(0.0, 0.0, objVec2ViewPixels.x / fScale, objVec2ViewPixels.y / fScale);
    }

    Tab* tabContainingFocus(Component*& pComponentFocused) const {
        const void* pFocused = m_objUiContext.focusedComponent();
        if (pFocused == null) { return null; }
        for (Frame* pFrame : m_vecFramesBackToFront) {
            Tab* pTab = pFrame->isVisible() ? pFrame->activeTab() : null;
            if (pTab == null) { continue; }
            for (Component* pComponent : pTab->focusOrder()) {
                if (pComponent != pFocused) { continue; }
                pComponentFocused = pComponent;
                return pTab;
            }
        }
        return null;
    }

    void moveKeyboardFocus(int64 iDirection) {
        Component* pComponentFocused = null;
        Tab* pTab = tabContainingFocus(pComponentFocused);
        if (pTab == null) {
            Frame* pFrame = frontVisibleFrame();
            pTab = pFrame == null ? null : pFrame->activeTab();
        }
        if (pTab == null) { return; }
        std::vector<Component*> vecOrder = pTab->focusOrder();
        int64 iCount = vecOrder.size();
        if (iCount == 0) { return; }
        int64 iNext = iDirection > 0 ? 0 : iCount - 1;
        for (int64 iIndex = 0; iIndex < iCount; iIndex++) {
            if (vecOrder[iIndex] == pComponentFocused) { iNext = (iIndex + iDirection + iCount) % iCount; }
        }
        m_objUiContext.closePopup();
        m_objUiContext.setFocus(vecOrder[iNext]);
        pTab->scrollIntoView(vecOrder[iNext]);
    }

    void handleKeyboardNavigation() {
        if (m_objInputState.isMousePressed() || m_objInputState.isSecondaryMousePressed()) { m_objUiContext.clearFocus(); }
        if (m_objInputState.isKeyPressed(vk::tab) && m_objUiContext.allowsTabNavigation()) {
            moveKeyboardFocus(m_objInputState.isShiftDown() ? -1 : 1);
        } else if (m_objInputState.isKeyPressed(vk::escape) && !m_objUiContext.isKeyboardCaptured()) {
            m_objUiContext.clearFocus();
        }
        Component* pComponentFocused = null;
        if (m_objUiContext.focusedComponent() != null && tabContainingFocus(pComponentFocused) == null) { m_objUiContext.clearFocus(); }
    }

    bool updatePopup() {
        Popup* pPopup = m_objUiContext.openPopupInstance();
        if (pPopup == null) { return false; }
        bool bMouseOverPopup = pPopup->popupBounds(m_objUiContext).contains(m_objInputState.mousePosition());
        bool bPressedOutside = !bMouseOverPopup && (m_objInputState.isMousePressed() || m_objInputState.isSecondaryMousePressed());
        if (bPressedOutside && !m_objUiContext.isMouseCaptured()) {
            m_objUiContext.closePopup();
            m_objInputState.consumeMousePress();
            return false;
        }
        m_objUiContext.setMouseBlocked(!bMouseOverPopup);
        pPopup->updatePopup(m_objUiContext);
        m_objUiContext.setMouseBlocked(false);
        return bMouseOverPopup;
    }

    void updateAndDrawFrames() {
        handleKeyboardNavigation();
        bool bMouseOverPopup = updatePopup();
        Frame* pFrameUnderMouse = bMouseOverPopup ? null : frameUnderMouse();
        if (pFrameUnderMouse != null && m_objInputState.isMousePressed()) { bringToFront(pFrameUnderMouse); }

        std::vector<Frame*> vecFramesThisFrame = m_vecFramesBackToFront;
        for (Frame* pFrame : vecFramesThisFrame) {
            if (!pFrame->isVisible()) { continue; }
            m_objUiContext.setMouseBlocked(pFrame != pFrameUnderMouse);
            pFrame->update(m_objUiContext);
        }
        for (Frame* pFrame : vecFramesThisFrame) {
            if (!pFrame->isVisible()) { continue; }
            m_objUiContext.setMouseBlocked(pFrame != pFrameUnderMouse);
            pFrame->draw(m_objUiContext);
        }

        Popup* pPopup = m_objUiContext.openPopupInstance();
        if (pPopup != null) {
            m_objUiContext.setMouseBlocked(false);
            pPopup->drawPopup(m_objUiContext);
        }
    }

    std::vector<Rect> regionsNeedingInputCapture(float64 fScale) {
        std::vector<Rect> vecPixelRegions;
        if (!m_bVisible) { return vecPixelRegions; }
        for (Frame* pFrame : m_vecFramesBackToFront) {
            if (!pFrame->isVisible()) { continue; }
            const Rect& objRectFrame = pFrame->bounds();
            vecPixelRegions.push_back(Rect(objRectFrame.fX * fScale, objRectFrame.fY * fScale, objRectFrame.fWidth * fScale, objRectFrame.fHeight * fScale));
        }
        Popup* pPopup = m_objUiContext.openPopupInstance();
        if (pPopup != null) {
            Rect objRectPopup = pPopup->popupBounds(m_objUiContext);
            vecPixelRegions.push_back(Rect(objRectPopup.fX * fScale, objRectPopup.fY * fScale, objRectPopup.fWidth * fScale, objRectPopup.fHeight * fScale));
        }
        return vecPixelRegions;
    }

public:
    Gui() : Gui(std::make_unique<PerceptionRenderBackend>(), std::make_unique<PerceptionPlatformBackend>()) {}

    Gui(std::unique_ptr<RenderBackend> upRenderBackend, std::unique_ptr<PlatformBackend> upPlatformBackend)
        : m_upRenderBackend(std::move(upRenderBackend)),
          m_upPlatformBackend(std::move(upPlatformBackend)),
          m_objTheme(Theme::dark()),
          m_objPainter(m_upRenderBackend.get(), &m_objFontLibrary),
          m_objUiContext(&m_objPainter, &m_objInputState, &m_objTheme, m_upPlatformBackend.get()) {
        m_objUiContext.setContextMenu(&m_objContextMenu);
    }

    Gui(const Gui& objGuiOther) = delete;
    Gui& operator=(const Gui& objGuiOther) = delete;

    Frame* addFrame(const std::string& strTitle, vec2 objVec2Position, vec2 objVec2Size) {
        Frame* pFrame = new Frame(strTitle, Rect(objVec2Position.x, objVec2Position.y, objVec2Size.x, objVec2Size.y), &m_objKeybindRegistry);
        m_vecFrames.push_back(std::unique_ptr<Frame>(pFrame));
        m_vecFramesBackToFront.push_back(pFrame);
        return pFrame;
    }

    Keybind* addKeybind(const std::string& strName, int64 iVirtualKey, KeybindMode eMode) {
        return m_objKeybindRegistry.create(strName, iVirtualKey, eMode);
    }

    Theme& theme() { return m_objTheme; }
    void setTheme(const Theme& objTheme) { m_objTheme = objTheme; }
    FontLibrary& fonts() { return m_objFontLibrary; }

    void setInputCapture(std::unique_ptr<InputCapture> upInputCapture) { m_upInputCapture = std::move(upInputCapture); }

    bool copyValue(const Component* pComponent) { return m_objContextMenu.copyFrom(m_objUiContext, pComponent); }
    bool pasteValue(Component* pComponent) { return m_objContextMenu.pasteInto(m_objUiContext, pComponent); }

    float64 resolutionScale() const {
        vec2 objVec2ViewPixels = m_upRenderBackend->viewSize();
        bool bUsable = is_finite(objVec2ViewPixels.x) && is_finite(objVec2ViewPixels.y) && objVec2ViewPixels.x > 0.0 && objVec2ViewPixels.y > 0.0;
        if (!bUsable) { return 1.0; }
        return fmin(objVec2ViewPixels.x / fReferenceWidth, objVec2ViewPixels.y / fReferenceHeight);
    }

    float64 scale() const { return clamp(resolutionScale() * m_fUserScale, fMinimumScale, fMaximumScale); }

    void setScale(float64 fUserScale) {
        if (is_finite(fUserScale) && fUserScale > 0.0) { m_fUserScale = fUserScale; }
    }

    bool isVisible() const { return m_bVisible; }

    void setVisible(bool bVisible) {
        if (bVisible == m_bVisible) { return; }
        m_bVisible = bVisible;
        if (!m_bVisible) { m_objUiContext.releaseAll(); }
        if (m_fnOnVisibilityChange != null) { m_fnOnVisibilityChange(m_bVisible); }
    }

    void setToggleKey(int64 iVirtualKey) { m_iToggleKey = iVirtualKey; }

    Gui* onVisibilityChange(BoolCallback fnOnVisibilityChange) {
        m_fnOnVisibilityChange = fnOnVisibilityChange;
        return this;
    }

    void renderFrame() {
        float64 fScale = scale();
        try {
            m_objInputState.capture(m_upPlatformBackend.get(), fScale);
            m_objFontLibrary.resolve(m_upRenderBackend.get(), m_upPlatformBackend.get(), fScale);
            m_objPainter.beginFrame(fScale);
            bool bKeyboardCaptured = m_objUiContext.isKeyboardCaptured();
            if (!bKeyboardCaptured && m_objInputState.isKeyPressed(m_iToggleKey)) { setVisible(!m_bVisible); }
            m_objKeybindRegistry.update(m_objInputState, !bKeyboardCaptured);
            if (m_bVisible) {
                m_objUiContext.beginFrame(logicalViewBounds(fScale));
                updateAndDrawFrames();
            }
            if (m_upInputCapture != null) { m_upInputCapture->captureRegions(regionsNeedingInputCapture(fScale)); }
        } catch (const std::exception& objException) {
            m_upPlatformBackend->log(std::string("frame aborted: ") + objException.what());
            m_objUiContext.releaseAll();
        }
        m_objPainter.endFrame();
    }
};

}
