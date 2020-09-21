local r = PcgRandom(minetest.get_mapgen_setting("seed"))

local syscenter = { x = 0, y = 10000, z = 0 }

local max_planets = 3

local sun_min = 50
local sun_max = 500
local planet_min = 50
local planet_max = 500
local gap_min = 100
local min_xz = -25000
local max_xz = 25000
local min_y = 6000
local max_y = 25000

local size_asteroid = 100

local dist_hot = 5000
local dist_warm = 8000
local dist_habitable = 11000
local dist_cold = 15000

local max_ins_failures = 3

local ins_failures = 0

function is_planet_valid(p)
	if (
		p.pos.x - p.radius < min_xz or p.pos.x + p.radius > max_xz or
		p.pos.y - p.radius < min_y or p.pos.y + p.radius > max_y or
		p.pos.z - p.radius < min_xz or p.pos.z + p.radius > max_xz
	) then
		minetest.log("warning", "[planetoid_autogen] Rejecting next planet because it is out of defined limits.")
		return false
	end
	-- do their potentially faster check first?
	if planetoidgen.get_planet_at_pos(p.pos, p.radius + gap_min) then
		--minetest.log("warning", "[planetoid_autogen] Rejecting next planet because it is too close to another planet.")
		return false
	end
	--[[for i=1,#planetoidgen.planets,1 do
		if vector.distance(p.pos, planetoidgen.planets[i].pos) < p.radius + planetoidgen.planets[i].radius + gap_min then
			minetest.log("warning", "[planetoid_autogen] Rejecting next planet because it is too close to another planet called \"" .. planetoidgen.planets[i].name .. "\" r " .. planetoidgen.planets[i].radius .. ".")
			return false
		end
	end]]--
	return true
end

function add_planetoid(t)
	if is_planet_valid(t) then
		--table.insert(planetoidgen.planets, t)
		planetoidgen.register_planet(t)
		return true
	else
		ins_failures = ins_failures + 1
		return false
	end
end

-- sun
add_planetoid({
	pos = syscenter,
	radius = r:next(sun_min, sun_max),
	type = "sun",
	name = "The Sun"
})

function ins_planets()
	local rxzs = max_xz - min_xz
	local rys = max_y - min_y
	local addcount = 0
	while (ins_failures < max_ins_failures and addcount < max_planets) do
		local p = {
			pos = { x = 0, y = 0, z = 0 },
			radius = r:next(planet_min, planet_max),
			type = "",
			name = "",
			airshell = true
		}
		local rxzsmr = rxzs - (p.radius * 2)
		local rysmr = rys - (p.radius * 2)
		p.pos = {
			x = min_xz + p.radius + r:next(0,rxzsmr),
			y = min_y + p.radius + r:next(0,rysmr),
			z = min_xz + p.radius + r:next(0,rxzsmr)
		}
		local d = vector.distance(p.pos, syscenter)
		if d < dist_hot then
			if p.radius < size_asteroid then
				p.type = "class-n"
			else
				p.type = "sun"
			end
		elseif d < dist_warm then
			if p.radius < size_asteroid then
				p.type = "class-n"
			else
				p.type = "class-h"
			end
		elseif d < dist_habitable then
			if p.radius < size_asteroid then
				p.type = "class-p"
			else
				p.type = "class-m"
				p.airshell = true
			end
		else
			p.type = "class-p"
		end
		p.name = tostring(d) .. "-r" .. tostring(p.radius) .. "-" .. p.type .. "-" .. tostring(addcount + 1)
		if add_planetoid(p) then
			minetest.log("action", "[planetoid_autogen] Added planetoid \"" .. p.name .. "\" at (" .. tostring(p.pos.x) .. ", " .. tostring(p.pos.y) .. ", " .. tostring(p.pos.z) .. ").")
			addcount = addcount + 1
		else
			--minetest.log("warning", "[planetoid_autogen] Failed to add planetoid \"" .. p.name .. "\" r " .. tostring(p.radius) ..  " at (" .. tostring(p.pos.x) .. ", " .. tostring(p.pos.y) .. ", " .. tostring(p.pos.z) .. ").")
		end
	end
	minetest.log("action", "[planetoid_autogen] Added " .. tostring(addcount) .. " planets.")
end
ins_planets()

--planetoidgen.generate_index()

-- spaaaace

gravity_manager.register({
	miny = 4000,
	maxy = 31000,
	gravity = 0.32
})

skybox.register({
	name = "spaaaace",
	miny = 4000,
	maxy = 31000,
	always_day = false,
	sky_type = "plain",
	sky_color = { r = 0, g = 0, b = 0 }
})

-- heo

gravity_manager.register({
	miny = 3000,
	maxy = 4000,
	gravity = 0.42
})

skybox.register({
	name = "high earth orbit",
	miny = 3000,
	maxy = 4000,
	always_day = false,
	sky_type = "plain",
	sky_color = { r = 0, g = 0, b = 16 }
})

-- meo

gravity_manager.register({
	miny = 2000,
	maxy = 3000,
	gravity = 0.56
})

skybox.register({
	name = "middle earth orbit",
	miny = 2000,
	maxy = 3000,
	always_day = false,
	sky_type = "plain",
	sky_color = { r = 0, g = 0, b = 32 }
})

-- leo

gravity_manager.register({
	miny = 1000,
	maxy = 2000,
	gravity = 0.75
})

skybox.register({
	name = "low earth orbit",
	miny = 1000,
	maxy = 2000,
	always_day = false,
	sky_type = "plain",
	sky_color = { r = 0, g = 0, b = 64 }
})

-- is fly = true a real thing here?
-- gravity_manager needs dealt with and more layers from low/mid/high orbit to space

minetest.log("action", "[planetoid_autogen] Finished.")
--[[for i=1,#planetoidgen.planets,1 do
	minetest.log("action", "[planetoid_autogen] Planet " .. planetoidgen.planets[i].name .. "\" r " .. planetoidgen.planets[i].radius .. " at (" .. tostring(planetoidgen.planets[i].pos.x) .. ", " .. tostring(planetoidgen.planets[i].pos.x) .. ", " .. tostring(planetoidgen.planets[i].pos.z) .. ").")
end]]--
