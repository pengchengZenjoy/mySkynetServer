local skynet = require "skynet"

local CMD = {}

local playerList = {}

function CMD.enterRoom()

end


skynet.start(function()

	-- If you want to fork a work thread , you MUST do it in CMD.login
	skynet.dispatch("lua", function(session, source, command, ...)
		local f = assert(CMD[command])
		skynet.ret(skynet.pack(f(source, ...)))
	end)
end)
