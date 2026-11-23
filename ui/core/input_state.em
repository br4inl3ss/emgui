#pragma once

namespace ui {

class InputState {
    static constexpr int64 iKeyCount = 256;
    static constexpr int64 iRepeatDelayMilliseconds = 420;
    static constexpr int64 iRepeatIntervalMilliseconds = 38;

    vec2 m_objVec2MousePosition = vec2(-1.0, -1.0);
    vec2 m_objVec2PreviousMousePosition = vec2(-1.0, -1.0);
    std::vector<bool> m_vecKeysDown;
    std::vector<bool> m_vecKeysDownPrevious;
    std::vector<bool> m_vecKeysRepeatFired;
    std::vector<int64> m_vecNextRepeatMilliseconds;
    float64 m_fScrollDelta = 0.0;
    std::string m_strTextInput;
    bool m_bMousePressConsumed = false;
    bool m_bScrollConsumed = false;
    int64 m_iTimeMilliseconds = 0;
    float64 m_fDeltaSeconds = 0.0;

    static bool isPrintableByte(char chValue) {
        int32 iCode = static_cast<int32>(static_cast<uint8>(chValue));
        return iCode >= 32 && iCode != 127;
    }

    static float64 normalizeScrollDelta(float64 fRawDelta) {
        if (!is_finite(fRawDelta)) { return 0.0; }
        if (fabs(fRawDelta) >= 60.0) { return fRawDelta / 120.0; }
        return fRawDelta;
    }

public:
    InputState() {
        m_vecKeysDown.resize(iKeyCount, false);
        m_vecKeysDownPrevious.resize(iKeyCount, false);
        m_vecKeysRepeatFired.resize(iKeyCount, false);
        m_vecNextRepeatMilliseconds.resize(iKeyCount, 0);
    }

    void capture(PlatformBackend* pPlatformBackend, float64 fScale) {
        int64 iNow = pPlatformBackend->timeMilliseconds();
        m_fDeltaSeconds = m_iTimeMilliseconds == 0 ? 0.0 : clamp(static_cast<float64>(iNow - m_iTimeMilliseconds) / 1000.0, 0.0, 0.25);
        m_iTimeMilliseconds = iNow;

        m_objVec2PreviousMousePosition = m_objVec2MousePosition;
        vec2 objVec2MousePixels = pPlatformBackend->mousePosition();
        m_objVec2MousePosition = vec2(objVec2MousePixels.x / fScale, objVec2MousePixels.y / fScale);

        for (int64 iKey = 0; iKey < iKeyCount; iKey++) {
            m_vecKeysDownPrevious[iKey] = m_vecKeysDown[iKey];
            m_vecKeysDown[iKey] = false;
        }
        for (int32 iKeyDown : pPlatformBackend->keysDown()) {
            if (iKeyDown > 0 && iKeyDown < iKeyCount) { m_vecKeysDown[iKeyDown] = true; }
        }
        for (int64 iKey = 0; iKey < iKeyCount; iKey++) {
            m_vecKeysRepeatFired[iKey] = false;
            if (!m_vecKeysDown[iKey]) { continue; }
            if (!m_vecKeysDownPrevious[iKey]) {
                m_vecKeysRepeatFired[iKey] = true;
                m_vecNextRepeatMilliseconds[iKey] = iNow + iRepeatDelayMilliseconds;
            } else if (iNow >= m_vecNextRepeatMilliseconds[iKey]) {
                m_vecKeysRepeatFired[iKey] = true;
                m_vecNextRepeatMilliseconds[iKey] = iNow + iRepeatIntervalMilliseconds;
            }
        }

        m_fScrollDelta = normalizeScrollDelta(pPlatformBackend->scrollDelta());
        m_bScrollConsumed = false;
        m_bMousePressConsumed = false;

        m_strTextInput = "";
        std::string strRawText = pPlatformBackend->takeTextInput();
        for (int64 iIndex = 0; iIndex < strRawText.size(); iIndex++) {
            if (isPrintableByte(strRawText[iIndex])) { m_strTextInput.push_back(strRawText[iIndex]); }
        }
    }

    vec2 mousePosition() const { return m_objVec2MousePosition; }
    vec2 mouseDelta() const {
        return vec2(m_objVec2MousePosition.x - m_objVec2PreviousMousePosition.x, m_objVec2MousePosition.y - m_objVec2PreviousMousePosition.y);
    }

    bool isKeyDown(int64 iVirtualKey) const {
        return iVirtualKey > 0 && iVirtualKey < iKeyCount && m_vecKeysDown[iVirtualKey];
    }
    bool isKeyPressed(int64 iVirtualKey) const {
        return iVirtualKey > 0 && iVirtualKey < iKeyCount && m_vecKeysDown[iVirtualKey] && !m_vecKeysDownPrevious[iVirtualKey];
    }
    bool isKeyReleased(int64 iVirtualKey) const {
        return iVirtualKey > 0 && iVirtualKey < iKeyCount && !m_vecKeysDown[iVirtualKey] && m_vecKeysDownPrevious[iVirtualKey];
    }
    bool isKeyPressedRepeating(int64 iVirtualKey) const {
        return iVirtualKey > 0 && iVirtualKey < iKeyCount && m_vecKeysRepeatFired[iVirtualKey];
    }
    bool isControlDown() const {
        return isKeyDown(vk::ctrl) || isKeyDown(vk::lctrl) || isKeyDown(vk::rctrl);
    }
    bool isShiftDown() const {
        return isKeyDown(vk::shift) || isKeyDown(vk::lshift) || isKeyDown(vk::rshift);
    }

    int64 firstPressedKey() const {
        for (int64 iKey = 1; iKey < iKeyCount; iKey++) {
            if (isKeyPressed(iKey)) { return iKey; }
        }
        return 0;
    }

    bool isMouseDown() const { return isKeyDown(vk::lbutton); }
    bool isMousePressed() const { return !m_bMousePressConsumed && isKeyPressed(vk::lbutton); }
    bool isMouseReleased() const { return isKeyReleased(vk::lbutton); }
    bool isSecondaryMousePressed() const { return !m_bMousePressConsumed && isKeyPressed(vk::rbutton); }
    void consumeMousePress() { m_bMousePressConsumed = true; }

    float64 scrollDelta() const { return m_bScrollConsumed ? 0.0 : m_fScrollDelta; }
    void consumeScroll() { m_bScrollConsumed = true; }

    const std::string& textInput() const { return m_strTextInput; }
    int64 timeMilliseconds() const { return m_iTimeMilliseconds; }
    float64 deltaSeconds() const { return m_fDeltaSeconds; }
};

}
