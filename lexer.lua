-- lexer.lua
local M = {}

local function is_number(s)
    return tonumber(s) ~= nil
end

local function is_name(s)
    return not tonumber(s) and not s:find("%s")
end

local function trim(s)
    return s:match("^%s*(.-)%s*$")
end

local function return_token(_type, expr)
    return { type=_type, value=expr }
end

function M.tokenize(input)
    local result = {}
    input = tostring(input)
    for line in input:gmatch("[^\n]+") do
        line = trim(line)
        if line:sub(1, 2) == "--" then
            -- Ignorar comentários
        else
            local i = 1
            while i <= #line do
                local c = line:sub(i, i)

                if c == "(" then
                    -- Expressão entre parênteses
                    local expr = ""
                    local depth = 1
                    i = i + 1
                    while i <= #line and depth > 0 do
                        local ch = line:sub(i, i)
                        if ch == "(" then
                            depth = depth + 1
                        elseif ch == ")" then
                            depth = depth - 1
                            if depth == 0 then
                                i = i + 1
                                break
                            end
                        end
                        expr = expr .. ch
                        i = i + 1
                    end
                    table.insert(result, return_token("EXPR", expr))

                elseif c == "\"" then
                    -- String entre aspas
                    local str = ""
                    i = i + 1
                    while i <= #line do
                        local ch = line:sub(i, i)
                        if ch == "\"" then
                            i = i + 1
                            break
                        elseif ch == "\\" and i < #line then
                            local next_ch = line:sub(i + 1, i + 1)
                            if next_ch == "\"" or next_ch == "\\" then
                                str = str .. next_ch
                                i = i + 2
                            else
                                str = str .. ch
                                i = i + 1
                            end
                        else
                            str = str .. ch
                            i = i + 1
                        end
                    end
                    table.insert(result, return_token("STRING", tostring(str)))

                elseif c:match("%s") then
                    i = i + 1 -- Ignorar espaços

                else
                    -- Token padrão (número ou nome)
                    local token = ""
                    while i <= #line and not line:sub(i, i):match("[%s%(%)\"]") do
                        token = token .. line:sub(i, i)
                        i = i + 1
                    end
                    if is_number(token) then
                        table.insert(result, return_token("NUMBER", tonumber(token)))
                    elseif is_name(token) then
                        table.insert(result, return_token("NAME", tostring(token)))
                    else
                        table.insert(result, return_token("UNKNOWN", token))
                    end
                end
            end
        end
    end

    return result
end

function M.dump(o)
   if type(o) == 'table' then
      local s = '\n{\n'
      for k,v in pairs(o) do
         if type(k) ~= 'number' then
		 k = '"'..k..'"'
	 end
	 if v ~= nil and k ~= nil then
             s = s .. '['..k..'] = ' .. M.dump(v) .. ','
         end
      end
      return s .. '\n}\n'
   else
      return tostring(o)
   end
end

return M
