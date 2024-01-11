local colors = {}

local chat = require('chat')

------------------------------------------------------------------------------------------------------------------------
function colors.Purple(s)
    return chat.color1(81, s)
end

------------------------------------------------------------------------------------------------------------------------
function colors.Green(s)
    return chat.success(s)
end

------------------------------------------------------------------------------------------------------------------------
function colors.Beige(s)
    return chat.color2(59, s)
end

------------------------------------------------------------------------------------------------------------------------
function colors.Red(s)
    return chat.color2(38, s)
end

return colors
