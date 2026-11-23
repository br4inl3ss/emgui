#pragma once

namespace ui {

class Element {
    std::vector<ColorRole> m_vecOverriddenRoles;
    std::vector<color> m_vecOverrideColors;
    HoverCallback m_fnOnHover = null;

protected:
    Element* m_pParent = null;
    KeybindRegistry* m_pKeybindRegistry = null;
    Rect m_objRectBounds;
    std::string m_strLabel;
    bool m_bHovered = false;
    float64 m_fHoverBlend = 0.0;

    void adoptChild(Element* pElementChild) {
        pElementChild->m_pParent = this;
        pElementChild->m_pKeybindRegistry = m_pKeybindRegistry;
    }

    void trackHover(UiContext& objUiContext, bool bHoveredNow) {
        m_fHoverBlend = approachValue(m_fHoverBlend, bHoveredNow ? 1.0 : 0.0, objUiContext.animationStep());
        if (bHoveredNow == m_bHovered) { return; }
        m_bHovered = bHoveredNow;
        if (m_fnOnHover != null) { m_fnOnHover(m_bHovered); }
    }

public:
    Element(const std::string& strLabel) : m_strLabel(strLabel) {}
    virtual ~Element() {}

    Element(const Element& objElementOther) = delete;
    Element& operator=(const Element& objElementOther) = delete;

    const std::string& label() const { return m_strLabel; }
    void setLabel(const std::string& strLabel) { m_strLabel = strLabel; }
    const Rect& bounds() const { return m_objRectBounds; }
    bool isHovered() const { return m_bHovered; }
    Element* parent() const { return m_pParent; }

    void onHover(HoverCallback fnOnHover) { m_fnOnHover = fnOnHover; }

    void setColor(ColorRole eRole, color objColorValue) {
        for (int64 iIndex = 0; iIndex < m_vecOverriddenRoles.size(); iIndex++) {
            if (m_vecOverriddenRoles[iIndex] == eRole) {
                m_vecOverrideColors[iIndex] = objColorValue;
                return;
            }
        }
        m_vecOverriddenRoles.push_back(eRole);
        m_vecOverrideColors.push_back(objColorValue);
    }

    void resetColor(ColorRole eRole) {
        for (int64 iIndex = 0; iIndex < m_vecOverriddenRoles.size(); iIndex++) {
            if (m_vecOverriddenRoles[iIndex] == eRole) {
                m_vecOverriddenRoles.erase(m_vecOverriddenRoles.begin() + iIndex);
                m_vecOverrideColors.erase(m_vecOverrideColors.begin() + iIndex);
                return;
            }
        }
    }

    color colorOf(const UiContext& objUiContext, ColorRole eRole) const {
        const Element* pElementCurrent = this;
        while (pElementCurrent != null) {
            for (int64 iIndex = 0; iIndex < pElementCurrent->m_vecOverriddenRoles.size(); iIndex++) {
                if (pElementCurrent->m_vecOverriddenRoles[iIndex] == eRole) { return pElementCurrent->m_vecOverrideColors[iIndex]; }
            }
            pElementCurrent = pElementCurrent->m_pParent;
        }
        return objUiContext.theme().colorOf(eRole);
    }

    WidgetVisuals widgetVisuals(const UiContext& objUiContext, float64 fHoverBlend, float64 fActiveBlend, float64 fOpenBlend) const {
        WidgetVisuals objWidgetVisuals;
        objWidgetVisuals.objColorFill = colorOf(objUiContext, ColorRole::WidgetFill)
            .lerp(colorOf(objUiContext, ColorRole::WidgetOpenFill), fOpenBlend)
            .lerp(colorOf(objUiContext, ColorRole::WidgetHoveredFill), fHoverBlend)
            .lerp(colorOf(objUiContext, ColorRole::WidgetActiveFill), fActiveBlend);
        objWidgetVisuals.objColorStroke = colorOf(objUiContext, ColorRole::WidgetStroke)
            .lerp(colorOf(objUiContext, ColorRole::WidgetOpenStroke), fOpenBlend)
            .lerp(colorOf(objUiContext, ColorRole::WidgetHoveredStroke), fHoverBlend)
            .lerp(colorOf(objUiContext, ColorRole::WidgetActiveStroke), fActiveBlend);
        objWidgetVisuals.objColorText = colorOf(objUiContext, ColorRole::WidgetText)
            .lerp(colorOf(objUiContext, ColorRole::WidgetOpenText), fOpenBlend)
            .lerp(colorOf(objUiContext, ColorRole::WidgetHoveredText), fHoverBlend)
            .lerp(colorOf(objUiContext, ColorRole::WidgetActiveText), fActiveBlend);
        objWidgetVisuals.fExpansion = fmax(fHoverBlend, fActiveBlend);
        return objWidgetVisuals;
    }
};

}
