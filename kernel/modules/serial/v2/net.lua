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
if hook == nil then error("Net library requires hooks") end

local net = {}

--Connection types
net.connections = {
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
net.buffers = {
    ["back"] = {
        ["active"] = false,
        ["lastclk"] = false,
        ["connection"] = net.connections["transmitter"],
        ["buffer"] = {},
        ["outbuffer"] = {}
    }
}

--[[
Internal crossover
]]--
function net:intCrossover(side, mode)
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
function net:boolToNum(bool)
    if bool == true then
        return 1
    else
        return 0
    end
end

--[[
get a nibble from side
]]--
function net:getNibble(side)
    local connection = self.buffers[side]["connection"]
    local b0 = redstone.testBundledInput(side, connection["r0"])
    local b1 = redstone.testBundledInput(side, connection["r1"])
    local b2 = redstone.testBundledInput(side, connection["r2"])
    local b3 = redstone.testBundledInput(side, connection["r3"])
    return self:boolToNum(b0), self:boolToNum(b1), self:boolToNum(b2), self:boolToNum(b3)
end

function net:nibbleToNum(b0, b1, b2, b3)
    return b0 + (b1*2) + (b2*4) + (b3*8)
end

function net:numToNibble(num)
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

--[[
handle redstone event
]]--
function net:callback()
    if net.debug then print("netcallback") end
    for side, sdata in pairs(net.buffers) do
        if net.debug then print("--checking side: "..side) end
        
        local clk = redstone.testBundledInput(side, sdata["connection"]["clk"])
        local pclk = net.buffers[side]["lastclk"] or false
        sdata["lastclk"] = clk
        
        if net.debug then print("--clock stats: "..tostring(clk).."/"..tostring(pclk)) end
        
        if clk == true and pclk == false  then --Low to high, read the line if theres something to read
            if redstone.testBundledInput(side, sdata["connection"]["rx"]) == true then 
                if net.debug then print("----reading the line") end
                
                local num = net:nibbleToNum(net:getNibble(side))
                
                if net.debug then print("------num: "..num) end
                if num == 9 then net:sendTable("back", {1,2,3,4,5,6,7,8}) end
            end
        elseif clk == false and pclk == true then --High to low, set the line
            local outbuffer = sdata["outbuffer"] --looks better
            if #outbuffer > 0 then
                local num = table.remove(outbuffer, 1)
                if num >= 0 then 
                    if net.debug then print("----sending num: "..num) end
                    
                    local b0, b1, b2, b3 = net:numToNibble(num)
                    
                    --Set the outputs
                    redstone.setBundledOutput(side, 
                        --redstone.getBundledInput(side) + 
                        (sdata["connection"]["t0"] * b0) + 
                        (sdata["connection"]["t1"] * b1) + 
                        (sdata["connection"]["t2"] * b2) + 
                        (sdata["connection"]["t3"] * b3) +
                        sdata["connection"]["tx"]
                    )
                else
                    redstone.setBundledOutput(side, 0)
                end
            end
        end
    end
end

--[[
Listen (blocking)
]]--
function net:listen(side)
    local event, arg
    repeat
        event, arg = os.pullEvent()
        if event == "redstone" then
            self:callback()
        end
    until event == "redstone" and redstone.getInput("left") == true
end

--[[
Process into correct format
]]--
function net:format(payload, protocol)
    --if payload > 32 then return nil end
    local packet = {protocol or 0}
    
    if type(payload) == "table" then
        for k, v in pairs(payload) do
            table.insert(packet, v)
        end
    else
        table.insert(packet, payload)
    end
     
     table.insert(packet, -1)
     table.insert(packet, -1)
     table.insert(packet, -1)
     return packet
end

function net:mergeTable(tbl, tbl2)
    for k, v in pairs(tbl2) do
        table.insert(tbl, v)
    end
end

--[[
send
]]--
function net:send(side, num)
    self:mergeTable(self.buffers[side]["outbuffer"], self:format(num))
    if self.debug then print("added "..num.." to outbuffer on side "..side) end
end

function net:sendTable(side, tbl)
    self:mergeTable(self.buffers[side]["outbuffer"], self:format(tbl))
end


function net:setHook()
    hook:add("redstone", "net", net.callback)
end

return net
    
    
    
    
    
    
    
    
    
    
    
    
    
    