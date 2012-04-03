-- requires acceess to the hook library

assert(hook ~= nil, "Net requires hook")

local net = {}

net.debug = false

net.packetsize = 16

net.buffer = {}
net.buffers = {
    ["front"] = {["clock"] = false, ["active"] = false, ["buffer"] = {}, ["outbuffer"] = {}},
    ["back"] = {["clock"] = false, ["active"] = false, ["buffer"] = {}, ["outbuffer"] = {}},
    ["left"] = {["clock"] = false, ["active"] = false, ["buffer"] = {}, ["outbuffer"] = {}},
    ["right"] = {["clock"] = false, ["active"] = false, ["buffer"] = {}, ["outbuffer"] = {}},
    ["top"] = {["clock"] = false, ["active"] = false, ["buffer"] = {}, ["outbuffer"] = {}}
}

net.decToBin = function(num)
    if num > 255 then error("Only one octet is currently supported") end
    
    local bin = {}
    local i = 1
    local decmal = num
    
    while decmal > 0 do 
        local bit = decmal % 2
        bin[i] = bit
        decmal = math.floor(decmal / 2)
        i = i + 1
    end
    
    return bin
end

net.littleToBig = function(bin)
    local count = #bin
    local newbin = {}
    for k,v in ipairs(bin) do 
        newbin[count-k+1] = v
    end
    return newbin
end

net.stripClock = function(num)
    if num > 32758 then
        return num - 32768
    end
end
--[[
net.sendPreProcess = function(data)
    if type(data) ~= "table" then error("sendPreProcess requires an array of numerical data") end
    
    local processedData = {}
    local newdata = {}
    
    if #data > net.packetsize then
        for k, v in pairs(data) do 
            if #newdata >= net.packetsize then
                table.insert(processedData, newdata)
                newdata = {}
            end
            table.insert(newdata, v)
        end
    else
        return {data}
    end
    
    table.insert(processedData, newdata)
    return processedData
end

net.sendNum = function(side, num)
    if num > 32758 then return false, "Value to big, would interfere with clock" end
    
    redstone.setBundledOutput(side, num)
    redstone.setBundledOutput(side, redstone.getBundledOutput(side) + colors.black)
    
    return true
end

net.sendArrayFunc = function(side, data)
    data = net.sendPreProcess(data)
    print("preprocessing done")
    
    for num, packet in pairs(data) do
        print("Packet: "..num)
        for k, v in ipairs(packet) do
        print("Num: "..k.." - "..#packet)
            net.sendNum(side, v)
        end
        print("Meep: "..tostring(num).." = "..#data)
        redstone.setBundledOutput(side, 0)
        coroutine.yield(num, #data)
    end
end

net.sendArray = function(self, side, data)
    local co = coroutine.create(function() net.sendArrayFunc(side, data) end)
    return function()
        local ok, num, total = coroutine.resume(co)
        if net.debug then print("resume ret: "..tostring(ok).."/"..tostring(num).."/"..tostring(total)) end
        return num, total
    end
end
]]--

net.sendPreprocess = function(data)
    if type(data) ~= "table" then error("sendPreProcess requires an array of numerical data") end
    
    local newdata = {}
    
    for k, v in pairs(data) do 
        table.insert(newdata, v)
        table.insert(newdata, v+32768)
    end
    
    table.insert(newdata, 0)
    return newdata
end


net.sendArray = function(self, side, data)
    print("preprocessing")
    data = self.sendPreprocess(data)
    print("adding to buffer")
    --table.insert(self.buffers[side]["outbuffer"], data)
    for k, v in pairs(data) do
        table.insert(self.buffers[side]["outbuffer"], v)
    end
end
    

net.callback = function()
    if net.debug then print("net callback triggered") end
    for k,v in pairs(net.buffers) do 
        if v["active"] == true then
            if net.debug then print("--"..k.." is active") end
            
            local clk = redstone.testBundledInput(k, colors.black)
            local lclk = net.buffers[k]["clock"]
            
            if net.debug then print("----clk: ["..tostring(clk).."/"..tostring(lclk).."]") end
            
            if clk == true and lclk == false then
            
                local val = net.stripClock(rs.getBundledInput(k))
                if net.debug then print("----val: "..tostring(val)) end
                table.insert(v["buffer"], val)
                if net.debug then  print("----saving "..tostring(val).." from side "..k) end
            end

            net.buffers[k]["clock"] = clk

        end
    end
end

net.sendCallback = function()
    local clockactive = redstone.getInput("right")
    
    if clockactive and net.clockactive == false then
        print("clock active")
        for k, v in pairs(net.buffers) do
            local out = v["outbuffer"]
            if #out > 0 then
                print(k.." has data")
                redstone.setBundledOutput(k, out[1])
                if net.debug then print("sending "..out[1]) end
                table.remove(out, 1)
                print("done")
            end
        end
    end
    net.clockactive = clockactive
end


net.init = function(self)
    print(tostring(hook))
    if self.initialized ~= true then
        self.initialized = true
        hook:add("redstone", "netlib", self.callback)
        hook:add("redstone", "netlibsend", self.sendCallback)
        print("Initialized")
    end
end

net.listen = function(self, side)
    self.buffers[side]["active"] = true
end

return net