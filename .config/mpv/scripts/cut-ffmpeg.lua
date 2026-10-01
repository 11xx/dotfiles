-- define function to copy timestamp to clipboard
function copy_timestamp_to_clipboard()
   local timestamp = os.date("%H:%M:%S", mp.get_property_number("time-pos")) -- get the current timestamp in the format HH:MM:SS
   mp.commandv("run", "echo", timestamp, "|", "xclip", "-selection", "clipboard") -- copy the timestamp to the clipboard using xclip
   mp.osd_message("Copied timestamp to clipboard: " .. timestamp, 2) -- display an OSD message with the copied timestamp
end

-- register key binding to copy timestamp to clipboard
mp.add_key_binding("c", "copy-timestamp-to-clipboard", copy_timestamp_to_clipboard)

-- define function to create cut command for ffmpeg
function create_cut_command()
   local start_timestamp = mp.get_property_osd("osd-playing-time") -- get the start timestamp from the OSD
   local end_timestamp = mp.get_property_osd("osd-bar") -- get the end timestamp from the OSD bar
   local input_filename = mp.get_property("filename") -- get the input filename
   local output_filename = "output.mp4" -- set the output filename
   local cut_command = string.format("ffmpeg -i '%s' -ss %s -to %s -c copy '%s'", input_filename, start_timestamp, end_timestamp, output_filename) -- format the cut command with the input filename, start and end timestamps, and output filename
   mp.commandv("run", "echo", cut_command, "|", "xclip", "-selection", "clipboard") -- copy the cut command to the clipboard using xclip
   mp.osd_message("Copied cut command to clipboard:\n" .. cut_command, 5) -- display an OSD message with the copied cut command
end

-- register key binding to create cut command for ffmpeg
mp.add_key_binding("C", "create-cut-command-for-ffmpeg", create_cut_command)
