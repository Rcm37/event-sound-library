# Event Sound Library

A dependency plugin that detects RuneScape events and plays sounds supplied by each consumer. The library contains no sound files, settings storage, or UI. Multiple consumers can run together; each gets independent sounds, toggles, volume, and cleanup.

## Credits

Trigger detection logic is adapted from [Devdeve's Boaty Hype Man plugin](https://github.com/Devdeve/boatyHypeMan-RS3-plugin) and adheres to the GPL-3 LICENSE as a result.


## Install and use

Keep `event-sound-library` beside your development plugin and add this manifest entry:

```json
"requiredDependencies": { "event_sound_library": "event-sound-library" }
```

RuneScape exposes the return value of the dependency's `main.lua` as the alias `event_sound_library`. Use that global directly, rather than `require` across plugin folders. For distribution, replace the folder string with the library's published numeric Mod.io ID. This library has no published ID yet. See the [official dependency format](https://developer.runescape.com/rs/structure.html).

Grant **chatAccess to the library** for chat-based triggers.

Store .ogg files in your own plugin's `resources/` directory. This example uses `resources/levelup.ogg`, `resources/death1.ogg`, and `resources/death2.ogg`. Load them in your plugin before registering the sounds:

```lua
local Settings = require("settings")
local levelUp = Plugin.resources.levelup
local deaths = { Plugin.resources.death1, Plugin.resources.death2 }

levelUp:Load()
for _, sound in ipairs(deaths) do sound:Load() end

local registration = event_sound_library.new({
    sounds = {
        levelUp = levelUp,
        death = deaths,
    },
    enabled = function(trigger, event)
        if trigger == "levelUp" then return Settings.get("enableLevelUps") end
        if trigger == "death" then return Settings.get("enableDeaths") end
        return true
    end,
    volume = 0.2,
    audioBus = audio.AudioBus.MASTER,
})

function PluginShutdown()
    registration:dispose()
end
```

`Settings` is the consuming plugin's own module; the library does not provide settings or toggles. The example expects boolean settings named `enableLevelUps` and `enableDeaths`. Merge the registration's disposal into your existing shutdown function if you already have one.

Each event selects one entry uniformly at random from its sound list. Use a single resource, a built-in sound ID, or a nonempty array of sounds. Omitted triggers are silent. The library copies sound lists, so later edits to the input list do not change an existing registration.

Preload custom resources with `resource:Load()` during the consuming plugin's startup, before registering them with the library. Built-in sound IDs do not need preloading. The library calls `audio.Play` directly and tracks instances for cleanup; no playback callback is needed.

`enabled(trigger, event)` is optional and evaluated on every matching event, so toggles take effect immediately. It must return a truthy value to play. It receives the original event payload; it can also serve as a consumer-specific filter. Without it, all configured triggers are enabled. Callback errors are isolated so other consumers receive the event. Keep callbacks free of side effects.

## Volume

Volume defaults to `0.2` (20%) and uses a range of 0 to 1. For a slider that stores percentages, call this from its change handler after saving the setting:

```lua
registration:setVolume(percent / 100)
```

The new volume applies to subsequent sounds. Currently playing clips finish at their original volume, including when the slider is set to 0%.

Alternatively, the constructor's `volume` option accepts a function `(trigger, event)` returning a number from 0 to 1. For example, `volume = function() return Settings.get("volume") / 100 end` reads a saved percentage before each playback. Calling `setVolume` replaces that callback with a fixed value.

The audio bus defaults to `audio.AudioBus.MASTER`. Set `audioBus = audio.AudioBus.SFX` to use the game's sound-effects bus instead. The bus is fixed per registration.

## Supported triggers

| Name | Detection |
| --- | --- |
| `levelUp` | Gameplay level increases in `SkillTransmit`. |
| `questCompletion` | System chat contains `Congratulations! You have completed:`. |
| `collectionLog` | System chat contains `New collection log entry`. |
| `achievement` | `CHEEVO_RECENT_COMPLETE_1` changes to a nonnegative achievement ID. |
| `death` | System chat contains `Oh dear, you are dead!`. |
| `petDrop` | Broadcast starts with the local player's name and contains a pet drop announcement or Artemis Treasure Trail compass announcement. |
| `expensiveDrop` | An owned ground stack is added or increases, and per-item `objType.cost * 0.6` meets `LOOT_BEAM`. |

Chat detection strips markup and uses English messages. Player chat and plugin messages are excluded. Pet matching treats punctuation in the player's name literally and ignores other players. Pet detection covers boss pets and Artemis, not every skilling pet announcement. Drop detection uses estimated high-alchemy value, not GE prices or total stack value; an owned stack appearing in view can also trigger it. Achievement detection uses the recent-completion variable rather than a dedicated completion event.

## Registration methods

- `registration:setSounds(trigger, resourceOrList)` replaces a trigger's sounds. Preload any new custom resources in their owning plugin before calling this method.
- `registration:setSounds(trigger, nil)` removes a trigger.
- `registration:setVolume(volume)` sets the volume for subsequent sounds (0..1), replacing any volume callback. Playing clips finish at their original volume.
- `registration:play(trigger, payload)` manually plays a configured trigger, applying the same enabled callback. It returns the sound instance or nil if skipped/playback fails. The payload is optional; callbacks receive nil when it is omitted. Callback errors propagate for manual calls.
- `registration:dispose()` unregisters this consumer, stops its active sounds, and releases its resources/callback. Safe to call repeatedly. Manual playback after disposal is silent; updating sounds after disposal raises an error.

Consumers **must call `dispose()` from their shutdown function**; a shared library cannot observe an individual dependent's shutdown. The library subscribes during its own startup so chat events belong to the plugin requesting chatAccess, and unsubscribes at library shutdown. Event handlers do no detection work while no registrations exist. Library shutdown disposes all remaining registrations. Consumers may play simultaneously, and playback is subject to the client's sound-instance limits. No cross-trigger deduplication or cooldown is applied.

Built-in detectors are defined in `src/triggers.lua`; the playback and registration layer is independent of detection.

