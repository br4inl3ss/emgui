#pragma once

namespace ui {

struct SvgShape {
    std::vector<std::vector<vec2>> vecContours;
    std::vector<bool> vecContourIsClosed;
    bool bFillEnabled = true;
    bool bFillUsesEvenOddRule = false;
    color objColorFill = color(0, 0, 0, 255);
    bool bStrokeEnabled = false;
    color objColorStroke = color(0, 0, 0, 255);
    float64 fStrokeWidth = 1.0;
};

struct SvgDocument {
    Rect objRectViewBox;
    std::vector<SvgShape> vecShapes;

    bool isValid() const { return !vecShapes.empty() && !objRectViewBox.isEmpty(); }
};

}
