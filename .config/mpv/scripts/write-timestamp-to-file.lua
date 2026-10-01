local mp = require "mp"
local utils = require "mp.utils"

function write_timestamp()
    local file_path = mp.get_property("path")
    local timestamp = mp.get_property_osd("playback-time/full")
    local filename = mp.get_property("media-title")
    if filename == nil or filename == "" then
        filename = utils.split_path(file_path).filename
    end
    local output_file = io.open(file_path..".timestamps", "a")
    output_file:write("["..filename.."] "..timestamp.."\n")
    output_file:close()
    mp.osd_message("Timestamp saved to file")
end

mp.add_key_binding("Ctrl+t", "write_timestamp", write_timestamp)
