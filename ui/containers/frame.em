#pragma once

namespace ui {

class Gui;

class Frame : public Element {
    friend class Gui;

    enum class DragMode : int32 { None, Move, ResizeRight, ResizeBottom, ResizeCorner };

    static constexpr float64 fResizeEdgeThickness = 6.0;

    std::vector<std::unique_ptr<Tab>> m_vecTabs;
    int64 m_iActiveTabIndex = 0;
    vec2 m_objVec2MinimumSize = vec2(320.0, 220.0);
    bool m_bVisible = true;
    bool m_bResizable = true;
    bool m_bMovable = true;
    DragMode m_eDragMode = DragMode::None;
    vec2 m_objVec2DragStartMouse = vec2(0.0, 0.0);
    Rect m_objRectDragStartBounds;
    Vec2Callback m_fnOnMove = null;
    Vec2Callback m_fnOnResize = null;

    bool showsTabBar() const { return m_vecTabs.size() > 1; }

    Rect titleBarBounds(UiContext& objUiContext) const { return m_objRectBounds.takeTop(objUiContext.metrics().fTitleBarHeight); }

    Rect tabBarBounds(UiContext& objUiContext) const {
        if (!showsTabBar()) { return Rect(m_objRectBounds.fX, titleBarBounds(objUiContext).bottom(), m_objRectBounds.fWidth, 0.0); }
        return Rect(m_objRectBounds.fX, titleBarBounds(objUiContext).bottom(), m_objRectBounds.fWidth, objUiContext.metrics().fTabBarHeight);
    }

    Rect contentBounds(UiContext& objUiContext) const {
        return m_objRectBounds.withoutTop(tabBarBounds(objUiContext).bottom() - m_objRectBounds.fY);
    }

    Rect resizeCornerBounds(UiContext& objUiContext) const {
        float64 fCornerSize = objUiContext.metrics().fResizeCornerSize;
        return Rect(m_objRectBounds.right() - fCornerSize, m_objRectBounds.bottom() - fCornerSize, fCornerSize, fCornerSize);
    }

    Rect resizeRightEdgeBounds() const {
        return Rect(m_objRectBounds.right() - fResizeEdgeThickness, m_objRectBounds.fY, fResizeEdgeThickness, m_objRectBounds.fHeight);
    }

    Rect resizeBottomEdgeBounds() const {
        return Rect(m_objRectBounds.fX, m_objRectBounds.bottom() - fResizeEdgeThickness, m_objRectBounds.fWidth, fResizeEdgeThickness);
    }

    void keepTitleBarReachable(UiContext& objUiContext) {
        const Rect& objRectView = objUiContext.viewBounds();
        if (objRectView.isEmpty()) { return; }
        float64 fTitleBarHeight = objUiContext.metrics().fTitleBarHeight;
        m_objRectBounds.fX = clamp(m_objRectBounds.fX, objRectView.fX - m_objRectBounds.fWidth + 80.0, objRectView.right() - 80.0);
        m_objRectBounds.fY = clamp(m_objRectBounds.fY, objRectView.fY, fmax(objRectView.fY, objRectView.bottom() - fTitleBarHeight));
    }

    DragMode dragModeUnderMouse(UiContext& objUiContext) {
        if (m_bResizable) {
            if (objUiContext.isMouseOver(resizeCornerBounds(objUiContext))) { return DragMode::ResizeCorner; }
            if (objUiContext.isMouseOver(resizeRightEdgeBounds())) { return DragMode::ResizeRight; }
            if (objUiContext.isMouseOver(resizeBottomEdgeBounds())) { return DragMode::ResizeBottom; }
        }
        if (m_bMovable && objUiContext.isMouseOver(titleBarBounds(objUiContext))) { return DragMode::Move; }
        return DragMode::None;
    }

    void applyDrag(UiContext& objUiContext) {
        InputState& objInputState = objUiContext.input();
        vec2 objVec2Mouse = objInputState.mousePosition();
        float64 fDeltaX = objVec2Mouse.x - m_objVec2DragStartMouse.x;
        float64 fDeltaY = objVec2Mouse.y - m_objVec2DragStartMouse.y;
        Rect objRectBefore = m_objRectBounds;

        if (m_eDragMode == DragMode::Move) {
            m_objRectBounds.fX = m_objRectDragStartBounds.fX + fDeltaX;
            m_objRectBounds.fY = m_objRectDragStartBounds.fY + fDeltaY;
            keepTitleBarReachable(objUiContext);
        }
        if (m_eDragMode == DragMode::ResizeRight || m_eDragMode == DragMode::ResizeCorner) {
            m_objRectBounds.fWidth = fmax(m_objVec2MinimumSize.x, m_objRectDragStartBounds.fWidth + fDeltaX);
        }
        if (m_eDragMode == DragMode::ResizeBottom || m_eDragMode == DragMode::ResizeCorner) {
            m_objRectBounds.fHeight = fmax(m_objVec2MinimumSize.y, m_objRectDragStartBounds.fHeight + fDeltaY);
        }

        bool bMoved = objRectBefore.fX != m_objRectBounds.fX || objRectBefore.fY != m_objRectBounds.fY;
        bool bResized = objRectBefore.fWidth != m_objRectBounds.fWidth || objRectBefore.fHeight != m_objRectBounds.fHeight;
        if (bMoved && m_fnOnMove != null) { m_fnOnMove(m_objRectBounds.position()); }
        if (bResized && m_fnOnResize != null) { m_fnOnResize(m_objRectBounds.size()); }

        if (!objInputState.isMouseDown()) {
            m_eDragMode = DragMode::None;
            objUiContext.releaseMouse(this);
        }
    }

    void beginDragIfPressed(UiContext& objUiContext) {
        InputState& objInputState = objUiContext.input();
        if (!objInputState.isMousePressed()) { return; }
        DragMode eDragMode = dragModeUnderMouse(objUiContext);
        if (eDragMode == DragMode::None) { return; }
        objInputState.consumeMousePress();
        m_eDragMode = eDragMode;
        m_objVec2DragStartMouse = objInputState.mousePosition();
        m_objRectDragStartBounds = m_objRectBounds;
        objUiContext.captureMouse(this);
    }

    void updateTabs(UiContext& objUiContext) {
        if (m_vecTabs.empty()) { return; }
        m_iActiveTabIndex = clamp(m_iActiveTabIndex, static_cast<int64>(0), m_vecTabs.size() - 1);
        if (showsTabBar()) {
            const ThemeMetrics& objThemeMetrics = objUiContext.metrics();
            Rect objRectTabBar = tabBarBounds(objUiContext);
            float64 fX = objRectTabBar.fX + objThemeMetrics.fWindowMargin;
            float64 fY = objRectTabBar.centerY() - objThemeMetrics.fTabButtonHeight * 0.5;
            objUiContext.pushHitClip(objRectTabBar);
            for (int64 iIndex = 0; iIndex < m_vecTabs.size(); iIndex++) {
                Tab* pTab = m_vecTabs[iIndex].get();
                float64 fWidth = pTab->buttonWidth(objUiContext);
                bool bClicked = pTab->updateButton(objUiContext, Rect(fX, fY, fWidth, objThemeMetrics.fTabButtonHeight), iIndex == m_iActiveTabIndex);
                if (bClicked && iIndex != m_iActiveTabIndex) {
                    m_iActiveTabIndex = iIndex;
                    objUiContext.closePopup();
                    pTab->notifySelected();
                }
                fX += fWidth + objThemeMetrics.fIconSpacing;
            }
            objUiContext.popHitClip();
        }
        Tab* pTabActive = m_vecTabs[m_iActiveTabIndex].get();
        pTabActive->layoutContent(objUiContext, contentBounds(objUiContext));
        pTabActive->updateContent(objUiContext);
    }

    void update(UiContext& objUiContext) {
        if (objUiContext.isMouseCapturedBy(this)) {
            applyDrag(objUiContext);
        } else {
            beginDragIfPressed(objUiContext);
        }
        keepTitleBarReachable(objUiContext);
        trackHover(objUiContext, objUiContext.isMouseOver(m_objRectBounds));
        updateTabs(objUiContext);
        if (objUiContext.isMouseOver(m_objRectBounds) && objUiContext.input().isMousePressed()) { objUiContext.input().consumeMousePress(); }
    }

    void drawResizeCorner(UiContext& objUiContext) {
        Rect objRectCorner = resizeCornerBounds(objUiContext).shrunk(2.0);
        bool bActive = m_eDragMode == DragMode::ResizeCorner || objUiContext.isMouseOver(resizeCornerBounds(objUiContext));
        color objColorLines = colorOf(objUiContext, bActive ? ColorRole::WidgetHoveredText : ColorRole::TextNormal);
        for (int64 iLine = 1; iLine <= 3; iLine++) {
            float64 fOffset = objRectCorner.fWidth * static_cast<float64>(iLine) / 3.0;
            objUiContext.painter().drawLine(vec2(objRectCorner.right() - fOffset, objRectCorner.bottom()), vec2(objRectCorner.right(), objRectCorner.bottom() - fOffset), objColorLines, 1.0);
        }
    }

    void draw(UiContext& objUiContext) {
        Painter& objPainter = objUiContext.painter();
        const ThemeMetrics& objThemeMetrics = objUiContext.metrics();
        float64 fRounding = objThemeMetrics.fWindowRounding;
        color objColorSeparator = colorOf(objUiContext, ColorRole::Separator);
        objPainter.drawShadow(m_objRectBounds, fRounding, colorOf(objUiContext, ColorRole::WindowShadow), objThemeMetrics.fShadowSize, vec2(5.0, 10.0));
        objPainter.fillRect(m_objRectBounds, colorOf(objUiContext, ColorRole::WindowFill), fRounding);

        Rect objRectTitleBar = titleBarBounds(objUiContext);
        objPainter.drawTextInRect(m_strLabel, objRectTitleBar.shrunk(objThemeMetrics.fWindowMargin), colorOf(objUiContext, ColorRole::TextStrong), FontRole::Title, HorizontalAlignment::Center);
        objPainter.fillRect(Rect(objRectTitleBar.fX, objRectTitleBar.bottom() - 1.0, objRectTitleBar.fWidth, 1.0), objColorSeparator, 0.0);

        if (showsTabBar()) {
            Rect objRectTabBar = tabBarBounds(objUiContext);
            objPainter.pushClip(objRectTabBar);
            for (std::unique_ptr<Tab>& upTab : m_vecTabs) { upTab->drawButton(objUiContext); }
            objPainter.popClip();
            objPainter.fillRect(Rect(objRectTabBar.fX + objThemeMetrics.fWindowMargin, objRectTabBar.bottom() - 1.0, objRectTabBar.fWidth - objThemeMetrics.fWindowMargin * 2.0, 1.0), objColorSeparator, 0.0);
        }
        if (!m_vecTabs.empty()) { m_vecTabs[m_iActiveTabIndex]->drawContent(objUiContext); }

        objPainter.strokeRect(m_objRectBounds, colorOf(objUiContext, ColorRole::WindowStroke), 1.0, fRounding);
        if (m_bResizable) { drawResizeCorner(objUiContext); }
    }

public:
    Frame(const std::string& strTitle, const Rect& objRectBounds, KeybindRegistry* pKeybindRegistry) : Element(strTitle) {
        m_objRectBounds = objRectBounds;
        m_pKeybindRegistry = pKeybindRegistry;
        setSize(objRectBounds.size());
    }

    Tab* addTab(const std::string& strLabel) {
        Tab* pTab = new Tab(strLabel);
        adoptChild(pTab);
        m_vecTabs.push_back(std::unique_ptr<Tab>(pTab));
        return pTab;
    }

    Tab* addTab(const std::string& strLabel, const std::string& strSvgIconMarkup) { return addTab(strLabel)->setIcon(strSvgIconMarkup); }

    Frame* onMove(Vec2Callback fnOnMove) {
        m_fnOnMove = fnOnMove;
        return this;
    }

    Frame* onResize(Vec2Callback fnOnResize) {
        m_fnOnResize = fnOnResize;
        return this;
    }

    Tab* activeTab() const { return m_vecTabs.empty() ? null : m_vecTabs[m_iActiveTabIndex].get(); }

    void selectTab(int64 iIndex) {
        if (iIndex < 0 || iIndex >= m_vecTabs.size() || iIndex == m_iActiveTabIndex) { return; }
        m_iActiveTabIndex = iIndex;
        m_vecTabs[iIndex]->notifySelected();
    }

    bool isVisible() const { return m_bVisible; }
    void setVisible(bool bVisible) { m_bVisible = bVisible; }
    void setResizable(bool bResizable) { m_bResizable = bResizable; }
    void setMovable(bool bMovable) { m_bMovable = bMovable; }

    vec2 position() const { return m_objRectBounds.position(); }
    vec2 size() const { return m_objRectBounds.size(); }

    void setPosition(vec2 objVec2Position) {
        m_objRectBounds.fX = objVec2Position.x;
        m_objRectBounds.fY = objVec2Position.y;
    }

    void setSize(vec2 objVec2Size) {
        m_objRectBounds.fWidth = fmax(m_objVec2MinimumSize.x, objVec2Size.x);
        m_objRectBounds.fHeight = fmax(m_objVec2MinimumSize.y, objVec2Size.y);
    }

    void setMinimumSize(vec2 objVec2MinimumSize) {
        m_objVec2MinimumSize = vec2(fmax(120.0, objVec2MinimumSize.x), fmax(80.0, objVec2MinimumSize.y));
        setSize(size());
    }
};

}
