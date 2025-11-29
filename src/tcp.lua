local Logger = require("logger")
local json = require("json")
local config = require("config")


local tcp = {
    sent_objects = 0,
}

function tcp:Init()
    local socket = require("socket")
    self.socket = socket.tcp()
    self.socket:settimeout(0)
    self.sent_objects = 0
    self.socket:connect(config.relay_address.ip, config.relay_address.port)
end


function tcp:Send(data)
    if not data or data == {} then
        Logger:debug("Data is empty or null, nothing to do here...")
        return false
    end

    local payload = json:dump(data)
    local rc, err_msg = self.socket:send(payload)

    if err_msg ~= nil then
        Logger:warning("Cannot send this motherfucker: " .. err_msg)
        if err_msg == "closed" then
            self:Close()
            self:Init()
        end
        return false
    end

    Logger:debug("Sent rc: " .. rc)
    Logger:debug("Payload length: " .. string.len(payload))
    self.sent_objects = self.sent_objects + 1
    Logger:debug("Sent objects: ".. self.sent_objects)

    return true
end

function tcp:Close()
    if self.socket ~= nil then
        self.socket:close()
    end
end

function tcp:Update()
    self.sent_objects = 0
end

return tcp
