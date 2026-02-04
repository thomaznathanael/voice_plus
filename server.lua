local broadcasts = {}
local playerChannel = {} -- Armazena o canal de cada jogador

-- Sincroniza configurações com o Client
addEventHandler("onPlayerResourceStart", root, function(res)
    if res == resource then
        triggerClientEvent(source, "voice_local:updateSettings", source, settings)
    end
end)

-- Função mestre para decidir quem ouve quem
function updateVoiceTargets(player)
    if not isElement(player) then return end
    
    local channel = playerChannel[player]
    local targets = {}

    if channel then
        -- MODO CANAL: Procura todos os jogadores no mesmo canal (sem limite de distância)
        for _, p in ipairs(getElementsByType("player")) do
            if playerChannel[p] == channel then
                table.insert(targets, p)
            end
        end
    else
        -- MODO PROXIMIDADE: Usa apenas os jogadores que o cliente reportou como "perto"
        targets = broadcasts[player] or {player}
    end

    setPlayerVoiceBroadcastTo(player, targets)
end

-- Comandos de Canal
addCommandHandler("canal", function(player, cmd, id)
    local id = tonumber(id)
    if not id then return outputChatBox("Use: /canal [id]", player) end

    playerChannel[player] = id
    setElementData(player, "voice:channel", id) -- Sincroniza com o client
    outputChatBox("Entrou no canal de voz: " .. id, player, 0, 255, 0)
    
    updateVoiceTargets(player)
end)

addCommandHandler("saircanal", function(player)
    if not playerChannel[player] then return end
    
    playerChannel[player] = nil
    setElementData(player, "voice:channel", nil)
    outputChatBox("Você voltou para o modo proximidade.", player, 255, 255, 0)
    
    updateVoiceTargets(player)
end)

-- Eventos de Proximidade (Broadcasts)
addEventHandler("voice_local:setPlayerBroadcast", root, function(players)
    if not client then return end
    broadcasts[client] = {client}
    for p, _ in pairs(players) do
        if p ~= client and canPlayerBeWithinOtherPlayerStreamDistance(client, p) then
            table.insert(broadcasts[client], p)
        end
    end
    updateVoiceTargets(client)
end)

addEventHandler("voice_local:addToPlayerBroadcast", root, function(p)
    if not client or not isElement(p) then return end
    broadcasts[client] = broadcasts[client] or {client}
    table.insert(broadcasts[client], p)
    updateVoiceTargets(client)
end)

addEventHandler("voice_local:removeFromPlayerBroadcast", root, function(p)
    if not client or not broadcasts[client] then return end
    for i, b in ipairs(broadcasts[client]) do
        if b == p then table.remove(broadcasts[client], i) break end
    end
    updateVoiceTargets(client)
end)

-- Gatilhos de Voz
addEventHandler("onPlayerVoiceStart", root, function()
    if not broadcasts[source] and not playerChannel[source] then 
        cancelEvent() 
        return 
    end
    -- No canal, enviamos o evento de "falando" para todos no canal
    local targets = playerChannel[source] and "all" or broadcasts[source]
    triggerClientEvent(root, "voice_local:onClientPlayerVoiceStart", source, source)
end)

addEventHandler("onPlayerVoiceStop", root, function()
    triggerClientEvent(root, "voice_local:onClientPlayerVoiceStop", source, source)
end)

-- Anti-cheat (original)
function canPlayerBeWithinOtherPlayerStreamDistance(player, otherPlayer)
    local maxDist = tonumber(getServerConfigSetting("ped_syncer_distance")) or 100
    if getElementInterior(player) ~= getElementInterior(otherPlayer) or getElementDimension(player) ~= getElementDimension(otherPlayer) then return false end
    local px, py, pz = getElementPosition(player)
    local opx, opy, opz = getElementPosition(otherPlayer)
    return getDistanceBetweenPoints3D(px, py, pz, opx, opy, opz) <= maxDist
end