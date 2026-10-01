local options = {
    font_size = 22,
    position_x = 98,  -- percentage from left
    position_y = 98,  -- percentage from top
    border_size = 1.0,
    font_name = "sans-serif",
    bold = false,
    italic = false,
    prefix_text = "path: "
}

-- Read options from config file if it exists
opt = require "mp.options"
opt.read_options(options, "toggle-fullpath")
-- mp.get_script_name())

local show_path = false
local overlay = mp.create_osd_overlay("ass-events")

-- Function to format the ASS text with advanced styling
local function format_text(text)
    -- Use \an3 for bottom-right alignment
    -- This way the text grows left and up from the anchor point
    return string.format(
        "{\\an3\\fs%d\\bord%f\\b%d\\i%d\\fn%s}%s",
        options.font_size,
        options.border_size,
        options.bold and 1 or 0,
        options.italic and 1 or 0,
        options.font_name,
        text or ""
    )
end

-- Function to update the displayed path
local function update_path()
    if show_path then
        local path = mp.get_property("path", "N/A")
        -- Use margins instead of absolute positioning
        overlay.res_x = mp.get_property_number("osd-width", 1280)
        overlay.res_y = mp.get_property_number("osd-height", 720)
        -- Set margins based on percentages
        overlay.data = string.format(
            "{\\pos(%d,%d)}",
            overlay.res_x * options.position_x / 100,
            overlay.res_y * options.position_y / 100
        ) .. format_text(options.prefix_text .. path)
        overlay:update()
    end
end

-- Function to toggle path display
local function toggle_path_display()
    show_path = not show_path
    if show_path then
        update_path()
    else
        overlay.data = ""
        overlay:update()
    end
end

-- Update when file changes
mp.observe_property("path", "string", update_path)

-- Update when screen size changes
mp.observe_property("osd-width", "number", update_path)
mp.observe_property("osd-height", "number", update_path)

-- Expose the toggle function for manual binding
mp.register_script_message("toggle-fullpath", toggle_path_display)

-- Remove overlay when mpv exits
mp.register_event("shutdown", function()
    overlay:remove()
end)
