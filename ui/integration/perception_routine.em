#pragma once

namespace ui {
    void renderGuiEveryFrame(int64 iGuiAddress) {
        reinterpret_cast<Gui*>(iGuiAddress)->renderFrame();
    }

    int64 startRendering(Gui& objGui) {
        objGui.setInputCapture(std::make_unique<PerceptionInputCapture>());
        return register_routine(reinterpret_cast<int64>(renderGuiEveryFrame), reinterpret_cast<int64>(&objGui));
    }
}
