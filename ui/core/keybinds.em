#pragma once

namespace ui {

enum class KeybindMode : int32 { AlwaysOn, OnToggle, OffHotkey };

class Keybind {
    std::string m_strName;
    int64 m_iVirtualKey;
    KeybindMode m_eMode;
    bool m_bToggledOn = false;
    bool m_bActive = true;
    KeybindStateCallback m_fnOnStateChange = null;

    bool evaluateActive(const InputState& objInputState, bool bAcceptKeys) {
        switch (m_eMode) {
            case KeybindMode::AlwaysOn:
                return true;
            case KeybindMode::OnToggle:
                if (bAcceptKeys && objInputState.isKeyPressed(m_iVirtualKey)) { m_bToggledOn = !m_bToggledOn; }
                return m_bToggledOn;
            case KeybindMode::OffHotkey:
                return !(bAcceptKeys && objInputState.isKeyDown(m_iVirtualKey));
        }
        return true;
    }

public:
    Keybind(const std::string& strName, int64 iVirtualKey, KeybindMode eMode)
        : m_strName(strName), m_iVirtualKey(iVirtualKey), m_eMode(eMode) {
        m_bActive = eMode != KeybindMode::OnToggle;
    }

    Keybind(const Keybind& objKeybindOther) = delete;
    Keybind& operator=(const Keybind& objKeybindOther) = delete;

    const std::string& name() const { return m_strName; }
    int64 key() const { return m_iVirtualKey; }
    KeybindMode mode() const { return m_eMode; }
    bool isActive() const { return m_bActive; }

    Keybind* setKey(int64 iVirtualKey) {
        m_iVirtualKey = iVirtualKey;
        return this;
    }

    Keybind* setMode(KeybindMode eMode) {
        m_eMode = eMode;
        m_bToggledOn = false;
        return this;
    }

    Keybind* onStateChange(KeybindStateCallback fnOnStateChange) {
        m_fnOnStateChange = fnOnStateChange;
        return this;
    }

    void update(const InputState& objInputState, bool bAcceptKeys) {
        bool bActiveNow = evaluateActive(objInputState, bAcceptKeys);
        if (bActiveNow == m_bActive) { return; }
        m_bActive = bActiveNow;
        if (m_fnOnStateChange != null) { m_fnOnStateChange(m_bActive); }
    }

    static std::string modeName(KeybindMode eMode) {
        switch (eMode) {
            case KeybindMode::AlwaysOn: return "Always On";
            case KeybindMode::OnToggle: return "On Toggle";
            case KeybindMode::OffHotkey: return "Off Hotkey";
        }
        return "";
    }
};

class KeybindRegistry {
    std::vector<std::unique_ptr<Keybind>> m_vecKeybinds;

public:
    Keybind* create(const std::string& strName, int64 iVirtualKey, KeybindMode eMode) {
        m_vecKeybinds.push_back(std::make_unique<Keybind>(strName, iVirtualKey, eMode));
        return m_vecKeybinds.back().get();
    }

    void update(const InputState& objInputState, bool bAcceptKeys) {
        for (std::unique_ptr<Keybind>& upKeybind : m_vecKeybinds) { upKeybind->update(objInputState, bAcceptKeys); }
    }

    int64 count() const { return m_vecKeybinds.size(); }
    Keybind* at(int64 iIndex) const { return m_vecKeybinds[iIndex].get(); }
};

}
