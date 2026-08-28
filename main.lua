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

local DEFAULT_SKIN_COLOR = "green"

local SKIN_COLOR_ORDER = {
    "red",
    "green",
    "blue"
}

local SKIN_COLOR_INDEX = {
    red = 1,
    green = 2,
    blue = 3
}

local SKIN_COLOR_PALETTES = {
    red = {
        { 255, 255, 255 },
        { 239, 156, 107 },
        { 248, 56, 8  },
        { 0, 0, 0 }
    },
    green = {
        { 255, 255, 255 },
        { 239, 156, 107 },
        { 0, 132, 0 },
        { 0, 0, 0 }
    },
    blue = {
        { 255, 255, 255 },
        { 239, 156, 107 },
        { 0, 0, 255 },
        { 0, 0, 0 }
    }
}

-- Palette pipeline contract:
-- 1. The skin selects the image assets.
-- 2. RED/GREEN/BLUE is the skin's base RGB palette.
-- 3. PaletteFX/GbcPalette and the current game context always own the final color.
-- Never redraw the selected RGB palette after the recomp palette pipeline.

local function selected_skin_color()
    local id = mod.save:get("skin_color", DEFAULT_SKIN_COLOR)
    return SKIN_COLOR_INDEX[id] and id or DEFAULT_SKIN_COLOR
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
    local gen2_original_defs = {}

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
                shade = luminance >= 0.50 and 170 / 255 or luminance >= 0.17 and 85 / 255 or 0
            else
                shade = luminance >= 0.83 and 1 or luminance >= 0.50 and 170 / 255 or luminance >= 0.17 and 85 / 255 or 0
            end

            return shade, shade, shade, a
        end)

        return data
    end

    Assets.imageData = function(path)
        local kind = palette_assets[path]
        local data = base_image_data(path)

        if not kind then return data end
        return quantize_palette_data(data, kind == "obj")
    end

    local function create_gen2_front_preview(game)
        local ok, TrainerCard = pcall(require, "src.ui.gen2.TrainerCard")
        if not ok or not TrainerCard then return nil end

        local trainer_card = TrainerCard.new(game)
        if not trainer_card:styled() then return nil end

        local portrait = love.graphics.newCanvas(40, 56)
        local wide = trainer_card.gfx and trainer_card.gfx.portraitWide or 5
        local high = math.floor((trainer_card.gfx and trainer_card.gfx.portraitTiles or 35) / wide)

        love.graphics.push("all")
        love.graphics.setCanvas(portrait)
        love.graphics.origin()
        love.graphics.clear(0, 0, 0, 0)
        love.graphics.setColor(1, 1, 1, 1)
        love.graphics.translate(-112, -8)

        for row = 0, high - 1 do
            for col = 0, wide - 1 do
                trainer_card:tile(trainer_card.card, row * wide + col, 14 + col, 1 + row)
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
                        register_palette_asset(path, key ~= "front" and key ~= "back")
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

local function selected_skin()
    return get_skin(mod.save:get("skin", skins[1].id))
end

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

local function skin_base_palette(skin)
    if not skin or skin.id == "Default" then return nil end
    return SKIN_COLOR_PALETTES[selected_skin_color()]
end

local function selected_skin_palette()
    return skin_base_palette(selected_skin())
end

local function skin_palette_group(skin, prefix)
    local id = skin and skin.id or "none"
    return (prefix or "trainer_skin") .. ":" .. tostring(id) .. ":" .. selected_skin_color()
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

        if not entity or not world.player or entity ~= world.player or not entity.sprite then
            return result
        end

        local skin = selected_skin()
        if not skin or skin.id == "Default" then return result end
        if not is_custom_gen2_player_sprite(entity, skin) then return result end

        local colors = skin_base_palette(skin)
        if colors then
            entity.sprite:setObjPalette(colors, skin_palette_group(skin, "trainer_skin_gen2"))
        end

        return result
    end

    World._trainerSkinsPaletteSourcePatched = true
end

install_gen2_overworld_palette_source()

local skin_image_cache = {}

local function cached_skin_image(full_path)
    if not full_path then return nil end

    local cached = skin_image_cache[full_path]
    if cached then return cached end

    local data = Assets.imageData(full_path)
    local image = love.graphics.newImage(data)
    image:setFilter("nearest", "nearest")

    skin_image_cache[full_path] = image
    return image
end

local function skin_image(path)
    return path and cached_skin_image(mod.assets:path(path)) or nil
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
            local colors = skin_base_palette(skin)

            if colors then
                return PaletteFX.darkObp(colors, skin_palette_group(skin, "trainer_skin_advanced"))
            end
        end

        return original_sprite_obp(sprite_def, seed)
    end

    PaletteFX._trainerSkinsPaletteSourcePatched = true
end

install_gen1_advanced_palette_source()

local gen1_battle_back_palette_cache = {}

local function get_gen1_advanced_back_image(path)
    local skin = selected_skin()
    local colors = skin_base_palette(skin)
    if not colors then return nil end

    local full_path = mod.assets:path(path)
    local cache_key = full_path .. "#" .. selected_skin_color()
    local cached = gen1_battle_back_palette_cache[cache_key]
    if cached then return cached end

    local data = Assets.imageData(full_path)

    data:mapPixel(function(_, _, r, g, b, a)
        if a == 0 then return r, g, b, a end

        local color = r > 0.83 and colors[1]
            or r > 0.50 and colors[2]
            or r > 0.17 and colors[3]
            or colors[4]

        return color[1] / 255, color[2] / 255, color[3] / 255, a
    end)

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
        if image ~= state.playerBackPic then return resolved end
        if not PaletteFX.usesGbcPack() then return resolved end

        local skin = selected_skin()
        if not skin or not skin.back then return resolved end

        if state.grayPics or state.blackedOut or (state.introSlide or 0) > 0 then
            return resolved
        end

        if state.activeBgp and state:activeBgp() then
            return resolved
        end

        local success, replacement = pcall(get_gen1_advanced_back_image, skin.back)
        if success and replacement then return replacement end

        return resolved
    end

    BattleState._trainerSkinsBackPalettePipelinePatched = true
end

Assets.register(function()
    gen1_battle_back_palette_cache = {}
end)

install_gen1_battle_back_palette_pipeline()

    local gen2_card_cache = {}

Assets.register(function()
    gen2_card_cache = {}
end)

local function install_gen2_battle_back_palette_pipeline()
    local ok, BattleState = pcall(require, "src.ui.gen2.BattleState")
    if not ok or not BattleState or type(BattleState.new) ~= "function" then return end
    if BattleState._trainerSkinsBackPalettePipelinePatched then return end

    local original_new = BattleState.new
    local original_draw_pic = BattleState.drawPic
    local Gen2Palettes = require("src.world.gen2.Palettes")
    local original_trainer_colors = Gen2Palettes.trainerColors

    BattleState.new = function(game, opts)
        local state = original_new(game, opts)

        if not is_gen2(game) or state.tutorial then return state end

        local skin = selected_skin()
        if not skin or not skin.back then return state end

local ok_image, image = pcall(skin_image, skin.back)

if ok_image and image then
    state.playerBackImage = image
    state.playerBackPath = mod.assets:path(skin.back)
            state.playerBackTrueColor = false
            state._trainerSkinBack = true
        end

        return state
    end

    BattleState.drawPic = function(state, mon, back)
        local skin = selected_skin()
        local colors = back and state.showPlayerTrainer and state._trainerSkinBack
            and skin_base_palette(skin)

        if not colors then
            return original_draw_pic(state, mon, back)
        end

        Gen2Palettes.trainerColors = function(data, class_name)
            if class_name == "PLAYER" then return colors end
            return original_trainer_colors(data, class_name)
        end

        local results = { pcall(original_draw_pic, state, mon, back) }
        Gen2Palettes.trainerColors = original_trainer_colors

        local success = table.remove(results, 1)
        if not success then error(results[1], 0) end
        return unpack(results)
    end

    BattleState._trainerSkinsBackPalettePipelinePatched = true
end

install_gen2_battle_back_palette_pipeline()

    local function get_gen2_card_portrait(path)
        local full_path = mod.assets:path(path)
        if gen2_card_cache[full_path] then return gen2_card_cache[full_path] end

        local data = Assets.imageData(full_path)
        local iw, ih = data:getDimensions()
        local min_x, min_y, max_x, max_y = iw, ih, -1, -1

        for y = 0, ih - 1 do
            for x = 0, iw - 1 do
                local _, _, _, a = data:getPixel(x, y)

                if a > 0 then
                    min_x, min_y = math.min(min_x, x), math.min(min_y, y)
                    max_x, max_y = math.max(max_x, x), math.max(max_y, y)
                end
            end
        end

        if max_x < min_x or max_y < min_y then
            min_x, min_y, max_x, max_y = 0, 0, iw - 1, ih - 1
        end

        local content_w, content_h = max_x - min_x + 1, max_y - min_y + 1
        local scale = math.min(1, 40 / content_w, 56 / content_h)
        local image = love.graphics.newImage(data)

        image:setFilter("nearest", "nearest")

        local portrait = {
            image = image,
            scale = scale,
            x = 112 + math.floor((40 - content_w * scale) / 2) - min_x * scale,
            y = 8 + 56 - content_h * scale - min_y * scale
        }

        gen2_card_cache[full_path] = portrait
        return portrait
    end

    local function install_gen2_trainer_card_palette_pipeline()
        local ok, TrainerCard = pcall(require, "src.ui.gen2.TrainerCard")
        if not ok or not TrainerCard or TrainerCard._trainerSkinsPalettePipelinePatched then return end

        local original_draw_portrait = TrainerCard.drawPortrait

        TrainerCard.drawPortrait = function(card)
            local skin = selected_skin()
            if not skin or not skin.front then return original_draw_portrait(card) end

            local portrait = get_gen2_card_portrait(skin.front)
            local colors = skin_base_palette(skin) or (card.palette and card:palette(1))

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
        local skin = selected_skin()

        if skin and skin.front then
            local ok_image, image = pcall(skin_image, skin.front)

            if ok_image and image then
                card.pic = image
                card.picTrueColor = false
                card._trainerSkinCustomPortrait = true
                card._trainerSkinCurrentId = skin.id
            end

            return
        end

        card.pic = card._trainerSkinsVanillaPic
        card.picTrueColor = card._trainerSkinsVanillaTrueColor
        card._trainerSkinCustomPortrait = false
        card._trainerSkinCurrentId = "Default"
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
        local skin = selected_skin()
        local skin_id = skin and skin.id or "Default"

        if card._trainerSkinCurrentId ~= skin_id then
            refresh_portrait(card)
        end

        return original_draw(card)
    end

    TrainerCard.sgbPalettes = function(card, game)
        if card._trainerSkinCustomPortrait and PaletteFX.usesGbcPack() then
            local colors = selected_skin_palette()

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

local function install_trainer_card_skins_indicator()
    -- Gen 1
    do
        local ok, TrainerCard = pcall(require, "src.ui.TrainerCard")

        if ok and TrainerCard
            and type(TrainerCard.update) == "function"
            and type(TrainerCard.draw) == "function"
            and not TrainerCard._trainerSkinsIndicatorPatched then

            local original_update = TrainerCard.update
            local original_draw = TrainerCard.draw

TrainerCard.update = function(card, dt)
    update_trainer_skins_arrow(card, dt)
    return original_update(card, dt)
end

            TrainerCard.draw = function(card)
                original_draw(card)

if trainer_skins_arrow_visible(card) then
    draw_trainer_skins_down_arrow(7, 133)
end
            end

            TrainerCard._trainerSkinsIndicatorPatched = true
        end
    end

-- Gen 2
do
    local ok, TrainerCard = pcall(require, "src.ui.gen2.TrainerCard")

    if ok and TrainerCard
        and type(TrainerCard.update) == "function"
        and type(TrainerCard.drawPanel) == "function"
        and not TrainerCard._trainerSkinsIndicatorPatched then

        local original_update = TrainerCard.update
        local original_draw_panel = TrainerCard.drawPanel

TrainerCard.update = function(card, dt)
    update_trainer_skins_arrow(card, dt)
    return original_update(card, dt)
end

        TrainerCard.drawPanel = function(card)
            original_draw_panel(card)

if trainer_skins_arrow_visible(card) then
    draw_trainer_skins_down_arrow(15, 130)
end
        end

        TrainerCard._trainerSkinsIndicatorPatched = true
    end
end
end

install_trainer_card_skins_indicator()

local function install_trainer_card_skins_shortcut()
    -- Gen 1
    do
        local ok, TrainerCard = pcall(require, "src.ui.TrainerCard")

        if ok and TrainerCard and type(TrainerCard.update) == "function"
            and not TrainerCard._trainerSkinsShortcutPatched then

            local original_update = TrainerCard.update

            TrainerCard.update = function(card, dt)
                local input = card.game and card.game.input

                if input and input:wasPressed("down") then
                    mod.ui.push(card.game, "TrainerSkins")
                    return
                end

                return original_update(card, dt)
            end

            TrainerCard._trainerSkinsShortcutPatched = true
        end
    end

    -- Gen 2
    do
        local ok, TrainerCard = pcall(require, "src.ui.gen2.TrainerCard")

        if ok and TrainerCard and type(TrainerCard.update) == "function"
            and not TrainerCard._trainerSkinsShortcutPatched then

            local original_update = TrainerCard.update

            TrainerCard.update = function(card, dt)
                local input = card.game and card.game.input

if input and input:wasPressed("down") then
    mod.ui.push(card.game, "TrainerSkins")
    return
end

                return original_update(card, dt)
            end

            TrainerCard._trainerSkinsShortcutPatched = true
        end
    end
end

install_trainer_card_skins_shortcut()

local function install_gen1_hall_of_fame_palette_pipeline()
    local ok, HallOfFame = pcall(require, "src.ui.HallOfFame")
    if not ok or not HallOfFame or HallOfFame._trainerSkinsPalettePipelinePatched then return end

    local original_new = HallOfFame.new
    local original_back_pic_for = HallOfFame.backPicFor
    local original_sgb_palettes = HallOfFame.sgbPalettes

    HallOfFame.new = function(game, on_done)
        local state = original_new(game, on_done)
        local skin = selected_skin()
        state._trainerSkinCustomPlayer = skin and skin.id ~= "Default"
            and (skin.front ~= nil or skin.back ~= nil) or false

        if skin and skin.front then
            local ok_image, image = pcall(skin_image, skin.front)
            if ok_image and image then
                state.playerPic = image
                state.playerTrueColor = false
            end
        end

        return state
    end

    HallOfFame.backPicFor = function(state)
        local mon = state.game and state.game.save and state.game.save.party[state.index or 0]
        if mon then return original_back_pic_for(state) end

        local skin = selected_skin()
        if skin and skin.back then
            local ok_image, image = pcall(skin_image, skin.back)
            if ok_image and image then return image, false end
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
            local colors = selected_skin_palette()
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
        local skin = selected_skin()

        if skin and skin.back and path == mod.assets:path(skin.back) then
            local ok_image, image = pcall(cached_skin_image, path)
            if ok_image and image then return image end
        end

        return original_image(state, path)
    end

    HallOfFame.drawScrolled = function(state, image, tile_x, tile_y, colors)
        local skin = selected_skin()

        if not colors and skin and skin.back and state.playerBackPath == mod.assets:path(skin.back) then
            local custom_back = skin_image(skin.back)
            if image == custom_back then colors = skin_base_palette(skin) end
        end

        return original_draw_scrolled(state, image, tile_x, tile_y, colors)
    end

    HallOfFame.drawPortrait = function(state, tile_x, tile_y)
        local skin = selected_skin()
        if not skin or not skin.front then return original_draw_portrait(state, tile_x, tile_y) end

        local image = skin_image(skin.front)
        local colors = skin_base_palette(skin)
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
                    local original = gen2_original_defs[def]
                    if not original then return def end

local vanilla = shallow_copy(def)
                    vanilla.image = original.image
                    vanilla.trueColor = original.trueColor
                    return vanilla
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

local function create_overworld_renderer(game, kind, path, skin)
    local base = get_default_sprite_def(game, kind)
    if not base or not path then return nil end

local def = shallow_copy(base)

    def.image = mod.assets:path(path)
    def.trueColor = false
    def._trainerSkinId = skin and skin.id or nil

    local renderer = SpriteRenderer.new(def, "player")

    if is_gen2(game) then
        apply_gen2_palette(game, renderer, def)

        local colors = skin_base_palette(skin)
        if colors then
            renderer:setObjPalette(colors, skin_palette_group(skin, "trainer_skin_gen2_preview"))
        end
    end

    return renderer
end

    local function create_default_renderer(game, kind)
        local def = get_default_sprite_def(game, kind)
        if not def then return nil end

        local renderer = SpriteRenderer.new(def, "player")
        apply_gen2_palette(game, renderer, def)
        return renderer
    end

    local function apply_sprite(player, field, game, skin, skin_key, default_kind)
        local path = skin[skin_key]

        if path then
            player[field] = create_overworld_renderer(game, default_kind, path, skin)
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
            local def = world.sprites[entry.id]

            if def then
                if not gen2_original_defs[def] then
                    gen2_original_defs[def] = {
                        image = def.image,
                        trueColor = def.trueColor,
                        trainerSkinId = def._trainerSkinId
                    }
                end

                local original = gen2_original_defs[def]
                local path = skin[entry.key]

                if path then
                    def.image = mod.assets:path(path)
                    def.trueColor = false
                    def._trainerSkinId = skin.id
                else
                    def.image = original.image
                    def.trueColor = original.trueColor
                    def._trainerSkinId = original.trainerSkinId
                end
            end
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

local function equip_skin(game, skin)
    if not skin then return end

    mod.save:set("skin", skin.id)
    apply_overworld_skin(game, skin)
end

local function set_skin_color(game, color)
    if not SKIN_COLOR_INDEX[color] then return false end

    mod.save:set("skin_color", color)

    SpriteRenderer.invalidate()

    if game then
        apply_overworld_skin(game, selected_skin())
    end

    return true
end

local function cycle_skin_color(game, delta)
    local index = SKIN_COLOR_INDEX[selected_skin_color()] or 1
    index = (index - 1 + (delta or 1)) % #SKIN_COLOR_ORDER + 1
    return set_skin_color(game, SKIN_COLOR_ORDER[index])
end

    -- Battle, Trainer Card and Hall of Fame sprites
    mod.hooks:wrap("player.sprite", function(next, path, ctx)
        path = next(path, ctx)

        if ctx.demo then return path end

        local skin = selected_skin()
        if not skin then return path end

        if ctx.side == "front" and skin.front then
            ctx.trueColor = false
            return mod.assets:path(skin.front)
        end

        if ctx.side == "back" and skin.back then
            ctx.trueColor = false
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
    if live_game then
        apply_overworld_skin(live_game, selected_skin())
    end
end)

mod.events:on("world.tod_changed", function()
    if live_game and is_gen2(live_game) then
        apply_overworld_skin(live_game, selected_skin())
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
                walk_phase = 1
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

local _, equipped_index = selected_skin()
self.index = equipped_index
self.equipped_index = equipped_index
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
                    battle_colors = skin_base_palette(preview_skin) or battle_colors
                end

                zones[#zones + 1] = PaletteFX.zone(battle_colors, 12, 2, 18, 8)

                if PaletteFX.usesGbcPack() or PaletteFX.usesSpriteObp() then
                    zones[#zones + 1] = PaletteFX.trueColorZone(12, 11, 18, 12)
                    zones[#zones + 1] = PaletteFX.trueColorZone(12, 15, 18, 16)
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

            local function custom_or_default(path, kind)
                if not path then return default_preview_image(kind) end
                return skin_image(path)
            end

local function overworld_preview(kind, path, skin)
    local renderer = path
        and create_overworld_renderer(game, kind, path, skin)
        or create_default_renderer(game, kind)

    if not renderer then return nil end
    return renderer:resolveImage()
end

local function gen2_player_palette(custom, skin)
    if custom then
        local colors = skin_base_palette(skin)
        if colors then return colors end
    end

    if gen2_default_player_palette then
        return gen2_default_player_palette
    end

    local ok, TrainerCard = pcall(require, "src.ui.gen2.TrainerCard")
    if not ok or not TrainerCard then return nil end

    gen2_default_player_palette = TrainerCard.new(game):palette(1)
    return gen2_default_player_palette
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
                if preview_cache[skin.id] then return preview_cache[skin.id] end

local walk = overworld_preview("walk", skin.walk, skin)
local bike = overworld_preview("bike", skin.bike, skin)

                local preview = {
                    front = custom_or_default(skin.front, "front"),
                    back = custom_or_default(skin.back, "back"),
                    walk = walk,
                    bike = bike,
                    custom_front = skin.front ~= nil,
                    custom_back = skin.back ~= nil,
                }

                preview.walk_quads = create_walker_quads(preview.walk)
                preview.bike_quads = create_walker_quads(preview.bike)

                preview_cache[skin.id] = preview
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
                local colors = gen2_player_palette(custom, skin)

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
end

                self.preview_timer = self.preview_timer + dt

                if self.preview_timer >= 2 then
                    self.preview_timer = 0
                    self.show_back = not self.show_back
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
    if cycle_skin_color(game, -1) then
	    Sound.play(game.data, "Press_AB")
        preview_cache = {}
    end
end

if game.input:wasPressed("right") then
    if cycle_skin_color(game, 1) then
	    Sound.play(game.data, "Press_AB")
        preview_cache = {}
    end
end

if game.input:wasPressed("a") then
    equip_skin(game, skins[self.index])
    self.equipped_index = self.index
    Sound.play(game.data, "Press_AB")
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
Font.draw("SKINS", 18, 0)
Font.draw("COLORS", 112, 0)
love.graphics.setShader()

-- Left arrow
love.graphics.setColor(1, 1, 1, 1)
love.graphics.rectangle("fill", 101, 3, 1, 1)
love.graphics.rectangle("fill", 102, 2, 1, 3)
love.graphics.rectangle("fill", 103, 1, 1, 5)
love.graphics.rectangle("fill", 104, 0, 1, 7)

-- Right arrow
love.graphics.rectangle("fill", 106, 0, 1, 7)
love.graphics.rectangle("fill", 107, 1, 1, 5)
love.graphics.rectangle("fill", 108, 2, 1, 3)
love.graphics.rectangle("fill", 109, 3, 1, 1)

love.graphics.setColor(0, 0, 0, 1)

                -- UI boxes
                Font.drawBox(0, 1, 11, 17)
                Font.drawBox(11, 1, 9, 9)
                Font.drawBox(11, 10, 9, 4)
                Font.drawBox(11, 14, 9, 4)

                love.graphics.setColor(0, 0, 0, 1)

local first = self.scroll + 1
local last = math.min(#skins, self.scroll + SKIN_LIST_VISIBLE)

for i = first, last do
    local skin = skins[i]
    local row = i - first
    local y = 24 + row * 16

    Font.draw(skin.name, 16, y)

if i == self.equipped_index then
    draw_equipped_marker(9, gen2 and y or y + 1)
end

    if i == self.index then Font.drawCode(Theme.cursor, 8, y) end
end

if self.scroll + SKIN_LIST_VISIBLE < #skins then
    Font.drawCode(Theme.moreArrow, 72, 128)
end

                local skin = skins[self.index]
                local preview = load_preview(skin)

                love.graphics.setColor(1, 1, 1, 1)

                -- Battle front / back
                if self.show_back then
                    draw_battle_preview(preview.back, preview.custom_back)
                else
                    draw_battle_preview(preview.front, preview.custom_front)
                end

                -- Walk and bike previews
draw_direction_preview(preview.walk, preview.walk_quads, PREVIEW.walk_y)
draw_direction_preview(preview.bike, preview.bike_quads, PREVIEW.bike_y)
            end

            return self
        end
    })
end