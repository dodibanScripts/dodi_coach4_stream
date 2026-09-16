MetaLib = {}

local NATIVE_IS_DRAFT_MODEL = 0xA273060E04036CF6
local NATIVE_CREATE_VEHICLE = 0xAF35D0D2583051B0
local NATIVE_CREATE_VEHICLE_LEGACY = 0xDD958B5A23777EA3
local NATIVE_MODIFY_TOP_SPEED = 0x35AD938C74CACD6A -- RDR3 (nao usar gta_hash 0x93A399...)
local NATIVE_DRAFT_DESIRED_SPEED = 0x0C3F0F7F92CA847C
local NATIVE_EST_MAX_SPEED = 0xFE52F34491529F0B -- RDR3 (nao usar gta_hash 0x53AF99...)
local COACH4_FALLBACK_EST_MAX = 11.5
local NATIVE_GET_ENTITY_ROLL = 0xBF966536FA8B6879
local NATIVE_SET_VEHICLE_ON_GROUND = 0x7263332501E07F52
local NATIVE_APPLY_FORCE = 0xF15E8F5D333F09C4
local CONTROL_HANDBRAKE = `INPUT_JUMP` -- SPACEBAR 0xD9D0E1C0
local COACH4 = `coach4`

local profileKeeper = {
    active = false,
    veh = 0,
    profileId = 'stock',
    overrides = nil,
    lastMult = nil,
    lastRollFixMs = 0,
}

local function mergeProfile(profileId, overrides)
    local base = Config.CarProfiles[profileId or 'stock']
    if not base then
        return nil
    end
    if type(overrides) ~= 'table' then
        return base
    end

    local merged = {}
    for k, v in pairs(base) do
        merged[k] = v
    end
    for k, v in pairs(overrides) do
        merged[k] = v
    end
    return merged
end

function MetaLib.isCoach4DraftModel()
    return Citizen.InvokeNative(NATIVE_IS_DRAFT_MODEL, COACH4, Citizen.ResultAsInteger()) == 1
end

function MetaLib.isEntityCarType(veh)
    if not veh or veh == 0 or not DoesEntityExist(veh) then
        return false
    end
    if GetEntityModel(veh) ~= COACH4 then
        return false
    end
    if IsDraftVehicle then
        return not IsDraftVehicle(veh)
    end
    return not MetaLib.isCoach4DraftModel()
end

function MetaLib.hasCarMeta()
    if GetConvarInt('coach4_meta_force_ok', 0) == 1 then
        return true
    end
    if not MetaLib.isCoach4DraftModel() then
        return true
    end
    local inVeh = GetVehiclePedIsIn(PlayerPedId(), false)
    if MetaLib.isEntityCarType(inVeh) then
        return true
    end
    return MetaLib.probeSpawnedCoach4IsCar(6000)
end

function MetaLib.probeSpawnedCoach4IsCar(timeoutMs)
    timeoutMs = timeoutMs or 6000
    RequestModel(COACH4)
    local t0 = GetGameTimer()
    while not HasModelLoaded(COACH4) and GetGameTimer() - t0 < timeoutMs do
        Wait(25)
    end
    if not HasModelLoaded(COACH4) then
        return false
    end

    local c = GetEntityCoords(PlayerPedId())
    local function tryCreate(hash)
        return Citizen.InvokeNative(
            hash, COACH4, c.x, c.y, c.z - 40.0, 0.0,
            false, true, true, false,
            Citizen.ResultAsInteger()
        )
    end
    local veh = tryCreate(NATIVE_CREATE_VEHICLE)
    if not veh or veh == 0 then
        veh = tryCreate(NATIVE_CREATE_VEHICLE_LEGACY)
    end

    local isCar = false
    if veh and veh ~= 0 then
        local waitEnd = GetGameTimer() + 800
        while not DoesEntityExist(veh) and GetGameTimer() < waitEnd do
            Wait(25)
        end
        if DoesEntityExist(veh) then
            Wait(150)
            isCar = MetaLib.isEntityCarType(veh)
        end
        SetEntityAsMissionEntity(veh, true, true)
        DeleteVehicle(veh)
    end
    SetModelAsNoLongerNeeded(COACH4)
    return isCar
end

local function getEstimatedMaxSpeed(veh)
    local ok, spd = pcall(function()
        return Citizen.InvokeNative(NATIVE_EST_MAX_SPEED, veh, Citizen.ResultAsFloat())
    end)
    if ok and spd then
        return spd
    end
    return 0.0
end

local function modifyVehicleTopSpeed(veh, mult)
    mult = mult + 0.0
    if ModifyVehicleTopSpeed then
        pcall(function()
            ModifyVehicleTopSpeed(veh, 1.0)
            ModifyVehicleTopSpeed(veh, mult)
        end)
        return
    end
    pcall(function()
        Citizen.InvokeNative(NATIVE_MODIFY_TOP_SPEED, veh, 1.0)
        Citizen.InvokeNative(NATIVE_MODIFY_TOP_SPEED, veh, mult)
    end)
end

local function applyTopSpeedMult(veh, mult)
    mult = mult + 0.0
    if profileKeeper.lastMult and math.abs(profileKeeper.lastMult - mult) < 0.015 then
        return
    end
    profileKeeper.lastMult = mult
    modifyVehicleTopSpeed(veh, mult)
end

local function resolveMaxSpeedMps(veh, profile)
    if profile.maxSpeedMps then
        return profile.maxSpeedMps + 0.0
    end
    local est = getEstimatedMaxSpeed(veh)
    if est <= 0.05 then
        est = COACH4_FALLBACK_EST_MAX
    end
    return est * (profile.topSpeedMult or 1.0)
end

local function clampVehicleSpeed(veh, maxMps)
    maxMps = maxMps + 0.0
    if maxMps <= 0.0 then
        return
    end

    local speed = GetEntitySpeed(veh)
    if speed <= maxMps + 0.08 then
        return
    end

    local vel = GetEntityVelocity(veh)
    local scale = maxMps / math.max(speed, 0.01)
    SetEntityVelocity(veh, vel.x * scale, vel.y * scale, vel.z * scale)
end

local function isPlayerSteeringVehicle()
    return IsControlPressed(0, `INPUT_VEH_CAR_TURN_LEFT_ONLY`)
        or IsControlPressed(0, `INPUT_VEH_CAR_TURN_RIGHT_ONLY`)
        or IsControlPressed(0, `INPUT_VEH_DRAFT_TURN_LEFT_ONLY`)
        or IsControlPressed(0, `INPUT_VEH_DRAFT_TURN_RIGHT_ONLY`)
end

local function isPlayerBrakingVehicle()
    return IsControlPressed(0, `INPUT_VEH_CAR_BRAKE`)
        or IsControlPressed(0, `INPUT_VEH_DRAFT_BRAKE`)
        or IsControlPressed(0, `INPUT_VEH_BRAKE`)
        or IsControlPressed(0, `INPUT_VEH_MOVE_DOWN_ONLY`)
        or IsControlPressed(0, `INPUT_VEH_DRAFT_MOVE_DOWN_ONLY`)
        or IsDisabledControlPressed(0, `INPUT_VEH_CAR_BRAKE`)
        or IsDisabledControlPressed(0, `INPUT_VEH_DRAFT_BRAKE`)
end

-- S / ré de verdade. Freio nativo de idle NAO conta — senao W parado
-- entra em burnout e o governor puxa o carro pra tras na arrancada.
local function isPlayerHoldingReverseKey()
    return IsControlPressed(0, `INPUT_VEH_MOVE_DOWN_ONLY`)
        or IsDisabledControlPressed(0, `INPUT_VEH_MOVE_DOWN_ONLY`)
        or IsControlPressed(0, `INPUT_VEH_DRAFT_MOVE_DOWN_ONLY`)
        or IsDisabledControlPressed(0, `INPUT_VEH_DRAFT_MOVE_DOWN_ONLY`)
end

local function isPlayerAcceleratingVehicle()
    return IsControlPressed(0, `INPUT_VEH_CAR_ACCELERATE`)
        or IsControlPressed(0, `INPUT_VEH_DRAFT_ACCELERATE`)
        or IsControlPressed(0, `INPUT_VEH_ACCELERATE`)
        or IsControlPressed(0, `INPUT_VEH_MOVE_UP_ONLY`)
        or IsControlPressed(0, `INPUT_VEH_DRAFT_MOVE_UP_ONLY`)
        or IsDisabledControlPressed(0, `INPUT_VEH_CAR_ACCELERATE`)
        or IsDisabledControlPressed(0, `INPUT_VEH_DRAFT_ACCELERATE`)
end

-- SPACE / gamepad X. Nao conta como S — senao reduzida e freio de mao viram a mesma coisa.
local function isPlayerHandbraking()
    return IsControlPressed(0, CONTROL_HANDBRAKE)
        or IsDisabledControlPressed(0, CONTROL_HANDBRAKE)
end

local function disableHandbrakeJump()
    DisableControlAction(0, CONTROL_HANDBRAKE, true)
    DisableControlAction(1, CONTROL_HANDBRAKE, true)
    DisableControlAction(2, CONTROL_HANDBRAKE, true)
end

local function getEntityRollDeg(veh)
    local ok, roll = pcall(function()
        return Citizen.InvokeNative(NATIVE_GET_ENTITY_ROLL, veh, Citizen.ResultAsFloat())
    end)
    if ok and roll then
        return roll
    end
    return 0.0
end

local function requestVehicleControl(veh)
    if not veh or veh == 0 or not DoesEntityExist(veh) then
        return false
    end
    if NetworkHasControlOfEntity and NetworkHasControlOfEntity(veh) then
        return true
    end
    if NetworkRequestControlOfEntity then
        NetworkRequestControlOfEntity(veh)
        local attempts = 0
        while attempts < 8 do
            if NetworkHasControlOfEntity and NetworkHasControlOfEntity(veh) then
                return true
            end
            Wait(0)
            attempts = attempts + 1
        end
    end
    return true
end

local function getEntityBasis(veh)
    local heading = math.rad(GetEntityHeading(veh))
    local fwdX = -math.sin(heading)
    local fwdY = math.cos(heading)
    local rightX = math.cos(heading)
    local rightY = math.sin(heading)
    return fwdX, fwdY, rightX, rightY
end

local function tickProfileRollSnap(veh, profile)
    local speed = GetEntitySpeed(veh)
    if speed < (profile.rollMinSpeed or 2.5) then
        return
    end

    local roll = getEntityRollDeg(veh)
    local rollLimit = profile.maxRollDeg or 28.0
    if math.abs(roll) <= rollLimit then
        return
    end

    local now = GetGameTimer()
    local cooldown = profile.rollFixCooldownMs or 1800
    if now - profileKeeper.lastRollFixMs < cooldown then
        return
    end

    profileKeeper.lastRollFixMs = now
    requestVehicleControl(veh)
    pcall(function()
        Citizen.InvokeNative(NATIVE_SET_VEHICLE_ON_GROUND, veh, false)
    end)
    if SetVehicleOnGroundProperly then
        SetVehicleOnGroundProperly(veh)
    end
end

local function tickProfileRollSlide(veh, profile)
    local vel = GetEntityVelocity(veh)
    -- Buraco/pedra: o chassis ganha vel.z e um pouco de roll. Downforce
    -- aqui esmaga no chao e mata a velocidade.
    if math.abs(vel.z) > (profile.rollSlideMaxVz or 0.9) then
        return
    end

    local roll = getEntityRollDeg(veh)
    local absRoll = math.abs(roll)
    local startDeg = profile.rollSlideStartDeg or 14.0
    if absRoll < startDeg then
        return
    end

    local speed = GetEntitySpeed(veh)
    if speed < (profile.rollMinSpeed or 2.5) then
        return
    end

    local snapDeg = profile.rollSnapDeg or 72.0
    if profile.rollSnapFix == true and absRoll >= snapDeg then
        tickProfileRollSnap(veh, profile)
        return
    end

    requestVehicleControl(veh)

    local fwdX, fwdY, rightX, rightY = getEntityBasis(veh)
    local slideSign = roll >= 0.0 and 1.0 or -1.0
    local rollRange = math.max((profile.maxRollDeg or 32.0) - startDeg, 1.0)
    local intensity = math.min(1.0, (absRoll - startDeg) / rollRange)

    local dt = 0.05
    local slideMps = (profile.rollSlideMps or 4.5) * intensity * math.min(speed / 5.5, 1.6)
    local bleed = profile.rollForwardBleed or 0.9

    local fwdDot = (vel.x * fwdX) + (vel.y * fwdY)
    local baseVx = vel.x - (fwdX * fwdDot * (1.0 - bleed))
    local baseVy = vel.y - (fwdY * fwdDot * (1.0 - bleed))
    local latPush = slideMps * dt * 3.2

    SetEntityVelocity(
        veh,
        baseVx + (rightX * slideSign * latPush),
        baseVy + (rightY * slideSign * latPush),
        vel.z
    )

    local downForce = (profile.rollCorrectForce or 1.4) * intensity
    local sideOffset = 0.75 * slideSign
    pcall(function()
        Citizen.InvokeNative(
            NATIVE_APPLY_FORCE,
            veh,
            1,
            0.0, 0.0, -downForce,
            0.0, sideOffset, 0.35,
            0,
            true, true, true, false, true
        )
    end)
end

-- Anti-roll sem alterar a trajetoria: detecta qual lateral levantou e aplica
-- apenas a força vertical necessária nela. Diferente do modo slide, não injeta
-- velocidade lateral nem reduz o componente para frente.
local function tickProfileRollGrip(veh, profile)
    local speed = GetEntitySpeed(veh)
    if speed < (profile.rollMinSpeed or 2.5) then
        return
    end

    local vel = GetEntityVelocity(veh)
    local roll = math.abs(getEntityRollDeg(veh))
    local startDeg = profile.rollGripStartDeg or 5.0
    if math.abs(vel.z) > (profile.rollGripMaxVz or 0.9) and roll < (startDeg + 4.0) then
        return
    end
    if roll < startDeg then
        return
    end

    local left = GetOffsetFromEntityInWorldCoords(veh, -0.9, 0.0, 0.0)
    local right = GetOffsetFromEntityInWorldCoords(veh, 0.9, 0.0, 0.0)
    local highSideX = left.z > right.z and -0.9 or 0.9
    local maxDeg = math.max(profile.maxRollDeg or 18.0, startDeg + 1.0)
    local intensity = math.min(1.0, (roll - startDeg) / (maxDeg - startDeg))
    local force = (profile.rollGripForce or 1.1) * intensity
    local plantFrom = tonumber(profile.rollGripPlantMps) or 16.7
    if speed > plantFrom then
        force = force * (1.0 + math.min(1.4, (speed - plantFrom) / 6.0))
    end

    local function down(offX, mag)
        pcall(function()
            Citizen.InvokeNative(
                NATIVE_APPLY_FORCE,
                veh,
                1,
                0.0, 0.0, -mag,
                offX, 0.0, -3.5,
                0,
                true, true, true, false, true
            )
        end)
    end

    down(highSideX, force)
    down(0.0, force * 0.45)
end

local function tickProfileTurnLimit(veh, profile)
    local baseMult = profile.topSpeedMult or 1.0
    local mult = baseMult

    if profile.stability then
        local speed = GetEntitySpeed(veh)
        local turnCap = profile.turnSpeedCap or 6.0
        local turnMult = profile.turnTopMult or 0.55
        if isPlayerSteeringVehicle() and speed > turnCap then
            mult = baseMult * math.max(turnMult, 0.5)
        end
    end

    applyTopSpeedMult(veh, mult)
end

local function tickProfileSpeedLimit(veh, profile)
    tickProfileTurnLimit(veh, profile)
    clampVehicleSpeed(veh, resolveMaxSpeedMps(veh, profile))
end

-- Governor por frame: limita ganho de velocidade a accelMps2 (aceleracao
-- progressiva) e suaviza o freio-motor no coast com coastDecelMps2, pra dar
-- pra manter velocidade intermediaria sem o carro gargalar.
local speedGovernor = { active = false }

local function getEntityPitchDeg(veh)
    -- Mede a altura frente/traseira para que nariz levantado seja sempre positivo,
    -- independente do sinal de GET_ENTITY_PITCH usado pelo patch do coach4.
    local front = GetOffsetFromEntityInWorldCoords(veh, 0.0, 1.0, 0.0)
    local rear = GetOffsetFromEntityInWorldCoords(veh, 0.0, -1.0, 0.0)
    return math.deg(math.atan(front.z - rear.z, 2.0))
end

local function getPlayerSteerDirection()
    local left = IsControlPressed(0, `INPUT_VEH_CAR_TURN_LEFT_ONLY`)
        or IsDisabledControlPressed(0, `INPUT_VEH_CAR_TURN_LEFT_ONLY`)
        or IsControlPressed(0, `INPUT_VEH_DRAFT_TURN_LEFT_ONLY`)
        or IsDisabledControlPressed(0, `INPUT_VEH_DRAFT_TURN_LEFT_ONLY`)
    local right = IsControlPressed(0, `INPUT_VEH_CAR_TURN_RIGHT_ONLY`)
        or IsDisabledControlPressed(0, `INPUT_VEH_CAR_TURN_RIGHT_ONLY`)
        or IsControlPressed(0, `INPUT_VEH_DRAFT_TURN_RIGHT_ONLY`)
        or IsDisabledControlPressed(0, `INPUT_VEH_DRAFT_TURN_RIGHT_ONLY`)

    if left and not right then
        return -1.0
    end
    if right and not left then
        return 1.0
    end
    return 0.0
end

-- Turn assist: forca lateral na frente enquanto o player esterca, pra apertar
-- o raio de curva (o coach4 fica pesado demais pra girar em baixa/media).
-- Forca calibrada pra tick de 50ms; dt escala pra rodar por frame sem exagerar.
-- Ramp-in: toque rapido no A/D quase nao ganha assist; segurando chega no maximo
-- (senao varios toques acumulam yaw e o carro gira demais).
local function tickTurnAssist(veh, profile, fwdSpeed, steerDir, dt, steerHeldS)
    local assist = tonumber(profile.turnAssistForce) or 0.05
    if assist <= 0.0 or steerDir == 0.0 then
        return
    end

    local speed = math.abs(fwdSpeed)
    if speed < 1.5 then
        return
    end

    local rampS = tonumber(profile.turnAssistRampS) or 0.35
    local ramp = rampS > 0.0 and math.min(steerHeldS / rampS, 1.0) or 1.0
    local frameScale = math.min(dt / 0.05, 1.0)
    -- Cap 1.2 = assist trava ~22 km/h. Carro de 90 precisa cap maior
    -- senao a inercia sobe e o yaw fica igual ao da pickup.
    local speedRef = tonumber(profile.turnAssistSpeedRef) or 6.0
    local speedCap = tonumber(profile.turnAssistSpeedCap) or 1.2
    if speedRef <= 0.0 then
        speedRef = 6.0
    end
    local speedScale = math.min(speed / speedRef, speedCap)
    local mag = assist * speedScale * frameScale * ramp
    local offsetY = tonumber(profile.turnAssistOffsetY) or 1.6
    local offsetZ = tonumber(profile.turnAssistOffsetZ) or -3.5

    local function applyLat(dir, offY, forceMag)
        pcall(function()
            Citizen.InvokeNative(
                NATIVE_APPLY_FORCE,
                veh,
                1,
                dir * forceMag, 0.0, 0.0,
                0.0, offY, offsetZ,
                0,
                true, true, true, false, true
            )
        end)
    end

    local couple = profile.turnAssistCouple == true
    local coupleAbove = tonumber(profile.turnAssistCoupleAboveMps)
    local usingCouple = couple and (not coupleAbove or speed >= coupleAbove)
    local maxMps = tonumber(profile.maxSpeedMps) or 25.0
    local above = coupleAbove or 11.1
    local t = math.max(0.0, math.min(1.0, (speed - above) / math.max(maxMps - above, 1.0)))
    local handbrake = profile.handbrake == true and isPlayerHandbraking()
    if handbrake then
        -- Tap de SPACE+A/D ainda precisa yaw; ramp sozinha atrasa o drift.
        ramp = math.max(ramp, 0.7)
        mag = assist * speedScale * frameScale * ramp
    end

    local frontMag = mag
    if usingCouple then
        frontMag = mag * (1.0 - t * (tonumber(profile.turnAssistFrontFade) or 0.0))
    end
    applyLat(steerDir, offsetY, frontMag)

    if usingCouple then
        local boost = tonumber(profile.turnAssistCoupleBoost) or 0.0
        if handbrake then
            boost = boost + (tonumber(profile.handbrakeCoupleExtra) or 0.55)
        end
        applyLat(-steerDir, -offsetY, mag * (1.0 + boost * t))
    end

    -- Em alta o chassis gira e a velocity fica reta (subviragem).
    -- Rotaciona o XY junto com o esterco, sem forca lateral extra.
    local followDegS = tonumber(profile.turnFollowDegS) or 0.0
    if followDegS > 0.0 and dt > 0.0 and (usingCouple or speed >= (coupleAbove or 6.5)) then
        local extra = 1.0
        local above = coupleAbove or 11.1
        local maxMps = tonumber(profile.maxSpeedMps) or 25.0
        local t = math.max(0.0, math.min(1.0, (speed - above) / math.max(maxMps - above, 1.0)))
        extra = 1.0 + t * (tonumber(profile.turnFollowHighMult) or 0.35)

        -- Curva fechada: A/D no fundo (e freio) aperta o raio.
        -- Em alta o tightMult capota — fade depois de ~50 km/h.
        local tight = tonumber(profile.turnFollowTightMult) or 1.0
        local tightFadeMps = tonumber(profile.turnFollowTightFadeMps) or 16.7
        if ramp >= 0.75 and tight > 1.0 then
            local fade = 1.0
            if speed > tightFadeMps then
                fade = math.max(0.0, 1.0 - (speed - tightFadeMps) / 6.0)
            end
            extra = extra * (1.0 + (tight - 1.0) * fade)
        end
        if isPlayerBrakingVehicle() then
            extra = extra * (tonumber(profile.turnFollowBrakeMult) or 1.0)
        end
        if handbrake then
            extra = extra * (tonumber(profile.handbrakeFollowMult) or 2.0)
        end

        -- Nao zera o yaw (isso e a travada). So alivia se ja inclinou.
        local rollAbs = math.abs(getEntityRollDeg(veh))
        local rollSoft = tonumber(profile.turnFollowMaxRollDeg) or 10.0
        if rollAbs > 3.0 then
            extra = extra * math.max(0.35, 1.0 - (rollAbs - 3.0) / math.max(rollSoft, 6.0))
        end

        local a = steerDir * math.rad(followDegS * extra) * ramp * dt
        local fwdX, fwdY, rightX, rightY = getEntityBasis(veh)
        local vel = GetEntityVelocity(veh)
        local fwdDot = (vel.x * fwdX) + (vel.y * fwdY)
        local latDot = (vel.x * rightX) + (vel.y * rightY)
        local ca, sa = math.cos(a), math.sin(a)
        local nFwd = fwdDot * ca - latDot * sa
        local nLat = fwdDot * sa + latDot * ca
        SetEntityVelocity(
            veh,
            (fwdX * nFwd) + (rightX * nLat),
            (fwdY * nFwd) + (rightY * nLat),
            vel.z
        )
    end

    -- Planta as 4 enquanto esterca em alta, ANTES de levantar.
    local plant = tonumber(profile.turnPlantForce) or 0.0
    local plantFrom = tonumber(profile.turnPlantMps) or 13.9
    if plant > 0.0 and speed >= plantFrom and ramp > 0.15 then
        local plantMag = plant * ramp * math.min(1.0, (speed - plantFrom) / 5.0 + 0.35)
        if handbrake then
            plantMag = plantMag * (tonumber(profile.handbrakePlantMult) or 0.22)
        end
        pcall(function()
            Citizen.InvokeNative(
                NATIVE_APPLY_FORCE,
                veh, 1,
                0.0, 0.0, -plantMag,
                0.0, 0.0, -3.5,
                0, true, true, true, false, true
            )
            -- lado de dentro (o que levanta)
            Citizen.InvokeNative(
                NATIVE_APPLY_FORCE,
                veh, 1,
                0.0, 0.0, -plantMag * 0.7,
                -steerDir * 0.95, 0.0, -3.5,
                0, true, true, true, false, true
            )
        end)
    end
end

-- Anti-wheelie: so corrige wheelie SUSTENTADO. Bump de terreno dispara
-- pitchRate absurdo + vel.z; esmagar a frente nisso puxa o carro pro chao
-- e come velocidade.
local function tickAntiWheelie(veh, profile, pitch, pitchRate, dt, fwdSpeed, velZ)
    if profile.wheelieControl == false then
        return
    end

    if math.abs(fwdSpeed or 0.0) < 1.6 then
        return
    end

    -- Pulo / irregularidade: nao e wheelie.
    if math.abs(velZ or 0.0) > (profile.wheelieMaxVz or 0.75) then
        return
    end

    local startDeg = profile.wheelieStartDeg or 6.5
    if pitch <= startDeg then
        return
    end

    -- Spike de 1-2 frames = pedra. Wheelie sobe ~8-25 deg/s.
    if pitchRate > (profile.wheelieMaxRateDegS or 32.0) then
        return
    end

    local rateThreshold = profile.wheelieRateDegS or 10.0
    local hardDeg = profile.wheelieHardDeg or 12.0
    if pitchRate < rateThreshold and pitch < hardDeg then
        return
    end

    local frameScale = math.min(dt / 0.05, 1.0)
    local intensity = math.min(1.0, (pitch - startDeg) / 10.0)
    local force = (profile.wheelieForce or 2.0) * intensity * frameScale
    pcall(function()
        Citizen.InvokeNative(
            NATIVE_APPLY_FORCE,
            veh,
            1,
            0.0, 0.0, -force,
            0.0, 1.6, 0.2,
            0,
            true, true, true, false, true
        )
    end)
end

local function setForwardSpeed(veh, vel, fwdX, fwdY, fwdSpeed, newFwd)
    local latX = vel.x - (fwdX * fwdSpeed)
    local latY = vel.y - (fwdY * fwdSpeed)
    SetEntityVelocity(
        veh,
        (fwdX * newFwd) + latX,
        (fwdY * newFwd) + latY,
        vel.z
    )
end

local function resolveServiceBrakeBite(profile, lastFwd, brakeHeldS)
    local decel = tonumber(profile.brakeDecelMps2) or 0.0
    if decel <= 0.0 then
        return 0.0
    end
    local highMult = tonumber(profile.brakeHighSpeedMult)
    if not highMult or not lastFwd or lastFwd < 5.0 then
        return decel
    end
    local maxMps = tonumber(profile.maxSpeedMps) or 25.0
    local t = math.min(1.0, lastFwd / math.max(maxMps, 1.0))
    local light = decel * ((1.0 - t) + t * highMult)
    -- Tap = reduzida. Segura S >0.35s e o bite volta pro freio de verdade.
    local holdT = math.min(1.0, math.max(0.0, ((brakeHeldS or 0.0) - 0.35) / 0.45))
    return light + (decel - light) * holdT
end

-- SPACE: bleed suave + nao deixa o nativo (jump) comer velo. W+SPACE = power slide.
local function tickHandbrake(veh, profile, dt, accelerating, lastFwd)
    if profile.handbrake ~= true or not isPlayerHandbraking() then
        return lastFwd
    end
    if dt <= 0.0 then
        return lastFwd
    end

    local fwdX, fwdY = getEntityBasis(veh)
    local vel = GetEntityVelocity(veh)
    local nowFwd = (vel.x * fwdX) + (vel.y * fwdY)
    if nowFwd < 0.35 then
        return lastFwd
    end

    local hb = tonumber(profile.handbrakeDecelMps2) or 6.0
    if accelerating then
        hb = hb * 0.42
    end
    local target = math.max((lastFwd or nowFwd) - hb * dt, 0.0)
    if math.abs(nowFwd - target) > 0.04 then
        setForwardSpeed(veh, vel, fwdX, fwdY, nowFwd, target)
    end
    return target
end

local function startSpeedGovernor()
    if speedGovernor.active then
        return
    end
    speedGovernor.active = true
    CreateThread(function()
        local lastFwd = nil
        local lastPitch = nil
        local steerHeldS = 0.0
        local burnoutHeldS = 0.0
        local brakeHeldS = 0.0
        local boostUntilMs = 0
        local lastMs = GetGameTimer()
        while profileKeeper.active do
            local v = profileKeeper.veh
            if v == 0 or not DoesEntityExist(v) then
                break
            end

            local profile = mergeProfile(profileKeeper.profileId, profileKeeper.overrides)
            local accel = profile and tonumber(profile.accelMps2) or 0.0
            local coast = profile and tonumber(profile.coastDecelMps2) or 0.0

            if (accel <= 0.0 and coast <= 0.0) or GetVehiclePedIsIn(PlayerPedId(), false) ~= v then
                lastFwd = nil
                lastPitch = nil
                lastMs = GetGameTimer()
                Wait(250)
            else
                local now = GetGameTimer()
                local dt = math.min((now - lastMs) / 1000.0, 0.1)
                lastMs = now

                local fwdX, fwdY = getEntityBasis(v)
                local vel = GetEntityVelocity(v)
                local fwdSpeed = (vel.x * fwdX) + (vel.y * fwdY)

                local pitch = getEntityPitchDeg(v)
                local pitchRate = (lastPitch and dt > 0.0) and ((pitch - lastPitch) / math.max(dt, 0.001)) or 0.0
                lastPitch = pitch

                local steerDir = getPlayerSteerDirection()
                if steerDir ~= 0.0 then
                    steerHeldS = steerHeldS + dt
                else
                    steerHeldS = 0.0
                end
                local grounded = math.abs(vel.z) <= 2.0

                local braking = isPlayerBrakingVehicle()
                local accelerating = isPlayerAcceleratingVehicle()
                local holdingReverse = isPlayerHoldingReverseKey()
                local handbrake = profile.handbrake == true and isPlayerHandbraking()
                if profile.handbrake == true then
                    disableHandbrakeJump()
                end
                if braking and not accelerating and not handbrake then
                    brakeHeldS = brakeHeldS + dt
                else
                    brakeHeldS = 0.0
                end

                -- Pulo/queda: nao herda o dip de XY (virou vel.z). Senão o
                -- governor trava lastFwd baixo e o carro "morre" no bump.
                if not grounded or dt <= 0.0 then
                    if lastFwd == nil then
                        lastFwd = fwdSpeed
                    elseif fwdSpeed > lastFwd then
                        lastFwd = fwdSpeed
                    end
                elseif lastFwd == nil then
                    lastFwd = fwdSpeed
                elseif accelerating and holdingReverse and profile.burnoutHold ~= false
                    and math.abs(fwdSpeed) <= (tonumber(profile.burnoutMaxMps) or 3.0) then
                    -- Burnout (W+S juntos): segura o carro no lugar patinando.
                    -- Soltar S -> larga com boost; soltar W -> fica parado.
                    -- Precisa do S real. Freio de idle + W NAO e burnout.
                    burnoutHeldS = burnoutHeldS + dt
                    local hold = fwdSpeed * math.max(0.0, 1.0 - (dt * 8.0))
                    if math.abs(fwdSpeed) > 0.05 then
                        setForwardSpeed(v, vel, fwdX, fwdY, fwdSpeed, hold)
                    end
                    lastFwd = hold
                elseif braking and not accelerating and not handbrake then
                    burnoutHeldS = 0.0
                    boostUntilMs = 0
                    -- Reduzida so nos carros com brakeHighSpeedMult (Royale).
                    -- Pickup/taxi continuam no assist de 50ms + lastFwd = fwdSpeed.
                    if tonumber(profile.brakeHighSpeedMult) then
                        local bite = resolveServiceBrakeBite(profile, lastFwd, brakeHeldS)
                        if bite > 0.0 and lastFwd and lastFwd > 0.4 then
                            local target = math.max(lastFwd - bite * dt, 0.0)
                            if math.abs(fwdSpeed - target) > 0.04 then
                                setForwardSpeed(v, vel, fwdX, fwdY, fwdSpeed, target)
                            end
                            lastFwd = target
                        else
                            lastFwd = fwdSpeed
                        end
                    else
                        lastFwd = fwdSpeed
                    end
                elseif accelerating then
                    -- Largada do burnout: kick inicial + rampa turbinada por um tempo
                    if burnoutHeldS >= 0.35 then
                        boostUntilMs = now + (tonumber(profile.burnoutBoostMs) or 1500)
                        lastFwd = math.max(lastFwd or 0.0, tonumber(profile.burnoutLaunchMps) or 2.5)
                    end
                    burnoutHeldS = 0.0

                    if accel > 0.0 then
                        local accelNow = accel
                        if now < boostUntilMs then
                            accelNow = accel * (tonumber(profile.burnoutBoostMult) or 2.5)
                        end

                        if lastFwd < 0.0 then
                            lastFwd = 0.0
                        end

                        -- W com o chassis ainda andando pra tras (patinada/rock):
                        -- zera a ré em vez de herdar lastFwd negativo.
                        if fwdSpeed < -0.08 then
                            local recovered = math.min(0.0, fwdSpeed + (accelNow * dt * 6.0))
                            setForwardSpeed(v, vel, fwdX, fwdY, fwdSpeed, recovered)
                            lastFwd = math.max(recovered, 0.0)
                        else
                            local allowed = lastFwd + (accelNow * dt)
                            if fwdSpeed > allowed then
                                local launching = lastFwd < 3.5
                                if launching then
                                    -- Snap allowed<-fwdSpeed puxa o carro pra tras todo
                                    -- frame. Na largada so corta salto absurdo.
                                    local spikeCap = lastFwd + math.max(accelNow * dt * 8.0, 0.6)
                                    if fwdSpeed > spikeCap then
                                        setForwardSpeed(v, vel, fwdX, fwdY, fwdSpeed, spikeCap)
                                        lastFwd = spikeCap
                                    else
                                        lastFwd = fwdSpeed
                                    end
                                else
                                    setForwardSpeed(v, vel, fwdX, fwdY, fwdSpeed, allowed)
                                    lastFwd = allowed
                                end
                            else
                                -- Bump: native perde XY num frame. Copiar lastFwd =
                                -- fwdSpeed trava a perda e o recovery fica limitado
                                -- a accelMps2 (parece que algo comeu a velo).
                                local dip = lastFwd - fwdSpeed
                                if dip > 0.12 and dip < 8.0 and fwdSpeed > 0.4 then
                                    lastFwd = lastFwd - math.min(dip * 0.12, accelNow * dt)
                                else
                                    lastFwd = math.max(fwdSpeed, 0.0)
                                end
                            end
                        end
                    else
                        lastFwd = math.max(fwdSpeed, 0.0)
                    end

                    tickAntiWheelie(v, profile, pitch, pitchRate, dt, fwdSpeed, vel.z)
                elseif steerDir ~= 0.0 then
                    burnoutHeldS = 0.0
                    -- Estercando no coast: deixa a curva perder velocidade
                    -- naturalmente (floor aqui cola o carro e mata a curva).
                    lastFwd = fwdSpeed
                else
                    burnoutHeldS = 0.0
                    -- Coast reto: segura o freio-motor nativo num decaimento suave.
                    if coast > 0.0 and lastFwd > 0.8 then
                        local floor = lastFwd - (coast * dt)
                        if fwdSpeed < floor then
                            setForwardSpeed(v, vel, fwdX, fwdY, fwdSpeed, floor)
                            lastFwd = floor
                        else
                            lastFwd = fwdSpeed
                        end
                    else
                        lastFwd = fwdSpeed
                    end
                end

                lastFwd = tickHandbrake(v, profile, dt, accelerating, lastFwd)

                if grounded then
                    tickTurnAssist(v, profile, fwdSpeed, steerDir, dt, steerHeldS)
                end

                Wait(0)
            end
        end
        speedGovernor.active = false
    end)
end

local function tickProfileBrakeAssist(veh, profile)
    -- Governor ja aplica o bite (reduzida / hold). Nao empilha.
    if tonumber(profile.brakeHighSpeedMult) then
        return
    end
    if profile.handbrake == true and isPlayerHandbraking() then
        return
    end
    local decel = profile.brakeDecelMps2
    if not decel or decel <= 0.0 then
        return
    end
    if not isPlayerBrakingVehicle() then
        return
    end
    -- Freio extra nao pode brigar com o W. Idle-brake nativo + throttle
    -- era o puxao pra tras na arrancada.
    if isPlayerAcceleratingVehicle() then
        return
    end

    local speed = GetEntitySpeed(veh)
    if speed < 0.08 then
        return
    end

    local fwdX, fwdY = getEntityBasis(veh)
    local vel = GetEntityVelocity(veh)
    local fwdSpeed = (vel.x * fwdX) + (vel.y * fwdY)
    if fwdSpeed <= 0.12 then
        return
    end

    requestVehicleControl(veh)

    local dt = 0.05
    local reduction = math.min(decel * dt, fwdSpeed)
    local newFwdSpeed = fwdSpeed - reduction
    local latX = vel.x - (fwdX * fwdSpeed)
    local latY = vel.y - (fwdY * fwdSpeed)

    SetEntityVelocity(
        veh,
        (fwdX * newFwdSpeed) + latX,
        (fwdY * newFwdSpeed) + latY,
        vel.z
    )
end

local function shouldRollStabilize(profile)
    if not profile then
        return false
    end
    if profile.rollStabilize ~= nil then
        return profile.rollStabilize == true
    end
    return profile.stability == true
end

local function tickProfileRollStabilize(veh, profile)
    if not shouldRollStabilize(profile) then
        return
    end

    local mode = profile.rollFixMode or 'slide'
    if mode == 'snap' then
        tickProfileRollSnap(veh, profile)
        return
    end
    if mode == 'hybrid' then
        local switchMps = tonumber(profile.rollGripAboveMps) or 11.1
        if GetEntitySpeed(veh) >= switchMps then
            tickProfileRollGrip(veh, profile)
        else
            tickProfileRollSlide(veh, profile)
        end
        return
    end
    if mode == 'grip' then
        tickProfileRollGrip(veh, profile)
        return
    end

    tickProfileRollSlide(veh, profile)
end

local function stopProfileKeeper()
    profileKeeper.active = false
    profileKeeper.veh = 0
    profileKeeper.lastMult = nil
    profileKeeper.lastRollFixMs = 0
end

local function startProfileKeeper(veh, profileId, overrides)
    -- Viatura NPC / outro coach4 não pode roubar o keeper do carro do player.
    local playerVeh = GetVehiclePedIsIn(PlayerPedId(), false)
    if playerVeh ~= 0 and playerVeh ~= veh then
        return
    end

    profileKeeper.veh = veh
    profileKeeper.profileId = profileId
    profileKeeper.overrides = overrides
    profileKeeper.lastMult = nil
    profileKeeper.lastRollFixMs = 0
    if profileKeeper.active then
        startSpeedGovernor()
        return
    end
    profileKeeper.active = true
    startSpeedGovernor()
    CreateThread(function()
        local refreshTick = 0
        while profileKeeper.active do
            local v = profileKeeper.veh
            if v == 0 or not DoesEntityExist(v) then
                break
            end
            local ped = PlayerPedId()
            if GetVehiclePedIsIn(ped, false) ~= v then
                Wait(500)
            else
                local profile = mergeProfile(profileKeeper.profileId, profileKeeper.overrides)
                if profile then
                    tickProfileSpeedLimit(v, profile)
                    tickProfileBrakeAssist(v, profile)
                    tickProfileRollStabilize(v, profile)
                    Wait(50)
                else
                    Wait(500)
                end
                refreshTick = refreshTick + 1
                if refreshTick >= 120 then
                    MetaLib.applyCarProfile(v, profileKeeper.profileId, true, profileKeeper.overrides)
                    refreshTick = 0
                end
            end
        end
        stopProfileKeeper()
    end)
end

function MetaLib.applyCarProfile(veh, profileId, silent, overrides)
    if veh == 0 or not DoesEntityExist(veh) then
        return false
    end
    if GetEntityModel(veh) ~= COACH4 then
        return false
    end

    local profile = mergeProfile(profileId, overrides)
    if not profile then
        return false
    end

    local mult = profile.topSpeedMult or 1.0
    applyTopSpeedMult(veh, mult)
    clampVehicleSpeed(veh, resolveMaxSpeedMps(veh, profile))

    if IsDraftVehicle and IsDraftVehicle(veh) then
        local draftSpd = (profile.draftSpeed or 6.0) * mult
        pcall(function()
            Citizen.InvokeNative(NATIVE_DRAFT_DESIRED_SPEED, veh, draftSpd + 0.0)
        end)
    end

    startProfileKeeper(veh, profileId, overrides)

    local est = getEstimatedMaxSpeed(veh)
    -- if not silent then
    --     print(('^2[dodi_coach4_stream]^7 perfil=%s topMult=%.2f draftSpd=%.1f estMax=%.2f entityDraft=%s'):format(
    --         profileId,
    --         mult,
    --         profile.draftSpeed or 0,
    --         est,
    --         tostring(IsDraftVehicle and IsDraftVehicle(veh) or false)
    --     ))
    -- end

    return true, profile, est
end

function MetaLib.printMetaDebug()
    local modelDraft = MetaLib.isCoach4DraftModel()
    local inVeh = GetVehiclePedIsIn(PlayerPedId(), false)
    print('^6[coach4 meta debug]^7')
    print(('  IsThisModelDraft(coach4)=%s  (false = patch no .app OK)'):format(tostring(modelDraft)))
    print(('  HasCoach4CarMeta()=%s'):format(tostring(MetaLib.hasCarMeta())))
    if inVeh ~= 0 then
        print(('  inVehicle=%s entityDraft=%s estMax=%.2f'):format(
            inVeh,
            tostring(IsDraftVehicle and IsDraftVehicle(inVeh) or false),
            getEstimatedMaxSpeed(inVeh)
        ))
    end
end

exports('IsCoach4DraftModel', MetaLib.isCoach4DraftModel)
exports('HasCoach4CarMeta', MetaLib.hasCarMeta)
exports('IsCoach4EntityCar', MetaLib.isEntityCarType)
exports('ApplyCarProfile', MetaLib.applyCarProfile)
exports('PrintMetaDebug', MetaLib.printMetaDebug)
