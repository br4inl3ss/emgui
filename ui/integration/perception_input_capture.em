#pragma once

namespace ui {

bool suppressInputShieldRendering(int64 iFrameHandle) { return false; }

class PerceptionInputCapture : public InputCapture {
    layer_t m_objLayer;
    bool m_bLayerCreated = false;
    std::vector<frame_t> m_vecShieldFrames;
    std::vector<Rect> m_vecShieldRegions;
    std::vector<bool> m_vecShieldVisible;

    static float64 hostUnitsPerPixel() {
        float64 fHostScale = render::get_view_scale();
        return is_finite(fHostScale) && fHostScale > 0.0 ? 1.0 / fHostScale : 1.0;
    }

    void ensureLayer() {
        if (m_bLayerCreated) { return; }
        m_objLayer = create_layer("enma-ui input capture", false, false);
        m_bLayerCreated = true;
    }

    void ensureShieldCount(int64 iCount) {
        while (m_vecShieldFrames.size() < iCount) {
            std::string strName = "enma-ui input capture " + std::to_string(m_vecShieldFrames.size());
            frame_t objFrameShield = create_frame(strName, vec2(0.0, 0.0), vec2(1.0, 1.0), m_objLayer);
            objFrameShield.install_hook(ui_hook::should_render, reinterpret_cast<int64>(suppressInputShieldRendering));
            objFrameShield.set_float(widget_attr::frame_border_thickness, 0.0);
            objFrameShield.set_visible(false);
            m_vecShieldFrames.push_back(objFrameShield);
            m_vecShieldRegions.push_back(Rect());
            m_vecShieldVisible.push_back(false);
        }
    }

    void placeShield(int64 iIndex, const Rect& objRectPixels) {
        float64 fUnits = hostUnitsPerPixel();
        Rect objRectUnits = Rect(objRectPixels.fX * fUnits, objRectPixels.fY * fUnits, objRectPixels.fWidth * fUnits, objRectPixels.fHeight * fUnits);
        const Rect& objRectPlaced = m_vecShieldRegions[iIndex];
        bool bMoved = objRectPlaced.fX != objRectUnits.fX || objRectPlaced.fY != objRectUnits.fY
            || objRectPlaced.fWidth != objRectUnits.fWidth || objRectPlaced.fHeight != objRectUnits.fHeight;
        if (bMoved) {
            m_vecShieldFrames[iIndex].set_pos(objRectUnits.position());
            m_vecShieldFrames[iIndex].set_size(objRectUnits.size());
            m_vecShieldRegions[iIndex] = objRectUnits;
        }
        if (!m_vecShieldVisible[iIndex]) {
            m_vecShieldFrames[iIndex].set_visible(true);
            m_vecShieldVisible[iIndex] = true;
        }
    }

    void hideShield(int64 iIndex) {
        if (!m_vecShieldVisible[iIndex]) { return; }
        m_vecShieldFrames[iIndex].set_visible(false);
        m_vecShieldVisible[iIndex] = false;
    }

public:
    void captureRegions(const std::vector<Rect>& vecPixelRegions) override {
        if (vecPixelRegions.empty() && !m_bLayerCreated) { return; }
        ensureLayer();
        ensureShieldCount(vecPixelRegions.size());
        for (int64 iIndex = 0; iIndex < m_vecShieldFrames.size(); iIndex++) {
            if (iIndex < vecPixelRegions.size()) {
                placeShield(iIndex, vecPixelRegions[iIndex]);
            } else {
                hideShield(iIndex);
            }
        }
    }
};

}
