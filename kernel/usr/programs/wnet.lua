--[[
Copyright (C) 2012  Jordan (Riddler)

    This program is free software: you can redistribute it and/or modify
    it under the terms of the GNU General Public License as published by
    the Free Software Foundation, either version 3 of the License, or
    (at your option) any later version.

    This program is distributed in the hope that it will be useful,
    but WITHOUT ANY WARRANTY; without even the implied warranty of
    MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
    GNU General Public License for more details.

    You should have received a copy of the GNU General Public License
    along with this program.  If not, see <http://www.gnu.org/licenses/>.
    
    Contact: PM Riddler80 on http://www.minecraftforum.net
]]--
--[[
NWM Packets
0 - echo
1 - echo reply
]]--

local wnet = {}

local callbacks = {}

wnet.sides = {
    "front",
    "back",
    "left",
    "right",
    "top",
    "bottom"
}
wnet.modem = nil
wnet.header = "WNET"
wnet.lookupTable = {} --Track who we can talk to and how

--Settings
wnet.forward = 0

--Packet count
local idCount = 0

--Already handled packets
local hasSeen = {}

local function getPacketID()
    local id = os.getComputerID()
    while id <  99 do
        id = id * 10
    end
    
    idCount = idCount + 1
    return id + idCount
end

local function cleanUpPacketList()
    for k, v in pairs(hasSeen) do
        if v >= os.clock() then
            hasSeen[k] = nil
            syslog:logString("wnet", "Removing handled packet ["..v.."] from list")
        end
    end
end

local function checkHandledPacketID(id)
    local timeend = hasSeen[id]
    if timeend == nil or timeend >= os.clock() then 
        hasSeen[id] = os.clock()+60
        return false
    else
        return true
    end 
end


local function updateSenderInfo(sender, packetsource)
    local senderinfo = {
        ["via"] = sender,
        ["LastMessage"] = os.clock()
    }
    wnet.lookupTable[packetsource] = senderinfo
end

--[[--------------------------------------------------
Name: validatePacket
Called: Internally
Job: Check the packet is valid
Returns: string with removed header/nill for bad packet
-]]---------------------------------------------------
local function validatePacket(message)
    local headerlen = string.len(wnet.header)
    
    if string.sub(message, 1, headerlen) == wnet.header then
        return string.sub(message, headerlen - string.len(message))
    end
    return nil
end

--[[--------------------------------------------------
Name: lookUp
Called: Internally/externally
Job: Check the lookup table for routing info
Returns: PC id or nil
-]]---------------------------------------------------
function wnet.lookUp(id)
    if wnet.lookupTable[id] ~= nil then
        return wnet.lookupTable[id]["via"]
    end
        return nil
end
--[[--------------------------------------------------
Name: sendPacket
Called: Internally
Job: Send a packet to correct destination
Returns:
-]]---------------------------------------------------
local function sendPacket(packet)
    local dest = packet[2]
    
    packet = wnet.header..textutils.serialize(packet) --TODO: create my own

    if dest == -1 then
        wnet.modem.broadcast(packet)
        syslog:logString("wnet", "Broadcasting packet")
    else
        local sendvia = wnet.lookUp(id)
        if sendvia == nil then
            wnet.modem.broadcast(packet)
            syslog:logString("wnet", "Broadcasting packet (no lookup)")
        else
            wnet.modem.send(sendvia, packet)
            syslog:logString("wnet", "Sending data direct to "..dest.." via: "..sendvia)
        end
    end
end

local function forwardPacket(packet)
    --Update TTL
    if packet[4] > 0 then
        syslog:logString("wnet", "Forwarding packet")
        packet[4] = packet[4] - 1
        sendPacket(packet)
    else
        syslog:logString("wnet", "Dropping packet, TTL expired")
    end
end

--[[--------------------------------------------------
Name: sendNWMPacket
Called: Internally/externally
Job: Send a NWM packet
Returns:
-]]---------------------------------------------------
function wnet.sendNWMPacket(typ, dest, ...)
    local targs = { ... }
    local packet = {os.getComputerID(), dest or -1, -1, 16, getPacketID()}
    local data = {typ}
    if typ == 0 then --Online notification
        packet[2] = -1 --always -1 for this packet
        table.insert(data, os.clock()) --ID, clock seems good as any
        table.insert(data, 0) --hop count
    elseif typ == 1 then --echo
        table.insert(data, os.clock()) --timestamp
        syslog:logString("wnet", "Sending echo request")
    elseif typ == 2 then --echo reply
        table.insert(data, targs[1])
    end
    packet[6] = textutils.serialize(data)
    sendPacket(packet)
end

--[[--------------------------------------------------
Name: checkDevices
Called: By a function/on startup
Job:
--Check for a modem
--Send the online notification
Returns: true/false based on modems presence
-]]---------------------------------------------------
function wnet.checkDevices()
    for _, side in pairs(wnet.sides) do
        if peripheral.isPresent(side) then
            if peripheral.getType(side) == "modem" then
                wnet.modem = peripheral.wrap(side)
                wnet.modem.open()
                wnet.sendNWMPacket(0) --send online notification
                syslog:logString("wnet", "Setup for modem on side "..side)
                return true
            end
        end
    end
    return false
end

--Check for devices on startup
wnet.checkDevices()
if wnet.modem == nil then
    print("Warning: Did not locate modem for automatic setup")
    print("Call wnet.checkDecvices() to initiate setup")
    syslog:logString("wnet", "Warning: Did not locate modem  for automatic setup")
end


local function handleNWMPacket(packet)
    local data = textutils.unserialize(packet[6])
    
    if data[1] == 0 and packet[1] ~= os.getComputerID() then --online notification, essentially a dummy packet to provide routing info (make sure its not from us)
        syslog:logString("wnet", "Online notification receaved for pc "..packet[2])
        --Update hop count
        data[3] = data[3] + 1
        --Forward
        packet[5] = textutils.serialize(data)
        forwardPacket(packet)
    elseif data[1] == 1 then --echo
        wnet.sendNWMPacket(2, packet[1], data[2]) --give it origional echo data so it can respond properly
        syslog:logString("wnet", "Sending echo reply")
    elseif data[1] == 2 then --echo reply
        local RTT = os.clock() - data[2]
        print("Echo reply: ")
        print("Sender: "..packet[1])
        print("RTT: "..RTT)
     end
end

--[[-----------------------------------------
Name: HandleWNetPacket
Called: By callback after packet validation
Args: Packet
Jobs:
--Send the data to the process attached to the port
--If it's not for us, forward it
--]]-----------------------------------------
local function handleWNetPacket(packet)
    local dest = packet[2]
    local port = packet[3]
    
    if dest == os.getComputerID() then
        if port >= 0 then --Just a regular data packet
            local callbackpid= callbacks[port]
            if callbackpid ~= nil then
                syslog:logString("wnet", "Packet receaved directed at this PC, passing to program: "..callbackpid)
                procman.sendEvent(callbackpid, "wnet-data", port, packet[5])
            else
                syslog:logString("wnet", "Error, no callback or incorrect type")
            end
        elseif port == -1 then --NWM packet
            syslog:logString("wnet", "NWM Packet receaved")
            handleNWMPacket(packet)
        end
        return
    end
    
    if port == -1 then --NWM broadcasted to everyone
            syslog:logString("wnet", "NWM BROADCAST Packet receaved")
            handleNWMPacket(packet)
    end
    
    if wnet.forward == 1 then
        syslog:logString("wnet", "Packet receaved, Not intended recipient, forwarding")
        forwardPacket(packet)
    end
end

--[[-----------------------------------------
Name: attachPort
Called: program
Args: port, callback
Jobs:
-Add callback to table
--]]-----------------------------------------
function wnet.attachPort(port)
    callbacks[port] = procman.getPID()
end

--[[-----------------------------------------
Name: Send
Called: By processes to send data
Args: destination, port, data, TTL
Jobs:
--Create a valid packet from the data
--Send the packet
--]]-----------------------------------------
function wnet.send(dest, port, data, TTL)
    if wnet.modem == nil then
        error("Can not send a packet without a modem!") --TODO: create status codes
    end
    
    if type(data) ~= "string" then return false end
    
    local packet = {os.getComputerID(), dest, port, 16 or TTL, getPacketID(), data}
    sendPacket(packet)
end



--[[-----------------------------------------
Name: Callback
Called: When a message is receaved
Args: PC the packet came from, packet
Jobs:
--Validate a packet
--update lookup table
--]]-----------------------------------------
function wnet.callback(sender, message)
    if message == nil then error("Message is nil") end
    
    syslog:logString("wnet", "Validating packet"..message)
    message = validatePacket(message)
    if message == nil then 
        syslog:logString("wnet", "Invalid packet")
        return 
    end
    syslog:logString("wnet", "Unserializing message")
    message = textutils.unserialize(message)
    
    local packetID = message[5]
    syslog:logString("wnet", "Checking if packet has been handled ["..packetID.."]")
    if checkHandledPacketID(packetID) == true then 
        syslog:logString("wnet", "Packet already handled, dropping ["..packetID.."]")
        return 
    end
    
    syslog:logString("wnet", "Updating sender info "..sender.." : "..tostring(message[1]))
    updateSenderInfo(sender, message[1]) --message[1] = source, actual sender of the packet
    
    --handle it
    syslog:logString("wnet", "Handleing packet")
    handleWNetPacket(message)
end

_G["wnet"] = wnet

local function cleanup()
    syslog:logString("wnet", "process terminated, cleaning up")
    syslog:logString("wnet", "--removing global table")
    _G["wnet"] = nil 
    
    if wnet.modem ~= nil then
        syslog:logString("wnet", "--closing modem") 
        wnet.modem.close() 
    end
end

return {
    ["name"] = "wnet",
    ["hooks"] = {
        --["think"] = wnet.checkPackets,
        ["rednet_message"] = wnet.callback,
        ["terminate"] = cleanup,
        ["think"] = cleanUpPacketList
    }
}
