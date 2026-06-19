-- This Script is Part of the Prometheus Obfuscator by levno-710
--
-- namegenerators.lua
--
-- This Script provides a collection of name generators for Prometheus.

return {
	Mangled = require("./namegenerators/mangled");
	MangledShuffled = require("./namegenerators/mangled_shuffled");
	Il = require("./namegenerators/Il");
	Number = require("./namegenerators/number");
	Confuse = require("./namegenerators/confuse");
}