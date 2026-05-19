local menuOpen = false
local previewCam = nil
local savedCoords = nil
local savedHeading = nil
local savedForward = nil


-- Guarda posición original del personaje
function SavePlayerPosition()
    local ped = PlayerPedId()
    savedCoords = GetEntityCoords(ped)
    savedHeading = GetEntityHeading(ped)
end

-- Devuelve al personaje a la posición original
function ResetPlayerPosition()
    if savedCoords and savedHeading then
        local ped = PlayerPedId()
        ClearPedTasksImmediately(ped)
        -- Colocar al ped de vuelta con precisión
        SetEntityCoords(ped, savedCoords.x, savedCoords.y, savedCoords.z, false, false, false, false)
        SetEntityHeading(ped, savedHeading)
    end
end

local camDistance = 2.4
local camAngle = 0.0

-- Actualiza la posición de la cámara orbitando en 3D alrededor del jugador
function UpdateCameraPosition()
    if previewCam and savedCoords then
        local rad = math.rad(camAngle)
        -- En RDR3, a partir del heading en grados, calculamos coordenadas esféricas
        local camX = savedCoords.x - math.sin(rad) * camDistance
        local camY = savedCoords.y + math.cos(rad) * camDistance
        local camZ = savedCoords.z + 0.45 -- Nivel del pecho
        
        SetCamCoord(previewCam, camX, camY, camZ)
        
        local ped = PlayerPedId()
        PointCamAtEntity(previewCam, ped, 0.0, 0.0, 0.2, true)
    end
end

-- Crea la cámara frontal enfocada en el personaje
function CreatePreviewCamera()
    local ped = PlayerPedId()
    SavePlayerPosition()
    
    savedForward = GetEntityForwardVector(ped)
    camDistance = 2.4
    camAngle = savedHeading or GetEntityHeading(ped)
    
    local rad = math.rad(camAngle)
    local camX = savedCoords.x - math.sin(rad) * camDistance
    local camY = savedCoords.y + math.cos(rad) * camDistance
    local camZ = savedCoords.z + 0.45
    
    previewCam = CreateCamWithParams("DEFAULT_SCRIPTED_CAMERA", camX, camY, camZ, 0.0, 0.0, 0.0, 48.0, true, 2)
    
    PointCamAtEntity(previewCam, ped, 0.0, 0.0, 0.2, true)
    RenderScriptCams(true, true, 900, true, true)
end

-- Destruye la cámara frontal
function DestroyPreviewCamera()
    if previewCam then
        RenderScriptCams(false, true, 900, true, true)
        DestroyCam(previewCam, false)
        previewCam = nil
    end
    ResetPlayerPosition()
end

-- Función para alternar el menú
function ToggleMenu()
    menuOpen = not menuOpen
    SetNuiFocus(menuOpen, menuOpen)
    SendNUIMessage({
        action = "toggleMenu",
        state = menuOpen,
        language = Config.Language or 'es'
    })
    
    if menuOpen then
        CreatePreviewCamera()
    else
        DestroyPreviewCamera()
    end
end

-- Comando para abrir el menú
RegisterCommand(Config.Command or 'animtest', function()
    ToggleMenu()
end, false)

-- Asignación de tecla nativa
if type(RegisterKeyMapping) == 'function' or RegisterKeyMapping ~= nil then
    RegisterKeyMapping(Config.Command or 'animtest', 'Menú de Pruebas de Animación (torp_animtest)', 'keyboard', Config.DefaultKey or 'F9')
else
    -- Fallback si RegisterKeyMapping es nulo en esta versión de RedM
    Citizen.CreateThread(function()
        while true do
            Citizen.Wait(0)
            -- 0xF383F50C es el hash de tecla para F9 en RDR3
            if IsControlJustPressed(0, 0xF383F50C) then
                ToggleMenu()
            end
        end
    end)
end

-- Hilo para congelar movimiento y controles mientras el menú está abierto
Citizen.CreateThread(function()
    while true do
        if menuOpen then
            DisableControlAction(0, 0x5997C630, true) -- MOVE_LR
            DisableControlAction(0, 0x3D77B13B, true) -- MOVE_UD
            DisableControlAction(0, 0x8FFC75D6, true) -- SPRINT
            DisableControlAction(0, 0xD45CEE5C, true) -- JUMP
            DisableControlAction(0, 0xD7963AA4, true) -- ATTACK
            DisableControlAction(0, 0xF84FA74F, true) -- AIM
            Citizen.Wait(0)
        else
            Citizen.Wait(250)
        end
    end
end)

-- Callback para cerrar el menú
RegisterNUICallback('closeMenu', function(data, cb)
    menuOpen = false
    SetNuiFocus(false, false)
    DestroyPreviewCamera()
    cb('ok')
end)

-- Callback para detener acciones y regresar al punto de inicio
RegisterNUICallback('stopAction', function(data, cb)
    ResetPlayerPosition()
    cb('ok')
end)

-- Callback para rotar la cámara orbital alrededor del personaje con el mouse
RegisterNUICallback('rotatePlayer', function(data, cb)
    local delta = tonumber(data.delta) or 0.0
    if previewCam and savedCoords then
        -- En lugar de rotar la entidad (que se bloquea en escenarios), orbitamos la cámara
        camAngle = camAngle + delta
        UpdateCameraPosition()
    end
    cb('ok')
end)

-- Callback para reproducir animaciones estándar
RegisterNUICallback('playAnim', function(data, cb)
    local dict = data.dict
    local name = data.name
    local ped = PlayerPedId()
    
    -- Cancelar cualquier tarea inmediatamente para evitar bloqueos
    ClearPedTasksImmediately(ped)
    
    -- Solicitar diccionario de animación
    RequestAnimDict(dict)
    local timeout = 0
    while not HasAnimDictLoaded(dict) and timeout < 50 do
        Wait(100)
        timeout = timeout + 1
    end
    
    if HasAnimDictLoaded(dict) then
        -- flag 1: Loop, 0: Normal, 49: Upper Body Only Loop
        local flag = data.upperOnly and 49 or 1
        TaskPlayAnim(ped, dict, name, 8.0, -8.0, -1, flag, 0.0, false, false, false)
    else
        TriggerEvent('ox_lib:notify', {
            title = 'Error',
            description = 'No se pudo cargar el diccionario de animación: ' .. tostring(dict),
            type = 'error'
        })
    end
    
    cb('ok')
end)

-- Callback para reproducir escenarios
RegisterNUICallback('playScenario', function(data, cb)
    local scenarioName = data.name
    local ped = PlayerPedId()
    
    -- Cancelación inmediata evita que el nuevo escenario sea rechazado por el anterior
    ClearPedTasksImmediately(ped)
    
    -- TASK_START_SCENARIO_IN_PLACE_HASH
    Citizen.InvokeNative(0x524B54361229154F, ped, GetHashKey(scenarioName), -1, true, 0, -1.0, 0)
    
    cb('ok')
end)

-- Callback para reproducir Kit Emotes
RegisterNUICallback('playEmote', function(data, cb)
    local emoteName = data.name
    local category = tonumber(data.category) or 1
    local ped = PlayerPedId()
    
    ClearPedTasksImmediately(ped)
    
    -- Citizen.InvokeNative(0xB31A277C1AC7B7FF, ped, categoryId, playType (2 = full body), emoteHash, 0, 0, 0, 0, 0)
    Citizen.InvokeNative(0xB31A277C1AC7B7FF, ped, category, 2, GetHashKey(emoteName), 0, 0, 0, 0, 0)
    
    cb('ok')
end)

-- Callback para cambiar la distancia de la cámara (Zoom físico de 1 a 10 metros)
RegisterNUICallback('changeZoom', function(data, cb)
    local distance = tonumber(data.distance) or 2.4
    if previewCam and savedCoords then
        camDistance = distance
        UpdateCameraPosition()
    end
    cb('ok')
end)

-- ============================================================================
-- 👁️ SECCIÓN VISUALES Y SHARDS (NATIVOS RDR2)
-- ============================================================================

local _UI_FEED_POST_LOCATION_SHARD = 0xD05590C1AB38F068
local _UI_FEED_POST_TWO_TEXT_SHARD = 0xA6F4216AB10EB08E
local _SET_HUD_PRESET = 0x4CC5F2FC1332577F
local _REMOVE_HUD_PRESET = 0x8BC7C1F929D057CC

function SetHudPreset(name, active)
    local hash = GetHashKey(name)
    if active then
        Citizen.InvokeNative(_SET_HUD_PRESET, hash)
    else
        Citizen.InvokeNative(_REMOVE_HUD_PRESET, hash)
    end
end

function ShowLocationShard(title, subTitle, duration)
    local dur = duration or 5000
    local data = DataView.ArrayBuffer(104)
    data:SetInt32(0, dur)
    local info = DataView.ArrayBuffer(64)
    local titleVar = CreateVarString(10, "LITERAL_STRING", title)
    local subVar = CreateVarString(10, "LITERAL_STRING", subTitle or "")
    info:SetInt64(8, titleVar)
    info:SetInt64(16, subVar)
    Citizen.InvokeNative(_UI_FEED_POST_LOCATION_SHARD, data:Buffer(), info:Buffer(), true)
end

function ShowTwoTextShard(title, subTitle, duration)
    local dur = duration or 5000
    SetHudPreset("HUD_CTX_IN_MISSION_TASK", true)
    
    local data = DataView.ArrayBuffer(104)
    data:SetInt32(0, dur)
    local info = DataView.ArrayBuffer(64)
    local titleVar = CreateVarString(10, "LITERAL_STRING", title)
    local subVar = CreateVarString(10, "LITERAL_STRING", subTitle or "")
    info:SetInt64(8, titleVar)
    info:SetInt64(16, subVar)
    
    Citizen.InvokeNative(_UI_FEED_POST_TWO_TEXT_SHARD, data:Buffer(), info:Buffer(), true)
    
    Citizen.SetTimeout(dur, function()
        SetHudPreset("HUD_CTX_IN_MISSION_TASK", false)
    end)
end

-- Callback para reproducir AnimPostFX
RegisterNUICallback('playPostFX', function(data, cb)
    local effectName = data.effect
    if effectName then
        AnimpostfxPlay(effectName)
    end
    cb('ok')
end)

-- Callback para detener AnimPostFX
RegisterNUICallback('stopPostFX', function(data, cb)
    local effectName = data.effect
    if effectName then
        AnimpostfxStop(effectName)
    end
    cb('ok')
end)

-- Callback para detener todos los AnimPostFX
RegisterNUICallback('stopAllPostFX', function(data, cb)
    AnimpostfxStopAll()
    cb('ok')
end)

-- --- WANTED UI SYSTEM (Estilo torp_weed / torp_telegrama) ---
local WantedUI = {
    messages = {
        [1] = {},
        [2] = {},
        [3] = {}
    }
}
local isWantedShowing = false

Citizen.CreateThread(function()
    local wanted_label = "LAW_UI_WANTED_M" 
    WantedUI.wanted = DatabindingAddDataContainerFromPath("", "wanted")
    WantedUI.showBountyHunterMessage = DatabindingAddDataBool(WantedUI.wanted, "showBountyHunterMessage", false)
    WantedUI.messages[1].container = DatabindingAddDataContainer(WantedUI.wanted, "firstMessage")
    WantedUI.messages[2].container = DatabindingAddDataContainer(WantedUI.wanted, "secondMessage")
    WantedUI.messages[3].container = DatabindingAddDataContainer(WantedUI.wanted, "thirdMessage")
    
    for i, v in pairs(WantedUI.messages) do
        v.show = DatabindingAddDataBool(v.container, "showMessage", false)
        v.upperLocText = DatabindingAddDataString(v.container, "upperLocText", wanted_label)
        v.upperTextStyle = DatabindingAddDataInt(v.container, "upperTextStyle", 0)
        v.lowerText0 = DatabindingAddDataString(v.container, "lowerText0", "")
        v.lowerText1 = DatabindingAddDataString(v.container, "lowerText1", "")
        v.lowerText2 = DatabindingAddDataString(v.container, "lowerText2", "")
        v.lowerText3 = DatabindingAddDataString(v.container, "lowerText3", "")
        v.lowerRawText0 = DatabindingAddDataString(v.container, "lowerRawText0", "")
        v.lowerRawText1 = DatabindingAddDataString(v.container, "lowerRawText1", "")
        v.lowerRawText2 = DatabindingAddDataString(v.container, "lowerRawText2", "")
        v.lowerRawText3 = DatabindingAddDataString(v.container, "lowerRawText3", "")
        v.switchLowerTextToIndex = DatabindingAddDataInt(v.container, "switchLowerTextToIndex", 0)
        v.showKnownPulse = DatabindingAddDataBool(v.container, "showKnownPulse", false)
        v.showUnknownPulse = DatabindingAddDataBool(v.container, "showUnknownPulse", false)
        v.showShortWantedCooldown = DatabindingAddDataBool(v.container, "showShortWantedCooldown", false)
        v.showLongWantedCooldown = DatabindingAddDataBool(v.container, "showLongWantedCooldown", false)
        v.showWarningAnimation = DatabindingAddDataBool(v.container, "showWarningAnimation", false)
    end
end)

function WantedUI:ShowMessage(index, bool)
    if index < 0 or index > 3 then return end
    if index == 0 or index == nil then
        for i, message in pairs(self.messages) do
            message.show = DatabindingAddDataBool(message.container, "showMessage", bool or false)
        end
    else
        for i, message in pairs(self.messages) do
            message.show = DatabindingAddDataBool(message.container, "showMessage", i == index and bool or false)
        end
    end
end

function WantedUI:SetMainTextLabel(index, label)
    if self.messages[index] == nil then return end
    self.messages[index].upperLocText = DatabindingAddDataString(self.messages[index].container, "upperLocText", label)
end

function WantedUI:SetLowerTextRawText(index, index_2, string)
    if self.messages[index] == nil then return end
    if index_2 < 0 or index_2 > 3 then return end
    if index_2 == 0 then
        self.messages[index].lowerRawText0 = DatabindingAddDataString(self.messages[index].container, "lowerRawText0", string)
    elseif index_2 == 1 then
        self.messages[index].lowerRawText1 = DatabindingAddDataString(self.messages[index].container, "lowerRawText1", string)
    elseif index_2 == 2 then
        self.messages[index].lowerRawText2 = DatabindingAddDataString(self.messages[index].container, "lowerRawText2", string)
    elseif index_2 == 3 then
        self.messages[index].lowerRawText3 = DatabindingAddDataString(self.messages[index].container, "lowerRawText3", string)
    end
end

function WantedUI:ShowKnownPulse(index, bool)
    if self.messages[index] == nil then return end
    self.messages[index].showKnownPulse = DatabindingAddDataBool(self.messages[index].container, "showKnownPulse", bool)
end

function ForceWantedStatus()
    local player = PlayerId()
    local playerPed = PlayerPedId()
    Citizen.InvokeNative(0x462E0196826435D3, 5) 
    ClearPlayerWantedLevel(player)
    Wait(10)
    local crimeHash = 23777478 
    Citizen.InvokeNative(0x5B56D91A, player, crimeHash, 1000, playerPed, true) 
    Citizen.InvokeNative(0xB7A0914B, player, 5, false) 
    Citizen.InvokeNative(0xE0A7D1E497FFCD6F, player, false) 
    Citizen.InvokeNative(0x8D9DF7E20B5A79E6, "WANTED_MUSIC") 
end

function ShowWantedText()
    isWantedShowing = true
    Citizen.CreateThread(function()
        local endTime = GetGameTimer() + 5000 
        while GetGameTimer() < endTime and isWantedShowing do
            local str = CreateVarString(10, "LITERAL_STRING", "WANTED")
            Citizen.InvokeNative(0x16794E044C9686DD, str, 0.5, 0.2, 5, 3.0, 180, 0, 0, 255, true)
            Wait(0)
        end
    end)
end

-- Callback para probar Estado Se Busca (Wanted) - Corregido para RDR2 estilo torp_weed
RegisterNUICallback('testWanted', function(data, cb)
    local active = data.active
    local reason = data.reason or "ROBO A MANO ARMADA"
    
    if active then
        ForceWantedStatus()
        WantedUI:SetMainTextLabel(1, "LAW_UI_WANTED_M")
        WantedUI:SetLowerTextRawText(1, 0, reason)
        WantedUI:ShowMessage(1, true)
        WantedUI:ShowKnownPulse(1, true)
        ShowWantedText()
    else
        isWantedShowing = false
        WantedUI:ShowMessage(1, false)
        ClearPlayerWantedLevel(PlayerId())
    end
    cb('ok')
end)

-- Callback para probar Shards Visuales
RegisterNUICallback('testShard', function(data, cb)
    local shardType = data.type -- 'location' o 'task'
    local title = data.title or "TITULO DE PRUEBA"
    local subtitle = data.subtitle or "Subtítulo de prueba"
    local duration = tonumber(data.duration) or 5000
    
    if shardType == 'location' then
        ShowLocationShard(title, subtitle, duration)
    elseif shardType == 'task' then
        ShowTwoTextShard(title, subtitle, duration)
    end
    cb('ok')
end)

-- ============================================================================
-- 📋 NUEVOS CONTENIDOS HUD, TIMERS Y UIAPPs
-- ============================================================================

local helperRoot = nil
local helperActive = false
local helperFields = {
    [0] = { label = nil, value = nil },
    [1] = { label = nil, value = nil },
    [2] = { label = nil, value = nil }
}
local passiveRoot = nil
local passiveVisible = nil
local passiveState = nil
local countdownContainer = nil
local countdownString = nil
local countdownBool = nil
local countdownActive = false

-- Hilo para mantener visible el contexto HUD helperTextfields cada frame
Citizen.CreateThread(function()
    while true do
        if helperActive then
            Citizen.InvokeNative(0xC9CAEAEEC1256E54, -66088566)
        end
        Wait(0)
    end
end)

-- Helper Text Fields (Datastore helperTextfields)
RegisterNUICallback('testHelperText', function(data, cb)
    local active = data.active
    if active then
        local fields = data.fields or {}
        if not helperRoot then
            helperRoot = DatabindingAddDataContainerFromPath("", "helperTextfields")
        end
        for i = 0, 2 do
            local field = fields[i + 1]
            local lbl = field and field.label or ""
            local val = field and field.value or ""
            
            -- Si la propiedad Label no existe, la creamos
            if not helperFields[i].label then
                helperFields[i].label = DatabindingAddDataString(helperRoot, "rawLabel" .. i, lbl)
            else
                -- Si ya existe, actualizamos su valor de forma dinámica
                DatabindingWriteDataString(helperFields[i].label, lbl)
            end
            
            -- Si la propiedad Value no existe, la creamos
            if not helperFields[i].value then
                helperFields[i].value = DatabindingAddDataString(helperRoot, "rawValue" .. i, val)
            else
                -- Si ya existe, actualizamos su valor
                DatabindingWriteDataString(helperFields[i].value, val)
            end
        end
        helperActive = true
    else
        helperActive = false
    end
    cb('ok')
end)

-- Countdown Timer (Datastore MPCountdown)
RegisterNUICallback('testCountdown', function(data, cb)
    local active = data.active
    local duration = tonumber(data.duration) or 10
    
    if active then
        countdownActive = false
        Wait(50)
        countdownActive = true
        Citizen.CreateThread(function()
            if not countdownContainer then
                countdownContainer = DatabindingAddDataContainerFromPath("", "MPCountdown")
            end
            if not countdownString then
                countdownString = DatabindingAddDataString(countdownContainer, "Timer", tostring(duration))
            else
                DatabindingWriteDataString(countdownString, tostring(duration))
            end
            if not countdownBool then
                countdownBool = DatabindingAddDataBool(countdownContainer, "showTimer", true)
            else
                DatabindingWriteDataBool(countdownBool, true)
            end
            
            local remaining = duration
            while remaining >= 0 and countdownActive do
                DatabindingWriteDataString(countdownString, tostring(remaining))
                Wait(1000)
                remaining = remaining - 1
            end
            
            if countdownBool then
                DatabindingWriteDataBool(countdownBool, false)
            end
            countdownActive = false
        end)
    else
        countdownActive = false
        if countdownBool then
            DatabindingWriteDataBool(countdownBool, false)
        end
    end
    cb('ok')
end)

-- Passive Icon (Datastore PassiveIcon)
RegisterNUICallback('testPassiveIcon', function(data, cb)
    local active = data.active
    if not passiveRoot then
        passiveRoot = DatabindingAddDataContainerFromPath("", "PassiveIcon")
    end
    
    if not passiveVisible then
        passiveVisible = DatabindingAddDataBool(passiveRoot, "isVisible", active)
    else
        DatabindingWriteDataBool(passiveVisible, active)
    end
    
    if not passiveState then
        passiveState = DatabindingAddDataInt(passiveRoot, "setState", 1)
    else
        DatabindingWriteDataInt(passiveState, active and 1 or 0)
    end
    
    cb('ok')
end)

-- UI Apps (Launch / Close UI Application)
local _LAUNCH_UIAPP_BY_HASH = 0xC8FC7F4E4CF4F581
local _CLOSE_UIAPP_BY_HASH = 0x2FF10C9C3F92277E

RegisterNUICallback('testUiApp', function(data, cb)
    local appName = data.name or "opening_credits_sequence"
    local active = data.active
    local hash = GetHashKey(appName)
    if active then
        Citizen.InvokeNative(_LAUNCH_UIAPP_BY_HASH, hash)
    else
        Citizen.InvokeNative(_CLOSE_UIAPP_BY_HASH, hash)
    end
    cb('ok')
end)

-- Limpieza automática de foco NUI, cámara y HUD al detener/reiniciar recurso
AddEventHandler('onResourceStop', function(resourceName)
    if GetCurrentResourceName() ~= resourceName then return end

    -- PRIMERO: Liberar el foco NUI y el ratón ANTES de cualquier otra cosa
    menuOpen = false
    SetNuiFocus(false, false)
    SetNuiFocus(false, false) -- Doble llamada por seguridad

    -- Limpiar cámara de preview (envuelto en pcall para que nunca falle)
    pcall(function()
        if previewCam then
            RenderScriptCams(false, false, 0, true, true)
            DestroyCam(previewCam, false)
            previewCam = nil
        end
    end)

    -- Limpiar HUD elements (envuelto en pcall individual por si alguno es nil)
    pcall(function()
        if helperRoot then Citizen.InvokeNative(0xF9352125F75E0160, -66088566) end
    end)
    pcall(function()
        if countdownBool then DatabindingWriteDataBool(countdownBool, false) end
    end)
    pcall(function()
        if passiveVisible then DatabindingWriteDataBool(passiveVisible, false) end
    end)
    pcall(function()
        isWantedShowing = false
        if WantedUI then WantedUI:ShowMessage(1, false) end
    end)
    pcall(function()
        ClearPlayerWantedLevel(PlayerId())
    end)

    -- ÚLTIMO: Una tercera llamada de seguridad por si algún pcall reactivó algo
    SetNuiFocus(false, false)
end)
