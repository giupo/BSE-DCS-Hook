local Logger = require("logger")
local json = require("json")
local config = require("config")


local tcp = {
    connected = false,
    sent_objects = 0
}

function tcp:Init()
    local socket = require("socket")
    tcp:Close()
    self.socket = socket.tcp()
    self.socket:settimeout(0)
    self.sent_objects = 0
end

function tcp:connect()
    if self.connected then return true end

    local ok, err = self.socket:connect(config.relay_address.ip, config.relay_address.port)
    self.connected = ok

    if not ok and err ~= "timeout" then
        Logger:warning("TCP connect error: " .. err)
        self.connected = false
    end

    return self.connected
end

function tcp:Send(data)

    if data == nil or data == {} then
        Logger:debug("Data is nil or empty, nothing to do here..")
        return false
    end

    if self.socket == nil then
        Logger:warning("Cannot connect, TCP not initizlized")
        self:Init()
    end

    if not self:connect() then
        Logger:warning("Trying to send, but still disconnected, check the server...")
        return false
    end



    local payload = json:dump(data)
    local rc, err_msg = self.socket:send(payload)

    if err_msg ~= nil then
        Logger:warning("Cannot send this motherfucker: " .. err_msg)
        if err_msg == "closed" then
            self.connected = false
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
    self.connected = false
end

function tcp:Update()
    self.sent_objects = 0
end

return tcp
