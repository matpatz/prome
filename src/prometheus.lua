-- This Script is Part of the Prometheus Obfuscator by levno-710
--
-- prometheus.lua
--
-- This file is the entrypoint for Prometheus

-- newproxy polyfill
_G.newproxy = _G.newproxy or function(arg)
    if arg then
        return setmetatable({}, {});
    end
    return {};
end

-- Require Prometheus Submodules
local Pipeline = require("./prometheus/pipeline");
local highlight = require("./highlightlua");
local colors = require("./colors");
local Logger = require("./logger");
local Presets = require("./presets");
local Config = require("./config");
local util = require("./prometheus/util");

-- Export
return {
    Pipeline = Pipeline;
    colors = colors;
    Config = util.readonly(Config); -- Readonly
    Logger = Logger;
    highlight = highlight;
    Presets = Presets;
}
