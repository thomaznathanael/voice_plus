-- Remote events:
addEvent("voice_local:onClientPlayerVoiceStart", true)
addEvent("voice_local:onClientPlayerVoiceStop", true)
addEvent("voice_local:updateSettings", true)
addEvent("voice_local:setVoiceMode", true)
addEvent("voice_local:requestBroadcastRefresh", true)
addEvent("voice_local:playRadioRoger", true)
addEvent("voice_local:playRadioRogerNearby", true)
addEvent("voice_local:setRadioVolume", true)
addEvent("voice_plus:onClientTxStart")
addEvent("voice_plus:onClientTxStop")
addEvent("voice_plus:onClientRxStart")
addEvent("voice_plus:onClientRxStop")
addEvent("voice_plus:onClientRadioVolumeChange")
addEvent("voice_plus:set_radio_volume")

-- Only starts handling player voices after receiving the settings from the server
local initialWaiting = true

local streamedPlayers = {}
local localPlayerTalking = false
local voiceMode = "general"
local voicePartner = nil
local radioType = nil
local radioFreq = nil
local radioTxActive = false
local localRadioTxTalking = false
local localRadioTxMode = nil
local localRadioTxPartner = nil
local localRadioTxType = nil
local localRadioTxFreq = nil
local radioRxActive = {}
local DEFAULT_RADIO_VOLUME_LEVEL = 3
local RADIO_VOLUME_LEVELS = {
    [0] = {label="off", scale=0.0},
    [1] = {label="low", scale=0.3},
    [2] = {label="medium", scale=0.6},
    [3] = {label="high", scale=1.0},
}
local localRadioVolumeLevel = DEFAULT_RADIO_VOLUME_LEVEL
local localRadioVolumeScale = RADIO_VOLUME_LEVELS[DEFAULT_RADIO_VOLUME_LEVEL].scale

local function clampRadioVolumeLevel(level)
    local value = tonumber(level)
    if not value then
        return nil
    end
    value = math.floor(value)
    if value < 0 then
        value = 0
    elseif value > 3 then
        value = 3
    end
    return value
end

local function getRadioVolumeScaleForLevel(level)
    local data = RADIO_VOLUME_LEVELS[level]
    if data then
        return data.scale
    end
    return RADIO_VOLUME_LEVELS[DEFAULT_RADIO_VOLUME_LEVEL].scale
end

local function getPlayerRadioVolumeScale(player)
    local level = getElementData(player, "voice:radioVolume")
    return getRadioVolumeScaleForLevel(level)
end

local function playVolumeChangeSfx(scale)
    local volumeScale = tonumber(scale) or 1.0
    if volumeScale <= 0.0 then
        return
    end
    local sound = playSound("vol.mp3")
    if sound then
        setSoundVolume(sound, 0.6 * volumeScale)
    end
end

local function setLocalRadioVolume(level, playSfx)
    local newLevel = clampRadioVolumeLevel(level)
    if newLevel == nil then
        return nil
    end
    if newLevel == localRadioVolumeLevel then
        return newLevel
    end
    localRadioVolumeLevel = newLevel
    localRadioVolumeScale = getRadioVolumeScaleForLevel(newLevel)
    if playSfx then
        playVolumeChangeSfx(localRadioVolumeScale)
    end
    triggerEvent("voice_plus:onClientRadioVolumeChange", localPlayer, localRadioVolumeLevel, localRadioVolumeScale)
    return newLevel
end

local function requestRadioVolume(level)
    local newLevel = setLocalRadioVolume(level, true)
    if newLevel == nil then
        return
    end
    triggerServerEvent("voice_local:setRadioVolume", localPlayer, newLevel)
end

local function cacheRadioTxInfo()
    localRadioTxMode = voiceMode
    localRadioTxPartner = voicePartner
    localRadioTxType = radioType
    localRadioTxFreq = radioFreq
end

local function isSameRadioChannel(otherType, otherFreq, otherTx)
    if voiceMode ~= "radio" then
        return false
    end
    if not radioType or not radioFreq then
        return false
    end
    if otherTx ~= true then
        return false
    end
    if otherType ~= radioType then
        return false
    end
    return tonumber(otherFreq) == radioFreq
end

local function startRadioRx(player, otherType, otherFreq, otherTx)
    if radioRxActive[player] then
        return
    end
    local freq = tonumber(otherFreq)
    radioRxActive[player] = {
        otherType = otherType,
        otherFreq = freq,
        otherTx = otherTx == true,
    }
    triggerEvent("voice_plus:onClientRxStart", localPlayer, player, otherType, freq, otherTx == true)
end

local function stopRadioRx(player)
    local data = radioRxActive[player]
    if not data then
        return
    end
    radioRxActive[player] = nil
    triggerEvent("voice_plus:onClientRxStop", localPlayer, player, data.otherType, data.otherFreq, data.otherTx)
end

local function stopAllRadioRx()
    for player in pairs(radioRxActive) do
        stopRadioRx(player)
    end
end

local function syncRadioRxForCurrentTalkers()
    if voiceMode ~= "radio" or not radioType or not radioFreq then
        return
    end
    for player, talking in pairs(streamedPlayers) do
        if talking == true then
            local otherType = getElementData(player, "voice:radioType")
            local otherFreq = getElementData(player, "voice:radioFreq")
            local otherTx = getElementData(player, "voice:radioTx")
            if isSameRadioChannel(otherType, otherFreq, otherTx) then
                startRadioRx(player, otherType, otherFreq, otherTx)
            end
        end
    end
end

local sx, sy = guiGetScreenSize()

local devSX, devSY = sx / 1920, sy / 1080
local talkRingTexture = dxCreateTexture("ring.png", "dxt5", true, "clamp")
local talkRingRadioTexture = dxCreateTexture("ring-radio.png", "dxt5", true, "clamp")
local talkRingPhoneTexture = dxCreateTexture("ring-telefone.png", "dxt5", true, "clamp")
local talkRingSize = 0.6
local talkRingColor = tocolor(255, 255, 255, 220)

local function resolveTalkRingTexture(ringStyle)
    if ringStyle == "phone" and isElement(talkRingPhoneTexture) then
        return talkRingPhoneTexture
    end
    if ringStyle == "radio" and isElement(talkRingRadioTexture) then
        return talkRingRadioTexture
    end
    if isElement(talkRingTexture) then
        return talkRingTexture
    end
    return nil
end

local function drawTalkRing(player, ringStyle)
    local texture = resolveTalkRingTexture(ringStyle)
    if not texture then
        return
    end
    local px, py, pz = getElementPosition(player)
    local z = pz - 0.98
    dxDrawMaterialLine3D(
        px - talkRingSize, py, z,
        px + talkRingSize, py, z,
        texture,
        talkRingSize * 2,
        talkRingColor,
        false,
        px, py, z + 1.0
    )
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
            local otherTx = getElementData(player, "voice:radioTx")
            if radioType and radioFreq and otherType == radioType and tonumber(otherFreq) == radioFreq and otherTx == true then
                playerVolume = localRadioVolumeScale
            else
                if (realDistanceToPlayer >= maxDistance) then
                    playerVolume = 0.0
                else
                    playerVolume = (1.0 - (realDistanceToPlayer / maxDistance)^2)
                end
                if otherTx == true then
                    playerVolume = playerVolume * getPlayerRadioVolumeScale(player)
                end
            end
        else
            if (realDistanceToPlayer >= maxDistance) then
                playerVolume = 0.0
            else
                playerVolume = (1.0 - (realDistanceToPlayer / maxDistance)^2)
            end
            local otherTx = getElementData(player, "voice:radioTx")
            if otherTx == true then
                playerVolume = playerVolume * getPlayerRadioVolumeScale(player)
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
            local ringStyle = nil
            if voiceMode == "call" and player == voicePartner then
                ringStyle = "phone"
            else
                local otherTx = getElementData(player, "voice:radioTx")
                if otherTx == true then
                    ringStyle = "radio"
                end
            end
            drawTalkRing(player, ringStyle)
        end
    end
    if localPlayerTalking and (settings.showTalkingIcon.value == true) then
        local ringStyle = nil
        if voiceMode == "call" then
            ringStyle = "phone"
        elseif radioTxActive == true then
            ringStyle = "radio"
        end
        drawTalkRing(localPlayer, ringStyle)
    end
end

local function computeDistanceVolume(distance, maxDistance)
    if distance >= maxDistance then
        return 0.0
    end
    return (1.0 - (distance / maxDistance)^2)
end

local function setRadioTxState(state)
    if voiceMode ~= "radio" or not radioType or not radioFreq then
        return
    end
    radioTxActive = state == true
    triggerServerEvent("voice_local:setRadioTx", localPlayer, radioTxActive)
    if localPlayerTalking then
        if radioTxActive and not localRadioTxTalking then
            localRadioTxTalking = true
            cacheRadioTxInfo()
            triggerEvent("voice_plus:onClientTxStart", localPlayer, localRadioTxMode, localRadioTxPartner, localRadioTxType, localRadioTxFreq, true)
        elseif not radioTxActive and localRadioTxTalking then
            localRadioTxTalking = false
            triggerEvent("voice_plus:onClientTxStop", localPlayer, localRadioTxMode, localRadioTxPartner, localRadioTxType, localRadioTxFreq, false)
            localRadioTxMode = nil
            localRadioTxPartner = nil
            localRadioTxType = nil
            localRadioTxFreq = nil
        end
    end
end

addEventHandler("onClientResourceStart", resourceRoot, function()
    for _, player in pairs(getElementsByType("player", root, true)) do
        if player ~= localPlayer and streamedPlayers[player] == nil then
            setSoundVolume(player, 0)
            streamedPlayers[player] = false
        end
    end
    triggerServerEvent("voice_local:setPlayerBroadcast", localPlayer, streamedPlayers)

    bindKey("f2", "down", function()
        setRadioTxState(not radioTxActive)
    end)
end, false)

-- Handle remote/other player quit
addEventHandler("onClientPlayerQuit", root, function()
    if streamedPlayers[source] ~= nil then
        streamedPlayers[source] = nil
        triggerServerEvent("voice_local:removeFromPlayerBroadcast", localPlayer, source)
    end
    if radioRxActive[source] then
        stopRadioRx(source)
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
    if radioRxActive[source] then
        stopRadioRx(source)
    end
end)

-- Update player talking status (for displaying)
addEventHandler("voice_local:onClientPlayerVoiceStart", root, function(player)
    if not (isElement(player) and getElementType(player) == "player") then return end

    if player == localPlayer then
        localPlayerTalking = true
        if voiceMode == "radio" and radioTxActive == true and not localRadioTxTalking then
            localRadioTxTalking = true
            cacheRadioTxInfo()
            triggerEvent("voice_plus:onClientTxStart", localPlayer, localRadioTxMode, localRadioTxPartner, localRadioTxType, localRadioTxFreq, true)
        end
    elseif streamedPlayers[player] ~= nil then
        streamedPlayers[player] = true
        local otherType = getElementData(player, "voice:radioType")
        local otherFreq = getElementData(player, "voice:radioFreq")
        local otherTx = getElementData(player, "voice:radioTx")
        if isSameRadioChannel(otherType, otherFreq, otherTx) then
            startRadioRx(player, otherType, otherFreq, otherTx)
        end
    end
end)
addEventHandler("voice_local:onClientPlayerVoiceStop", root, function(player)
    if not (isElement(player) and getElementType(player) == "player") then return end

    if player == localPlayer then
        localPlayerTalking = false
        if localRadioTxTalking then
            localRadioTxTalking = false
            triggerEvent("voice_plus:onClientTxStop", localPlayer, localRadioTxMode, localRadioTxPartner, localRadioTxType, localRadioTxFreq, radioTxActive == true)
            localRadioTxMode = nil
            localRadioTxPartner = nil
            localRadioTxType = nil
            localRadioTxFreq = nil
        end
    elseif streamedPlayers[player] ~= nil then
        streamedPlayers[player] = false
        if radioRxActive[player] then
            stopRadioRx(player)
        end
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

addEventHandler("voice_local:setRadioVolume", localPlayer, function(level)
    setLocalRadioVolume(level, true)
end, false)

addEventHandler("voice_plus:set_radio_volume", localPlayer, function(level)
    requestRadioVolume(level)
end, false)

addEventHandler("voice_local:setVoiceMode", localPlayer, function(mode, partner, freq)
    local previousMode = voiceMode
    local previousRadioType = radioType
    local previousRadioFreq = radioFreq
    voiceMode = mode or "general"
    voicePartner = (isElement(partner) and getElementType(partner) == "player") and partner or nil

    if voiceMode == "radio" and type(partner) == "string" then
        radioType = partner
        radioFreq = tonumber(freq)
    elseif voiceMode ~= "radio" then
        if previousMode == "radio" and localRadioTxTalking then
            localRadioTxTalking = false
            triggerEvent("voice_plus:onClientTxStop", localPlayer, localRadioTxMode, localRadioTxPartner, localRadioTxType, localRadioTxFreq, false)
            localRadioTxMode = nil
            localRadioTxPartner = nil
            localRadioTxType = nil
            localRadioTxFreq = nil
        end
        radioType = nil
        radioFreq = nil
        radioTxActive = false
        setRadioTxState(false)
    end

    if voiceMode == "call" or voiceMode == "private" then
        if radioTxActive == true then
            radioTxActive = false
            setRadioTxState(false)
        end
        if localRadioTxTalking then
            localRadioTxTalking = false
            triggerEvent("voice_plus:onClientTxStop", localPlayer, localRadioTxMode, localRadioTxPartner, localRadioTxType, localRadioTxFreq, false)
            localRadioTxMode = nil
            localRadioTxPartner = nil
            localRadioTxType = nil
            localRadioTxFreq = nil
        end
    end

    local channelChanged = previousMode == "radio"
        and voiceMode == "radio"
        and (previousRadioType ~= radioType or previousRadioFreq ~= radioFreq)

    if channelChanged then
        if localRadioTxTalking then
            localRadioTxTalking = false
            triggerEvent("voice_plus:onClientTxStop", localPlayer, localRadioTxMode, localRadioTxPartner, localRadioTxType, localRadioTxFreq, radioTxActive == true)
            localRadioTxMode = nil
            localRadioTxPartner = nil
            localRadioTxType = nil
            localRadioTxFreq = nil
        end

        if radioTxActive == true then
            setRadioTxState(true)
        end
    end

    if voiceMode ~= "radio" then
        stopAllRadioRx()
    elseif previousMode == "radio" and (previousRadioType ~= radioType or previousRadioFreq ~= radioFreq) then
        stopAllRadioRx()
    end
    if voiceMode == "radio" then
        syncRadioRxForCurrentTalkers()
    end

    if (voiceMode == "call" or voiceMode == "private") and voicePartner then
        if streamedPlayers[voicePartner] == nil then
            streamedPlayers[voicePartner] = false
        end
        setSoundVolume(voicePartner, settings.voiceSoundBoost.value or 1.0)
    end
end, false)

addEventHandler("onClientResourceStop", resourceRoot, function()
    unbindKey("f2", "down")
end)

addEventHandler("voice_local:requestBroadcastRefresh", localPlayer, function()
    triggerServerEvent("voice_local:setPlayerBroadcast", localPlayer, streamedPlayers)
end, false)

addEventHandler("voice_local:playRadioRoger", root, function()
    if voiceMode ~= "radio" or voiceMode == "call" or voiceMode == "private" then
        return
    end
    if localRadioVolumeScale <= 0.0 then
        return
    end
    local soundPath = "faction-roger.mp3"
    if radioType == "police" then
        soundPath = "police-roger.mp3"
    end
    local sound = playSound(soundPath)
    if sound then
        setSoundVolume(sound, 0.6 * localRadioVolumeScale)
    end
end)

addEventHandler("voice_local:playRadioRogerNearby", root, function(sourcePlayer)
    if voiceMode == "call" or voiceMode == "private" then
        return
    end
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
    local volume = computeDistanceVolume(distance, maxDistance) * 0.1
    if volume <= 0.0 then
        return
    end

    local soundPath = "faction-roger.mp3"
    if sourceType == "police" then
        soundPath = "police-roger.mp3"
    end
    local radioScale = getPlayerRadioVolumeScale(sourcePlayer)
    if radioScale <= 0.0 then
        return
    end
    volume = volume * radioScale

    local sound = playSound(soundPath)
    if sound then
        if volume > 1.0 then
            volume = 1.0
        end
        setSoundVolume(sound, volume)
    end
end)
