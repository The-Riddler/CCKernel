local xorcipher = {}

local function iterate(cipherobj, num)
    if num == nil or num <= 0 then
        num = 10
    end
    
    if cipherobj.pos >= cipherobj.datalen then
        if cipherobj.decrypt then
            return true, cipherobj.data
        else
        return true, cipherobj.ciphertext, cipherobj.key
    end
    
    if cipherobj.decrypt then
        for i=cipherobj.pos, math.min(cipherobj.pos+num, cipherobj.datalen) do
            local char = string.sub(cipherobj.ciphertext, i , i)
            
            local keychar = string.byte(cipherobj.key, i, i) --ASCII codes that can go in a string (i.e exclude controll chars)
            local char = bit.bxor(string.byte(char), keychar)
            
            cipherobj.data = cipherobj.data..string.char(char)
        end
    else
        for i=cipherobj.pos, math.min(cipherobj.pos+num, cipherobj.datalen) do
            local char = string.sub(cipherobj.data, i , i)
            
            local keychar = math.random(32,254) --ASCII codes that can go in a string (i.e exclude controll chars)
            local cipherchar = bit.bxor(string.byte(char), keychar)
            
            cipherobj.ciphertext = cipherobj.ciphertext..string.char(cipherchar)
            cipherobj.key = cipherobj.key..string.char(keychar)
        end
    end
    
    cipherobj.pos = cipherobj.pos+num
    
    return false, (cipherobj.pos*100)/cipherobj.datalen
end

function xorcipher.create(decrypt, data, key)
    decrypt = decrypt or false

    if type(data) ~= "string" then return false end
    if decrypt and (key == nil or type(key) ~= "string") then return false end
    
    local cipherobj = {}
    cipherobj.decrypt = decrypt
    cipherobj.pos = 1
    cipherobj.datalen = string.len(data)
    cipherobj.iterate = iterate
    --the data
    if decrypt then
        cipherobj.data = ""
        cipherobj.ciphertext = data
        cipherobj.key = key
    else
        cipherobj.data = data
        cipherobj.ciphertext = ""
        cipherobj.key = ""
    end
    
    return cipherobj
end

_G["xorcipher"] = xorcipher