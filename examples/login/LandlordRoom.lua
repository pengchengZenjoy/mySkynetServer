local skynet = require "skynet"
local pokerUtils = require "login.pokerUtils"

skynet.register_protocol {
	name = "client",
	id = skynet.PTYPE_CLIENT,
	unpack = skynet.tostring,
}

local gamePlayNum = 3

local playDelayTime = 2500
local CMD = {}

local playerList = {}
local playerMap = {}
local pokerList = {}

local landlordIndex = nil
local curMoveIndex = nil
local timeSession = nil
local nameList = {}

local recPlayPokerList = {}
local recPlayPokerListUserId = nil

local curGate
function CMD.enterRoom(source, gate, username, userId)
	if #playerList >= gamePlayNum then
		return false
	end
	curGate = gate
	skynet.error("enterRoom gate="..tostring(gate))
	skynet.error("enterRoom username="..tostring(username))
	local playInfo = {}
	playInfo.gate = gate
	playInfo.username = username
	playInfo.userId = userId
	table.insert(playerList,playInfo)
	playerMap[userId] = playInfo
	return true
end

local function updateNameList()
	nameList = {}
	for i,playInfo in ipairs(playerList) do
		table.insert(nameList, playInfo.username)
	end
end

local function exitRoom(userId)
	curMoveIndex = nil
	chessMap = {}
	for i,playInfo in ipairs(playerList) do
		if playInfo.userId == userId then
			skynet.error("Room afk userId="..tostring(userId))
			table.remove(playerList, i)
			playerMap[userId] = nil
			return
		end
	end
end

local function removeTimeCallBack()
	if timeSession then
		skynet.remove_timeout(timeSession)
		timeSession = nil
	end
end

function CMD.afk(source, userId)
	exitRoom(userId)
	updateNameList()
	local msgTb = {
        msgId = "S_EXITROOM",
        userId = userId,
    }
	skynet.send(curGate, "lua", "roomSendMsg", nameList, msgTb)
	removeTimeCallBack()
end

function sendNothing()
	local info = {}
	info.cancelResult = true
	skynet.ret(skynet.pack(info))
end

function sendError(userId, msg)
	local msgTb = {
        msgId = "GAMEERROR",
        errorContent = msg,
    }
	skynet.send(curGate, "lua", "roomSendMsg", {userId}, msgTb)
end

local function nextCallLandlord()
	skynet.error("nextCallLandlord curMoveIndex="..tostring(curMoveIndex))
	curMoveIndex = curMoveIndex + 1
	if curMoveIndex > gamePlayNum then
		curMoveIndex = 1
	end
	local msgTb = {
        msgId = "CALLLANDLORD",
        userId = playerList[curMoveIndex].userId
    }
	skynet.send(curGate, "lua", "roomSendMsg", nameList, msgTb)
	timeSession = skynet.timeoutMy(playDelayTime, nextCallLandlord)
end

local function nextPlayCard()
	skynet.error("nextPlayCard curMoveIndex="..tostring(curMoveIndex))
	local curUserId = playerList[curMoveIndex].userId
	curMoveIndex = curMoveIndex + 1
	if curMoveIndex > gamePlayNum then
		curMoveIndex = 1
	end
	local msgTb = {
        msgId = "PLAYPOKER",
        userId = curUserId,
        nextUserId = playerList[curMoveIndex].userId,
    }
	skynet.send(curGate, "lua", "roomSendMsg", nameList, msgTb)
	timeSession = skynet.timeoutMy(playDelayTime, nextPlayCard)
end

local function removePokerList(userId, removeList)
	local pokerList = playerMap[userId].pokerList
	local isInRemoveList = function(pokerInfo)
		for i=1,#removeList do
			local removeInfo = removeList[i]
			if removeInfo.num == pokerInfo.num and removeInfo.type == pokerInfo.type then
				return true
			end
		end
		return false
	end
	for i=#pokerList,1,-1 do
		local pokerInfo = pokerList[i]
		if isInRemoveList(pokerInfo) then
			table.remove(pokerList, i)
		end
	end
end

local function request(userId, messageTb)
	msgId = messageTb.msgId
	skynet.error("Room request userId="..tostring(userId))
	skynet.error("Room request msgId="..tostring(msgId))
	if msgId == "GAMEREADY" then
		local readyNum = 0
		nameList = {}
		local userIdList = {}
		for i,playInfo in ipairs(playerList) do
			if playInfo.userId == userId then
				playInfo.isReady = true
			end
			if playInfo.isReady then
				readyNum = readyNum + 1
				table.insert(nameList, playInfo.username)
				info = {}
				info.userId = tostring(playInfo.userId)
				skynet.error("Room userIdList info.userId="..tostring(info.userId))
				table.insert(userIdList,info)-- {["userId"]=playInfo.userId})
			end
		end
		
		if readyNum == gamePlayNum then
			recPlayPokerList = {}
			recPlayPokerListUserId = nil
			pokerList = pokerUtils.getShufflePokerList()
			curMoveIndex = math.random(1,gamePlayNum)
			local beginUserId = playerList[curMoveIndex].userId
			for i=1,gamePlayNum do
				local playPokerList = {}
				for j=1,17 do
					local index = (i-1)*17 + j
					table.insert(playPokerList, pokerList[index])
				end
				playerList[i].pokerList = playPokerList
				local curUserName = playerList[i].username
				skynet.error("Room DEALPOKER curUserId="..tostring(curUserId))
				local msgTb = {
			        msgId = "DEALPOKER", 
			        userId = beginUserId,
			        pokerList = playPokerList,
			        playList = userIdList
			    }
			    skynet.error("Room DEALPOKER curGate="..tostring(curGate))
				skynet.send(curGate, "lua", "roomSendMsg", {curUserName}, msgTb)
			end
			timeSession = skynet.timeoutMy(playDelayTime, nextCallLandlord)
		end
	elseif msgId == "CALLLANDLORD" then
		local isLandlord = messageTb.isLandlord
		skynet.error("CALLLANDLORD playerList[curMoveIndex].userId="..tostring(playerList[curMoveIndex].userId))
		if userId ~= playerList[curMoveIndex].userId then
			sendError(userId, "not your turn")
			return
		end
		removeTimeCallBack()
		if isLandlord then
			landlordIndex = curMoveIndex
			local addPokerList = {}
			for i=1,3 do
				local index = #pokerList - i + 1
				table.insert(addPokerList, pokerList[index])
			end
			local msgTb = {
		        msgId = "GAMESTART",
		        userId = playerList[curMoveIndex].userId,
		        pokerList = addPokerList,
		    }
			skynet.send(curGate, "lua", "roomSendMsg", nameList, msgTb)
		else
			nextCallLandlord()
		end
	elseif msgId == "PLAYPOKER" then
		local pokerList = messageTb.pokerList
		if not pokerUtils.isPlayCardCorrect(recPlayPokerList, recPlayPokerListUserId, messageTb, userId) then
			pokerList = nil
		end
		removeTimeCallBack()
		if pokerList then
			recPlayPokerList = pokerList
			recPlayPokerListUserId = userId
			removePokerList(userId, pokerList)
		end
		local nowPokerList = playerMap[userId].pokerList
		if #nowPokerList == 0 then
			local msgTb = {
		        msgId = "S_PLAYRESULT",
		        userId = userId,
		        pokerList = pokerList,
		    }
			skynet.send(curGate, "lua", "roomSendMsg", nameList, msgTb)
			return
		end
		skynet.error("PLAYPOKER pokerList="..tostring(pokerList))
		curMoveIndex = curMoveIndex + 1
		if curMoveIndex > gamePlayNum then
			curMoveIndex = 1
		end
		local msgTb = {
	        msgId = "PLAYPOKER",
	        userId = userId,
	        pokerList = pokerList,
	        nextUserId = playerList[curMoveIndex].userId,
	    }
		skynet.send(curGate, "lua", "roomSendMsg", nameList, msgTb)
		timeSession = skynet.timeoutMy(playDelayTime, nextPlayCard)
	elseif msgId == "EXITROOM" then
		removeTimeCallBack()
		exitRoom(userId)
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
