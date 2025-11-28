local Logger = require("logger")
local json = require("json")
local config = require("config")
local tcp = {
    connected = false
}

function tcp:Init()
    local socket = require("socket")
    self.socket = socket.tcp()
    self.socket:settimeout(0)
    self.socket:setoption("broadcast", true)
end

function tcp:connect()
    if self.connected then return true end

    local ok, err = self.socket:connect(config.relay_address.ip, config.relay_address.port)
    self.connected = ok

    --if not ok and err ~= "timeout" then
    --    Logger:warning("TCP connect error: " .. tostring(err))
    --    self.connected = false
    --end

    return self.connected
end

function tcp:Send(data)
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

function tcp:Close()
    if self.socket ~= nil then
        self.socket:close()
    end
    self.connected = false
end

return tcp
