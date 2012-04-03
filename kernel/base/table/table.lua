local tbl = {}

function tbl.clone(tbl, cpmeta)
    local lookup_table = {}
    
    local function _copy(obj, cpmeta)
        if type(obj) ~= "table" then
            return obj
        elseif lookup_table[obj] then
            return lookup_table[obj]
        end
        
        local new_table = {}
        lookup_table[obj] = new_table
        for index, value in pairs(obj) do
            new_table[_copy(index)] = _copy(value, cpmeta)
        end
        
        if cpmeta == true then
            return setmetatable(new_table, getmetatable(obj))
        else
            return new_table
        end
    end
    
    return _copy(tbl, cpmeta == true)
end

function tbl.merge(tbl1, tbl2)
    local function _merge(tbl1, tbl2)
        for k, v in pairs(tbl2) do
            if type(v) == "table" then
                if tbl1[k] ~= nil and type(tbl1[k]) == "table" then
                    _merge(tbl1[k], v)
                else
                    tbl1[k] = v
                end
            else
                tbl1[k] = v
            end
        end
    end
    _merge(tbl1, tbl2)
end

function tbl.fill(tbl, fillData, num)
    while #tbl < num do
        table.insert(tbl, fillData)
    end
    return tbl
end
    

function tbl:print(tbl, level)
    level = level or 0
    
    for k, v in pairs(tbl) do
        term.write(string.rep(" ", level*2))
        if type(v) ~= "table" then
            print(tostring(k).. " = "..tostring(v))
        else
            print(tostring(k)..":")
            if v ~= tbl then
                self:print(v, level + 1)
            end
        end
    end
end


function tbl.split(tbl, count)
    local result = {}
    local ctbl = {}
    for k, v in ipairs(tbl) do
        if #ctbl >= count then
            table.insert(result, ctbl)
            ctbl = {}
        end
        table.insert(ctbl, v)
    end
    table.insert(ctbl, v)
    table.insert(result, ctbl)
    return result
end

function tbl.join(tbl, ...)
    for k, v in ipairs(arg) do
        for _, val in ipairs(v) do
            table.insert(tbl, val)
        end
    end
    return tbl --Syntactical prittyness only
end

return tbl