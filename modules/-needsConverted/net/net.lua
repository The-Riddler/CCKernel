--[[ 
This protocol is self-routing. 
    The user is not expected to half to tell it where to send the packet
    beyond telling it which sides have network connections
    
In a network management packet the "port" is replaced with the type of network management packet

Packet format - all 8 bits unless specified otherwise
1 - source
2 - destination
3 - port
4 - TTL
5 - isNetworkManagementPacket
4 - data

Network management packet types
0 - Announce (just saying hi!)
1 - ping
2 - ping reply
3 - WhereIs
4 - WhereIsResponse

ping packet data
ping request:
1 - Time sent

ping reply:
1 - Time sent from ping requiest
2 - Time receaved

Whereis packet data is blank
]]--
--if serial == nil then error("Net lib requires serial") end --And hook but serial wont load without hook so

local net = {}

net.packet_forwarding = 0
net.create_lookup = 0
net.mode = 0    --0[managed] 1[monitor]
net.allow_broadcast_whole_packet = 0

net.debug = false

net.lookup = {}
net.sides = {}
net.whoIsBuffer = {} --Things we don't know where to send yet

local function sendPacket(data, excludeside)
    local dest = data[2]
    local destside = net.lookupPC(dest)
    
    if destside ~= nil then
        syslog:logString("net", "Sending to "..tostring(dest).."-"..destside)
        net.sendHandle(destside, data)
        return
    end
    
    if net.allow_broadcast_whole_packet == 1 or (data[5] == 1 and data[3] == 3) then --or is whereIs packet
        syslog:debugString(net.debug, "net", "Broadcasting whole packet")
        for k,v in pairs(net.sides) do
            if v == true  and k ~= excludeside then 
                net.sendHandle(k, data)
            end
        end
    elseif net.create_lookup == 1 then
        syslog:debugString(net.debug, "net", "Putting packet in buffer, looking for destination") 
        table.insert(net.whoIsBuffer, data) --store for later
        net.sendNWMPacket(3, dest, excludeside)
    else
        error("NET: can't forward whole packets, or create a lookup table. So what do you expect me to do?")
    end
end
    
local function forwardPacket(source, dest, port, TTL, nwm,  data, fromside)
    if TTL == 0 then --Dead
        syslog:logString("Warning: packet TTL expired, dropping ["..tostring(source).." "..tostring(dest).."]")
        return
    end
    
    table.insert(data, 1, nwm)
    table.insert(data, 1, TTL-1)
    table.insert(data, 1, port)
    table.insert(data, 1, dest)
    table.insert(data, 1, source) --preserve the source
    
    syslog:debugString(net.debug, "net", "Sending forwarding packet")
    
    sendPacket(data, fromside)
end

function net.callback(side, data)
    local source = table.remove(data, 1)
    local dest = table.remove(data, 1)
    local port = table.remove(data, 1)
    local TTL = table.remove(data, 1)
    local nwm = table.remove(data, 1)
    
    if net.create_lookup == 1 then
        if net.lookup[source] ~= side then
            syslog:debugString(net.debug, "net", "Adding entry to lookup table ["..tostring(source).." = "..side.."]")
            net.lookup[source] = side
        end
    end
    
    local isdest = (dest == os.getComputerID())
    
    if isdest and nwm == 1 then
        syslog:debugString(net.debug, "net", "Network management packet received [Source:"..tostring(source).." Dest:"..tostring(dest).." Type:"..tostring(port).." TTL:"..tostring(TTL).."]")
        net.handleNWMPacket(source, dest, port, TTL, data, side)
        return
    end
    
    if isdest then
        syslog:logString("net", "Packet received, calling hook [Port:"..tostring(port).." Source:"..tostring(source).." Dest:"..tostring(dest).."]")
        hook:call("net"..tostring(port), source, dest, data)
    elseif net.packet_forwarding == 1 then
        syslog:logString("net", "Forwarding packet from "..tostring(source).." to "..tostring(dest))
        forwardPacket(source, dest, port, TTL, nwm, data, side)
    end
    
    if net.mode == 1 then
        hook:call("netmonitor", source, dest, port, TTL, nwm, data)
    end
end

function net.lookupPC(pc)
    local count = 0
    local side
    for k, v in pairs(net.sides) do
        if v then 
            count = count + 1 
            side = k
        end
    end
    
    if count <= 0 then
        error("No sides active on net")
    elseif count == 1 then --Only one place to go
        return side
    elseif net.create_lookup == 1 then
        local destside = net.lookup[pc]
        if destside == nil or destside == "" then
            syslog:debugString(net.debug, "net", "Lookup failed for "..tostring(pc))
            return nil
        else
            syslog:debugString(net.debug, "net", "Lookup successfull for "..tostring(pc).." side "..tostring(destside))
            return destside
        end
    else
        syslog:debugString(net.debug, "net", "Lookup disabled")
        return nil
    end
end
    
function net.send(dest, port, data)
    exide = exside or ""
    
    table.insert(data, 1, 0)
    table.insert(data, 1, 16)
    table.insert(data, 1, port)
    table.insert(data, 1, dest)
    table.insert(data, 1, os.getComputerID())
    
    sendPacket(data)
end

function net.sendNWMPacket(packetType, dest, exside)
    syslog:logString("net", "Sending network management packet "..tostring(packetType))
    if packetType == 3 then --Only reason to use this is because we don't know where the destination is
        local packet = {os.getComputerID(), dest, 3, 16, 1}
        for k, v in pairs(net.sides) do
            if v == true and k ~= exside then
                net.sendHandle(k, packet)
            end
        end
        syslog:debugString(net.debug, "net", "Sent whereis packet")
    end
end

function net.handleNWMPacket(source, dest, packetType, TTL, data, side)
    if packetType == 3 then
        syslog:debugString(net.debug, "net", "Receaved whereIs request, sending response")
        local packet = {os.getComputerID(), source, 4, 16, 1}
        net.sendHandle(side, packet)
    elseif packetType == 4 then
        syslog:debugTable(net.debug, "net", "Receaved whereIs response, resending waiting packets", net.whoIsBuffer)
        for k, v in pairs(net.whoIsBuffer) do
            if v[2] == source then
                net.sendHandle(side, v)
                syslog:debugString(net.debug, "net", "Sent waiting packet")
            end
        end
    end
end

function net.enableSide(side, active)
    active = active == true
    serial:listen(side, active)
    net.sides[side] = active
    syslog:logString("net", "Side "..side.." set to "..tostring(active))
end

--Setup for serial library
if serial then
    syslog:logString("net", "Serial library detected, setting up for serial communication")
    
    net.sendHandle = function(side, data)
        syslog:debugTable(net.debug, "net", "Sending packet", data)
        local newpacket = {}
        for k, v in ipairs(data) do --order is important here
            local bits = bit.tobits(v)
            table.fill(bits, 0, 8)
            local splitbits = table.split(bits, 4)
            table.insert(newpacket, bit.tonumb(splitbits[1]))
            table.insert(newpacket, bit.tonumb(splitbits[2]))
            syslog:debugString(net.debug, "net", "Spliting number into 4bit segments ["..tostring(v).."/"..table.concat(splitbits[1])..":"..tostring(table.concat(splitbits[2])).."]")
        end
        syslog:debugTable(net.debug, "net", "Finished serial table for "..side, newpacket)
        serial:sendTable(side, newpacket, 1)
    end
    
    hook:add("serialdataall", "net", function(side, protocol, data)
    
        if net.sides[side] ~= true then
            syslog:debugString(net.debug, "net", "Got packet on in-active side dropping")
            return
        end
        
        if protocol ~= 1 then 
            syslog:debugString(net.debug, "net", "Got packet with incorrect protocol dropping")
            return
        end

        if #data % 2 ~= 0 then
            syslog:logString("net", "Warning: malformed net packet, dropping")
            return
        end
        
        local netpacket = {}
        while #data > 0  do
            
            --print("Getting numbers")
            local lowernum = table.remove(data, 1)
            local highernum = table.remove(data, 1)
            --print("["..tostring(lowernum)..","..tostring(highernum).."] Turning to bits")
            local lowerbits = table.fill(bit.tobits(lowernum), 0, 4)
            local higherbits = bit.tobits(highernum) --lower bit for 0 is {}, so does not append properly 
            --print("Joining")
            local numbits = table.join(lowerbits, higherbits)
            --table:print(numbits)
            local num = bit.tonumb(numbits)
            --print("["..tostring(num).."] Adding to netpacket "..tostring(#data))
            table.insert(netpacket, num)
            --table.insert(netpacket, bit.tonumb(table.join(bit.tobits(table.remove(data, 1)), bit.tobits(table.remove(data, 1)))))
        end
        syslog:debugTable(net.debug, "net", "Table being passed to callback", netpacket)
        net.callback(side, netpacket)
    end)
    
    syslog:logString("net", "Net library setup for serial")
end

syslog:logString("net", "Net library loaded")

_G["net"] = net
