#pragma once

namespace demo {

struct DemoInterface {
    ui::Frame* pFrameMain = null;
    ui::Frame* pFrameStatus = null;
    ui::Tab* pTabCombat = null;
    ui::Tab* pTabVisuals = null;
    ui::Tab* pTabSettings = null;
    ui::Tab* pTabAbout = null;

    ui::Checkbox* pCheckboxAimEnabled = null;
    ui::SliderFloat* pSliderFloatSmoothing = null;
    ui::SliderInt* pSliderIntFieldOfView = null;
    ui::Combobox* pComboboxTargetBone = null;
    ui::MultiCombobox* pMultiComboboxTargets = null;
    ui::Checkbox* pCheckboxTriggerEnabled = null;
    ui::SliderInt* pSliderIntTriggerDelay = null;
    ui::Button* pButtonResetDefaults = null;

    ui::Checkbox* pCheckboxBoxes = null;
    ui::Combobox* pComboboxBoxStyle = null;
    ui::ColorPicker* pColorPickerBox = null;
    ui::ColorPicker* pColorPickerSelection = null;
    ui::SliderFloat* pSliderFloatBrightness = null;
    ui::Checkbox* pCheckboxNightMode = null;
    ui::Button* pButtonAccentEmerald = null;
    ui::Checkbox* pCheckboxLightTheme = null;
    ui::Button* pButtonDanger = null;

    ui::Textfield* pTextfieldUsername = null;
    ui::Textfield* pTextfieldNotes = null;
    ui::Button* pButtonSave = null;
    ui::Label* pLabelDocumentation = null;
    ui::Combobox* pComboboxFont = null;
    ui::Combobox* pComboboxScale = null;
    ui::Listbox* pListboxEventLog = null;

    ui::Keybind* pKeybindPanic = null;
};

ui::Listbox* g_pListboxEventLog = null;
ui::Label* g_pLabelLastEvent = null;
ui::Label* g_pLabelAimState = null;
ui::Label* g_pLabelTriggerState = null;
ui::Label* g_pLabelWindowState = null;
int64 g_iEventCount = 0;

void recordEvent(const std::string& strEvent) {
    g_iEventCount += 1;
    println("[demo] " + strEvent);
    if (g_pLabelLastEvent != null) { g_pLabelLastEvent->setText(strEvent); }
    if (g_pListboxEventLog == null) { return; }
    std::vector<std::string> vecEvents = g_pListboxEventLog->items();
    vecEvents.insert(vecEvents.begin(), std::to_string(g_iEventCount) + ". " + strEvent);
    if (vecEvents.size() > 100) { vecEvents.pop_back(); }
    g_pListboxEventLog->setItems(vecEvents);
}

std::string onOff(bool bValue) { return bValue ? "on" : "off"; }

void buildCombatTab(ui::Frame* pFrameMain, DemoInterface& objDemoInterface) {
    ui::Tab* pTabCombat = pFrameMain->addTab("Combat", icons::strCrosshair)->onSelect([]() { recordEvent("Tab selected: Combat"); });
    objDemoInterface.pTabCombat = pTabCombat;

    ui::Child* pChildAimAssist = pTabCombat->addChild("Aim assist");
    objDemoInterface.pCheckboxAimEnabled = pChildAimAssist->addCheckbox("Enabled")
        ->onChange([](bool bValue) { recordEvent("Aim assist " + onOff(bValue)); });
    objDemoInterface.pCheckboxAimEnabled->bindKey(vk::f, ui::KeybindMode::OnToggle)->onStateChange([](bool bActive) {
        if (g_pLabelAimState != null) { g_pLabelAimState->setText(std::string("Aim assist keybind: ") + (bActive ? "active" : "inactive")); }
        recordEvent(std::string("Aim keybind ") + (bActive ? "activated" : "deactivated"));
    });
    objDemoInterface.pSliderFloatSmoothing = pChildAimAssist->addSliderFloat("Smoothing", 0.0, 1.0, 0.35)
        ->onChange([](float64 fValue) { recordEvent(std::format("Smoothing = {:.2f}", fValue)); });
    objDemoInterface.pSliderIntFieldOfView = pChildAimAssist->addSliderInt("Field of view", 1, 180, 60)->setSuffix(" deg")
        ->onChange([](int64 iValue) { recordEvent("Field of view = " + std::to_string(iValue)); });
    objDemoInterface.pComboboxTargetBone = pChildAimAssist->addCombobox("Target bone", { "Head", "Neck", "Chest", "Pelvis" })
        ->onChange([](int64 iIndex, const std::string& strItem) { recordEvent("Target bone = " + strItem); });
    objDemoInterface.pMultiComboboxTargets = pChildAimAssist->addMultiCombobox("Targets", { "Players", "Bots", "Teammates", "Vehicles" })
        ->onChange([](int64 iIndex, const std::string& strItem, bool bSelected) { recordEvent("Target " + strItem + " " + onOff(bSelected)); });

    ui::Child* pChildTriggerbot = pTabCombat->addChild("Triggerbot");
    objDemoInterface.pCheckboxTriggerEnabled = pChildTriggerbot->addCheckbox("Enabled", true)
        ->onChange([](bool bValue) { recordEvent("Triggerbot " + onOff(bValue)); });
    objDemoInterface.pCheckboxTriggerEnabled->bindKey(vk::xbutton1, ui::KeybindMode::OffHotkey)->onStateChange([](bool bActive) {
        if (g_pLabelTriggerState != null) { g_pLabelTriggerState->setText(std::string("Triggerbot: ") + (bActive ? "armed" : "paused while held")); }
    });
    objDemoInterface.pSliderIntTriggerDelay = pChildTriggerbot->addSliderInt("Reaction delay", 0, 500, 120)->setSuffix(" ms")
        ->onChange([](int64 iValue) { recordEvent("Reaction delay = " + std::to_string(iValue) + " ms"); });

    ui::SliderFloat* pSliderFloatSmoothing = objDemoInterface.pSliderFloatSmoothing;
    ui::SliderInt* pSliderIntFieldOfView = objDemoInterface.pSliderIntFieldOfView;
    ui::SliderInt* pSliderIntTriggerDelay = objDemoInterface.pSliderIntTriggerDelay;
    objDemoInterface.pButtonResetDefaults = pChildTriggerbot->addButton("Reset combat defaults")->onClick([pSliderFloatSmoothing, pSliderIntFieldOfView, pSliderIntTriggerDelay]() {
        pSliderFloatSmoothing->setValue(0.35);
        pSliderIntFieldOfView->setValue(60);
        pSliderIntTriggerDelay->setValue(120);
        recordEvent("Combat settings reset");
    });
}

void buildVisualsTab(ui::Gui& objGui, ui::Frame* pFrameMain, DemoInterface& objDemoInterface) {
    ui::Gui* pGui = &objGui;
    ui::Tab* pTabVisuals = pFrameMain->addTab("Visuals", icons::strEye)->onSelect([]() { recordEvent("Tab selected: Visuals"); });
    objDemoInterface.pTabVisuals = pTabVisuals;

    ui::Child* pChildPlayers = pTabVisuals->addChild("Players");
    objDemoInterface.pCheckboxBoxes = pChildPlayers->addCheckbox("Bounding boxes", true)->onChange([](bool bValue) { recordEvent("Boxes " + onOff(bValue)); });
    pChildPlayers->addCheckbox("Names")->onChange([](bool bValue) { recordEvent("Names " + onOff(bValue)); });
    pChildPlayers->addCheckbox("Health bars", true)->onChange([](bool bValue) { recordEvent("Health bars " + onOff(bValue)); });
    objDemoInterface.pComboboxBoxStyle = pChildPlayers->addCombobox("Box style", { "Full", "Corners", "Rounded", "3D" }, 1)
        ->onChange([](int64 iIndex, const std::string& strItem) { recordEvent("Box style = " + strItem); });
    objDemoInterface.pColorPickerBox = pChildPlayers->addColorPicker("Box color", color(255, 196, 0, 200))
        ->onChange([](color objColorValue) { recordEvent("Box color = " + ui::ComponentValue::colorToHex(objColorValue)); });

    ui::Child* pChildWorld = pTabVisuals->addChild("World");
    objDemoInterface.pSliderFloatBrightness = pChildWorld->addSliderFloat("Brightness", 0.0, 2.0, 1.0)->setDecimals(1)
        ->onChange([](float64 fValue) { recordEvent(std::format("Brightness = {:.1f}", fValue)); });
    objDemoInterface.pCheckboxNightMode = pChildWorld->addCheckbox("Night mode")->onChange([](bool bValue) { recordEvent("Night mode " + onOff(bValue)); });
    objDemoInterface.pCheckboxNightMode->bindKey(0, ui::KeybindMode::AlwaysOn);

    ui::Child* pChildColors = pTabVisuals->addChild("Selection color");
    objDemoInterface.pColorPickerSelection = pChildColors->addColorPicker("Custom", pGui->theme().colorOf(ui::ColorRole::SelectionFill))
        ->setAlphaEditable(false)
        ->onChange([pGui](color objColorValue) { pGui->theme().setAccent(objColorValue); });
    pChildColors->addButton("egui blue")->onClick([pGui]() {
        pGui->theme().setAccent(color(0, 92, 128, 255));
        recordEvent("Selection color: egui blue");
    });
    objDemoInterface.pButtonAccentEmerald = pChildColors->addButton("Emerald")->onClick([pGui]() {
        pGui->theme().setAccent(color(24, 110, 78, 255));
        recordEvent("Selection color: emerald");
    });
    pChildColors->addButton("Rose")->onClick([pGui]() {
        pGui->theme().setAccent(color(132, 36, 66, 255));
        recordEvent("Selection color: rose");
    });
    objDemoInterface.pCheckboxLightTheme = pChildColors->addCheckbox("Light theme")->onChange([pGui](bool bLight) {
        pGui->setTheme(bLight ? ui::Theme::light() : ui::Theme::dark());
        recordEvent(std::string("Theme: ") + (bLight ? "light" : "dark"));
    });

    ui::Child* pChildOverrides = pTabVisuals->addChild("Per-component colors");
    objDemoInterface.pButtonDanger = pChildOverrides->addButton("Danger zone")->onClick([]() { recordEvent("Danger button pressed"); });
    objDemoInterface.pButtonDanger->setColor(ui::ColorRole::WidgetFill, color(96, 30, 42, 255));
    objDemoInterface.pButtonDanger->setColor(ui::ColorRole::WidgetHoveredFill, color(128, 38, 54, 255));
    objDemoInterface.pButtonDanger->setColor(ui::ColorRole::WidgetHoveredStroke, color(230, 110, 125, 255));
    objDemoInterface.pButtonDanger->setColor(ui::ColorRole::WidgetText, color(255, 205, 210, 255));
    ui::Checkbox* pCheckboxGold = pChildOverrides->addCheckbox("Gold checkbox", true);
    pCheckboxGold->setColor(ui::ColorRole::WidgetText, color(230, 176, 52, 255));
    pCheckboxGold->setColor(ui::ColorRole::WidgetHoveredText, color(250, 204, 96, 255));
    pChildOverrides->setColor(ui::ColorRole::GroupStroke, color(120, 95, 40, 255));
}

void buildSettingsTab(ui::Gui& objGui, ui::Frame* pFrameMain, DemoInterface& objDemoInterface) {
    ui::Gui* pGui = &objGui;
    ui::Tab* pTabSettings = pFrameMain->addTab("Settings", icons::strSettings)->onSelect([]() { recordEvent("Tab selected: Settings"); });
    objDemoInterface.pTabSettings = pTabSettings;

    ui::Child* pChildProfile = pTabSettings->addChild("Profile");
    objDemoInterface.pTextfieldUsername = pChildProfile->addTextfield("Username", "Enter a name...")->setMaximumLength(24)
        ->onChange([](const std::string& strText) { recordEvent("Username typed: " + strText); })
        ->onSubmit([](const std::string& strText) { recordEvent("Username submitted: " + strText); });
    objDemoInterface.pTextfieldNotes = pChildProfile->addTextfield("Notes", "Anything you like")
        ->onSubmit([](const std::string& strText) { recordEvent("Notes submitted: " + strText); });
    ui::Textfield* pTextfieldUsername = objDemoInterface.pTextfieldUsername;
    objDemoInterface.pButtonSave = pChildProfile->addButton("Save profile")->onClick([pTextfieldUsername]() {
        recordEvent("Profile saved for '" + pTextfieldUsername->text() + "'");
    });
    objDemoInterface.pTextfieldNotes->setTabOrder(1);
    objDemoInterface.pTextfieldUsername->setTabOrder(2);
    objDemoInterface.pButtonSave->setTabOrder(3);
    objDemoInterface.pLabelDocumentation = pChildProfile->addLabel("Click me: labels can react too")->onClick([]() { recordEvent("Label clicked"); });

    ui::Child* pChildInterface = pTabSettings->addChild("Interface");
    objDemoInterface.pComboboxFont = pChildInterface->addCombobox("Font family", { "Segoe UI", "Bahnschrift", "Consolas", "Missing Font Family" })
        ->onChange([pGui](int64 iIndex, const std::string& strItem) {
            pGui->fonts().setFontFamily(strItem);
            recordEvent("Font family = " + strItem);
        });
    objDemoInterface.pComboboxScale = pChildInterface->addCombobox("Interface scale", { "75%", "100%", "125%", "150%", "200%" }, 1)
        ->onChange([pGui](int64 iIndex, const std::string& strItem) {
            std::vector<float64> vecScales = { 0.75, 1.0, 1.25, 1.5, 2.0 };
            pGui->setScale(vecScales[iIndex]);
            recordEvent("Interface scale = " + strItem);
        });
    pChildInterface->addLabel("Insert toggles the menu")->setColor(ui::ColorRole::TextNormal, color(100, 100, 100, 255));

    ui::Child* pChildEventLog = pTabSettings->addChild("Event log");
    objDemoInterface.pListboxEventLog = pChildEventLog->addListbox("", {})->setVisibleRows(7)
        ->onSelect([](int64 iIndex, const std::string& strItem) { println("[demo] inspecting event " + strItem); });
    g_pListboxEventLog = objDemoInterface.pListboxEventLog;

    ui::Child* pChildPanic = pTabSettings->addChild("Standalone keybind");
    pChildPanic->addLabel("End toggles a panic keybind that is");
    pChildPanic->addLabel("not attached to any component.");
    objDemoInterface.pKeybindPanic = pGui->addKeybind("Panic", vk::end, ui::KeybindMode::OnToggle)->onStateChange([](bool bActive) {
        recordEvent(std::string("Panic mode ") + (bActive ? "engaged" : "released"));
    });
}

void buildAboutTab(ui::Frame* pFrameMain, DemoInterface& objDemoInterface) {
    objDemoInterface.pTabAbout = pFrameMain->addTab("About", icons::strInfo)->setIconOnly(true)->onSelect([]() { recordEvent("Tab selected: About"); });
    ui::Child* pChildAbout = objDemoInterface.pTabAbout->addChild("Neverland UI");
    pChildAbout->addLabel("A component framework written in Enma.");
    pChildAbout->addLabel("Left-click a key box to rebind it,");
    pChildAbout->addLabel("right-click it to change its mode.");
    pChildAbout->addLabel("Ctrl+click a slider to type a value.");
    pChildAbout->addLabel("Right-click a component to copy/paste.");
    pChildAbout->addLabel("Tab / Shift+Tab move the keyboard focus.");
    ui::Child* pChildCredits = objDemoInterface.pTabAbout->addChild("Credits");
    pChildCredits->addLabel("Tab icons: Lucide (ISC license)");
}

void buildStatusFrame(ui::Gui& objGui, DemoInterface& objDemoInterface) {
    objDemoInterface.pFrameStatus = objGui.addFrame("Live status", vec2(780.0, 100.0), vec2(400.0, 190.0));
    ui::Tab* pTabStatus = objDemoInterface.pFrameStatus->addTab("Status");
    ui::Child* pChildKeybinds = pTabStatus->addChild("Keybinds");
    g_pLabelAimState = pChildKeybinds->addLabel("Aim assist keybind: inactive");
    g_pLabelTriggerState = pChildKeybinds->addLabel("Triggerbot: armed");
    ui::Child* pChildEvents = pTabStatus->addChild("Last event");
    g_pLabelLastEvent = pChildEvents->addLabel("Nothing happened yet");
    g_pLabelWindowState = pChildEvents->addLabel("Main window untouched");
}

DemoInterface buildDemoInterface(ui::Gui& objGui) {
    DemoInterface objDemoInterface;
    objDemoInterface.pFrameMain = objGui.addFrame("Neverland", vec2(100.0, 100.0), vec2(680.0, 500.0));
    objDemoInterface.pFrameMain
        ->onMove([](vec2 objVec2Position) {
            if (g_pLabelWindowState != null) { g_pLabelWindowState->setText(std::format("Moved to {:.0f}, {:.0f}", objVec2Position.x, objVec2Position.y)); }
        })
        ->onResize([](vec2 objVec2Size) {
            if (g_pLabelWindowState != null) { g_pLabelWindowState->setText(std::format("Resized to {:.0f} x {:.0f}", objVec2Size.x, objVec2Size.y)); }
        });
    buildCombatTab(objDemoInterface.pFrameMain, objDemoInterface);
    buildVisualsTab(objGui, objDemoInterface.pFrameMain, objDemoInterface);
    buildSettingsTab(objGui, objDemoInterface.pFrameMain, objDemoInterface);
    buildAboutTab(objDemoInterface.pFrameMain, objDemoInterface);
    buildStatusFrame(objGui, objDemoInterface);
    objGui.onVisibilityChange([](bool bVisible) { println(std::string("[demo] menu ") + (bVisible ? "shown" : "hidden")); });
    return objDemoInterface;
}

}
