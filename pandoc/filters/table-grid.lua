local utils = require("pandoc.utils")

local function has_special_chars(text)
    if text == nil then
        return false
    end

    -- 如果有 LaTeX 特殊字元，就不要用自訂 tabular，避免編譯錯誤
    return text:match("[\\%%$&#_^{}]") ~= nil
end

local function is_simple_table(tbl)
    if tbl == nil then
        return false
    end

    if tbl.bodies == nil or #tbl.bodies ~= 1 then
        return false
    end

    local body = tbl.bodies[1]

    if body.row_head_columns ~= nil and body.row_head_columns ~= 0 then
        return false
    end

    if tbl.foot ~= nil and tbl.foot.rows ~= nil and #tbl.foot.rows > 0 then
        return false
    end

    return true
end

local function cells_to_strings(cells)
    local result = {}

    for i = 1, #cells do
        local text = utils.stringify(cells[i])

        if has_special_chars(text) then
            return nil
        end

        table.insert(result, text)
    end

    return result
end

function Table(tbl)
    if FORMAT ~= "latex" and FORMAT ~= "beamer" then
        return nil
    end

    if not is_simple_table(tbl) then
        return nil
    end

    local head_rows = tbl.head.rows or {}
    local body_rows = tbl.bodies[1].rows or {}

    if #head_rows == 0 then
        return nil
    end

    local col_count = #head_rows[1].cells

    if col_count == 0 then
        return nil
    end

    local header_cells = cells_to_strings(head_rows[1].cells)

    if header_cells == nil then
        return nil
    end

    local rows = {}

    for i = 1, #body_rows do
        local row_cells = cells_to_strings(body_rows[i].cells)

        if row_cells == nil or #row_cells ~= col_count then
            return nil
        end

        table.insert(rows, row_cells)
    end

    local col_spec = {}

    for _ = 1, col_count do
        table.insert(col_spec, "|l")
    end

    table.insert(col_spec, "|")

    local lines = {}

    table.insert(lines, "\\begin{center}")
    table.insert(lines, "\\renewcommand{\\arraystretch}{1.25}")
    table.insert(lines, "\\setlength{\\tabcolsep}{6pt}")
    table.insert(lines, "\\begin{tabular}{" .. table.concat(col_spec, "") .. "}")
    table.insert(lines, "\\hline")
    table.insert(lines, table.concat(header_cells, " & ") .. " \\\\ \\hline")

    for i = 1, #rows do
        table.insert(lines, table.concat(rows[i], " & ") .. " \\\\ \\hline")
    end

    table.insert(lines, "\\end{tabular}")
    table.insert(lines, "\\end{center}")

    local code = table.concat(lines, "\n")

    return pandoc.RawBlock("latex", code)
end
