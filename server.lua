-- Remote events:
addEvent("voice_local:setPlayerBroadcast", true)
addEvent("voice_local:addToPlayerBroadcast", true)
addEvent("voice_local:removeFromPlayerBroadcast", true)
addEvent("voice_local:requestPrivateLeave", true)
addEvent("voice_local:playRadioRoger", true)

local broadcasts = {}
local generalBroadcasts = {}
local privateChannels = {}
local playerPrivateChannel = {}
local radioChannels = {}
local playerRadioFreq = {}
local playerRadioType = {}
local callPartners = {}
local updateRadioChannel
local applyModeAfterCall

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
    generalBroadcasts[source] = nil

    local callPartner = callPartners[source]
    if callPartner then
        callPartners[source] = nil
        if isElement(callPartner) then
            callPartners[callPartner] = nil
            applyModeAfterCall(callPartner)
            outputChatBox("Ligação encerrada (outro jogador saiu).", callPartner, 255, 120, 120)
        end
    end

    local freq = playerRadioFreq[source]
    local rType = playerRadioType[source]
    if freq and rType then
        local key = ("%s:%d"):format(rType, freq)
        if radioChannels[key] then
            radioChannels[key][source] = nil
            if next(radioChannels[key]) == nil then
                radioChannels[key] = nil
            else
                updateRadioChannel(freq, rType)
            end
        end
    end
    playerRadioFreq[source] = nil
    playerRadioType[source] = nil

    local channelId = playerPrivateChannel[source]
    if channelId then
        local members = privateChannels[channelId] or {}
        privateChannels[channelId] = nil
        playerPrivateChannel[source] = nil

        for _, member in pairs(members) do
            if member ~= source and isElement(member) then
                playerPrivateChannel[member] = nil
                setPlayerVoiceBroadcastTo(member, {member})
                triggerClientEvent(member, "voice_local:setVoiceMode", member, "general", nil)
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

local function mergeUnique(listA, listB)
    local set = {}
    local merged = {}
    for _, player in ipairs(listA or {}) do
        if isElement(player) and not set[player] then
            set[player] = true
            table.insert(merged, player)
        end
    end
    for _, player in ipairs(listB or {}) do
        if isElement(player) and not set[player] then
            set[player] = true
            table.insert(merged, player)
        end
    end
    return merged
end

local function getRadioMembersList(freq, rType)
    local membersMap = radioChannels[("%s:%d"):format(rType or "", freq or 0)]
    if not membersMap then
        return nil
    end
    local list = {}
    for member, _ in pairs(membersMap) do
        if isElement(member) and not callPartners[member] and not playerPrivateChannel[member] then
            table.insert(list, member)
        end
    end
    if #list == 0 then
        return nil
    end
    return list
end

local function updateBroadcastForRadio(player)
    local freq = playerRadioFreq[player]
    if not freq then
        return false
    end
    local list = getRadioMembersList(freq, playerRadioType[player])
    if not list then
        return false
    end
    local base = generalBroadcasts[player] or {player}
    local combined = mergeUnique(base, list)
    broadcasts[player] = combined
    setPlayerVoiceBroadcastTo(player, combined)
    return true
end

local function updateBroadcastForCall(player)
    local partner = callPartners[player]
    if not partner then
        return false
    end
    local base = generalBroadcasts[player] or {player}
    local combined = mergeUnique(base, {player, partner})
    broadcasts[player] = combined
    setPlayerVoiceBroadcastTo(player, combined)
    return true
end

local function updateBroadcastForVoice(player)
    if updateBroadcastForCall(player) then
        return true
    end
    if updateBroadcastForPrivate(player) then
        return true
    end
    if updateBroadcastForRadio(player) then
        return true
    end
    return false
end

local function resetPlayerToGeneral(player)
    playerPrivateChannel[player] = nil
    broadcasts[player] = {player}
    setPlayerVoiceBroadcastTo(player, {player})
    triggerClientEvent(player, "voice_local:setVoiceMode", player, "general", nil)
    triggerClientEvent(player, "voice_local:requestBroadcastRefresh", player)
end

addEventHandler("voice_local:setPlayerBroadcast", root, function(players)
    if not client then return end
    if type(players) ~= "table" then return end

    if updateBroadcastForVoice(client) then
        return
    end

    generalBroadcasts[client] = {client}

    for player, _ in pairs(players) do
        if player ~= client then
            if canPlayerBeWithinOtherPlayerStreamDistance(client, player) then
                table.insert(generalBroadcasts[client], player)
            else
                iprint(eventName, "ignoring", getPlayerName(player))
            end
        end
    end

    if not updateBroadcastForVoice(client) then
        broadcasts[client] = generalBroadcasts[client]
        setPlayerVoiceBroadcastTo(client, broadcasts[client])
    end
end)

addEventHandler("voice_local:addToPlayerBroadcast", root, function(player)
    if not client then return end
    if not (isElement(player) and getElementType(player) == "player") then return end

    if not generalBroadcasts[client] then
        generalBroadcasts[client] = {client}
    end

    if not canPlayerBeWithinOtherPlayerStreamDistance(client, player) then
        iprint(eventName, "ignoring", getPlayerName(player))
        return
    end

    -- Prevent duplicates
    for _, broadcast in pairs(generalBroadcasts[client]) do
        if player == broadcast then
            return
        end
    end

    table.insert(generalBroadcasts[client], player)
    if not updateBroadcastForVoice(client) then
        broadcasts[client] = generalBroadcasts[client]
        setPlayerVoiceBroadcastTo(client, broadcasts[client])
    end
end)

addEventHandler("voice_local:removeFromPlayerBroadcast", root, function(player)
    if not client then return end
    if not (isElement(player) and getElementType(player) == "player") then return end

    if not generalBroadcasts[client] then
        return
    end

    for i, broadcast in pairs(generalBroadcasts[client]) do
        if player~=client and player == broadcast then
            table.remove(generalBroadcasts[client], i)
            break
        end
    end

    if not updateBroadcastForVoice(client) then
        broadcasts[client] = generalBroadcasts[client]
        setPlayerVoiceBroadcastTo(client, broadcasts[client])
    end
end)

local function findPlayerByCharId(charIdRaw)
    if not charIdRaw or charIdRaw == "" then return nil end
    local charIdStr = tostring(charIdRaw)
    for _, player in ipairs(getElementsByType("player")) do
        local playerCharId = getElementData(player, "char:id")
        if playerCharId ~= nil and tostring(playerCharId) == charIdStr then
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

    triggerClientEvent(initiator, "voice_local:setVoiceMode", initiator, "private", target)
    triggerClientEvent(target, "voice_local:setVoiceMode", target, "private", initiator)

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
            if callPartners[member] then
                updateBroadcastForCall(member)
                triggerClientEvent(member, "voice_local:setVoiceMode", member, "call", callPartners[member])
            elseif playerRadioFreq[member] then
                updateRadioChannel(playerRadioFreq[member], playerRadioType[member])
                triggerClientEvent(member, "voice_local:setVoiceMode", member, "radio", playerRadioType[member])
            else
                resetPlayerToGeneral(member)
            end
            outputChatBox("Canal de voz privado encerrado.", member, 255, 120, 120)
        end
    end
end

addEventHandler("voice_local:requestPrivateLeave", root, function()
    if not client then return end
    leavePrivateChannel(client)
end)

updateRadioChannel = function(freq, rType)
    local list = getRadioMembersList(freq, rType)
    if not list then
        radioChannels[("%s:%d"):format(rType or "", freq or 0)] = nil
        return
    end

    for _, member in ipairs(list) do
        if not callPartners[member] and not playerPrivateChannel[member] then
            broadcasts[member] = list
            setPlayerVoiceBroadcastTo(member, list)
            triggerClientEvent(member, "voice_local:setVoiceMode", member, "radio", rType)
        end
    end
end

local function joinRadio(player, freq, rType)
    local current = playerRadioFreq[player]
    local currentType = playerRadioType[player]
    if current == freq and currentType == rType then
        outputChatBox(("Você já está na %s %d."):format(rType, freq), player, 255, 200, 120)
        return
    end

    if current and currentType then
        local currentKey = ("%s:%d"):format(currentType, current)
        if radioChannels[currentKey] then
            radioChannels[currentKey][player] = nil
            if next(radioChannels[currentKey]) == nil then
                radioChannels[currentKey] = nil
            else
                updateRadioChannel(current, currentType)
            end
        else
            updateRadioChannel(current, currentType)
        end
    end

    local key = ("%s:%d"):format(rType, freq)
    if not radioChannels[key] then
        radioChannels[key] = {}
    end
    radioChannels[key][player] = true
    playerRadioFreq[player] = freq
    playerRadioType[player] = rType

    updateRadioChannel(freq, rType)

    outputChatBox(("Você entrou na %s %d."):format(rType, freq), player, 120, 255, 120)
end

local function leaveRadio(player)
    local current = playerRadioFreq[player]
    if not current then
        outputChatBox("Você não está em nenhuma frequência.", player, 255, 200, 120)
        return
    end

    local currentType = playerRadioType[player]
    local key = currentType and ("%s:%d"):format(currentType, current) or nil
    if key and radioChannels[key] then
        radioChannels[key][player] = nil
        if next(radioChannels[key]) == nil then
            radioChannels[key] = nil
        else
            updateRadioChannel(current, currentType)
        end
    end
    playerRadioFreq[player] = nil
    playerRadioType[player] = nil

    if not callPartners[player] and not playerPrivateChannel[player] then
        resetPlayerToGeneral(player)
    end

    outputChatBox("Você saiu da frequência.", player, 255, 120, 120)
end

applyModeAfterCall = function(player)
    if not isElement(player) then return end

    if playerPrivateChannel[player] then
        updateBroadcastForPrivate(player)
        local channelId = playerPrivateChannel[player]
        local members = privateChannels[channelId] or {}
        local partner = nil
        for _, member in pairs(members) do
            if member ~= player then
                partner = member
                break
            end
        end
        triggerClientEvent(player, "voice_local:setVoiceMode", player, "private", partner)
        return
    end

    if playerRadioFreq[player] then
        updateRadioChannel(playerRadioFreq[player], playerRadioType[player])
        triggerClientEvent(player, "voice_local:setVoiceMode", player, "radio", playerRadioType[player])
        return
    end

    resetPlayerToGeneral(player)
end

local function startCall(player, target)
    if callPartners[player] then
        outputChatBox("Você já está em ligação.", player, 255, 120, 120)
        return
    end
    if callPartners[target] then
        outputChatBox("Jogador está em ligação.", player, 255, 120, 120)
        return
    end

    callPartners[player] = target
    callPartners[target] = player

    local list = {player, target}
    broadcasts[player] = list
    broadcasts[target] = list
    setPlayerVoiceBroadcastTo(player, list)
    setPlayerVoiceBroadcastTo(target, list)

    triggerClientEvent(player, "voice_local:setVoiceMode", player, "call", target)
    triggerClientEvent(target, "voice_local:setVoiceMode", target, "call", player)

    outputChatBox(("Ligação iniciada com %s."):format(getPlayerName(target)), player, 120, 255, 120)
    outputChatBox(("Ligação iniciada com %s."):format(getPlayerName(player)), target, 120, 255, 120)
end

local function hangup(player)
    local partner = callPartners[player]
    if not partner then
        outputChatBox("Você não está em ligação.", player, 255, 120, 120)
        return
    end

    callPartners[player] = nil
    if isElement(partner) then
        callPartners[partner] = nil
    end

    applyModeAfterCall(player)
    if isElement(partner) then
        applyModeAfterCall(partner)
        outputChatBox("Ligação encerrada.", partner, 255, 120, 120)
    end
    outputChatBox("Ligação encerrada.", player, 255, 120, 120)
end

addCommandHandler("vpriv", function(player, _, targetCharId, channelIdRaw)
    if not targetCharId or not channelIdRaw then
        outputChatBox("Uso: /vpriv <char:id> <canal>", player, 255, 200, 120)
        return
    end

    local channelId = tonumber(channelIdRaw)
    if not channelId then
        outputChatBox("Canal inválido. Use um número.", player, 255, 120, 120)
        return
    end

    local target = findPlayerByCharId(targetCharId)
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

addCommandHandler("radio", function(player, _, radioTypeRaw, freqRaw)
    if not radioTypeRaw then
        outputChatBox("Uso: /radio <police|faction> <freq> ou /radio off", player, 255, 200, 120)
        return
    end

    local radioType = tostring(radioTypeRaw):lower()
    if radioType == "off" or radioType == "0" then
        leaveRadio(player)
        return
    end

    if radioType ~= "police" and radioType ~= "faction" then
        outputChatBox("Tipo inválido. Use police ou faction.", player, 255, 120, 120)
        return
    end

    if not freqRaw then
        outputChatBox("Uso: /radio <police|faction> <freq>", player, 255, 200, 120)
        return
    end

    local freq = tonumber(freqRaw)
    if not freq then
        outputChatBox("Frequência inválida. Use um número.", player, 255, 120, 120)
        return
    end

    joinRadio(player, freq, radioType)
end)

addCommandHandler("call", function(player, _, targetCharId)
    if not targetCharId then
        outputChatBox("Uso: /call <char:id>", player, 255, 200, 120)
        return
    end

    local target = findPlayerByCharId(targetCharId)
    if not target or not isElement(target) then
        outputChatBox("Jogador não encontrado.", player, 255, 120, 120)
        return
    end

    if target == player then
        outputChatBox("Você não pode ligar para você mesmo.", player, 255, 120, 120)
        return
    end

    startCall(player, target)
end)

addCommandHandler("hangup", function(player)
    hangup(player)
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

    local freq = playerRadioFreq[source]
    local rType = playerRadioType[source]
    if freq and rType and not callPartners[source] and not playerPrivateChannel[source] then
        local list = getRadioMembersList(freq, rType)
        if list then
            triggerClientEvent(list, "voice_local:playRadioRoger", source, source)
        end
    end
end)

-- Cancel resource start if voice is not enabled on the server
addEventHandler("onResourceStart", resourceRoot, function()
    if not isVoiceEnabled() then
        cancelEvent(true, "<voice> setting is not enabled on this server")
    end
end, false)
