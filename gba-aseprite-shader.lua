local dlg = nil

-- Constants
local PIXEL_SCALE = 6
local BGR_COLUMNS = {BLUE = {0, 1}, GREEN = {2, 3}, RED = {4, 5}}
local DIMMED_ROWS = {TOP = 0, BOTTOM = 5}

-- Validation functions
function validateSprite()
    local sprite = app.activeSprite
    if not sprite then
        app.alert("No active sprite")
        return nil
    end
    return sprite
end

function validateCel()
    local cel = app.activeCel
    if not cel then
        app.alert("No active cel")
        return nil
    end
    return cel
end

function sliderOnChange(dialog, sliderId, increment)
    return function()
        local value = dialog.data[sliderId]
        local rounded = math.floor((value + increment / 2) / increment) * increment
        if value ~= rounded then
            dialog:modify{
                id = sliderId,
                value = rounded
            }
        end
    end
end

function createColorChannels(r, g, b, blendFactor, a)
    -- Calculate blend values
    local rBlend = math.floor(r * blendFactor)
    local gBlend = math.floor(g * blendFactor)
    local bBlend = math.floor(b * blendFactor)

    -- Create BGR color channels with blending
    local blueColor = app.pixelColor.rgba(rBlend, gBlend, b, a)
    local greenColor = app.pixelColor.rgba(rBlend, g, bBlend, a)
    local redColor = app.pixelColor.rgba(r, gBlend, bBlend, a)

    return blueColor, greenColor, redColor, rBlend, gBlend, bBlend
end

function createDimmedColors(r, g, b, rBlend, gBlend, bBlend, rowDimming, a)
    local rDimmed = math.floor(r * rowDimming)
    local gDimmed = math.floor(g * rowDimming)
    local bDimmed = math.floor(b * rowDimming)
    local rBlendDimmed = math.floor(rBlend * rowDimming)
    local gBlendDimmed = math.floor(gBlend * rowDimming)
    local bBlendDimmed = math.floor(bBlend * rowDimming)

    local dimmedB = app.pixelColor.rgba(rBlendDimmed, gBlendDimmed, bDimmed, a)
    local dimmedG = app.pixelColor.rgba(rBlendDimmed, gDimmed, bBlendDimmed, a)
    local dimmedR = app.pixelColor.rgba(rDimmed, gBlendDimmed, bBlendDimmed, a)

    return dimmedB, dimmedG, dimmedR
end

function processPixel(x, y, image, scaledImage, pixelDimming, colorBlending, data)
    local pixelValue = image:getPixel(x, y)
    local r = app.pixelColor.rgbaR(pixelValue)
    local g = app.pixelColor.rgbaG(pixelValue)
    local b = app.pixelColor.rgbaB(pixelValue)
    local a = app.pixelColor.rgbaA(pixelValue)

    -- Apply GBA color effects if data is provided
    if data then
        r, g, b = applyGBAEffects(r, g, b, data)
    end

    -- Calculate pixel position in scaled image
    local pixelX = x * PIXEL_SCALE
    local pixelY = y * PIXEL_SCALE

    -- Create BGR color channels
    local blueColor, greenColor, redColor, rBlend, gBlend, bBlend = createColorChannels(r, g, b, colorBlending, a)

    -- Draw the 6x6 pixel grid (BGR layout)
    for row = 0, PIXEL_SCALE - 1 do
        -- Blue columns (left 2)
        scaledImage:putPixel(pixelX + BGR_COLUMNS.BLUE[1], pixelY + row, blueColor)
        scaledImage:putPixel(pixelX + BGR_COLUMNS.BLUE[2], pixelY + row, blueColor)
        -- Green columns (middle 2)
        scaledImage:putPixel(pixelX + BGR_COLUMNS.GREEN[1], pixelY + row, greenColor)
        scaledImage:putPixel(pixelX + BGR_COLUMNS.GREEN[2], pixelY + row, greenColor)
        -- Red columns (right 2)
        scaledImage:putPixel(pixelX + BGR_COLUMNS.RED[1], pixelY + row, redColor)
        scaledImage:putPixel(pixelX + BGR_COLUMNS.RED[2], pixelY + row, redColor)
    end

    -- Apply dimming to top and bottom rows
    local dimmedB, dimmedG, dimmedR = createDimmedColors(r, g, b, rBlend, gBlend, bBlend, pixelDimming, a)
    
    -- Top row (dimmed)
    scaledImage:putPixel(pixelX + BGR_COLUMNS.BLUE[1], pixelY + DIMMED_ROWS.TOP, dimmedB)
    scaledImage:putPixel(pixelX + BGR_COLUMNS.BLUE[2], pixelY + DIMMED_ROWS.TOP, dimmedB)
    scaledImage:putPixel(pixelX + BGR_COLUMNS.GREEN[1], pixelY + DIMMED_ROWS.TOP, dimmedG)
    scaledImage:putPixel(pixelX + BGR_COLUMNS.GREEN[2], pixelY + DIMMED_ROWS.TOP, dimmedG)
    scaledImage:putPixel(pixelX + BGR_COLUMNS.RED[1], pixelY + DIMMED_ROWS.TOP, dimmedR)
    scaledImage:putPixel(pixelX + BGR_COLUMNS.RED[2], pixelY + DIMMED_ROWS.TOP, dimmedR)

    -- Bottom row (dimmed)
    scaledImage:putPixel(pixelX + BGR_COLUMNS.BLUE[1], pixelY + DIMMED_ROWS.BOTTOM, dimmedB)
    scaledImage:putPixel(pixelX + BGR_COLUMNS.BLUE[2], pixelY + DIMMED_ROWS.BOTTOM, dimmedB)
    scaledImage:putPixel(pixelX + BGR_COLUMNS.GREEN[1], pixelY + DIMMED_ROWS.BOTTOM, dimmedG)
    scaledImage:putPixel(pixelX + BGR_COLUMNS.GREEN[2], pixelY + DIMMED_ROWS.BOTTOM, dimmedG)
    scaledImage:putPixel(pixelX + BGR_COLUMNS.RED[1], pixelY + DIMMED_ROWS.BOTTOM, dimmedR)
    scaledImage:putPixel(pixelX + BGR_COLUMNS.RED[2], pixelY + DIMMED_ROWS.BOTTOM, dimmedR)
end

function init(plugin)
    plugin:newCommand{
        id = "GBAShader",
        title = "GBA Shader",
        group = "edit_fx",
        onclick = function()
            showPixelGridDialog()
        end
    }
end

function exit(plugin)
    if dlg then
        dlg:close()
    end
    -- Cleanup on plugin exit
end

function showPixelGridDialog()
    local gridDlg = Dialog("GBA Shader")

    gridDlg:separator{
        text = " Colour "
    }

    gridDlg:slider{
        id = "saturation",
        label = "Saturation:",
        min = 70,
        max = 90,
        value = 80,
        onchange = sliderOnChange(gridDlg, "saturation", 5)
    }

    gridDlg:slider{
        id = "minBrightness",
        label = "Min brightness:",
        min = 5,
        max = 15,
        value = 10,
        onchange = sliderOnChange(gridDlg, "minBrightness", 5)
    }

    gridDlg:slider{
        id = "maxBrightness",
        label = "Max brightness:",
        min = 85,
        max = 95,
        value = 90,
        onchange = sliderOnChange(gridDlg, "maxBrightness", 5)
    }

    gridDlg:check{
        id = "colorShift",
        label = "Color match",
        selected = true
    }
    gridDlg:label{
        text = "Better match the original screen colors"
    }

    gridDlg:separator{
        text = " Pixels "
    }

    gridDlg:slider{
        id = "rowSeparation",
        label = "Row separation:",
        min = 0,
        max = 50,
        value = 25,
        onchange = sliderOnChange(gridDlg, "rowSeparation", 5)
    }
    gridDlg:label{
        text = "Darkens the row separation"
    }

    gridDlg:slider{
        id = "blendFactor",
        label = "Blend:",
        min = 50,
        max = 100,
        value = 75,
        onchange = sliderOnChange(gridDlg, "blendFactor", 5)
    }
    gridDlg:label{
        text = "Blends adjacent RGB colors together"
    }

    gridDlg:separator()

    gridDlg:label{
        text = " Note: The Image will be scaled to 6x size to simulate real pixels "
    }

    gridDlg:button{
        id = "apply",
        text = "Apply",
        onclick = function()
            applyPixelGrid(gridDlg.data)
            gridDlg:close()
        end
    }

    gridDlg:button{
        id = "cancel",
        text = "Cancel",
        onclick = function()
            gridDlg:close()
        end
    }

    gridDlg:show{
        wait = false
    }
end

function applyPixelGrid(data)
    local sprite = validateSprite()
    if not sprite then return end
    
    local cel = validateCel()
    if not cel then return end

    local image = cel.image
    local spec = image.spec

    if spec.colorMode ~= ColorMode.RGB then
        app.command.ChangePixelFormat {
            format = "rgb"
        }
        image = cel.image
        spec = image.spec
    end

    apply6xPixelGrid(sprite, cel, image, data)
end

function apply6xPixelGrid(sprite, cel, image, data)
    local originalWidth = image.width
    local originalHeight = image.height

    -- Convert UI percentages to working values
    local pixelDimming = (100 - data.rowSeparation) / 100.0
    local colorBlending = data.blendFactor / 100.0

    -- Create scaled output sprite
    local scaledSprite = Sprite(originalWidth * PIXEL_SCALE, originalHeight * PIXEL_SCALE, image.spec.colorMode)
    local scaledImage = scaledSprite.cels[1].image

    -- Set the filename to match the original sprite's path
    if sprite.filename then
        local path = sprite.filename
        local dir = path:match("(.*/)")
        local name = path:match("([^/]+)%.[^%.]+$")
        local ext = path:match("%.([^%.]+)$")
        if dir and name and ext then
            scaledSprite.filename = dir .. name .. "_6x." .. ext
        end
    end

    -- Process each pixel in the original image
    app.transaction(function()
        for y = 0, originalHeight - 1 do
            for x = 0, originalWidth - 1 do
                processPixel(x, y, image, scaledImage, pixelDimming, colorBlending, data)
            end
        end
    end)

    app.refresh()
end

function applyGBAEffects(r, g, b, data)
    local original_r = r
    local original_g = g
    local original_b = b

    -- colorShift
    if data.colorShift then
        -- shift red to green
        r = r * 0.8
        g = g + (original_r * 0.1)

        -- cyan: shift blue to green
        b = b * 0.8
        g = g + (original_b * 0.1)

        -- less vibrant green
        g = g * 0.8
    end

    -- desaturation
    local luma = 0.299 * r + 0.587 * g + 0.114 * b
    local saturation_factor = data.saturation / 100.0
    r = luma + (r - luma) * saturation_factor
    g = luma + (g - luma) * saturation_factor
    b = luma + (b - luma) * saturation_factor

    -- compress colors using brightness levels
    local minBrightness = (data.minBrightness / 100.0) * 255
    local maxBrightness = (data.maxBrightness / 100.0) * 255
    local range = maxBrightness - minBrightness
    r = minBrightness + (r * range / 255)
    g = minBrightness + (g * range / 255)
    b = minBrightness + (b * range / 255)

    return math.floor(r), math.floor(g), math.floor(b)
end
