local printers = {}

local chat = require('chat')

------------------------------------------------------------------------------------------------------------------------
function printers.Addon(...)
    local args = { ... }
    for _, value in pairs(args) do
        print(string.format('%s%s', chat.header(addon.name), value))
    end
end

------------------------------------------------------------------------------------------------------------------------
function printers.Debug(...)
    if (not debug) then
        return
    end
    printers.Addon(...)
end

return printers