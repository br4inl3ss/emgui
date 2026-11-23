#pragma once

namespace ui {

class Listbox : public Component {
    static constexpr float64 fFramePadding = 3.0;

    std::vector<std::string> m_vecItems;
    int64 m_iSelectedIndex = -1;
    int64 m_iVisibleRows = 5;
    ItemListView m_objItemListView;
    SelectionCallback m_fnOnSelect = null;

    bool hasLabelRow() const { return !m_strLabel.empty(); }

    float64 listFrameHeight(const UiContext& objUiContext) const {
        return ItemListView::contentHeight(objUiContext, m_iVisibleRows) + fFramePadding * 2.0;
    }

    Rect listFrameBounds(const UiContext& objUiContext) const { return m_objRectBounds.takeBottom(listFrameHeight(objUiContext)); }

    std::vector<bool> selectionFlags() const {
        std::vector<bool> vecSelected;
        vecSelected.resize(m_vecItems.size(), false);
        if (m_iSelectedIndex >= 0 && m_iSelectedIndex < m_vecItems.size()) { vecSelected[m_iSelectedIndex] = true; }
        return vecSelected;
    }

public:
    Listbox(const std::string& strLabel, const std::vector<std::string>& vecItems) : Component(strLabel), m_vecItems(vecItems) {}

    Listbox* onSelect(SelectionCallback fnOnSelect) {
        m_fnOnSelect = fnOnSelect;
        return this;
    }

    Listbox* setVisibleRows(int64 iVisibleRows) {
        m_iVisibleRows = clamp(iVisibleRows, static_cast<int64>(1), static_cast<int64>(30));
        return this;
    }

    int64 selectedIndex() const { return m_iSelectedIndex; }
    std::string selectedItem() const { return m_iSelectedIndex >= 0 ? m_vecItems[m_iSelectedIndex] : ""; }
    void setSelectedIndex(int64 iIndex) { m_iSelectedIndex = iIndex >= 0 && iIndex < m_vecItems.size() ? iIndex : -1; }
    const std::vector<std::string>& items() const { return m_vecItems; }

    void setItems(const std::vector<std::string>& vecItems) {
        m_vecItems = vecItems;
        if (m_iSelectedIndex >= m_vecItems.size()) { m_iSelectedIndex = -1; }
    }

    void addItem(const std::string& strItem) { m_vecItems.push_back(strItem); }

    std::string typeName() const override { return "list box"; }

    ComponentValue copyValue() const override {
        if (m_iSelectedIndex < 0) { return ComponentValue(); }
        return ComponentValue::ofSelection(m_iSelectedIndex, m_vecItems[m_iSelectedIndex]);
    }

    bool pasteValue(UiContext& objUiContext, const ComponentValue& objValue, bool bApply) override {
        int64 iIndex = values::tryReadSelectionIndex(objValue, m_vecItems);
        if (iIndex < 0) { return false; }
        if (bApply) { changeSelection(objUiContext, iIndex); }
        return true;
    }

protected:
    void changeSelection(UiContext& objUiContext, int64 iIndex) {
        if (iIndex < 0 || iIndex >= m_vecItems.size() || iIndex == m_iSelectedIndex) { return; }
        m_iSelectedIndex = iIndex;
        m_objItemListView.scrollToItem(objUiContext, listFrameBounds(objUiContext).shrunk(fFramePadding), m_vecItems.size(), iIndex);
        if (m_fnOnSelect != null && callbacksAllowed()) { m_fnOnSelect(m_iSelectedIndex, m_vecItems[m_iSelectedIndex]); }
    }

    float64 measureHeight(UiContext& objUiContext, float64 fWidth) override {
        return (hasLabelRow() ? rowHeight(objUiContext) + objUiContext.metrics().fItemSpacing : 0.0) + listFrameHeight(objUiContext);
    }

    void update(UiContext& objUiContext) override {
        Rect objRectFrame = listFrameBounds(objUiContext);
        bool bHoveredNow = isInteractive(objUiContext, objRectFrame);
        trackHover(objUiContext, bHoveredNow);
        if (hasLabelRow()) { updateKeybindButton(objUiContext, m_objRectBounds.takeTop(rowHeight(objUiContext))); }
        if (!m_bEnabled) { return; }
        if (bHoveredNow && objUiContext.input().isMousePressed()) { takeFocus(objUiContext); }
        if (acceptsKeyboardInput(objUiContext) && objUiContext.input().isKeyPressedRepeating(vk::up)) { changeSelection(objUiContext, max(m_iSelectedIndex - 1, static_cast<int64>(0))); }
        if (acceptsKeyboardInput(objUiContext) && objUiContext.input().isKeyPressedRepeating(vk::down)) { changeSelection(objUiContext, m_iSelectedIndex + 1); }
        changeSelection(objUiContext, m_objItemListView.update(objUiContext, objRectFrame.shrunk(fFramePadding), m_vecItems.size()));
    }

    void draw(UiContext& objUiContext) override {
        Painter& objPainter = objUiContext.painter();
        float64 fRounding = objUiContext.metrics().fWidgetRounding;
        if (hasLabelRow()) {
            Rect objRectLabel = m_objRectBounds.takeTop(rowHeight(objUiContext)).withoutRight(keybindReservedWidth(objUiContext));
            objPainter.drawTextInRect(m_strLabel, objRectLabel, textColor(objUiContext, ColorRole::TextNormal), FontRole::Body, HorizontalAlignment::Left);
            drawKeybindButton(objUiContext);
        }
        Rect objRectFrame = listFrameBounds(objUiContext);
        objPainter.fillRect(objRectFrame, textColor(objUiContext, ColorRole::ExtremeBackground), fRounding);
        objPainter.strokeRect(objRectFrame, textColor(objUiContext, ColorRole::WindowStroke), 1.0, fRounding);
        m_objItemListView.draw(objUiContext, this, objRectFrame.shrunk(fFramePadding), m_vecItems, selectionFlags(), false);
        drawFocusRing(objUiContext, objRectFrame);
    }
};

}
