local min_y = minetest.settings:get("planetoids_autogen.min_y") or 6000
local max_y = minetest.settings:get("planetoids_autogen.max_y") or 25000

gravity_manager.register({
	miny = min_y,
	maxy = max_y,
	gravity = 0.32
})

skybox.register({
	name = "spaaaace",
	miny = min_y,
	maxy = max_y,
	always_day = true,
	sky_type = "plain",
	sky_color = { r = 0, g = 0, b = 0 }
})

local always_regenerate = minetest.settings:get_bool("planetoids_autogen.always_regenerate") or false -- this prevents storage functioning
local storage_format = minetest.settings:get("planetoids_autogen.storage_format") or "mod_storage"

local storageref
if storage_format == "mod_storage" then storageref = minetest.get_mod_storage()
elseif storage_format == "json" then
end
local storage = storageref:to_table()

if not storage.planets then storage.planets = {} end -- store planets
if not storage.systems then storage.systems = {} end -- store systems, their boundaries and star positions

local add_from_storage_planetoids = function()
	if not storage.last_write_check or always_regenerate then return false end
	for i=1,#storage.planets,1 do table.insert(planetoidgen.planets,storage.planets[i]) end
	planetoidgen.regenerate_index()
	minetest.log("action", "[planetoids_autogen] Added " .. tostring(#planetoidgen.planets) .. " planets from storage.")
	-- storage = nil -- don't need it anymore
	return true
end

-- could end here if other mods don't add anything to the lists

local max_planets = minetest.settings:get("planetoids_autogen.max_planets") or 256 -- random scatter stage
local max_system_planets = minetest.settings:get("planetoids_autogen.max_system_planets") or 64
local max_systems = minetest.settings:get("planetoids_autogen.max_systems") or 16

local sun_min = minetest.settings:get("planetoids_autogen.sun_min_radius") or 1024
local sun_max = minetest.settings:get("planetoids_autogen.sun_max_radius") or 2048
local planet_min = minetest.settings:get("planetoids_autogen.planet_min_radius") or 32
local planet_max = minetest.settings:get("planetoids_autogen.planet_max_radius") or 1024
local gap_min = minetest.settings:get("planetoids_autogen.gap_min") or 64
local min_xz = minetest.settings:get("planetoids_autogen.min_xz") or -25000
local max_xz = minetest.settings:get("planetoids_autogen.max_xz") or 25000

local size_asteroid = minetest.settings:get("planetoids_autogen.size_asteroid") or 128
local size_debris = size_asteroid

local dist_hot = minetest.settings:get("planetoids_autogen.dist_hot") or 5000
local dist_warm = minetest.settings:get("planetoids_autogen.dist_warm") or 8000
local dist_habitable = minetest.settings:get("planetoids_autogen.dist_habitable") or 11000
local dist_cold = minetest.settings:get("planetoids_autogen.dist_cold") or 15000

local min_system_gap = minetest.settings:get("planetoids_autogen.min_system_gap") or 4096

local max_ins_failures = minetest.settings:get("planetoids_autogen.max_ins_failures") or 2048 -- for random scatter stage
local max_ins_failures_system_objects = minetest.settings:get("planetoids_autogen.max_ins_failures_system_objects") or 256
local max_ins_failures_satellite = minetest.settings:get("planetoids_autigen.max_ins_failures_satellite") or 64
local max_ins_failures_system = minetest.settings:get("planetoids_autogen.max_ins_failures_system") or 1024

local defer_generate_time_seconds = minetest.settings:get("planetoids_autogen.defer_generate_time_seconds") or 20 -- defer generation so other mods have a chance to insert their own planetoids

local binary_star_chance = minetest.settings:get("planetoids_autogen.binary_star_chance") or 50

--- ex: planetoid_autogen.habitable.register({chance = 0.4, name = "wooly_world"})

planetoid_autogen = {
	hot = {
		-- close to sun, mercury-like, venus-like, stone
		list = {
			{chance = 0.9, name = "sun", min_radius = planet_min},
			{chance = 0.1, name = "class-n", min_radius = planet_min},
		},
		satellite_chance = minetest.settings:get("planetoids_autogen.hot.satellite_chance") or 0.01
	},
	warm = {
		-- warm, but too hot for vegetation. rocky and sandy
		list = {
			{chance = 0.5, name = "class-n", min_radius = planet_min},
			{chance = 0.5, name = "class-h", min_radius = planet_min},
		},
		satellite_chance = minetest.settings:get("planetoids_autogen.hot.satellite_chance") or 0.07
	},
	habitable = {
		-- habitable distance, vegetation, grass
		list = {
			{chance = 0.7, name = "class-m", min_radius = planet_min},
			{chance = 0.2, name = "class-h", min_radius = planet_min},
			{chance = 0.1, name = "class-p", min_radius = planet_min},
		},
		satellite_chance = minetest.settings:get("planetoids_autogen.habitable.satellite_chance") or 0.1
	},
	cold = {
		-- too cold for vegetation, ice, snow
		list = {
			{chance = 0.98, name = "class-p", min_radius = planet_min},
			{chance = 0.02, name = "dyson-sphere", min_radius = 100},
		},
		satellite_chance = minetest.settings:get("planetoids_autogen.hot.satellite_chance") or 0.07
	},
	satellite = {
		-- moons, rocky
		list = {
			{chance = 1.0, name = "class-n", min_radius = planet_min},
		},
		satellite_chance = minetest.settings:get("planetoids_autogen.satellite.satellite_chance") or 0.01
	},
	debris = {
		-- random small rocks
		list = {
			{chance = 1.0, name = "class-n", min_radius = planet_min},
		}
	}
}
planetoid_autogen.hot.register = function(in_table)
	if not in_table.chance then in_table.chance = 1.0 end
	if not in_table.name then return false end
	if not in_table.min_radius then in_table.min_radius = planet_min end
	table.insert(planetoid_autogen.hot.list, in_table)
	return true
end
planetoid_autogen.warm.register = function(in_table)
	if not in_table.chance then in_table.chance = 1.0 end
	if not in_table.name then return false end
	if not in_table.min_radius then in_table.min_radius = planet_min end
	table.insert(planetoid_autogen.warm.list, in_table)
	return true
end
planetoid_autogen.habitable.register = function(in_table)
	if not in_table.chance then in_table.chance = 1.0 end
	if not in_table.name then return false end
	if not in_table.min_radius then in_table.min_radius = planet_min end
	table.insert(planetoid_autogen.habitable.list, in_table)
	return true
end
planetoid_autogen.cold.register = function(in_table)
	if not in_table.chance then in_table.chance = 1.0 end
	if not in_table.name then return false end
	if not in_table.min_radius then in_table.min_radius = planet_min end
	table.insert(planetoid_autogen.cold.list, in_table)
	return true
end
planetoid_autogen.satellite.register = function(in_table)
	if not in_table.chance then in_table.chance = 1.0 end
	if not in_table.name then return false end
	if not in_table.min_radius then in_table.min_radius = planet_min end
	table.insert(planetoid_autogen.cold.satellite, in_table)
	return true
end
planetoid_autogen.debris.register = function(in_table)
	if not in_table.chance then in_table.chance = 1.0 end
	if not in_table.name then return false end
	if not in_table.min_radius then in_table.min_radius = planet_min end
	table.insert(planetoid_autogen.debris.list, in_table)
	return true
end

if add_from_storage_planetoids() then return end -- if have storage can skip everything else, just add the planets and be done with it

-- generation

local r = PcgRandom(
		minetest.settings:get("planetoids_autogen.seed")
	or
		minetest.get_mapgen_setting("seed")
)

local random_name_from_weighted_list_with_r = function(t,pr)
	local sum = 0
	for i=1,#t,1 do
		if t[i].min_radius <= pr then sum = sum + t[i].chance end
	end
	local n = 1
	local roll = r:next(0,sum)
	local acc = t[1].chance
	while (acc < roll and n < #t) do
		n = n + 1
		while (t[n].min_radius > pr) do n = n + 1 end
		acc = t[n].chance
	end
	return t[n].name
end

local is_planet_valid = function(p)
	if (
		p.pos.x - p.radius < min_xz or p.pos.x + p.radius > max_xz or
		p.pos.y - p.radius < min_y or p.pos.y + p.radius > max_y or
		p.pos.z - p.radius < min_xz or p.pos.z + p.radius > max_xz
	) then
		minetest.log("warning", "[planetoid_autogen] Rejecting next planet because it is out of defined limits. This shouldn't happen.")
		return false
	end
	-- do their potentially faster check first?
	if planetoidgen.get_planet_at_pos(p.pos, p.radius + gap_min) then
		minetest.log("verbose", "[planetoid_autogen] Rejecting next planet because it is too close to another planet. This is normal.")
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

local have_storage = false

local stars = { }
local system_stars = { }

local add_planetoid = function(t)
	if is_planet_valid(t) then
		--table.insert(planetoidgen.planets, t)
		planetoidgen.register_planet(t)
		if not have_storage and not always_regenerate then
			table.insert(storage.planets,t)
		end
		minetest.log("action", "[planetoid_autogen] Added planetoid \"" .. t.name .. "\" at (" .. tostring(t.pos.x) .. ", " .. tostring(t.pos.y) .. ", " .. tostring(t.pos.z) .. ").")
		return true
	else
		--ins_failures = ins_failures + 1
		return false
	end
end

local add_system_star = function(t)
	if add_planetoid(t) then
		table.insert(system_stars, t)
		table.insert(stars, t)
		return true
	else
		return false
	end
end

local add_star = function(t)
	if add_planetoid(t) then
		table.insert(stars, t)
		return true
	else
		return false
	end
end

local find_closest_star = function(p)
	local n = nil
	local ndist = 99999
	for i=1,#stars,1 do
		local d = vector.distance(p, stars[i].pos)
		if d < ndist then
			n = i
			ndist = d
		end
	end
	if n == nil then return nil, nil end
	return stars[n], ndist
end

local ins_planets = function()
	local rxzs = max_xz - min_xz
	local rys = max_y - min_y
	local addcount = 0
	local ins_failures = 0
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
		local closest_star, d = find_closest_star(p.pos)
		--local d = vector.distance(p.pos, syscenter)
		if d < dist_hot then
			p.type = random_name_from_weighted_list_with_r(planetoid_autogen.hot.list, p.radius)
		elseif d < dist_warm then
			p.type = random_name_from_weighted_list_with_r(planetoid_autogen.warm.list, p.radius)
		elseif d < dist_habitable then
			p.type = random_name_from_weighted_list_with_r(planetoid_autogen.habitable.list, p.radius)
		else
			p.type = random_name_from_weighted_list_with_r(planetoid_autogen.cold.list, p.radius)
		end
		p.name = closest_star.name .. "-" .. tostring(d) .. "-r" .. tostring(p.radius) .. "-" .. p.type .. "-x" .. tostring(addcount + 1)
		if add_planetoid(p) then
			--minetest.log("info", "[planetoid_autogen] Added planetoid \"" .. p.name .. "\" at (" .. tostring(p.pos.x) .. ", " .. tostring(p.pos.y) .. ", " .. tostring(p.pos.z) .. ").")
			addcount = addcount + 1
		else
			--minetest.log("warning", "[planetoid_autogen] Failed to add planetoid \"" .. p.name .. "\" r " .. tostring(p.radius) ..  " at (" .. tostring(p.pos.x) .. ", " .. tostring(p.pos.y) .. ", " .. tostring(p.pos.z) .. ").")
			ins_failures = ins_failures + 1
		end
	end
	minetest.log("action", "[planetoid_autogen] Added " .. tostring(addcount) .. " planets.")
end
--ins_planets()

--planetoidgen.generate_index()

-- this here is the new code to replace above generation

local ins_system_star = function(n)
	-- pick a location for the star
	local rxzs = max_xz - min_xz
	local rys = max_y - min_y
	local star_first_gap = 0;
	local ins_failures = 0;
	while (ins_failures < max_ins_failures_system) do
		local p = { pos = { x = 0, y = 0, z = 0 }, radius = r:next(sun_min, sun_max), name = "star" .. tostring(n), type = "" }
		star_first_gap = p.radius + gap_min
		local rxzsmr = rxzs - (p.radius * 2)
		local rysmr = rys - (p.radius * 2)
		p.pos = {
			x = min_xz + p.radius + r:next(0,rxzsmr),
			y = min_y + p.radius + r:next(0,rysmr),
			z = min_xz + p.radius + r:next(0,rxzsmr)
		}
		-- too close to another star?
		local valid = true;
		for i=1,#stars,1 do
			if vector.distance(p.pos,stars[i].pos) <= min_system_gap then
				valid = false
				break
			end
		end
		if valid then
			valid = is_planet_valid(p)
			if valid then
				-- should it be binary?
				if r:next(0,1000) * 0.1 > binary_star_chance then
					-- yes, insert another sun next to it and increase star_first_gap
					local b_ins_failures = 0
					while b_ins_failures < max_ins_failures_satellite do
						local a = r:next(0,6283) * 0.001
						local br = r:next(sun_min, p.radius)
						local m = gap_min + p.radius + br
						local wobblewobble = r:next(0, p.radius * 2) - p.radius
						local bp = {
							pos = {
								x = p.pos.x + (m * math.cos(a)),
								y = p.pos.y + wobblewobble,
								z = p.pos.z + (m * math.sin(a))
							},
							radius = br, type = "sun", name = "star" .. tostring(n) .. "-b"
						}
						--[[minetest.log("action", "m = " .. tostring(m))
						minetest.log("action", "a = " .. tostring(a))
						minetest.log("action", "br = " .. tostring(br))
						minetest.log("action", "p.pos.x = " .. tostring(p.pos.x))
						minetest.log("action", "bp.pos.x = " .. tostring(bp.pos.x))
						minetest.log("action", "(m * math.cos(a)) = " .. tostring(m * math.cos(a)))]]--
						if add_star(bp) then
							star_first_gap = m + gap_min
							break
						end
						b_ins_failures = b_ins_failures + 1
					end
				end
				if add_system_star(p) then
					return p, star_first_gap
				end
			end
		end
		ins_failures = ins_failures + 1
	end
	return nil, nil -- failed to insert
end

local ins_star_planet = function(s, from_dist, n)
	local a = r:next(0,6283) * 0.001
	local rr = r:next(planet_min, planet_max)
	local m = from_dist + rr + gap_min
	local p = {
		pos = {
			x = s.pos.x + (m * math.sin(a)),
			y = s.pos.y,
			z = s.pos.z + (m * math.cos(a))
		},
		radius = rr,
		name = "",
		type = ""
	}
	local closest_sun, d = find_closest_star(p.pos)
	if d < dist_hot then
		p.type = random_name_from_weighted_list_with_r(planetoid_autogen.hot.list, p.radius)
	elseif d < dist_warm then
		p.type = random_name_from_weighted_list_with_r(planetoid_autogen.warm.list, p.radius)
	elseif d < dist_habitable then
		p.type = random_name_from_weighted_list_with_r(planetoid_autogen.habitable.list, p.radius)
	else
		p.type = random_name_from_weighted_list_with_r(planetoid_autogen.cold.list, p.radius)
	end
	p.name = closest_sun.name .. "-" .. tostring(d) .. "-r" .. tostring(p.radius) .. "-" .. p.type .. "-" .. tostring(n)
	if add_planetoid(p) then return true end
	return false
end

local ins_system_planets = function(s, from_dist)
	local c = 0
	local f = 0
	local d = from_dist
	while c < max_system_planets and f < max_ins_failures_system_objects do
		local success, new_min_dist = ins_star_planet(s, d, c + 1)
		if success then
			c = c + 1
			d = new_min_dist
		else
			d = d + gap_min
			f = f + 1
		end
	end
	return c
end

local do_generate = function()
	-- stars first
	local f = 0
	local c = 0
	local gaps = { }
	while (f < max_ins_failures_system and c < max_systems) do
		local success, g = ins_system_star()
		if success then
			table.insert(gaps, g)
			c = c + 1
		else
			f = f + 1
		end
	end
	minetest.log("action","done with system stars")
	-- planets around stars
	if c > 0 then
		for i=1,#system_stars,1 do ins_system_planets(stars[i], gaps[i]) end
	end
	minetest.log("action","done with system planets")
	-- random scatter planets
	ins_planets()
	minetest.log("action","done with randomly scattered planets")
	if not always_regenerate then
		storage.planets = planetoidgen.planets
		storage.stars = stars
		storage.system_stars = system_stars
		if storage_format == "mod_storage" then
			storage_ref:from_table(storage)
		elseif storage_format == "json" then
		end
	end
end

-- save storage as the last thing
--storage.last_write_check = true
--storage_ref:from_table(storage)

--minetest.log("action", "[planetoid_autogen] Finished.")
--[[for i=1,#planetoidgen.planets,1 do
	minetest.log("action", "[planetoid_autogen] Planet " .. planetoidgen.planets[i].name .. "\" r " .. planetoidgen.planets[i].radius .. " at (" .. tostring(planetoidgen.planets[i].pos.x) .. ", " .. tostring(planetoidgen.planets[i].pos.x) .. ", " .. tostring(planetoidgen.planets[i].pos.z) .. ").")
end]]--

minetest.after(defer_generate_time_seconds, do_generate)
