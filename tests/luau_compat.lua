-- Luau supports compound assignment operators (+=, -=, *=, /=) that vanilla
-- Lua 5.3 (used to run these tests outside Roblox) doesn't parse. This
-- rewrites `x += y` into `x = x + y` (etc.) line-by-line before handing
-- source to load(), so the real game files can be loaded and executed
-- as-is for testing without modifying them.

local M = {}

local RULES = {
	{ pattern = "^(%s*)([%w_%.%[%]\"']+)%s*%+=%s*(.-)$", op = "+" },
	{ pattern = "^(%s*)([%w_%.%[%]\"']+)%s*%-=%s*(.-)$", op = "-" },
	{ pattern = "^(%s*)([%w_%.%[%]\"']+)%s*%*=%s*(.-)$", op = "*" },
	{ pattern = "^(%s*)([%w_%.%[%]\"']+)%s*/=%s*(.-)$", op = "/" },
}

function M.desugarCompoundAssignment(source)
	local lines = {}
	for line in (source .. "\n"):gmatch("(.-)\n") do
		table.insert(lines, line)
	end

	for i, line in ipairs(lines) do
		for _, rule in ipairs(RULES) do
			local indent, lhs, rhs = line:match(rule.pattern)
			if lhs and lhs ~= "" then
				lines[i] = string.format("%s%s = %s %s (%s)", indent, lhs, lhs, rule.op, rhs)
				break
			end
		end
	end

	return table.concat(lines, "\n")
end

return M
