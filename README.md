# Voice Plus (MTA:SA)

Sistema de voz local por proximidade com suporte a:

- chamada 1:1 por `char:id`
- radio por tipo/frequencia (`police` e `faction`)
- canal de voz privado 1:1
- API server-side para integrar com celular, walktalk e outros resources
- eventos de observabilidade (TX/RX e volume)

O foco deste resource e permitir integracao limpa com outros sistemas, mantendo a experiencia de voz no cliente.

## Recursos

- Voz por distancia com atenuacao dinamica.
- Modo `general`, `call`, `radio` e `private`.
- Push-to-talk de radio por tecla (`F2`) para alternar transmissao.
- Controle de volume de radio por jogador (`0..3`), com feedback sonoro.
- Indicador visual 3D de quem esta falando (normal, telefone e radio).
- Exports e eventos para controlar tudo por script.
- Validacoes server-side para reduzir abuso de broadcast.

## Requisitos

- MTA:SA com voz habilitada no servidor (`<voice>` no `mtaserver.conf`).
- Versao minima conforme `meta.xml`:
  - `1.3.0-0.04570`
- Seu gamemode precisa definir `char:id` nos jogadores para chamadas e canal privado.

## Instalacao

1. Coloque a pasta do resource em `resources/` (exemplo: `resources/[local]/voice_plus`).
2. Garanta que o `meta.xml` esteja junto de `client.lua`, `server.lua` e `shared.lua`.
3. Inicie no servidor com `start voice_plus` (ou nome da pasta que voce usar).
4. Teste com dois jogadores para validar proximidade, chamada e radio.

## Configuracao

As configuracoes estao em `meta.xml`:

```xml
<setting name="*max_voice_distance" value="[25]"/>
<setting name="*voice_sound_boost" value="[6]"/>
<setting name="*show_talking_icon" value="[true]"/>
```

- `*max_voice_distance`: distancia maxima da voz local (modo geral).
- `*voice_sound_boost`: ganho final aplicado no volume da voz.
- `*show_talking_icon`: mostra/esconde o indicador visual de fala.

## Controle no Cliente

- `F2`: alterna o estado de TX do radio (`on/off`) quando o jogador estiver em modo radio.

## API Server-Side (triggerEvent)

Use estes eventos para integrar com outros resources:

```lua
-- iniciar chamada por char:id
triggerEvent("voice_plus:call", player, targetCharId)

-- encerrar chamada atual
triggerEvent("voice_plus:hangup", player)

-- entrar em radio (tipo + frequencia)
triggerEvent("voice_plus:radio", player, "police", 190)
triggerEvent("voice_plus:radio", player, "faction", 12)

-- sair do radio
triggerEvent("voice_plus:radio_off", player)

-- habilitar/desabilitar TX do radio
triggerEvent("voice_plus:set_radio_tx", player, true)

-- definir volume do radio (0..3)
triggerEvent("voice_plus:set_radio_volume", player, 2)

-- iniciar canal privado por char:id alvo + id do canal
triggerEvent("voice_plus:private", player, targetCharId, 5001)

-- sair do canal privado
triggerEvent("voice_plus:private_off", player)
```

Regras importantes:

- `player` precisa ser elemento `player` valido.
- `targetCharId` deve corresponder ao `char:id` de outro jogador.
- `radioType` aceita apenas `police` ou `faction`.
- `freq` e `channelId` sao numericos.

## API Server-Side (exports)

Os mesmos controles acima estao disponiveis via export.
Use o nome real do seu resource no prefixo (ex.: `voice_plus`):

```lua
exports.voice_plus:voice_plus_call(player, targetCharId)
exports.voice_plus:voice_plus_hangup(player)
exports.voice_plus:voice_plus_radio(player, "faction", 12)
exports.voice_plus:voice_plus_radio_off(player)
exports.voice_plus:voice_plus_set_radio_tx(player, true)
exports.voice_plus:voice_plus_set_radio_volume(player, 3)
exports.voice_plus:voice_plus_private(player, targetCharId, 5001)
exports.voice_plus:voice_plus_private_off(player)
```

## Eventos de Observabilidade (Server)

Escute estes eventos para log, UI externa, analytics ou regras adicionais:

```lua
-- source = jogador que iniciou/finalizou TX
addEventHandler("voice_plus:onPlayerTxStart", root, function(speaker)
end)

addEventHandler("voice_plus:onPlayerTxStop", root, function(speaker)
end)

-- source = jogador receptor, arg = speaker
addEventHandler("voice_plus:onPlayerRxStart", root, function(speaker)
end)

addEventHandler("voice_plus:onPlayerRxStop", root, function(speaker)
end)

-- source = jogador que alterou o volume
addEventHandler("voice_plus:onPlayerRadioVolumeChange", root, function(level)
end)
```

## Eventos de Observabilidade (Client)

```lua
-- localPlayer iniciou/finalizou TX no contexto atual
addEventHandler("voice_plus:onClientTxStart", root, function(mode, partner, radioType, radioFreq, radioTxActive)
end)

addEventHandler("voice_plus:onClientTxStop", root, function(mode, partner, radioType, radioFreq, radioTxActive)
end)

-- localPlayer iniciou/finalizou recepcao de voz via radio
addEventHandler("voice_plus:onClientRxStart", root, function(speaker, radioType, radioFreq, speakerTxActive)
end)

addEventHandler("voice_plus:onClientRxStop", root, function(speaker, radioType, radioFreq, speakerTxActive)
end)

-- volume local de radio foi alterado
addEventHandler("voice_plus:onClientRadioVolumeChange", root, function(level, scale)
end)
```

## Prioridade de Modos

A logica server-side segue a seguinte prioridade de broadcast:

1. `call`
2. `private`
3. `radio` (quando TX estiver ativo)
4. `general`

Isso evita conflito entre modos e mantem o comportamento consistente.

## Debug

Se quiser mensagens de depuracao em chat, descomente as linhas `outputChatBox` no `server.lua`.

## Estrutura do Resource

- `meta.xml`: declaracoes, arquivos, settings e exports.
- `shared.lua`: chaves de configuracao compartilhadas.
- `server.lua`: controle de broadcast/modos/eventos/exports.
- `client.lua`: volume local, HUD/ring, teclas e eventos client-side.

## Licenca

Este projeto esta licenciado sob a **MIT License**.
Consulte `LICENSE` para os termos completos.
