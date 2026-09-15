-- Minimal test assertion helpers shared by every tests/test_*.lua file.

local M = {}

local passed = 0
local failed = 0

function M.suite(name)
	print("=== " .. name .. " ===")
	passed = 0
	failed = 0
end

local function record(ok, message)
	if ok then
		passed = passed + 1
	else
		failed = failed + 1
		print("FAIL: " .. message)
	end
end

function M.assertTrue(condition, message)
	record(condition == true, message or "expected true")
end

function M.assertEqual(actual, expected, message)
	record(actual == expected, string.format("%s (expected %s, got %s)", message or "values differ", tostring(expected), tostring(actual)))
end

function M.assertNear(actual, expected, tolerance, message)
	local ok = type(actual) == "number" and math.abs(actual - expected) <= tolerance
	record(ok, string.format("%s (expected ~%s +/- %s, got %s)", message or "values not near", tostring(expected), tostring(tolerance), tostring(actual)))
end

function M.report()
	print()
	print(passed .. " passed, " .. failed .. " failed")
	if failed > 0 then
		os.exit(1)
	end
end

return M
