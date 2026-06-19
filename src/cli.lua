-- This Script is Part of the Prometheus Obfuscator by levno-710
--
-- cli.lua (Lune build)
--
-- This Script contains the Code for the Prometheus CLI, targeting the Lune Luau runtime.

local process = require("@lune/process")
local fs = require("@lune/fs")
local stdio = require("@lune/stdio")
local luau = require("@lune/luau")

local INSTALL_SCRIPT_URL = "https://raw.githubusercontent.com/prometheus-lua/Prometheus/master/install.sh"

local function run_shell(command)
	local result = process.exec(command, {}, {
		shell = true,
		stdio = { stdout = "inherit", stderr = "inherit" },
	})
	return result.ok
end

local function get_version()
	local version = process.env.PROMETHEUS_LUA_VERSION
	if version and version ~= "" then
		return version
	end
	return "dev"
end

local function print_help()
	print("Prometheus Lua CLI")
	print("Usage: prometheus-lua [command] [options] <input.lua>")
	print("")
	print("Commands:")
	print("  update                 Install latest release via installer script")
	print("  --version, -v          Print CLI version")
	print("")
	print("Obfuscation options:")
	print("  --preset, --p <name>   Use preset (e.g. Minify, Medium, High)")
	print("  --config, --c <file>   Use custom config Lua file")
	print("  --out, --o <file>      Set output path")
	print("  --Lua51                Force Lua 5.1 target")
	print("  --LuaU                 Force LuaU target")
	print("  --pretty               Pretty print output")
	print("  --nocolors             Disable colored logs")
	print("  --saveerrors           Persist parser errors to file")
end

local function run_update()
	local command
	if run_shell("command -v curl >/dev/null 2>&1") then
		command = string.format("curl -fsSL '%s' | sh", INSTALL_SCRIPT_URL)
	elseif run_shell("command -v wget >/dev/null 2>&1") then
		command = string.format("wget -qO- '%s' | sh", INSTALL_SCRIPT_URL)
	else
		stdio.ewrite("Neither curl nor wget was found. Please install one of them and retry.\n")
		process.exit(1)
	end

	print("Updating prometheus-lua using official installer")
	if not run_shell(command) then
		stdio.ewrite("Update failed\n")
		process.exit(1)
	end

	print("Update completed")
end

if process.args[1] == "update" then
	run_update()
	process.exit(0)
end

if process.args[1] == "--version" or process.args[1] == "-v" then
	print(get_version())
	process.exit(0)
end

if process.args[1] == "--help" or process.args[1] == "-h" or process.args[1] == "help" then
	print_help()
	process.exit(0)
end

---@diagnostic disable-next-line: different-requires
local Prometheus = require("./prometheus")

-- make writable copies
Prometheus = table.clone(Prometheus)
Prometheus.Logger = table.clone(Prometheus.Logger)

Prometheus.Logger.logLevel = Prometheus.Logger.LogLevel.Info

Prometheus.Logger.errorCallback = function(...)
    local args = {...}
    local message = table.concat(args, " ")

    stdio.ewrite(
        Prometheus.colors(
            Prometheus.Config.NameUpper .. ": " .. message,
            "red"
        ) .. "\n"
    )

    process.exit(1)
end

-- Check if the file exists
local function file_exists(file)
	return fs.isFile(file)
end

-- Replacement for loadstring/load: compiles + loads a Luau chunk via @lune/luau
local function load_chunk(content, chunkName, environment)
	local ok, fnOrErr = pcall(luau.load, content, {
		debugName = chunkName,
		environment = environment, -- nil keeps the default global env
	})
	if not ok then
		return nil, fnOrErr
	end
	return fnOrErr
end

local function run_cli()
	-- CLI
	local config, sourceFile, outFile, luaVersion, prettyPrint

	Prometheus.colors.enabled = true

	-- Parse Arguments
	local args = process.args
	local i = 1
	while i <= #args do
		local curr = args[i]
		if curr:sub(1, 2) == "--" then
			if curr == "--preset" or curr == "--p" then
				if config then
					Prometheus.Logger:warn("The config was set multiple times")
				end

				i = i + 1
				local preset = Prometheus.Presets[args[i]]
				if not preset then
					Prometheus.Logger:error(string.format('A Preset with the name "%s" was not found!', tostring(args[i])))
				end

				config = preset
			elseif curr == "--config" or curr == "--c" then
				i = i + 1
				local filename = tostring(args[i])
				if not file_exists(filename) then
					Prometheus.Logger:error(string.format('The config file "%s" was not found!', filename))
				end

				local content = fs.readFile(filename)
				-- Load Config from File
				local func, err = load_chunk(content, "@" .. filename, {})
				if not func then
					Prometheus.Logger:error(string.format('Failed to parse config file "%s": %s', filename, tostring(err)))
				end
				config = func()
			elseif curr == "--out" or curr == "--o" then
				i = i + 1
				if outFile then
					Prometheus.Logger:warn("The output file was specified multiple times!")
				end
				outFile = args[i]
			elseif curr == "--nocolors" then
				Prometheus.colors.enabled = false
			elseif curr == "--Lua51" then
				luaVersion = "Lua51"
			elseif curr == "--LuaU" then
				luaVersion = "LuaU"
			elseif curr == "--pretty" then
				prettyPrint = true
			elseif curr == "--saveerrors" then
				-- Override error callback
				Prometheus.Logger.errorCallback = function(...)
					local cbArgs = { ... }
					local message = table.concat(cbArgs, " ")
					stdio.ewrite(Prometheus.colors(Prometheus.Config.NameUpper .. ": " .. message, "red") .. "\n")

					local fileName = sourceFile:sub(-4) == ".lua" and sourceFile:sub(0, -5) .. ".error.txt"
						or sourceFile .. ".error.txt"
					fs.writeFile(fileName, message)

					process.exit(1)
				end
			else
				Prometheus.Logger:warn(string.format('The option "%s" is not valid and therefore ignored', curr))
			end
		else
			if sourceFile then
				Prometheus.Logger:error(string.format('Unexpected argument "%s"', args[i]))
			end
			sourceFile = tostring(args[i])
		end
		i = i + 1
	end

	if not sourceFile then
		Prometheus.Logger:error("No input file was specified!")
	end

	if not config then
		Prometheus.Logger:warn("No config was specified, falling back to Minify preset")
		config = Prometheus.Presets.Minify
	end

	-- Add Option to override Lua Version
	config.LuaVersion = luaVersion or config.LuaVersion
	config.PrettyPrint = prettyPrint ~= nil and prettyPrint or config.PrettyPrint

	if not file_exists(sourceFile) then
		Prometheus.Logger:error(string.format('The File "%s" was not found!', sourceFile))
	end

	if not outFile then
		if sourceFile:sub(-4) == ".lua" then
			outFile = sourceFile:sub(0, -5) .. ".obfuscated.lua"
		else
			outFile = sourceFile .. ".obfuscated.lua"
		end
	end

	local source = fs.readFile(sourceFile)
	local pipeline = Prometheus.Pipeline:fromConfig(config)
	local out = pipeline:apply(source, sourceFile)
	Prometheus.Logger:info(string.format('Writing output to "%s"', outFile))

	-- Write Output
	fs.writeFile(outFile, out)
end

local ok, err = xpcall(run_cli, function(e)
	return tostring(e)
end)
if not ok then
	local message = tostring(err):gsub("^.-:%d+:%s*", "")
	stdio.ewrite(Prometheus.colors(Prometheus.Config.NameUpper .. ": " .. message, "red") .. "\n")
	process.exit(1)
end