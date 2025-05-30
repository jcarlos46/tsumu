#!/usr/bin/env lua
-- tsumu.lua
local lexer = require("lexer")
local vm = require("vm")

-- Máquina Virtual
local process
local run
local import

local function eval(token)
    if token.value == "--" then return end
    if token.type == "NAME" then
        if vm.NAMES[token.value] ~= nil then
            if vm.DEBUG_MODE then print("DEFINING: " .. token.value) end
            vm.NAMES[token.value]()
        else
            vm.error_msg("NAME not found: " .. token.value)
        end
    else
        vm.push(token)
    end
end

function process(tokens)
    for _, token in ipairs(tokens) do
	if vm.EXIT then return end
        eval(token)
    end
end

function run(code)
    local tokens = lexer.tokenize(code)
    process(tokens)
end

local function _import()
    local a = vm.pop()
    if not vm.string_check(a.type, "IMPORT") then return end
    if a then
        import(a.value)
    end
end

local function def()
    local body = vm.pop()
    local name = vm.pop()
    if not vm.expr_check(name.type, "DEF") then return end
    vm.NAMES[name.value] = function() run(body.value) end
    if vm.INT_MODE then
        print("Tsumu: name "..name.value.." defined.")
    end
end

local function _while()
    local body = vm.pop()
    if not vm.expr_check(body.type, "WHILE") then return end

    local cond = vm.pop()
    if not vm.expr_check(body.type, "WHILE") then return end

    while true do
        vm.TOTAL_LOOP = vm.TOTAL_LOOP + 1
        if vm.TOTAL_LOOP >= vm.MAX_LOOP then 
            vm.error_msg("You reached the maximum loop quantity allowed")
            break
        end
        run(cond.value)
        if vm.pop().value ~= 1 then break end
        run(body.value)
    end
    vm.TOTAL_LOOP = 0
end

local function _eval()
    local expr = vm.pop()
    run(expr.value)
end

local function dip()
    local a = vm.pop()
    assert(a.type == "EXPR", "DIP: LIST expected, but got "..a.type)
    local b = vm.pop()

    run(a.value)
    vm.push(b)
end

vm.NAMES["def"] = def
vm.NAMES["while"] = _while
vm.NAMES["eval"] = _eval
vm.NAMES["import"] = _import
vm.NAMES["dip"] = dip

---@param filename string
function import(filename)
    -- Normaliza nodo do arquivo
    if string.sub(filename, -4) ~= ".tsu" then
        filename = filename .. ".tsu"
    end
    -- Abre o arquivo para leitura
    local file = io.open(filename, "r")
    if not file then
        vm.error_msg("Não foi possível abrir o arquivo de entrada: " .. filename)
        return
    end
    local code = file:read("*a")

    file:close()

    if vm.INT_MODE then
        print("Tsumu: "..filename.." imported.")
    end

    run(code)
end

if (arg[1] ~= nil) then
    import(arg[1])
else
    import("cli.tsu")
end
