--[[
 *	The MIT License (MIT)
 *
 *	Copyright (c) 2019 InoUno
 *
 *	Permission is hereby granted, free of charge, to any person obtaining a copy
 *	of this software and associated documentation files (the "Software"), to
 *	deal in the Software without restriction, including without limitation the
 *	rights to use, copy, modify, merge, publish, distribute, sublicense, and/or
 *	sell copies of the Software, and to permit persons to whom the Software is
 *	furnished to do so, subject to the following conditions:
 *
 *	The above copyright notice and this permission notice shall be included in
 *	all copies or substantial portions of the Software.
 *
 *	THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
 *	IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
 *	FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
 *	AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
 *	LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING
 *	FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER
 *	DEALINGS IN THE SOFTWARE.
]]--


--[[
TODO:   Make sure the mobType filter is correct
        General code cleanup
]]--

addon.author = 'InoUno & Tny5989'
addon.name = 'WhoGot'
addon.version = '1.0.0.1'

require('common')
local chat = require('chat')

local claims = {}
local debug = false
local pruneDead = false
local pruneUnclaimed = true

------------------------------------------------------------------------------------------------------------------------
local function DebugPrint(...)
    if (not debug) then
        return
    end
    print(...)
end

------------------------------------------------------------------------------------------------------------------------
local function GetTarget()
    local playerTarget = AshitaCore:GetMemoryManager():GetTarget()
    if (playerTarget == nil) then
        return nil
    end

    return playerTarget:GetTargetIndex(0)
end

------------------------------------------------------------------------------------------------------------------------
local function GetClaimer(claimerId)
    for i = 0x400, 0x700, 1 do
        local serverId = AshitaCore:GetMemoryManager():GetEntity():GetServerId(i)
        if (serverId == claimerId) then
            return AshitaCore:GetMemoryManager():GetEntity():GetName(i)
        end
    end
    return nil
end

------------------------------------------------------------------------------------------------------------------------
local function PrintClaimer(mobId, claimInfo)
    if (mobId == 0) then
        print(string.format('%s%s', chat.header(addon.name), chat.color2(38, 'Unknown Target')))
        return
    end

    local mobName = AshitaCore:GetMemoryManager():GetEntity():GetName(mobId)
    local claimerName = (claimInfo.claimer ~= nil and ((type(claimInfo.claimer) == 'number') and GetClaimer(claimInfo.claimer) or claimInfo.claimer) or nil)

    if (claimerName == nil) then
        print(string.format('%s%s %s %s %s %s', chat.header(addon.name), chat.color2(59, mobName), chat.color1(81, "->"), chat.color2(38, 'Unknown'), chat.color1(81, '@'), chat.color2(59, claimInfo.time)))
    else
        print(string.format('%s%s %s %s %s %s', chat.header(addon.name), chat.color2(59, mobName), chat.color1(81, "->"), chat.success(claimerName), chat.color1(81, '@'), chat.color2(59, claimInfo.time)))
    end
end

------------------------------------------------------------------------------------------------------------------------
ashita.events.register('command', 'command_cb', function(e)
    local args = e.command:args()
    if (args[1] ~= '/whogot') then
        return false
    end

    if (args[2] == 'all' or args[2] == 'a') then
        for mobId, claimer in pairs(claims) do
            PrintClaimer(mobId, claimer)
        end
        return true
    elseif (args[2] == 'debug' or args[2] == 'd') then
        debug = not debug
        print(string.format('%s%s %s %s', chat.header(addon.name), chat.color2(59, 'Debug'), chat.color1(81, "->"), (debug and chat.success('On') or chat.color2(38, 'Off'))))
        return true
    elseif (args[2] == 'clear' or args[2] == 'c') then
        claims = {}
        print(string.format('%s%s %s %s', chat.header(addon.name), chat.color2(59, 'Claims'), chat.color1(81, "->"), chat.success('Cleared')))
        return true
    elseif (args[2] == 'prune' or args[2] == 'p') then
        if (args[3] == 'dead' or args[3] == 'd') then
            pruneDead = not pruneDead
            print(string.format('%s%s %s %s', chat.header(addon.name), chat.color2(59, 'Prune Dead'), chat.color1(81, "->"), (pruneDead and chat.success('On') or chat.color2(38, 'Off'))))
        elseif (args[3] == 'unclaimed' or args[3] == 'u') then
            pruneUnclaimed = not pruneUnclaimed
            print(string.format('%s%s %s %s', chat.header(addon.name), chat.color2(59, 'Prune Unclaimed'), chat.color1(81, "->"), (pruneUnclaimed and chat.success('On') or chat.color2(38, 'Off'))))
        end
        return true
    end

    local mobId = GetTarget()
    PrintClaimer(mobId, claims[mobId])

    return true
end)

------------------------------------------------------------------------------------------------------------------------
ashita.events.register('packet_in', 'packet_in_cb', function(e)
    if (e.id == 0x0B) then
        -- zone, reset claim table
        claims = {}
        return false
    end

    if (e.id ~= 0x0E) then
        -- NPC update packet
        return false
    end

    local updateMask = struct.unpack('B', e.data_modified, 0x0A + 1)
    local hasClaimInfo = (bit.band(updateMask, 2) > 0)
    local hasClaimName = (hasClaimInfo and (bit.band(updateMask, 8) == 0))
    local mobDisappear = bit.band(updateMask, 32) > 0
    local time = os.date('[%I:%M:%S]', os.time())

    if (not hasClaimInfo and not mobDisappear) then
        return false
    end

    local mobIndex = struct.unpack('H', e.data_modified, 0x08 + 1)
    local mobType = AshitaCore:GetMemoryManager():GetEntity():GetType(mobIndex)
    if (mobDisappear and pruneDead) then
        claims[mobIndex] = nil
        return false
    end

    if (claims[mobIndex] ~= nil) then
        return false
    end

    if (mobType == 0) then
        -- Non-killable NPCs
        return false;
    end

    if (hasClaimName) then
        local claimerName = struct.unpack('s', e.data_modified, 0x34 + 1)
        if (string.len(claimerName) > 0) then
            DebugPrint(string.format('adding claimer(%s) for mob(%d) with mobType(%d) at(%s)', claimerName, mobIndex, mobType, time))
            claims[mobIndex] = { claimer = tostring(claimerName), time = time }
            return false
        end
    end

    local claimerId = struct.unpack('I', e.data_modified, 0x2C + 1)
    if (claims[mobIndex] ~= nil and claimerId == 0 and pruneUnclaimed) then
        claims[mobIndex] = nil
    elseif (claimerId > 0) then
        local claimerName = GetClaimer(claimerId)
        if (claimerName ~= nil) then
            DebugPrint(string.format('adding claimer(%s) for mob(%d) with mobType(%d) at(%s)', claimerName, mobIndex, mobType, time))
            claims[mobIndex] = { claimer = tostring(claimerName), time = time }
        else
            DebugPrint(string.format('adding claimer(%d) for mob(%d) with mobType(%d) at(%s)', claimerId, mobIndex, mobType, time))
            claims[mobIndex] = { claimer = tonumber(claimerId), time = time }
        end
    end

    return false
end)
