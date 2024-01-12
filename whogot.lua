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
addon.version = '1.0.0.3'

require('common')
local settings = require('settings');
local colors = require('colors')
local print = require('print')

------------------------------------------------------------------------------------------------------------------------
local defaultSettings = T {
    debug = false,
    pruneDead = false,
    pruneUnclaimed = true,
}
local whoGot = {
    claims = {},
    settings = settings.load(defaultSettings),
}

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
local function ReportClaimer(mobId, claimInfo)
    if (mobId == 0) then
        print.Addon(string.format('%s', colors.Red('Unknown Target')))
        return
    end

    local mobName = AshitaCore:GetMemoryManager():GetEntity():GetName(mobId)
    local claimerName = ((claimInfo ~= nil and claimInfo.claimer ~= nil) and ((type(claimInfo.claimer) == 'number') and GetClaimer(claimInfo.claimer) or claimInfo.claimer) or nil)

    if (claimerName == nil) then
        print.Addon(string.format('%s %s %s', colors.Beige(mobName), colors.Purple('->'), colors.Red('Unknown')))
    else
        print.Addon(string.format('%s %s %s %s %s', colors.Beige(mobName), colors.Purple('->'), colors.Green(claimerName), colors.Purple('@'), colors.Beige(claimInfo.time)))
    end
end

------------------------------------------------------------------------------------------------------------------------
ashita.events.register('command', 'command_cb', function(e)
    local args = e.command:args()
    if (args[1] ~= '/whogot') then
        return false
    end

    if (args[2] == 'all' or args[2] == 'a') then
        for mobId, claimer in pairs(whoGot.claims) do
            ReportClaimer(mobId, claimer)
        end
        return true
    elseif (args[2] == 'debug' or args[2] == 'd') then
        whoGot.settings.debug = not whoGot.settings.debug
        settings.save()
        print.Addon(string.format('%s %s %s', colors.Beige('Debug'), colors.Purple('->'), (whoGot.settings.debug and colors.Green('On') or colors.Red('Off'))))
        return true
    elseif (args[2] == 'clear' or args[2] == 'c') then
        whoGot.claims = {}
        settings.save()
        print.Addon(string.format('%s %s %s', colors.Beige('Claims'), colors.Purple('->'), colors.Green('Cleared')))
        return true
    elseif (args[2] == 'prune' or args[2] == 'p') then
        if (args[3] == 'dead' or args[3] == 'd') then
            whoGot.settings.pruneDead = not whoGot.settings.pruneDead
            settings.save()
            print.Addon(string.format('%s %s %s', colors.Beige('Prune Dead'), colors.Purple('->'), (whoGot.settings.pruneDead and colors.Green('On') or colors.Red('Off'))))
        elseif (args[3] == 'unclaimed' or args[3] == 'u') then
            whoGot.settings.pruneUnclaimed = not whoGot.settings.pruneUnclaimed
            settings.save()
            print.Addon(string.format('%s %s %s', colors.Beige('Prune Unclaimed'), colors.Purple('->'), (whoGot.settings.pruneUnclaimed and colors.Green('On') or colors.Red('Off'))))
        end
        return true
    end

    local mobId = GetTarget()
    ReportClaimer(mobId, whoGot.claims[mobId])

    return true
end)

------------------------------------------------------------------------------------------------------------------------
ashita.events.register('packet_in', 'packet_in_cb', function(e)
    if (e.id == 0x0B) then
        -- zone, reset claim table
        whoGot.claims = {}
        return false
    end

    if (e.id ~= 0x0E) then
        -- NPC update packet
        return false
    end

    local updateMask = struct.unpack('B', e.data_modified, 0x0A + 1)
    local hasClaimId = (bit.band(updateMask, 2) > 0)
    local mobDisappear = (whoGot.settings.pruneDead and (bit.band(updateMask, 32) > 0))
    local time = os.date('[%I:%M:%S]', os.time())

    if (not hasClaimId and not mobDisappear) then
        return false
    end

    local mobIndex = struct.unpack('H', e.data_modified, 0x08 + 1)
    local mobType = AshitaCore:GetMemoryManager():GetEntity():GetType(mobIndex)
    if (mobDisappear and whoGot.claims[mobIndex] ~= nil) then
        print.Debug(string.format('resetting claim for dead mob(%d) at(%s)', mobIndex, time))
        whoGot.claims[mobIndex] = nil
        return false
    end

    if (whoGot.claims[mobIndex] ~= nil) then
        return false
    end

    if (mobType ~= 2) then
        -- Non-killable NPCs
        return false;
    end

    local claimerId = struct.unpack('I', e.data_modified, 0x2C + 1)
    if (whoGot.settings.pruneUnclaimed and whoGot.claims[mobIndex] ~= nil and claimerId == 0) then
        print.Debug(string.format('resetting claim for mob(%d) at(%s)', mobIndex, time))
        whoGot.claims[mobIndex] = nil
    elseif (claimerId > 0) then
        local claimerName = GetClaimer(claimerId)
        if (claimerName ~= nil) then
            print.Debug(string.format('adding claimer(%s) for mob(%d) with mobType(%d) at(%s)', claimerName, mobIndex, mobType, time))
            whoGot.claims[mobIndex] = { claimer = tostring(claimerName), time = time }
        else
            print.Debug(string.format('adding claimer(%d) for mob(%d) with mobType(%d) at(%s)', claimerId, mobIndex, mobType, time))
            whoGot.claims[mobIndex] = { claimer = tonumber(claimerId), time = time }
        end
    end

    return false
end)
