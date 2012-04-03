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
wnet.forward = 1

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
            syslog:logString("wnet", "Sending data direct to "..dest)
        end
    end
end

--[[--------------------------------------------------
Name: sendNWMPacket
Called: Internally/externally
Job: Send a NWM packet
Returns:
-]]---------------------------------------------------
function wnet.sendNWMPacket(typ, dest)
    local packet = {os.getComputerID(), dest or -1, -1, 16}
    if typ == 0 then --Online notification
        table.insert(packet, 0) --type
        table.insert(packet, os.clock()) --ID, clock seems good as any
        table.insert(packet, 0) --hop count
    end
    
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
    if packet[5] == 0 then --online notification, essentialyl a dummy packet to provide routing info
        syslog:logString("wnet", "Onlien notification receaved for pc "..source)
        --Update hop count
        packet[7] = packet[7] + 1
        --Forward
        forwardPacket(packet)
        return
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
    local source = packet[1]
    local dest = packet[2]
    local port = packet[3]
    local TTL = packet[4]
    
    if dest == os.getComputerID() then
        if port >= 0 then --Just a regular data packet
            --Send to whatever program has that port
            syslog:logString("wnet", "Packet receaved directed at this PC, passing to program")
        elseif protocol == -1 then --NWM packet
            syslog:logString("wnet", "NWM Packet receaved")
            handleNWMPacket(packet)
        end
    elseif id == -1 then --broadcasted to everyone
            syslog:logString("wnet", "NWM BROADCAST Packet receaved")
            handleNWMPacket(packet)
    elseif wnet.forward == 1 then
        syslog:logString("wnet", "Packet receaved, Not intended recipient, forwarding")
        forwardPacket(packet)
    end
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
    
    --Add source port and dest and TTL to packet
    table.insert(data, 1, 16 or TTL) --TTL
    table.insert(data, 1, port)
    table.insert(data, 1, dest)
    table.insert(data, 1, os.getComputerID())
    
    sendPacket(data)
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
    print(message)
    syslog:logString("wnet", "Unserializing message")
    message = textutils.unserialize(message)
    
    syslog:logString("wnet", "Updating sender info")
    updateSenderInfo(sender, message[1]) --message[1] = source, actual sender of the packet
    
    --handle it
    syslog:logString("wnet", "Handleing packet")
    handleWNetPacket(message)
end

_G["wnet"] = wnet

local function cleanup()
    print("cleaning up")
    print("--removing global table")
    _G["wnet"] = nil 
    
    if wnet.modem ~= nil then
        print("--closing modem") 
        wnet.modem.close() 
    end
end

return {
    ["name"] = "wnet",
    ["hooks"] = {
        --["think"] = wnet.checkPackets,
        ["rednet_message"] = wnet.callback,
        ["terminate"] = cleanup
    }
}
