local utils = pandoc.utils

local function get_output_dir()
    local base_dir = os.getenv("MERMAID_OUTPUT_DIR")

    if base_dir == nil or base_dir == "" then
        return nil
    end

    base_dir = base_dir:gsub("[/\\]+$", "")
    base_dir = base_dir:gsub("/", "\\")
    return base_dir
end

local function run_mmdc(code, outfile)
    local function try_cmd(cmd, args)
        local ok, err = pcall(function()
            pandoc.pipe(cmd, args, code)
        end)

        return ok, err
    end

    local common_args = { "-i", "-", "-o", outfile, "-s", "4" }

    local envCmd = os.getenv("MMDCCMD")

    if envCmd ~= nil and envCmd ~= "" then
        local env_args = { "/c", envCmd }

        for _, v in ipairs(common_args) do
            table.insert(env_args, v)
        end

        local okEnv, errEnv = try_cmd("cmd", env_args)

        if okEnv then
            return true
        end

        io.stderr:write("mermaid html filter: MMDCCMD failed: " .. tostring(errEnv) .. "\n")
    end

    local appdata = os.getenv("APPDATA")

    if appdata ~= nil and appdata ~= "" then
        local candidate = appdata .. "\\npm\\mmdc.cmd"
        local mmdc_appdata_args = { "/c", candidate }

        for _, v in ipairs(common_args) do
            table.insert(mmdc_appdata_args, v)
        end

        local okApp, errApp = try_cmd("cmd", mmdc_appdata_args)

        if okApp then
            return true
        end

        io.stderr:write("mermaid html filter: APPDATA npm mmdc failed: " .. tostring(errApp) .. "\n")
    end

    local mmdc_args = { "/c", "mmdc" }

    for _, v in ipairs(common_args) do
        table.insert(mmdc_args, v)
    end

    local okMmdc, errMmdc = try_cmd("cmd", mmdc_args)

    if okMmdc then
        return true
    end

    io.stderr:write("mermaid html filter: cmd /c mmdc failed: " .. tostring(errMmdc) .. "\n")
    return false
end

local function mermaid(block)
    if FORMAT ~= "html" then
        return nil
    end

    if not block.classes:includes("mermaid") then
        return nil
    end

    local code = block.text or ""
    local hash = code

    if utils.sha1 ~= nil then
        hash = utils.sha1(code)
    end

    local base_dir = get_output_dir()
    local outfile = "output/tmp/mermaid-" .. hash .. ".svg"

    if base_dir ~= nil then
        outfile = base_dir .. "\\mermaid-" .. hash .. ".svg"
    end

    local ok = run_mmdc(code, outfile)

    if not ok then
        return block
    end

    local line_count = 1

    for _ in code:gmatch("\n") do
        line_count = line_count + 1
    end

    local is_large = line_count >= 28 or #code >= 1200

    if is_large then
        -- 讀取 SVG 內容並修改其寬高屬性
        local svg_file = io.open(outfile, "r")
        if svg_file then
            local svg_content = svg_file:read("*all")
            svg_file:close()
            
            -- 查找 <svg 標籤並在其中添加 height="100%"
            -- 使用更寬鬆的模式匹配，處理可能的換行和空白
            svg_content = svg_content:gsub('(<svg[^>]-)>()', function(svg_tag, pos)
                -- 如果已經有 height 屬性，不修改
                if svg_tag:match('height%s*=') then
                    return svg_tag .. '>'
                end
                -- 添加 height="100%"
                return svg_tag .. ' height="100%">'
            end, 1)
            
            -- 使用 RawBlock 直接嵌入 SVG
            local wrapper = pandoc.Div(
                { pandoc.RawBlock("html", '<div class="mermaid-fullpage-wrap"><p>' .. svg_content .. '</p></div>') },
                pandoc.Attr("")
            )
            return wrapper
        end
    end

    local img = pandoc.Image({ pandoc.Str("") }, outfile)
    img.attributes = img.attributes or {}
    img.classes = img.classes or {}
    table.insert(img.classes, "mermaid-diagram")

    local wrapper = pandoc.Div(
        { pandoc.Para({ img }) },
        pandoc.Attr("", { "mermaid-wrap" })
    )

    return wrapper
end

return {
    { CodeBlock = mermaid }
}
