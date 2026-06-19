-- This Script is Part of the Prometheus Obfuscator by levno-710
--
-- steps.lua
--
-- This Script provides a collection of obfuscation steps.

return {
	WrapInFunction = require("./steps/WrapInFunction"),
	SplitStrings = require("./steps/SplitStrings"),
	Vmify = require("./steps/Vmify"),
	ConstantArray = require("./steps/ConstantArray"),
	ProxifyLocals = require("./steps/ProxifyLocals"),
	AntiTamper = require("./steps/AntiTamper"),
	EncryptStrings = require("./steps/EncryptStrings"),
	NumbersToExpressions = require("./steps/NumbersToExpressions"),
	AddVararg = require("./steps/AddVararg"),
	WatermarkCheck = require("./steps/WatermarkCheck"),
}