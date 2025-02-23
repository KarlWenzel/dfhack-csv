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
				
		local line_item = ("%s,%s,%s,%s,%f,%s,%d,%d,%s,%d"):format(
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

function matches_any(word, word_list)

	for _,v in ipairs(word_list) do
		if (word == v) then
			return true
		end
	end
	
	return false
end

function split_last_word(x)
	
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
	return front, back
end

function coalesce_mat_types(mat)

	-- rather than have e.g., "dog bone", "pig bone", "wolverine bone", etc.. just report it as "bone"

	local last_word = ""
	_, last_word = split_last_word(mat)
	
	local mat_types = { "bone", "cloth", "leather", "wood" }
	
	for _,mat_type in ipairs(mat_types) do
		if (last_word == mat_type) then
			return mat_type
		end
	end
	
	return mat
end

function parseDescription(item_type, item)

	local raw_long_desc = dfhack.items.getDescription(item, 0, false)
	raw_long_desc = string.gsub(raw_long_desc, ",", " ") -- remove commas. they mess up the CSV output
	
	local long_desc = string.gsub(raw_long_desc, "(%s<#%d+>)", "") -- get rid of any possible "<#xx>" designations
	local short_desc = ""
	local mat = "<unk>"
	local count = 1
	local contains_items = false
	local stored_items = ""
	
	-- part 1: easy special cases
	
	if (item_type == "BOULDER") then
		return raw_long_desc, "rock", long_desc, 1, false
	end
		
	if (item_type == "ROUGH") then
		return raw_long_desc, "uncut gem", long_desc, 1, false
	end
	
	if (long_desc == "coke") then
		return raw_long_desc, "bars", "coke", 1, false
	end
	
	-- TODO: "large pot" vs "pot, large"
	-- TODO: gender on things like caged animals
	
	-- part 2: general cases

	for k,v in string.gmatch(long_desc, "([%a%s]+)%[(%d+)%]") do
		count = v
		long_desc = string.gsub(dfhack.items.getDescription(item, 1, false), ",", " ")
	end
	
	for k,v in string.gmatch(long_desc, "([%a%s%-]+)%s%(([%a%s%-]+)%)") do -- looking for a material pattern like "(dog leather)"
		stored_items,short_desc = split_last_word(k)
		mat = v
		contains_items = true -- the material pattern with parentheses is used for containers
	end	
	
	if (not contains_items) then
		for k,v in string.gmatch(long_desc, "([%a%s%-]+)%s%(([%d%%]+)%)") do -- looking for pattern like "(64%)"
			long_desc = k
			count = tonumber(string.match(v,"%d+"))/100
		end	
		mat,short_desc = split_last_word(long_desc) 			
	end
	
	-- part 3: postprocessing special cases
	
	if (item_type == "PLANT") then
		mat = mat .. " " .. short_desc
		short_desc = "plant"
	end
	
	local mat_front = ""
	local mat_back = ""	
	mat_front, mat_back = split_last_word(mat)
	
	for _,v in ipairs({ "left", "right", "high", "low", "battle", "war" }) do
		if (mat_back == v) then
			mat = mat_front
			short_desc = mat_back .. " " .. short_desc
			break
		end
	end	
	
	mat = coalesce_mat_types(mat)
	return raw_long_desc, short_desc, mat, count, contains_items
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

for fname, item_types in pairs(reports) do
	write_inventory_csv(fname, item_types)
end

-- local item_type = "BARREL"
-- local cond = {}
-- itemtools.condition_type(cond, item_type)	
-- local _, items, _ = itemtools.execute("count", cond, {verbose = true}, true)

-- for k,v in pairs(items) do
	-- long_desc, short_desc, mat, count, contains_items = parseDescription(item_type, v)
	-- print(short_desc, mat, count, contains_items)
-- end








