--[[
Colors Provider module
Copyright (C) Outsidepro-Arts & other contributors, 2020-2021 
Based on https://gist.github.com/jdiscar/9144764
Special thanks to @beqabeqa473 for parsing the full list and some Python syntax prompts
]] --

local colors = {}

colors.colorList = {
	{ name = "Alice Blue", r = 240, g = 248, b = 255 },
	{ name = "Antique White", r = 250, g = 235, b = 215 },
	{ name = "Aqua", r = 0, g = 255, b = 255 },
	{ name = "Aquamarine", r = 127, g = 255, b = 212 },
	{ name = "Azure", r = 240, g = 255, b = 255 },
	{ name = "Beige", r = 245, g = 245, b = 220 },
	{ name = "Bisque", r = 255, g = 228, b = 196 },
	{ name = "Black", r = 0, g = 0, b = 0 },
	{ name = "Blanched Almond", r = 255, g = 235, b = 205 },
	{ name = "Blue", r = 0, g = 0, b = 255 },
	{ name = "Blue Violet", r = 138, g = 43, b = 226 },
	{ name = "Brown", r = 165, g = 42, b = 42 },
	{ name = "Burly Wood", r = 222, g = 184, b = 135 },
	{ name = "Cadet Blue", r = 95, g = 158, b = 160 },
	{ name = "Chartreuse", r = 127, g = 255, b = 0 },
	{ name = "Chocolate", r = 210, g = 105, b = 30 },
	{ name = "Coral", r = 255, g = 127, b = 80 },
	{ name = "Cornflower Blue", r = 100, g = 149, b = 237 },
	{ name = "Cornsilk", r = 255, g = 248, b = 220 },
	{ name = "Crimson", r = 220, g = 20, b = 60 },
	{ name = "Dark Blue", r = 0, g = 0, b = 139 },
	{ name = "Dark Cyan", r = 0, g = 139, b = 139 },
	{ name = "Dark Golden Rod", r = 184, g = 134, b = 11 },
	{ name = "Dark Gray", r = 169, g = 169, b = 169 },
	{ name = "Dark Green", r = 0, g = 100, b = 0 },
	{ name = "Dark Khaki", r = 189, g = 183, b = 107 },
	{ name = "Dark Magenta", r = 139, g = 0, b = 139 },
	{ name = "Dark Olive Green", r = 85, g = 107, b = 47 },
	{ name = "Darkorange", r = 255, g = 140, b = 0 },
	{ name = "Dark Orchid", r = 153, g = 50, b = 204 },
	{ name = "Dark Red", r = 139, g = 0, b = 0 },
	{ name = "Dark Salmon", r = 233, g = 150, b = 122 },
	{ name = "Dark Sea Green", r = 143, g = 188, b = 143 },
	{ name = "Dark Slate Blue", r = 72, g = 61, b = 139 },
	{ name = "Dark Slate Gray", r = 47, g = 79, b = 79 },
	{ name = "Dark Turquoise", r = 0, g = 206, b = 209 },
	{ name = "Dark Violet", r = 148, g = 0, b = 211 },
	{ name = "Deep Pink", r = 255, g = 20, b = 147 },
	{ name = "Deep Sky Blue", r = 0, g = 191, b = 255 },
	{ name = "Dim Gray", r = 105, g = 105, b = 105 },
	{ name = "Dodger Blue", r = 30, g = 144, b = 255 },
	{ name = "Fire Brick", r = 178, g = 34, b = 34 },
	{ name = "Floral White", r = 255, g = 250, b = 240 },
	{ name = "Forest Green", r = 34, g = 139, b = 34 },
	{ name = "Fuchsia", r = 255, g = 0, b = 255 },
	{ name = "Gainsboro", r = 220, g = 220, b = 220 },
	{ name = "Ghost White", r = 248, g = 248, b = 255 },
	{ name = "Gold", r = 255, g = 215, b = 0 },
	{ name = "Golden Rod", r = 218, g = 165, b = 32 },
	{ name = "Gray", r = 128, g = 128, b = 128 },
	{ name = "Green", r = 0, g = 128, b = 0 },
	{ name = "Green Yellow", r = 173, g = 255, b = 47 },
	{ name = "Honey Dew", r = 240, g = 255, b = 240 },
	{ name = "Hot Pink", r = 255, g = 105, b = 180 },
	{ name = "Indian Red", r = 205, g = 92, b = 92 },
	{ name = "Indigo", r = 75, g = 0, b = 130 },
	{ name = "Ivory", r = 255, g = 255, b = 240 },
	{ name = "Khaki", r = 240, g = 230, b = 140 },
	{ name = "Lavender", r = 230, g = 230, b = 250 },
	{ name = "Lavender Blush", r = 255, g = 240, b = 245 },
	{ name = "Lawn Green", r = 124, g = 252, b = 0 },
	{ name = "Lemon Chiffon", r = 255, g = 250, b = 205 },
	{ name = "Light Blue", r = 173, g = 216, b = 230 },
	{ name = "Light Coral", r = 240, g = 128, b = 128 },
	{ name = "Light Cyan", r = 224, g = 255, b = 255 },
	{ name = "Light Golden Rod Yellow", r = 250, g = 250, b = 210 },
	{ name = "Light Gray", r = 211, g = 211, b = 211 },
	{ name = "Light Green", r = 144, g = 238, b = 144 },
	{ name = "Light Pink", r = 255, g = 182, b = 193 },
	{ name = "Light Salmon", r = 255, g = 160, b = 122 },
	{ name = "Light Sea Green", r = 32, g = 178, b = 170 },
	{ name = "Light Sky Blue", r = 135, g = 206, b = 250 },
	{ name = "Light Slate Gray", r = 119, g = 136, b = 153 },
	{ name = "Light Steel Blue", r = 176, g = 196, b = 222 },
	{ name = "Light Yellow", r = 255, g = 255, b = 224 },
	{ name = "Lime", r = 0, g = 255, b = 0 },
	{ name = "Lime Green", r = 50, g = 205, b = 50 },
	{ name = "Linen", r = 250, g = 240, b = 230 },
	{ name = "Maroon", r = 128, g = 0, b = 0 },
	{ name = "Medium Aqua Marine", r = 102, g = 205, b = 170 },
	{ name = "Medium Blue", r = 0, g = 0, b = 205 },
	{ name = "Medium Orchid", r = 186, g = 85, b = 211 },
	{ name = "Medium Purple", r = 147, g = 112, b = 216 },
	{ name = "Medium Sea Green", r = 60, g = 179, b = 113 },
	{ name = "Medium Slate Blue", r = 123, g = 104, b = 238 },
	{ name = "Medium Spring Green", r = 0, g = 250, b = 154 },
	{ name = "Medium Turquoise", r = 72, g = 209, b = 204 },
	{ name = "Medium Violet Red", r = 199, g = 21, b = 133 },
	{ name = "Midnight Blue", r = 25, g = 25, b = 112 },
	{ name = "Mint Cream", r = 245, g = 255, b = 250 },
	{ name = "Misty Rose", r = 255, g = 228, b = 225 },
	{ name = "Moccasin", r = 255, g = 228, b = 181 },
	{ name = "Navajo White", r = 255, g = 222, b = 173 },
	{ name = "Navy", r = 0, g = 0, b = 128 },
	{ name = "Old Lace", r = 253, g = 245, b = 230 },
	{ name = "Olive", r = 128, g = 128, b = 0 },
	{ name = "Olive Drab", r = 107, g = 142, b = 35 },
	{ name = "Orange", r = 255, g = 165, b = 0 },
	{ name = "Orange Red", r = 255, g = 69, b = 0 },
	{ name = "Orchid", r = 218, g = 112, b = 214 },
	{ name = "Pale Golden Rod", r = 238, g = 232, b = 170 },
	{ name = "Pale Green", r = 152, g = 251, b = 152 },
	{ name = "Pale Turquoise", r = 175, g = 238, b = 238 },
	{ name = "Pale Violet Red", r = 216, g = 112, b = 147 },
	{ name = "Papaya Whip", r = 255, g = 239, b = 213 },
	{ name = "Peach Puff", r = 255, g = 218, b = 185 },
	{ name = "Peru", r = 205, g = 133, b = 63 },
	{ name = "Pink", r = 255, g = 192, b = 203 },
	{ name = "Plum", r = 221, g = 160, b = 221 },
	{ name = "Powder Blue", r = 176, g = 224, b = 230 },
	{ name = "Purple", r = 128, g = 0, b = 128 },
	{ name = "Red", r = 255, g = 0, b = 0 },
	{ name = "Rosy Brown", r = 188, g = 143, b = 143 },
	{ name = "Royal Blue", r = 65, g = 105, b = 225 },
	{ name = "Saddle Brown", r = 139, g = 69, b = 19 },
	{ name = "Salmon", r = 250, g = 128, b = 114 },
	{ name = "Sandy Brown", r = 244, g = 164, b = 96 },
	{ name = "Sea Green", r = 46, g = 139, b = 87 },
	{ name = "Sea Shell", r = 255, g = 245, b = 238 },
	{ name = "Sienna", r = 160, g = 82, b = 45 },
	{ name = "Silver", r = 192, g = 192, b = 192 },
	{ name = "Sky Blue", r = 135, g = 206, b = 235 },
	{ name = "Slate Blue", r = 106, g = 90, b = 205 },
	{ name = "Slate Gray", r = 112, g = 128, b = 144 },
	{ name = "Snow", r = 255, g = 250, b = 250 },
	{ name = "Spring Green", r = 0, g = 255, b = 127 },
	{ name = "Steel Blue", r = 70, g = 130, b = 180 },
	{ name = "Tan", r = 210, g = 180, b = 140 },
	{ name = "Teal", r = 0, g = 128, b = 128 },
	{ name = "Thistle", r = 216, g = 191, b = 216 },
	{ name = "Tomato", r = 255, g = 99, b = 71 },
	{ name = "Turquoise", r = 64, g = 224, b = 208 },
	{ name = "Violet", r = 238, g = 130, b = 238 },
	{ name = "Wheat", r = 245, g = 222, b = 179 },
	{ name = "White", r = 255, g = 255, b = 255 },
	{ name = "White Smoke", r = 245, g = 245, b = 245 },
	{ name = "Yellow", r = 255, g = 255, b = 0 },
	{ name = "Yellow Green", r = 154, g = 205, b = 50 },
	{ name = "maroon", r = 176, g = 48, b = 96 },
	{ name = "Pale Violet Red", r = 219, g = 112, b = 147 },
	{ name = "Violet Red", r = 208, g = 32, b = 144 },
	{ name = "magenta", r = 255, g = 0, b = 255 },
	{ name = "purple", r = 160, g = 32, b = 240 },
	{ name = "Medium Purple", r = 147, g = 112, b = 219 },
	{ name = "Light Slate Blue", r = 132, g = 112, b = 255 },
	{ name = "Medium Blue", r = 0, g = 0, b = 205 },
	{ name = "Dark Blue", r = 0, g = 0, b = 139 },
	{ name = "Navy Blue", r = 0, g = 0, b = 128 },
	{ name = "Light Slate Grey", r = 119, g = 136, b = 153 },
	{ name = "Slate Grey", r = 112, g = 128, b = 144 },
	{ name = "cyan", r = 0, g = 255, b = 255 },
	{ name = "Dark Cyan", r = 0, g = 139, b = 139 },
	{ name = "Dark Slate Grey", r = 47, g = 79, b = 79 },
	{ name = "Medium Aquamarine", r = 102, g = 205, b = 170 },
	{ name = "Medium Forest Green", r = 50, g = 129, b = 75 },
	{ name = "lime", r = 0, g = 255, b = 0 },
	{ name = "Yellow Green", r = 154, g = 205, b = 50 },
	{ name = "Medium Golden Rod", r = 209, g = 193, b = 102 },
	{ name = "Light Goldenrod", r = 238, g = 221, b = 130 },
	{ name = "Saddle Brown", r = 139, g = 69, b = 19 },
	{ name = "Light Grey", r = 211, g = 211, b = 211 },
	{ name = "Dark Grey", r = 169, g = 169, b = 169 },
	{ name = "gray", r = 126, g = 126, b = 126 },
	{ name = "Dim Grey", r = 105, g = 105, b = 105 }
}

function colors:getName(r, g, b)
	local mindiff = nil
	local minColorName = nil
	for _, color in ipairs(self.colorList) do
		diff = math.abs(r - color.r) * 256 + math.abs(g - color.g) * 256 + math.abs(b - color.b) * 256
		if mindiff == nil or diff < mindiff then
			mindiff = diff
			minColorName = color.name
		end
	end
	return minColorName
end

function colors:getColorID(r, g, b)
	local mindiff = nil
	local minID = nil
	for id, color in ipairs(self.colorList) do
		diff = math.abs(r - color.r) * 256 + math.abs(g - color.g) * 256 + math.abs(b - color.b) * 256
		if mindiff == nil or diff < mindiff then
			mindiff = diff
			minID = id
		end
	end
	return minID
end

return colors