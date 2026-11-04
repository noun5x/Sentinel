local declarations = {
	forward = {
		tables = {
			deepClone = nil,
			deepEqual = nil,
			deepFreeze = nil,
			merge = nil,
		},
	},
}

local helpers = {
	tables = {
		deepClone = function(original: any, seen: { [any]: any }?): any
			if type(original) ~= "table" then
				return original
			end

			local visited: { [any]: any } = seen or {}

			if visited[original] then
				return visited[original]
			end

			local clone = {}
			visited[original] = clone

			for key, value in original do
				clone[declarations.forward.tables.deepClone(key, visited)] =
					declarations.forward.tables.deepClone(value, visited)
			end

			local metatable = getmetatable(original)

			if type(metatable) == "table" then
				setmetatable(clone, metatable)
			end

			return clone
		end,

		deepEqual = function(first: any, second: any): boolean
			if first == second then
				return true
			end

			if type(first) ~= "table" or type(second) ~= "table" then
				return false
			end

			for key, value in first do
				if not declarations.forward.tables.deepEqual(value, second[key]) then
					return false
				end
			end

			for key in second do
				if first[key] == nil then
					return false
				end
			end

			return true
		end,

		deepFreeze = function(original: any, seen: { [any]: boolean }?): any
			if type(original) ~= "table" then
				return original
			end

			local visited: { [any]: boolean } = seen or {}

			if visited[original] then
				return original
			end

			visited[original] = true

			for _, value in original do
				if type(value) == "table" then
					declarations.forward.tables.deepFreeze(value, visited)
				end
			end

			if not table.isfrozen(original) then
				table.freeze(original)
			end

			return original
		end,

		merge = function(first: { [any]: any }, second: { [any]: any }): { [any]: any }
			local result = declarations.forward.tables.deepClone(first)

			for key, value in second do
				if type(value) == "table" and type(result[key]) == "table" then
					result[key] = declarations.forward.tables.merge(result[key], value)
				else
					result[key] = value
				end
			end

			return result
		end,

		count = function(original: { [any]: any }): number
			local total = 0

			for _ in original do
				total += 1
			end

			return total
		end,

		isEmpty = function(original: { [any]: any }): boolean
			return next(original) == nil
		end,
	},
}

declarations.forward.tables.deepClone = helpers.tables.deepClone
declarations.forward.tables.deepEqual = helpers.tables.deepEqual
declarations.forward.tables.deepFreeze = helpers.tables.deepFreeze
declarations.forward.tables.merge = helpers.tables.merge

-- sentinel
local Sentinel = {
	Log = {
		report = function(message: string)
			print(message)
		end,

		verbose = function(...)
			print(...)
		end,

		alert = function(...)
			warn(...)
		end,

		alertOnce = (function()
			local warned = {}

			return function(...)
				local arguments = table.pack(...)
				local messageParts = {}

				for index = 1, arguments.n do
					messageParts[index] = tostring(arguments[index])
				end

				local message = table.concat(messageParts, " ")

				if warned[message] then
					return
				end

				warned[message] = true
				warn(...)
			end
		end)(),

		error = function(...)
			error(...)
		end,

		assert = function<T>(value: T, errorMessage: string?): T
			if not value then
				error(errorMessage or "assertion failed", 2)
			end

			return value
		end,
	},

	callbacks = {
		pcall = function<A..., R...>(func: (A...) -> R..., ...: A...): (boolean, R...)
			return pcall(func, ...)
		end,

		xpcall = function<E, A..., R...>(func: (A...) -> R..., err: (E) -> any, ...: A...): (boolean, R...)
			return xpcall(func, err, ...)
		end,

		retry = function(func: () -> ...any, attempts: number): (boolean, ...any)
			local lastError

			for _ = 1, attempts do
				local results = table.pack(pcall(func))

				if results[1] then
					return true, table.unpack(results, 2, results.n)
				end

				lastError = results[2]
			end

			return false, lastError
		end,
	},

	debug = {
		inspect = function(target: number | thread | (() -> ...any), options: string): ...any
			if typeof(target) == "thread" then
				return debug.info(target, 1, options)
			elseif type(target) == "number" then
				return debug.info(target, options)
			else
				return debug.info(target, options)
			end
		end,

		assignMemoryTag = function(tag: string): ()
			debug.setmemorycategory(tag)
		end,

		getMemoryTag = function(): string
			return debug.getmemorycategory()
		end,

		clearMemoryTag = function(): ()
			debug.resetmemorycategory()
		end,

		traceback = function(message: string?, level: number?): string
			return debug.traceback(message, (level or 1) + 1)
		end,

		startProfile = function(label: string): ()
			debug.profilebegin(label)
		end,

		endProfile = function(): ()
			debug.profileend()
		end,

		dumpCodeSize = function(): ()
			(debug :: any).dumpcodesize()
		end,
	},

	tables = {
		deepClone = helpers.tables.deepClone,
		deepEqual = helpers.tables.deepEqual,
		deepFreeze = helpers.tables.deepFreeze,
		merge = helpers.tables.merge,
		count = helpers.tables.count,
		isEmpty = helpers.tables.isEmpty,
	},

	strings = {
		capitalize = function(original: string): string
			return string.upper(string.sub(original, 1, 1)) .. string.sub(original, 2)
		end,

		trim = function(original: string): string
			return original:match("^%s*(.-)%s*$") or ""
		end,

		split = function(original: string, separator: string): { string }
			local result = {}

			if separator == "" then
				for index = 1, #original do
					table.insert(result, string.sub(original, index, index))
				end

				return result
			end

			local start = 1

			while true do
				local first, last = string.find(original, separator, start, true)

				if not first then
					table.insert(result, string.sub(original, start))
					break
				end

				table.insert(result, string.sub(original, start, first - 1))
				start = last + 1
			end

			return result
		end,
	},

	threads = {
		spawn = function(func: (...any) -> (), ...: any): thread
			return task.spawn(func, ...)
		end,

		defer = function(func: (...any) -> (), ...: any): thread
			return task.defer(func, ...)
		end,

		delay = function(seconds: number, func: (...any) -> (), ...: any): thread
			return task.delay(seconds, func, ...)
		end,

		cancel = function(target: thread): ()
			task.cancel(target)
		end,
	},

	math = {
		clamp = function(value: number, minimum: number, maximum: number): number
			return math.max(minimum, math.min(maximum, value))
		end,

		round = function(value: number): number
			return math.round(value)
		end,

		lerp = function(start: number, finish: number, alpha: number): number
			return start + (finish - start) * alpha
		end,

		sign = function(value: number): number
			return math.sign(value)
		end,
	},

	Util = {
		formatNumber = function(number: number): string
			local abbreviations = {
				"K",
				"M",
				"B",
				"T",
				"Qd",
				"Qt",
				"Sx",
				"Sp",
				"Oc",
				"No",
				"De",
			}

			if number == 0 or math.abs(number) < 1e3 then
				return tostring(number)
			end

			local index = math.floor(math.log(math.abs(number), 1e3))
			local value = number / 10 ^ (index * 3)

			if math.round(math.abs(value) * 100) / 100 >= 1000 then
				index += 1
				value = number / 10 ^ (index * 3)
			end

			local abbreviation = abbreviations[index]

			if not abbreviation then
				return tostring(number)
			end

			local formatted = string.format("%.2f", value)
			formatted = formatted:gsub("%.?0+$", "")

			return formatted .. abbreviation
		end,

		formatNumberWithCommas = function(number: number): string
			local formatted = tostring(number)
			local k

			while true do
				formatted, k = string.gsub(formatted, "^(-?%d+)(%d%d%d)", "%1,%2")

				if k == 0 then
					break
				end
			end

			return formatted
		end,

		formatTime = function(seconds: number): string
			local hours = math.floor(seconds / 3600)
			local minutes = math.floor(seconds % 3600 / 60)
			local remainingSeconds = math.floor(seconds % 60)

			if hours > 0 then
				return string.format("%d:%02d:%02d", hours, minutes, remainingSeconds)
			end

			return string.format("%d:%02d", minutes, remainingSeconds)
		end,
	},
}

return Sentinel
