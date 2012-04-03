--[[
colors.white          = transmit bit 0
colors.orange        = transmit bit 1
colors.magenta     = transmit bit 2
colors.lightBlue     = transmit bit 3
colors.yellow        = transmiting
colors.lime            = receive bit 0
colors.pink            = receive bit 1
colors.gray            = receive bit 2
colors.lightGray     = receive bit 3
colors.cyan            = receive
colors.purple
colors.blue
colors.brown
colors.green
colors.red
colors.black            = clock
]]--

--Need hook library
if hook == nil then error("Serial library requires hooks") end

local serial = {}

serial.debug = false

--Connection types
serial.connections = {
    ["transmitter"] =  {        
        ["t0"] = colors.white,
        ["t1"] = colors.orange,
        ["t2"] = colors.magenta,
        ["t3"] = colors.lightBlue,
        ["tx"] = colors.yellow,
        ["r0"] = colors.lime,
        ["r1"] = colors.pink,
        ["r2"] = colors.gray,
        ["r3"] = colors.lightGray,
        ["rx"] = colors.cyan,
        ["clk"] = colors.black
    },
    ["receiver"] = {        
        ["t0"] = colors.lime,
        ["t1"] = colors.pink,
        ["t2"] = colors.gray,
        ["t3"] = colors.lightGray,
        ["tx"] = colors.cyan,
        ["r0"] = colors.white,
        ["r1"] = colors.orange,
        ["r2"] = colors.magenta,
        ["r3"] = colors.lightBlue,
        ["rx"] = colors.yellow,
        ["clk"] = colors.black
    }
}
--Create buffers
serial.buffers = {
    ["back"] = {
        ["active"] = false,
        ["lastclk"] = false,
        ["connection"] = serial.connections["transmitter"],
        ["buffer"] = {},
        ["outbuffer"] = {},
        ["inbuffer"] = {},
        ["gapcount"] = 0,
        ["assemblyline"] = {}
    },
    ["left"] = {
        ["active"] = false,
        ["lastclk"] = false,
        ["connection"] = serial.connections["transmitter"],
        ["buffer"] = {},
        ["outbuffer"] = {},
        ["inbuffer"] = {},
        ["gapcount"] = 0,
        ["assemblyline"] = {}
    },
    ["right"] = {
        ["active"] = false,
        ["lastclk"] = false,
        ["connection"] = serial.connections["transmitter"],
        ["buffer"] = {},
        ["outbuffer"] = {},
        ["inbuffer"] = {},
        ["gapcount"] = 0,
        ["assemblyline"] = {}
    },
    ["top"] = {
        ["active"] = false,
        ["lastclk"] = false,
        ["connection"] = serial.connections["transmitter"],
        ["buffer"] = {},
        ["outbuffer"] = {},
        ["inbuffer"] = {},
        ["gapcount"] = 0,
        ["assemblyline"] = {}
    },
    ["bottom"] = {
        ["active"] = false,
        ["lastclk"] = false,
        ["connection"] = serial.connections["transmitter"],
        ["buffer"] = {},
        ["outbuffer"] = {},
        ["inbuffer"] = {},
        ["gapcount"] = 0,
        ["assemblyline"] = {}
    },
    ["front"] = {
        ["active"] = false,
        ["lastclk"] = false,
        ["connection"] = serial.connections["transmitter"],
        ["buffer"] = {},
        ["outbuffer"] = {},
        ["inbuffer"] = {},
        ["gapcount"] = 0,
        ["assemblyline"] = {}
    }
}

--[[
Internal crossover
]]--
function serial:intCrossover(side, mode)
    if self.buffers[side] == nil then
        error("Invalid side "..side)
    end
    
    if mode then --receiver
        self.buffers[side]["connection"] = self.connections["receiver"]
    else --transmitter
        self.buffers[side]["connection"] = self.connections["transmitter"]
    end
    return
end

--[[
bool to number
]]--
function serial:boolToNum(bool)
    if bool == true then
        return 1
    else
        return 0
    end
end

--[[
get a nibble from side
]]--
function serial:getNibble(side)
    local connection = self.buffers[side]["connection"]
    local b0 = redstone.testBundledInput(side, connection["r0"])
    local b1 = redstone.testBundledInput(side, connection["r1"])
    local b2 = redstone.testBundledInput(side, connection["r2"])
    local b3 = redstone.testBundledInput(side, connection["r3"])
    return self:boolToNum(b0), self:boolToNum(b1), self:boolToNum(b2), self:boolToNum(b3)
end

function serial:nibbleToNum(b0, b1, b2, b3)
    return b0 + (b1*2) + (b2*4) + (b3*8)
end

function serial:numToNibble(num)
     if num > 15 then return nil, "Number to large" end
     
     local dec = num
     local nibble = {}

     repeat
        table.insert(nibble, dec % 2)
        dec = math.floor(dec/2)
    until dec <= 0
    
    local i
    for i=0, 4-#nibble do
        table.insert(nibble, 0)
    end
    
    --if self.debug then print("numToNibble"..num.." - "..nibble[1]..nibble[2]..nibble[3]..nibble[4]) end
    return nibble[1], nibble[2], nibble[3], nibble[4]
end

function serial:cloneTable(tbl)
    local tblcpy = {}
    for k, v in pairs(tbl) do
        tblcpy[k] = v
    end
    return tblcpy
end

function serial:processPacket(side)
    local inbuffer = self.buffers[side]["inbuffer"]
    local protocol = table.remove(inbuffer, 1)
    local fragmented = table.remove(inbuffer, 1) == 1
    local id = 0
    local number = 0
    local data = {}

    
    if fragmented then
        id = table.remove(inbuffer, 1)
        number = table.remove(inbuffer, 1)
    end
    --data is all thats left soooo
    data = inbuffer

        
    if fragmented then
        local assemblyline = self.buffers[side]["assemblyline"]
        if assemblyline[id] == nil then assemblyline[id] = {} end
        assemblyline = assemblyline[id]
        
        if number ~= 15 then
            if number == 0 then
                assemblyline["protocol"] = protocol
                assemblyline["packets"] = {}
            end
            
            table.insert(assemblyline["packets"],  {["number"] = number, ["data"] = data})
        else
            --Assemble
            table.sort(assemblyline["packets"], function(a,b) return a["number"] < b["number"] end)
            local assembleddata = {}
            for _, packet in pairs(assemblyline["packets"]) do
                self:mergeTable(assembleddata, packet["data"])
            end
            self:mergeTable(assembleddata, data)
            hook:call("netdata"..side..assemblyline["protocol"], assembleddata)
        end
    else
        hook:call("serialdata"..side..protocol, data)
        hook:call("serialdataall", side, protocol, data)
    end
end

--[[
handle redstone event
]]--
function serial:callback()
   syslog:debugString(serial.debug, "serial", "Serial callback start")
    for side, sdata in pairs(serial.buffers) do
       syslog:debugString(serial.debug, "serial", "--checking side: "..side)
                        
        local clk = redstone.testBundledInput(side, sdata["connection"]["clk"])
        local pclk = serial.buffers[side]["lastclk"] or false
        sdata["lastclk"] = clk
        
        syslog:debugString(serial.debug, "serial", "--clock stats: "..tostring(clk).."/"..tostring(pclk))
        
        if clk == true and pclk == false  and sdata["active"] == true then --Low to high, read the line if theres something to read
            if redstone.testBundledInput(side, sdata["connection"]["rx"]) == true then 
                sdata["gapcount"] = 0
                syslog:debugString(serial.debug, "serial", "----reading the line")
                
                local num = serial:nibbleToNum(serial:getNibble(side))
                
                syslog:debugString(serial.debug, "serial", "------num: "..num)
                
                table.insert(sdata["inbuffer"], num)
                
                --if num == 9 and net.debug then net:sendTable("back", {1,2,3,4,5,6,7,8}) end
            else
                sdata["gapcount"] = sdata["gapcount"] + 1
                syslog:debugString(serial.debug, "serial", "Gapcount: "..sdata["gapcount"])
                if sdata["gapcount"] == 3 and #sdata["inbuffer"] > 0 then
                    syslog:debugString(serial.debug, "serial", "Processing packet")
                    serial:processPacket(side)
                    sdata["inbuffer"] = {}
                end
            end
        elseif clk == false and pclk == true then --High to low, set the line
            local outbuffer = sdata["outbuffer"]
            if #outbuffer > 0 then
                local cpacket = outbuffer[1]
                if #cpacket > 0 then
                    local num = table.remove(cpacket, 1)
                    if num >= 0 then 
                        syslog:debugString(serial.debug, "serial", "----sending num: "..num)
                        
                        local b0, b1, b2, b3 = serial:numToNibble(num)
                        
                        --Set the outputs
                        redstone.setBundledOutput(side, 
                            --redstone.getBundledInput(side) + 
                            (sdata["connection"]["t0"] * b0) + 
                            (sdata["connection"]["t1"] * b1) + 
                            (sdata["connection"]["t2"] * b2) + 
                            (sdata["connection"]["t3"] * b3) +
                            sdata["connection"]["tx"] +
                            colours.red
                        )
                    else
                        redstone.setBundledOutput(side, colours.red) --keep red line on, will be reset later if we arnt sending more
                    end
                else
                    table.remove(outbuffer, 1)
                    syslog:debugString(serial.debug, "serial", "Removing empty table from buffer")
                end
            else
                redstone.setBundledOutput(side, 0)
            end
        end
    end
end

--[[
Listen (blocking)
]]--
function serial:listenB(side)
    local event, arg
    repeat
        event, arg = os.pullEvent()
        if event == "redstone" then
            self:callback()
        end
    until event == "redstone" and redstone.getInput("left") == true
end

function serial:listen(side, active)
    active = active or true
    self.buffers[side]["active"] = active
   syslog:logString("serial", "Listening on "..side.." set to "..tostring(active))
end

--[[
Process into correct format
]]--
function serial:format(payload, protocol)
    --if payload > 32 then return nil end
    protocol = protocol or 0
    
    local fragmented = #payload > 256
    local packetID = 0
    
    local packets = {}

    if fragmented then
        local splitdata = table.split(payload, 256)
        for num, data in pairs(splitdata) do
            local fragmentnum = num-1
            if num == #splitdata then fragmentnum = 15 end
            
            local packet = {protocol, 1, packetID, fragmentnum}
            self:mergeTable(packet, data)
            self:mergeTable(packet, {-1, -1, -1})
            table.insert(packets,  packet)
        end
    else
        local packet = {protocol, 0}
        self:mergeTable(packet, payload)
        self:mergeTable(packet, {-1, -1, -1})
        table.insert(packets, packet)
    end
    return packets
end

function serial:mergeTable(tbl, tbl2)
    for k, v in pairs(tbl2) do
        table.insert(tbl, v)
    end
end

--[[
send
]]--
--[[
function serial:send(side, num)
    self:mergeTable(self.buffers[side]["outbuffer"], self:format({num}))
    redstone.setBundledOutput(side, solours.red) --Turn on red line to show were sending
    syslog:debugString(serial.debug, "serial", "added "..num.." to outbuffer on side "..side)
end
]]--
--[[
serial.printlvl = 0
function serial:printTable(tbl)
    serial.printlvl = serial.printlvl+1
    for k, v in pairs(tbl) do
        print(string.rep("--", serial.printlvl)..tostring(k).." - "..tostring(v))
        if type(v) == "table" then serial:printTable(v) end
        os.sleep(0.05)
    end
    serial.printlvl = serial.printlvl-1
end
]]--

function serial:sendTable(side, tbl, protocol)
    local formattedpacket = self:format(tbl, protocol)
    self:mergeTable(self.buffers[side]["outbuffer"], formattedpacket)
    redstone.setBundledOutput(side, colours.red)
    --self:printTable(self.buffers[side]["outbuffer"])
    syslog:debugTable(serial.debug, "serial", "added table to outbuffer on side "..side, tbl)
end


function serial.setHook()
    hook:add("redstone", "serial", serial.callback)
    syslog:debugString(serial.debug, "serial", "Added serial hook")
end

_G["serial"] = serial
 