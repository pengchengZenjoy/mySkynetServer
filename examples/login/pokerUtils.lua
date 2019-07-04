local skynet = require "skynet"

local utils = {}

function utils.getShufflePokerList()
	local pokerList = {}
	for i=3,15 do
		for j=1,4 do
			local pokerInfo = {}
			pokerInfo.num = i
			pokerInfo.type = j
			table.insert(pokerList, pokerInfo)
		end
	end
	local pokerInfo = {}
	pokerInfo.num = 16
	pokerInfo.type = 5
	table.insert(pokerList, pokerInfo)
	local pokerInfo = {}
	pokerInfo.num = 17
	pokerInfo.type = 5
	table.insert(pokerList, pokerInfo)
	local shuffleList = {}
	local pokerNum = #pokerList
	for i=pokerNum,2,-1 do
		local index = math.random(1, i)
		table.insert(shuffleList, pokerList[index])
		table.remove(pokerList, index)
	end
	table.insert(shuffleList, pokerList[1])
	return shuffleList
end

function utils.getSeriesNum(numListMap, num)
    local map = numListMap[num]
    if not map then
        return 0
    end
    local list = {}
    for k,v in pairs(map) do
        table.insert(list, k)
    end
    local sortfunction = function(item1, item2)
        return item1 < item2
    end
    table.sort(list, sortfunction)
    local isSeries = true
    if #list > 1 then
        local startNum = list[1]
        for i=2,#list do
            if (startNum + 1) ~= list[i] then
                isSeries = false
                break
            end
            startNum = list[i]
        end
    end
    if isSeries then
        return #list
    else
        return 0
    end
end

function utils.getModeInfo(pokerList)
    local info = {}
    local flowerMap = {}
    local numMap = {}
    local numToFlowerMap = {}
    local numListMap = {}
    local maxNum = -1
    local pokerNum = #pokerList
    for i=1,pokerNum do
        local num = pokerList[i].num
        if not flowerMap[num] then
            flowerMap[num] = 1
        else
            flowerMap[num] = flowerMap[num] + 1
        end
        if num > maxNum then
            maxNum = num
        end
    end 
    for k,num in pairs(flowerMap) do
        numToFlowerMap[num] = k
        if not numListMap[num] then
            numListMap[num] = {}
        end
        numListMap[num][k] = true
        if not numMap[num] then
            numMap[num] = 1
        else
            numMap[num] = numMap[num] + 1
        end
    end
    local numMapNum = 0
    local numMapKey = nil
    local numMapValue = nil
    for k,v in pairs(numMap) do
        numMapKey = k
        numMapValue = v
        numMapNum = numMapNum + 1
    end
    --[[print("getSeriesNum(1)="..tostring(self:getSeriesNum(numListMap,1)))
    print("getSeriesNum(2)="..tostring(self:getSeriesNum(numListMap,2)))
    print("getSeriesNum(3)="..tostring(self:getSeriesNum(numListMap,3)))
    print("getSeriesNum(4)="..tostring(self:getSeriesNum(numListMap,4)))]]
    if numMapNum == 1 then
        if numMapKey == 1 then
            if numMapValue == 1 then
                info.type = "one"
                info.num = maxNum
                return info
            end
            if maxNum <= 15 and utils.getSeriesNum(numListMap,1) >= 5then
                info.type = "oneSeries"..numMapValue
                info.num = maxNum
                return info
            end
        elseif numMapKey == 2 and (numMapValue >= 3 or numMapValue==1) and utils.getSeriesNum(numListMap,2) > 0 then
            info.type = "twoSeries"..tostring(numMapValue)
            info.num = maxNum
            return info
        elseif numMapKey == 3 and utils.getSeriesNum(numListMap,3) > 0 then
            info.type = "threeSeries"..tostring(numMapValue)
            info.num = maxNum
            return info
        end
    elseif numMapNum > 1 then
        local threeSeriesNum = utils.getSeriesNum(numListMap,3)
        if threeSeriesNum > 0 and numMap[1] == threeSeriesNum and pokerNum == threeSeriesNum*4 then
            info.type = "threeSeries"..tostring(threeSeriesNum).."AddOne"
            info.num = maxNum
            return info
        elseif threeSeriesNum > 0 and numMap[2] == threeSeriesNum and pokerNum == threeSeriesNum*5 then
            info.type = "threeSeries"..tostring(threeSeriesNum).."AddTwo"
            info.num = maxNum
            return info
        end
    end
    if #pokerList == 2 and pokerList[1].type == 5 and pokerList[2].type == 5 then --火箭
        info.type = "killAll"
        info.num = 100
    elseif #pokerList == 4 and numMap[4] == 1 then --炸弹
        info.type = "killAll"
        info.num = pokerList[1].num
    elseif #pokerList == 8 and numMap[4] == 1 and numMap[2] == 2 then
        info.type = "fourAddFour"
        info.num = numToFlowerMap[4]
    elseif #pokerList == 6 and numMap[4] == 1 and numMap[1] == 2 then
        info.type = "fourAddTwo"
        info.num = numToFlowerMap[4]
    elseif #pokerList == 6 and numMap[4] == 1 and numMap[2] == 1 then
        info.type = "fourAddTwo"
        info.num = numToFlowerMap[4]
    elseif #pokerList == 5 and numMap[3] == 1 and numMap[2] == 1 then
        info.type = "threeAddTwo"
        info.num = numToFlowerMap[3]
    elseif #pokerList == 4 and numMap[3] == 1 and numMap[1] == 1 then
        info.type = "threeAddOne"
        info.num = numToFlowerMap[3]
    end
    if not info.type then
        info = nil
    end
    return info
end

function utils.isPlayCardCorrect(recPlayPokerList, recPlayPokerListUserId, messageTb, userId)
    local selectList = messageTb.pokerList
    if not selectList then
    	return false
    end
    if #selectList == 0 then
    	skynet.error("没有选择牌")
        return false
    end
    local modeInfo = utils.getModeInfo(selectList)
    if modeInfo then
        print("modeInfo.type = "..tostring(modeInfo.type))
        print("modeInfo.num = "..tostring(modeInfo.num))
   	else
   		skynet.error("不能这样出牌")
        return false
    end
    if recPlayPokerListUserId == nil or recPlayPokerListUserId == userId then
        return true
    else
        local oldModeInfo = utils.getModeInfo(recPlayPokerList)
        if oldModeInfo then
            print("oldModeInfo.type = "..tostring(oldModeInfo.type))
            print("oldModeInfo.num = "..tostring(oldModeInfo.num))
            if modeInfo.type == oldModeInfo.type then
                if modeInfo.num > oldModeInfo.num then
                    return true
                else
                    skynet.error("请出比上家大的牌")
                    return false
                end
            elseif modeInfo.type ~= oldModeInfo.type then
                if modeInfo.type == "killAll" then
                    return true
                else
                    skynet.error("请和上家出同类型的牌")
                    return false
                end
            end
        else
            return true
        end
    end
    return false
end

return utils
