local blocked = false
local kickAt = 0

local function isEnforced()
    if GetConvarInt('coach4_meta_enforce', Config.EnforceMeta and 1 or 0) == 0 then
        return false
    end
    return true
end

local function showBlockUi()
    SendNUIMessage({
        action = 'show',
        title = Config.Messages.title,
        lines = {
            Config.Messages.line1,
            Config.Messages.line2,
            Config.Messages.line3,
            Config.Messages.line4,
        },
    })
end

local function hideBlockUi()
    SendNUIMessage({ action = 'hide' })
end

local function setBlocked(on)
    blocked = on
    local ped = PlayerPedId()
    if on then
        showBlockUi()
        FreezeEntityPosition(ped, true)
        kickAt = GetGameTimer() + (Config.KickAfterMs or 90000)
    else
        hideBlockUi()
        FreezeEntityPosition(ped, false)
        kickAt = 0
    end
end

local function reportMetaToServer(hasMeta)
    TriggerServerEvent('dodi_coach4:metaStatus', hasMeta)
end

local function runMetaCheck()
    local hasMeta = MetaLib.hasCarMeta()
    if not hasMeta then
        hasMeta = MetaLib.probeSpawnedCoach4IsCar(6000)
    end
    return hasMeta
end

function RunCoach4MetaGate()
    if not isEnforced() then
        reportMetaToServer(true)
        return true
    end

    local hasMeta = runMetaCheck()
    reportMetaToServer(hasMeta)

    if hasMeta then
        if blocked then
            setBlocked(false)
        end
        return true
    end

    setBlocked(true)
    return false
end

CreateThread(function()
    while not NetworkIsSessionStarted() do
        Wait(200)
    end
    Wait(3000)
    RunCoach4MetaGate()
end)

CreateThread(function()
    while true do
        Wait(Config.RecheckMs or 15000)
        if not isEnforced() then
            goto continue
        end
        if blocked then
            if RunCoach4MetaGate() then
                pcall(function()
                    TriggerEvent('dodi_notifys:Tip', 'Patch detected — restart RedM if anything still looks off.', 8000)
                end)
            end
        end
        ::continue::
    end
end)

CreateThread(function()
    while true do
        if blocked then
            DisableAllControlActions(0)
            DisableAllControlActions(1)
            DisableAllControlActions(2)
            if Config.BlockControls then
                local ped = PlayerPedId()
                DisablePlayerFiring(ped, true)
            end
            if Config.KickWithoutMeta and kickAt > 0 and GetGameTimer() >= kickAt then
                TriggerServerEvent('dodi_coach4:requestKick')
                kickAt = GetGameTimer() + 60000
            end
            Wait(0)
        else
            Wait(500)
        end
    end
end)

local function isCoach4Admin()
    local pid = PlayerId()
    return IsPlayerAceAllowed(pid, 'god')
        or IsPlayerAceAllowed(pid, 'admin')
        or IsPlayerAceAllowed(pid, 'command')
end

RegisterCommand('coach4_meta_recheck', function()
    if not isCoach4Admin() then
        return
    end
    if RunCoach4MetaGate() then
        print('^2[dodi_coach4_stream]^7 meta COACH4 OK — gate opens')
    else
        print('^1[dodi_coach4_stream]^7 no meta — install the patch + full RedM restart')
    end
    MetaLib.printMetaDebug()
end, false)

RegisterCommand('coach4_meta_debug', function()
    if not isCoach4Admin() then
        return
    end
    MetaLib.printMetaDebug()
end, false)

exports('RunMetaGate', RunCoach4MetaGate)
exports('IsMetaBlocked', function()
    return blocked
end)
