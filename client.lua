-- Remote events:
addEvent("voice_local:onClientPlayerVoiceStart", true)
addEvent("voice_local:onClientPlayerVoiceStop", true)
addEvent("voice_local:updateSettings", true)
addEvent("voice_local:setVoiceMode", true)
addEvent("voice_local:requestBroadcastRefresh", true)
addEvent("voice_local:playRadioRoger", true)
addEvent("voice_local:playRadioRogerNearby", true)

-- Only starts handling player voices after receiving the settings from the server
local initialWaiting = true

local streamedPlayers = {}
local localPlayerTalking = false
local voiceMode = "general"
local voicePartner = nil
local radioType = nil
local radioFreq = nil

local sx, sy = guiGetScreenSize()

local devSX, devSY = sx / 1920, sy / 1080
local iconWidth = 108 * devSX
local iconHalfWidth = iconWidth / 2
local iconHeight = 180 * devSY
local iconHalfHeight = iconHeight / 2
local iconTexture = dxCreateTexture("icon.png", "dxt5", true, "clamp")

local function drawTalkingIcon(player, camDistToPlayer)
    local boneX, boneY, boneZ = getPedBonePosition(player, 8)
    local screenX, screenY = getScreenFromWorldPosition(boneX, boneY, boneZ + 0.4)
    if screenX and screenY then
        local factor = 1 / camDistToPlayer
        dxDrawImage(
            screenX - iconHalfWidth * factor,
            screenY - iconHalfHeight * factor,
            iconWidth * factor,
            iconHeight * factor,
            iconTexture, 0, 0, 0, -1, false
        )
    end
end

local function handlePreRender()
    local debugY = 50
    local maxDistance = settings.maxVoiceDistance.value
    local cameraX, cameraY, cameraZ = getCameraMatrix()
    local localPlayerX, localPlayerY, localPlayerZ = getElementPosition(localPlayer)
    for player, talking in pairs(streamedPlayers) do
        local otherPlayerX, otherPlayerY, otherPlayerZ = getElementPosition(player)
        local realDistanceToPlayer = getDistanceBetweenPoints3D(localPlayerX, localPlayerY, localPlayerZ, otherPlayerX, otherPlayerY, otherPlayerZ)
        local playerVolume
        if voiceMode == "call" or voiceMode == "private" then
            if player == voicePartner then
                playerVolume = 1.0
            else
                playerVolume = 0.0
            end
        elseif voiceMode == "radio" then
            local otherType = getElementData(player, "voice:radioType")
            local otherFreq = getElementData(player, "voice:radioFreq")
            if radioType and radioFreq and otherType == radioType and tonumber(otherFreq) == radioFreq then
                playerVolume = 1.0
            else
                if (realDistanceToPlayer >= maxDistance) then
                    playerVolume = 0.0
                else
                    playerVolume = (1.0 - (realDistanceToPlayer / maxDistance)^2)
                end
            end
        else
            if (realDistanceToPlayer >= maxDistance) then
                playerVolume = 0.0
            else
                playerVolume = (1.0 - (realDistanceToPlayer / maxDistance)^2)
            end
        end

        -- Voice voume is usually unfortunately very low, resulting in players
        -- barely hearing others if we set the player voice volume to 1.0
        -- So we need to increase it to like 6.0 to make it audible
        playerVolume = playerVolume * settings.voiceSoundBoost.value

        setSoundVolume(player, playerVolume)

        if DEBUG_MODE then
            dxDrawRectangle(20, debugY - 5, 300, 25, tocolor(0, 0, 0, 200))
            dxDrawText(("%s | Distance: %.2f | Voice Volume: %.2f"):format(getPlayerName(player), realDistanceToPlayer, playerVolume), 30, debugY)
            debugY = debugY + 15
        end

        if talking and (settings.showTalkingIcon.value == true)
        and (voiceMode ~= "general" or realDistanceToPlayer < maxDistance)
        and (voiceMode ~= "general" or isLineOfSightClear(cameraX, cameraY, cameraZ, otherPlayerX, otherPlayerY, otherPlayerZ, false, false, false, false, true, true, true, localPlayer)) then
            drawTalkingIcon(player, getDistanceBetweenPoints3D(cameraX, cameraY, cameraZ, otherPlayerX, otherPlayerY, otherPlayerZ))
        end
    end
    if localPlayerTalking and (settings.showTalkingIcon.value == true) then
        drawTalkingIcon(localPlayer, getDistanceBetweenPoints3D(cameraX, cameraY, cameraZ, localPlayerX, localPlayerY, localPlayerZ))
    end
end

local function computeDistanceVolume(distance, maxDistance)
    if distance >= maxDistance then
        return 0.0
    end
    return (1.0 - (distance / maxDistance)^2)
end

addEventHandler("onClientResourceStart", resourceRoot, function()
    for _, player in pairs(getElementsByType("player", root, true)) do
        if player ~= localPlayer and streamedPlayers[player] == nil then
            setSoundVolume(player, 0)
            streamedPlayers[player] = false
        end
    end
    triggerServerEvent("voice_local:setPlayerBroadcast", localPlayer, streamedPlayers)
end, false)

-- Handle remote/other player quit
addEventHandler("onClientPlayerQuit", root, function()
    if streamedPlayers[source] ~= nil then
        streamedPlayers[source] = nil
        triggerServerEvent("voice_local:removeFromPlayerBroadcast", localPlayer, source)
    end
end)

-- Code considers this event's problem @ "Note" box: https://wiki.multitheftauto.com/wiki/OnClientElementStreamIn
-- It should be modified if said behavior ever changes
addEventHandler("onClientElementStreamIn", root, function()
    if source == localPlayer then return end
    if not (isElement(source) and getElementType(source) == "player") then return end

    if isPedDead(source) then return end

    if streamedPlayers[source] == nil then
        setSoundVolume(source, 0)
        streamedPlayers[source] = false
        if not ((voiceMode == "call" or voiceMode == "private") and source == voicePartner) then
            triggerServerEvent("voice_local:addToPlayerBroadcast", localPlayer, source)
        end
    end
end)
addEventHandler("onClientElementStreamOut", root, function()
    if source == localPlayer then return end
    if not (isElement(source) and getElementType(source) == "player") then return end

    if (voiceMode == "call" or voiceMode == "private") and source == voicePartner then
        return
    end

    if streamedPlayers[source] ~= nil then
        setSoundVolume(source, 0)
        streamedPlayers[source] = nil
        triggerServerEvent("voice_local:removeFromPlayerBroadcast", localPlayer, source)
    end
end)

-- Update player talking status (for displaying)
addEventHandler("voice_local:onClientPlayerVoiceStart", root, function(player)
    if not (isElement(player) and getElementType(player) == "player") then return end

    if player == localPlayer then
        localPlayerTalking = true
    elseif streamedPlayers[player] ~= nil then
        streamedPlayers[player] = true
    end
end)
addEventHandler("voice_local:onClientPlayerVoiceStop", root, function(player)
    if not (isElement(player) and getElementType(player) == "player") then return end

    if player == localPlayer then
        localPlayerTalking = false
    elseif streamedPlayers[player] ~= nil then
        streamedPlayers[player] = false
    end
end)

-- Load the settings received from the server
addEventHandler("voice_local:updateSettings", localPlayer, function(settingsFromServer)
    settings = settingsFromServer

    if initialWaiting then
        addEventHandler("onClientPreRender", root, handlePreRender, false)
        initialWaiting = false
    end
end, false)

addEventHandler("voice_local:setVoiceMode", localPlayer, function(mode, partner, freq)
    voiceMode = mode or "general"
    voicePartner = (isElement(partner) and getElementType(partner) == "player") and partner or nil

    if voiceMode == "radio" and type(partner) == "string" then
        radioType = partner
        radioFreq = tonumber(freq)
    elseif voiceMode ~= "radio" then
        radioType = nil
        radioFreq = nil
    end

    if (voiceMode == "call" or voiceMode == "private") and voicePartner then
        if streamedPlayers[voicePartner] == nil then
            streamedPlayers[voicePartner] = false
        end
        setSoundVolume(voicePartner, settings.voiceSoundBoost.value or 1.0)
    end
end, false)

addEventHandler("voice_local:requestBroadcastRefresh", localPlayer, function()
    triggerServerEvent("voice_local:setPlayerBroadcast", localPlayer, streamedPlayers)
end, false)

addEventHandler("voice_local:playRadioRoger", root, function()
    if voiceMode ~= "radio" then
        return
    end
    local soundPath = "faction-roger.mp3"
    if radioType == "police" then
        soundPath = "police-roger.mp3"
    end
    local sound = playSound(soundPath)
    if sound then
        setSoundVolume(sound, 0.6)
    end
end)

addEventHandler("voice_local:playRadioRogerNearby", root, function(sourcePlayer)
    if not (isElement(sourcePlayer) and getElementType(sourcePlayer) == "player") then
        return
    end
    if sourcePlayer == localPlayer then
        return
    end

    local sourceType = getElementData(sourcePlayer, "voice:radioType")
    local sourceFreq = getElementData(sourcePlayer, "voice:radioFreq")
    if voiceMode == "radio" and radioType and radioFreq and sourceType == radioType and tonumber(sourceFreq) == radioFreq then
        return
    end

    local maxDistance = settings.maxVoiceDistance.value
    local localX, localY, localZ = getElementPosition(localPlayer)
    local sourceX, sourceY, sourceZ = getElementPosition(sourcePlayer)
    local distance = getDistanceBetweenPoints3D(localX, localY, localZ, sourceX, sourceY, sourceZ)
    local volume = computeDistanceVolume(distance, maxDistance) * settings.voiceSoundBoost.value
    if volume <= 0.0 then
        return
    end

    local soundPath = "faction-roger.mp3"
    if sourceType == "police" then
        soundPath = "police-roger.mp3"
    end

    local sound = playSound(soundPath)
    if sound then
        if volume > 1.0 then
            volume = 1.0
        end
        setSoundVolume(sound, volume)
    end
end)
