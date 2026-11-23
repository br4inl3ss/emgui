#pragma once

namespace ui {

class MultiCombobox : public DropdownBase {
    std::vector<bool> m_vecSelected;
    MultiSelectionCallback m_fnOnChange = null;

    void changeItem(int64 iIndex, bool bSelected) {
        if (m_vecSelected[iIndex] == bSelected) { return; }
        m_vecSelected[iIndex] = bSelected;
        if (m_fnOnChange != null && callbacksAllowed()) { m_fnOnChange(iIndex, m_vecItems[iIndex], bSelected); }
    }

    std::vector<std::string> pastedItemNames(const ComponentValue& objValue) const {
        if (objValue.eKind == ValueKind::MultiSelection) { return objValue.vecItems; }
        std::vector<std::string> vecNames;
        if (objValue.eKind == ValueKind::Selection || objValue.eKind == ValueKind::Text) { vecNames.push_back(objValue.strText); }
        return vecNames;
    }

protected:
    std::string displayText() const override {
        std::vector<std::string> vecSelectedItems = selectedItems();
        return std::join(vecSelectedItems, ", ");
    }

    bool isItemSelected(int64 iIndex) const override { return iIndex >= 0 && iIndex < m_vecSelected.size() && m_vecSelected[iIndex]; }
    bool showsCheckBoxes() const override { return true; }

    void handleItemClicked(UiContext& objUiContext, int64 iIndex) override { changeItem(iIndex, !m_vecSelected[iIndex]); }

public:
    MultiCombobox(const std::string& strLabel, const std::vector<std::string>& vecItems) : DropdownBase(strLabel, vecItems) {
        m_vecSelected.resize(vecItems.size(), false);
    }

    MultiCombobox* onChange(MultiSelectionCallback fnOnChange) {
        m_fnOnChange = fnOnChange;
        return this;
    }

    bool isSelected(int64 iIndex) const { return isItemSelected(iIndex); }

    void setSelected(int64 iIndex, bool bSelected) {
        if (iIndex >= 0 && iIndex < m_vecSelected.size()) { m_vecSelected[iIndex] = bSelected; }
    }

    std::vector<std::string> selectedItems() const {
        std::vector<std::string> vecSelectedItems;
        for (int64 iIndex = 0; iIndex < m_vecItems.size(); iIndex++) {
            if (m_vecSelected[iIndex]) { vecSelectedItems.push_back(m_vecItems[iIndex]); }
        }
        return vecSelectedItems;
    }

    void setItems(const std::vector<std::string>& vecItems) {
        m_vecItems = vecItems;
        m_vecSelected.clear();
        m_vecSelected.resize(vecItems.size(), false);
    }

    std::string typeName() const override { return "multi-select combo box"; }
    ComponentValue copyValue() const override { return ComponentValue::ofMultiSelection(selectedItems()); }

    bool pasteValue(UiContext& objUiContext, const ComponentValue& objValue, bool bApply) override {
        std::vector<std::string> vecNames = pastedItemNames(objValue);
        bool bIsSelectionKind = objValue.eKind == ValueKind::MultiSelection || objValue.eKind == ValueKind::Selection || objValue.eKind == ValueKind::Text;
        if (!bIsSelectionKind) { return false; }
        for (const std::string& strName : vecNames) {
            if (values::findItem(m_vecItems, strName) < 0) { return false; }
        }
        if (!bApply) { return true; }
        for (int64 iIndex = 0; iIndex < m_vecItems.size(); iIndex++) {
            changeItem(iIndex, values::findItem(vecNames, m_vecItems[iIndex]) >= 0);
        }
        return true;
    }
};

}
