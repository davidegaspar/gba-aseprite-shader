local dlg = nil
local originalImage = nil
local previewActive = false

function init(plugin)
    plugin:newCommand{
        id = "GBAShader",
        title = "GBA Shader",
        group = "edit_fx",
        onclick = function()
            showDialog()
        end
    }
end

function exit(plugin)
    if dlg then
        dlg:close()
    end
end

function showDialog()
    if dlg then
        dlg:close()
    end

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
        end
    }

    dlg:button{
        id = "cancel",
        text = "Cancel",
        onclick = function()
            if previewActive then
                restoreOriginal()
            end
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

    local image = cel.image:clone()
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
        b = b * 0.9
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
