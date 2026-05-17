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
