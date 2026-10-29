local Triggers = require("src/triggers")
local events, soundAPI = Event, audio
local registrations = {}
local Library = { version = "0.1.0" }
local subscriptionID = "event-sound-library"

local function checkVolume(volume)
    assert(type(volume) == "number" and volume >= 0 and volume <= 1, "volume must be between 0 and 1")
    return volume
end

local function checkTrigger(trigger)
    assert(Triggers.names[trigger], "Unknown sound trigger: " .. tostring(trigger))
end

local function soundList(sounds)
    if type(sounds) ~= "table" then sounds = { sounds } end
    assert(#sounds > 0, "Sound lists must not be empty")
    local list = {}
    for _, sound in ipairs(sounds) do
        assert(type(sound) == "userdata" or type(sound) == "number", "Expected an audio resource or sound ID")
        list[#list + 1] = sound
    end
    return list
end

function Library.new(options)
    local sounds, instances = {}, {}
    local volume = options.volume or 0.2
    if type(volume) ~= "function" then checkVolume(volume) end
    local enabled = options.enabled
    local audioBus = options.audioBus or soundAPI.AudioBus.MASTER
    local disposed = false
    local registration = {}

    for trigger, resources in pairs(options.sounds) do
        checkTrigger(trigger)
        sounds[trigger] = soundList(resources)
    end

    function registration:setVolume(value)
        assert(not disposed, "Sound registration is disposed")
        volume = checkVolume(value)
    end

    function registration:setSounds(trigger, resources)
        assert(not disposed, "Sound registration is disposed")
        checkTrigger(trigger)
        sounds[trigger] = resources and soundList(resources) or nil
    end

    function registration:play(trigger, event)
        checkTrigger(trigger)
        local choices = sounds[trigger]
        if disposed or not choices or (enabled and not enabled(trigger, event)) then return end

        for index = #instances, 1, -1 do
            local instance = instances[index]
            if not instance.isPlaying and not instance.isPaused then table.remove(instances, index) end
        end

        local params = soundAPI.SoundPlaybackParams.new()
        params.type = soundAPI.SoundType.SCRIPT
        params.audioBus = audioBus
        params.volume = type(volume) == "function" and checkVolume(volume(trigger, event)) or volume
        params.delayTick = 0
        local instance = soundAPI.Play(choices[math.random(#choices)], params)
        if instance then instances[#instances + 1] = instance end
        return instance
    end

    function registration:dispose()
        if disposed then return end
        disposed = true
        registrations[self] = nil
        for _, instance in ipairs(instances) do instance:Stop() end
        sounds, instances, enabled = {}, {}, nil
    end

    registrations[registration] = true
    return registration
end

local function emit(trigger, event)
    for registration in pairs(registrations) do
        pcall(registration.play, registration, trigger, event)
    end
end

local listeners = Triggers.listeners(emit)
for name, callback in pairs(listeners) do
    events[name].Subscribe(subscriptionID, function(event)
        if next(registrations) then callback(event) end
    end)
end

function PluginShutdown()
    for registration in pairs(registrations) do registration:dispose() end
    for name in pairs(listeners) do events[name].Unsubscribe(subscriptionID) end
end

return Library
