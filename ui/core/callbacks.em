#pragma once

namespace ui {

delegate void ClickCallback();
delegate void HoverCallback(bool bHovered);
delegate void BoolCallback(bool bValue);
delegate void IntCallback(int64 iValue);
delegate void FloatCallback(float64 fValue);
delegate void TextCallback(const std::string& strText);
delegate void SelectionCallback(int64 iIndex, const std::string& strItem);
delegate void MultiSelectionCallback(int64 iIndex, const std::string& strItem, bool bSelected);
delegate void Vec2Callback(vec2 objVec2Value);
delegate void KeybindStateCallback(bool bActive);
delegate void ColorCallback(color objColorValue);

}
