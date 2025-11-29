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
