-- Remote events:
addEvent("voice_local:setPlayerBroadcast", true)
addEvent("voice_local:addToPlayerBroadcast", true)
addEvent("voice_local:removeFromPlayerBroadcast", true)
addEvent("voice_local:requestPrivateLeave", true)

local broadcasts = {}
local privateChannels = {}
local playerPrivateChannel = {}

for settingName, settingData in pairs(settings) do
    if settingData then
        settings[settingName].value = get("*"..settingData.key)
    end
end

addEventHandler("onPlayerResourceStart", root, function(res)
    if res == resource then
        triggerClientEvent(source, "voice_local:updateSettings", source, settings)
    end
end)

-- Don't let the player talk to anyone as soon as they join
addEventHandler("onPlayerJoin", root, function()
    setPlayerVoiceBroadcastTo(source, {})
end)

addEventHandler("onPlayerQuit", root, function()
    broadcasts[source] = nil

    local channelId = playerPrivateChannel[source]
    if channelId then
        local members = privateChannels[channelId] or {}
        privateChannels[channelId] = nil
        playerPrivateChannel[source] = nil

        for _, member in pairs(members) do
            if member ~= source and isElement(member) then
                playerPrivateChannel[member] = nil
                setPlayerVoiceBroadcastTo(member, {member})
                triggerClientEvent(member, "voice_local:setPrivateState", member, false, nil)
                triggerClientEvent(member, "voice_local:requestBroadcastRefresh", member)
                outputChatBox("Canal de voz privado encerrado (outro jogador saiu).", member, 255, 120, 120)
            end
        end
    end
end)

-- Anti-cheat
-- Prevents clients from wanting to broadcast their voice to players that are really too far away
local function canPlayerBeWithinOtherPlayerStreamDistance(player, otherPlayer)
    local maxDist = tonumber(getServerConfigSetting("ped_syncer_distance")) or 100
    if (not isElement(player)) or (not isElement(otherPlayer)) then
        return false
    end
    if getElementType(player) ~= "player" or getElementType(otherPlayer) ~= "player" then
        return false
    end
    if getElementInterior(player) ~= getElementInterior(otherPlayer)
    or getElementDimension(player) ~= getElementDimension(otherPlayer) then
        return false
    end
    local px, py, pz = getElementPosition(player)
    local opx, opy, opz = getElementPosition(otherPlayer)
    return getDistanceBetweenPoints3D(px, py, pz, opx, opy, opz) <= maxDist
end

local function updateBroadcastForPrivate(player)
    local channelId = playerPrivateChannel[player]
    if not channelId then
        return false
    end

    local members = privateChannels[channelId]
    if not members then
        return false
    end

    broadcasts[player] = members
    setPlayerVoiceBroadcastTo(player, members)
    return true
end

local function resetPlayerToGeneral(player)
    playerPrivateChannel[player] = nil
    broadcasts[player] = {player}
    setPlayerVoiceBroadcastTo(player, {player})
    triggerClientEvent(player, "voice_local:setPrivateState", player, false, nil)
    triggerClientEvent(player, "voice_local:requestBroadcastRefresh", player)
end

addEventHandler("voice_local:setPlayerBroadcast", root, function(players)
    if not client then return end
    if type(players) ~= "table" then return end

    if updateBroadcastForPrivate(client) then
        return
    end

    broadcasts[client] = {client}

    for player, _ in pairs(players) do
        if player ~= client then
            if canPlayerBeWithinOtherPlayerStreamDistance(client, player) then
                table.insert(broadcasts[client], player)
            else
                iprint(eventName, "ignoring", getPlayerName(player))
            end
        end
    end
    setPlayerVoiceBroadcastTo(client, broadcasts[client])
end)

addEventHandler("voice_local:addToPlayerBroadcast", root, function(player)
    if not client then return end
    if not (isElement(player) and getElementType(player) == "player") then return end

    if updateBroadcastForPrivate(client) then
        return
    end

    if not broadcasts[client] then
        broadcasts[client] = {client}
    end

    if not canPlayerBeWithinOtherPlayerStreamDistance(client, player) then
        iprint(eventName, "ignoring", getPlayerName(player))
        return
    end

    -- Prevent duplicates
    for _, broadcast in pairs(broadcasts[client]) do
        if player == broadcast then
            return
        end
    end

    table.insert(broadcasts[client], player)
    setPlayerVoiceBroadcastTo(client, broadcasts[client])
end)

addEventHandler("voice_local:removeFromPlayerBroadcast", root, function(player)
    if not client then return end
    if not (isElement(player) and getElementType(player) == "player") then return end

    if updateBroadcastForPrivate(client) then
        return
    end

    if not broadcasts[client] then
        return
    end

    for i, broadcast in pairs(broadcasts[client]) do
        if player~=client and player == broadcast then
            table.remove(broadcasts[client], i)
            break
        end
    end

    setPlayerVoiceBroadcastTo(client, broadcasts[client])
end)

local function findPlayerByPartialName(namePart)
    if not namePart or namePart == "" then return nil end
    local namePartLower = namePart:lower()
    for _, player in ipairs(getElementsByType("player")) do
        local playerName = getPlayerName(player)
        if playerName and playerName:lower():find(namePartLower, 1, true) then
            return player
        end
    end
    return nil
end

local function setPrivateChannel(initiator, target, channelId)
    if not (isElement(initiator) and isElement(target)) then return end

    if privateChannels[channelId] then
        outputChatBox("Esse canal já está em uso.", initiator, 255, 120, 120)
        return
    end

    if playerPrivateChannel[initiator] then
        resetPlayerToGeneral(initiator)
    end
    if playerPrivateChannel[target] then
        resetPlayerToGeneral(target)
    end

    privateChannels[channelId] = {initiator, target}
    playerPrivateChannel[initiator] = channelId
    playerPrivateChannel[target] = channelId

    broadcasts[initiator] = privateChannels[channelId]
    broadcasts[target] = privateChannels[channelId]
    setPlayerVoiceBroadcastTo(initiator, privateChannels[channelId])
    setPlayerVoiceBroadcastTo(target, privateChannels[channelId])

    triggerClientEvent(initiator, "voice_local:setPrivateState", initiator, true, target)
    triggerClientEvent(target, "voice_local:setPrivateState", target, true, initiator)

    outputChatBox(("Canal de voz privado %d iniciado com %s."):format(channelId, getPlayerName(target)), initiator, 120, 255, 120)
    outputChatBox(("Canal de voz privado %d iniciado com %s."):format(channelId, getPlayerName(initiator)), target, 120, 255, 120)
end

local function leavePrivateChannel(player)
    local channelId = playerPrivateChannel[player]
    if not channelId then
        outputChatBox("Você não está em um canal privado.", player, 255, 120, 120)
        return
    end

    local members = privateChannels[channelId] or {}
    privateChannels[channelId] = nil

    for _, member in pairs(members) do
        if isElement(member) then
            resetPlayerToGeneral(member)
            outputChatBox("Canal de voz privado encerrado.", member, 255, 120, 120)
        end
    end
end

addEventHandler("voice_local:requestPrivateLeave", root, function()
    if not client then return end
    leavePrivateChannel(client)
end)

addCommandHandler("vpriv", function(player, _, targetName, channelIdRaw)
    if not targetName or not channelIdRaw then
        outputChatBox("Uso: /vpriv <player> <canal>", player, 255, 200, 120)
        return
    end

    local channelId = tonumber(channelIdRaw)
    if not channelId then
        outputChatBox("Canal inválido. Use um número.", player, 255, 120, 120)
        return
    end

    local target = findPlayerByPartialName(targetName)
    if not target or not isElement(target) then
        outputChatBox("Jogador não encontrado.", player, 255, 120, 120)
        return
    end

    if target == player then
        outputChatBox("Você não pode criar canal com você mesmo.", player, 255, 120, 120)
        return
    end

    setPrivateChannel(player, target, channelId)
end)

addCommandHandler("vleave", function(player)
    leavePrivateChannel(player)
end)

addEventHandler("onPlayerVoiceStart", root, function()
    if not broadcasts[source] then
        -- Somehow if the system still hasn't loaded the player, prevent them from talking
        cancelEvent()
        return
    end
    triggerClientEvent(broadcasts[source], "voice_local:onClientPlayerVoiceStart", source, source)
end)

addEventHandler("onPlayerVoiceStop", root, function()
    if not broadcasts[source] then
        return
    end
    triggerClientEvent(broadcasts[source], "voice_local:onClientPlayerVoiceStop", source, source)
end)

-- Cancel resource start if voice is not enabled on the server
addEventHandler("onResourceStart", resourceRoot, function()
    if not isVoiceEnabled() then
        cancelEvent(true, "<voice> setting is not enabled on this server")
    end
end, false)
