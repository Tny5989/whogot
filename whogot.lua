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

_addon.author   = 'InoUno'
_addon.name     = 'WhoGot'
_addon.version  = '1.0.0'

require 'common'

whogot = {}
whogot.claims = { }

-------------------------------------------------
-- Misc. functionality
-------------------------------------------------

local function addonPrint(text)
    print('\31\200[\31\05' .. _addon.name .. '\31\200]\30\01 ' .. text)
end

local function getClaimerForId(id)
    if type(whogot.claims[id]) == "number" then
        local claimerName = GetNameByServerId(whogot.claims[id])
        if claimerName ~= nil then
            whogot.claims[id] = claimerName
        end
    end

    return whogot.claims[id]
end

local function printClaimerForTarget()
    local target = AshitaCore:GetDataManager():GetTarget()
    local targetId = target:GetTargetServerId()
    local targetName = target:GetTargetName()
    if target == nil or targetId == nil or targetName == nil then
        addonPrint("Invalid target.")
        return false
    end

    local claimer = getClaimerForId(targetId)
    if claimer == nil then
        addonPrint("Not able to find claimer for \31\214" .. targetName .. "\31\01.")
        return false
    end

    if type(claimer) == "number" then
        addonPrint("\31\214" .. targetName .. "\31\01 was claimed by player with ID: \31\214" .. whogot.claims[targetId] .. "\31\01")
    else
        addonPrint("\31\214" .. targetName .. "\31\01 was claimed by: \31\214" .. whogot.claims[targetId] .. "\31\01")
    end
end

function GetEntityByServerId(id)
    for x = 0, 2303 do
        -- Get the entity..
        local e = GetEntity(x);

        -- Ensure the entity is valid..
        if (e ~= nil and e.WarpPointer ~= 0) then
            if (e.ServerId == id) then
                return e;
            end
        end
    end
    return nil;
end

function GetNameByServerId(id)
    local entity = GetEntityByServerId(id)
    if entity ~= nil and entity.Name ~= nil then
        return entity.Name
    end

    return nil
end


----------------------------------------------------------------------------------------------------
-- func: command
-- desc: Event called when a command was entered.
----------------------------------------------------------------------------------------------------
ashita.register_event('command', function(command, ntype)
    local args = command:args()
    if (args[1] ~= '/whogot') then
        return false
    end

    if (args[2] == 'all') then
        for k,v in pairs(whogot.claims) do
            addonPrint(k .. ": " .. v)
        end
        return true
    end

    printClaimerForTarget()
    return true
end)

---------------------------------------------------------------------------------------------------
-- func: incoming_packet
-- desc: Called when our addon receives an incoming packet.
---------------------------------------------------------------------------------------------------
ashita.register_event('incoming_packet', function(id, size, packet)
    if id == 0x0B then -- zone, reset claim table
        whogot.claims = {}
        return false
    end

    if id ~= 0x0E then -- NPC update packet
        return false
    end

    local updateMask = struct.unpack('B', packet, 0x0A + 1)
    if updateMask ~= 6 and updateMask ~= 7 then -- is claim packets
        -- mask 3 is also claim, but I think this is the reset one
        return false
    end

    local mobId = struct.unpack('I', packet, 0x04 + 1)
    if whogot.claims[mobId] ~= nil then
        -- already claimed
        -- TODO: add a reset for when mob dies
        return false
    end

    local claimerName = struct.unpack('s', packet, 0x34 + 1)
    if string.len(claimerName) > 0 then
        whogot.claims[mobId] = claimerName
        return false
    end

    local claimerId = struct.unpack('I', packet, 0x2C + 1)

    claimerName = GetNameByServerId(claimerId)
    if claimerName ~= nil then
        whogot.claims[mobId] = claimerName
    else
        whogot.claims[mobId] = claimerId
    end

    return false
end)
