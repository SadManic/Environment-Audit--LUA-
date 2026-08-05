-- json.lua
-- No json lib on these executors so rolling our own. Pure Luau, no dependencies.

local JSON = {}

-- ===== Encode =====

local JSON_ESCAPES = {
    ['"']  = '\\"',
    ['\\'] = '\\\\',
    ['\n'] = '\\n',
    ['\r'] = '\\r',
    ['\t'] = '\\t',
    ['\b'] = '\\b',
    ['\f'] = '\\f',
}

local function jsonEncodeString(str)
    str = tostring(str):gsub('[%c"\\]', function(c)
        return JSON_ESCAPES[c] or string.format('\\u%04x', string.byte(c))
    end)
    return '"' .. str .. '"'
end

-- Array = keys 1..N with no gaps, else it's an object
local function isArray(t)
    local n = 0
    for _ in pairs(t) do n = n + 1 end
    if n == 0 then return true end
    for i = 1, n do
        if t[i] == nil then return false end
    end
    return true
end
JSON.isArray = isArray

function JSON.encode(value)
    local vType = type(value)

    if value == nil then
        return "null"
    elseif vType == "boolean" then
        return tostring(value)
    elseif vType == "number" then
        if value ~= value or value == math.huge or value == -math.huge then
            return "null" -- Not valid JSON
        end
        return tostring(value)
    elseif vType == "string" then
        return jsonEncodeString(value)
    elseif vType == "table" then
        if isArray(value) then
            local parts = {}
            for i = 1, #value do
                parts[i] = JSON.encode(value[i])
            end
            return "[" .. table.concat(parts, ",") .. "]"
        else
            local parts = {}
            for k, v in pairs(value) do
                table.insert(parts, jsonEncodeString(tostring(k)) .. ":" .. JSON.encode(v))
            end
            return "{" .. table.concat(parts, ",") .. "}"
        end
    else
        return "null" -- Functions, userdata, etc
    end
end

-- ===== Decode =====

local function jsonSkipWhitespace(str, pos)
    local _, stop = str:find("^[ \t\r\n]*", pos)
    return stop + 1
end

local jsonDecodeValue -- Forward decl

local function jsonDecodeError(msg, str, pos)
    error(string.format("JSON decode error at position %d: %s (near '%s')",
        pos, msg, str:sub(pos, pos + 15)))
end

local function jsonDecodeString(str, pos)
    if str:sub(pos, pos) ~= '"' then jsonDecodeError("expected '\"'", str, pos) end
    pos = pos + 1
    local out = {}
    while true do
        local c = str:sub(pos, pos)
        if c == "" then
            jsonDecodeError("unterminated string", str, pos)
        elseif c == '"' then
            pos = pos + 1
            break
        elseif c == "\\" then
            local esc = str:sub(pos + 1, pos + 1)
            local simple = { n = "\n", t = "\t", r = "\r", b = "\b", f = "\f", ['"'] = '"', ["\\"] = "\\", ["/"] = "/" }
            if simple[esc] then
                table.insert(out, simple[esc])
                pos = pos + 2
            elseif esc == "u" then
                local hex = str:sub(pos + 2, pos + 5)
                local codepoint = tonumber(hex, 16)
                if not codepoint then jsonDecodeError("bad \\u escape", str, pos) end
                -- utf8 encode
                if codepoint < 0x80 then
                    table.insert(out, string.char(codepoint))
                elseif codepoint < 0x800 then
                    table.insert(out, string.char(
                        0xC0 + math.floor(codepoint / 0x40),
                        0x80 + (codepoint % 0x40)))
                else
                    table.insert(out, string.char(
                        0xE0 + math.floor(codepoint / 0x1000),
                        0x80 + (math.floor(codepoint / 0x40) % 0x40),
                        0x80 + (codepoint % 0x40)))
                end
                pos = pos + 6
            else
                jsonDecodeError("unknown escape \\" .. esc, str, pos)
            end
        else
            table.insert(out, c)
            pos = pos + 1
        end
    end
    return table.concat(out), pos
end

local function jsonDecodeNumber(str, pos)
    local numStr = str:match("^-?%d+%.?%d*[eE]?[%+%-]?%d*", pos)
    if not numStr or numStr == "" then jsonDecodeError("invalid number", str, pos) end
    local num = tonumber(numStr)
    if not num then jsonDecodeError("invalid number literal: " .. numStr, str, pos) end
    return num, pos + #numStr
end

local function jsonDecodeArray(str, pos)
    pos = pos + 1 -- skip '['
    local arr = {}
    pos = jsonSkipWhitespace(str, pos)
    if str:sub(pos, pos) == "]" then return arr, pos + 1 end

    while true do
        local value
        value, pos = jsonDecodeValue(str, pos)
        table.insert(arr, value)
        pos = jsonSkipWhitespace(str, pos)
        local c = str:sub(pos, pos)
        if c == "," then
            pos = jsonSkipWhitespace(str, pos + 1)
        elseif c == "]" then
            return arr, pos + 1
        else
            jsonDecodeError("expected ',' or ']'", str, pos)
        end
    end
end

local function jsonDecodeObject(str, pos)
    pos = pos + 1 -- skip '{'
    local obj = {}
    pos = jsonSkipWhitespace(str, pos)
    if str:sub(pos, pos) == "}" then return obj, pos + 1 end

    while true do
        pos = jsonSkipWhitespace(str, pos)
        local key
        key, pos = jsonDecodeString(str, pos)
        pos = jsonSkipWhitespace(str, pos)
        if str:sub(pos, pos) ~= ":" then jsonDecodeError("expected ':'", str, pos) end
        pos = jsonSkipWhitespace(str, pos + 1)
        local value
        value, pos = jsonDecodeValue(str, pos)
        obj[key] = value
        pos = jsonSkipWhitespace(str, pos)
        local c = str:sub(pos, pos)
        if c == "," then
            pos = jsonSkipWhitespace(str, pos + 1)
        elseif c == "}" then
            return obj, pos + 1
        else
            jsonDecodeError("expected ',' or '}'", str, pos)
        end
    end
end

jsonDecodeValue = function(str, pos)
    pos = jsonSkipWhitespace(str, pos)
    local c = str:sub(pos, pos)
    if c == '"' then
        return jsonDecodeString(str, pos)
    elseif c == "{" then
        return jsonDecodeObject(str, pos)
    elseif c == "[" then
        return jsonDecodeArray(str, pos)
    elseif c == "-" or c:match("%d") then
        return jsonDecodeNumber(str, pos)
    elseif str:sub(pos, pos + 3) == "true" then
        return true, pos + 4
    elseif str:sub(pos, pos + 4) == "false" then
        return false, pos + 5
    elseif str:sub(pos, pos + 3) == "null" then
        return nil, pos + 4
    else
        jsonDecodeError("unexpected token", str, pos)
    end
end

-- Returns nil + err instead of throwing on bad input
function JSON.decode(str)
    if type(str) ~= "string" or str:match("^%s*$") then
        return nil, "empty input"
    end
    local ok, value, pos = pcall(function()
        local v, p = jsonDecodeValue(str, 1)
        return v, p
    end)
    if not ok then
        return nil, tostring(value)
    end
    return value
end

return JSON
