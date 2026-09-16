Config = {}

-- Convar: setr coach4_meta_enforce 0  desliga tudo (dev local)
Config.EnforceMeta = true
Config.KickWithoutMeta = true
Config.KickAfterMs = 90000
Config.RecheckMs = 15000
Config.BlockControls = true

Config.Messages = {
    title = 'VEHICLE PATCH REQUIRED',
    line1 = 'This server uses cars (coach4 as VEHICLE_TYPE_CAR).',
    line2 = 'Merge the citizen folder from the pack into your RedM.app and RESTART RedM.',
    line3 = 'Without the patch you cannot play — it prevents desync and wagon abuse.',
    line4 = 'Patch folder: dodi_coach4_stream/client_patch/citizen  ->  RedM.app/citizen',
    kickReason = 'COACH4 / RedM.app patch not installed. Check the server Discord.',
}

-- topSpeedMult = MODIFY_VEHICLE_TOP_SPEED (1.0 = stock do handling.meta)
-- maxSpeedMps  = teto hard em m/s (ignora mult; ex: 5.5 = ~20 km/h caminhao)
-- draftSpeed = se entity ainda for draft, empurra _SET_DRAFT_VEHICLE_DESIRED_SPEED
-- brakeDecelMps2 = desaceleracao extra ao segurar freio/S (m/s^2); 0 = so nativo
-- brakeHighSpeedMult = 0-1; em alta o S vira reduzida (tap ~0.35s). Segurar S
--   rampa de volta pro bite cheio. Nil = S antigo (assist 50ms, pickup/taxi)
-- handbrake = true mapeia SPACE (INPUT_JUMP 0xD9D0E1C0) pra freio de mao/drift
--   handbrakeDecelMps2 bleed (W+SPACE = 42% disso, power slide)
--   handbrakeFollowMult / handbrakeCoupleExtra / handbrakePlantMult = yaw do drift
-- accelMps2 = aceleracao maxima com throttle (m/s^2); menor = arranca mais devagar
--             e progressivo (da pra segurar velocidade). 0/nil = sem limite (instantaneo)
-- coastDecelMps2 = decaimento maximo ao soltar W sem frear (m/s^2); suaviza o
--             freio-motor nativo pra dar pra manter velocidade so tapeando o W.
--             0/nil = freio-motor nativo puro
-- Anti-wheelie (frente levantando ao acelerar), defaults no codigo:
--   wheelieControl = false desliga | wheelieStartDeg (6.5) pitch minimo
--   wheelieRateDegS (10.0) subida sustentada do nariz | wheelieHardDeg (12.0)
--   wheelieForce (2.0) | wheelieMaxRateDegS (32) spike acima disso = bump
--   wheelieMaxVz (0.75) ignora se o chassis esta pulando no terreno
-- turnAssistForce = forca lateral na frente enquanto esterca (aperta o raio de
--   curva); maior = vira mais facil; 0 = desliga; default 0.05 no codigo
-- turnAssistOffsetZ = altura local onde o assist atua; deve acompanhar o COM
--   do handling.meta para nao gerar roll artificial (default -3.5)
-- turnAssistRampS = segundos segurando A/D ate o assist chegar no maximo (0.35
--   default); toque rapido quase nao ganha assist, evita girar demais em tapinhas
-- turnAssistSpeedRef = m/s da escala (6 = pickup). turnAssistSpeedCap = teto da
--   escala (1.2 = trava ~22 km/h). NAO subir o cap em carro rapido — vira two-wheel.
-- turnAssistCouple = true aplica forca oposta na traseira (gira no eixo, sem
--   sideslip). turnAssistCoupleAboveMps = so ativa o par acima dessa velo
-- turnAssistCoupleBoost = extra de yaw na traseira no teto (0.65 = +65% a 90)
-- turnFollowDegS = rotaciona a velocity com o esterco (deg/s). 0 = off
-- turnFollowHighMult = extra de follow no teto (0.35 = +35% a 90)
-- turnFollowTightMult = extra com A/D no fundo (curva fechada)
-- turnFollowBrakeMult = extra com S+esterco (entrada de curva)
-- Burnout (W+S juntos com carro quase parado): segura o carro patinando; soltar
--   S larga com boost, soltar W fica parado. burnoutHold = false desliga;
--   burnoutMaxMps (3.0) velocidade maxima pra entrar no burnout
--   burnoutLaunchMps (2.5) kick inicial da largada | burnoutBoostMult (2.5)
--   multiplicador do accelMps2 na largada | burnoutBoostMs (1500) duracao do boost
-- Lua NAO muda massa/tracao — diferenca forte = editar COACH4 / COACH4_SPORT no handling.meta
Config.CarProfiles = {
    stock = {
        label = 'Stock',
        model = 'coach4',
        topSpeedMult = 1.0,
        draftSpeed = 6.0,
        accelMps2 = 3.0,
        coastDecelMps2 = 1.3,
    },
    sedan = {
        label = 'Sedan',
        model = 'coach4',
        topSpeedMult = 0.75,
        draftSpeed = 4.5,
        accelMps2 = 2.4,
        coastDecelMps2 = 1.2,
    },
    sport = {
        label = 'Sport',
        model = 'coach4',
        topSpeedMult = 1.65,
        draftSpeed = 10.0,
        accelMps2 = 4.5,
        coastDecelMps2 = 1.6,
    },
    truck = {
        label = 'Truck',
        model = 'coach4',
        topSpeedMult = 0.62,
        draftSpeed = 4.0,
        accelMps2 = 1.6,
        coastDecelMps2 = 1.0,
        turnAssistForce = 0.05,
        turnAssistOffsetZ = -3.5,
        stability = false,
        rollStabilize = true,
        rollFixMode = 'slide',       -- slide = derrapa de lado | snap = teleporte antigo
        rollSlideStartDeg = 12.0,
        rollSlideMps = 5.0,
        rollForwardBleed = 0.88,
        rollCorrectForce = 1.6,
        maxRollDeg = 38.0,
        rollSnapFix = false,         -- true = SetVehicleOnGroundProperly so se tombar muito
        rollSnapDeg = 72.0,
        rollMinSpeed = 2.5,
        rollFixCooldownMs = 2000,
        turnSpeedCap = 6.0,
        turnTopMult = 0.55,
    },
}
