#pragma once

namespace ui {

class TextEditBuffer {
    static constexpr int64 iCaretBlinkPeriodMilliseconds = 1060;

    std::string m_strText;
    int64 m_iCaretIndex = 0;
    int64 m_iMaximumLength = 256;
    float64 m_fScrollX = 0.0;
    int64 m_iLastCaretMoveMilliseconds = 0;
    bool m_bEverythingSelected = false;

    static bool isContinuationByte(char chValue) { return (static_cast<uint8>(chValue) & 0xC0) == 0x80; }

    static std::string singleLine(const std::string& strText) {
        return std::replace_all(std::replace_all(std::replace_all(strText, "\r\n", " "), "\n", " "), "\r", " ");
    }

    int64 previousBoundary(int64 iIndex) const {
        int64 iBoundary = iIndex - 1;
        while (iBoundary > 0 && isContinuationByte(m_strText[iBoundary])) { iBoundary--; }
        return max(iBoundary, static_cast<int64>(0));
    }

    int64 nextBoundary(int64 iIndex) const {
        int64 iBoundary = iIndex + 1;
        while (iBoundary < m_strText.size() && isContinuationByte(m_strText[iBoundary])) { iBoundary++; }
        return min(iBoundary, m_strText.size());
    }

    float64 widthOfPrefix(UiContext& objUiContext, int64 iLength) const {
        return objUiContext.painter().measureText(m_strText.substr(0, iLength), FontRole::Body).x;
    }

    bool removeSelection() {
        if (!m_bEverythingSelected) { return false; }
        m_bEverythingSelected = false;
        if (m_strText.empty()) { return false; }
        m_strText.clear();
        m_iCaretIndex = 0;
        return true;
    }

    bool insertAtCaret(const std::string& strInsertion) {
        if (strInsertion.empty()) { return false; }
        bool bRemovedSelection = removeSelection();
        int64 iRoom = m_iMaximumLength - m_strText.size();
        int64 iInsertLength = min(strInsertion.size(), max(iRoom, static_cast<int64>(0)));
        while (iInsertLength > 0 && iInsertLength < strInsertion.size() && isContinuationByte(strInsertion[iInsertLength])) { iInsertLength--; }
        if (iInsertLength == 0) { return bRemovedSelection; }
        m_strText.insert(m_iCaretIndex, strInsertion.substr(0, iInsertLength));
        m_iCaretIndex += iInsertLength;
        return true;
    }

public:
    const std::string& text() const { return m_strText; }
    int64 maximumLength() const { return m_iMaximumLength; }
    bool isEverythingSelected() const { return m_bEverythingSelected; }

    void setMaximumLength(int64 iMaximumLength) { m_iMaximumLength = max(iMaximumLength, static_cast<int64>(1)); }

    void setText(const std::string& strText) {
        std::string strSingleLine = singleLine(strText);
        m_strText = strSingleLine.substr(0, min(strSingleLine.size(), m_iMaximumLength));
        m_iCaretIndex = m_strText.size();
        m_bEverythingSelected = false;
        m_fScrollX = 0.0;
    }

    void selectAll(UiContext& objUiContext) {
        m_bEverythingSelected = true;
        m_iCaretIndex = m_strText.size();
        m_iLastCaretMoveMilliseconds = objUiContext.input().timeMilliseconds();
    }

    void placeCaret(UiContext& objUiContext, float64 fTextX) {
        m_bEverythingSelected = false;
        int64 iBestIndex = 0;
        float64 fBestDistance = fabs(fTextX + m_fScrollX);
        int64 iIndex = 0;
        while (iIndex < m_strText.size()) {
            iIndex = nextBoundary(iIndex);
            float64 fDistance = fabs(widthOfPrefix(objUiContext, iIndex) - (fTextX + m_fScrollX));
            if (fDistance < fBestDistance) {
                fBestDistance = fDistance;
                iBestIndex = iIndex;
            }
        }
        m_iCaretIndex = iBestIndex;
        m_iLastCaretMoveMilliseconds = objUiContext.input().timeMilliseconds();
    }

    bool applyEditingKeys(UiContext& objUiContext) {
        InputState& objInputState = objUiContext.input();
        int64 iCaretBefore = m_iCaretIndex;
        bool bChanged = insertAtCaret(objInputState.textInput());
        if (objInputState.isControlDown() && objInputState.isKeyPressed(vk::v)) {
            bChanged = insertAtCaret(singleLine(objUiContext.platform().clipboardText())) || bChanged;
        }
        if (objInputState.isControlDown() && objInputState.isKeyPressed(vk::c)) { objUiContext.platform().setClipboardText(m_strText); }
        if (objInputState.isControlDown() && objInputState.isKeyPressed(vk::a)) { selectAll(objUiContext); }
        if (objInputState.isKeyPressedRepeating(vk::backspace)) {
            if (removeSelection()) {
                bChanged = true;
            } else if (m_iCaretIndex > 0) {
                int64 iErasedFrom = previousBoundary(m_iCaretIndex);
                m_strText.erase(iErasedFrom, m_iCaretIndex - iErasedFrom);
                m_iCaretIndex = iErasedFrom;
                bChanged = true;
            }
        }
        if (objInputState.isKeyPressedRepeating(vk::delete_)) {
            if (removeSelection()) {
                bChanged = true;
            } else if (m_iCaretIndex < m_strText.size()) {
                m_strText.erase(m_iCaretIndex, nextBoundary(m_iCaretIndex) - m_iCaretIndex);
                bChanged = true;
            }
        }
        bool bCaretKey = objInputState.isKeyPressedRepeating(vk::left) || objInputState.isKeyPressedRepeating(vk::right)
            || objInputState.isKeyPressed(vk::home) || objInputState.isKeyPressed(vk::end);
        if (bCaretKey) { m_bEverythingSelected = false; }
        if (objInputState.isKeyPressedRepeating(vk::left) && m_iCaretIndex > 0) { m_iCaretIndex = previousBoundary(m_iCaretIndex); }
        if (objInputState.isKeyPressedRepeating(vk::right) && m_iCaretIndex < m_strText.size()) { m_iCaretIndex = nextBoundary(m_iCaretIndex); }
        if (objInputState.isKeyPressed(vk::home)) { m_iCaretIndex = 0; }
        if (objInputState.isKeyPressed(vk::end)) { m_iCaretIndex = m_strText.size(); }
        if (bChanged || bCaretKey || iCaretBefore != m_iCaretIndex) { m_iLastCaretMoveMilliseconds = objInputState.timeMilliseconds(); }
        return bChanged;
    }

    void keepCaretVisible(UiContext& objUiContext, float64 fViewportWidth) {
        float64 fCaretX = widthOfPrefix(objUiContext, m_iCaretIndex);
        float64 fTextWidth = widthOfPrefix(objUiContext, m_strText.size());
        if (fCaretX - m_fScrollX > fViewportWidth) { m_fScrollX = fCaretX - fViewportWidth; }
        if (fCaretX - m_fScrollX < 0.0) { m_fScrollX = fCaretX; }
        m_fScrollX = clamp(m_fScrollX, 0.0, fmax(0.0, fTextWidth - fViewportWidth + 2.0));
    }

    void resetScroll() {
        m_fScrollX = 0.0;
        m_bEverythingSelected = false;
    }

    void draw(UiContext& objUiContext, const Rect& objRectViewport, color objColorText, color objColorCaret, color objColorSelection, bool bShowCaret) {
        Painter& objPainter = objUiContext.painter();
        float64 fLineHeight = objPainter.lineHeight(FontRole::Body);
        float64 fTextX = objRectViewport.fX - m_fScrollX;
        float64 fTextY = objRectViewport.centerY() - fLineHeight * 0.5;
        objPainter.pushClip(objRectViewport.expanded(1.0));
        if (m_bEverythingSelected && !m_strText.empty()) {
            objPainter.fillRect(Rect(fTextX, fTextY, widthOfPrefix(objUiContext, m_strText.size()), fLineHeight), objColorSelection, 0.0);
        }
        objPainter.drawText(m_strText, vec2(fTextX, fTextY), objColorText, FontRole::Body);
        int64 iBlinkPhase = (objUiContext.input().timeMilliseconds() - m_iLastCaretMoveMilliseconds) % iCaretBlinkPeriodMilliseconds;
        if (bShowCaret && iBlinkPhase < iCaretBlinkPeriodMilliseconds / 2) {
            float64 fCaretX = fTextX + widthOfPrefix(objUiContext, m_iCaretIndex);
            objPainter.fillRect(Rect(fCaretX, fTextY + 1.0, 2.0, fLineHeight - 2.0), objColorCaret, 0.0);
        }
        objPainter.popClip();
    }
};

}
