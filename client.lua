local initialWaiting = true
local streamedPlayers = {}
local localPlayerTalking = false
local settings = {}

local sx, sy = guiGetScreenSize()
local devSX, devSY = sx / 1920, sy / 1080
local iconWidth, iconHeight = 108 * devSX, 180 * devSY
local iconTexture = dxCreateTexture("icon.png", "dxt5", true, "clamp")

local function drawTalkingIcon(player, camDistToPlayer)
    local boneX, boneY, boneZ = getPedBonePosition(player, 8)
    local screenX, screenY = getScreenFromWorldPosition(boneX, boneY, boneZ + 0.4)
    if screenX and screenY then
        local factor = 1 / camDistToPlayer
        dxDrawImage(screenX - (iconWidth/2) * factor, screenY - (iconHeight/2) * factor, iconWidth * factor, iconHeight * factor, iconTexture, 0, 0, 0, -1, false)
    end
end

local function handlePreRender()
    if not settings.maxVoiceDistance then return end
    
    local maxDistance = settings.maxVoiceDistance.value
    local camX, camY, camZ = getCameraMatrix()
    local lpX, lpY, lpZ = getElementPosition(localPlayer)
    local myChannel = getElementData(localPlayer, "voice:channel")

    for player, talking in pairs(streamedPlayers) do
        if isElement(player) then
            local pX, pY, pZ = getElementPosition(player)
            local dist = getDistanceBetweenPoints3D(lpX, lpY, lpZ, pX, pY, pZ)
            local targetChannel = getElementData(player, "voice:channel")
            
            local volume = 0
            
            -- LÓGICA DE CANAL vs PROXIMIDADE
            if myChannel and targetChannel and myChannel == targetChannel then
                volume = 1.0 -- Canal privado ignora distância
            elseif dist < maxDistance then
                volume = (1.0 - (dist / maxDistance)^2)
            end

            setSoundVolume(player, volume * settings.voiceSoundBoost.value)

            if talking and (settings.showTalkingIcon.value == true) and (dist < maxDistance or (myChannel and targetChannel == myChannel)) then
                local camDist = getDistanceBetweenPoints3D(camX, camY, camZ, pX, pY, pZ)
                drawTalkingIcon(player, camDist)
            end
        end
    end

    if localPlayerTalking and (settings.showTalkingIcon.value == true) then
        drawTalkingIcon(localPlayer, 1)
    end
end

-- Gerenciamento de Stream (original)
addEventHandler("onClientElementStreamIn", root, function()
    if source == localPlayer or getElementType(source) ~= "player" then return end
    streamedPlayers[source] = false
    triggerServerEvent("voice_local:addToPlayerBroadcast", localPlayer, source)
end)

addEventHandler("onClientElementStreamOut", root, function()
    if streamedPlayers[source] ~= nil then
        streamedPlayers[source] = nil
        triggerServerEvent("voice_local:removeFromPlayerBroadcast", localPlayer, source)
    end
end)

addEventHandler("voice_local:onClientPlayerVoiceStart", root, function(p)
    if p == localPlayer then localPlayerTalking = true else streamedPlayers[p] = true end
end)

addEventHandler("voice_local:onClientPlayerVoiceStop", root, function(p)
    if p == localPlayer then localPlayerTalking = false else streamedPlayers[p] = false end
end)

addEventHandler("voice_local:updateSettings", localPlayer, function(s)
    settings = s
    if initialWaiting then
        addEventHandler("onClientPreRender", root, handlePreRender, false)
        initialWaiting = false
    end
end)