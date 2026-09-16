local playersMeta = {}
local playersReported = {}

local function isEnforced()
    return GetConvarInt('coach4_meta_enforce', 1) ~= 0
end

RegisterNetEvent('dodi_coach4:metaStatus', function(hasMeta)
    local src = source
    playersReported[src] = true
    playersMeta[src] = hasMeta == true

    if not isEnforced() then
        return
    end

    if not hasMeta then
        print(('^1[dodi_coach4_stream]^7 player %s WITHOUT the COACH4 patch'):format(src))
    end
end)

AddEventHandler('playerJoining', function()
    local src = source
    playersMeta[src] = nil
    playersReported[src] = nil
    SetTimeout(65000, function()
        if not isEnforced() then
            return
        end
        if playersReported[src] then
            return
        end
        if GetPlayerPing(src) > 0 then
            DropPlayer(src, Config.Messages.kickReason)
        end
    end)
end)

RegisterNetEvent('dodi_coach4:requestKick', function()
    local src = source
    if not isEnforced() then
        return
    end
    if playersMeta[src] then
        return
    end
    DropPlayer(src, Config.Messages.kickReason or 'Patch obrigatorio.')
end)

AddEventHandler('playerDropped', function()
    playersMeta[source] = nil
    playersReported[source] = nil
end)

-- Outros resources: so spawna carro se o client reportou meta OK
exports('PlayerHasCarMeta', function(playerId)
    return playersMeta[playerId] == true
end)

RegisterCommand('coach4_meta_kick', function(source, args)
    if source ~= 0 then
        return
    end
    local id = tonumber(args[1])
    if not id then
        print('usage: coach4_meta_kick [playerId]')
        return
    end
    DropPlayer(id, Config.Messages.kickReason)
end, true)
