# Voice Plus - Integracao com Outros Resources

Este resource expõe apenas **APIs server-side** para integração com recursos de celular e walktalk.

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

-- canal privado (char:id alvo, canal)
triggerEvent("voice_plus:private", player, targetCharId, 123)

-- sair do canal privado
triggerEvent("voice_plus:private_off", player)
```

## Exports Server-Side

Use `exports` no server:

```lua
exports.voice_plus:voice_plus_call(player, charId)
exports.voice_plus:voice_plus_hangup(player)
exports.voice_plus:voice_plus_radio(player, "faction", 123)
exports.voice_plus:voice_plus_radio_off(player)
exports.voice_plus:voice_plus_set_radio_tx(player, true)
exports.voice_plus:voice_plus_private(player, targetCharId, 123)
exports.voice_plus:voice_plus_private_off(player)
```

## Observacoes

- `player` deve ser o elemento do jogador.
- `charId` é o `char:id` do player alvo.
- `radio` aceita apenas `"police"` ou `"faction"`.
- O canal privado agora esta exposto via `voice_plus:private` e `voice_plus:private_off`.
