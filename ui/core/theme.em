#pragma once

namespace ui {

enum class ColorRole : int32 {
    WindowFill,
    WindowStroke,
    WindowShadow,
    Separator,
    GroupFill,
    GroupStroke,
    TextNormal,
    TextStrong,
    TextWeak,
    Hyperlink,
    ExtremeBackground,
    WidgetFill,
    WidgetStroke,
    WidgetText,
    WidgetHoveredFill,
    WidgetHoveredStroke,
    WidgetHoveredText,
    WidgetActiveFill,
    WidgetActiveStroke,
    WidgetActiveText,
    WidgetOpenFill,
    WidgetOpenStroke,
    WidgetOpenText,
    SelectionFill,
    SelectionStroke,
    Count
};

struct WidgetVisuals {
    color objColorFill;
    color objColorStroke;
    color objColorText;
    float64 fExpansion = 0.0;
};

struct ThemeMetrics {
    float64 fWindowRounding = 6.0;
    float64 fMenuRounding = 6.0;
    float64 fGroupRounding = 3.0;
    float64 fWidgetRounding = 2.0;
    float64 fWindowMargin = 8.0;
    float64 fTitleBarHeight = 30.0;
    float64 fTabBarHeight = 32.0;
    float64 fTabButtonHeight = 22.0;
    float64 fGroupMargin = 8.0;
    float64 fGroupGap = 8.0;
    float64 fGroupHeaderHeight = 24.0;
    float64 fItemSpacing = 5.0;
    float64 fInteractHeight = 20.0;
    float64 fButtonPadding = 8.0;
    float64 fIconSpacing = 6.0;
    float64 fCheckboxSize = 14.0;
    float64 fControlWidthRatio = 0.62;
    float64 fMenuPadding = 4.0;
    float64 fScrollbarWidth = 6.0;
    float64 fResizeCornerSize = 12.0;
    float64 fShadowSize = 14.0;
    float64 fAnimationSpeed = 16.0;
};

class Theme {
    std::vector<color> m_vecColors;
    ThemeMetrics m_objThemeMetrics;

    static color gray(int32 iLevel) {
        uint8 uLevel = static_cast<uint8>(iLevel);
        return color(uLevel, uLevel, uLevel, 255);
    }

    static color transparentGray(int32 iLevel) {
        uint8 uLevel = static_cast<uint8>(iLevel);
        return color(uLevel, uLevel, uLevel, 0);
    }

public:
    Theme() {
        m_vecColors.resize(static_cast<int64>(ColorRole::Count));
    }

    color colorOf(ColorRole eRole) const {
        return m_vecColors[static_cast<int64>(eRole)];
    }

    void setColor(ColorRole eRole, color objColorValue) {
        if (eRole == ColorRole::Count) { return; }
        m_vecColors[static_cast<int64>(eRole)] = objColorValue;
    }

    void setAccent(color objColorAccent) {
        color objColorWindow = colorOf(ColorRole::WindowFill);
        bool bLightTheme = static_cast<int64>(objColorWindow.r) + static_cast<int64>(objColorWindow.g) + static_cast<int64>(objColorWindow.b) > 384;
        setColor(ColorRole::SelectionFill, objColorAccent);
        setColor(ColorRole::SelectionStroke, bLightTheme ? objColorAccent.scale_rgb(0.35) : objColorAccent.lerp(color(255, 255, 255, 255), 0.72));
    }

    ThemeMetrics& metrics() { return m_objThemeMetrics; }
    const ThemeMetrics& metrics() const { return m_objThemeMetrics; }

    static Theme dark() {
        Theme objTheme;
        objTheme.setColor(ColorRole::WindowFill, gray(27));
        objTheme.setColor(ColorRole::WindowStroke, gray(60));
        objTheme.setColor(ColorRole::WindowShadow, color(0, 0, 0, 96));
        objTheme.setColor(ColorRole::Separator, gray(60));
        objTheme.setColor(ColorRole::GroupFill, transparentGray(27));
        objTheme.setColor(ColorRole::GroupStroke, gray(60));
        objTheme.setColor(ColorRole::TextNormal, gray(140));
        objTheme.setColor(ColorRole::TextStrong, gray(255));
        objTheme.setColor(ColorRole::TextWeak, gray(95));
        objTheme.setColor(ColorRole::Hyperlink, color(90, 170, 255, 255));
        objTheme.setColor(ColorRole::ExtremeBackground, gray(10));
        objTheme.setColor(ColorRole::WidgetFill, gray(60));
        objTheme.setColor(ColorRole::WidgetStroke, transparentGray(150));
        objTheme.setColor(ColorRole::WidgetText, gray(180));
        objTheme.setColor(ColorRole::WidgetHoveredFill, gray(70));
        objTheme.setColor(ColorRole::WidgetHoveredStroke, gray(150));
        objTheme.setColor(ColorRole::WidgetHoveredText, gray(240));
        objTheme.setColor(ColorRole::WidgetActiveFill, gray(55));
        objTheme.setColor(ColorRole::WidgetActiveStroke, gray(255));
        objTheme.setColor(ColorRole::WidgetActiveText, gray(255));
        objTheme.setColor(ColorRole::WidgetOpenFill, gray(45));
        objTheme.setColor(ColorRole::WidgetOpenStroke, gray(60));
        objTheme.setColor(ColorRole::WidgetOpenText, gray(210));
        objTheme.setColor(ColorRole::SelectionFill, color(0, 92, 128, 255));
        objTheme.setColor(ColorRole::SelectionStroke, color(192, 222, 255, 255));
        return objTheme;
    }

    static Theme light() {
        Theme objTheme;
        objTheme.setColor(ColorRole::WindowFill, gray(248));
        objTheme.setColor(ColorRole::WindowStroke, gray(190));
        objTheme.setColor(ColorRole::WindowShadow, color(0, 0, 0, 40));
        objTheme.setColor(ColorRole::Separator, gray(190));
        objTheme.setColor(ColorRole::GroupFill, transparentGray(248));
        objTheme.setColor(ColorRole::GroupStroke, gray(190));
        objTheme.setColor(ColorRole::TextNormal, gray(80));
        objTheme.setColor(ColorRole::TextStrong, gray(0));
        objTheme.setColor(ColorRole::TextWeak, gray(150));
        objTheme.setColor(ColorRole::Hyperlink, color(0, 155, 255, 255));
        objTheme.setColor(ColorRole::ExtremeBackground, gray(255));
        objTheme.setColor(ColorRole::WidgetFill, gray(230));
        objTheme.setColor(ColorRole::WidgetStroke, transparentGray(105));
        objTheme.setColor(ColorRole::WidgetText, gray(60));
        objTheme.setColor(ColorRole::WidgetHoveredFill, gray(220));
        objTheme.setColor(ColorRole::WidgetHoveredStroke, gray(105));
        objTheme.setColor(ColorRole::WidgetHoveredText, gray(0));
        objTheme.setColor(ColorRole::WidgetActiveFill, gray(165));
        objTheme.setColor(ColorRole::WidgetActiveStroke, gray(0));
        objTheme.setColor(ColorRole::WidgetActiveText, gray(0));
        objTheme.setColor(ColorRole::WidgetOpenFill, gray(220));
        objTheme.setColor(ColorRole::WidgetOpenStroke, gray(160));
        objTheme.setColor(ColorRole::WidgetOpenText, gray(0));
        objTheme.setColor(ColorRole::SelectionFill, color(144, 209, 255, 255));
        objTheme.setColor(ColorRole::SelectionStroke, color(0, 83, 125, 255));
        return objTheme;
    }
};

}
