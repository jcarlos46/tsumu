-- vm.lua
local M = {}

M.STACK = {}
STASH = {}
M.NAMES = {}
M.MAX_LOOP = 128
M.TOTAL_LOOP = 0
M.DEBUG_MODE = false
M.INT_MODE = false
M.EXIT = false

function M.build_token(_type, expr)
    return { type=_type, value=expr }
end

function M.build_number(value)
    return M.build_token("NUMBER", tonumber(value))
end

function M.build_expr(value)
    return M.build_token("EXPR", value)
end

function M.build_string(value)
    return M.build_token("STRING", tostring(value))
end

function M.build_list(value)
    return M.build_token("LIST", value)
end

function M.error_msg(msg) 
    if M.INT_MODE then
        print(msg)
    else
        error(msg)
    end
end

function _G.trim(s)
  return s:match("^%s*(.-)%s*$")
end

local function type_comp(a_type, b_type, msg)
    if a_type ~= b_type then
        M.error_msg(msg.." : trying to operate on different types - "..a_type.." and "..b_type)
        return false
    end
    return true
end

local function type_check(expected_type, a_type, msg)
    if a_type ~= expected_type then
        M.error_msg(msg.." : "..expected_type.." was expected, but recieved "..a_type)
        return false
    end
    return true
end

local function number_check(a_type, msg)
    return type_check("NUMBER", a_type, msg)
end

function M.expr_check(a_type, msg)
    return type_check("EXPR", a_type, msg)
end

function M.string_check(a_type, msg)
    return type_check("STRING", a_type, msg)
end

function M.push(token)
    table.insert(M.STACK, token)
end

function M.pop()
    if #M.STACK == 0 then
        M.error_msg("POP: STACK UNDERFLOW!")
    end
    return table.remove(M.STACK)
end

local function eq ()
    local a = M.pop()
    local b = M.pop()
    if not type_comp(a.type, b.type, "EQ") then return end
    if a.value == b.value then
        M.push(M.build_number(1))
    else
        M.push(M.build_number(0))
    end
end

local function gt ()
    local a = M.pop()
    local b = M.pop()
    if not number_check(a.type, "GT") then return end
    if not number_check(b.type, "GT") then return end
    if not type_comp(a.type, b.type, "GT") then return end
    if b.value > a.value then
        M.push(M.build_number(1))
    else
        M.push(M.build_number(0))
    end
end

local function lt()
    local a = M.pop()
    local b = M.pop()
    if not number_check(a.type, "LT") then return end
    if not type_comp(a.type, b.type, "LT") then return end
    if b.value < a.value then
        M.push(M.build_number(1))
    else
        M.push(M.build_number(0))
    end
end

local function _not()
    local a = M.pop()
    if not number_check(a.type, "NOT") then return end
	if a.value ~= 0 then
        M.push(M.build_number(1))
    else
        M.push(M.build_number(0))
    end
end

local function len()
    M.push(M.build_number(#M.STACK))
end

local function cond()
   local f = M.pop()
   local t = M.pop()
   local cond = M.pop()
   if not number_check(cond.type, "COND") then return end
   if cond.value > 0 then M.push(t) else M.push(f) end
end

local function swap()
   local a = M.pop()
   local b = M.pop()
   M.push(a)
   M.push(b)
end

local function quote()
    local a = M.pop()
    if a.type == "NUMBER" or a.type == "EXPR" then
        M.push(M.build_string(tostring(a.value)))
    elseif a.type == "LIST" then
        local str = ""
        for _,u in pairs(a.value) do
                str = str .. u.value .. " "
        end
        str = "["..string.sub(str,1,-2).."]"
        M.push(M.build_string(str))
    else
        M.push(a)
    end
end

local function compose()
   local a = M.pop()
   local b = M.pop()
   M.push(M.build_expr(b.value.." "..a.value))
end

local function max_loop_def()
   local a = M.pop()
   assert(a.type == "NUMBER", "MAX-LOOP-DEF: NUMBER expected, but got "..a.type)
   M.MAX_LOOP = a.value
end

local function stash_in()  table.insert(STASH, M.pop()) end
local function stash_out() local a = table.remove(STASH) M.push(a) end

local function ps_list(list)
    local str = ""
    for _, u in ipairs(list) do
        if u.type == "LIST" then
            str = str .. ps_list(u.value) .. " "
        else
            str = str .. tostring(u.value) .. " "
        end
    end
    return "[" .. (str:sub(1, -2)) .. "]"
end

local function ps()
    for _, i in ipairs(M.STACK) do
        if i.type == "LIST" then
            io.write(ps_list(i.value))
        else
            io.write("[" .. tostring(i.value) .. "]")
        end
    end
    io.write("\n")
end

local function exit()
   M.EXIT = true
end

local function contains()
    local needle = M.pop()
    local haystask = M.pop()

    assert(needle.type == "STRING", "CONTAINS: STRING expected, but got "..needle.type)
    assert(haystask.type == "LIST", "CONTAINS: LIST expected, but got "..haystask.type)

    local qnt = 0
    for _, v in pairs(haystask.value) do
        if v.value == needle.value then
            qnt = qnt + 1
        end
    end

    return M.push(M.build_number(qnt))
end

local function deep_copy(orig, copies)
    copies = copies or {}
    if type(orig) ~= 'table' then
        return orig
    elseif copies[orig] then
        return copies[orig]  -- evita loops em tabelas auto-referenciadas
    end

    local copy = {}
    copies[orig] = copy
    for k, v in pairs(orig) do
        copy[deep_copy(k, copies)] = deep_copy(v, copies)
    end
    return setmetatable(copy, getmetatable(orig))
end

local function pick()
    local len = M.pop()
    if not number_check(len.type, "PICK") then return end
    if len.value > #M.STACK then
        M.error_msg("PICK: STACK UNDERFLOW")
        return
    end
    local i = #M.STACK - len.value
    local a = deep_copy(M.STACK[i])
    table.insert(M.STACK, a)
end


-- Operações disponíveis
M.NAMES["pop"] = M.pop
M.NAMES["+"] = function()
        local a = M.pop()
        local b = M.pop()

        if not type_comp(a.type, b.type, "PLUS") then return end
        if not number_check(a.type, "PLUS") then return end
        if not number_check(b.type, "PLUS") then return end

        M.push(M.build_number(a.value + b.value))
    end
M.NAMES["*"] = function()
    local a = M.pop()
    local b = M.pop()

    if not type_comp(a.type, b.type, "MULT") then return end
    if not number_check(a.type, "MULT") then return end
    if not number_check(b.type, "MULT") then return end

    M.push(M.build_number(a.value * b.value))
end
M.NAMES["/"] = function()
    local a = M.pop()
    local b = M.pop()

    if not type_comp(a.type, b.type, "DIV") then return end
    if not number_check(a.type, "DIV") then return end
    if not number_check(b.type, "DIV") then return end

    M.push(M.build_number(b.value / a.value))
end
M.NAMES["%"] = function()
    local a = M.pop()
    local b = M.pop()

    if not type_comp(a.type, b.type, "MOD") then return end
    if not number_check(a.type, "MOD") then return end
    if not number_check(b.type, "MOD") then return end

    M.push(M.build_number(b.value % a.value))
end
M.NAMES["-"] = function()
    local a = M.pop()
    local b = M.pop()

    if not type_comp(a.type, b.type, "MOD") then return end
    if not number_check(a.type, "MOD") then return end
    if not number_check(b.type, "MOD") then return end

    M.push(M.build_number(b.value - a.value))
end
M.NAMES["="] = eq
M.NAMES[">"] = gt
M.NAMES["<"] = lt
M.NAMES["not"] = _not
M.NAMES["len"] = len
M.NAMES["pick"] = pick
M.NAMES["cond"] = cond
M.NAMES["quote"] = quote
M.NAMES["compose"] = compose
M.NAMES["swap"] = swap
M.NAMES["stash>"] = stash_in
M.NAMES["<stash"] = stash_out
M.NAMES["contains?"] = contains
M.NAMES["max-loop-def"] = max_loop_def
M.NAMES["ps"] = ps
M.NAMES["exit"] = exit
M.NAMES["error-msg"] = function() M.error_msg(M.pop()) end
M.NAMES["int-mode"] = function() M.INT_MODE = true end
M.NAMES["debug-mode"] = function() M.DEBUG_MODE = true end
M.NAMES["rot"] = function()
    local last = table.remove(M.STACK)
    table.insert(M.STACK, 1, last)
end
M.NAMES["-rot"] = function()
    local first = table.remove(M.STACK,1)
    table.insert(M.STACK, first)
end

local function cons()
    local b = M.pop()
    assert(b.type == "LIST", "CONS: LIST expected, but got "..b.type)
    local a = M.pop()
    table.insert(b.value, 1, a)
    M.push(b)
end

local function uncons()
    local b = M.pop()
    assert(b.type == "LIST", "UNCONS: LIST expected, but got "..b.type)
    local a = table.remove(b.value, 1)
    M.push(a) M.push(b)
end

local function size()
    local a = M.pop()
    assert(a.type == "LIST", "SIZE: LIST expected, but got "..a.type)
    local b = #a.value
    M.push(a) M.push(M.build_number(b))
end

M.NAMES["cons"] = cons
M.NAMES["uncons"] = uncons
M.NAMES["size"] = size

local function split()
    local sep = M.pop()
    local str = M.pop()

    assert(sep.type == "STRING", "SPLIT: STRING expected, but got "..sep.type)
    assert(str.type == "STRING", "SPLIT: STRING expected, but got "..str.type)

    local result = {}

    if sep.value == "" then
        -- Sem separador: divide por caractere
        for i = 1, #str.value do
            table.insert(result, M.build_string(str.value:sub(i, i)))
        end
    else
        -- Com separador: divide por padrão
        for part in string.gmatch(str.value, "([^" .. sep.value .. "]+)") do
            table.insert(result, M.build_string(part))
        end
    end
    M.push(M.build_list(result))
end

local function lines()
    local str = M.pop()

    assert(str.type == "STRING", "LINES: STRING expected, but got "..str.type)

    local result = {}
    for s in string.gmatch(str.value, "[^\r\n]+") do
        table.insert(result, M.build_string(s))
    end
     
    M.push(M.build_list(result))
end

local function words()
    local str = M.pop()

    assert(str.type == "STRING", "WORDS: STRING expected, but got "..str.type)

    local result = {}
    for i = 1, #str do
        table.insert(result, M.build_string(str:sub(i, i)))
    end
    for word in string.gmatch(str.value, "%S+") do
        table.insert(result, M.build_string(word))
    end
    M.push(M.build_list(result))
end

local function char()
    local str = M.pop()

    assert(str.type == "STRING", "CHAR: STRING expected, but got "..str.type)

    local result = {}
    for i = 1, #str.value do
        table.insert(result, M.build_string(str.value:sub(i, i)))
    end
    M.push(M.build_list(result))
end

M.NAMES['lines'] = lines
M.NAMES['words'] = words
M.NAMES['char'] = char
M.NAMES["split"] = split

local function read_file()
    local filepath = M.pop()
    assert(filepath.type == "STRING", "READ-FILE: STRING expected, but got "..filepath.type)

    local file = io.open(filepath.value, "r")  -- abre em modo leitura ("r")
    if not file then
        error("Não foi possível abrir o arquivo: " .. filepath.value)
    end
    local content = file:read("*a")  -- lê todo o conteúdo como string
    file:close()
    M.push(M.build_string(content))
end
M.NAMES["read-file"] = read_file

local function ffi()
    local func_name = M.pop()
    assert(func_name.type == "EXPR", "FFI: EXPR expected, but got " .. func_name.type)
    local lua_func = M.pop()
    assert(lua_func.type == "STRING", "FFI: STRING expected, but got " .. lua_func.type)
    local args_count = M.pop()
    assert(args_count.type == "NUMBER", "FFI: NUMBER expected, but got " .. args_count.type)
    local return_type = M.pop()
    assert(return_type.type == "STRING", "FFI: STRING expected, but got " .. return_type.type)

    -- Resolve a função Lua, incluindo namespaces
    local function resolve_function(path)
        local parts = {}
        for part in string.gmatch(path, "[^%.]+") do
            table.insert(parts, part)
        end

        local func = _G
        for _, part in ipairs(parts) do
            func = func[part]
            if not func then break end
        end
        return func
    end

    local resolved_func = resolve_function(lua_func.value)
    assert(type(resolved_func) == "function", "FFI: " .. lua_func.value .. " is not a valid function")

    -- Registra a função no ambiente da linguagem
    M.NAMES[func_name.value] = function()
        local args = {}
        for i = 1, args_count.value do
            local arg = M.pop()
            local value = {}
            if (arg.type == "LIST") then
                for _, v in ipairs(arg.value) do
                    table.insert(value, v.value)
                end
            else
                value = arg.value
            end
            table.insert(args, value) -- Insere em ordem reversa para corresponder ao comportamento da pilha
        end

        local unpack = table.unpack or unpack
        local result = resolved_func(unpack(args))
        if return_type.value == "STRING" then
            M.push(M.build_string(tostring(result)))
        elseif return_type.value == "NUMBER" then
            M.push(M.build_number(tonumber(result)))
        elseif return_type.value == "LIST" and type(result) == "table" then
            local list = {}
            for _, v in ipairs(result) do
                table.insert(list, M.build_string(tostring(v)))
            end
            M.push(M.build_list(list))
        end
    end
end

M.NAMES["ffi"] = ffi

local function _type()
    local a = M.pop()
    local b = M.build_string(a.type)
    M.push(a) M.push(b)
end
M.NAMES["type?"] = _type

return M