#include "../ui/ui.em"
#include "demo_icons.em"
#include "demo_interface.em"

ui::Gui g_objGui;

int64 main() {
    g_objGui.fonts().setFontFamily("Segoe UI");
    g_objGui.fonts().setFont(ui::FontRole::Title, "Segoe UI Semibold", 16.0);
    g_objGui.fonts().setFont(ui::FontRole::Heading, "Segoe UI Semibold", 14.0);
    g_objGui.setToggleKey(vk::insert);
    demo::buildDemoInterface(g_objGui);
    ui::startRendering(g_objGui);
    return 1;
}
