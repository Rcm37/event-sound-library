local player = Player
local vars = var
local triggers = {}
local systemChat = {
    [ChatType.GENERAL] = true,
    [ChatType.ENGINE] = true,
    [ChatType.SPAM] = true,
    [ChatType.GENERAL_LINKABLE] = true,
    [ChatType.BROADCAST] = true,
    [ChatType.SYSTEM_BROADCAST] = true,
    [ChatType.MISC_BROADCAST] = true,
    [ChatType.BROADCAST_GLOBAL] = true,
    [ChatType.BROADCAST_WORLD] = true,
    [ChatType.BROADCAST_FRIENDS] = true,
}

triggers.names = {
    levelUp = true,
    questCompletion = true,
    collectionLog = true,
    achievement = true,
    death = true,
    petDrop = true,
    expensiveDrop = true,
}

local function contains(text, fragment)
    return text:find(fragment, 1, true) ~= nil
end

local function escapePattern(text)
    return (text:gsub("(%W)", "%%%1"))
end

function triggers.listeners(emit)
    local function drop(event)
        local threshold = vars.VarPlayer.LOOT_BEAM.value
        if event.isOwner and event.objType.cost * 0.6 >= threshold then
            emit("expensiveDrop", event)
        end
    end

    return {
        SkillTransmit = function(event)
            if event.newGameplayLevel > event.oldGameplayLevel then emit("levelUp", event) end
        end,
        ObjStackEntityAdded = drop,
        ObjStackEntityChanged = function(event)
            if event.newCount > event.oldCount then drop(event) end
        end,
        VarTransmit = function(event)
            local variable = event.var
            if variable.typeName == "VarPlayer" and variable.valueType == 131
                and variable.configName == "CHEEVO_RECENT_COMPLETE_1"
                and event.newValue ~= event.oldValue and event.newValue >= 0 then
                emit("achievement", event)
            end
        end,
        ChatMessage = function(event)
            if not systemChat[event.chatType] then return end

            local message = event.chatMessage:gsub("<[^>]*>", "")
            if contains(message, "New collection log entry") then emit("collectionLog", event) end
            if contains(message, "Oh dear, you are dead!") then emit("death", event) end
            if contains(message, "Congratulations! You have completed:") then
                emit("questCompletion", event)
            end

            local entity = player.GetEntity()
            if not entity or not entity.displayName or entity.displayName == "" then return end
            local name = escapePattern(entity.displayName)
            if message:find("^" .. name .. " has received .* pet drop .*")
                or message:find("^" .. name .. " solved a Treasure Trail .* compass!") then
                emit("petDrop", event)
            end
        end,
    }
end

return triggers
