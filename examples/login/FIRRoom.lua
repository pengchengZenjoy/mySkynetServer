local skynet = require "skynet"

skynet.register_protocol {
	name = "client",
	id = skynet.PTYPE_CLIENT,
	unpack = skynet.tostring,
}

local CMD = {}

local playerList = {}

local curMoveIndex = nil
local nameList = {}

local chessMap = {}

local curGate
function CMD.enterRoom(source, gate, username, userid)
	if #playerList >= 2 then
		return false
	end
	curGate = gate
	skynet.error("enterRoom gate="..tostring(gate))
	skynet.error("enterRoom username="..tostring(username))
	local playInfo = {}
	playInfo.gate = gate
	playInfo.username = username
	playInfo.userid = userid
	table.insert(playerList,playInfo)
	return true
end

local function updateNameList()
	nameList = {}
	for i,playInfo in ipairs(playerList) do
		table.insert(nameList, playInfo.username)
	end
end

local function exitRoom(userid)
	curMoveIndex = nil
	chessMap = {}
	for i,playInfo in ipairs(playerList) do
		if playInfo.userid == userid then
			skynet.error("Room afk userid="..tostring(userid))
			table.remove(playerList, i)
			return
		end
	end
end

function CMD.afk(source, userid)
	exitRoom(userid)
	updateNameList()
	local msgTb = {
        msgId = "S_EXITROOM",
        userId = userId,
    }
	skynet.send(curGate, "lua", "roomSendMsg", nameList, msgTb)
end

local function checkIsEnd(curIndexX, curIndexY, curMoveIndex)
	local dirList = {{1,0}, {1,1}, {1,-1}}
	for i,dir in ipairs(dirList) do
		local num = 0
		local dirX = dir[1]
		local dirY = dir[2]
		for j=1,100 do
			local indexX = curIndexX + dirX*j
			local indexY = curIndexY + dirY*j
			if chessMap[indexX] and chessMap[indexX][indexY] == curMoveIndex then
				num = num + 1
			else
				break
			end
		end
		dirX = -dirX
		dirY = -dirY
		for j=1,100 do
			local indexX = curIndexX + dirX*j
			local indexY = curIndexY + dirY*j
			if chessMap[indexX] and chessMap[indexX][indexY] == curMoveIndex then
				num = num + 1
			else
				break
			end
		end
		if num >= 4 then
			return true
		end
	end
	return false
end

local function request(userId, messageTb)
	msgId = messageTb.msgId
	skynet.error("Room request userId="..tostring(userId))
	skynet.error("Room request msgId="..tostring(msgId))
	if msgId == "GAMEREADY" then
		local readyNum = 0
		nameList = {}
		for i,playInfo in ipairs(playerList) do
			if playInfo.userid == userId then
				playInfo.isReady = true
			end
			if playInfo.isReady then
				readyNum = readyNum + 1
				table.insert(nameList, playInfo.username)
			end
		end
		if readyNum == 2 then
			curMoveIndex = 1
			chessMap = {}
			skynet.error("Room request playerList[curMoveIndex].userid="..tostring(playerList[curMoveIndex].userid))
			local msgTb = {
		        msgId = "S_G_MOVE",
		        userId = playerList[curMoveIndex].userid
		    }
			skynet.send(curGate, "lua", "roomSendMsg", nameList, msgTb)
		end
	elseif msgId == "PLAYCHESS" then
		skynet.error("Room request playerList[curMoveIndex].userid="..tostring(playerList[curMoveIndex].userid))
		if userId == playerList[curMoveIndex].userid then
			local curIndexX = messageTb.chessIndexX
			local curIndexY = messageTb.chessIndexY
			if not chessMap[curIndexX] then
				chessMap[curIndexX] = {}
			end
			if chessMap[curIndexX][curIndexY] ~= nil then
				return
			end
			chessMap[curIndexX][curIndexY] = curMoveIndex
			skynet.error("Room request curIndexX="..tostring(curIndexX))
			skynet.error("Room request curIndexY="..tostring(curIndexY))

			if checkIsEnd(curIndexX, curIndexY, curMoveIndex) then
				local msgTb = {
			        msgId = "S_PLAYRESULT",
			        userId = userId,
			        chessIndexX = messageTb.chessIndexX,
		        	chessIndexY = messageTb.chessIndexY,
			    }
				skynet.send(curGate, "lua", "roomSendMsg", nameList, msgTb)
			else
				local msgTb = {
			        msgId = "S_PLAYCHESS",
			        userId = userId,
			        chessIndexX = messageTb.chessIndexX,
			        chessIndexY = messageTb.chessIndexY,
			    }
				skynet.send(curGate, "lua", "roomSendMsg", nameList, msgTb)
				curMoveIndex = curMoveIndex + 1
				if curMoveIndex > 2 then
					curMoveIndex = 1
				end
			end
		end
	elseif msgId == "EXITROOM" then
		exitRoom(userid)
		local msgTb = {
	        msgId = "S_EXITROOM",
	        userId = userId,
	    }
		skynet.send(curGate, "lua", "roomSendMsg", nameList, msgTb)
	end
end

skynet.start(function()

	-- If you want to fork a work thread , you MUST do it in CMD.login
	skynet.dispatch("lua", function(session, source, command, ...)
		local f = assert(CMD[command])
		skynet.ret(skynet.pack(f(source, ...)))
	end)

	skynet.dispatch("client", function(_,_, info)
		-- the simple echo service
		skynet.error("Room dispatch client")
		local userId, messageTb = skynet.unpack(info)
		request(userId, messageTb)
		local info = {}
	    info.cancelResult = true
	    skynet.ret(skynet.pack(info))
	end)
end)
