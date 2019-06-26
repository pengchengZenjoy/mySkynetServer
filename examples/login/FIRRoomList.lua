local skynet = require "skynet"
require "skynet.manager"	-- import skynet.register

local roomList = {}

local CMD = {}

function CMD.getRoomList()
	skynet.ret(skynet.pack(roomList))
	--return roomList
end

skynet.start(function()
	local FIRRoom = skynet.newservice("FIRRoom")
	skynet.error("start FIRRoom="..tostring(FIRRoom))
	table.insert(roomList, FIRRoom)
	-- If you want to fork a work thread , you MUST do it in CMD.login
	skynet.dispatch("lua", function(session, source, command, ...)
		skynet.error("roomList command="..tostring(command))
		local f = assert(CMD[command])
		f()
		--skynet.ret(skynet.pack(f(source, ...)))
	end)
	skynet.register "FIRRoomList"
end)
