-- Installs a custom `require` searcher that lets plain Lua 5.3 load the
-- game's Luau source files. The only Luau syntax this project's modules
-- use that vanilla Lua lacks is compound assignment (+=, -=, *=, /=) --
-- pure sugar for `x = x <op> y` with no semantic difference in Luau
-- either, so rewriting it before `load()` preserves behavior exactly.
-- This is NOT a full Luau parser/runtime -- it only desugars the one
-- construct this codebase actually uses.

local function desugarCompoundAssignment(source)
	return source
		:gsub("([%w_%.%[%]\"']+)%s*%+=%s*", "%1 = %1 + ")
		:gsub("([%w_%.%[%]\"']+)%s*%-=%s*", "%1 = %1 - ")
		:gsub("([%w_%.%[%]\"']+)%s*%*=%s*", "%1 = %1 * ")
		:gsub("([%w_%.%[%]\"']+)%s*%/=%s*", "%1 = %1 / ")
end

local function luauSearcher(moduleName)
	local relativePath = moduleName:gsub("%.", "/") .. ".lua"

	for template in package.path:gmatch("[^;]+") do
		local candidate = template:gsub("%?", moduleName:gsub("%.", "/"))
		local file = io.open(candidate, "r")
		if file then
			local source = file:read("*a")
			file:close()

			local rewritten = desugarCompoundAssignment(source)
			local chunk, loadErr = load(rewritten, "@" .. candidate)
			if not chunk then
				return "\n\tluau_compat: failed to load " .. candidate .. ": " .. tostring(loadErr)
			end
			return chunk
		end
	end

	return "\n\tluau_compat: no file found for '" .. moduleName .. "' (tried " .. relativePath .. ")"
end

table.insert(package.searchers, 2, luauSearcher)

return { desugarCompoundAssignment = desugarCompoundAssignment }
