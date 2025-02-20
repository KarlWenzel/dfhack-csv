local save_path = "C:\\DF\\Notes\\_KHack\\output\\"	

local itemtools = reqscript("item")

function write_to_file(fname, line_items)
	
	
	local file = io.open(save_path .. fname, 'w')
	
	if file then
		for _,line_item in pairs(line_items) do
			file:write(line_item, "\n")
		end
		file:close()
	else
		print("Failed to open file.")
	end
end

function create_line_items()
	-- line_items is a table of strings for csv output. the first line is csv header values below
	return { "item_type,short_desc,material,contains_items,count,long_desc,quality,value,pos_x,pos_y,pos_z,wear" }
end

function add_line_items(item_type, line_items)	
	
	local cond = {}
	itemtools.condition_type(cond, item_type)	
	local _, items, _ = itemtools.execute("count", cond, {verbose = true}, true)
	
	line_items = line_items or {}
	prior_count = 0	
	for _,v in ipairs(line_items) do
		prior_count = prior_count + 1
	end
	
	for index,item in pairs(items) do
		
		local long_desc = ""
		local short_desc = ""
		local mat = ""
		local count = 1
		local contains_items = false
		long_desc, short_desc, mat, count, contains_items = parseDescription(item_type, item)
		
		local pos = ("%d,%d,%d"):format(dfhack.items.getPosition(item))		
		
		local quality = 1
		
		-- not all items have a quality. if it does, then assign it
		for k,v in pairs(item) do
			if (k == "quality") then
				quality = v
				break
			end
		end
				
		local line_item = ("%s,%s,%s,%s,%d,%s,%d,%d,%s,%d"):format(
			item_type,
			short_desc,
			mat,
			contains_items,
			count,
			long_desc,
			quality,
			dfhack.items.getValue(item),
			pos, --already a formatted string with 3 integer values
			item["wear"]
		)
		
		line_items[prior_count + index] = line_item
	end
	
	return line_items
end

function write_inventory_csv(file_name, item_types)

	local line_items = create_line_items()
	
	for _,item_type in ipairs(item_types) do
		line_items = add_line_items(item_type, line_items)
	end		
	
	write_to_file(file_name, line_items)	
end

function split_last_word(x)

	print("split", x)
	
	local rev = string.reverse(x)
	local i = string.find(rev, " ")
	if (i == nil) then
		return "", x
	end
	
	local n = string.len(rev)
	if (i+1 > n) then
		return "", x
	end
	
	-- the string is in reverse order, so the front is the back
	local back = string.reverse(string.sub(rev, 1, i-1))
	local front = string.reverse(string.sub(rev, i+1, n))
	print("split result = ", front, back)
	return front, back
end

function coalesce_mat_types(mat)

	-- rather than have e.g., "dog bone", "pig bone", "wolverine bone", etc.. just report it as "bone"

	local last_word = ""
	_, last_word = split_last_word(mat)
	
	if (last_word == "bone") then
		return "bone"
	elseif (last_word == "leather") then
		return "leather"
	elseif (last_word == "wood") then
		return "wood"
	else
		return mat
	end
end

function parseDescription(item_type, item)

	local long_desc = dfhack.items.getDescription(item, 0, false)
	long_desc = string.gsub(long_desc, "(%s<#%d+>)", "") -- get rid of the possible whatever this <#xx> designator is
			
	local short_desc = ""
	local mat = "<unk>"
	local count = 1
	local contains_items = false
	-- dfhack.items.getContainedItems(item)
	-- dfhack.items.getContainer(v)	
	
	if (item_type == "AMMO") then
		for k,v in string.gmatch(long_desc, "([%a%s]+)%[(%d+)%]") do
			count = v			
		end
		mat, short_desc = split_last_word(dfhack.items.getDescription(item, 2, false))
	
	elseif (item_type == "BARREL") then
		short_desc = "barrel"
		for k,v in string.gmatch(long_desc, "([%a%s%-]+)%(([%a%s%-]+)%)") do
			mat = v
			contains_items = true
		end
		if (not contains_items) then
			mat,_ = split_last_word(long_desc) --remove trailing " barrel"
		end
		
	end	
	
	mat = coalesce_mat_types(mat)
	return long_desc, short_desc, mat, count, contains_items
end

local reports = {
	 ["kit.csv"] = { 'AMMO','ARMOR','BACKPACK','FLASK','GLOVES','HELM','PANTS','QUIVER','SHIELD','SHOES','WEAPON' }
	,["mining.csv"] = { 'BAR','BLOCKS','BOULDER','ROCK','ROUGH','WOOD' }
	,["treasure.csv"] = { 'AMULET','BRACELET','COIN','CROWN','EARRING','FIGURINE','GEM','RING','SCEPTER','SMALLGEM','TOTEM','TOY' }
	,["equipment.csv"] = { 'BAG','BARREL','BIN','BUCKET','CHAIN','CRUTCH','GOBLET','INSTRUMENT','SPLINT','TOOL' }
	,["fixtures.csv"] = { 'ANVIL','ARMORSTAND','BED','BOX','CABINET','CAGE','CHAIR','COFFIN','DOOR','FLOODGATE','GRATE','HATCH_COVER','MILLSTONE',
						  'PIPE_SECTION','QUERN','SLAB','STATUE','TABLE','TRACTION_BENCH','TRAPCOMP','TRAPPARTS','WEAPONRACK','WINDOW' }
	,["agriculture.csv"] = { 'BOOK','CHEESE','CLOTH','DRINK','EGG','FISH','FOOD','GLOB','LIQUID_MISC','MEAT','PLANT','POWDER_MISC','SEEDS',
						  'SHEET','SKIN_TANNED','THREAD' }
}

--reports = {["equipment.csv"] = { 'BARREL' }}
--reports = {["kit.csv"] = { 'AMMO' }, ["equipment.csv"] = { 'BARREL' }}

for fname, item_types in pairs(reports) do
	write_inventory_csv(fname, item_types)
end


-- local item_type = "BARREL" --"AMMO"
-- local cond = {}
-- itemtools.condition_type(cond, item_type)	
-- local _, items, _ = itemtools.execute("count", cond, {verbose = true}, true)

-- for k,v in pairs(items) do
	-- long_desc, short_desc, mat, count, contains_items = parseDescription(item_type, v)
	-- print(short_desc, mat, count, contains_items)
-- end


--[[
	formatting issues: examples
		dog soap (64%)
		giraffe () cage (copper)	***male
		giraffe () cage (tin)		***female
		dwarven ale flask (silver)
		copper right gauntlet
		alpaca cheese [5]
		giant cave spider silk cloth
		rope reed cloth (80%)
		dimple cup spawn Bag (giant cave spider silk)		
		rock nuts Bag (pig tail)

	formatting issues: fixed
		Cheese Barrel (bayberry wood) <#35>
	
]]--







