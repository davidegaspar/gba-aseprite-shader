local dlg = nil
local originalImage = nil
local previewActive = false

function init(plugin)
    plugin:newMenuGroup{
        id = "gba_shader_menu",
        title = "GBA Shader",
        group = "edit_fx"
    }

    plugin:newMenuSeparator{
        group = "gba_shader_menu"
    }

    plugin:newCommand{
        id = "GBAColorEffects",
        title = "Color Effects",
        group = "gba_shader_menu",
        onclick = function()
            showDialog()
        end
    }

    plugin:newCommand{
        id = "GBAPixelGrid",
        title = "Pixel Grid",
        group = "gba_shader_menu",
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
    local gridDlg = Dialog("GBA Pixel Grid")

    gridDlg:separator{
        text = "6x Pixel Grid"
    }

    gridDlg:slider{
        id = "dimmingFactor",
        label = "Dimming:",
        min = 50,
        max = 100,
        value = 75
    }

    gridDlg:slider{
        id = "blendFactor",
        label = "Blend:",
        min = 25,
        max = 75,
        value = 25
    }

    gridDlg:slider{
        id = "saturation",
        label = "Saturation:",
        min = 70,
        max = 90,
        value = 80
    }

    gridDlg:slider{
        id = "blackLevel",
        label = "Black:",
        min = 5,
        max = 15,
        value = 10
    }

    gridDlg:slider{
        id = "whiteLevel",
        label = "White:",
        min = 75,
        max = 85,
        value = 80
    }

    gridDlg:check{
        id = "colorShift",
        label = "Color Shift",
        selected = true
    }

    gridDlg:separator()

    gridDlg:button{
        id = "apply",
        text = "Apply",
        onclick = function()
            local dimmingFactor = gridDlg.data.dimmingFactor / 100.0
            local blendFactor = gridDlg.data.blendFactor / 100.0
            applyPixelGrid(dimmingFactor, blendFactor, gridDlg.data)
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

function applyPixelGrid(dimmingFactor, blendFactor, data)
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
        app.alert("Pixel Grid only works with RGB images")
        return
    end

    apply6xPixelGrid(sprite, cel, image, dimmingFactor or 0.75, blendFactor or 0.5, data)
end

function apply6xPixelGrid(sprite, cel, image, dimmingFactor, blendFactor, data)
    local width = image.width
    local height = image.height

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

                -- Calculate dimmed values
                local rDimmed = math.floor(r * dimmingFactor)
                local gDimmed = math.floor(g * dimmingFactor)
                local bDimmed = math.floor(b * dimmingFactor)
                local rBlendDimmed = math.floor(rBlend * dimmingFactor)
                local gBlendDimmed = math.floor(gBlend * dimmingFactor)
                local bBlendDimmed = math.floor(bBlend * dimmingFactor)

                -- Dim the first row (top) using configurable dimming factor
                local dimmedB = app.pixelColor.rgba(rBlendDimmed, gBlendDimmed, bDimmed, a)
                local dimmedG = app.pixelColor.rgba(rBlendDimmed, gDimmed, bBlendDimmed, a)
                local dimmedR = app.pixelColor.rgba(rDimmed, gBlendDimmed, bBlendDimmed, a)

                newImage:putPixel(newX, newY, dimmedB)
                newImage:putPixel(newX + 1, newY, dimmedB)
                newImage:putPixel(newX + 2, newY, dimmedG)
                newImage:putPixel(newX + 3, newY, dimmedG)
                newImage:putPixel(newX + 4, newY, dimmedR)
                newImage:putPixel(newX + 5, newY, dimmedR)

                -- Dim the last row (bottom) using configurable dimming factor
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

function showDialog()
    if dlg then
        dlg:close()
    end

    -- Reset preview state when opening dialog
    previewActive = false
    originalImage = nil

    dlg = Dialog("GBA Aseprite Shader")

    dlg:separator{
        text = "GBA Screen Effects"
    }

    dlg:slider{
        id = "saturation",
        label = "Saturation:",
        min = 50,
        max = 70,
        value = 60,
        onchange = function()
            -- Round to nearest 10
            local value = dlg.data.saturation
            local rounded = math.floor((value + 5) / 10) * 10
            if value ~= rounded then
                dlg:modify{
                    id = "saturation",
                    value = rounded
                }
            end
            if previewActive then
                updatePreview()
            end
        end
    }

    dlg:slider{
        id = "blackLevel",
        label = "Black:",
        min = 5,
        max = 15,
        value = 10,
        onchange = function()
            -- Round to nearest 5
            local value = dlg.data.blackLevel
            local rounded = math.floor((value + 2.5) / 5) * 5
            if value ~= rounded then
                dlg:modify{
                    id = "blackLevel",
                    value = rounded
                }
            end
            if previewActive then
                updatePreview()
            end
        end
    }

    dlg:slider{
        id = "whiteLevel",
        label = "White:",
        min = 75,
        max = 85,
        value = 80,
        onchange = function()
            -- Round to nearest 5
            local value = dlg.data.whiteLevel
            local rounded = math.floor((value + 2.5) / 5) * 5
            if value ~= rounded then
                dlg:modify{
                    id = "whiteLevel",
                    value = rounded
                }
            end
            if previewActive then
                updatePreview()
            end
        end
    }

    dlg:check{
        id = "colorShift",
        label = "Color Shift",
        selected = true,
        onclick = function()
            if previewActive then
                updatePreview()
            end
        end
    }

    dlg:check{
        id = "preview",
        label = "Preview",
        selected = true,
        onclick = function()
            togglePreview()
        end
    }

    dlg:separator()

    dlg:button{
        id = "apply",
        text = "Apply",
        onclick = function()
            applyGBAShader()
            -- Cleanup after apply
            previewActive = false
            originalImage = nil
        end
    }

    dlg:button{
        id = "cancel",
        text = "Cancel",
        onclick = function()
            if previewActive then
                restoreOriginal()
            end
            -- Cleanup after cancel
            previewActive = false
            originalImage = nil
            dlg:close()
        end
    }

    dlg:show{
        wait = false
    }

    togglePreview()
end

function applyGBAShader()
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

    -- Use original image if preview is active, otherwise use current image
    local image = (previewActive and originalImage) and originalImage:clone() or cel.image:clone()
    local spec = image.spec

    if spec.colorMode ~= ColorMode.RGB then
        app.alert("GBA Shader only works with RGB images")
        return
    end

    local data = dlg.data

    app.transaction(function()
        for pixel in image:pixels() do
            local pixelValue = pixel()
            local r = app.pixelColor.rgbaR(pixelValue)
            local g = app.pixelColor.rgbaG(pixelValue)
            local b = app.pixelColor.rgbaB(pixelValue)
            local a = app.pixelColor.rgbaA(pixelValue)

            r, g, b = applyGBAEffects(r, g, b, data)

            pixel(app.pixelColor.rgba(r, g, b, a))
        end

        cel.image = image
    end)

    app.refresh()
    dlg:close()
end

function applyGBAEffects(r, g, b, data)
    r = r / 255.0
    g = g / 255.0
    b = b / 255.0

    local original_r = r
    local original_g = g
    local original_b = b

    -- colorShift
    if data.colorShift then

        -- shift red to green
        r = r * 0.8
        g = g + (original_r * 0.1)

        -- cyan: shift blue to green
        b = b * 0.75
        g = g + (original_b * 0.15)

        -- less vibrant green
        g = g * 0.8
    end

    -- desaturation
    local luma = 0.299 * r + 0.587 * g + 0.114 * b
    local saturation_factor = data.saturation / 100.0
    r = luma + (r - luma) * saturation_factor
    g = luma + (g - luma) * saturation_factor
    b = luma + (b - luma) * saturation_factor

    -- compress colors using black and white levels
    local blackLevel = data.blackLevel / 100.0
    local whiteLevel = data.whiteLevel / 100.0
    local range = whiteLevel - blackLevel
    r = blackLevel + (r * range)
    g = blackLevel + (g * range)
    b = blackLevel + (b * range)

    -- convert
    r = r * 255
    g = g * 255
    b = b * 255

    return math.floor(r), math.floor(g), math.floor(b)
end

function togglePreview()
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

    if dlg.data.preview then
        if not previewActive then
            originalImage = cel.image:clone()
            previewActive = true
            updatePreview()
        end
    else
        if previewActive then
            restoreOriginal()
        end
    end
end

function updatePreview()
    if not previewActive or not originalImage then
        return
    end

    local sprite = app.activeSprite
    local cel = app.activeCel

    if not sprite or not cel then
        return
    end

    if cel.image.spec.colorMode ~= ColorMode.RGB then
        return
    end

    local previewImage = originalImage:clone()
    local data = dlg.data

    app.transaction(function()
        for pixel in previewImage:pixels() do
            local pixelValue = pixel()
            local r = app.pixelColor.rgbaR(pixelValue)
            local g = app.pixelColor.rgbaG(pixelValue)
            local b = app.pixelColor.rgbaB(pixelValue)
            local a = app.pixelColor.rgbaA(pixelValue)

            r, g, b = applyGBAEffects(r, g, b, data)

            pixel(app.pixelColor.rgba(r, g, b, a))
        end

        cel.image = previewImage
    end)

    app.refresh()
end

function restoreOriginal()
    if not previewActive or not originalImage then
        return
    end

    local cel = app.activeCel
    if cel then
        app.transaction(function()
            cel.image = originalImage:clone()
        end)
        app.refresh()
    end

    previewActive = false
    originalImage = nil
end
