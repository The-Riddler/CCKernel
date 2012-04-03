local procdata = {}

local errorcodes = {}
errorcodes.STAT_404 = 0
errorcodes.STAT_CALL = 1
errorcodes.STAT_LOAD = 2
errorcodes.STAT_OK_RET = 3
errorcodes.STAT_DATAERROR = 4

local function run(path)
    if not fs.exists(path) or fs.isDir(path) then return errorcodes.STAT_404 end
    
    local retval
    
    local code, err = loadfile(dir)
    if code ~= nil then
        setfenv(code, getfenv(1)) --Set to our environment
        local ok, err = pcall(code)
        if not ok then return errorcodes.STAT_CALL, err end
        retval = err
    else
        return errorcodes.STAT_LOAD
    end
    
    --Parse program data return
    if type(retval) ~= table then
        return errorcodes.STAT_OK_RET, retval
    else
        local celement = retval["hooks"]
        if type(celement) == "table" then --We have hooks to add
            for k, v in ipairs(celement) do
                local event = v[1]
                local name = v[2]
                local func = v[3]
                
                if type(event) ~= "string" or type(name) ~= "string" or type(func) ~= "function" then return errorcodes.STAT_DATAERROR, "Incorrect return type(s) for 'hook' data" end
                hook:add(v[1], v[2], v[3])
    end
end
            