-- BUNDLE AUTOGENERATO
-- project_root: /home/user/m024000/projects/Hook/src

package.preload["config"] = function()
    local config = {
        PKGNAME = "BSE-Export",
    
        -- this is the address towards who we are flooding with DCS data.
        -- usually this should be our middleware that exposes data as a REST API
        --
        -- This is where you wanna change the ip if the relay is not on the same
        -- host where DCS is running.
        
        relay_address = {
    	ip = "127.0.0.1",
            port = 6666
        },
    
        -- Number of packets (UDP packets) per frame allowed to send
        -- this is used to not flood and hung DCS waiting for I/O ops.
        max_send_ops = 256
    }
    
    return config
end

package.preload["debug"] = function()
    local debug = {}
    
    local Logger = require("logger")
    
    -- debug functions:
    
    function debug.writeFile(path, text)
        local file = io.open(path, "w")
        if not file then
            Logger:error("Cannot open file " .. path)
            return false
        end
    
        file:write(text)
        file:close()
        return true
    end
    
    return debug
end

package.preload["json"] = function()
    -- json 
    
    local json = {}
    
    local Logger = require("logger")
    local net = net or {
        lua2json = function(obj)
    	Logger:info("called lua2json")
        end
    }
    
    
    function json:dump(obj)
        local data, err = pcall(function() net.lua2json(obj) end)
        if err ~= nil then
    	Logger:info("Error dumping JSON data...")
        end
    
        return data
    end
    
    
    return json
end

package.preload["logger"] = function()
    -- Logger Wrapper, the original sucks big time.
    local log = log or {
        DEBUG = "DEBUG",
        INFO = "INFO",
        WARNING = "WARNING",
        ERROR = "ERROR",
    
        write = function(name, level, msg)
    	print("["..name.."]", level, msg)
        end
    }
    
    local config = require("config")
    
    local Logger = {}
    
    function Logger:info(msg)
        log.write(config.PKGNAME, log.INFO, msg)
    end
    
    function Logger:warning(msg)
        log.write(config.PKGNAME, log.WARNING, msg)
    end
    
    function Logger:error(msg)
        log.write(config.PKGNAME, log.ERROR, msg)
    end
    
    function Logger:debug(msg)
        log.write(config.PKGNAME, log.DEBUG, msg)
    end
    
    return Logger
end

package.preload["tcp"] = function()
    local Logger = require("logger")
    local json = require("json")
    
    local tcp = {
        ip =  "127.0.0.1",
        port = 6666,
        connected = false
    }
    
    function tcp:init(ip, port)
        local socket = require("socket")
        self.socket = socket.tcp()
        self.socket:settimeout(0)
        self.socket:setoption("broadcast", true)
    end
    
    function tcp:connect()
        if self.connected then return true end
    
        local ok, err = self.socket:connect(self.ip, self.port)
        self.connected = ok
    
        --if not ok and err ~= "timeout" then
        --    Logger:warning("TCP connect error: " .. tostring(err))
        --    self.connected = false
        --end
    
        return self.connected
    end
    
    function tcp:send(data)
        if self.socket == nil then
            Logger:warning("Cannot connect, TCP not initizlized")
            return
        end
    
        self:connect()
    
        local payload = (data and json:dump(data) or "")
        local rc, err_msg = self.socket:send(payload)
    
        if err_msg ~= nil then
            Logger:warning("Cannot send this motherfucker: " .. err_msg)
            if err_msg == "closed" then
                self.connected = false
            end
        end
    end
    
    function tcp:close()
        if self.socket ~= nil then
            self.socket:close()
        end
        self.connected = false
    end
    
    return tcp
end

package.preload["udp"] = function()
    local Logger = require("logger")
    local json = require("json")
    
    local udp = {
        ip =  "127.0.0.1",
        port = 6666,
        sent_objects = 0
    }
    
    function udp:Init(ip, port)
        local socket = require("socket")
        self.socket = socket.udp()
        self.socket:settimeout(0)
        self.socket:setoption("broadcast", true)
    end
    
    function udp:Send(data)
        if self.socket == nil then
            Logger:warning("Cannot send, UDP not initizlized")
            return
        end
    
        local payload = (data and json:dump(data) or "")    
        local rc, err_msg = self.socket:sendto(payload, self.ip, self.port)
    
        if err_msg ~= nil then
            Logger:warning("Cannot send this motherfucker: " .. err_msg)
            return
        end
    
        self.sent_objects = self.sent_objects + 1
    end
    
    function udp:Close()
        if self.socket ~= nil then
            self.socket:close()
        end
    end
    
    function udp:Update()
        self.sent_objects = 0
    end
    
    
    return udp
end

-- MAIN
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
