local function screen_base(monitor)
    local state = os.getenv("XDG_STATE_HOME") or (os.getenv("HOME") .. "/.local/state")
    local file  = io.open(state .. "/quickshell/workspaces")
    if not file then return 0 end
    local lines = {}
    for line in file:lines() do lines[#lines + 1] = line end
    file:close()
    if lines[1] ~= "per-monitor" then return 0 end
    for pos = 2, #lines do
        if monitor and lines[pos] == monitor.name then return (pos - 2) * 10 end
    end
    return 0
end

for i = 1, 10 do
    local key = i % 10
    hl.bind("SUPER + SHIFT + " .. key, function()
        hl.dispatch(hl.dsp.window.move({ workspace = screen_base(hl.get_active_monitor()) + i }))
    end)
end

hl.bind("SUPER + equal", hl.dsp.layout("colresize +conf"))
hl.bind("SUPER + minus", hl.dsp.layout("colresize -conf"))
