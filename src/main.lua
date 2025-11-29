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

    -- sender = require("udp"),
    sender = require("tcp"),
}

function BSE:onSimulationStart()
    Logger:info("Hook (v ".. config.VERSION ..") Starting...") 
    Logger:info("Started")
    self.frameCounter = 0
    self.last_updated = {
        playerId = 0,
        position = 0,
        worldObjects = {},
        mission = 0
    }
end


function BSE:onSimulationStop()
    if self.sender ~= nil then
        self:stopMission()
    end

    Logger:info("Stopped.")
end

function BSE:shouldUpdate(last_updated, threshold)
    return self.frameCounter - (last_updated or 0) > threshold
end


-- generic updater used for playerId, position and mission
function BSE:UpdateData(threshold, what, data)
    local last_updated = self.last_updated[what]
    if not self:shouldUpdate(last_updated, threshold) then return end

    if not data then
        Logger:debug("Data " .. what .." is nil, returning")
        return
    end

    Logger:debug("About to send " .. what)
    local rc = self.sender:Send({
        [what] = data
    })
    self.last_updated[what] = self.frameCounter

    -- in case we had problems, i reset player/mission so they get resent...
    
    return rc
end



function BSE:UpdatePlayerUnit(threshold)
    if self.playerid_sent == true then
        return
    end
    self.playerid_sent = self:UpdateData(threshold, "playerId", DCS.getPlayerUnit())
end

function BSE:UpdatePlayerPosition(threshold)
    self:UpdateData(threshold, "position", Export.LoGetSelfData())
end

function BSE:UpdateMissionData(threshold)
    self.mission_sent = self:UpdateData(threshold, "mission", DCS.getCurrentMission())
    self:startMission()
end


-- fairly messy updated for WorldObjects
function BSE:UpdateWorldObjects(threshold)
    local worldObjects = Export.LoGetWorldObjects()
    if worldObjects == nil then
        Logger:info("worldObjects is nil, returning...")
        return
    end

    for id, unit in pairs(worldObjects) do
        local last_updated = self.last_updated.worldObjects[id] or 0
        if self:shouldUpdate(last_updated, threshold) then
            local unit_object = {
                [id] = unit
            }

            -- Logger:info("About to send unit: ".. id)
            self.sender:Send({
                worldObjects = unit_object
            })
            self.last_updated.worldObjects[id] = self.frameCounter
        end

        if self.sender.sent_objects > self.max_send_ops then
            break
        end
    end
end


function BSE:onSimulationFrame()
    self.frameCounter = self.frameCounter + 1
    self.sender:Update()

    Logger:debug("Updating..")

    self:UpdatePlayerUnit(1024)
    self:UpdatePlayerPosition(30)
    self:UpdateWorldObjects(60)
    self:UpdateMissionData(1024)
   
    Logger:debug("Updated.")
end

function BSE:onMissionLoadEnd()
    Logger:info("Mission just ended loading, scheduling resending mission data")
    self.frameCounter = 0
    self:UpdatePlayerUnit(0)
    self:UpdatePlayerPosition(0)
    self:UpdateWorldObjects(0)
    self:UpdateMissionData(0)
end

function BSE:startMission()
    Logger:info("Send start mission...")
    local message = {}
    message.messageState =  {
	    missionRunning = true,
		missionServerRunning = true,
	}
    self.sender:Send(message)
end

function BSE:stopMission()
    Logger:info("Send stop mission...")
    local message = {}
    message.messageState =  {
	    missionRunning = false,
		missionServerRunning = false,
	}
    self.sender:Send(message)
end


DCS.setUserCallbacks({
    onSimulationStart = function() BSE:onSimulationStart() end,
    onSimulationStop = function() BSE:onSimulationStop() end,
    onSimulationFrame = function() BSE:onSimulationFrame() end,
    onMissionLoadEnd = function() BSE:onMissionLoadEnd() end
})

Logger:info("Registered Callbacks")
BSE.sender:Init()