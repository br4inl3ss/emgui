#pragma once

namespace ui {

enum class FontRole : int32 { Body, Heading, Title, Small, Count };

class FontLibrary {
    struct FontRequest {
        std::string strSource;
        std::vector<uint8> vecFontBytes;
        bool bFromMemory = false;
        float64 fSize = 14.0;
        std::string strFallbackFamily;
        int64 iHandle = 0;
        float64 fResolvedScale = 0.0;
        bool bNeedsResolve = true;
    };

    static constexpr float64 fMinimumFontSize = 6.0;
    static constexpr float64 fMaximumFontSize = 96.0;

    std::vector<FontRequest> m_vecFontRequests;
    std::vector<std::string> m_vecReportedProblems;

    static std::string windowsFontDirectory() { return "C:/Windows/Fonts/"; }

    static bool hasFontExtension(const std::string& strLowercaseSource) {
        return strLowercaseSource.ends_with(".ttf") || strLowercaseSource.ends_with(".otf") || strLowercaseSource.ends_with(".ttc");
    }

    static std::string knownFamilyFile(const std::string& strLowercaseFamily) {
        switch (strLowercaseFamily) {
            case "segoe ui": return "segoeui.ttf";
            case "segoe ui semibold": return "seguisb.ttf";
            case "segoe ui bold": return "segoeuib.ttf";
            case "segoe ui light": return "segoeuil.ttf";
            case "arial": return "arial.ttf";
            case "arial bold": return "arialbd.ttf";
            case "calibri": return "calibri.ttf";
            case "calibri bold": return "calibrib.ttf";
            case "consolas": return "consola.ttf";
            case "consolas bold": return "consolab.ttf";
            case "verdana": return "verdana.ttf";
            case "verdana bold": return "verdanab.ttf";
            case "tahoma": return "tahoma.ttf";
            case "tahoma bold": return "tahomabd.ttf";
            case "bahnschrift": return "bahnschrift.ttf";
            case "cascadia code": return "CascadiaCode.ttf";
            case "cascadia mono": return "CascadiaMono.ttf";
            default: return "";
        }
    }

    static std::vector<std::string> candidatePaths(const std::string& strSource) {
        std::vector<std::string> vecCandidates;
        std::string strTrimmed = std::trim(strSource);
        if (strTrimmed.empty()) { return vecCandidates; }

        std::string strLowercase = std::to_lower(strTrimmed);
        bool bHasDirectory = strTrimmed.find('/') != std::string::npos || strTrimmed.find('\\') != std::string::npos;
        bool bHasExtension = hasFontExtension(strLowercase);
        vecCandidates.push_back(strTrimmed);

        if (bHasDirectory) {
            if (!bHasExtension) {
                vecCandidates.push_back(strTrimmed + ".ttf");
                vecCandidates.push_back(strTrimmed + ".otf");
            }
            return vecCandidates;
        }

        std::string strKnownFile = knownFamilyFile(strLowercase);
        if (!strKnownFile.empty()) { vecCandidates.push_back(windowsFontDirectory() + strKnownFile); }
        if (bHasExtension) {
            vecCandidates.push_back(windowsFontDirectory() + strTrimmed);
        } else {
            std::string strCompact = std::replace_all(strLowercase, " ", "");
            vecCandidates.push_back(windowsFontDirectory() + strTrimmed + ".ttf");
            vecCandidates.push_back(windowsFontDirectory() + strTrimmed + ".otf");
            vecCandidates.push_back(windowsFontDirectory() + strCompact + ".ttf");
        }
        return vecCandidates;
    }

    static float64 sanitizedSize(float64 fSize, float64 fFallbackSize) {
        if (!is_finite(fSize) || fSize <= 0.0) { return fFallbackSize; }
        return clamp(fSize, fMinimumFontSize, fMaximumFontSize);
    }

    void reportProblemOnce(PlatformBackend* pPlatformBackend, const std::string& strProblem) {
        for (const std::string& strReported : m_vecReportedProblems) {
            if (strReported == strProblem) { return; }
        }
        m_vecReportedProblems.push_back(strProblem);
        pPlatformBackend->log(strProblem);
    }

    int64 loadFirstAvailable(RenderBackend* pRenderBackend, const std::string& strSource, float64 fPixelSize) {
        for (const std::string& strCandidate : candidatePaths(strSource)) {
            int64 iHandle = pRenderBackend->loadFontFromFile(strCandidate, fPixelSize);
            if (iHandle != 0) { return iHandle; }
        }
        return 0;
    }

    int64 loadRequest(RenderBackend* pRenderBackend, PlatformBackend* pPlatformBackend, const FontRequest& objFontRequest, float64 fPixelSize) {
        if (objFontRequest.bFromMemory) {
            int64 iMemoryHandle = 0;
            if (!objFontRequest.vecFontBytes.empty()) {
                iMemoryHandle = pRenderBackend->loadFontFromMemory(objFontRequest.strSource, objFontRequest.vecFontBytes, fPixelSize);
            }
            if (iMemoryHandle != 0) { return iMemoryHandle; }
            reportProblemOnce(pPlatformBackend, "font from memory '" + objFontRequest.strSource + "' could not be loaded, using a fallback font");
        } else {
            int64 iFileHandle = loadFirstAvailable(pRenderBackend, objFontRequest.strSource, fPixelSize);
            if (iFileHandle != 0) { return iFileHandle; }
            std::string strProblem = std::trim(objFontRequest.strSource).empty()
                ? std::string("an empty font name was given, using a fallback font")
                : "font '" + objFontRequest.strSource + "' was not found, using a fallback font";
            reportProblemOnce(pPlatformBackend, strProblem);
        }

        std::vector<std::string> vecFallbackFamilies = { objFontRequest.strFallbackFamily, "Segoe UI", "Arial", "Tahoma" };
        for (const std::string& strFallbackFamily : vecFallbackFamilies) {
            int64 iFallbackHandle = loadFirstAvailable(pRenderBackend, strFallbackFamily, fPixelSize);
            if (iFallbackHandle != 0) { return iFallbackHandle; }
        }
        return pRenderBackend->builtinFont(fPixelSize);
    }

    FontRequest& requestFor(FontRole eRole) { return m_vecFontRequests[static_cast<int64>(eRole)]; }
    const FontRequest& requestFor(FontRole eRole) const { return m_vecFontRequests[static_cast<int64>(eRole)]; }

    void assignDefault(FontRole eRole, const std::string& strFamily, float64 fSize) {
        FontRequest& objFontRequest = requestFor(eRole);
        objFontRequest.strSource = strFamily;
        objFontRequest.strFallbackFamily = strFamily;
        objFontRequest.fSize = fSize;
    }

public:
    FontLibrary() {
        m_vecFontRequests.resize(static_cast<int64>(FontRole::Count));
        assignDefault(FontRole::Body, "Segoe UI", 16.0);
        assignDefault(FontRole::Heading, "Segoe UI Semibold", 16.0);
        assignDefault(FontRole::Title, "Segoe UI Semibold", 17.0);
        assignDefault(FontRole::Small, "Segoe UI", 13.0);
    }

    void setFont(FontRole eRole, const std::string& strPathOrFamily, float64 fSize) {
        if (eRole == FontRole::Count) { return; }
        FontRequest& objFontRequest = requestFor(eRole);
        objFontRequest.strSource = strPathOrFamily;
        objFontRequest.vecFontBytes.clear();
        objFontRequest.bFromMemory = false;
        objFontRequest.fSize = sanitizedSize(fSize, objFontRequest.fSize);
        objFontRequest.bNeedsResolve = true;
    }

    void setFont(FontRole eRole, const std::string& strPathOrFamily) {
        if (eRole == FontRole::Count) { return; }
        setFont(eRole, strPathOrFamily, requestFor(eRole).fSize);
    }

    void setFontFromMemory(FontRole eRole, const std::string& strLabel, const std::vector<uint8>& vecFontBytes, float64 fSize) {
        if (eRole == FontRole::Count) { return; }
        FontRequest& objFontRequest = requestFor(eRole);
        objFontRequest.strSource = strLabel;
        objFontRequest.vecFontBytes = vecFontBytes;
        objFontRequest.bFromMemory = true;
        objFontRequest.fSize = sanitizedSize(fSize, objFontRequest.fSize);
        objFontRequest.bNeedsResolve = true;
    }

    void setFontFamily(const std::string& strPathOrFamily) {
        setFont(FontRole::Body, strPathOrFamily);
        setFont(FontRole::Heading, strPathOrFamily);
        setFont(FontRole::Title, strPathOrFamily);
        setFont(FontRole::Small, strPathOrFamily);
    }

    void setFontSize(FontRole eRole, float64 fSize) {
        if (eRole == FontRole::Count) { return; }
        FontRequest& objFontRequest = requestFor(eRole);
        objFontRequest.fSize = sanitizedSize(fSize, objFontRequest.fSize);
        objFontRequest.bNeedsResolve = true;
    }

    float64 fontSize(FontRole eRole) const { return requestFor(eRole).fSize; }
    int64 handleFor(FontRole eRole) const { return requestFor(eRole).iHandle; }

    void resolve(RenderBackend* pRenderBackend, PlatformBackend* pPlatformBackend, float64 fScale) {
        for (FontRequest& objFontRequest : m_vecFontRequests) {
            if (!objFontRequest.bNeedsResolve && objFontRequest.fResolvedScale == fScale) { continue; }
            float64 fPixelSize = fmax(fMinimumFontSize, round(objFontRequest.fSize * fScale));
            objFontRequest.iHandle = loadRequest(pRenderBackend, pPlatformBackend, objFontRequest, fPixelSize);
            objFontRequest.fResolvedScale = fScale;
            objFontRequest.bNeedsResolve = false;
        }
    }
};

}
