#pragma once

namespace ui {

class Combobox : public DropdownBase {
    int64 m_iSelectedIndex;
    SelectionCallback m_fnOnChange = null;

    void changeSelection(int64 iIndex) {
        if (iIndex < 0 || iIndex >= m_vecItems.size() || iIndex == m_iSelectedIndex) { return; }
        m_iSelectedIndex = iIndex;
        if (m_fnOnChange != null && callbacksAllowed()) { m_fnOnChange(m_iSelectedIndex, m_vecItems[m_iSelectedIndex]); }
    }

protected:
    std::string displayText() const override {
        return m_iSelectedIndex >= 0 && m_iSelectedIndex < m_vecItems.size() ? m_vecItems[m_iSelectedIndex] : "";
    }

    bool isItemSelected(int64 iIndex) const override { return iIndex == m_iSelectedIndex; }
    bool showsCheckBoxes() const override { return false; }

    void handleItemClicked(UiContext& objUiContext, int64 iIndex) override {
        objUiContext.closePopup();
        changeSelection(iIndex);
    }

    void stepSelection(UiContext& objUiContext, int64 iDirection) override {
        if (m_vecItems.empty()) { return; }
        int64 iStart = m_iSelectedIndex < 0 ? (iDirection > 0 ? -1 : m_vecItems.size()) : m_iSelectedIndex;
        changeSelection(clamp(iStart + iDirection, static_cast<int64>(0), m_vecItems.size() - 1));
    }

public:
    Combobox(const std::string& strLabel, const std::vector<std::string>& vecItems, int64 iSelectedIndex)
        : DropdownBase(strLabel, vecItems), m_iSelectedIndex(iSelectedIndex < vecItems.size() ? iSelectedIndex : -1) {}

    Combobox* onChange(SelectionCallback fnOnChange) {
        m_fnOnChange = fnOnChange;
        return this;
    }

    int64 selectedIndex() const { return m_iSelectedIndex; }
    std::string selectedItem() const { return displayText(); }

    void setSelectedIndex(int64 iIndex) { m_iSelectedIndex = iIndex >= 0 && iIndex < m_vecItems.size() ? iIndex : -1; }

    void setItems(const std::vector<std::string>& vecItems) {
        m_vecItems = vecItems;
        if (m_iSelectedIndex >= m_vecItems.size()) { m_iSelectedIndex = -1; }
    }

    std::string typeName() const override { return "combo box"; }

    ComponentValue copyValue() const override {
        if (m_iSelectedIndex < 0) { return ComponentValue(); }
        return ComponentValue::ofSelection(m_iSelectedIndex, m_vecItems[m_iSelectedIndex]);
    }

    bool pasteValue(UiContext& objUiContext, const ComponentValue& objValue, bool bApply) override {
        int64 iIndex = values::tryReadSelectionIndex(objValue, m_vecItems);
        if (iIndex < 0) { return false; }
        if (bApply) { changeSelection(iIndex); }
        return true;
    }
};

}
