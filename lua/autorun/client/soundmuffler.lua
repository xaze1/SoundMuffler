local Sounds = {}
local soundsPerPage = 120
local currentPage = 1
local allSounds = sound.GetTable()
local filteredSounds = allSounds
local recentlyPlayed = {} -- track last heard time

-- Create the main frame once
local function CreateSoundMixer()
    local frame = vgui.Create("DFrame")
    frame:SetSize(900, 600)
    frame:SetSizable(true)
    frame:SetTitle("Sound Muffler")
    frame:Center()
    frame:SetVisible(false)
    frame:SetDeleteOnClose(false)
    function frame:OnClose()
        self:SetVisible(false)
    end

    function frame:Paint(w, h)
        draw.RoundedBox(5, 0, 0, w, h, Color(45, 45, 45, 200))
    end

    -- Filter Combo
    local filterCombo = vgui.Create("DComboBox", frame)
    filterCombo:Dock(TOP)
    filterCombo:SetValue("Index")
    filterCombo:AddChoice("Index")
    filterCombo:AddChoice("Recently played")

    -- Search box
    local searchBox = vgui.Create("DTextEntry", frame)
    searchBox:Dock(TOP)
    searchBox:SetPlaceholderText("Search sounds...")

    -- DListView
    local soundList = vgui.Create("DListView", frame)
    soundList:Dock(FILL)
    soundList:SetMultiSelect(false)
    soundList:AddColumn("Sound Name"):SetWidth(600)
    soundList:AddColumn("Muted"):SetWidth(80)
    soundList:AddColumn("Multiplier"):SetWidth(80)

    -- Pagination
    local bottomPanel = vgui.Create("DPanel", frame)
    bottomPanel:Dock(BOTTOM)
    bottomPanel:SetTall(30)
    bottomPanel:DockMargin(5, 5, 5, 5)

    local prevButton = vgui.Create("DButton", bottomPanel)
    prevButton:SetText("< Prev")
    prevButton:Dock(LEFT)
    prevButton:SetWide(70)

    local nextButton = vgui.Create("DButton", bottomPanel)
    nextButton:SetText("Next >")
    nextButton:Dock(RIGHT)
    nextButton:SetWide(70)

    local pageLabel = vgui.Create("DLabel", bottomPanel)
    pageLabel:Dock(FILL)
    pageLabel:SetContentAlignment(5)

    -- Refresh function
    local function RefreshSoundList()
        -- Filter by search
        local text = string.Trim(string.lower(searchBox:GetValue() or ""))
        filteredSounds = {}
        for _, sndName in ipairs(allSounds) do
            if text == "" or string.find(string.lower(sndName), text, 1, true) then
                table.insert(filteredSounds, sndName)
            end
        end

        -- Sort
        local filter = filterCombo:GetValue()
        if filter == "Recently played" then
            table.sort(filteredSounds, function(a, b)
                return (recentlyPlayed[a] or 0) > (recentlyPlayed[b] or 0)
            end)
        end
        -- "Index" just keeps the insertion order of `allSounds`

        -- Pagination
        soundList:Clear()
        local totalPages = math.max(1, math.ceil(#filteredSounds / soundsPerPage))
        currentPage = math.Clamp(currentPage, 1, totalPages)

        local startIndex = (currentPage - 1) * soundsPerPage + 1
        local endIndex = math.min(startIndex + soundsPerPage - 1, #filteredSounds)

        for i = startIndex, endIndex do
            local sndName = filteredSounds[i]
            local info = Sounds[sndName] or { mult = 1, muted = false }
            local line = soundList:AddLine(sndName, info.muted and "Yes" or "No", string.format("%.2f", info.mult))
            line.SoundName = sndName
            line.Muted = info.muted
            line.Mult = info.mult
        end

        pageLabel:SetText(string.format("Page %d / %d (%d total sounds)", currentPage, totalPages, #filteredSounds))
    end

    -- Search and filter hooks
    searchBox.OnChange = function()
        currentPage = 1
        RefreshSoundList()
    end

    filterCombo.OnSelect = function(_, index, value)
        currentPage = 1
        RefreshSoundList()
    end

    prevButton.DoClick = function()
        if currentPage > 1 then
            currentPage = currentPage - 1
            RefreshSoundList()
        end
    end

    nextButton.DoClick = function()
        if currentPage < math.ceil(#filteredSounds / soundsPerPage) then
            currentPage = currentPage + 1
            RefreshSoundList()
        end
    end

    -- Right-click menu
    function soundList:OnRowRightClick(_, line)
        if not IsValid(line) then return end
        local menu = DermaMenu()

        menu:AddOption(line.Muted and "Unmute" or "Mute", function()
            line.Muted = not line.Muted
            line:SetColumnText(2, line.Muted and "Yes" or "No")

            Sounds[line.SoundName] = Sounds[line.SoundName] or { mult = 1, muted = false }
            Sounds[line.SoundName].muted = line.Muted
            if not Sounds[line.SoundName].muted and Sounds[line.SoundName].mult == 1 then
                Sounds[line.SoundName] = nil
            end
        end)

        menu:AddOption("Set Volume Multiplier", function()
            local f = vgui.Create("DFrame")
            f:SetSize(300, 100)
            f:SetTitle("Volume - " .. line.SoundName)
            f:Center()
            f:MakePopup()

            local slider = vgui.Create("DNumSlider", f)
            slider:Dock(FILL)
            slider:SetText("Multiplier")
            slider:SetMin(0)
            slider:SetMax(2)
            slider:SetDecimals(2)
            slider:SetValue(line.Mult or 1)

            function slider:OnValueChanged(val)
                line.Mult = val
                line:SetColumnText(3, string.format("%.2f", val))
                Sounds[line.SoundName] = Sounds[line.SoundName] or { mult = 1, muted = false }
                Sounds[line.SoundName].mult = val
                if not Sounds[line.SoundName].muted and Sounds[line.SoundName].mult == 1 then
                    Sounds[line.SoundName] = nil
                end
            end
        end)

        local previewSound
        menu:AddOption("Play", function()
            -- Stop previous preview, if playing
            if previewSound then previewSound:Stop() end
            
            -- Create new preview
            previewSound = CreateSound(LocalPlayer(), line.SoundName)
            if not previewSound then return end

            previewSound:Play() -- Play preview

            -- Stop preview after 1s
            timer.Simple(1, function()
                if previewSound then previewSound:Stop() end
                previewSound = nil
            end)
        end)

        menu:Open()
    end

    return frame, RefreshSoundList
end

-- Create the frame once
hook.Add("InitPostEntity", "SoundMuffler_InitUI", function()
    if not IsValid(LocalPlayer()) or IsValid(soundMixer) then return end
    soundMixer, RefreshSoundList = CreateSoundMixer()
    
    print("[SoundMuffler] UI Initialized!")
end)

-- Track sounds
hook.Add("EntityEmitSound", "TrackAllSounds", function(data)
    local sndName = data.SoundName or data.FileName
    if not sndName or sndName == "" then return end

    -- Track the time it was last played
    recentlyPlayed[sndName] = CurTime()

    -- Add it to the list if not already there
    if not table.HasValue(allSounds, sndName) then
        table.insert(allSounds, sndName)
    end

    -- Apply your muted/multiplier logic
    local info = Sounds[sndName]
    if info then
        if info.muted then return false end
        data.Volume = math.Clamp(data.Volume * info.mult, 0, 1)
    end
end)

hook.Add("PlayerFootstep", "SoundMuffler_Footsteps", function(ply, pos, foot, soundName, volume, filter)
    if not soundName or soundName == "" then return end

    recentlyPlayed[soundName] = CurTime()

    if not table.HasValue(allSounds, soundName) then
        table.insert(allSounds, soundName)
    end

    local info = Sounds[soundName]
    if not info then return end

    if info.muted then
        return true -- Stop sound from playing
    end

    if info.mult and info.mult ~= 1 then
        ply:EmitSound(soundName, 75, 100, math.Clamp(volume * info.mult, 0, 1))
        return true -- Stop the original sound; our replacement plays with adjusted volume
    end
end)

-- Catch any SWEEP sounds
local entityMeta = FindMetaTable("Entity")
if entityMeta then
    local oldEmitSound = entityMeta.EmitSound
    function entityMeta:EmitSound(soundName, ...)
        recentlyPlayed[soundName] = CurTime()
        if not table.HasValue(allSounds, soundName) then
            table.insert(allSounds, soundName)
        end

        local info = Sounds[soundName]
        if info then
            if info.muted then return end
            local args = {...}
            if args[2] then args[2] = math.Clamp(args[2] * info.mult, 0, 1) end
            return oldEmitSound(self, soundName, unpack(args))
        end

        return oldEmitSound(self, soundName, ...)
    end
end

-- Catch UI and Menu sounds
local oldPlaySound = surface.PlaySound
function surface.PlaySound(soundName)
    recentlyPlayed[soundName] = CurTime()
    if not table.HasValue(allSounds, soundName) then
        table.insert(allSounds, soundName)
    end

    local info = Sounds[soundName]
    if info and info.muted then return end

    return oldPlaySound(soundName)
end

-- Toggle command
concommand.Add("soundmuffler", function()
    if not IsValid(soundMixer) then
        soundMixer, RefreshSoundList = CreateSoundMixer()
    end

    if soundMixer:IsVisible() then
        soundMixer:SetVisible(false)
    else
        soundMixer:SetVisible(true)
        soundMixer:MakePopup()
        soundMixer:MoveToFront()
        RefreshSoundList()
    end
end)

print("[SoundMuffler] Loaded successfully!")