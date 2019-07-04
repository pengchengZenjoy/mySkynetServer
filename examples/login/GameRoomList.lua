local skynet = require "skynet"
require "skynet.manager"	-- import skynet.register

local roomList = {}

local CMD = {}

function CMD.getRoomList()
	skynet.ret(skynet.pack(roomList))
	--return roomList
end

skynet.start(function()
	local LandlordRoom = skynet.newservice("LandlordRoom")
	skynet.error("start LandlordRoom="..tostring(LandlordRoom))
	table.insert(roomList, LandlordRoom)
	-- If you want to fork a work thread , you MUST do it in CMD.login
	skynet.dispatch("lua", function(session, source, command, ...)
		skynet.error("roomList command="..tostring(command))
		local f = assert(CMD[command])
		f()
		--skynet.ret(skynet.pack(f(source, ...)))
	end)
	skynet.register "GameRoomList"
end)
