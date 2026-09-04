-- Tiny assertion helpers shared by every test file. No Roblox dependency.

local M = {}

M.passCount = 0
M.failCount = 0
M.currentSuite = "?"

function M.suite(name)
	M.currentSuite = name
end

local function record(ok, message)
	if ok then
		M.passCount = M.passCount + 1
	else
		M.failCount = M.failCount + 1
		print(string.format("FAIL [%s] %s", M.currentSuite, message))
	end
end

function M.assertEqual(actual, expected, label)
	local ok = actual == expected
	record(ok, string.format("%s: expected %s, got %s", label or "assertEqual", tostring(expected), tostring(actual)))
end

function M.assertTrue(value, label)
	record(value == true, (label or "assertTrue") .. ": expected true, got " .. tostring(value))
end

function M.assertNil(value, label)
	record(value == nil, (label or "assertNil") .. ": expected nil, got " .. tostring(value))
end

function M.assertNear(actual, expected, tolerance, label)
	local ok = math.abs(actual - expected) <= tolerance
	record(
		ok,
		string.format(
			"%s: expected ~%s (+/- %s), got %s",
			label or "assertNear",
			tostring(expected),
			tostring(tolerance),
			tostring(actual)
		)
	)
end

function M.report()
	print(string.format("\n%d passed, %d failed", M.passCount, M.failCount))
	if M.failCount > 0 then
		os.exit(1)
	end
end

return M
