# Voice Plus - Integracao com Outros Resources

Este resource expoe **APIs server-side** para integracao com recursos de celular e walktalk, e emite eventos de TX/RX para integracao com outros resources.

## Eventos Server-Side

Use `triggerEvent` no server:

```lua
-- iniciar ligacao (char:id)
triggerEvent("voice_plus:call", player, charId)

-- finalizar ligacao
triggerEvent("voice_plus:hangup", player)

-- entrar no radio (police|faction, frequencia)
triggerEvent("voice_plus:radio", player, "police", 123)

-- sair do radio
triggerEvent("voice_plus:radio_off", player)

-- habilitar/desabilitar TX do radio
triggerEvent("voice_plus:set_radio_tx", player, true)

-- ajustar volume do radio (0-3)
triggerEvent("voice_plus:set_radio_volume", player, 3)

-- canal privado (char:id alvo, canal)
triggerEvent("voice_plus:private", player, targetCharId, 123)

-- sair do canal privado
triggerEvent("voice_plus:private_off", player)
```

## Eventos Server-Side (emissao/recepcao)

Estes eventos sao disparados automaticamente **apenas quando a transmissao estiver em radio** (F2 ativo e no canal correto). Fala local nao dispara estes eventos.

```lua
-- quando um jogador comeca a transmitir
addEventHandler("voice_plus:onPlayerTxStart", root, function()
    local speaker = source
end)

-- quando um jogador para de transmitir
addEventHandler("voice_plus:onPlayerTxStop", root, function()
    local speaker = source
end)

-- quando o jogador altera o volume do radio (0-3)
addEventHandler("voice_plus:onPlayerRadioVolumeChange", root, function(level)
    local player = source
end)

```

**Parametros (server-side):**
- `voice_plus:onPlayerTxStart` / `voice_plus:onPlayerTxStop`: `source` = jogador que esta transmitindo.
- `voice_plus:onPlayerRadioVolumeChange`: `source` = jogador que alterou o volume, `level` = 0..3.

## Eventos Client-Side (emissao/recepcao)

```lua
-- local player comecou a transmitir
addEventHandler("voice_plus:onClientTxStart", root, function(mode, partner, radioType, radioFreq, radioTxActive)
end)

-- local player parou de transmitir
addEventHandler("voice_plus:onClientTxStop", root, function(mode, partner, radioType, radioFreq, radioTxActive)
end)

-- local player comecou a receber voz de outro jogador
addEventHandler("voice_plus:onClientRxStart", root, function(mode, partner, radioType, radioFreq, volume)
    local speaker = source
end)

-- local player parou de receber voz de outro jogador
addEventHandler("voice_plus:onClientRxStop", root, function(mode, partner, radioType, radioFreq, volume)
    local speaker = source
end)

-- local player alterou o volume do radio (0-3)
addEventHandler("voice_plus:onClientRadioVolumeChange", root, function(level, scale)
end)

```

**Parametros (client-side):**
- `voice_plus:onClientTxStart` / `voice_plus:onClientTxStop`: `mode` = `general|call|private|radio`, `partner` = player em call/private (ou `nil`), `radioType` = `police|faction` (ou `nil`), `radioFreq` = numero (ou `nil`), `radioTxActive` = `true|false`.
- `voice_plus:onClientRxStart` / `voice_plus:onClientRxStop`: `source` = jogador que esta sendo ouvido, `mode` = `general|call|private|radio`, `partner` = player em call/private (ou `nil`), `radioType` = `police|faction` (ou `nil`), `radioFreq` = numero (ou `nil`), `volume` = numero (com boost, pode ser > 1.0).
- `voice_plus:onClientRadioVolumeChange`: `level` = 0..3, `scale` = multiplicador (0.0..1.0).

## Exports Server-Side

Use `exports` no server:

```lua
exports.voice_plus:voice_plus_call(player, charId)
exports.voice_plus:voice_plus_hangup(player)
exports.voice_plus:voice_plus_radio(player, "faction", 123)
exports.voice_plus:voice_plus_radio_off(player)
exports.voice_plus:voice_plus_set_radio_tx(player, true)
exports.voice_plus:voice_plus_set_radio_volume(player, 3)
exports.voice_plus:voice_plus_private(player, targetCharId, 123)
exports.voice_plus:voice_plus_private_off(player)
``'

## Observacoes

- `player` deve ser o elemento do jogador.
- `charId` e o `char:id` do player alvo.
- `radio` aceita apenas `"police"` ou `"faction"`.
- O canal privado agora esta exposto via `voice_plus:private` e `voice_plus:private_off`.
