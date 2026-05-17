-- -*- mode: lua; -*-

colorBlack = "rgb(000000)"
colorTransparent = "rgba(ff000000)"
colorNeronPink = "rgb(ff77cf)"
colorYtOrange = "rgb(ef6c00)"

function exec_once(cmd)
    hl.on("hyprland.start", function()
        hl.exec_cmd(cmd)
    end)
end

function reset_submap()
    return hl.dispatch(hl.dsp.submap("reset"))
end

local suppressed_leaf_presses = {}
local keymap_root = { children = {}, path = {}, submap = nil, has_reset_binds = false }
local keymap_config = { submap_timeout_ms = nil }
local keymap_submap_generation = 0

local function key_id(keys)
    return string.lower((keys:gsub("%s+", "")))
end

local function copy_flags(flags)
    local copied = {}
    for key, value in pairs(flags or {}) do
        copied[key] = value
    end
    return copied
end

local function dispatch_action(dispatcher)
    if type(dispatcher) == "function" then
        return dispatcher()
    end
    return hl.dispatch(dispatcher)
end

local function bind_raw(keys, callback, flags)
    hl.bind(keys, callback, flags or {})
end

local function full_reset()
    keymap_submap_generation = keymap_submap_generation + 1
    reset_submap()
end

function bind(keys, dispatcher, flags)
    local id = key_id(keys)
    bind_raw(keys, function()
        if suppressed_leaf_presses[id] then
            suppressed_leaf_presses[id] = nil
            return
        end
        full_reset()
        local result = dispatch_action(dispatcher)
        full_reset()
        return result
    end, flags or {})
end

function enter_submap(name)
    return hl.dispatch(hl.dsp.submap(name))
end

function bind_submap(keys, name, flags)
    local bind_flags = copy_flags(flags)

    bind_raw(keys, function()
        local id = key_id(keys)
        suppressed_leaf_presses[id] = true

        reset_submap()
        keymap_submap_generation = keymap_submap_generation + 1
        local timeout_generation = keymap_submap_generation
        local result = enter_submap(name)
        if keymap_config.submap_timeout_ms ~= nil then
            hl.timer(function()
                if keymap_submap_generation == timeout_generation then
                    full_reset()
                end
            end, { timeout = keymap_config.submap_timeout_ms, type = "oneshot" })
        end
        return result
    end, bind_flags)
end

function keymap_configure(config)
    for key, value in pairs(config or {}) do
        keymap_config[key] = value
    end
end

local function normalize_key_name(key)
    local aliases = {
        [" "] = "space",
        ["RET"] = "return",
        ["RETURN"] = "return",
        ["ESC"] = "escape",
        ["ESCAPE"] = "escape",
        ["SPC"] = "space",
        ["SPACE"] = "space",
    }
    local upper = string.upper(key)
    if aliases[upper] then
        return aliases[upper]
    end
    if #key == 1 and key:match("%a") then
        return upper
    end
    return key
end

local function parse_emacs_modifier(modifier)
    if modifier == "s" then
        return "SUPER"
    elseif modifier == "C" then
        return "CTRL"
    elseif modifier == "M" then
        return "ALT"
    elseif modifier == "S" then
        return "SHIFT"
    end
    return nil
end

local function parse_emacs_chord(chord)
    if chord:find("%+") then
        return chord
    end

    local parts = {}
    for part in chord:gmatch("[^-]+") do
        table.insert(parts, part)
    end

    if #parts == 0 then
        error("keymap_set: invalid chord " .. chord)
    end
    if #parts == 1 then
        return normalize_key_name(parts[1])
    end

    local seen_mods = {}
    for index = 1, #parts - 1 do
        local parsed = parse_emacs_modifier(parts[index])
        if parsed == nil then
            return chord
        end
        seen_mods[parts[index]] = parsed
    end

    local mods = {}
    for _, modifier in ipairs({ "C", "M", "s", "S" }) do
        if seen_mods[modifier] ~= nil then
            table.insert(mods, seen_mods[modifier])
        end
    end
    table.insert(mods, normalize_key_name(parts[#parts]))
    return table.concat(mods, " + ")
end

local function parse_key_sequence(sequence)
    if type(sequence) == "table" then
        local chords = {}
        for _, chord in ipairs(sequence) do
            table.insert(chords, parse_emacs_chord(chord))
        end
        return chords
    end

    local chords = {}
    for chord in sequence:gmatch("%S+") do
        table.insert(chords, parse_emacs_chord(chord))
    end
    return chords
end

local function submap_name(path)
    local name = table.concat(path, "__")
    name = name:gsub("[^%w]+", "_"):gsub("^_+", ""):gsub("_+$", "")
    return "keymap_" .. name
end

local function in_submap(node, callback)
    if node.submap == nil then
        callback()
    else
        hl.define_submap(node.submap, callback)
    end
end

local function ensure_reset_binds(node)
    if node.submap == nil or node.has_reset_binds then
        return
    end

    hl.define_submap(node.submap, function()
        bind_raw("escape", function()
            full_reset()
        end)
        bind_raw("catchall", function()
            full_reset()
        end)
    end)
    node.has_reset_binds = true
end

local function ensure_prefix(parent, chord)
    local child = parent.children[chord]
    if child ~= nil then
        return child
    end

    local path = {}
    for _, item in ipairs(parent.path) do
        table.insert(path, item)
    end
    table.insert(path, chord)

    child = { children = {}, path = path, submap = submap_name(path), has_reset_binds = false }
    parent.children[chord] = child

    in_submap(parent, function()
        bind_submap(chord, child.submap)
    end)
    ensure_reset_binds(child)

    return child
end

function keymap_set(sequence, dispatcher, flags)
    local chords = parse_key_sequence(sequence)
    if #chords == 0 then
        error("keymap_set: empty key sequence")
    end

    local node = keymap_root
    for index, chord in ipairs(chords) do
        if index < #chords then
            local child = node.children[chord]
            if child ~= nil and child.action ~= nil then
                error("keymap_set: " .. table.concat(chords, " ") .. " conflicts with final binding " .. table.concat(child.path, " "))
            end
            node = ensure_prefix(node, chord)
        else
            local existing = node.children[chord]
            if existing ~= nil and next(existing.children) ~= nil then
                error("keymap_set: " .. table.concat(chords, " ") .. " conflicts with prefix binding " .. table.concat(existing.path, " "))
            end
            if existing ~= nil and existing.action ~= nil then
                error("keymap_set: duplicate binding " .. table.concat(chords, " "))
            end

            local path = {}
            for _, item in ipairs(node.path) do
                table.insert(path, item)
            end
            table.insert(path, chord)

            local leaf = existing or { children = {}, path = path, submap = nil, has_reset_binds = false }
            leaf.path = path
            leaf.action = dispatcher
            node.children[chord] = leaf

            in_submap(node, function()
                bind(chord, dispatcher, flags)
            end)
        end
    end
end

function keymap_exec(sequence, cmd, flags)
    local bind_flags = flags or {}
    local rules = bind_flags.rules
    if rules ~= nil then
        bind_flags = {}
        for key, value in pairs(flags) do
            if key ~= "rules" then
                bind_flags[key] = value
            end
        end
    end
    keymap_set(sequence, function()
        return hl.exec_cmd(cmd, rules)
    end, bind_flags)
end

function bind_exec(keys, cmd, flags)
    local bind_flags = flags or {}
    local rules = bind_flags.rules
    if rules ~= nil then
        bind_flags = {}
        for key, value in pairs(flags) do
            if key ~= "rules" then
                bind_flags[key] = value
            end
        end
    end
    bind(keys, hl.dsp.exec_cmd(cmd, rules), bind_flags)
end

function window_rule(match, effects)
    local rule = { match = match }
    for key, value in pairs(effects) do
        rule[key] = value
    end
    hl.window_rule(rule)
end

function layer_rule(namespace, effects)
    local rule = { match = { namespace = namespace } }
    for key, value in pairs(effects) do
        rule[key] = value
    end
    hl.layer_rule(rule)
end
