#pragma once

namespace ui {

class DropdownBase : public Component, public Popup {
    static constexpr float64 fPopupGap = 4.0;
    static constexpr float64 fTriangleWidth = 8.0;
    static constexpr int64 iMaximumVisibleItems = 8;

    float64 m_fOpenBlend = 0.0;

    Rect boxBounds(UiContext& objUiContext) {
        Rect objRectControl = controlBounds(objUiContext);
        float64 fHeight = rowHeight(objUiContext);
        return Rect(objRectControl.fX, objRectControl.centerY() - fHeight * 0.5, objRectControl.fWidth, fHeight);
    }

    Rect listViewBounds(UiContext& objUiContext) { return popupBounds(objUiContext).shrunk(objUiContext.metrics().fMenuPadding); }

    std::vector<bool> selectionFlags() const {
        std::vector<bool> vecSelected;
        for (int64 iIndex = 0; iIndex < m_vecItems.size(); iIndex++) { vecSelected.push_back(isItemSelected(iIndex)); }
        return vecSelected;
    }

protected:
    std::vector<std::string> m_vecItems;
    ItemListView m_objItemListView;

    virtual std::string displayText() const = 0;
    virtual bool isItemSelected(int64 iIndex) const = 0;
    virtual bool showsCheckBoxes() const = 0;
    virtual void handleItemClicked(UiContext& objUiContext, int64 iIndex) = 0;
    virtual void stepSelection(UiContext& objUiContext, int64 iDirection) {}

    float64 measureHeight(UiContext& objUiContext, float64 fWidth) override { return rowHeight(objUiContext); }

    void togglePopup(UiContext& objUiContext) {
        if (objUiContext.isPopupOpen(this)) {
            objUiContext.closePopup();
            return;
        }
        objUiContext.openPopup(this);
        Rect objRectList = listViewBounds(objUiContext);
        for (int64 iIndex = 0; iIndex < m_vecItems.size(); iIndex++) {
            if (!isItemSelected(iIndex)) { continue; }
            m_objItemListView.scrollToItem(objUiContext, objRectList, m_vecItems.size(), iIndex);
            break;
        }
    }

    void update(UiContext& objUiContext) override {
        bool bHoveredNow = isInteractive(objUiContext, boxBounds(objUiContext));
        trackHover(objUiContext, bHoveredNow);
        updateKeybindButton(objUiContext, m_objRectBounds);
        m_fOpenBlend = approachValue(m_fOpenBlend, objUiContext.isPopupOpen(this) ? 1.0 : 0.0, objUiContext.animationStep());
        if (activationKeyPressed(objUiContext)) { togglePopup(objUiContext); }
        if (acceptsKeyboardInput(objUiContext) && objUiContext.input().isKeyPressedRepeating(vk::up)) { stepSelection(objUiContext, -1); }
        if (acceptsKeyboardInput(objUiContext) && objUiContext.input().isKeyPressedRepeating(vk::down)) { stepSelection(objUiContext, 1); }
        if (!bHoveredNow || !objUiContext.input().isMousePressed()) { return; }
        objUiContext.input().consumeMousePress();
        takeFocus(objUiContext);
        togglePopup(objUiContext);
    }

    void draw(UiContext& objUiContext) override {
        Painter& objPainter = objUiContext.painter();
        float64 fRounding = objUiContext.metrics().fWidgetRounding;
        WidgetVisuals objWidgetVisuals = stateVisuals(objUiContext, m_fHoverBlend, 0.0, m_fOpenBlend);
        Rect objRectBox = boxBounds(objUiContext).expanded(objWidgetVisuals.fExpansion);
        objPainter.fillRect(objRectBox, objWidgetVisuals.objColorFill, fRounding);
        objPainter.strokeRect(objRectBox, objWidgetVisuals.objColorStroke, 1.0, fRounding);

        std::string strDisplay = displayText();
        bool bIsPlaceholder = strDisplay.empty();
        color objColorText = bIsPlaceholder ? textColor(objUiContext, ColorRole::TextWeak) : objWidgetVisuals.objColorText;
        Rect objRectText = objRectBox.withoutLeft(6.0).withoutRight(fTriangleWidth + 12.0);
        objPainter.drawTextInRect(bIsPlaceholder ? std::string("None") : strDisplay, objRectText, objColorText, FontRole::Body, HorizontalAlignment::Left);
        vec2 objVec2TriangleCenter = vec2(objRectBox.right() - 6.0 - fTriangleWidth * 0.5, objRectBox.centerY());
        objPainter.drawDropdownTriangle(objVec2TriangleCenter, fTriangleWidth, m_fOpenBlend > 0.5, objWidgetVisuals.objColorText);

        objPainter.drawTextInRect(m_strLabel, labelBesideControl(objUiContext), textColor(objUiContext, ColorRole::TextNormal), FontRole::Body, HorizontalAlignment::Left);
        drawFocusRing(objUiContext, boxBounds(objUiContext));
        drawKeybindButton(objUiContext);
    }

public:
    DropdownBase(const std::string& strLabel, const std::vector<std::string>& vecItems) : Component(strLabel), m_vecItems(vecItems) {}

    const std::vector<std::string>& items() const { return m_vecItems; }

    Rect popupBounds(UiContext& objUiContext) override {
        Rect objRectBox = boxBounds(objUiContext);
        int64 iVisibleItems = clamp(m_vecItems.size(), static_cast<int64>(1), iMaximumVisibleItems);
        float64 fHeight = ItemListView::contentHeight(objUiContext, iVisibleItems) + objUiContext.metrics().fMenuPadding * 2.0;
        Rect objRectBelow = Rect(objRectBox.fX, objRectBox.bottom() + fPopupGap, objRectBox.fWidth, fHeight);
        if (objRectBelow.bottom() <= objUiContext.viewBounds().bottom()) { return objRectBelow; }
        return Rect(objRectBox.fX, objRectBox.fY - fPopupGap - fHeight, objRectBox.fWidth, fHeight);
    }

    void updatePopup(UiContext& objUiContext) override {
        int64 iClickedIndex = m_objItemListView.update(objUiContext, listViewBounds(objUiContext), m_vecItems.size());
        if (iClickedIndex >= 0) { handleItemClicked(objUiContext, iClickedIndex); }
    }

    void drawPopup(UiContext& objUiContext) override {
        Painter& objPainter = objUiContext.painter();
        float64 fRounding = objUiContext.metrics().fMenuRounding;
        Rect objRectPopup = popupBounds(objUiContext);
        objPainter.drawShadow(objRectPopup, fRounding, colorOf(objUiContext, ColorRole::WindowShadow), 8.0, vec2(3.0, 5.0));
        objPainter.fillRect(objRectPopup, colorOf(objUiContext, ColorRole::WindowFill), fRounding);
        objPainter.strokeRect(objRectPopup, colorOf(objUiContext, ColorRole::WindowStroke), 1.0, fRounding);
        m_objItemListView.draw(objUiContext, this, listViewBounds(objUiContext), m_vecItems, selectionFlags(), showsCheckBoxes());
    }
};

}
