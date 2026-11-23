#pragma once

namespace ui {

struct SvgTransform {
    float64 fA = 1.0;
    float64 fB = 0.0;
    float64 fC = 0.0;
    float64 fD = 1.0;
    float64 fE = 0.0;
    float64 fF = 0.0;

    vec2 apply(vec2 objVec2Point) const {
        return vec2(fA * objVec2Point.x + fC * objVec2Point.y + fE, fB * objVec2Point.x + fD * objVec2Point.y + fF);
    }

    SvgTransform then(const SvgTransform& objTransformInner) const {
        SvgTransform objTransformResult;
        objTransformResult.fA = fA * objTransformInner.fA + fC * objTransformInner.fB;
        objTransformResult.fB = fB * objTransformInner.fA + fD * objTransformInner.fB;
        objTransformResult.fC = fA * objTransformInner.fC + fC * objTransformInner.fD;
        objTransformResult.fD = fB * objTransformInner.fC + fD * objTransformInner.fD;
        objTransformResult.fE = fA * objTransformInner.fE + fC * objTransformInner.fF + fE;
        objTransformResult.fF = fB * objTransformInner.fE + fD * objTransformInner.fF + fF;
        return objTransformResult;
    }

    float64 averageScale() const { return sqrt(fabs(fA * fD - fB * fC)); }

    static SvgTransform matrix(float64 fAValue, float64 fBValue, float64 fCValue, float64 fDValue, float64 fEValue, float64 fFValue) {
        SvgTransform objTransform;
        objTransform.fA = fAValue;
        objTransform.fB = fBValue;
        objTransform.fC = fCValue;
        objTransform.fD = fDValue;
        objTransform.fE = fEValue;
        objTransform.fF = fFValue;
        return objTransform;
    }
};

class SvgPathBuilder {
    static constexpr int64 iMinimumCurveSegments = 6;
    static constexpr int64 iMaximumCurveSegments = 64;

    SvgTransform m_objTransform;
    vec2 m_objVec2Current = vec2(0.0, 0.0);
    vec2 m_objVec2ContourStart = vec2(0.0, 0.0);
    bool m_bContourOpen = false;
    std::vector<std::vector<vec2>> m_vecContours;
    std::vector<bool> m_vecContourIsClosed;

    void appendPoint(vec2 objVec2Point) {
        m_vecContours.back().push_back(m_objTransform.apply(objVec2Point));
    }

    void ensureContour() {
        if (m_bContourOpen) { return; }
        m_vecContours.push_back(std::vector<vec2>());
        m_vecContourIsClosed.push_back(false);
        m_bContourOpen = true;
        appendPoint(m_objVec2Current);
    }

    int64 curveSegmentCount(float64 fControlPolygonLength) const {
        float64 fScaledLength = fControlPolygonLength * fmax(0.01, m_objTransform.averageScale());
        return clamp(static_cast<int64>(ceil(fScaledLength * 0.75)), iMinimumCurveSegments, iMaximumCurveSegments);
    }

    static float64 distanceBetween(vec2 objVec2First, vec2 objVec2Second) {
        return hypot(objVec2Second.x - objVec2First.x, objVec2Second.y - objVec2First.y);
    }

    static float64 angleBetween(float64 fUx, float64 fUy, float64 fVx, float64 fVy) {
        return atan2(fUx * fVy - fUy * fVx, fUx * fVx + fUy * fVy);
    }

public:
    SvgPathBuilder(const SvgTransform& objTransform) : m_objTransform(objTransform) {}

    vec2 currentPoint() const { return m_objVec2Current; }

    void moveTo(vec2 objVec2Point) {
        m_bContourOpen = false;
        m_objVec2Current = objVec2Point;
        m_objVec2ContourStart = objVec2Point;
    }

    void lineTo(vec2 objVec2Point) {
        ensureContour();
        m_objVec2Current = objVec2Point;
        appendPoint(objVec2Point);
    }

    void cubicTo(vec2 objVec2ControlFirst, vec2 objVec2ControlSecond, vec2 objVec2End) {
        ensureContour();
        vec2 objVec2Start = m_objVec2Current;
        float64 fControlLength = distanceBetween(objVec2Start, objVec2ControlFirst)
            + distanceBetween(objVec2ControlFirst, objVec2ControlSecond)
            + distanceBetween(objVec2ControlSecond, objVec2End);
        int64 iSegments = curveSegmentCount(fControlLength);
        for (int64 iSegment = 1; iSegment <= iSegments; iSegment++) {
            float64 fT = static_cast<float64>(iSegment) / static_cast<float64>(iSegments);
            float64 fInverse = 1.0 - fT;
            float64 fWeightStart = fInverse * fInverse * fInverse;
            float64 fWeightFirst = 3.0 * fInverse * fInverse * fT;
            float64 fWeightSecond = 3.0 * fInverse * fT * fT;
            float64 fWeightEnd = fT * fT * fT;
            appendPoint(vec2(
                fWeightStart * objVec2Start.x + fWeightFirst * objVec2ControlFirst.x + fWeightSecond * objVec2ControlSecond.x + fWeightEnd * objVec2End.x,
                fWeightStart * objVec2Start.y + fWeightFirst * objVec2ControlFirst.y + fWeightSecond * objVec2ControlSecond.y + fWeightEnd * objVec2End.y));
        }
        m_objVec2Current = objVec2End;
    }

    void quadraticTo(vec2 objVec2Control, vec2 objVec2End) {
        vec2 objVec2Start = m_objVec2Current;
        vec2 objVec2ControlFirst = vec2(objVec2Start.x + (objVec2Control.x - objVec2Start.x) * 2.0 / 3.0, objVec2Start.y + (objVec2Control.y - objVec2Start.y) * 2.0 / 3.0);
        vec2 objVec2ControlSecond = vec2(objVec2End.x + (objVec2Control.x - objVec2End.x) * 2.0 / 3.0, objVec2End.y + (objVec2Control.y - objVec2End.y) * 2.0 / 3.0);
        cubicTo(objVec2ControlFirst, objVec2ControlSecond, objVec2End);
    }

    void arcTo(float64 fRadiusX, float64 fRadiusY, float64 fRotationDegrees, bool bLargeArc, bool bSweep, vec2 objVec2End) {
        vec2 objVec2Start = m_objVec2Current;
        if (fRadiusX == 0.0 || fRadiusY == 0.0) {
            lineTo(objVec2End);
            return;
        }
        if (objVec2Start.x == objVec2End.x && objVec2Start.y == objVec2End.y) { return; }

        float64 fRx = fabs(fRadiusX);
        float64 fRy = fabs(fRadiusY);
        float64 fPhi = deg_to_rad(fRotationDegrees);
        float64 fCosPhi = cos(fPhi);
        float64 fSinPhi = sin(fPhi);
        float64 fHalfDx = (objVec2Start.x - objVec2End.x) * 0.5;
        float64 fHalfDy = (objVec2Start.y - objVec2End.y) * 0.5;
        float64 fX1Prime = fCosPhi * fHalfDx + fSinPhi * fHalfDy;
        float64 fY1Prime = -fSinPhi * fHalfDx + fCosPhi * fHalfDy;

        float64 fLambda = (fX1Prime * fX1Prime) / (fRx * fRx) + (fY1Prime * fY1Prime) / (fRy * fRy);
        if (fLambda > 1.0) {
            float64 fLambdaRoot = sqrt(fLambda);
            fRx = fRx * fLambdaRoot;
            fRy = fRy * fLambdaRoot;
        }

        float64 fNumerator = fRx * fRx * fRy * fRy - fRx * fRx * fY1Prime * fY1Prime - fRy * fRy * fX1Prime * fX1Prime;
        float64 fDenominator = fRx * fRx * fY1Prime * fY1Prime + fRy * fRy * fX1Prime * fX1Prime;
        float64 fCoefficient = fDenominator == 0.0 ? 0.0 : sqrt(fmax(0.0, fNumerator / fDenominator));
        if (bLargeArc == bSweep) { fCoefficient = -fCoefficient; }
        float64 fCenterXPrime = fCoefficient * fRx * fY1Prime / fRy;
        float64 fCenterYPrime = -fCoefficient * fRy * fX1Prime / fRx;
        float64 fCenterX = fCosPhi * fCenterXPrime - fSinPhi * fCenterYPrime + (objVec2Start.x + objVec2End.x) * 0.5;
        float64 fCenterY = fSinPhi * fCenterXPrime + fCosPhi * fCenterYPrime + (objVec2Start.y + objVec2End.y) * 0.5;

        float64 fUx = (fX1Prime - fCenterXPrime) / fRx;
        float64 fUy = (fY1Prime - fCenterYPrime) / fRy;
        float64 fVx = (-fX1Prime - fCenterXPrime) / fRx;
        float64 fVy = (-fY1Prime - fCenterYPrime) / fRy;
        float64 fStartAngle = angleBetween(1.0, 0.0, fUx, fUy);
        float64 fSweepAngle = angleBetween(fUx, fUy, fVx, fVy);
        if (!bSweep && fSweepAngle > 0.0) { fSweepAngle -= 2.0 * std::numbers::pi; }
        if (bSweep && fSweepAngle < 0.0) { fSweepAngle += 2.0 * std::numbers::pi; }

        float64 fArcLength = fabs(fSweepAngle) * fmax(fRx, fRy);
        int64 iAngleSegments = static_cast<int64>(ceil(fabs(fSweepAngle) / (std::numbers::pi / 16.0)));
        int64 iSegments = clamp(max(iAngleSegments, curveSegmentCount(fArcLength)), static_cast<int64>(2), iMaximumCurveSegments);

        ensureContour();
        for (int64 iSegment = 1; iSegment <= iSegments; iSegment++) {
            float64 fAngle = fStartAngle + fSweepAngle * static_cast<float64>(iSegment) / static_cast<float64>(iSegments);
            float64 fCosAngle = cos(fAngle);
            float64 fSinAngle = sin(fAngle);
            appendPoint(vec2(
                fCenterX + fRx * fCosAngle * fCosPhi - fRy * fSinAngle * fSinPhi,
                fCenterY + fRx * fCosAngle * fSinPhi + fRy * fSinAngle * fCosPhi));
        }
        m_objVec2Current = objVec2End;
    }

    void closeContour() {
        if (m_bContourOpen) {
            m_vecContourIsClosed.back() = true;
            m_bContourOpen = false;
        }
        m_objVec2Current = m_objVec2ContourStart;
    }

    bool hasContours() const { return !m_vecContours.empty(); }

    void moveContoursInto(SvgShape& objSvgShape) {
        objSvgShape.vecContours = std::move(m_vecContours);
        objSvgShape.vecContourIsClosed = std::move(m_vecContourIsClosed);
        m_vecContours.clear();
        m_vecContourIsClosed.clear();
        m_bContourOpen = false;
    }

    void appendEllipse(float64 fCenterX, float64 fCenterY, float64 fRadiusX, float64 fRadiusY) {
        if (fRadiusX <= 0.0 || fRadiusY <= 0.0) { return; }
        moveTo(vec2(fCenterX + fRadiusX, fCenterY));
        arcTo(fRadiusX, fRadiusY, 0.0, false, true, vec2(fCenterX - fRadiusX, fCenterY));
        arcTo(fRadiusX, fRadiusY, 0.0, false, true, vec2(fCenterX + fRadiusX, fCenterY));
        closeContour();
    }

    void appendRoundedRect(float64 fX, float64 fY, float64 fWidth, float64 fHeight, float64 fRadiusX, float64 fRadiusY) {
        if (fWidth <= 0.0 || fHeight <= 0.0) { return; }
        float64 fRx = clamp(fRadiusX, 0.0, fWidth * 0.5);
        float64 fRy = clamp(fRadiusY, 0.0, fHeight * 0.5);
        if (fRx <= 0.0 || fRy <= 0.0) {
            moveTo(vec2(fX, fY));
            lineTo(vec2(fX + fWidth, fY));
            lineTo(vec2(fX + fWidth, fY + fHeight));
            lineTo(vec2(fX, fY + fHeight));
            closeContour();
            return;
        }
        moveTo(vec2(fX + fRx, fY));
        lineTo(vec2(fX + fWidth - fRx, fY));
        arcTo(fRx, fRy, 0.0, false, true, vec2(fX + fWidth, fY + fRy));
        lineTo(vec2(fX + fWidth, fY + fHeight - fRy));
        arcTo(fRx, fRy, 0.0, false, true, vec2(fX + fWidth - fRx, fY + fHeight));
        lineTo(vec2(fX + fRx, fY + fHeight));
        arcTo(fRx, fRy, 0.0, false, true, vec2(fX, fY + fHeight - fRy));
        lineTo(vec2(fX, fY + fRy));
        arcTo(fRx, fRy, 0.0, false, true, vec2(fX + fRx, fY));
        closeContour();
    }
};

}
