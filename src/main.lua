-- just to make the linter silent.

local Logger = require("logger")

-- if you think you should config something, it's right in the config module ;)
local config = require("config")


--- stubs for data that should already exist in the runntime.
--- this is just used for testing., nothing important here...

local Export = Export or {
    LoGetSelfData = function()
	Logger:info("called LoGetSelfData")
	return {}
    end,

    LoGetWorldObjects = function()
	Logger:info("called LoGetWorldObjects")
	return{}
    end
}

local DCS = DCS or {
    setUserCallbacks = function(obj)
	Logger:info("Called setUserCallbacks")
    end,

    getCurrentMission = function()
	Logger:info("Called getCurrentMission")
	return {}
    end,

    getPlayerUnit = function()
	Logger:info("called getPlayerUnit")
	return {}
    end,
    
}

-- Main entry point:

local BSE = {
    frameCounter = 0,
    relay_address = config.relay_address,
    
    last_updated = {
        playerId = 0,
        position = 0,
        worldObjects = {},
        mission = 0
    },

    max_send_ops = config.max_send_ops,

    udp_sender = require("udp")
    --tcp_sender = require("tcp"),
}

function BSE:Start()
    Logger:info("Starting...")
    self.udp_sender:Init(self.relay_address.ip, self.relay_address.port)
    Logger:info("Started")
end


function BSE:Stop()
    if self.udp_sender ~= nil then
        self.udp_sender:Close()
    end

    Logger:info("closed.")
end

function BSE:shouldUpdate(last_updated, threshold)
    return self.frameCounter - (last_updated or 0) > threshold
end

function BSE:UpdatePlayerUnit(threshold)
    if not self:shouldUpdate(self.last_updated.playerId, threshold) then return end
    
    self.udp_sender:Send({
        playerId = DCS.getPlayerUnit()                
    })   
    self.last_updated.playerId = self.frameCounter
end

function BSE:UpdatePlayerPosition(threshold)
    if not self:shouldUpdate(self.last_updated.position, threshold) then return end
    self.udp_sender:Send({
        position = Export.LoGetSelfData()                
    })
    self.last_updated.position = self.frameCounter
end

function BSE:UpdateWorldObjects(threshold)    
    local worldObjects = Export.LoGetWorldObjects()
    
    for id, unit in pairs(worldObjects) do
        local last_updated = self.last_updated.worldObjects[id] or 0
        if self:shouldUpdate(last_updated, threshold) then
            self.udp_sender:Send({
                worldObjects = {
                    [id] = unit
                }
            })
            self.last_updated.worldObjects[id] = self.frameCounter
        end

        if self.udp_sender.sent_objects > self.max_send_ops then 
            break
        end    
    end
end

function BSE:UpdateMissionData(threshold)
    if not self:shouldUpdate(self.last_updated.mission, threshold) then return end    
    self.udp_sender:Send(DCS.getCurrentMission())
    self.last_updated.mission = self.frameCounter
end

function BSE:Update()
    self.frameCounter = self.frameCounter + 1
    self.udp_sender:Update()
    
    Logger:debug("Updating..")
  
    if self.frameCounter == 1 then
        self:UpdatePlayerUnit(0)
        self:UpdatePlayerPosition(0)
        self:UpdateWorldObjects(0)
        self:UpdateMissionData(0)    
        Logger:debug("Early update, at first...")
        return
    end

    self:UpdatePlayerUnit(512)
    self:UpdatePlayerPosition(30)
    self:UpdateWorldObjects(60)
    self:UpdateMissionData(512)

    Logger:debug("Updated.")
end

DCS.setUserCallbacks({
    onSimulationStart = function() BSE:Start() end,
    onSimulationStop = function() BSE:Stop() end,
    onSimulationFrame = function() BSE:Update() end
})
