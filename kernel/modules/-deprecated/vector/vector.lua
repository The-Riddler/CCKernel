local vector = {}

function vector.new(x, y, z)
    if type(x) ~= "number" or type(y) ~= "number" or type(z) ~= "number" then
        error("Vector only takes 3 numbers as arguments")
    end
    
    local newvec = {}
    setmetatable(newvec, vector.mt)
    
    newvec[1] = x
    newvec[2] = y
    newvec[3] = z
end

function vector.add(vec1, vec2)
    return vector.new(vec1[1] + vec2[1], vec1[2] + vec2[2], vec1[3] + vec2[3])
end

function vector.sub(vec1, vec2)
    return vector.new(vec1[1] - vec2[1], vec1[2] - vec2[2], vec1[3] - vec2[3])
end

function vector.mul(vec1, vec2)
    return vector.new(vec1[1] * vec2[1], vec1[2] * vec2[2], vec1[3] * vec2[3])
end

function vector.toString(vec)
    return "{"..vec[1]..", "..vec[2]..", "..vec[3].."}"
end

vector.mt = {
    ["__add"] = vector.add,
    ["__sub"] = vector.sub,
    ["__mul"] = vector.mul,
    ["__tostring"] = vector.toString
}

_G["vector"] = vector