#pragma once

namespace ui {

struct Rect {
    float64 fX;
    float64 fY;
    float64 fWidth;
    float64 fHeight;

    Rect() : fX(0.0), fY(0.0), fWidth(0.0), fHeight(0.0) {}
    Rect(float64 fXValue, float64 fYValue, float64 fWidthValue, float64 fHeightValue)
        : fX(fXValue), fY(fYValue), fWidth(fWidthValue), fHeight(fHeightValue) {}

    float64 right() const { return fX + fWidth; }
    float64 bottom() const { return fY + fHeight; }
    float64 centerX() const { return fX + fWidth * 0.5; }
    float64 centerY() const { return fY + fHeight * 0.5; }
    vec2 position() const { return vec2(fX, fY); }
    vec2 size() const { return vec2(fWidth, fHeight); }
    vec2 center() const { return vec2(centerX(), centerY()); }
    bool isEmpty() const { return fWidth <= 0.0 || fHeight <= 0.0; }

    bool contains(vec2 objVec2Point) const {
        return objVec2Point.x >= fX && objVec2Point.x < fX + fWidth
            && objVec2Point.y >= fY && objVec2Point.y < fY + fHeight;
    }

    Rect shrunk(float64 fAmount) const {
        return Rect(fX + fAmount, fY + fAmount, fmax(0.0, fWidth - fAmount * 2.0), fmax(0.0, fHeight - fAmount * 2.0));
    }

    Rect expanded(float64 fAmount) const {
        return Rect(fX - fAmount, fY - fAmount, fWidth + fAmount * 2.0, fHeight + fAmount * 2.0);
    }

    Rect translated(float64 fOffsetX, float64 fOffsetY) const {
        return Rect(fX + fOffsetX, fY + fOffsetY, fWidth, fHeight);
    }

    Rect intersection(const Rect& objRectOther) const {
        float64 fLeft = fmax(fX, objRectOther.fX);
        float64 fTop = fmax(fY, objRectOther.fY);
        float64 fRight = fmin(right(), objRectOther.right());
        float64 fBottom = fmin(bottom(), objRectOther.bottom());
        return Rect(fLeft, fTop, fmax(0.0, fRight - fLeft), fmax(0.0, fBottom - fTop));
    }

    Rect takeLeft(float64 fAmount) const { return Rect(fX, fY, fmin(fAmount, fWidth), fHeight); }
    Rect takeRight(float64 fAmount) const {
        float64 fTaken = fmin(fAmount, fWidth);
        return Rect(right() - fTaken, fY, fTaken, fHeight);
    }
    Rect takeTop(float64 fAmount) const { return Rect(fX, fY, fWidth, fmin(fAmount, fHeight)); }
    Rect takeBottom(float64 fAmount) const {
        float64 fTaken = fmin(fAmount, fHeight);
        return Rect(fX, bottom() - fTaken, fWidth, fTaken);
    }
    Rect withoutLeft(float64 fAmount) const {
        float64 fTaken = fmin(fAmount, fWidth);
        return Rect(fX + fTaken, fY, fWidth - fTaken, fHeight);
    }
    Rect withoutRight(float64 fAmount) const { return Rect(fX, fY, fmax(0.0, fWidth - fAmount), fHeight); }
    Rect withoutTop(float64 fAmount) const {
        float64 fTaken = fmin(fAmount, fHeight);
        return Rect(fX, fY + fTaken, fWidth, fHeight - fTaken);
    }
};

enum class HorizontalAlignment : int32 { Left, Center, Right };

float64 approachValue(float64 fCurrent, float64 fTarget, float64 fMaximumStep) {
    if (fCurrent < fTarget) { return fmin(fTarget, fCurrent + fMaximumStep); }
    return fmax(fTarget, fCurrent - fMaximumStep);
}

}
