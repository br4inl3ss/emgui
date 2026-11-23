#pragma once

namespace ui {

enum class SvgColorMode : int32 { Tinted, Original };

class SvgRasterizer {
    static constexpr int64 iVerticalSamplesPerPixel = 5;

    int64 m_iPixelSize;
    float64 m_fScale;
    float64 m_fOffsetX;
    float64 m_fOffsetY;
    std::vector<float64> m_vecCoverage;
    std::vector<float64> m_vecRed;
    std::vector<float64> m_vecGreen;
    std::vector<float64> m_vecBlue;
    std::vector<float64> m_vecAlpha;

    vec2 toPixels(vec2 objVec2ViewBoxPoint) const {
        return vec2(objVec2ViewBoxPoint.x * m_fScale + m_fOffsetX, objVec2ViewBoxPoint.y * m_fScale + m_fOffsetY);
    }

    void clearCoverage() {
        for (int64 iIndex = 0; iIndex < m_vecCoverage.size(); iIndex++) { m_vecCoverage[iIndex] = 0.0; }
    }

    void addSpan(int64 iRow, float64 fSpanStart, float64 fSpanEnd, float64 fWeight) {
        float64 fWidth = static_cast<float64>(m_iPixelSize);
        float64 fStart = clamp(fSpanStart, 0.0, fWidth);
        float64 fEnd = clamp(fSpanEnd, 0.0, fWidth);
        if (fEnd <= fStart) { return; }
        int64 iRowOffset = iRow * m_iPixelSize;
        int64 iFirstColumn = static_cast<int64>(floor(fStart));
        int64 iLastColumn = static_cast<int64>(floor(fEnd));
        if (iFirstColumn == iLastColumn) {
            m_vecCoverage[iRowOffset + iFirstColumn] += (fEnd - fStart) * fWeight;
            return;
        }
        m_vecCoverage[iRowOffset + iFirstColumn] += (static_cast<float64>(iFirstColumn + 1) - fStart) * fWeight;
        for (int64 iColumn = iFirstColumn + 1; iColumn < iLastColumn; iColumn++) {
            m_vecCoverage[iRowOffset + iColumn] += fWeight;
        }
        if (iLastColumn < m_iPixelSize) {
            m_vecCoverage[iRowOffset + iLastColumn] += (fEnd - static_cast<float64>(iLastColumn)) * fWeight;
        }
    }

    void accumulateFill(const SvgShape& objSvgShape) {
        std::vector<float64> vecEdgeStartX;
        std::vector<float64> vecEdgeStartY;
        std::vector<float64> vecEdgeEndX;
        std::vector<float64> vecEdgeEndY;
        float64 fTop = 1e300;
        float64 fBottom = -1e300;
        for (const std::vector<vec2>& vecContour : objSvgShape.vecContours) {
            int64 iPointCount = vecContour.size();
            if (iPointCount < 3) { continue; }
            for (int64 iIndex = 0; iIndex < iPointCount; iIndex++) {
                vec2 objVec2Start = toPixels(vecContour[iIndex]);
                vec2 objVec2End = toPixels(vecContour[(iIndex + 1) % iPointCount]);
                if (objVec2Start.y == objVec2End.y) { continue; }
                vecEdgeStartX.push_back(objVec2Start.x);
                vecEdgeStartY.push_back(objVec2Start.y);
                vecEdgeEndX.push_back(objVec2End.x);
                vecEdgeEndY.push_back(objVec2End.y);
                fTop = fmin(fTop, fmin(objVec2Start.y, objVec2End.y));
                fBottom = fmax(fBottom, fmax(objVec2Start.y, objVec2End.y));
            }
        }
        if (vecEdgeStartX.empty()) { return; }

        int64 iFirstRow = clamp(static_cast<int64>(floor(fTop)), static_cast<int64>(0), m_iPixelSize - 1);
        int64 iLastRow = clamp(static_cast<int64>(ceil(fBottom)), static_cast<int64>(0), m_iPixelSize - 1);
        float64 fSampleWeight = 1.0 / static_cast<float64>(iVerticalSamplesPerPixel);
        std::vector<float64> vecCrossingX;
        std::vector<int64> vecCrossingDirection;

        for (int64 iRow = iFirstRow; iRow <= iLastRow; iRow++) {
            for (int64 iSample = 0; iSample < iVerticalSamplesPerPixel; iSample++) {
                float64 fSampleY = static_cast<float64>(iRow) + (static_cast<float64>(iSample) + 0.5) * fSampleWeight;
                vecCrossingX.clear();
                vecCrossingDirection.clear();
                for (int64 iEdge = 0; iEdge < vecEdgeStartX.size(); iEdge++) {
                    float64 fStartY = vecEdgeStartY[iEdge];
                    float64 fEndY = vecEdgeEndY[iEdge];
                    bool bCrosses = (fSampleY >= fStartY && fSampleY < fEndY) || (fSampleY >= fEndY && fSampleY < fStartY);
                    if (!bCrosses) { continue; }
                    float64 fRatio = (fSampleY - fStartY) / (fEndY - fStartY);
                    float64 fCrossingX = vecEdgeStartX[iEdge] + (vecEdgeEndX[iEdge] - vecEdgeStartX[iEdge]) * fRatio;
                    int64 iDirection = fEndY > fStartY ? 1 : -1;
                    int64 iInsertAt = vecCrossingX.size();
                    vecCrossingX.push_back(fCrossingX);
                    vecCrossingDirection.push_back(iDirection);
                    while (iInsertAt > 0 && vecCrossingX[iInsertAt - 1] > fCrossingX) {
                        vecCrossingX[iInsertAt] = vecCrossingX[iInsertAt - 1];
                        vecCrossingDirection[iInsertAt] = vecCrossingDirection[iInsertAt - 1];
                        iInsertAt--;
                    }
                    vecCrossingX[iInsertAt] = fCrossingX;
                    vecCrossingDirection[iInsertAt] = iDirection;
                }

                int64 iWinding = 0;
                for (int64 iCrossing = 0; iCrossing + 1 < vecCrossingX.size(); iCrossing++) {
                    iWinding += vecCrossingDirection[iCrossing];
                    bool bInside = objSvgShape.bFillUsesEvenOddRule ? (abs(iWinding) % 2) == 1 : iWinding != 0;
                    if (bInside) { addSpan(iRow, vecCrossingX[iCrossing], vecCrossingX[iCrossing + 1], fSampleWeight); }
                }
            }
        }
    }

    void accumulateSegmentStroke(vec2 objVec2Start, vec2 objVec2End, float64 fHalfWidth) {
        float64 fReach = fHalfWidth + 1.0;
        int64 iFirstColumn = clamp(static_cast<int64>(floor(fmin(objVec2Start.x, objVec2End.x) - fReach)), static_cast<int64>(0), m_iPixelSize - 1);
        int64 iLastColumn = clamp(static_cast<int64>(ceil(fmax(objVec2Start.x, objVec2End.x) + fReach)), static_cast<int64>(0), m_iPixelSize - 1);
        int64 iFirstRow = clamp(static_cast<int64>(floor(fmin(objVec2Start.y, objVec2End.y) - fReach)), static_cast<int64>(0), m_iPixelSize - 1);
        int64 iLastRow = clamp(static_cast<int64>(ceil(fmax(objVec2Start.y, objVec2End.y) + fReach)), static_cast<int64>(0), m_iPixelSize - 1);
        float64 fSegmentX = objVec2End.x - objVec2Start.x;
        float64 fSegmentY = objVec2End.y - objVec2Start.y;
        float64 fSegmentLengthSquared = fSegmentX * fSegmentX + fSegmentY * fSegmentY;

        for (int64 iRow = iFirstRow; iRow <= iLastRow; iRow++) {
            for (int64 iColumn = iFirstColumn; iColumn <= iLastColumn; iColumn++) {
                float64 fPixelX = static_cast<float64>(iColumn) + 0.5 - objVec2Start.x;
                float64 fPixelY = static_cast<float64>(iRow) + 0.5 - objVec2Start.y;
                float64 fProjection = fSegmentLengthSquared > 0.0 ? clamp((fPixelX * fSegmentX + fPixelY * fSegmentY) / fSegmentLengthSquared, 0.0, 1.0) : 0.0;
                float64 fDistance = hypot(fPixelX - fSegmentX * fProjection, fPixelY - fSegmentY * fProjection);
                float64 fPixelCoverage = clamp(fHalfWidth + 0.5 - fDistance, 0.0, 1.0);
                int64 iPixelIndex = iRow * m_iPixelSize + iColumn;
                if (fPixelCoverage > m_vecCoverage[iPixelIndex]) { m_vecCoverage[iPixelIndex] = fPixelCoverage; }
            }
        }
    }

    void accumulateStroke(const SvgShape& objSvgShape) {
        float64 fHalfWidth = fmax(0.5, objSvgShape.fStrokeWidth * m_fScale * 0.5);
        for (int64 iContour = 0; iContour < objSvgShape.vecContours.size(); iContour++) {
            const std::vector<vec2>& vecContour = objSvgShape.vecContours[iContour];
            int64 iPointCount = vecContour.size();
            if (iPointCount == 0) { continue; }
            if (iPointCount == 1) {
                accumulateSegmentStroke(toPixels(vecContour[0]), toPixels(vecContour[0]), fHalfWidth);
                continue;
            }
            for (int64 iIndex = 0; iIndex + 1 < iPointCount; iIndex++) {
                accumulateSegmentStroke(toPixels(vecContour[iIndex]), toPixels(vecContour[iIndex + 1]), fHalfWidth);
            }
            if (objSvgShape.vecContourIsClosed[iContour]) {
                accumulateSegmentStroke(toPixels(vecContour[iPointCount - 1]), toPixels(vecContour[0]), fHalfWidth);
            }
        }
    }

    void compositeCoverage(color objColorPaint, SvgColorMode eColorMode) {
        float64 fPaintRed = eColorMode == SvgColorMode::Tinted ? 1.0 : static_cast<float64>(objColorPaint.r) / 255.0;
        float64 fPaintGreen = eColorMode == SvgColorMode::Tinted ? 1.0 : static_cast<float64>(objColorPaint.g) / 255.0;
        float64 fPaintBlue = eColorMode == SvgColorMode::Tinted ? 1.0 : static_cast<float64>(objColorPaint.b) / 255.0;
        float64 fPaintAlpha = static_cast<float64>(objColorPaint.a) / 255.0;
        for (int64 iPixel = 0; iPixel < m_vecCoverage.size(); iPixel++) {
            float64 fSourceAlpha = fmin(1.0, m_vecCoverage[iPixel]) * fPaintAlpha;
            if (fSourceAlpha <= 0.0) { continue; }
            float64 fDestinationWeight = m_vecAlpha[iPixel] * (1.0 - fSourceAlpha);
            float64 fResultAlpha = fSourceAlpha + fDestinationWeight;
            m_vecRed[iPixel] = (fPaintRed * fSourceAlpha + m_vecRed[iPixel] * fDestinationWeight) / fResultAlpha;
            m_vecGreen[iPixel] = (fPaintGreen * fSourceAlpha + m_vecGreen[iPixel] * fDestinationWeight) / fResultAlpha;
            m_vecBlue[iPixel] = (fPaintBlue * fSourceAlpha + m_vecBlue[iPixel] * fDestinationWeight) / fResultAlpha;
            m_vecAlpha[iPixel] = fResultAlpha;
        }
    }

    SvgRasterizer(const Rect& objRectViewBox, int64 iPixelSize) : m_iPixelSize(iPixelSize) {
        float64 fSize = static_cast<float64>(iPixelSize);
        m_fScale = fSize / fmax(objRectViewBox.fWidth, objRectViewBox.fHeight);
        m_fOffsetX = (fSize - objRectViewBox.fWidth * m_fScale) * 0.5 - objRectViewBox.fX * m_fScale;
        m_fOffsetY = (fSize - objRectViewBox.fHeight * m_fScale) * 0.5 - objRectViewBox.fY * m_fScale;
        int64 iPixelCount = iPixelSize * iPixelSize;
        m_vecCoverage.resize(iPixelCount, 0.0);
        m_vecRed.resize(iPixelCount, 1.0);
        m_vecGreen.resize(iPixelCount, 1.0);
        m_vecBlue.resize(iPixelCount, 1.0);
        m_vecAlpha.resize(iPixelCount, 0.0);
    }

    std::vector<uint8> packRgba() const {
        std::vector<uint8> vecRgbaPixels;
        vecRgbaPixels.resize(m_vecAlpha.size() * 4);
        for (int64 iPixel = 0; iPixel < m_vecAlpha.size(); iPixel++) {
            vecRgbaPixels[iPixel * 4] = static_cast<uint8>(round(clamp(m_vecRed[iPixel], 0.0, 1.0) * 255.0));
            vecRgbaPixels[iPixel * 4 + 1] = static_cast<uint8>(round(clamp(m_vecGreen[iPixel], 0.0, 1.0) * 255.0));
            vecRgbaPixels[iPixel * 4 + 2] = static_cast<uint8>(round(clamp(m_vecBlue[iPixel], 0.0, 1.0) * 255.0));
            vecRgbaPixels[iPixel * 4 + 3] = static_cast<uint8>(round(clamp(m_vecAlpha[iPixel], 0.0, 1.0) * 255.0));
        }
        return vecRgbaPixels;
    }

public:
    static std::vector<uint8> rasterize(const SvgDocument& objSvgDocument, int64 iPixelSize, SvgColorMode eColorMode) {
        if (!objSvgDocument.isValid() || iPixelSize <= 0) { return std::vector<uint8>(); }
        SvgRasterizer objSvgRasterizer(objSvgDocument.objRectViewBox, iPixelSize);
        for (const SvgShape& objSvgShape : objSvgDocument.vecShapes) {
            if (objSvgShape.bFillEnabled) {
                objSvgRasterizer.clearCoverage();
                objSvgRasterizer.accumulateFill(objSvgShape);
                objSvgRasterizer.compositeCoverage(objSvgShape.objColorFill, eColorMode);
            }
            if (objSvgShape.bStrokeEnabled) {
                objSvgRasterizer.clearCoverage();
                objSvgRasterizer.accumulateStroke(objSvgShape);
                objSvgRasterizer.compositeCoverage(objSvgShape.objColorStroke, eColorMode);
            }
        }
        return objSvgRasterizer.packRgba();
    }
};

}
