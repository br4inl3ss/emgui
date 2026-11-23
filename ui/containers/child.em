#pragma once

namespace ui {

class Tab;

class Child : public Element {
    friend class Tab;

    std::vector<std::unique_ptr<Component>> m_vecComponents;

    template<typename TComponent>
    TComponent* adopt(TComponent* pComponent) {
        adoptChild(pComponent);
        m_vecComponents.push_back(std::unique_ptr<Component>(pComponent));
        return pComponent;
    }

    float64 measureHeight(UiContext& objUiContext, float64 fWidth) {
        const ThemeMetrics& objThemeMetrics = objUiContext.metrics();
        float64 fInnerWidth = fWidth - objThemeMetrics.fGroupMargin * 2.0;
        float64 fHeight = objThemeMetrics.fGroupHeaderHeight + objThemeMetrics.fGroupMargin * 2.0;
        for (int64 iIndex = 0; iIndex < m_vecComponents.size(); iIndex++) {
            if (iIndex > 0) { fHeight += objThemeMetrics.fItemSpacing; }
            fHeight += m_vecComponents[iIndex]->measureHeight(objUiContext, fInnerWidth);
        }
        return fHeight;
    }

    void arrange(UiContext& objUiContext, const Rect& objRectBounds) {
        const ThemeMetrics& objThemeMetrics = objUiContext.metrics();
        m_objRectBounds = objRectBounds;
        float64 fInnerWidth = objRectBounds.fWidth - objThemeMetrics.fGroupMargin * 2.0;
        float64 fY = objRectBounds.fY + objThemeMetrics.fGroupHeaderHeight + objThemeMetrics.fGroupMargin;
        for (std::unique_ptr<Component>& upComponent : m_vecComponents) {
            float64 fHeight = upComponent->measureHeight(objUiContext, fInnerWidth);
            upComponent->arrange(Rect(objRectBounds.fX + objThemeMetrics.fGroupMargin, fY, fInnerWidth, fHeight));
            fY += fHeight + objThemeMetrics.fItemSpacing;
        }
    }

    void update(UiContext& objUiContext) {
        trackHover(objUiContext, objUiContext.isMouseOver(m_objRectBounds));
        for (std::unique_ptr<Component>& upComponent : m_vecComponents) {
            upComponent->update(objUiContext);
            upComponent->offerContextMenu(objUiContext);
        }
    }

    void appendFocusableComponents(std::vector<Component*>& vecComponents) const {
        for (const std::unique_ptr<Component>& upComponent : m_vecComponents) {
            if (upComponent->acceptsKeyboardFocus()) { vecComponents.push_back(upComponent.get()); }
        }
    }

    void draw(UiContext& objUiContext) {
        Painter& objPainter = objUiContext.painter();
        const ThemeMetrics& objThemeMetrics = objUiContext.metrics();
        objPainter.fillRect(m_objRectBounds, colorOf(objUiContext, ColorRole::GroupFill), objThemeMetrics.fGroupRounding);
        objPainter.strokeRect(m_objRectBounds, colorOf(objUiContext, ColorRole::GroupStroke), 1.0, objThemeMetrics.fGroupRounding);

        Rect objRectHeader = m_objRectBounds.takeTop(objThemeMetrics.fGroupHeaderHeight + objThemeMetrics.fGroupMargin * 0.5)
            .withoutLeft(objThemeMetrics.fGroupMargin).withoutRight(objThemeMetrics.fGroupMargin);
        objPainter.drawTextInRect(m_strLabel, objRectHeader.withoutTop(objThemeMetrics.fGroupMargin * 0.5), colorOf(objUiContext, ColorRole::TextStrong), FontRole::Heading, HorizontalAlignment::Left);
        objPainter.fillRect(Rect(objRectHeader.fX, objRectHeader.bottom(), objRectHeader.fWidth, 1.0), colorOf(objUiContext, ColorRole::Separator), 0.0);

        for (std::unique_ptr<Component>& upComponent : m_vecComponents) { upComponent->draw(objUiContext); }
    }

public:
    Child(const std::string& strTitle) : Element(strTitle) {}

    Label* addLabel(const std::string& strText) { return adopt(new Label(strText)); }
    Button* addButton(const std::string& strLabel) { return adopt(new Button(strLabel)); }
    Checkbox* addCheckbox(const std::string& strLabel, bool bChecked) { return adopt(new Checkbox(strLabel, bChecked)); }
    Checkbox* addCheckbox(const std::string& strLabel) { return adopt(new Checkbox(strLabel, false)); }

    SliderInt* addSliderInt(const std::string& strLabel, int64 iMinimum, int64 iMaximum, int64 iValue) {
        return adopt(new SliderInt(strLabel, iMinimum, iMaximum, iValue));
    }

    SliderFloat* addSliderFloat(const std::string& strLabel, float64 fMinimum, float64 fMaximum, float64 fValue) {
        return adopt(new SliderFloat(strLabel, fMinimum, fMaximum, fValue));
    }

    Combobox* addCombobox(const std::string& strLabel, const std::vector<std::string>& vecItems, int64 iSelectedIndex) {
        return adopt(new Combobox(strLabel, vecItems, iSelectedIndex));
    }

    Combobox* addCombobox(const std::string& strLabel, const std::vector<std::string>& vecItems) {
        return adopt(new Combobox(strLabel, vecItems, 0));
    }

    MultiCombobox* addMultiCombobox(const std::string& strLabel, const std::vector<std::string>& vecItems) {
        return adopt(new MultiCombobox(strLabel, vecItems));
    }

    Listbox* addListbox(const std::string& strLabel, const std::vector<std::string>& vecItems) {
        return adopt(new Listbox(strLabel, vecItems));
    }

    Textfield* addTextfield(const std::string& strLabel, const std::string& strPlaceholder) {
        return adopt(new Textfield(strLabel, strPlaceholder));
    }

    Textfield* addTextfield(const std::string& strLabel) { return adopt(new Textfield(strLabel, "")); }

    ColorPicker* addColorPicker(const std::string& strLabel, color objColorInitial) { return adopt(new ColorPicker(strLabel, objColorInitial)); }

    template<typename TComponent>
    TComponent* addComponent(TComponent* pCustomComponent) { return adopt(pCustomComponent); }

    int64 componentCount() const { return m_vecComponents.size(); }
};

}
