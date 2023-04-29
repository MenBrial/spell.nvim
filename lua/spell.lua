--------------------------------------------------------------------------------
-- Spell suggestion module
--------------------------------------------------------------------------------
local M = {}

local config = {
}

local default_config = {
    -- Replace `z=` mapping
    default_mapping = true,
    -- Suggest spelling only for current word.
    current_word_only = false,
    -- Number of spelling suggestions.
    spelling_suggestions = 20,
    -- Floating window margins.
    margin = 2,
    -- Separation between columns.
    gutter = 2,
    -- Keys for suggestions.
    keys = '1234567890abcdefghijklmnopqrstuvwxyz'

}

local spell_suggest = function()
    -- Retrieve the current word.
    local cword = vim.fn.expand('<cword>')
    -- Retrieve the badly spelled word.
    local bad_word, spelling_error = unpack(vim.fn.spellbadword())

    -- Use bad word if not empty, depending on `current_word_only` value.
    if bad_word == '' or (bad_word ~= cword and config.current_word_only) then
        return
    end

    -- Find suggestions.
    local suggestions
    if spelling_error == 'caps' then
        suggestions = {
            string.upper(string.sub(bad_word, 1, 1)) .. string.sub(bad_word, 2, -1),
            bad_word,
        }
    else
       suggestions = vim.fn.spellsuggest(bad_word, config.spelling_suggestions)
    end

    -- Compute floating window dimensions.
    -- Window size.
    local margin = config.margin
    local win_height = vim.fn.winheight(0)
    local win_width = vim.fn.winwidth(0)
    -- Remove margin and border.
    win_width = win_width - margin - margin - 2

    -- Maximum suggestion length.
    local max_len = 0
    for _, suggestion in ipairs(suggestions) do
        local l = vim.fn.strdisplaywidth(suggestion)
        if l > max_len then
            max_len = l
        end
    end
    -- Add key length.
    max_len = max_len + 4

    -- Number of columns.
    local gutter = config.gutter
    local columns = math.floor((win_width + gutter) / (max_len + gutter))

    -- Create floating window content.
    local lines = {}
    local ranges = {}
    local line = ''
    local keys = config.keys
    local column = 0
    local row = 0
    for i, suggestion in ipairs(suggestions) do
        local key = string.sub(keys, i, i)
        local current = string.format('%1s → %s', key, suggestion)
        local gap = max_len - vim.fn.strdisplaywidth(current)
        if line ~= '' then
            line = line .. string.rep(' ', gutter)
        end
        line = line .. current .. string.rep(' ', gap)
        table.insert(ranges, {{ row, column }, { row, column + 2 }})
        column = column + #current + gap + gutter
        if i % columns == 0 then
            row = row + 1
            column = 0
            table.insert(lines, line)
            line = ''
        end
    end
    table.insert(lines, line)

    -- Create buffer.
    local ns_id = vim.api.nvim_create_namespace('spell_suggest')
    local buf = vim.api.nvim_create_buf(false, true)
    vim.api.nvim_buf_set_lines(buf, 0, -1, true, lines)
    vim.bo[buf].filetype = 'Spell'
    vim.bo[buf].bufhidden = 'wipe'
    for _, range in ipairs(ranges) do
        local start, finish = unpack(range)
        vim.highlight.range(buf, ns_id, 'Special', start, finish, {})
    end

    -- Create floating window.
    local win_opts = {
        relative = 'win',
        anchor = 'SW',
        row = win_height,
        col = margin,
        width = win_width,
        height = #lines,
        noautocmd = true,
        style = 'minimal',
        border = 'rounded',
    }
    local win = vim.api.nvim_open_win(buf, 0, win_opts)

    -- Function for applying spelling correction.
    local correct = function(correction)
        -- vim.cmd(':norm "<c-g>uciw' .. correction .. '<Esc><c-g>u"')
        vim.api.nvim_feedkeys('ciw' .. correction ..
            vim.api.nvim_replace_termcodes( '<Esc>', true, false, true),
            'n', false)
    end

    -- Keymaps for selecting suggestion.
    for i, suggestion in ipairs(suggestions) do
        local key = string.sub(keys, i, i)
        vim.keymap.set('n', string.format('%s', key), function()
                vim.api.nvim_win_close(win, true)
                correct(suggestion)
            end, {
                desc = 'Select spelling suggestion',
                buffer = buf,
                nowait = true,
                silent = true,
        })
    end
    vim.keymap.set('n', '<esc>', function()
            vim.api.nvim_win_close(win, true)
        end, {
            desc = 'Close spelling suggestion',
            buffer = buf,
            nowait = true,
            silent = true,
    })
    vim.api.nvim_create_autocmd({
        'BufLeave',
    }, {
        buffer = buf,
        callback = function()
            vim.api.nvim_win_close(win, true)
        end,
    })
end

M.spell_suggest = spell_suggest

M.setup = function(opts)
    config = vim.tbl_deep_extend('force', default_config, opts or {})
    if config.default_mapping then
        vim.keymap.set('n', 'z=', spell_suggest, {
            desc = 'Suggest spelling correction',
            silent = true,
        })
    end
end

return M
