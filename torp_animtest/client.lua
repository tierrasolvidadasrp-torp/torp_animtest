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
            -- Deshabilitar movimiento (WASD, saltar, correr) para evitar desplazamientos accidentales
            DisableControlAction(0, 0x5997C630, true) -- MOVE_LR
            DisableControlAction(0, 0x3D77B13B, true) -- MOVE_UD
            DisableControlAction(0, 0x8FFC75D6, true) -- SPRINT
            DisableControlAction(0, 0xD45CEE5C, true) -- JUMP
            DisableControlAction(0, 0xD7963AA4, true) -- ATTACK
            DisableControlAction(0, 0xF84FA74F, true) -- AIM
        else
            Citizen.Wait(250)
        end
        Citizen.Wait(0)
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

-- Limpieza automática del foco NUI y cámara al reiniciar el recurso
AddEventHandler('onResourceStop', function(resourceName)
    if GetCurrentResourceName() == resourceName then
        SetNuiFocus(false, false)
        if previewCam then
            RenderScriptCams(false, false, 0, true, true)
            DestroyCam(previewCam, false)
            previewCam = nil
        end
    end
end)
