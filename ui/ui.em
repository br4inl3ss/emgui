#pragma once

#include "core/geometry.em"
#include "core/callbacks.em"
#include "core/component_value.em"
#include "core/theme.em"
#include "core/backends.em"
#include "core/perception_backends.em"
#include "core/input_state.em"
#include "core/fonts.em"

#include "svg/svg_document.em"
#include "svg/svg_path_builder.em"
#include "svg/svg_parser.em"
#include "svg/svg_rasterizer.em"
#include "svg/svg_icon.em"

#include "core/painter.em"
#include "core/keybinds.em"
#include "core/ui_context.em"

#include "components/element.em"
#include "components/keybind_button.em"
#include "components/text_edit_buffer.em"
#include "components/drag_value_box.em"
#include "components/component.em"
#include "components/context_menu.em"
#include "components/item_list_view.em"
#include "components/label.em"
#include "components/button.em"
#include "components/checkbox.em"
#include "components/slider.em"
#include "components/dropdown_base.em"
#include "components/combobox.em"
#include "components/multi_combobox.em"
#include "components/listbox.em"
#include "components/textfield.em"
#include "components/color_picker.em"

#include "containers/child.em"
#include "containers/tab.em"
#include "containers/frame.em"

#include "gui.em"

#ifndef UI_HEADLESS
#include "integration/perception_input_capture.em"
#include "integration/perception_routine.em"
#endif
