#pragma once

namespace ui {

class SvgIcon {
    SvgDocument m_objSvgDocument;
    SvgColorMode m_eColorMode;
    RenderBackend* m_pTextureOwner = null;
    int64 m_iTextureHandle = 0;
    int64 m_iTexturePixelSize = 0;

    void releaseTexture() {
        if (m_pTextureOwner != null && m_iTextureHandle != 0) { m_pTextureOwner->destroyTexture(m_iTextureHandle); }
        m_iTextureHandle = 0;
        m_iTexturePixelSize = 0;
    }

public:
    SvgIcon(const std::string& strSvgMarkup, SvgColorMode eColorMode)
        : m_objSvgDocument(SvgParser::parse(strSvgMarkup)), m_eColorMode(eColorMode) {}

    SvgIcon(const SvgIcon& objSvgIconOther) = delete;
    SvgIcon& operator=(const SvgIcon& objSvgIconOther) = delete;

    ~SvgIcon() { releaseTexture(); }

    bool isValid() const { return m_objSvgDocument.isValid(); }
    SvgColorMode colorMode() const { return m_eColorMode; }

    void setColorMode(SvgColorMode eColorMode) {
        if (m_eColorMode == eColorMode) { return; }
        m_eColorMode = eColorMode;
        releaseTexture();
    }

    int64 textureForPixelSize(RenderBackend* pRenderBackend, int64 iPixelSize) {
        if (!isValid() || iPixelSize <= 0) { return 0; }
        if (m_iTextureHandle != 0 && m_iTexturePixelSize == iPixelSize && m_pTextureOwner == pRenderBackend) { return m_iTextureHandle; }
        releaseTexture();
        std::vector<uint8> vecRgbaPixels = SvgRasterizer::rasterize(m_objSvgDocument, iPixelSize, m_eColorMode);
        if (vecRgbaPixels.empty()) { return 0; }
        m_pTextureOwner = pRenderBackend;
        m_iTextureHandle = pRenderBackend->createTexture(iPixelSize, iPixelSize, vecRgbaPixels);
        m_iTexturePixelSize = m_iTextureHandle != 0 ? iPixelSize : 0;
        return m_iTextureHandle;
    }
};

}
