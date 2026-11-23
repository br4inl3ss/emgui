#pragma once

namespace ui {

enum class ValueKind : int32 { None, Boolean, Integer, Float, Text, Color, Selection, MultiSelection };

struct ComponentValue {
    ValueKind eKind = ValueKind::None;
    bool bBoolean = false;
    int64 iInteger = 0;
    float64 fFloat = 0.0;
    std::string strText;
    color objColorValue;
    std::vector<std::string> vecItems;

    static ComponentValue ofBoolean(bool bValue) {
        ComponentValue objValue;
        objValue.eKind = ValueKind::Boolean;
        objValue.bBoolean = bValue;
        return objValue;
    }

    static ComponentValue ofInteger(int64 iValue) {
        ComponentValue objValue;
        objValue.eKind = ValueKind::Integer;
        objValue.iInteger = iValue;
        return objValue;
    }

    static ComponentValue ofFloat(float64 fValue) {
        ComponentValue objValue;
        objValue.eKind = ValueKind::Float;
        objValue.fFloat = fValue;
        return objValue;
    }

    static ComponentValue ofText(const std::string& strValue) {
        ComponentValue objValue;
        objValue.eKind = ValueKind::Text;
        objValue.strText = strValue;
        return objValue;
    }

    static ComponentValue ofColor(color objColor) {
        ComponentValue objValue;
        objValue.eKind = ValueKind::Color;
        objValue.objColorValue = objColor;
        return objValue;
    }

    static ComponentValue ofSelection(int64 iIndex, const std::string& strItem) {
        ComponentValue objValue;
        objValue.eKind = ValueKind::Selection;
        objValue.iInteger = iIndex;
        objValue.strText = strItem;
        return objValue;
    }

    static ComponentValue ofMultiSelection(const std::vector<std::string>& vecSelectedItems) {
        ComponentValue objValue;
        objValue.eKind = ValueKind::MultiSelection;
        objValue.vecItems = vecSelectedItems;
        return objValue;
    }

    bool isEmpty() const { return eKind == ValueKind::None; }

    std::string kindName() const {
        switch (eKind) {
            case ValueKind::None: return "nothing";
            case ValueKind::Boolean: return "an on/off value";
            case ValueKind::Integer: return "an integer";
            case ValueKind::Float: return "a decimal number";
            case ValueKind::Text: return "text";
            case ValueKind::Color: return "a color";
            case ValueKind::Selection: return "a selection";
            case ValueKind::MultiSelection: return "a multi-selection";
        }
        return "an unknown value";
    }

    std::string displayText() const {
        switch (eKind) {
            case ValueKind::None: return "";
            case ValueKind::Boolean: return bBoolean ? "true" : "false";
            case ValueKind::Integer: return std::to_string(iInteger);
            case ValueKind::Float: {
                float64 fDisplayed = fFloat;
                return std::format("{}", fDisplayed);
            }
            case ValueKind::Text: return strText;
            case ValueKind::Color: return colorToHex(objColorValue);
            case ValueKind::Selection: return strText;
            case ValueKind::MultiSelection: return std::join(vecItems, ", ");
        }
        return "";
    }

    static std::string colorToHex(color objColor) {
        return std::format("#{:02X}{:02X}{:02X}{:02X}", static_cast<int64>(objColor.r), static_cast<int64>(objColor.g),
            static_cast<int64>(objColor.b), static_cast<int64>(objColor.a));
    }
};

namespace values {

bool tryParseNumber(const std::string& strText, float64& fNumber) {
    std::string strTrimmed = std::trim(strText);
    if (strTrimmed.empty()) { return false; }
    try {
        uint64 uConsumed = 0;
        float64 fParsed = std::stod(strTrimmed, &uConsumed);
        if (static_cast<int64>(uConsumed) != strTrimmed.size() || !is_finite(fParsed)) { return false; }
        fNumber = fParsed;
        return true;
    } catch (...) {
        return false;
    }
}

bool tryParseHexColor(const std::string& strText, color& objColor) {
    std::string strHex = std::trim(strText);
    if (strHex.starts_with("#")) { strHex = strHex.substr(1); }
    if (strHex.size() != 6 && strHex.size() != 8) { return false; }
    std::vector<int64> vecChannels;
    for (int64 iIndex = 0; iIndex < strHex.size(); iIndex += 2) {
        try {
            uint64 uConsumed = 0;
            int64 iChannel = std::stoll(strHex.substr(iIndex, 2), &uConsumed, 16);
            if (uConsumed != 2) { return false; }
            vecChannels.push_back(iChannel);
        } catch (...) {
            return false;
        }
    }
    int64 iAlpha = vecChannels.size() == 4 ? vecChannels[3] : 255;
    objColor = color(static_cast<uint8>(vecChannels[0]), static_cast<uint8>(vecChannels[1]), static_cast<uint8>(vecChannels[2]), static_cast<uint8>(iAlpha));
    return true;
}

bool tryReadFloat(const ComponentValue& objValue, float64& fNumber) {
    if (objValue.eKind == ValueKind::Float) { fNumber = objValue.fFloat; return true; }
    if (objValue.eKind == ValueKind::Integer) { fNumber = static_cast<float64>(objValue.iInteger); return true; }
    if (objValue.eKind == ValueKind::Text) { return tryParseNumber(objValue.strText, fNumber); }
    return false;
}

bool tryReadInteger(const ComponentValue& objValue, int64& iNumber) {
    if (objValue.eKind == ValueKind::Integer) { iNumber = objValue.iInteger; return true; }
    float64 fNumber = 0.0;
    if (!tryReadFloat(objValue, fNumber)) { return false; }
    iNumber = static_cast<int64>(fNumber);
    return true;
}

bool tryReadBoolean(const ComponentValue& objValue, bool& bValue) {
    if (objValue.eKind != ValueKind::Boolean) { return false; }
    bValue = objValue.bBoolean;
    return true;
}

bool tryReadText(const ComponentValue& objValue, std::string& strValue) {
    if (objValue.isEmpty()) { return false; }
    strValue = objValue.displayText();
    return true;
}

bool tryReadColor(const ComponentValue& objValue, color& objColor) {
    if (objValue.eKind == ValueKind::Color) { objColor = objValue.objColorValue; return true; }
    if (objValue.eKind == ValueKind::Text) { return tryParseHexColor(objValue.strText, objColor); }
    return false;
}

int64 findItem(const std::vector<std::string>& vecItems, const std::string& strItem) {
    for (int64 iIndex = 0; iIndex < vecItems.size(); iIndex++) {
        if (vecItems[iIndex] == strItem) { return iIndex; }
    }
    return -1;
}

int64 tryReadSelectionIndex(const ComponentValue& objValue, const std::vector<std::string>& vecItems) {
    if (objValue.eKind == ValueKind::Selection || objValue.eKind == ValueKind::Text) { return findItem(vecItems, objValue.strText); }
    if (objValue.eKind == ValueKind::Integer && objValue.iInteger >= 0 && objValue.iInteger < vecItems.size()) { return objValue.iInteger; }
    return -1;
}

}

}
