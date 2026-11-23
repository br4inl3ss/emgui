#pragma once

namespace ui {

class ItemListView {
    static constexpr float64 fScrollStep = 48.0;
    static constexpr float64 fItemTextInset = 6.0;

    float64 m_fScrollOffset = 0.0;
    bool m_bDraggingScrollbar = false;

    static float64 itemHeight(const UiContext& objUiContext) { return objUiContext.metrics().fInteractHeight; }

    float64 maximumScroll(const UiContext& objUiContext, const Rect& objRectView, int64 iItemCount) const {
        return fmax(0.0, contentHeight(objUiContext, iItemCount) - objRectView.fHeight);
    }

    Rect scrollbarThumb(const UiContext& objUiContext, const Rect& objRectView, int64 iItemCount) const {
        float64 fScrollbarWidth = objUiContext.metrics().fScrollbarWidth;
        float64 fContentHeight = contentHeight(objUiContext, iItemCount);
        float64 fThumbHeight = fmax(16.0, objRectView.fHeight * objRectView.fHeight / fContentHeight);
        float64 fScrollRange = maximumScroll(objUiContext, objRectView, iItemCount);
        float64 fThumbTravel = objRectView.fHeight - fThumbHeight;
        float64 fThumbY = objRectView.fY + (fScrollRange <= 0.0 ? 0.0 : fThumbTravel * m_fScrollOffset / fScrollRange);
        return Rect(objRectView.right() - fScrollbarWidth, fThumbY, fScrollbarWidth, fThumbHeight);
    }

public:
    static float64 contentHeight(const UiContext& objUiContext, int64 iItemCount) { return itemHeight(objUiContext) * static_cast<float64>(iItemCount); }

    void scrollToItem(const UiContext& objUiContext, const Rect& objRectView, int64 iItemCount, int64 iIndex) {
        if (iIndex < 0) { return; }
        float64 fItemHeight = itemHeight(objUiContext);
        float64 fItemTop = fItemHeight * static_cast<float64>(iIndex);
        if (fItemTop < m_fScrollOffset) { m_fScrollOffset = fItemTop; }
        if (fItemTop + fItemHeight > m_fScrollOffset + objRectView.fHeight) { m_fScrollOffset = fItemTop + fItemHeight - objRectView.fHeight; }
        m_fScrollOffset = clamp(m_fScrollOffset, 0.0, maximumScroll(objUiContext, objRectView, iItemCount));
    }

    int64 update(UiContext& objUiContext, const Rect& objRectView, int64 iItemCount) {
        InputState& objInputState = objUiContext.input();
        float64 fScrollRange = maximumScroll(objUiContext, objRectView, iItemCount);
        m_fScrollOffset = clamp(m_fScrollOffset, 0.0, fScrollRange);

        if (m_bDraggingScrollbar) {
            Rect objRectThumb = scrollbarThumb(objUiContext, objRectView, iItemCount);
            float64 fThumbTravel = objRectView.fHeight - objRectThumb.fHeight;
            if (fThumbTravel > 0.0) { m_fScrollOffset = clamp(m_fScrollOffset + objInputState.mouseDelta().y * fScrollRange / fThumbTravel, 0.0, fScrollRange); }
            if (!objInputState.isMouseDown()) {
                m_bDraggingScrollbar = false;
                objUiContext.releaseMouse(this);
            }
            return -1;
        }
        if (!objUiContext.isMouseOver(objRectView)) { return -1; }

        if (fScrollRange > 0.0 && objInputState.scrollDelta() != 0.0) {
            m_fScrollOffset = clamp(m_fScrollOffset - objInputState.scrollDelta() * fScrollStep, 0.0, fScrollRange);
            objInputState.consumeScroll();
        }
        if (!objInputState.isMousePressed()) { return -1; }
        objInputState.consumeMousePress();

        Rect objRectThumbHit = scrollbarThumb(objUiContext, objRectView, iItemCount).expanded(3.0);
        if (fScrollRange > 0.0 && objRectThumbHit.contains(objInputState.mousePosition())) {
            m_bDraggingScrollbar = true;
            objUiContext.captureMouse(this);
            return -1;
        }
        int64 iIndex = static_cast<int64>(floor((objInputState.mousePosition().y - objRectView.fY + m_fScrollOffset) / itemHeight(objUiContext)));
        return iIndex >= 0 && iIndex < iItemCount ? iIndex : -1;
    }

    void draw(UiContext& objUiContext, const Element* pElementOwner, const Rect& objRectView, const std::vector<std::string>& vecItems,
              const std::vector<bool>& vecSelected, bool bShowCheckBoxes) {
        Painter& objPainter = objUiContext.painter();
        const ThemeMetrics& objThemeMetrics = objUiContext.metrics();
        int64 iItemCount = vecItems.size();
        float64 fItemHeight = itemHeight(objUiContext);
        bool bScrollable = maximumScroll(objUiContext, objRectView, iItemCount) > 0.0;
        float64 fScrollbarReserve = bScrollable ? objThemeMetrics.fScrollbarWidth + 3.0 : 0.0;
        float64 fRounding = objThemeMetrics.fWidgetRounding;

        objPainter.pushClip(objRectView);
        objUiContext.pushHitClip(objRectView);
        int64 iFirstVisible = max(static_cast<int64>(floor(m_fScrollOffset / fItemHeight)), static_cast<int64>(0));
        int64 iLastVisible = min(static_cast<int64>(ceil((m_fScrollOffset + objRectView.fHeight) / fItemHeight)), iItemCount);
        for (int64 iIndex = iFirstVisible; iIndex < iLastVisible; iIndex++) {
            Rect objRectItem = Rect(objRectView.fX, objRectView.fY + fItemHeight * static_cast<float64>(iIndex) - m_fScrollOffset,
                objRectView.fWidth - fScrollbarReserve, fItemHeight);
            bool bSelected = iIndex < vecSelected.size() && vecSelected[iIndex];
            bool bHovered = !m_bDraggingScrollbar && objUiContext.isMouseOver(objRectItem);
            WidgetVisuals objWidgetVisuals = pElementOwner->widgetVisuals(objUiContext, bHovered ? 1.0 : 0.0, 0.0, 0.0);
            color objColorText = objWidgetVisuals.objColorText;
            if (bSelected && !bShowCheckBoxes) {
                objPainter.fillRect(objRectItem, pElementOwner->colorOf(objUiContext, ColorRole::SelectionFill), fRounding);
                objColorText = pElementOwner->colorOf(objUiContext, ColorRole::SelectionStroke);
            } else if (bHovered) {
                objPainter.fillRect(objRectItem, objWidgetVisuals.objColorFill, fRounding);
                objPainter.strokeRect(objRectItem, objWidgetVisuals.objColorStroke, 1.0, fRounding);
            }

            Rect objRectText = objRectItem.withoutLeft(fItemTextInset).withoutRight(fItemTextInset);
            if (bShowCheckBoxes) {
                float64 fBoxSize = objThemeMetrics.fCheckboxSize;
                Rect objRectCheck = Rect(objRectText.fX, objRectItem.centerY() - fBoxSize * 0.5, fBoxSize, fBoxSize);
                WidgetVisuals objBoxVisuals = pElementOwner->widgetVisuals(objUiContext, 0.0, 0.0, 0.0);
                objPainter.fillRect(objRectCheck, objBoxVisuals.objColorFill, fRounding);
                if (bSelected) { objPainter.drawCheckMark(objRectCheck, objColorText, 1.0); }
                objRectText = objRectText.withoutLeft(fBoxSize + objThemeMetrics.fIconSpacing);
            }
            objPainter.drawTextInRect(vecItems[iIndex], objRectText, objColorText, FontRole::Body, HorizontalAlignment::Left);
        }
        objUiContext.popHitClip();
        objPainter.popClip();

        if (bScrollable) {
            Rect objRectThumb = scrollbarThumb(objUiContext, objRectView, iItemCount);
            bool bThumbHovered = m_bDraggingScrollbar || objUiContext.isMouseOver(objRectThumb.expanded(3.0));
            WidgetVisuals objThumbVisuals = pElementOwner->widgetVisuals(objUiContext, bThumbHovered ? 1.0 : 0.0, m_bDraggingScrollbar ? 1.0 : 0.0, 0.0);
            objPainter.fillRect(objRectThumb, objThumbVisuals.objColorFill, objRectThumb.fWidth * 0.5);
        }
    }
};

}
