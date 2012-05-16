local debug = {}
local stack = {}

function debug.markCall(name, info)
    table.insert(stack, {["name"] = name, ["info"] = info})
end

function debug.markRet()
    table.remove(stack, #stack)
end

local infoprint = {
    ["string"] = function(info) return info end,
    ["number"] = function(number) return tostring(number) end
}

function debug.stackTraceStr()
    if #stack == 0 then return nil end
    local stacktrace = ""
    for k, v in pairs(stack) do
        stacktrace = stacktrace..v["name"]
        
        local info = v["info"]
        if info ~= nil then
            local typ = type(info)
            local infotostring = infoprint[typ]
            if infotostring ~= nil then
                stacktrace = stacktrace.." - "..infotostring(info)
            else
                print("[debug] Warning unknown type "..typ)
            end
        end
        stacktrace = stacktrace.."\n"
    end
    return stacktrace
end

function debug.error(str)
   print("Error: "..str)
   print("Stack trace:\n"..debug.stackTraceStr())
   syslog:logTable("debug", str.." Stack trace:", stack)
end

_G["debug"] = debug

--[[ meep
function switch(c)
    local swtbl = {
        casevar = c,
        caseof = function (self, code)
        local f
        if (self.casevar) then
            f = code[self.casevar] or code.default
        else
            f = code.missing or code.default
        end
        if f then
            if type(f)=="function" then
                return f(self.casevar,self)
            else
                error("case "..tostring(self.casevar).." not a function")
            end
        end
    end
    }
    return swtbl
end

switch(c) : caseof {
    [1]   = function (x) print(x,"one") end,
    [2]   = function (x) print(x,"two") end,
    [3]   = 12345, -- this is an invalid case stmt
  default = function (x) print(x,"default") end,
  missing = function (x) print(x,"missing") end,
}

]]--