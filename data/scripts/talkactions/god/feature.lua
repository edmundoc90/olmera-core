--[[
  Feature Flags Commands
  Archivo: data/scripts/talkactions/god/feature.lua
--]]

local command = TalkAction("/feature")

function command.onSay(player, words, param)
  if not player:getGroup():hasFlag(PlayerFlag_CanEditFeatures) then
    return false
  end

  local params = param:split(" ")
  local action = params[1]
  local featureId = params[2]

  if not action or not featureId then
    player:sendTextMessage(MESSAGE_STATUS_CONSOLE_BLUE, "Usage: /feature <enable|disable|info> <featureId>")
    return false
  end

  if action == "enable" then
    local success, error = FeatureFlags.enable(featureId)
    if success then
      player:sendTextMessage(MESSAGE_STATUS_CONSOLE_BLUE, string.format("Feature '%s' enabled", featureId))
      Game.broadcastMessage(string.format("[System] Feature '%s' has been enabled", featureId), MESSAGE_STATUS_WARNING)
    else
      player:sendTextMessage(MESSAGE_STATUS_CONSOLE_BLUE, string.format("Error: %s", error))
    end
    return true
  end

  if action == "disable" then
    local success, error = FeatureFlags.disable(featureId)
    if success then
      player:sendTextMessage(MESSAGE_STATUS_CONSOLE_BLUE, string.format("Feature '%s' disabled", featureId))
      Game.broadcastMessage(string.format("[System] Feature '%s' has been disabled", featureId), MESSAGE_STATUS_WARNING)
    else
      player:sendTextMessage(MESSAGE_STATUS_CONSOLE_BLUE, string.format("Error: %s", error))
    end
    return true
  end

  if action == "info" then
    local features = FeatureFlags.list()
    local feature = features[featureId]
    
    if not feature then
      player:sendTextMessage(MESSAGE_STATUS_CONSOLE_BLUE, string.format("Feature '%s' not found", featureId))
      return false
    end
    
    local info = string.format([[
Feature: %s
Status: %s
Author: %s
Description: %s
Dependencies: %s
    ]], 
    featureId,
    feature.enabled and "Enabled" or "Disabled",
    feature.author,
    feature.description,
    table.concat(feature.dependencies, ", "))
    
    player:sendTextMessage(MESSAGE_STATUS_CONSOLE_BLUE, info)
    return true
  end

  if action == "list" then
    local features = FeatureFlags.list()
    local list = "Feature Flags:\n"
    for id, feature in pairs(features) do
      list = list .. string.format("- %s: %s\n", id, feature.enabled and "Enabled" or "Disabled")
    end
    player:sendTextMessage(MESSAGE_STATUS_CONSOLE_BLUE, list)
    return true
  end

  return false
end

command:register()