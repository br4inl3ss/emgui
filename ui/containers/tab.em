#pragma once

namespace ui {

class Frame;
class Gui;

class Tab : public Element {
    friend class Frame;
    friend class Gui;

    static constexpr float64 fIconSize = 16.0;
    static constexpr float64 fHorizontalPadding = 10.0;
    static constexpr float64 fScrollStep = 60.0;

    std::vector<std::unique_ptr<Child>> m_vecChildren;
    std::unique_ptr<SvgIcon> m_upSvgIcon;
    bool m_bIconOnly = false;
    ClickCallback m_fnOnSelect = null;
    Rect m_objRectContent;
    float64 m_fActiveBlend = 0.0;
    float64 m_fScrollOffset = 0.0;
    float64 m_fContentHeight = 0.0;

    bool hasIcon() const { return m_upSvgIcon != null && m_upSvgIcon->isValid(); }

    bool showsLabel() const { return !m_strLabel.empty() && !(m_bIconOnly && hasIcon()); }

    float64 buttonWidth(UiContext& objUiContext) {
        const ThemeMetrics& objThemeMetrics = objUiContext.metrics();
        if (!showsLabel()) { return objThemeMetrics.fTabButtonHeight + fHorizontalPadding; }
        float64 fWidth = objUiContext.painter().measureText(m_strLabel, FontRole::Body).x + fHorizontalPadding * 2.0;
        if (hasIcon()) { fWidth += fIconSize + objThemeMetrics.fIconSpacing; }
        return fWidth;
    }

    bool updateButton(UiContext& objUiContext, const Rect& objRectButton, bool bActive) {
        m_objRectBounds = objRectButton;
        bool bHoveredNow = objUiContext.isMouseOver(objRectButton);
        trackHover(objUiContext, bHoveredNow);
        m_fActiveBlend = approachValue(m_fActiveBlend, bActive ? 1.0 : 0.0, objUiContext.animationStep());
        if (!bHoveredNow || !objUiContext.input().isMousePressed()) { return false; }
        objUiContext.input().consumeMousePress();
        return true;
    }

    void drawButton(UiContext& objUiContext) {
        Painter& objPainter = objUiContext.painter();
        const ThemeMetrics& objThemeMetrics = objUiContext.metrics();
        float64 fRounding = objThemeMetrics.fWidgetRounding;
        float64 fHoverOnly = m_fHoverBlend * (1.0 - m_fActiveBlend);
        WidgetVisuals objWidgetVisuals = widgetVisuals(objUiContext, m_fHoverBlend, 0.0, 0.0);
        color objColorSelectionFill = colorOf(objUiContext, ColorRole::SelectionFill);
        if (fHoverOnly > 0.0) {
            objPainter.fillRect(m_objRectBounds, objWidgetVisuals.objColorFill.with_alpha(static_cast<uint8>(static_cast<float64>(objWidgetVisuals.objColorFill.a) * fHoverOnly)), fRounding);
            objPainter.strokeRect(m_objRectBounds, objWidgetVisuals.objColorStroke.with_alpha(static_cast<uint8>(static_cast<float64>(objWidgetVisuals.objColorStroke.a) * fHoverOnly)), 1.0, fRounding);
        }
        if (m_fActiveBlend > 0.0) {
            objPainter.fillRect(m_objRectBounds, objColorSelectionFill.with_alpha(static_cast<uint8>(static_cast<float64>(objColorSelectionFill.a) * m_fActiveBlend)), fRounding);
        }
        color objColorContent = objWidgetVisuals.objColorText.lerp(colorOf(objUiContext, ColorRole::SelectionStroke), m_fActiveBlend);

        if (!showsLabel()) {
            objPainter.drawSvgIcon(*m_upSvgIcon, Rect(m_objRectBounds.centerX() - fIconSize * 0.5, m_objRectBounds.centerY() - fIconSize * 0.5, fIconSize, fIconSize), objColorContent);
            return;
        }
        Rect objRectContent = m_objRectBounds.withoutLeft(fHorizontalPadding).withoutRight(fHorizontalPadding);
        if (hasIcon()) {
            objPainter.drawSvgIcon(*m_upSvgIcon, Rect(objRectContent.fX, objRectContent.centerY() - fIconSize * 0.5, fIconSize, fIconSize), objColorContent);
            objRectContent = objRectContent.withoutLeft(fIconSize + objThemeMetrics.fIconSpacing);
        }
        objPainter.drawTextInRect(m_strLabel, objRectContent, objColorContent, FontRole::Body, HorizontalAlignment::Left);
    }

    float64 maximumScroll() const { return fmax(0.0, m_fContentHeight - m_objRectContent.fHeight); }

    Rect scrollbarThumb(UiContext& objUiContext) const {
        float64 fScrollbarWidth = objUiContext.metrics().fScrollbarWidth;
        float64 fThumbHeight = fmax(24.0, m_objRectContent.fHeight * m_objRectContent.fHeight / fmax(1.0, m_fContentHeight));
        float64 fTravel = m_objRectContent.fHeight - fThumbHeight - 4.0;
        float64 fThumbY = m_objRectContent.fY + 2.0 + (maximumScroll() <= 0.0 ? 0.0 : fTravel * m_fScrollOffset / maximumScroll());
        return Rect(m_objRectContent.right() - fScrollbarWidth - 2.0, fThumbY, fScrollbarWidth, fThumbHeight);
    }

    void layoutContent(UiContext& objUiContext, const Rect& objRectContent) {
        const ThemeMetrics& objThemeMetrics = objUiContext.metrics();
        m_objRectContent = objRectContent;
        m_fScrollOffset = clamp(m_fScrollOffset, 0.0, maximumScroll());
        float64 fScrollbarReserve = maximumScroll() > 0.0 ? objThemeMetrics.fScrollbarWidth + 2.0 : 0.0;
        float64 fInnerWidth = objRectContent.fWidth - objThemeMetrics.fWindowMargin * 2.0 - fScrollbarReserve;
        float64 fColumnWidth = fmax(0.0, (fInnerWidth - objThemeMetrics.fGroupGap) * 0.5);
        float64 fLeft = objRectContent.fX + objThemeMetrics.fWindowMargin;
        float64 fY = objRectContent.fY + objThemeMetrics.fWindowMargin - m_fScrollOffset;
        float64 fTop = fY;

        for (int64 iIndex = 0; iIndex < m_vecChildren.size(); iIndex += 2) {
            Child* pChildLeft = m_vecChildren[iIndex].get();
            Child* pChildRight = iIndex + 1 < m_vecChildren.size() ? m_vecChildren[iIndex + 1].get() : null;
            float64 fRowHeight = pChildLeft->measureHeight(objUiContext, fColumnWidth);
            if (pChildRight != null) { fRowHeight = fmax(fRowHeight, pChildRight->measureHeight(objUiContext, fColumnWidth)); }
            pChildLeft->arrange(objUiContext, Rect(fLeft, fY, fColumnWidth, fRowHeight));
            if (pChildRight != null) { pChildRight->arrange(objUiContext, Rect(fLeft + fColumnWidth + objThemeMetrics.fGroupGap, fY, fColumnWidth, fRowHeight)); }
            fY += fRowHeight + objThemeMetrics.fGroupGap;
        }
        float64 fChildrenHeight = m_vecChildren.empty() ? 0.0 : fY - fTop - objThemeMetrics.fGroupGap;
        m_fContentHeight = fChildrenHeight + objThemeMetrics.fWindowMargin * 2.0;
    }

    void updateScrolling(UiContext& objUiContext) {
        InputState& objInputState = objUiContext.input();
        float64 fScrollRange = maximumScroll();
        if (objUiContext.isMouseCapturedBy(this)) {
            Rect objRectThumb = scrollbarThumb(objUiContext);
            float64 fTravel = m_objRectContent.fHeight - objRectThumb.fHeight - 4.0;
            if (fTravel > 0.0) { m_fScrollOffset = clamp(m_fScrollOffset + objInputState.mouseDelta().y * fScrollRange / fTravel, 0.0, fScrollRange); }
            if (!objInputState.isMouseDown()) { objUiContext.releaseMouse(this); }
            return;
        }
        if (fScrollRange <= 0.0 || !objUiContext.isMouseOver(m_objRectContent)) { return; }
        if (objInputState.isMousePressed() && objUiContext.isMouseOver(scrollbarThumb(objUiContext).expanded(3.0))) {
            objInputState.consumeMousePress();
            objUiContext.captureMouse(this);
            return;
        }
        if (objInputState.scrollDelta() != 0.0) {
            m_fScrollOffset = clamp(m_fScrollOffset - objInputState.scrollDelta() * fScrollStep, 0.0, fScrollRange);
            objInputState.consumeScroll();
        }
    }

    void updateContent(UiContext& objUiContext) {
        objUiContext.pushHitClip(m_objRectContent);
        for (std::unique_ptr<Child>& upChild : m_vecChildren) {
            if (upChild->bounds().bottom() < m_objRectContent.fY || upChild->bounds().fY > m_objRectContent.bottom()) { continue; }
            upChild->update(objUiContext);
        }
        updateScrolling(objUiContext);
        objUiContext.popHitClip();
    }

    void drawContent(UiContext& objUiContext) {
        Painter& objPainter = objUiContext.painter();
        objPainter.pushClip(m_objRectContent);
        objUiContext.pushHitClip(m_objRectContent);
        for (std::unique_ptr<Child>& upChild : m_vecChildren) {
            if (upChild->bounds().bottom() < m_objRectContent.fY || upChild->bounds().fY > m_objRectContent.bottom()) { continue; }
            upChild->draw(objUiContext);
        }
        if (maximumScroll() > 0.0) {
            Rect objRectThumb = scrollbarThumb(objUiContext);
            bool bThumbDragged = objUiContext.isMouseCapturedBy(this);
            bool bThumbHovered = bThumbDragged || objUiContext.isMouseOver(objRectThumb.expanded(3.0));
            WidgetVisuals objThumbVisuals = widgetVisuals(objUiContext, bThumbHovered ? 1.0 : 0.0, bThumbDragged ? 1.0 : 0.0, 0.0);
            objPainter.fillRect(objRectThumb, objThumbVisuals.objColorFill, objRectThumb.fWidth * 0.5);
        }
        objUiContext.popHitClip();
        objPainter.popClip();
    }

    void notifySelected() {
        if (m_fnOnSelect != null) { m_fnOnSelect(); }
    }

    std::vector<Component*> focusOrder() const {
        std::vector<Component*> vecLayoutOrder;
        for (const std::unique_ptr<Child>& upChild : m_vecChildren) { upChild->appendFocusableComponents(vecLayoutOrder); }
        std::vector<Component*> vecOrdered;
        for (Component* pComponent : vecLayoutOrder) {
            if (!pComponent->hasTabOrder()) { continue; }
            int64 iInsertAt = vecOrdered.size();
            while (iInsertAt > 0 && vecOrdered[iInsertAt - 1]->tabOrder() > pComponent->tabOrder()) { iInsertAt--; }
            vecOrdered.insert(vecOrdered.begin() + iInsertAt, pComponent);
        }
        for (Component* pComponent : vecLayoutOrder) {
            if (!pComponent->hasTabOrder()) { vecOrdered.push_back(pComponent); }
        }
        return vecOrdered;
    }

    bool containsComponent(const Component* pComponent) const {
        for (Component* pCandidate : focusOrder()) {
            if (pCandidate == pComponent) { return true; }
        }
        return false;
    }

    void scrollIntoView(const Component* pComponent) {
        const Rect& objRectComponent = pComponent->bounds();
        if (objRectComponent.fY < m_objRectContent.fY) { m_fScrollOffset -= m_objRectContent.fY - objRectComponent.fY + 8.0; }
        if (objRectComponent.bottom() > m_objRectContent.bottom()) { m_fScrollOffset += objRectComponent.bottom() - m_objRectContent.bottom() + 8.0; }
        m_fScrollOffset = clamp(m_fScrollOffset, 0.0, maximumScroll());
    }

public:
    Tab(const std::string& strLabel) : Element(strLabel) {}

    Child* addChild(const std::string& strTitle) {
        Child* pChild = new Child(strTitle);
        adoptChild(pChild);
        m_vecChildren.push_back(std::unique_ptr<Child>(pChild));
        return pChild;
    }

    Tab* onSelect(ClickCallback fnOnSelect) {
        m_fnOnSelect = fnOnSelect;
        return this;
    }

    Tab* setIcon(const std::string& strSvgMarkup, SvgColorMode eColorMode) {
        m_upSvgIcon = std::make_unique<SvgIcon>(strSvgMarkup, eColorMode);
        return this;
    }

    Tab* setIcon(const std::string& strSvgMarkup) { return setIcon(strSvgMarkup, SvgColorMode::Tinted); }

    Tab* setIconOnly(bool bIconOnly) {
        m_bIconOnly = bIconOnly;
        return this;
    }

    bool hasValidIcon() const { return hasIcon(); }
    int64 childCount() const { return m_vecChildren.size(); }
};

}
