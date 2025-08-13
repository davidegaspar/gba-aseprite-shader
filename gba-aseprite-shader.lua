local dlg = nil
local originalImage = nil
local previewActive = false

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
    previewActive = false
    originalImage = nil
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
    local sprite = app.activeSprite
    if not sprite then
        app.alert("No active sprite")
        return
    end

    local cel = app.activeCel
    if not cel then
        app.alert("No active cel")
        return
    end

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
    local width = image.width
    local height = image.height

    -- Extract values from data
    local rowDimming = (100 - data.rowSeparation) / 100.0
    local blendFactor = data.blendFactor / 100.0

    -- Create new sprite with 6x width and height
    local newSprite = Sprite(width * 6, height * 6, image.spec.colorMode)
    local newImage = newSprite.cels[1].image

    -- Set the filename to match the original sprite's path
    if sprite.filename then
        local path = sprite.filename
        local dir = path:match("(.*/)")
        local name = path:match("([^/]+)%.[^%.]+$")
        local ext = path:match("%.([^%.]+)$")
        if dir and name and ext then
            newSprite.filename = dir .. name .. "_6x." .. ext
        end
    end

    app.transaction(function()
        for y = 0, height - 1 do
            for x = 0, width - 1 do
                local pixelValue = image:getPixel(x, y)
                local r = app.pixelColor.rgbaR(pixelValue)
                local g = app.pixelColor.rgbaG(pixelValue)
                local b = app.pixelColor.rgbaB(pixelValue)
                local a = app.pixelColor.rgbaA(pixelValue)

                -- Apply GBA effects if data is provided
                if data then
                    r, g, b = applyGBAEffects(r, g, b, data)
                end

                -- Create 6x6 grid for this pixel
                local newX = x * 6
                local newY = y * 6

                -- Calculate blend values
                local rBlend = math.floor(r * blendFactor)
                local gBlend = math.floor(g * blendFactor)
                local bBlend = math.floor(b * blendFactor)

                -- Blue vertical bars (left 2 columns) - blend with red and green
                local blueColor = app.pixelColor.rgba(rBlend, gBlend, b, a)
                for row = 0, 5 do
                    newImage:putPixel(newX, newY + row, blueColor)
                    newImage:putPixel(newX + 1, newY + row, blueColor)
                end

                -- Green vertical bars (middle 2 columns) - blend with blue and red
                local greenColor = app.pixelColor.rgba(rBlend, g, bBlend, a)
                for row = 0, 5 do
                    newImage:putPixel(newX + 2, newY + row, greenColor)
                    newImage:putPixel(newX + 3, newY + row, greenColor)
                end

                -- Red vertical bars (right 2 columns) - blend with blue and green
                local redColor = app.pixelColor.rgba(r, gBlend, bBlend, a)
                for row = 0, 5 do
                    newImage:putPixel(newX + 4, newY + row, redColor)
                    newImage:putPixel(newX + 5, newY + row, redColor)
                end

                -- Create dimmed colors for first and last rows
                local dimmedB, dimmedG, dimmedR = createDimmedColors(r, g, b, rBlend, gBlend, bBlend, rowDimming, a)

                newImage:putPixel(newX, newY, dimmedB)
                newImage:putPixel(newX + 1, newY, dimmedB)
                newImage:putPixel(newX + 2, newY, dimmedG)
                newImage:putPixel(newX + 3, newY, dimmedG)
                newImage:putPixel(newX + 4, newY, dimmedR)
                newImage:putPixel(newX + 5, newY, dimmedR)

                newImage:putPixel(newX, newY + 5, dimmedB)
                newImage:putPixel(newX + 1, newY + 5, dimmedB)
                newImage:putPixel(newX + 2, newY + 5, dimmedG)
                newImage:putPixel(newX + 3, newY + 5, dimmedG)
                newImage:putPixel(newX + 4, newY + 5, dimmedR)
                newImage:putPixel(newX + 5, newY + 5, dimmedR)
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
