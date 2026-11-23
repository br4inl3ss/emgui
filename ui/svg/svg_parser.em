#pragma once

namespace ui {

struct SvgStyle {
    bool bFillEnabled = true;
    bool bFillUsesEvenOddRule = false;
    color objColorFill = color(0, 0, 0, 255);
    bool bStrokeEnabled = false;
    color objColorStroke = color(0, 0, 0, 255);
    float64 fStrokeWidth = 1.0;
    float64 fOpacity = 1.0;
    float64 fFillOpacity = 1.0;
    float64 fStrokeOpacity = 1.0;
    SvgTransform objTransform;
};

struct SvgAttribute {
    std::string strName;
    std::string strValue;
};

struct SvgTag {
    std::string strName;
    std::vector<SvgAttribute> vecAttributes;
    bool bIsClosingTag = false;
    bool bIsSelfClosing = false;

    bool hasAttribute(const std::string& strAttributeName) const {
        for (const SvgAttribute& objAttribute : vecAttributes) {
            if (objAttribute.strName == strAttributeName) { return true; }
        }
        return false;
    }

    std::string attribute(const std::string& strAttributeName) const {
        for (const SvgAttribute& objAttribute : vecAttributes) {
            if (objAttribute.strName == strAttributeName) { return objAttribute.strValue; }
        }
        return "";
    }
};

class SvgParser {
    std::string m_strMarkup;
    int64 m_iPosition = 0;
    std::vector<SvgStyle> m_vecStyleStack;
    int64 m_iSkippedElementDepth = 0;
    bool m_bViewBoxFound = false;
    SvgDocument m_objSvgDocument;

    static bool isSeparator(char chValue) {
        return chValue == ' ' || chValue == ',' || chValue == '\t' || chValue == '\n' || chValue == '\r';
    }

    static bool isDigit(char chValue) { return chValue >= '0' && chValue <= '9'; }

    static bool isNameCharacter(char chValue) {
        return !isSeparator(chValue) && chValue != '=' && chValue != '>' && chValue != '/' && chValue != '<' && chValue != '"' && chValue != '\'';
    }

    static void skipSeparators(const std::string& strText, int64& iPosition) {
        while (iPosition < strText.size() && isSeparator(strText[iPosition])) { iPosition++; }
    }

    static bool scanNumber(const std::string& strText, int64& iPosition, float64& fNumber) {
        skipSeparators(strText, iPosition);
        int64 iStart = iPosition;
        int64 iCursor = iPosition;
        if (iCursor < strText.size() && (strText[iCursor] == '+' || strText[iCursor] == '-')) { iCursor++; }
        int64 iDigitCount = 0;
        while (iCursor < strText.size() && isDigit(strText[iCursor])) { iCursor++; iDigitCount++; }
        if (iCursor < strText.size() && strText[iCursor] == '.') {
            iCursor++;
            while (iCursor < strText.size() && isDigit(strText[iCursor])) { iCursor++; iDigitCount++; }
        }
        if (iDigitCount == 0) { return false; }
        if (iCursor < strText.size() && (strText[iCursor] == 'e' || strText[iCursor] == 'E')) {
            int64 iExponentCursor = iCursor + 1;
            if (iExponentCursor < strText.size() && (strText[iExponentCursor] == '+' || strText[iExponentCursor] == '-')) { iExponentCursor++; }
            if (iExponentCursor < strText.size() && isDigit(strText[iExponentCursor])) {
                while (iExponentCursor < strText.size() && isDigit(strText[iExponentCursor])) { iExponentCursor++; }
                iCursor = iExponentCursor;
            }
        }
        fNumber = std::stod(strText.substr(iStart, iCursor - iStart));
        iPosition = iCursor;
        return true;
    }

    static bool scanFlag(const std::string& strText, int64& iPosition, bool& bFlag) {
        skipSeparators(strText, iPosition);
        if (iPosition >= strText.size()) { return false; }
        char chValue = strText[iPosition];
        if (chValue != '0' && chValue != '1') { return false; }
        bFlag = chValue == '1';
        iPosition++;
        return true;
    }

    static std::vector<float64> parseNumberList(const std::string& strText) {
        std::vector<float64> vecNumbers;
        int64 iPosition = 0;
        float64 fNumber = 0.0;
        while (scanNumber(strText, iPosition, fNumber)) { vecNumbers.push_back(fNumber); }
        return vecNumbers;
    }

    static float64 parseLength(const std::string& strText, float64 fFallback) {
        int64 iPosition = 0;
        float64 fNumber = 0.0;
        if (scanNumber(strText, iPosition, fNumber)) { return fNumber; }
        return fFallback;
    }

    static int32 hexDigitValue(char chValue) {
        if (chValue >= '0' && chValue <= '9') { return static_cast<int32>(chValue - '0'); }
        if (chValue >= 'a' && chValue <= 'f') { return static_cast<int32>(chValue - 'a') + 10; }
        if (chValue >= 'A' && chValue <= 'F') { return static_cast<int32>(chValue - 'A') + 10; }
        return -1;
    }

    static bool parseHexColor(const std::string& strHex, color& objColorParsed) {
        std::vector<int32> vecDigits;
        for (int64 iIndex = 0; iIndex < strHex.size(); iIndex++) {
            int32 iDigit = hexDigitValue(strHex[iIndex]);
            if (iDigit < 0) { return false; }
            vecDigits.push_back(iDigit);
        }
        if (vecDigits.size() == 3 || vecDigits.size() == 4) {
            int32 iAlpha = vecDigits.size() == 4 ? vecDigits[3] * 17 : 255;
            objColorParsed = color(static_cast<uint8>(vecDigits[0] * 17), static_cast<uint8>(vecDigits[1] * 17), static_cast<uint8>(vecDigits[2] * 17), static_cast<uint8>(iAlpha));
            return true;
        }
        if (vecDigits.size() == 6 || vecDigits.size() == 8) {
            int32 iAlpha = vecDigits.size() == 8 ? vecDigits[6] * 16 + vecDigits[7] : 255;
            objColorParsed = color(static_cast<uint8>(vecDigits[0] * 16 + vecDigits[1]), static_cast<uint8>(vecDigits[2] * 16 + vecDigits[3]),
                static_cast<uint8>(vecDigits[4] * 16 + vecDigits[5]), static_cast<uint8>(iAlpha));
            return true;
        }
        return false;
    }

    static bool parsePaint(const std::string& strRawValue, bool& bEnabled, color& objColorPaint) {
        std::string strValue = std::to_lower(std::trim(strRawValue));
        if (strValue.empty() || strValue == "inherit") { return false; }
        if (strValue == "none" || strValue == "transparent") {
            bEnabled = false;
            return true;
        }
        bEnabled = true;
        if (strValue == "currentcolor" || strValue.starts_with("url(")) {
            objColorPaint = color(255, 255, 255, 255);
            return true;
        }
        if (strValue.starts_with("#")) { return parseHexColor(strValue.substr(1), objColorPaint); }
        if (strValue.starts_with("rgb")) {
            std::vector<float64> vecChannels = parseNumberList(strValue.substr(strValue.find('(') + 1));
            if (vecChannels.size() < 3) { return false; }
            float64 fAlpha = vecChannels.size() >= 4 ? vecChannels[3] : 1.0;
            objColorPaint = color(static_cast<uint8>(clamp(vecChannels[0], 0.0, 255.0)), static_cast<uint8>(clamp(vecChannels[1], 0.0, 255.0)),
                static_cast<uint8>(clamp(vecChannels[2], 0.0, 255.0)), static_cast<uint8>(clamp(fAlpha, 0.0, 1.0) * 255.0));
            return true;
        }
        switch (strValue) {
            case "black": objColorPaint = color(0, 0, 0, 255); return true;
            case "white": objColorPaint = color(255, 255, 255, 255); return true;
            case "red": objColorPaint = color(255, 0, 0, 255); return true;
            case "green": objColorPaint = color(0, 128, 0, 255); return true;
            case "lime": objColorPaint = color(0, 255, 0, 255); return true;
            case "blue": objColorPaint = color(0, 0, 255, 255); return true;
            case "yellow": objColorPaint = color(255, 255, 0, 255); return true;
            case "orange": objColorPaint = color(255, 165, 0, 255); return true;
            case "purple": objColorPaint = color(128, 0, 128, 255); return true;
            case "gray": objColorPaint = color(128, 128, 128, 255); return true;
            case "grey": objColorPaint = color(128, 128, 128, 255); return true;
            default: return false;
        }
    }

    static SvgTransform parseTransform(const std::string& strText) {
        SvgTransform objTransformResult;
        int64 iPosition = 0;
        while (iPosition < strText.size()) {
            int64 iOpen = strText.find('(', iPosition);
            if (iOpen < 0) { break; }
            int64 iClose = strText.find(')', iOpen);
            if (iClose < 0) { break; }
            std::string strFunction = std::to_lower(std::trim(strText.substr(iPosition, iOpen - iPosition)));
            std::vector<float64> vecArguments = parseNumberList(strText.substr(iOpen + 1, iClose - iOpen - 1));
            SvgTransform objTransformStep;
            if (strFunction == "matrix" && vecArguments.size() == 6) {
                objTransformStep = SvgTransform::matrix(vecArguments[0], vecArguments[1], vecArguments[2], vecArguments[3], vecArguments[4], vecArguments[5]);
            } else if (strFunction == "translate" && vecArguments.size() >= 1) {
                objTransformStep = SvgTransform::matrix(1.0, 0.0, 0.0, 1.0, vecArguments[0], vecArguments.size() >= 2 ? vecArguments[1] : 0.0);
            } else if (strFunction == "scale" && vecArguments.size() >= 1) {
                objTransformStep = SvgTransform::matrix(vecArguments[0], 0.0, 0.0, vecArguments.size() >= 2 ? vecArguments[1] : vecArguments[0], 0.0, 0.0);
            } else if (strFunction == "rotate" && vecArguments.size() >= 1) {
                float64 fAngle = deg_to_rad(vecArguments[0]);
                SvgTransform objTransformRotation = SvgTransform::matrix(cos(fAngle), sin(fAngle), -sin(fAngle), cos(fAngle), 0.0, 0.0);
                if (vecArguments.size() >= 3) {
                    SvgTransform objTransformToPivot = SvgTransform::matrix(1.0, 0.0, 0.0, 1.0, vecArguments[1], vecArguments[2]);
                    SvgTransform objTransformFromPivot = SvgTransform::matrix(1.0, 0.0, 0.0, 1.0, -vecArguments[1], -vecArguments[2]);
                    objTransformStep = objTransformToPivot.then(objTransformRotation).then(objTransformFromPivot);
                } else {
                    objTransformStep = objTransformRotation;
                }
            } else if (strFunction == "skewx" && vecArguments.size() >= 1) {
                objTransformStep = SvgTransform::matrix(1.0, 0.0, tan(deg_to_rad(vecArguments[0])), 1.0, 0.0, 0.0);
            } else if (strFunction == "skewy" && vecArguments.size() >= 1) {
                objTransformStep = SvgTransform::matrix(1.0, tan(deg_to_rad(vecArguments[0])), 0.0, 1.0, 0.0, 0.0);
            }
            objTransformResult = objTransformResult.then(objTransformStep);
            iPosition = iClose + 1;
            while (iPosition < strText.size() && isSeparator(strText[iPosition])) { iPosition++; }
        }
        return objTransformResult;
    }

    static void applyPresentationProperty(SvgStyle& objSvgStyle, const std::string& strName, const std::string& strValue) {
        if (strName == "fill") {
            parsePaint(strValue, objSvgStyle.bFillEnabled, objSvgStyle.objColorFill);
        } else if (strName == "stroke") {
            parsePaint(strValue, objSvgStyle.bStrokeEnabled, objSvgStyle.objColorStroke);
        } else if (strName == "stroke-width") {
            objSvgStyle.fStrokeWidth = fmax(0.0, parseLength(strValue, objSvgStyle.fStrokeWidth));
        } else if (strName == "fill-rule") {
            objSvgStyle.bFillUsesEvenOddRule = std::trim(strValue) == "evenodd";
        } else if (strName == "opacity") {
            objSvgStyle.fOpacity = objSvgStyle.fOpacity * clamp(parseLength(strValue, 1.0), 0.0, 1.0);
        } else if (strName == "fill-opacity") {
            objSvgStyle.fFillOpacity = clamp(parseLength(strValue, 1.0), 0.0, 1.0);
        } else if (strName == "stroke-opacity") {
            objSvgStyle.fStrokeOpacity = clamp(parseLength(strValue, 1.0), 0.0, 1.0);
        }
    }

    static SvgStyle styleForElement(const SvgStyle& objSvgStyleParent, const SvgTag& objSvgTag) {
        SvgStyle objSvgStyle = objSvgStyleParent;
        for (const SvgAttribute& objAttribute : objSvgTag.vecAttributes) {
            applyPresentationProperty(objSvgStyle, objAttribute.strName, objAttribute.strValue);
        }
        std::string strInlineStyle = objSvgTag.attribute("style");
        if (!strInlineStyle.empty()) {
            for (const std::string& strDeclaration : std::split(strInlineStyle, ";")) {
                int64 iColon = strDeclaration.find(':');
                if (iColon < 0) { continue; }
                applyPresentationProperty(objSvgStyle, std::trim(strDeclaration.substr(0, iColon)), std::trim(strDeclaration.substr(iColon + 1)));
            }
        }
        if (objSvgTag.hasAttribute("transform")) {
            objSvgStyle.objTransform = objSvgStyleParent.objTransform.then(parseTransform(objSvgTag.attribute("transform")));
        }
        return objSvgStyle;
    }

    static bool isSkippedElement(const std::string& strName) {
        return strName == "defs" || strName == "clipPath" || strName == "mask" || strName == "symbol"
            || strName == "linearGradient" || strName == "radialGradient" || strName == "pattern" || strName == "style"
            || strName == "title" || strName == "desc" || strName == "metadata" || strName == "text" || strName == "marker"
            || strName == "filter" || strName == "script" || strName == "foreignObject";
    }

    bool skipPast(const std::string& strTerminator) {
        int64 iFound = m_strMarkup.find(strTerminator, m_iPosition);
        if (iFound < 0) {
            m_iPosition = m_strMarkup.size();
            return false;
        }
        m_iPosition = iFound + strTerminator.size();
        return true;
    }

    bool readNextTag(SvgTag& objSvgTag) {
        while (true) {
            int64 iOpen = m_strMarkup.find('<', m_iPosition);
            if (iOpen < 0) { return false; }
            m_iPosition = iOpen + 1;
            bool bIsComment = m_iPosition + 2 < m_strMarkup.size() && m_strMarkup[m_iPosition] == '!'
                && m_strMarkup[m_iPosition + 1] == '-' && m_strMarkup[m_iPosition + 2] == '-';
            if (bIsComment) {
                if (!skipPast("-->")) { return false; }
                continue;
            }
            if (m_iPosition < m_strMarkup.size() && (m_strMarkup[m_iPosition] == '?' || m_strMarkup[m_iPosition] == '!')) {
                if (!skipPast(">")) { return false; }
                continue;
            }
            break;
        }

        objSvgTag = SvgTag();
        if (m_iPosition < m_strMarkup.size() && m_strMarkup[m_iPosition] == '/') {
            objSvgTag.bIsClosingTag = true;
            m_iPosition++;
        }
        int64 iNameStart = m_iPosition;
        while (m_iPosition < m_strMarkup.size() && isNameCharacter(m_strMarkup[m_iPosition])) { m_iPosition++; }
        objSvgTag.strName = m_strMarkup.substr(iNameStart, m_iPosition - iNameStart);
        int64 iNamespaceColon = objSvgTag.strName.find(':');
        if (iNamespaceColon >= 0) { objSvgTag.strName = objSvgTag.strName.substr(iNamespaceColon + 1); }

        while (m_iPosition < m_strMarkup.size()) {
            skipSeparators(m_strMarkup, m_iPosition);
            if (m_iPosition >= m_strMarkup.size()) { return false; }
            char chCurrent = m_strMarkup[m_iPosition];
            if (chCurrent == '>') {
                m_iPosition++;
                return true;
            }
            if (chCurrent == '/') {
                objSvgTag.bIsSelfClosing = true;
                m_iPosition++;
                continue;
            }
            int64 iAttributeStart = m_iPosition;
            while (m_iPosition < m_strMarkup.size() && isNameCharacter(m_strMarkup[m_iPosition])) { m_iPosition++; }
            SvgAttribute objAttribute;
            objAttribute.strName = m_strMarkup.substr(iAttributeStart, m_iPosition - iAttributeStart);
            skipSeparators(m_strMarkup, m_iPosition);
            if (m_iPosition < m_strMarkup.size() && m_strMarkup[m_iPosition] == '=') {
                m_iPosition++;
                skipSeparators(m_strMarkup, m_iPosition);
                if (m_iPosition >= m_strMarkup.size()) { return false; }
                char chQuote = m_strMarkup[m_iPosition];
                if (chQuote == '"' || chQuote == '\'') {
                    int64 iValueEnd = m_strMarkup.find(chQuote, m_iPosition + 1);
                    if (iValueEnd < 0) { return false; }
                    objAttribute.strValue = m_strMarkup.substr(m_iPosition + 1, iValueEnd - m_iPosition - 1);
                    m_iPosition = iValueEnd + 1;
                }
            }
            if (objAttribute.strName.empty()) {
                m_iPosition++;
                continue;
            }
            objSvgTag.vecAttributes.push_back(objAttribute);
        }
        return false;
    }

    void readRootDimensions(const SvgTag& objSvgTag) {
        std::vector<float64> vecViewBox = parseNumberList(objSvgTag.attribute("viewBox"));
        if (vecViewBox.size() == 4 && vecViewBox[2] > 0.0 && vecViewBox[3] > 0.0) {
            m_objSvgDocument.objRectViewBox = Rect(vecViewBox[0], vecViewBox[1], vecViewBox[2], vecViewBox[3]);
            m_bViewBoxFound = true;
            return;
        }
        float64 fWidth = parseLength(objSvgTag.attribute("width"), 0.0);
        float64 fHeight = parseLength(objSvgTag.attribute("height"), 0.0);
        if (fWidth > 0.0 && fHeight > 0.0) {
            m_objSvgDocument.objRectViewBox = Rect(0.0, 0.0, fWidth, fHeight);
            m_bViewBoxFound = true;
        }
    }

    static void parsePathData(const std::string& strPathData, SvgPathBuilder& objSvgPathBuilder) {
        int64 iPosition = 0;
        char chCommand = 0;
        char chPreviousCommand = 0;
        vec2 objVec2LastControl = vec2(0.0, 0.0);

        while (true) {
            skipSeparators(strPathData, iPosition);
            if (iPosition >= strPathData.size()) { return; }
            char chNext = strPathData[iPosition];
            if (std::isalpha(static_cast<int32>(chNext)) != 0) {
                chCommand = chNext;
                iPosition++;
            } else if (chCommand == 0) {
                return;
            }

            bool bRelative = chCommand >= 'a' && chCommand <= 'z';
            char chUpperCommand = bRelative ? static_cast<char>(chCommand - 32) : chCommand;
            vec2 objVec2Current = objSvgPathBuilder.currentPoint();
            float64 fOriginX = bRelative ? objVec2Current.x : 0.0;
            float64 fOriginY = bRelative ? objVec2Current.y : 0.0;

            if (chUpperCommand == 'Z') {
                objSvgPathBuilder.closeContour();
                chPreviousCommand = 'Z';
                chCommand = 0;
                continue;
            }

            float64 fFirst = 0.0;
            float64 fSecond = 0.0;
            float64 fThird = 0.0;
            float64 fFourth = 0.0;
            float64 fFifth = 0.0;
            float64 fSixth = 0.0;
            bool bLargeArc = false;
            bool bSweep = false;

            if (chUpperCommand == 'M') {
                if (!scanNumber(strPathData, iPosition, fFirst) || !scanNumber(strPathData, iPosition, fSecond)) { return; }
                objSvgPathBuilder.moveTo(vec2(fOriginX + fFirst, fOriginY + fSecond));
                chCommand = bRelative ? 'l' : 'L';
            } else if (chUpperCommand == 'L') {
                if (!scanNumber(strPathData, iPosition, fFirst) || !scanNumber(strPathData, iPosition, fSecond)) { return; }
                objSvgPathBuilder.lineTo(vec2(fOriginX + fFirst, fOriginY + fSecond));
            } else if (chUpperCommand == 'H') {
                if (!scanNumber(strPathData, iPosition, fFirst)) { return; }
                objSvgPathBuilder.lineTo(vec2(fOriginX + fFirst, objVec2Current.y));
            } else if (chUpperCommand == 'V') {
                if (!scanNumber(strPathData, iPosition, fFirst)) { return; }
                objSvgPathBuilder.lineTo(vec2(objVec2Current.x, fOriginY + fFirst));
            } else if (chUpperCommand == 'C') {
                if (!scanNumber(strPathData, iPosition, fFirst) || !scanNumber(strPathData, iPosition, fSecond)
                    || !scanNumber(strPathData, iPosition, fThird) || !scanNumber(strPathData, iPosition, fFourth)
                    || !scanNumber(strPathData, iPosition, fFifth) || !scanNumber(strPathData, iPosition, fSixth)) { return; }
                objVec2LastControl = vec2(fOriginX + fThird, fOriginY + fFourth);
                objSvgPathBuilder.cubicTo(vec2(fOriginX + fFirst, fOriginY + fSecond), objVec2LastControl, vec2(fOriginX + fFifth, fOriginY + fSixth));
            } else if (chUpperCommand == 'S') {
                if (!scanNumber(strPathData, iPosition, fFirst) || !scanNumber(strPathData, iPosition, fSecond)
                    || !scanNumber(strPathData, iPosition, fThird) || !scanNumber(strPathData, iPosition, fFourth)) { return; }
                bool bReflects = chPreviousCommand == 'C' || chPreviousCommand == 'S';
                vec2 objVec2Reflected = bReflects ? vec2(2.0 * objVec2Current.x - objVec2LastControl.x, 2.0 * objVec2Current.y - objVec2LastControl.y) : objVec2Current;
                objVec2LastControl = vec2(fOriginX + fFirst, fOriginY + fSecond);
                objSvgPathBuilder.cubicTo(objVec2Reflected, objVec2LastControl, vec2(fOriginX + fThird, fOriginY + fFourth));
            } else if (chUpperCommand == 'Q') {
                if (!scanNumber(strPathData, iPosition, fFirst) || !scanNumber(strPathData, iPosition, fSecond)
                    || !scanNumber(strPathData, iPosition, fThird) || !scanNumber(strPathData, iPosition, fFourth)) { return; }
                objVec2LastControl = vec2(fOriginX + fFirst, fOriginY + fSecond);
                objSvgPathBuilder.quadraticTo(objVec2LastControl, vec2(fOriginX + fThird, fOriginY + fFourth));
            } else if (chUpperCommand == 'T') {
                if (!scanNumber(strPathData, iPosition, fFirst) || !scanNumber(strPathData, iPosition, fSecond)) { return; }
                bool bReflects = chPreviousCommand == 'Q' || chPreviousCommand == 'T';
                objVec2LastControl = bReflects ? vec2(2.0 * objVec2Current.x - objVec2LastControl.x, 2.0 * objVec2Current.y - objVec2LastControl.y) : objVec2Current;
                objSvgPathBuilder.quadraticTo(objVec2LastControl, vec2(fOriginX + fFirst, fOriginY + fSecond));
            } else if (chUpperCommand == 'A') {
                if (!scanNumber(strPathData, iPosition, fFirst) || !scanNumber(strPathData, iPosition, fSecond)
                    || !scanNumber(strPathData, iPosition, fThird) || !scanFlag(strPathData, iPosition, bLargeArc)
                    || !scanFlag(strPathData, iPosition, bSweep) || !scanNumber(strPathData, iPosition, fFourth)
                    || !scanNumber(strPathData, iPosition, fFifth)) { return; }
                objSvgPathBuilder.arcTo(fFirst, fSecond, fThird, bLargeArc, bSweep, vec2(fOriginX + fFourth, fOriginY + fFifth));
            } else {
                return;
            }
            chPreviousCommand = chUpperCommand;
        }
    }

    static void buildElementGeometry(const SvgTag& objSvgTag, SvgPathBuilder& objSvgPathBuilder) {
        const std::string& strName = objSvgTag.strName;
        if (strName == "path") {
            parsePathData(objSvgTag.attribute("d"), objSvgPathBuilder);
        } else if (strName == "rect") {
            bool bHasRadiusX = objSvgTag.hasAttribute("rx");
            bool bHasRadiusY = objSvgTag.hasAttribute("ry");
            float64 fRadiusX = parseLength(objSvgTag.attribute("rx"), 0.0);
            float64 fRadiusY = parseLength(objSvgTag.attribute("ry"), 0.0);
            if (bHasRadiusX && !bHasRadiusY) { fRadiusY = fRadiusX; }
            if (bHasRadiusY && !bHasRadiusX) { fRadiusX = fRadiusY; }
            objSvgPathBuilder.appendRoundedRect(parseLength(objSvgTag.attribute("x"), 0.0), parseLength(objSvgTag.attribute("y"), 0.0),
                parseLength(objSvgTag.attribute("width"), 0.0), parseLength(objSvgTag.attribute("height"), 0.0), fRadiusX, fRadiusY);
        } else if (strName == "circle") {
            float64 fRadius = parseLength(objSvgTag.attribute("r"), 0.0);
            objSvgPathBuilder.appendEllipse(parseLength(objSvgTag.attribute("cx"), 0.0), parseLength(objSvgTag.attribute("cy"), 0.0), fRadius, fRadius);
        } else if (strName == "ellipse") {
            objSvgPathBuilder.appendEllipse(parseLength(objSvgTag.attribute("cx"), 0.0), parseLength(objSvgTag.attribute("cy"), 0.0),
                parseLength(objSvgTag.attribute("rx"), 0.0), parseLength(objSvgTag.attribute("ry"), 0.0));
        } else if (strName == "line") {
            objSvgPathBuilder.moveTo(vec2(parseLength(objSvgTag.attribute("x1"), 0.0), parseLength(objSvgTag.attribute("y1"), 0.0)));
            objSvgPathBuilder.lineTo(vec2(parseLength(objSvgTag.attribute("x2"), 0.0), parseLength(objSvgTag.attribute("y2"), 0.0)));
        } else if (strName == "polyline" || strName == "polygon") {
            std::vector<float64> vecCoordinates = parseNumberList(objSvgTag.attribute("points"));
            for (int64 iIndex = 0; iIndex + 1 < vecCoordinates.size(); iIndex += 2) {
                vec2 objVec2Point = vec2(vecCoordinates[iIndex], vecCoordinates[iIndex + 1]);
                if (iIndex == 0) { objSvgPathBuilder.moveTo(objVec2Point); } else { objSvgPathBuilder.lineTo(objVec2Point); }
            }
            if (strName == "polygon") { objSvgPathBuilder.closeContour(); }
        }
    }

    static color withOpacity(color objColorBase, float64 fOpacity) {
        return objColorBase.with_alpha(static_cast<uint8>(clamp(static_cast<float64>(objColorBase.a) * fOpacity, 0.0, 255.0)));
    }

    void emitShape(const SvgTag& objSvgTag, const SvgStyle& objSvgStyle) {
        if (!objSvgStyle.bFillEnabled && !objSvgStyle.bStrokeEnabled) { return; }
        SvgPathBuilder objSvgPathBuilder(objSvgStyle.objTransform);
        buildElementGeometry(objSvgTag, objSvgPathBuilder);
        if (!objSvgPathBuilder.hasContours()) { return; }

        SvgShape objSvgShape;
        objSvgPathBuilder.moveContoursInto(objSvgShape);
        objSvgShape.bFillEnabled = objSvgStyle.bFillEnabled && objSvgTag.strName != "line" && objSvgTag.strName != "polyline";
        objSvgShape.bFillUsesEvenOddRule = objSvgStyle.bFillUsesEvenOddRule;
        objSvgShape.objColorFill = withOpacity(objSvgStyle.objColorFill, objSvgStyle.fOpacity * objSvgStyle.fFillOpacity);
        objSvgShape.bStrokeEnabled = objSvgStyle.bStrokeEnabled && objSvgStyle.fStrokeWidth > 0.0;
        objSvgShape.objColorStroke = withOpacity(objSvgStyle.objColorStroke, objSvgStyle.fOpacity * objSvgStyle.fStrokeOpacity);
        objSvgShape.fStrokeWidth = objSvgStyle.fStrokeWidth * objSvgStyle.objTransform.averageScale();
        m_objSvgDocument.vecShapes.push_back(objSvgShape);
    }

    void handleOpenTag(const SvgTag& objSvgTag) {
        if (m_iSkippedElementDepth > 0 || isSkippedElement(objSvgTag.strName)) {
            if (!objSvgTag.bIsSelfClosing) { m_iSkippedElementDepth++; }
            return;
        }
        if (objSvgTag.strName == "svg" && !m_bViewBoxFound) { readRootDimensions(objSvgTag); }
        SvgStyle objSvgStyle = styleForElement(m_vecStyleStack.back(), objSvgTag);
        emitShape(objSvgTag, objSvgStyle);
        if (!objSvgTag.bIsSelfClosing) { m_vecStyleStack.push_back(objSvgStyle); }
    }

    void handleCloseTag() {
        if (m_iSkippedElementDepth > 0) {
            m_iSkippedElementDepth--;
            return;
        }
        if (m_vecStyleStack.size() > 1) { m_vecStyleStack.pop_back(); }
    }

    void fitViewBoxToShapes() {
        float64 fMinimumX = 1e300;
        float64 fMinimumY = 1e300;
        float64 fMaximumX = -1e300;
        float64 fMaximumY = -1e300;
        for (const SvgShape& objSvgShape : m_objSvgDocument.vecShapes) {
            for (const std::vector<vec2>& vecContour : objSvgShape.vecContours) {
                for (const vec2& objVec2Point : vecContour) {
                    fMinimumX = fmin(fMinimumX, objVec2Point.x);
                    fMinimumY = fmin(fMinimumY, objVec2Point.y);
                    fMaximumX = fmax(fMaximumX, objVec2Point.x);
                    fMaximumY = fmax(fMaximumY, objVec2Point.y);
                }
            }
        }
        if (fMaximumX > fMinimumX && fMaximumY > fMinimumY) {
            m_objSvgDocument.objRectViewBox = Rect(fMinimumX, fMinimumY, fMaximumX - fMinimumX, fMaximumY - fMinimumY);
        }
    }

    SvgParser(const std::string& strMarkup) : m_strMarkup(strMarkup) {
        m_vecStyleStack.push_back(SvgStyle());
    }

    void run() {
        SvgTag objSvgTag;
        while (readNextTag(objSvgTag)) {
            if (objSvgTag.bIsClosingTag) {
                handleCloseTag();
            } else {
                handleOpenTag(objSvgTag);
            }
        }
        if (!m_bViewBoxFound) { fitViewBoxToShapes(); }
    }

public:
    static SvgDocument parse(const std::string& strMarkup) {
        SvgParser objSvgParser(strMarkup);
        try {
            objSvgParser.run();
        } catch (...) {
            return SvgDocument();
        }
        return objSvgParser.m_objSvgDocument;
    }
};

}
