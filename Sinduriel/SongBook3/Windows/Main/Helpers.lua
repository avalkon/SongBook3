-- Shared SongBook3 path, identity, and window helpers.
function SongBook3EnsureDirectories(db)
    local dirs = {};
    local seen = {};

    local function AddDirectory(path)
        if type(path) ~= "string" or path == "" then return; end
        path = string.gsub(path, "\\", "/");
        if string.sub(path, 1, 1) ~= "/" then path = "/" .. path; end
        local current = "/";
        if not seen[current] then
            dirs[#dirs + 1] = current;
            seen[current] = true;
        end
        for name in string.gmatch(path, "([^/]+)") do
            current = current .. name .. "/";
            if not seen[current] then
                dirs[#dirs + 1] = current;
                seen[current] = true;
            end
        end
    end

    AddDirectory("/");
    for _, path in ipairs(db.Directories or {}) do AddDirectory(path); end
    local entries = db.Songs or db.Lyrics or {};
    for _, song in ipairs(entries) do AddDirectory(song.Filepath); end
    table.sort(dirs, function(a, b) return string.lower(a) < string.lower(b); end);
    db.Directories = dirs;
end

-- Return a directory's name only when it is a direct child of parentPath.
-- Compare the entire path rather than searching for the final folder name:
-- e.g. /Folk/Folk/Reels/ must work even with repeated folder names.
function SongBook3ImmediateChild(parentPath, childPath)
    if type(childPath) ~= "string" or
       string.sub(childPath, 1, #parentPath) ~= parentPath then
        return nil;
    end
    local suffix = string.sub(childPath, #parentPath + 1);
    if suffix ~= "" and string.sub(suffix, -1) == "/" and
       string.find(suffix, "/", 1, true) == #suffix then
        return suffix;
    end
    return nil;
end
-- Stable identity for a song, independent of sort order, filtering and depth.
function SongBook3SongPath(song)
    if not song then return ""; end
    local path = (song.Filepath or "/") .. (song.Filename or "");
    path = string.gsub(path, "\\", "/");
    if string.sub(path, 1, 1) ~= "/" then path = "/" .. path; end
    return string.lower(path);
end

-- A lyric index mirrors Music/songs below Music/lyrics. Thus
-- /songs/5parts/reaper.abc maps to /5parts/reaper in SongBook3Lyrics.
function SongBook3NormalizeTitle(value)
    if type(value) ~= "string" then return ""; end
    value = string.lower(value);
    value = string.gsub(value, "^%s+", "");
    value = string.gsub(value, "%s+$", "");
    value = string.gsub(value, "%s+", " ");
    value = string.gsub(value, "%s*%(%d+:%d%d?%)$", "");
    return value;
end

function SongBook3EncodePath(path)
    -- Keep compatibility with older @SBL format: an optional suffix AFTER
    -- the old 12 fields, not a 13th delimited field.
    return (string.gsub(path or "", "[^%w%._/%-]", function(c)
        return string.format("%%%02X", string.byte(c));
    end));
end

function SongBook3DecodePath(path)
    return (string.gsub(path or "", "%%(%x%x)", function(hex)
        return string.char(tonumber(hex, 16));
    end));
end

-- Deterministic compact identity for long paths when LOTRO's chat-line
-- length would otherwise be exceeded. Filename + part count still verified.
function SongBook3PathHash(path)
    local h = 5381;
    for i = 1, #path do
        h = (h * 33 + string.byte(path, i)) % 4294967296;
    end
    return string.format("%08x", h);
end


function SongBook3AttachResizeGrip(window, minimumWidth, minimumHeight, reflow, onFinish)
    local grip = Turbine.UI.Control();
    grip:SetParent(window);
    grip:SetSize(20, 20);
    grip:SetZOrder(220);
    grip:SetMouseVisible(true);
    -- Keep the established auxiliary-window corner-resize behavior. The
    -- main-window splitter-style event-coordinate approach is not equivalent
    -- here because this grip is repositioned as the window changes size.
    local function PositionGrip()
        grip:SetPosition(window:GetWidth() - 20, window:GetHeight() - 20);
    end
    grip.MouseDown = function(sender, args)
        if args.Button ~= Turbine.UI.MouseButton.Left then return; end
        sender.dragging = true;
        sender.mouseX, sender.mouseY = Turbine.UI.Display.GetMousePosition();
        sender.startWidth, sender.startHeight = window:GetSize();
    end;
    grip.MouseMove = function(sender, args)
        if not sender.dragging then return; end
        local x, y = Turbine.UI.Display.GetMousePosition();
        local displayW, displayH = Turbine.UI.Display.GetSize();
        local maxWidth = math.max(minimumWidth, displayW - window:GetLeft());
        local maxHeight = math.max(minimumHeight, displayH - window:GetTop());
        local width = math.max(minimumWidth,
            math.min(maxWidth, sender.startWidth + x - sender.mouseX));
        local height = math.max(minimumHeight,
            math.min(maxHeight, sender.startHeight + y - sender.mouseY));
        window:SetSize(width, height);
        reflow();
        PositionGrip();
    end;
    grip.MouseUp = function(sender, args)
        if not sender.dragging then return; end
        sender.dragging = false;
        if onFinish then onFinish(); end
    end;
    -- Also handle programmatic changes (e.g. loading the saved size).
    window.SizeChanged = function()
        reflow();
        PositionGrip();
    end;
    PositionGrip();
    return grip;
end

-- The original window sizes are used for existing SongBook3 installations.
-- Storing only sizes avoids changing window positions or any existing keys.
function SongBook3SavedWindowSize(key, defaultWidth, defaultHeight, minimumWidth, minimumHeight)
    local values = Sinduriel.SongBook3.Windows.Main.Settings.SubWindowSizes and Sinduriel.SongBook3.Windows.Main.Settings.SubWindowSizes[key];
    local displayWidth, displayHeight = Turbine.UI.Display.GetSize();
    local width = values and tonumber(values.Width) or defaultWidth;
    local height = values and tonumber(values.Height) or defaultHeight;
    return math.max(minimumWidth, math.min(width, math.max(minimumWidth, displayWidth - 40))),
           math.max(minimumHeight, math.min(height, math.max(minimumHeight, displayHeight - 40)));
end

