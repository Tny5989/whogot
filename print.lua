local printers = {}

local chat = require('chat')

printers.settings = { debug = false, }

------------------------------------------------------------------------------------------------------------------------
function printers.Addon(...)
    local args = { ... }
    for _, value in pairs(args) do
        print(string.format('%s%s', chat.header(addon.name), value))
    end
end

------------------------------------------------------------------------------------------------------------------------
function printers.Debug(...)
    if (not printers.settings.debug) then
        return
    end
    printers.Addon(...)
end

return printers