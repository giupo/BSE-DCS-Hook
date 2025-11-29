local Logger = require("logger")
local json = require("json")
local config = require("config")
local udp = {    
    sent_objects = 0,
    failures = 0
}

local lfs = require("lfs")

package.path  = package.path..";"..lfs.currentdir().."/LuaSocket/?.lua"
package.cpath = package.cpath..";"..lfs.currentdir().."/LuaSocket/?.dll"

function udp:Init()
    Logger:info("UDP Socket Init...")
    local socket = require("socket")
    self.socket = socket.udp()
    self.socket:setpeername(config.relay_address.ip, config.relay_address.port)
    self.socket:settimeout(0)
    -- self.socket:setoption("broadcast", true)
    self.failures = 0
    Logger:info("UDP Socket initialized with " .. config.relay_address.ip .. ":" .. config.relay_address.port)
end



function udp:Send(data)
    if not data or data == {} then
        Logger:debug("Data is empty or null, nothing to do here...")
        return false
    end

    if self.socket == nil then
        Logger:info("Socket is not initialized, doing it now...")
        self:Init()
    end

    local payload = json:dump(data)
    local rc, err_msg = self.socket:send(payload)

    if rc == nil then
        self.failures = self.failures + 1
        Logger:warning("Rc of UDP:send is nil, something is wrong ..." .. self.failures)
        if err_msg ~= nil then
            Logger:warning("Cannot send this motherfucker: " .. err_msg)            
        end
        self.socket = nil
        return false
    end


    Logger:debug("Sent rc: " .. rc)
    Logger:debug("Payload length: " .. string.len(payload))
    self.sent_objects = self.sent_objects + 1
    Logger:debug("Sent objects: ".. self.sent_objects)

    return true -- rc == string.len(payload)
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
