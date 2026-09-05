return function(mod)
    local Font = mod.ui.Font
    local Theme = mod.ui.Theme
    local SpriteRenderer = require("src.render.SpriteRenderer")
    local FieldDefaults = require("src.world.FieldDefaults")
    local Assets = require("src.render.Assets")
    local PaletteFX = require("src.render.PaletteFX")
    local GbcPalette = require("src.render.GbcPalette")
    local Sound = require("src.core.Sound")

local SKIN_FILES = {
    front = "front.png",
    front2 = "front2.png",
    front3 = "front3.png",
    back = "back.png",
    walk = "walk.png",
    bike = "bike.png",
    surf = "surf.png",
    surf_pikachu = "surf_pikachu.png",
    fish_front = "fish_front.png",
    fish_back = "fish_back.png",
    fish_side = "fish_side.png"
}

local PREVIEW = {
    x = 96,
    battle_y = 16,
    battle_w = 56,
    battle_h = 56,
    walk_y = 88,
    bike_y = 120,
    spacing = 20
}

local SKIN_LIST_VISIBLE = 7

local ROLE_PLAYER = "player"
local ROLE_RIVAL = "rival"

local ROLE_CONFIG = {
    [ROLE_PLAYER] = { skin_key = "skin", color_key = "skin_color" },
    [ROLE_RIVAL] = { skin_key = "rival_skin", color_key = "rival_skin_color" }
}

local DEFAULT_SKIN_COLOR = "green"

local SKIN_COLOR_ORDER = {
    "truecolor",
    "red",
    "green",
    "blue",
    "yellow",
    "purple",
    "orange",
    "cyan",
    "pink",
    "brown",
    "gray"
}

local SKIN_COLOR_INDEX = {}
for index, id in ipairs(SKIN_COLOR_ORDER) do
    SKIN_COLOR_INDEX[id] = index
end

local SKIN_COLOR_PALETTES = {
    red = {
        { 255, 255, 255 },
        { 239, 156, 107 },
        { 255, 0, 0  },
        { 0, 0, 0 }
    },
    green = {
        { 255, 255, 255 },
        { 239, 156, 107 },
        { 58, 189, 25 },
        { 0, 0, 0 }
    },
    blue = {
        { 255, 255, 255 },
        { 239, 156, 107 },
        { 82, 74, 255 },
        { 0, 0, 0 }
    },
	yellow = {
		{ 255, 255, 255 },
		{ 239, 156, 107 },
		{ 173, 90, 0 },
		{ 0, 0, 0 }
	},
    purple = {
        { 255, 255, 255 },
        { 239, 156, 107 },
        { 139, 0, 186 },
        { 0, 0, 0 }
    },
    orange = {
        { 255, 255, 255 },
        { 239, 156, 107 },
        { 191, 57, 0 },
        { 0, 0, 0 }
    },		
    cyan = {
        { 255, 255, 255 },
        { 239, 156, 107 },
        { 88, 184, 248 },
        { 0, 0, 0 }
    },
    pink = {
        { 255, 255, 255 },
        { 239, 156, 107 },
        { 249, 0, 170 },
        { 0, 0, 0 }
    },
    brown = {
        { 255, 255, 255 },
        { 239, 156, 107 },
        { 58, 44, 19 },
        { 0, 0, 0 }
    },
    gray = {
        { 255, 255, 255 },
        { 239, 156, 107 },
        { 75, 75, 75 },
        { 0, 0, 0 }
    },		
}

local function normalize_role(role)
    return role == ROLE_RIVAL and ROLE_RIVAL or ROLE_PLAYER
end

local function valid_skin_color(id)
    return SKIN_COLOR_INDEX[id] and id or DEFAULT_SKIN_COLOR
end

-- Migrate old saves once so Player and Rival colors become independent.
do
    local rival_color_key = ROLE_CONFIG[ROLE_RIVAL].color_key

    if mod.save:get(rival_color_key) == nil then
        local player_color = valid_skin_color(mod.save:get(ROLE_CONFIG[ROLE_PLAYER].color_key, DEFAULT_SKIN_COLOR))
        mod.save:set(rival_color_key, player_color)
    end
end

-- Palette pipeline contract:
-- 1. The skin selects the image assets.
-- 2. PaletteFX/GbcPalette and the current game context always own the final color.

local function selected_skin_color(role)
    role = normalize_role(role)
    return valid_skin_color(mod.save:get(ROLE_CONFIG[role].color_key, DEFAULT_SKIN_COLOR))
end

local function true_color_selected(role)
    return selected_skin_color(role) == "truecolor"
end

local function skin_true_color_active(role)
    return true_color_selected(role) and PaletteFX.honorsTrueColor()
end

    local IDLE_FRAMES = { down = 1, up = 2, left = 3 }
    local STEP_FRAMES = { down = 4, up = 5, left = 6 }

local skins = {
    {
        id = "Default",
        name = "Default"
    }
}

local Gen2Save
local original_sprite_defs = {}

    local GEN2_PLAYER_SPRITES = {
        { id = "SPRITE_CHRIS", key = "walk" },
        { id = "SPRITE_KRIS", key = "walk" },
        { id = "SPRITE_CHRIS_BIKE", key = "bike" },
        { id = "SPRITE_KRIS_BIKE", key = "bike" },
        { id = "SPRITE_SURF", key = "surf" },
        { id = "SPRITE_SURFING_PIKACHU", key = "surf_pikachu" }
    }

local GEN2_DEFAULT_SPRITES = {
    walk = {
        male = { "SPRITE_CHRIS" },
        female = { "SPRITE_KRIS", "SPRITE_CHRIS" }
    },
    bike = {
        male = { "SPRITE_CHRIS_BIKE" },
        female = { "SPRITE_KRIS_BIKE", "SPRITE_CHRIS_BIKE" }
    },
    surf = { "SPRITE_SURF" },
    surfPikachu = { "SPRITE_SURFING_PIKACHU" }
}

    local function is_gen2(game)
        return game and game.data and game.data.gen2Sprites ~= nil
    end

    local function is_gen2_female(game)
        if not is_gen2(game) then return false end

        if Gen2Save == nil then
            local ok, module = pcall(require, "src.core.gen2.Save")
            Gen2Save = ok and module or false
        end

        if Gen2Save and Gen2Save.isFemale then
            return Gen2Save.isFemale(game.save)
        end

        return game.save and game.save.player and game.save.player.gender == "female" or false
    end

    local function get_player(game)
        local world = game and (game.overworld or game.world)
        return world and world.player or nil
    end

    local function asset_exists(path)
        return love.filesystem.getInfo(mod.assets:path(path), "file") ~= nil
    end

    local function skin_asset(folder, filename)
        local path = "assets/skins/" .. folder .. "/" .. filename
        return asset_exists(path) and path or nil
    end

    local function safe_image(path)
        if not path then return nil end

        local ok, image = pcall(Assets.image, path)
        return ok and image or nil
    end

    local palette_assets = {}
    local base_image_data = Assets.imageData

    local function register_palette_asset(path, obj)
        palette_assets[mod.assets:path(path)] = obj and "obj" or "pic"
    end

    local function quantize_palette_data(data, obj)
        data:mapPixel(function(_, _, r, g, b, a)
            if a == 0 then return r, g, b, a end

            local luminance = r * 0.2126 + g * 0.7152 + b * 0.0722
            local shade

            if obj then
                shade = luminance >= 0.60 and 170 / 255 or luminance >= 0.17 and 85 / 255 or 0
            else
                shade = luminance >= 0.83 and 1 or luminance >= 0.50 and 170 / 255 or luminance >= 0.17 and 85 / 255 or 0
            end

            return shade, shade, shade, a
        end)

        return data
    end

local image_load_role = ROLE_PLAYER

local function with_skin_role(role, fn)
    role = normalize_role(role)

    if image_load_role == role then
        return fn()
    end

    local previous_role = image_load_role
    image_load_role = role

    local results = { pcall(fn) }

    image_load_role = previous_role

    local success = table.remove(results, 1)
    if not success then error(results[1], 0) end

    return unpack(results)
end

Assets.imageData = function(path)
    local kind = palette_assets[path]
    local data = base_image_data(path)

    if not kind or skin_true_color_active(image_load_role) then return data end
    return quantize_palette_data(data, kind == "obj")
end

local function sprite_renderer_role(renderer)
    local def = renderer and renderer.def
    if not def or not def._trainerSkinId then return nil end

    local role = def._trainerSkinRole

    if role ~= ROLE_PLAYER and role ~= ROLE_RIVAL then
        return nil
    end

    return role
end

local function install_sprite_renderer_role_context()
    if SpriteRenderer._trainerSkinsRoleContextPatched then return end

    local original_resolve_image = SpriteRenderer.resolveImage
    local original_draw = SpriteRenderer.draw
    local original_draw_tile = SpriteRenderer.drawTile

    SpriteRenderer.resolveImage = function(renderer)
        local role = sprite_renderer_role(renderer)

        if not role then
            return original_resolve_image(renderer)
        end

        return with_skin_role(role, function()
            return original_resolve_image(renderer)
        end)
    end

    SpriteRenderer.draw = function(renderer, px, py, camX, camY, facing, walkPhase, stepFlip, topHalf, forceFlip, frameOverride, oamRow)
        local role = sprite_renderer_role(renderer)

        if not role then
            return original_draw(renderer, px, py, camX, camY, facing, walkPhase, stepFlip, topHalf, forceFlip, frameOverride, oamRow)
        end

        return with_skin_role(role, function()
            return original_draw(renderer, px, py, camX, camY, facing, walkPhase, stepFlip, topHalf, forceFlip, frameOverride, oamRow)
        end)
    end

    SpriteRenderer.drawTile = function(renderer, path, x, y, flip, quad)
        local role = sprite_renderer_role(renderer)

        if not role then
            return original_draw_tile(renderer, path, x, y, flip, quad)
        end

        return with_skin_role(role, function()
            return original_draw_tile(renderer, path, x, y, flip, quad)
        end)
    end

    SpriteRenderer._trainerSkinsRoleContextPatched = true
end
install_sprite_renderer_role_context()

local function create_gen2_front_preview(game)
    local ok, TrainerCard = pcall(require, "src.ui.gen2.TrainerCard")
    if not ok or not TrainerCard then return nil end

    local trainer_card = TrainerCard.new(game)
    if not trainer_card:styled() or not trainer_card.card then return nil end

    local sheet = trainer_card.card
    local image = sheet:image()
    if not image then return nil end

    local portrait = love.graphics.newCanvas(40, 56)
    local wide = trainer_card.gfx and trainer_card.gfx.portraitWide or 5
    local high = math.floor((trainer_card.gfx and trainer_card.gfx.portraitTiles or 35) / wide)

    love.graphics.push("all")
    love.graphics.setCanvas(portrait)
    love.graphics.origin()
    love.graphics.clear(0, 0, 0, 0)
    love.graphics.setShader()
    love.graphics.setColor(1, 1, 1, 1)

    for row = 0, high - 1 do
        for col = 0, wide - 1 do
            local index = row * wide + col
            local quad = sheet:quad(index)

            if quad then
                love.graphics.draw(image, quad, col * 8, row * 8)
            end
        end
    end

    love.graphics.setCanvas()
    love.graphics.pop()

    return portrait
end

    local function discover_skins()
        local skins_path = mod.assets:path("assets/skins")
        local info = love.filesystem.getInfo(skins_path)

        if not info or info.type ~= "directory" then return end

        local folders = love.filesystem.getDirectoryItems(skins_path)

        table.sort(folders, function(a, b)
            local lower_a, lower_b = string.lower(a), string.lower(b)
            return lower_a == lower_b and a < b or lower_a < lower_b
        end)

        for _, folder in ipairs(folders) do
            local folder_info = love.filesystem.getInfo(skins_path .. "/" .. folder)

if folder_info and folder_info.type == "directory" and string.lower(folder) ~= "default" then
    local skin = {
        id = folder,
        name = folder
    }

                for key, filename in pairs(SKIN_FILES) do
                    local path = skin_asset(folder, filename)
                    skin[key] = path

if path then
    local is_pic = key == "front" or key == "front2" or key == "front3" or key == "back"
    register_palette_asset(path, not is_pic)
end
                end

                table.insert(skins, skin)
            end
        end
    end

    discover_skins()

local skin_by_id = {}
local skin_index_by_id = {}

for i, skin in ipairs(skins) do
    skin_by_id[skin.id] = skin
    skin_index_by_id[skin.id] = i

    if skin.back then
        mod.content.battle_sprite_scales:register("trainer_skin_back_" .. tostring(i), {
            path = mod.assets:path(skin.back),
            scale = 1
        })
    end
end

local TRAINER_SKINS_ARROW_BLINK_TIME = 2.5

local function update_trainer_skins_arrow(card, dt)
    local period = TRAINER_SKINS_ARROW_BLINK_TIME * 2
    card._trainerSkinsArrowTimer = ((card._trainerSkinsArrowTimer or 0) + dt) % period
end

local function trainer_skins_arrow_visible(card)
    return (card._trainerSkinsArrowTimer or 0) < TRAINER_SKINS_ARROW_BLINK_TIME
end

local function get_skin(id)
    local skin = skin_by_id[id]

    if skin then
        return skin, skin_index_by_id[id]
    end

    return skins[1], 1
end

local function selected_skin_for(role)
    role = normalize_role(role)
    return get_skin(mod.save:get(ROLE_CONFIG[role].skin_key, skins[1].id))
end

local function custom_trainer_skin_active()
    local player_skin = selected_skin_for(ROLE_PLAYER)
    local rival_skin = selected_skin_for(ROLE_RIVAL)

    return (player_skin and player_skin.id ~= "Default")
        or (rival_skin and rival_skin.id ~= "Default")
end

local function install_overworld_transition_compatibility()
    local ok_gen1, Gen1World = pcall(require, "src.world.OverworldController")

    if ok_gen1 and Gen1World and type(Gen1World.drawWorldFaded) == "function" and not Gen1World._trainerSkinsTransitionPatched then
        local original_draw_world_faded = Gen1World.drawWorldFaded

        Gen1World.drawWorldFaded = function(world, ...)
            if custom_trainer_skin_active() then
                return false
            end

            return original_draw_world_faded(world, ...)
        end

        Gen1World._trainerSkinsTransitionPatched = true
    end

    local ok_gen2, Gen2World = pcall(require, "src.world.gen2.World")

    if ok_gen2 and Gen2World and type(Gen2World.drawFadeRemap) == "function" and not Gen2World._trainerSkinsTransitionPatched then
        local original_draw_fade_remap = Gen2World.drawFadeRemap

        Gen2World.drawFadeRemap = function(world, ...)
            if custom_trainer_skin_active() then
                return false
            end

            return original_draw_fade_remap(world, ...)
        end

        Gen2World._trainerSkinsTransitionPatched = true
    end
end

install_overworld_transition_compatibility()

local function skin_fish_tiles(skin)
    if not skin or skin.id == "Default" then return nil end

    if skin._fishTiles ~= nil then
        return skin._fishTiles or nil
    end

    local tiles = {}

    if skin.fish_front then
        tiles.down = mod.assets:path(skin.fish_front)
    end

    if skin.fish_back then
        tiles.up = mod.assets:path(skin.fish_back)
    end

    if skin.fish_side then
        local side = mod.assets:path(skin.fish_side)
        tiles.left = side
        tiles.right = side
    end

    skin._fishTiles = next(tiles) and tiles or false
    return skin._fishTiles or nil
end

local function skin_base_palette(skin, role)
    if not skin or skin.id == "Default" then return nil end
    return SKIN_COLOR_PALETTES[selected_skin_color(role)]
end

local function selected_skin_palette(role)
    role = normalize_role(role)
    return skin_base_palette(selected_skin_for(role), role)
end

local function skin_palette_group(skin, prefix, role)
    role = normalize_role(role)
    local id = skin and skin.id or "none"
    return (prefix or "trainer_skin") .. ":" .. role .. ":" .. tostring(id) .. ":" .. selected_skin_color(role)
end

local GEN2_SKIN_SPRITE_KEYS = {
    "walk",
    "bike",
    "surf",
    "surf_pikachu"
}

local function is_custom_gen2_player_sprite(entity, skin)
    if not entity or not entity.spriteDef or not skin then return false end

    local def = entity.spriteDef

    if def._trainerSkinId ~= nil then
        return def._trainerSkinId == skin.id
    end

    local image = def.image
    if not image then return false end

    for _, key in ipairs(GEN2_SKIN_SPRITE_KEYS) do
        local path = skin[key]

        if path and image == mod.assets:path(path) then
            return true
        end
    end

    return false
end

local function install_gen2_overworld_palette_source()
    local ok, World = pcall(require, "src.world.gen2.World")
    if not ok or not World or type(World.applySpritePalette) ~= "function" then return end
    if World._trainerSkinsPaletteSourcePatched then return end

    local original_apply_sprite_palette = World.applySpritePalette

    World.applySpritePalette = function(world, entity)
        local result = original_apply_sprite_palette(world, entity)

        if not entity or not entity.sprite then
            return result
        end

        local skin
        local prefix
        local role

        if world.player and entity == world.player then
            skin = selected_skin_for(ROLE_PLAYER)

            if not skin or skin.id == "Default" then
                return result
            end

            if not is_custom_gen2_player_sprite(entity, skin) then
                return result
            end

            prefix = "trainer_skin_gen2"
            role = ROLE_PLAYER
        else
            local def = entity.spriteDef

            if not def or def._trainerSkinRole ~= ROLE_RIVAL then
                return result
            end

            skin = selected_skin_for(ROLE_RIVAL)

            if not skin or skin.id == "Default" then
                return result
            end

            prefix = "trainer_skin_rival_gen2"
            role = ROLE_RIVAL
        end

        local colors = skin_base_palette(skin, role)

        if colors then
            entity.sprite:setObjPalette(colors, skin_palette_group(skin, prefix, role))
        end
        return result
    end

    World._trainerSkinsPaletteSourcePatched = true
end

install_gen2_overworld_palette_source()

local skin_image_cache = {}

local function skin_image_variant(role)
    return skin_true_color_active(role) and "truecolor" or "quantized"
end

local function cached_skin_image(full_path, role)
    if not full_path then return nil end

    role = normalize_role(role)

    local variant = skin_image_variant(role)
    local key = full_path .. "#" .. variant

    local cached = skin_image_cache[key]
    if cached then return cached end

    local data = with_skin_role(role, function()
        return Assets.imageData(full_path)
    end)

    local image = love.graphics.newImage(data)
    image:setFilter("nearest", "nearest")

    skin_image_cache[key] = image
    return image
end

local function skin_image(path, role)
    return path and cached_skin_image(mod.assets:path(path), role) or nil
end

local function load_skin_visual(skin, key, role)
    if not skin or skin.id == "Default" then return nil end

    local path = skin[key]
    if not path then return nil end

    role = normalize_role(role)

    local ok, image = pcall(skin_image, path, role)
    if not ok or not image then return nil end

    return image, skin_true_color_active(role)
end

Assets.register(function()
    skin_image_cache = {}
end)

local function install_gen1_advanced_palette_source()
    if PaletteFX._trainerSkinsPaletteSourcePatched then return end
    if type(PaletteFX.spriteObp) ~= "function" then return end

    local original_sprite_obp = PaletteFX.spriteObp

    PaletteFX.spriteObp = function(sprite_def, seed)
        local skin_id = sprite_def and sprite_def._trainerSkinId

        if skin_id then
local skin = get_skin(skin_id)
local role = sprite_def._trainerSkinRole == ROLE_RIVAL and ROLE_RIVAL or ROLE_PLAYER
local colors = skin_base_palette(skin, role)

if colors then
    return PaletteFX.darkObp(colors, skin_palette_group(skin, "trainer_skin_advanced", role))
end
        end

        return original_sprite_obp(sprite_def, seed)
    end

    PaletteFX._trainerSkinsPaletteSourcePatched = true
end

install_gen1_advanced_palette_source()

local GEN1_RIVAL_CLASSES = {
    OPP_RIVAL1 = true,
    OPP_RIVAL2 = true,
    OPP_RIVAL3 = true
}

local function gen1_rival_front(skin, opp_class)
    if not skin then return nil end

    if opp_class == "OPP_RIVAL2" then
        return skin.front2 or skin.front
    end

    if opp_class == "OPP_RIVAL3" then
        return skin.front3 or skin.front
    end

    return skin.front
end

local gen1_battle_back_palette_cache = {}

local function get_gen1_battle_trainer_image(state, path, skin, role)
role = normalize_role(role)

    if not skin or skin.id == "Default" or not path then return nil end

    local full_path = mod.assets:path(path)
    local true_color_active = skin_true_color_active(role)

    local forced_raw = PaletteFX.mode == "og"
        or PaletteFX.mode == "og_inv"
        or PaletteFX.mode == "classic"
        or PaletteFX.forcesRawGrays()

    local colors

    if not true_color_active and not forced_raw then
        if PaletteFX.usesGbcPack() then
            colors = skin_base_palette(skin, role)
        else
            colors = PaletteFX.pal(state.game.data, "MEWMON") or PaletteFX.GRAYS
        end

        if colors then
            colors = PaletteFX.effectiveColors(colors)
        end
    end

    local cache_key = full_path
        .. "#" .. tostring(skin.id)
        .. "#" .. role
.. "#" .. selected_skin_color(role)
        .. "#" .. tostring(PaletteFX.mode)
        .. "#" .. tostring(true_color_active)
        .. "#" .. tostring(forced_raw)

    local cached = gen1_battle_back_palette_cache[cache_key]
    if cached then return cached end

    local data = with_skin_role(role, function()
    return Assets.imageData(full_path)
end)

    if colors then
        data:mapPixel(function(_, _, r, g, b, a)
            if a == 0 then return r, g, b, a end

            local color = r > 0.83 and colors[1]
                or r > 0.50 and colors[2]
                or r > 0.17 and colors[3]
                or colors[4]

            return color[1] / 255, color[2] / 255, color[3] / 255, a
        end)
    end

    local image = love.graphics.newImage(data)
    image:setFilter("nearest", "nearest")

    gen1_battle_back_palette_cache[cache_key] = image
    return image
end

local function install_gen1_battle_back_palette_pipeline()
    local ok, BattleState = pcall(require, "src.battle.BattleState")
    if not ok or not BattleState or type(BattleState.picImage) ~= "function" then return end
    if BattleState._trainerSkinsBackPalettePipelinePatched then return end

    local original_pic_image = BattleState.picImage

BattleState.picImage = function(state, image)
    local resolved = original_pic_image(state, image)

    if is_gen2(state.game) then return resolved end

local skin
local path
local role

if image == state.playerBackPic then
    skin = selected_skin_for(ROLE_PLAYER)
    path = skin and skin.back
    role = ROLE_PLAYER
elseif image == state.trainerPic and GEN1_RIVAL_CLASSES[state.oppClass] then

    skin = selected_skin_for(ROLE_RIVAL)
    path = skin and gen1_rival_front(skin, state.oppClass)
    role = ROLE_RIVAL
else
    return resolved
end

    if not skin or skin.id == "Default" or not path then
        return resolved
    end

    if state.grayPics or state.blackedOut or (state.introSlide or 0) > 0 then
        return resolved
    end

    if state.activeBgp and state:activeBgp() then
        return resolved
    end

    local success, replacement = pcall(get_gen1_battle_trainer_image, state, path, skin, role)

    if success and replacement then
        return replacement
    end

    return resolved
end

    BattleState._trainerSkinsBackPalettePipelinePatched = true
end

Assets.register(function()
    gen1_battle_back_palette_cache = {}
end)

install_gen1_battle_back_palette_pipeline()

local function install_gen1_rival_battle_pipeline()
    local ok, BattleState = pcall(require, "src.battle.BattleState")
    if not ok or not BattleState or type(BattleState.trainerSprite) ~= "function" then return end
    if BattleState._trainerSkinsRivalBattlePatched then return end

    local original_trainer_sprite = BattleState.trainerSprite

BattleState.trainerSprite = function(data, trainer, opp_class, party_index)
    local skin = selected_skin_for(ROLE_RIVAL)
    local front = gen1_rival_front(skin, opp_class)

    if GEN1_RIVAL_CLASSES[opp_class]
        and skin
        and skin.id ~= "Default"
        and front then

        local custom = {
            pic = mod.assets:path(front),
            trueColor = skin_true_color_active(ROLE_RIVAL)
        }

        if type(trainer) == "table" then
            setmetatable(custom, { __index = trainer })
        end

return with_skin_role(ROLE_RIVAL, function()
    return original_trainer_sprite(data, custom, opp_class, party_index)
end)
    end

    return original_trainer_sprite(data, trainer, opp_class, party_index)
end

    BattleState._trainerSkinsRivalBattlePatched = true
end

install_gen1_rival_battle_pipeline()

local gen2_card_cache = {}
local gen2_card_bounds_cache = {}

Assets.register(function()
    gen2_card_cache = {}
    gen2_card_bounds_cache = {}
end)

local GEN2_RIVAL_CLASSES = {
    RIVAL1 = true,
    RIVAL2 = true,
    [9] = true,
    [42] = true
}

local GEN2_RIVAL_FRONT2_CLASSES = {
    RIVAL2 = true,
    [42] = true
}

local function is_gen2_rival_class(class_name)
    return GEN2_RIVAL_CLASSES[class_name] == true
end

local function gen2_rival_front(skin, class_name)
    if not skin then return nil end

    if GEN2_RIVAL_FRONT2_CLASSES[class_name] then
        return skin.front2 or skin.front
    end

    return skin.front
end

local function install_gen2_battle_skin_pipeline()
    local ok, BattleState = pcall(require, "src.ui.gen2.BattleState")
    if not ok or not BattleState then return end
    if type(BattleState.new) ~= "function" or type(BattleState.drawPic) ~= "function" or type(BattleState.trainerArt) ~= "function" then return end
    if BattleState._trainerSkinsBattlePipelinePatched then return end

    local Gen2Palettes = require("src.world.gen2.Palettes")

    local original_new = BattleState.new
    local original_draw_pic = BattleState.drawPic
    local original_trainer_art = BattleState.trainerArt
    local original_trainer_colors = Gen2Palettes.trainerColors

    local function refresh_battle_trainer_image(state, role, path)
        if not path then return false end

        local ok_image, image = pcall(skin_image, path, role)
        if not ok_image or not image then return false end

        if role == ROLE_RIVAL then
            state.enemyTrainerImage = image
            state.enemyTrainerPath = mod.assets:path(path)
            state.enemyTrainerTrueColor = skin_true_color_active(ROLE_RIVAL)
        else
            state.playerBackImage = image
            state.playerBackPath = mod.assets:path(path)
            state.playerBackTrueColor = skin_true_color_active(ROLE_PLAYER)
        end

        return true
    end

    local function rival_palette(data, class_name)
        local skin = selected_skin_for(ROLE_RIVAL)
        local front = gen2_rival_front(skin, class_name)

        if is_gen2_rival_class(class_name) and skin and skin.id ~= "Default" and front then
            local colors = skin_base_palette(skin, ROLE_RIVAL)

            if colors then
                return colors
            end
        end

        return original_trainer_colors(data, class_name)
    end

    BattleState.trainerArt = function(data, class_name)
        local skin = selected_skin_for(ROLE_RIVAL)
        local front = gen2_rival_front(skin, class_name)

        if is_gen2_rival_class(class_name) and skin and skin.id ~= "Default" and front then
            return mod.assets:path(front), skin_true_color_active(ROLE_RIVAL)
        end

        return original_trainer_art(data, class_name)
    end

    Gen2Palettes.trainerColors = rival_palette

    BattleState.new = function(game, opts)
        local state = original_new(game, opts)

        if not is_gen2(game) or state.tutorial then return state end

        local player_skin = selected_skin_for(ROLE_PLAYER)

        if player_skin and player_skin.back and refresh_battle_trainer_image(state, ROLE_PLAYER, player_skin.back) then
            state._trainerSkinBack = true
        end

        local rival_skin = selected_skin_for(ROLE_RIVAL)
        local rival_front = gen2_rival_front(rival_skin, state.enemyTrainerClass)

        if state.showEnemyTrainer and is_gen2_rival_class(state.enemyTrainerClass) and rival_skin and rival_skin.id ~= "Default" and rival_front and refresh_battle_trainer_image(state, ROLE_RIVAL, rival_front) then
            state._trainerSkinRival = true
        end

        return state
    end

    BattleState.drawPic = function(state, mon, back)
        local player_skin = selected_skin_for(ROLE_PLAYER)
        local rival_skin = selected_skin_for(ROLE_RIVAL)
        local rival_front = gen2_rival_front(rival_skin, state.enemyTrainerClass)

        local custom_back = back and state.showPlayerTrainer and state._trainerSkinBack and player_skin and player_skin.back
        local custom_rival = not back and state.showEnemyTrainer and state._trainerSkinRival and rival_skin and rival_front

        if custom_back then
            refresh_battle_trainer_image(state, ROLE_PLAYER, player_skin.back)
        end

        if custom_rival then
            refresh_battle_trainer_image(state, ROLE_RIVAL, rival_front)
        end

        local player_colors = custom_back and skin_base_palette(player_skin, ROLE_PLAYER)
        local rival_colors = custom_rival and skin_base_palette(rival_skin, ROLE_RIVAL)

        if not player_colors and not rival_colors then
            return original_draw_pic(state, mon, back)
        end

        Gen2Palettes.trainerColors = function(data, class_name)
            if player_colors and class_name == "PLAYER" then
                return player_colors
            end

            if rival_colors and is_gen2_rival_class(class_name) then
                return rival_colors
            end

            return rival_palette(data, class_name)
        end

        local results = { pcall(original_draw_pic, state, mon, back) }

        Gen2Palettes.trainerColors = rival_palette

        local success = table.remove(results, 1)

        if not success then
            error(results[1], 0)
        end

        return unpack(results)
    end

    BattleState._trainerSkinsBattlePipelinePatched = true
end

install_gen2_battle_skin_pipeline()

local function get_gen2_card_bounds(full_path)
    local cached = gen2_card_bounds_cache[full_path]
    if cached then return cached end

    local data = base_image_data(full_path)
    local iw, ih = data:getDimensions()
    local min_x, min_y, max_x, max_y = iw, ih, -1, -1

    for y = 0, ih - 1 do
        for x = 0, iw - 1 do
            local _, _, _, a = data:getPixel(x, y)

            if a > 0 then
                min_x = math.min(min_x, x)
                min_y = math.min(min_y, y)
                max_x = math.max(max_x, x)
                max_y = math.max(max_y, y)
            end
        end
    end

    if max_x < min_x or max_y < min_y then
        min_x, min_y, max_x, max_y = 0, 0, iw - 1, ih - 1
    end

cached = {
    min_x = min_x,
    min_y = min_y,
    width = max_x - min_x + 1,
    height = max_y - min_y + 1
}

    gen2_card_bounds_cache[full_path] = cached
    return cached
end

local function get_gen2_card_portrait(path)
    local full_path = mod.assets:path(path)
    local variant = skin_image_variant(ROLE_PLAYER)
    local key = full_path .. "#" .. variant

    local cached = gen2_card_cache[key]
    if cached then return cached end

    local bounds = get_gen2_card_bounds(full_path)
    local image = skin_image(path, ROLE_PLAYER)

    if not image then return nil end

    local scale = math.min(1, 40 / bounds.width, 56 / bounds.height)

    local portrait = {
        image = image,
        scale = scale,
        x = 112 + math.floor((40 - bounds.width * scale) / 2) - bounds.min_x * scale,
        y = 8 + 56 - bounds.height * scale - bounds.min_y * scale
    }

    gen2_card_cache[key] = portrait
    return portrait
end

    local function install_gen2_trainer_card_palette_pipeline()
        local ok, TrainerCard = pcall(require, "src.ui.gen2.TrainerCard")
        if not ok or not TrainerCard or TrainerCard._trainerSkinsPalettePipelinePatched then return end

        local original_draw_portrait = TrainerCard.drawPortrait

        TrainerCard.drawPortrait = function(card)
            local skin = selected_skin_for(ROLE_PLAYER)
            if not skin or not skin.front then return original_draw_portrait(card) end

            local portrait = get_gen2_card_portrait(skin.front)
local colors

if not true_color_selected(ROLE_PLAYER) then
    colors = skin_base_palette(skin, ROLE_PLAYER)
end

            love.graphics.setColor(1, 1, 1, 1)
            love.graphics.rectangle("fill", 112, 8, 40, 56)

            local function draw()
                love.graphics.setColor(1, 1, 1, 1)
                love.graphics.draw(portrait.image, portrait.x, portrait.y, 0, portrait.scale, portrait.scale)
            end

if colors and GbcPalette.available() then
    GbcPalette.with(colors, draw)
else
    draw()
end
        end

        TrainerCard._trainerSkinsPalettePipelinePatched = true
    end

    install_gen2_trainer_card_palette_pipeline()

local function install_gen1_trainer_card_palette_pipeline()
    local ok, TrainerCard = pcall(require, "src.ui.TrainerCard")
    if not ok or not TrainerCard or TrainerCard._trainerSkinsPalettePipelinePatched then return end

    local original_new = TrainerCard.new
    local original_draw = TrainerCard.draw
    local original_sgb_palettes = TrainerCard.sgbPalettes

local function refresh_portrait(card)
    local skin = selected_skin_for(ROLE_PLAYER)
    local image, true_color_active = load_skin_visual(skin, "front", ROLE_PLAYER)

    if image then
        card.pic = image
        card.picTrueColor = true_color_active
        card._trainerSkinCustomPortrait = true
        card._trainerSkinCurrentId = skin.id
        card._trainerSkinCurrentColor = selected_skin_color(ROLE_PLAYER)
        card._trainerSkinTrueColorActive = true_color_active
        return
    end

    card.pic = card._trainerSkinsVanillaPic
    card.picTrueColor = card._trainerSkinsVanillaTrueColor
    card._trainerSkinCustomPortrait = false
    card._trainerSkinCurrentId = "Default"
    card._trainerSkinCurrentColor = selected_skin_color(ROLE_PLAYER)
    card._trainerSkinTrueColorActive = skin_true_color_active(ROLE_PLAYER)
end

    TrainerCard.new = function(game, opts)
        local card = original_new(game, opts)
        if is_gen2(game) then return card end

local vanilla_path = FieldDefaults.fieldValue(game.data, "playerPics", "front")
local vanilla_pic = vanilla_path and safe_image(vanilla_path) or nil

card._trainerSkinsVanillaPic = vanilla_pic or card.pic
card._trainerSkinsVanillaTrueColor = false

        refresh_portrait(card)

        return card
    end

TrainerCard.draw = function(card)
    local skin = selected_skin_for(ROLE_PLAYER)
    local skin_id = skin and skin.id or "Default"
   local skin_color = selected_skin_color(ROLE_PLAYER)
    local true_color_active = skin_true_color_active(ROLE_PLAYER)

    if card._trainerSkinCurrentId ~= skin_id
        or card._trainerSkinCurrentColor ~= skin_color
        or card._trainerSkinTrueColorActive ~= true_color_active then
        refresh_portrait(card)
    end

    if not card.picTrueColor then
        return original_draw(card)
    end

    card.picTrueColor = false
    local result = original_draw(card)
    card.picTrueColor = true

    local _, h = card.pic:getDimensions()

    -- Keep the right card border outside the true-color area.
    PaletteFX.markTrueColor(104, 4, 48, h)

    return result
end

    TrainerCard.sgbPalettes = function(card, game)
        if card._trainerSkinCustomPortrait and PaletteFX.usesGbcPack() then
            local colors = selected_skin_palette(ROLE_PLAYER)

            if colors then
                return { PaletteFX.whole(colors) }
            end
        end

        return original_sgb_palettes(card, game)
    end

    TrainerCard._trainerSkinsPalettePipelinePatched = true
end

install_gen1_trainer_card_palette_pipeline()

local function draw_trainer_skins_down_arrow(x, y)
    love.graphics.push("all")
    love.graphics.setShader()
    love.graphics.setColor(0, 0, 0, 1)

    love.graphics.rectangle("fill", x, y, 7, 1)
    love.graphics.rectangle("fill", x + 1, y + 1, 5, 1)
    love.graphics.rectangle("fill", x + 2, y + 2, 3, 1)
    love.graphics.rectangle("fill", x + 3, y + 3, 1, 1)

    love.graphics.pop()
end

local function patch_trainer_card_skin_ui(module_name, draw_method, arrow_x, arrow_y)
    local ok, TrainerCard = pcall(require, module_name)
    if not ok or not TrainerCard then return end
    if type(TrainerCard.update) ~= "function" or type(TrainerCard[draw_method]) ~= "function" then return end
    if TrainerCard._trainerSkinsUiPatched then return end

    local original_update = TrainerCard.update
    local original_draw = TrainerCard[draw_method]

    TrainerCard.update = function(card, dt)
        local input = card.game and card.game.input

        if input and input:wasPressed("down") then
            mod.ui.push(card.game, "TrainerSkins")
            return
        end

        update_trainer_skins_arrow(card, dt)
        return original_update(card, dt)
    end

    TrainerCard[draw_method] = function(card, ...)
        local results = { original_draw(card, ...) }

        if trainer_skins_arrow_visible(card) then
            draw_trainer_skins_down_arrow(arrow_x, arrow_y)
        end

        return unpack(results)
    end

    TrainerCard._trainerSkinsUiPatched = true
end

local function install_trainer_card_skin_ui()
    patch_trainer_card_skin_ui("src.ui.TrainerCard", "draw", 7, 133)
    patch_trainer_card_skin_ui("src.ui.gen2.TrainerCard", "drawPanel", 15, 130)
end

install_trainer_card_skin_ui()

local function install_gen1_hall_of_fame_palette_pipeline()
    local ok, HallOfFame = pcall(require, "src.ui.HallOfFame")
    if not ok or not HallOfFame or HallOfFame._trainerSkinsPalettePipelinePatched then return end

    local original_new = HallOfFame.new
    local original_back_pic_for = HallOfFame.backPicFor
    local original_sgb_palettes = HallOfFame.sgbPalettes

    HallOfFame.new = function(game, on_done)
        local state = original_new(game, on_done)
        local skin = selected_skin_for(ROLE_PLAYER)
        state._trainerSkinCustomPlayer = skin and skin.id ~= "Default"
            and (skin.front ~= nil or skin.back ~= nil) or false

local image, _, true_color_active = load_skin_visual(skin, "front", ROLE_PLAYER)

if image then
    state.playerPic = image
    state.playerTrueColor = true_color_active
end

        return state
    end

    HallOfFame.backPicFor = function(state)
        local mon = state.game and state.game.save and state.game.save.party[state.index or 0]
        if mon then return original_back_pic_for(state) end

local skin = selected_skin_for(ROLE_PLAYER)
local image, _, true_color_active = load_skin_visual(skin, "back", ROLE_PLAYER)

if image then
    return image, true_color_active
end

        return original_back_pic_for(state)
    end

    HallOfFame.sgbPalettes = function(state, game)
        local player_phase = state.phase == "player"
            or state.phase == "player_stats"
            or state.phase == "player_dex"
            or state.phase == "player_rating"
            or (state.phase == "back" and state.afterBack == "player")

        if player_phase and state._trainerSkinCustomPlayer and PaletteFX.usesGbcPack() then
            local colors = selected_skin_palette(ROLE_PLAYER)
            if colors then return { PaletteFX.whole(colors) } end
        end

        return original_sgb_palettes(state, game)
    end

    HallOfFame._trainerSkinsPalettePipelinePatched = true
end

install_gen1_hall_of_fame_palette_pipeline()

local function install_gen2_hall_of_fame_palette_pipeline()
    local ok, HallOfFame = pcall(require, "src.ui.gen2.HallOfFame")
    if not ok or not HallOfFame or HallOfFame._trainerSkinsPalettePipelinePatched then return end

    local original_image = HallOfFame.image
    local original_draw_portrait = HallOfFame.drawPortrait
    local original_draw_scrolled = HallOfFame.drawScrolled

    HallOfFame.image = function(state, path)
        local skin = selected_skin_for(ROLE_PLAYER)

        if skin and skin.back and path == mod.assets:path(skin.back) then
            local ok_image, image = pcall(cached_skin_image, path, ROLE_PLAYER)
            if ok_image and image then return image end
        end

        return original_image(state, path)
    end

    HallOfFame.drawScrolled = function(state, image, tile_x, tile_y, colors)
        local skin = selected_skin_for(ROLE_PLAYER)

        if not colors and skin and skin.back and state.playerBackPath == mod.assets:path(skin.back) then
local custom_back = skin_image(skin.back, ROLE_PLAYER)

if image == custom_back then
    colors = skin_base_palette(skin, ROLE_PLAYER)
end
        end

        return original_draw_scrolled(state, image, tile_x, tile_y, colors)
    end

    HallOfFame.drawPortrait = function(state, tile_x, tile_y)
        local skin = selected_skin_for(ROLE_PLAYER)
        if not skin or not skin.front then return original_draw_portrait(state, tile_x, tile_y) end

local image = skin_image(skin.front, ROLE_PLAYER)
local colors = skin_base_palette(skin, ROLE_PLAYER)
return original_draw_scrolled(state, image, tile_x, tile_y, colors)
    end

    HallOfFame._trainerSkinsPalettePipelinePatched = true
end

install_gen2_hall_of_fame_palette_pipeline()

    local white_text_shader = love.graphics.newShader([[
        vec4 effect(vec4 color, Image texture, vec2 texture_coords, vec2 screen_coords)
        {
            vec4 pixel = Texel(texture, texture_coords);
            if (pixel.a == 0.0) { discard; }
            return vec4(1.0, 1.0, 1.0, pixel.a);
        }
    ]])

    local function get_default_player_pic(game, side)
        if is_gen2(game) then return nil end

        local key = side == "back" and "back" or "front"
        return FieldDefaults.fieldValue(game.data, "playerPics", key)
    end

local function shallow_copy(source)
    local copy = {}

    for key, value in pairs(source) do
        copy[key] = value
    end

    return copy
end

local function remember_sprite_def(def)
    if not def then return nil end

    local original = original_sprite_defs[def]

    if not original then
        original = {
            image = def.image,
            trueColor = def.trueColor,
            trainerSkinId = def._trainerSkinId,
            trainerSkinRole = def._trainerSkinRole
        }

        original_sprite_defs[def] = original
    end

    return original
end

local function restore_sprite_def(def, original)
    if not def or not original then return end

    def.image = original.image
    def.trueColor = original.trueColor
    def._trainerSkinId = original.trainerSkinId
    def._trainerSkinRole = original.trainerSkinRole
end

local function vanilla_sprite_def(def)
    if not def then return nil end

    local copy = shallow_copy(def)
    local original = original_sprite_defs[def]

    if original then
        restore_sprite_def(copy, original)
    end

    return copy
end

local function apply_skin_to_sprite_def(def, skin, skin_key, role)
    if not def then return false end

    role = normalize_role(role)

    local original = remember_sprite_def(def)
    local path = skin and skin.id ~= "Default" and skin[skin_key]

    if not path then
        restore_sprite_def(def, original)
        return false
    end

    def.image = mod.assets:path(path)
    def.trueColor = true_color_selected(role)
    def._trainerSkinId = skin.id
    def._trainerSkinRole = role

    return true
end

    local function get_default_sprite_def(game, kind)
        local data = game and game.data
        if not data then return nil end

if is_gen2(game) then
    local options = GEN2_DEFAULT_SPRITES[kind]
    if not options then return nil end

    local candidates = options.male
        and (is_gen2_female(game) and options.female or options.male)
        or options

    for _, sprite_id in ipairs(candidates) do
                local def = data.gen2Sprites[sprite_id]

                if def then
return vanilla_sprite_def(def)
                end
            end

            return nil
        end

        if not data.sprites then return nil end

        local sprite_id = FieldDefaults.fieldValue(data, "playerSprites", kind)
        return sprite_id and data.sprites[sprite_id] or nil
    end

    local function apply_gen2_palette(game, renderer, def)
        local world = game and game.world

        if is_gen2(game) and world and world.applySpritePalette then
            world:applySpritePalette({ sprite = renderer, spriteDef = def })
        end
    end

local function create_overworld_renderer(game, kind, path, skin, role, base_override)
    role = normalize_role(role)

    local base = base_override or get_default_sprite_def(game, kind)
    if not base or not path then return nil end

    local def = shallow_copy(base)

def.image = mod.assets:path(path)
def.trueColor = true_color_selected(role)
def._trainerSkinId = skin and skin.id or nil
def._trainerSkinRole = def._trainerSkinId and role or nil

    local renderer = with_skin_role(role, function()
        return SpriteRenderer.new(def, role == ROLE_RIVAL and "rival_preview" or ROLE_PLAYER)
    end)

    if is_gen2(game) then
        apply_gen2_palette(game, renderer, def)

        local colors = skin_base_palette(skin, role)

        if colors then
            renderer:setObjPalette(colors, skin_palette_group(skin, "trainer_skin_gen2_preview", role))
        end
    end

    return renderer
end

    local function create_default_renderer(game, kind)
        local def = get_default_sprite_def(game, kind)
        if not def then return nil end

        local renderer = SpriteRenderer.new(def, ROLE_PLAYER)
        apply_gen2_palette(game, renderer, def)
        return renderer
    end

    local function apply_sprite(player, field, game, skin, skin_key, default_kind)
        local path = skin[skin_key]

        if path then
            player[field] = create_overworld_renderer(game, default_kind, path, skin, ROLE_PLAYER)
        else
            player[field] = create_default_renderer(game, default_kind)
        end
    end

local function apply_gen1_fishing_skin(player, skin)
    if not player then return end

    if not player._trainerSkinsOriginalFishTiles then
        local original = player.fishTiles or {}

        player._trainerSkinsOriginalFishTiles = {
            down = original.down,
            up = original.up,
            left = original.left,
            right = original.right
        }
    end

    local original = player._trainerSkinsOriginalFishTiles
    local custom = skin_fish_tiles(skin)

    if not custom then
        player.fishTiles = {
            down = original.down,
            up = original.up,
            left = original.left,
            right = original.right
        }

        return
    end

    player.fishTiles = {
        down = custom.down or original.down,
        up = custom.up or original.up,
        left = custom.left or original.left,
        right = custom.right or original.right
    }
end

local GEN2_FISH_ROD_OAM = {
    down = { dx = 0, dy = 16, tile = 0 },
    up = { dx = 0, dy = -8, tile = 0 },
    left = { dx = -8, dy = 5, tile = 1, flip = true },
    right = { dx = 16, dy = 5, tile = 1 }
}

local function install_gen2_fishing_skin_support()
    local ok, Player = pcall(require, "src.world.gen2.Player")
    if not ok or not Player or type(Player.drawFishing) ~= "function" then return end
    if Player._trainerSkinsFishingPatched then return end

    local original_draw_fishing = Player.drawFishing

    Player.drawFishing = function(player, yOffset)
        local tiles = player._trainerSkinFishTiles
        local facing = player.facing or "down"
        local fish_tile = tiles and tiles[facing]

        if not fish_tile or not player.sprite or not player.fishSheet then
            return original_draw_fishing(player, yOffset)
        end

        local sprite = player.sprite
        local py = player.py + (yOffset or 0)

        sprite:draw(player.px, py, 0, 0, facing, 0, false, true)

        local sx, sy = sprite:getScreenOrigin(player.px, py, 0, 0)

        sprite:drawTile(
            fish_tile,
            sx,
            sy + math.max(0, sprite.frameHeight - 8),
            facing == "right"
        )

        if not player._trainerSkinRodQuads then
            player._trainerSkinRodQuads = {
                love.graphics.newQuad(0, 24, 8, 8, 16, 32),
                love.graphics.newQuad(8, 24, 8, 8, 16, 32)
            }
        end

        local rod = GEN2_FISH_ROD_OAM[facing] or GEN2_FISH_ROD_OAM.down

        sprite:drawTile(
            player.fishSheet,
            sx + rod.dx,
            sy + rod.dy,
            rod.flip,
            player._trainerSkinRodQuads[rod.tile + 1]
        )
    end

    Player._trainerSkinsFishingPatched = true
end

install_gen2_fishing_skin_support()

local function apply_gen2_skin(game, skin)
    local world = game and game.world
    if not world or not world.sprites then return false end

    for _, entry in ipairs(GEN2_PLAYER_SPRITES) do
        apply_skin_to_sprite_def(world.sprites[entry.id], skin, entry.key, ROLE_PLAYER)
    end

    if world.applyPlayerState then
        world:applyPlayerState(world.playerState)
    end

    if world.player then
        world.player._trainerSkinFishTiles = skin_fish_tiles(skin)
    end

    return true
end

local function apply_overworld_skin(game, skin)
    if not game or not skin then return end
    if is_gen2(game) and apply_gen2_skin(game, skin) then return end

    local player = get_player(game)
    if not player then return end

    apply_sprite(player, "sprite", game, skin, "walk", "walk")
    apply_sprite(player, "bikeSprite", game, skin, "bike", "bike")
    apply_sprite(player, "surfSprite", game, skin, "surf", "surf")
    apply_sprite(player, "surfPikachuSprite", game, skin, "surf_pikachu", "surfPikachu")

    apply_gen1_fishing_skin(player, skin)
end

local function get_rival_sprite_def(game)
    local data = game and game.data
    if not data then return nil end

    if is_gen2(game) then
        return data.gen2Sprites and data.gen2Sprites["SPRITE_RIVAL"] or nil
    end

    return data.sprites and data.sprites["SPRITE_BLUE"] or nil
end

local function vanilla_rival_sprite_def(game)
    return vanilla_sprite_def(get_rival_sprite_def(game))
end

local function is_rival_npc(game, npc)
    if not npc then return false end

    local raw_sprite = npc.def and npc.def.sprite

    if is_gen2(game) then
        if raw_sprite == "SPRITE_RIVAL" or raw_sprite == 4 then
            return true
        end

        local def = npc.spriteDef
        return def and def.id == "SPRITE_RIVAL" or false
    end

    return raw_sprite == "SPRITE_BLUE"
end

local function apply_rival_overworld_skin(game, skin)
    if not game or not skin then return end

    local world = game.overworld or game.world
    local base = get_rival_sprite_def(game)

    if not world or not base then return end

apply_skin_to_sprite_def(base, skin, "walk", ROLE_RIVAL)

    local visited = {}

    local function repaint(npc)
        if not npc or visited[npc] then return end
        visited[npc] = true

        if not is_rival_npc(game, npc) then return end

        local runtime_def = shallow_copy(base)

        if is_gen2(game) and type(npc.setSpriteDef) == "function" then
            npc:setSpriteDef(runtime_def)

            if world.applySpritePalette then
                world:applySpritePalette(npc)
            end
        else
            npc.sprite = with_skin_role(ROLE_RIVAL, function()
    return SpriteRenderer.new(runtime_def, npc.id)
end)
        end
    end

    for _, npc in ipairs(world.npcs or {}) do
        repaint(npc)
    end

    for _, npc in pairs(world.npcPool or {}) do
        repaint(npc)
    end
end

local function apply_role_overworld_skin(game, role, skin)
    role = normalize_role(role)
    skin = skin or selected_skin_for(role)

    if role == ROLE_RIVAL then
        apply_rival_overworld_skin(game, skin)
    else
        apply_overworld_skin(game, skin)
    end
end

local function reapply_overworld_skins(game)
    if not game then return end

    apply_role_overworld_skin(game, ROLE_PLAYER)
    apply_role_overworld_skin(game, ROLE_RIVAL)
end

local function equip_role_skin(game, skin, role)
    if not skin then return end

    role = normalize_role(role)
    mod.save:set(ROLE_CONFIG[role].skin_key, skin.id)
    apply_role_overworld_skin(game, role, skin)
end

local function set_skin_color(game, color, role)
    if not SKIN_COLOR_INDEX[color] then return false end

    role = normalize_role(role)

    local previous_color = selected_skin_color(role)
if previous_color == color then return true end   
   local true_color_transition = previous_color == "truecolor" or color == "truecolor"

    mod.save:set(ROLE_CONFIG[role].color_key, color)
    SpriteRenderer.invalidate()

if true_color_transition and game and is_gen2(game) then
    GbcPalette.clear()
end

if game then
    apply_role_overworld_skin(game, role)
end

    return true
end

local function cycle_skin_color(game, delta, role)
    role = normalize_role(role)

    local index = SKIN_COLOR_INDEX[selected_skin_color(role)] or 1
    index = (index - 1 + (delta or 1)) % #SKIN_COLOR_ORDER + 1

    return set_skin_color(game, SKIN_COLOR_ORDER[index], role)
end

    -- Battle, Trainer Card and Hall of Fame sprites
    mod.hooks:wrap("player.sprite", function(next, path, ctx)
        path = next(path, ctx)

        if ctx.demo then return path end

        local skin = selected_skin_for(ROLE_PLAYER)
        if not skin then return path end

if ctx.side == "front" and skin.front then
    ctx.trueColor = skin_true_color_active(ROLE_PLAYER)
    return mod.assets:path(skin.front)
end

if ctx.side == "back" and skin.back then
    ctx.trueColor = skin_true_color_active(ROLE_PLAYER)
    return mod.assets:path(skin.back)
end

        return path
    end)

-- Reapply the selected skin after world changes
local live_game

mod.events:on("game.ready", function(ev)
    live_game = ev.game
end)

mod.events:on("map.entered", function()
    reapply_overworld_skins(live_game)
end)

mod.events:on("world.tod_changed", function()
    if live_game and is_gen2(live_game) then
        reapply_overworld_skins(live_game)
    end
end)

    -- Skin selector screen
    mod.content.screens:register("TrainerSkins", {
new = function(game)
    local gen2 = is_gen2(game)

local self = {
    game = game,
    isOpaque = true,
    index = 1,
    scroll = 0,
    preview_timer = 0,
    show_back = false,
    walk_timer = 0,
    walk_phase = 1,
    target = ROLE_PLAYER
}

local function clamp_skin_scroll()
    if #skins <= SKIN_LIST_VISIBLE then
        self.scroll = 0
        return
    end

    if self.index - self.scroll > SKIN_LIST_VISIBLE then
        self.scroll = self.index - SKIN_LIST_VISIBLE
    elseif self.index - self.scroll < 1 then
        self.scroll = self.index - 1
    end
end

local _, player_equipped_index = selected_skin_for(ROLE_PLAYER)
local _, rival_equipped_index = selected_skin_for(ROLE_RIVAL)

self.index = player_equipped_index
self.player_equipped_index = player_equipped_index
self.rival_equipped_index = rival_equipped_index

clamp_skin_scroll()

local preview_cache = {}
local walker_quad_cache = {}

local last_palette_mode = PaletteFX.mode
            local last_gbc_mode = GbcPalette.mode
            local last_gen2_daytime = gen2 and game.world and game.world.daytime or nil
			local gen2_default_player_palette
			
            function self:sgbPalettes()
                if gen2 then return nil end

                local world = game and game.overworld
                local world_colors

                if world and world.map and world.paletteNameFor then
                    world_colors = PaletteFX.pal(game.data, world:paletteNameFor(world.map))
                end

                world_colors = world_colors or PaletteFX.pal(game.data, "MEWMON") or PaletteFX.GRAYS

                local zones = {
                    PaletteFX.whole(PaletteFX.usesGbcPack() and false or world_colors)
                }

local preview_skin = skins[self.index]
local battle_colors = PaletteFX.pal(game.data, "MEWMON") or PaletteFX.GRAYS

                if preview_skin and preview_skin.id ~= "Default" and PaletteFX.usesGbcPack() then
                    battle_colors = skin_base_palette(preview_skin, self.target) or battle_colors
                end

                local custom_preview = preview_skin and preview_skin.id ~= "Default"
zones[#zones + 1] = custom_preview and skin_true_color_active(self.target) and PaletteFX.trueColorZone(12, 2, 18, 8) or PaletteFX.zone(battle_colors, 12, 2, 18, 8)

if PaletteFX.usesGbcPack() or PaletteFX.usesSpriteObp() then
    zones[#zones + 1] = PaletteFX.trueColorZone(12, 11, 18, 12)

    if self.target == ROLE_PLAYER then
        zones[#zones + 1] = PaletteFX.trueColorZone(12, 15, 18, 16)
    end
end

                return zones
            end

            local function default_preview_image(kind)
                if gen2 then
                    local gen2_gfx = game.data.gen2MenuGfx

                    if kind == "front" then
                        return create_gen2_front_preview(game)
                    end

                    if kind == "back" then
                        local hud = gen2_gfx and gen2_gfx.battleHud
                        if not hud then return nil end

                        local path = is_gen2_female(game) and hud.playerBackFemale or nil
                        return safe_image(path or hud.playerBack)
                    end
                end

                if kind == "front" or kind == "back" then
                    return safe_image(get_default_player_pic(game, kind))
                end

                local def = get_default_sprite_def(game, kind)
                return def and def.image and safe_image(def.image) or nil
            end

local function default_rival_front_image()
    if gen2 then
        local data = game.data
        local classes = data.gen2Trainers and data.gen2Trainers.classes
        local hud = data.gen2MenuGfx and data.gen2MenuGfx.battleHud

        for _, class_name in ipairs({ "RIVAL1", "RIVAL2" }) do
            local class_def = classes and classes[class_name]
            local path = class_def and class_def.pic
                or hud and hud.trainerPics and hud.trainerPics[class_name]

            if path then
                return safe_image(path)
            end
        end

        return nil
    end

    local ok, BattleState = pcall(require, "src.battle.BattleState")
    if not ok or not BattleState then return nil end

    local trainers = game.data and game.data.trainers
    if not trainers then return nil end

    for _, class_name in ipairs({ "OPP_RIVAL1", "OPP_RIVAL2", "OPP_RIVAL3" }) do
        local trainer = trainers[class_name]

        if trainer then
            local path = BattleState.trainerPicPath(game.data, trainer, class_name, 1)

            if path then
                return safe_image(path)
            end
        end
    end

    return nil
end

local function rival_overworld_preview(skin)
    local base = vanilla_rival_sprite_def(game)
    if not base then return nil end

    if skin and skin.id ~= "Default" and skin.walk then
        local renderer = create_overworld_renderer(game, "walk", skin.walk, skin, ROLE_RIVAL, base)
        return renderer and renderer:resolveImage() or nil
    end

    local renderer = with_skin_role(ROLE_RIVAL, function()
        return SpriteRenderer.new(base, "rival_preview")
    end)

    if gen2 then
        apply_gen2_palette(game, renderer, base)
    end

    return renderer:resolveImage()
end

local function custom_or_default(path, kind)
    if not path then return default_preview_image(kind) end
    return skin_image(path, ROLE_PLAYER)
end

local function overworld_preview(kind, path, skin)
local renderer = path
    and create_overworld_renderer(game, kind, path, skin, ROLE_PLAYER)
    or create_default_renderer(game, kind)

    if not renderer then return nil end
    return renderer:resolveImage()
end

local function gen2_player_palette(custom, skin)
    if custom and skin_true_color_active(ROLE_PLAYER) then return nil end
    if custom then return skin_base_palette(skin, ROLE_PLAYER) end

    if gen2_default_player_palette then return gen2_default_player_palette end

    local ok, TrainerCard = pcall(require, "src.ui.gen2.TrainerCard")
    if not ok or not TrainerCard then return nil end

    gen2_default_player_palette = TrainerCard.new(game):palette(1)
    return gen2_default_player_palette
end

local gen2_default_rival_palette

local function gen2_rival_palette(custom, skin)
if custom and skin_true_color_active(ROLE_RIVAL) then
    return nil
end

if custom then
    return skin_base_palette(skin, ROLE_RIVAL)
end

    if gen2_default_rival_palette then
        return gen2_default_rival_palette
    end

    local palettes = game.data and game.data.gen2Palettes
    local trainer_palettes = palettes and palettes.trainers
    local pair = trainer_palettes and (trainer_palettes.RIVAL1 or trainer_palettes.RIVAL2)

    if not pair or not pair[1] or not pair[2] then
        return nil
    end

    gen2_default_rival_palette = {
        { 255, 255, 255 },
        { pair[1][1], pair[1][2], pair[1][3] },
        { pair[2][1], pair[2][2], pair[2][3] },
        { 0, 0, 0 }
    }

    return gen2_default_rival_palette
end

local function create_walker_quads(image)
    if not image then return {} end

    local width, height = image:getDimensions()
    local key = width .. "x" .. height

    local cached = walker_quad_cache[key]
    if cached then return cached end

    local quads = {}

    for i = 0, 5 do
        quads[i + 1] = love.graphics.newQuad(0, i * 16, 16, 16, width, height)
    end

    walker_quad_cache[key] = quads
    return quads
end

local function load_preview(skin)
    local cache_key = self.target .. ":" .. skin.id

    if preview_cache[cache_key] then
        return preview_cache[cache_key]
    end

    local preview

    if self.target == ROLE_RIVAL then
        local front = skin.front and skin_image(skin.front, ROLE_RIVAL) or default_rival_front_image()
        local walk = rival_overworld_preview(skin)

preview = {
    front = front,
    back = nil,
    walk = walk,
    bike = nil,
    custom_front = skin.front ~= nil,
    custom_back = false
}
    else
        local walk = overworld_preview("walk", skin.walk, skin)
        local bike = overworld_preview("bike", skin.bike, skin)

        preview = {
            front = custom_or_default(skin.front, "front"),
            back = custom_or_default(skin.back, "back"),
            walk = walk,
            bike = bike,
            custom_front = skin.front ~= nil,
            custom_back = skin.back ~= nil
        }
    end

    preview.walk_quads = create_walker_quads(preview.walk)
    preview.bike_quads = create_walker_quads(preview.bike)

    preview_cache[cache_key] = preview
    return preview
end

            local function draw_centered(image, x, y, w, h)
                if not image then return end

                local iw, ih = image:getDimensions()
                local dx = x + math.floor((w - iw) / 2)
                local dy = y + math.floor((h - ih) / 2)

                love.graphics.draw(image, dx, dy)
            end

            local function draw_walker_frame(image, quad, x, y, mirrored)
                if mirrored then
                    love.graphics.draw(image, quad, x + 16, y, 0, -1, 1)
                else
                    love.graphics.draw(image, quad, x, y)
                end
            end

            local function draw_equipped_marker(x, y)
                love.graphics.setColor(1, 1, 1, 1)
                love.graphics.rectangle("fill", x + 1, y + 1, 1, 1)
                love.graphics.rectangle("fill", x + 1, y + 2, 2, 1)
                love.graphics.rectangle("fill", x + 1, y + 3, 3, 1)
                love.graphics.rectangle("fill", x + 1, y + 4, 2, 1)
                love.graphics.rectangle("fill", x + 1, y + 5, 1, 1)

                love.graphics.setColor(0, 0, 0, 1)
                love.graphics.rectangle("fill", x, y, 2, 1)
                love.graphics.rectangle("fill", x, y + 1, 1, 1)
                love.graphics.rectangle("fill", x + 2, y + 1, 1, 1)
                love.graphics.rectangle("fill", x, y + 2, 1, 1)
                love.graphics.rectangle("fill", x + 3, y + 2, 1, 1)
                love.graphics.rectangle("fill", x, y + 3, 1, 1)
                love.graphics.rectangle("fill", x + 4, y + 3, 1, 1)
                love.graphics.rectangle("fill", x, y + 4, 1, 1)
                love.graphics.rectangle("fill", x + 3, y + 4, 1, 1)
                love.graphics.rectangle("fill", x, y + 5, 1, 1)
                love.graphics.rectangle("fill", x + 2, y + 5, 1, 1)
                love.graphics.rectangle("fill", x, y + 6, 2, 1)

                love.graphics.setColor(0, 0, 0, 1)
            end

local function draw_rival_cursor(x, y)
    love.graphics.setColor(0, 0, 0, 1)

    love.graphics.rectangle("fill", x + 2, y, 3, 1)
    love.graphics.rectangle("fill", x + 1, y + 1, 5, 1)
    love.graphics.rectangle("fill", x, y + 2, 7, 3)
    love.graphics.rectangle("fill", x + 1, y + 5, 5, 1)
    love.graphics.rectangle("fill", x + 2, y + 6, 3, 1)
end

local function draw_rival_equipped_marker(x, y)
    love.graphics.setColor(0, 0, 0, 1)

    love.graphics.rectangle("fill", x + 2, y, 3, 1)
    love.graphics.rectangle("fill", x + 1, y + 1, 1, 1)
    love.graphics.rectangle("fill", x + 5, y + 1, 1, 1)
    love.graphics.rectangle("fill", x, y + 2, 1, 3)
    love.graphics.rectangle("fill", x + 6, y + 2, 1, 3)
    love.graphics.rectangle("fill", x + 1, y + 5, 1, 1)
    love.graphics.rectangle("fill", x + 5, y + 5, 1, 1)
    love.graphics.rectangle("fill", x + 2, y + 6, 3, 1)
end

            local function get_walker_frame(quads, direction, phase)
                if phase == 2 or phase == 4 then
                    return quads[IDLE_FRAMES[direction]], false
                end

                return quads[STEP_FRAMES[direction]], phase == 3 and direction ~= "left"
            end

local function draw_direction_preview(image, quads, y)
                if not image or #quads < 6 then return end

                local down_quad, down_mirrored = get_walker_frame(quads, "down", self.walk_phase)
                local up_quad, up_mirrored = get_walker_frame(quads, "up", self.walk_phase)
                local left_quad, left_mirrored = get_walker_frame(quads, "left", self.walk_phase)

                draw_walker_frame(image, down_quad, PREVIEW.x, y, down_mirrored)
                draw_walker_frame(image, up_quad, PREVIEW.x + PREVIEW.spacing, y, up_mirrored)
                draw_walker_frame(image, left_quad, PREVIEW.x + PREVIEW.spacing * 2, y, left_mirrored)
            end

local function draw_battle_preview(image, custom)
    if not image then return end

    if not gen2 then
        draw_centered(image, PREVIEW.x, PREVIEW.battle_y, PREVIEW.battle_w, PREVIEW.battle_h)
        return
    end

    local skin = skins[self.index]
    local true_color_active = custom and skin_true_color_active(self.target)

    if true_color_active then
        love.graphics.push("all")
        love.graphics.setShader()
        love.graphics.setColor(1, 1, 1, 1)

        draw_centered(image, PREVIEW.x, PREVIEW.battle_y, PREVIEW.battle_w, PREVIEW.battle_h)

        love.graphics.pop()
        return
    end

    local colors = self.target == ROLE_RIVAL
        and gen2_rival_palette(custom, skin)
        or gen2_player_palette(custom, skin)

    if colors and GbcPalette.available() then
        GbcPalette.with(colors, function()
            draw_centered(image, PREVIEW.x, PREVIEW.battle_y, PREVIEW.battle_w, PREVIEW.battle_h)
        end)
    else
        draw_centered(image, PREVIEW.x, PREVIEW.battle_y, PREVIEW.battle_w, PREVIEW.battle_h)
    end
end

            function self:update(dt)
                local gen2_daytime = gen2 and game.world and game.world.daytime or nil

if PaletteFX.mode ~= last_palette_mode
    or GbcPalette.mode ~= last_gbc_mode
    or gen2_daytime ~= last_gen2_daytime then

    last_palette_mode = PaletteFX.mode
    last_gbc_mode = GbcPalette.mode
    last_gen2_daytime = gen2_daytime

    preview_cache = {}
    gen2_default_player_palette = nil
	gen2_default_rival_palette = nil
end

if self.target == ROLE_PLAYER then
    self.preview_timer = self.preview_timer + dt

    if self.preview_timer >= 2 then
        self.preview_timer = 0
        self.show_back = not self.show_back
    end
else
    self.preview_timer = 0
    self.show_back = false
end

                self.walk_timer = self.walk_timer + dt

                if self.walk_timer >= 0.15 then
                    self.walk_timer = 0
                    self.walk_phase = self.walk_phase % 4 + 1
                end

if game.input:wasPressed("up") then
    self.index = self.index - 1
    if self.index < 1 then self.index = #skins end
    clamp_skin_scroll()
end

if game.input:wasPressed("down") then
    self.index = self.index + 1
    if self.index > #skins then self.index = 1 end
    clamp_skin_scroll()
end

if game.input:wasPressed("left") then
    if cycle_skin_color(game, -1, self.target) then
	    Sound.play(game.data, "Press_AB")
        preview_cache = {}
    end
end

if game.input:wasPressed("right") then
    if cycle_skin_color(game, 1, self.target) then
	    Sound.play(game.data, "Press_AB")
        preview_cache = {}
    end
end

if game.input:wasPressed("a") then
    equip_role_skin(game, skins[self.index], self.target)

    if self.target == ROLE_RIVAL then
        self.rival_equipped_index = self.index
    else
        self.player_equipped_index = self.index
    end

    Sound.play(game.data, "Press_AB")
end

if game.input:wasPressed("select") then
    self.target = self.target == ROLE_PLAYER and ROLE_RIVAL or ROLE_PLAYER
    self.preview_timer = 0
	Sound.play(game.data, "Press_AB")
    self.show_back = false
    return
end

if game.input:wasPressed("b") then game.stack:pop() end
            end

            function self:draw()
                -- Top header
                love.graphics.setColor(0, 0, 0, 1)
                love.graphics.rectangle("fill", 0, 0, 160, 8)

                -- Header arrows
                love.graphics.setColor(1, 1, 1, 1)
                love.graphics.rectangle("fill", 1, 1, 7, 1)
                love.graphics.rectangle("fill", 2, 2, 5, 1)
                love.graphics.rectangle("fill", 3, 3, 3, 1)
                love.graphics.rectangle("fill", 4, 4, 1, 1)

                love.graphics.rectangle("fill", 12, 1, 1, 1)
                love.graphics.rectangle("fill", 11, 2, 3, 1)
                love.graphics.rectangle("fill", 10, 3, 5, 1)
                love.graphics.rectangle("fill", 9, 4, 7, 1)

-- White title
love.graphics.setShader(white_text_shader)
love.graphics.setColor(1, 1, 1, 1)
Font.draw("SKIN", 17, 0)
Font.draw(self.target == ROLE_RIVAL and "SEL:R" or "SEL:P", 60, 0)
Font.draw("COLOR", 120, 0)
love.graphics.setShader()

-- Left arrow
love.graphics.setColor(1, 1, 1, 1)
love.graphics.rectangle("fill", 110, 3, 1, 1)
love.graphics.rectangle("fill", 111, 2, 1, 3)
love.graphics.rectangle("fill", 112, 1, 1, 5)
love.graphics.rectangle("fill", 113, 0, 1, 7)

-- Right arrow
love.graphics.rectangle("fill", 115, 0, 1, 7)
love.graphics.rectangle("fill", 116, 1, 1, 5)
love.graphics.rectangle("fill", 117, 2, 1, 3)
love.graphics.rectangle("fill", 118, 3, 1, 1)

love.graphics.setColor(0, 0, 0, 1)

-- UI boxes
Font.drawBox(0, 1, 11, 17)
Font.drawBox(11, 1, 9, 9)
Font.drawBox(11, 10, 9, 4)

if self.target == ROLE_PLAYER then
    Font.drawBox(11, 14, 9, 4)
end

                love.graphics.setColor(0, 0, 0, 1)

local first = self.scroll + 1
local last = math.min(#skins, self.scroll + SKIN_LIST_VISIBLE)

for i = first, last do
    local skin = skins[i]
    local row = i - first
    local y = 24 + row * 16

Font.draw(skin.name, 16, y)

if self.target == ROLE_PLAYER and i == self.player_equipped_index then
    draw_equipped_marker(9, y)
elseif self.target == ROLE_RIVAL and i == self.rival_equipped_index then
    draw_rival_equipped_marker(8, y)
end

if i == self.index then
    if self.target == ROLE_RIVAL then
        draw_rival_cursor(8, y)
    else
        Font.drawCode(Theme.cursor, 8, gen2 and y or y - 1)
    end
end
end

if self.scroll + SKIN_LIST_VISIBLE < #skins then
    Font.drawCode(Theme.moreArrow, 72, 128)
end

                local skin = skins[self.index]
                local preview = load_preview(skin)

                love.graphics.setColor(1, 1, 1, 1)

                -- Battle front / back
if self.target == ROLE_RIVAL then
    draw_battle_preview(preview.front, preview.custom_front)
else
    if self.show_back then
        draw_battle_preview(preview.back, preview.custom_back)
    else
        draw_battle_preview(preview.front, preview.custom_front)
    end
end

draw_direction_preview(preview.walk, preview.walk_quads, PREVIEW.walk_y)

if self.target == ROLE_PLAYER then
    draw_direction_preview(preview.bike, preview.bike_quads, PREVIEW.bike_y)
end
            end

            return self
        end
    })
end