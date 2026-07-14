require "themed_miniwindows"
require "movewindow"
require "gmcphelper"
require "tprint"
dofile(GetInfo(60) .. "telnet_options.lua")
dofile(GetInfo(60) .. "aardwolf_colors.lua")
local blank_gag_available = pcall(require, "gag_next_blank_line")

-- ===== Globals / State =====
local win = "gqdashboard_" .. GetPluginID()
local qgsound = "global_quest.wav"
local plugin_id_z_order = "462b665ecb569efbf261422f"
local min_window_width = 330
local min_window_height = 60
local load_nonce = tostring(GetUniqueNumber())

GQ_table = GQ_table or {}
gqhistory = gqhistory or {}
local valid_range = false

local function saved_boolean(name, default)
  local value = GetVariable(name)
  if value == "1" then return true end
  if value == "0" then return false end
  return default
end

-- User preferences persist; active GQs and captured command output do not.
sound_on = saved_boolean("gq_sound_on", true)
auto_toggle = saved_boolean("gq_auto_hide", false)
toggle25 = saved_boolean("gq_filter_under25", false)
toggle200 = saved_boolean("gq_filter_25to199", false)
toggle201 = saved_boolean("gq_filter_200plus", true)

local function save_preferences()
  SetVariable("gq_sound_on", sound_on and "1" or "0")
  SetVariable("gq_auto_hide", auto_toggle and "1" or "0")
  SetVariable("gq_filter_under25", toggle25 and "1" or "0")
  SetVariable("gq_filter_25to199", toggle200 and "1" or "0")
  SetVariable("gq_filter_200plus", toggle201 and "1" or "0")
end

local function menu_check(label, enabled)
  return (enabled and "+" or "") .. label
end

local function build_menu_string()
  return "!" .. menu_check("Sound", sound_on)
    .. "|" .. menu_check("Auto Hide", auto_toggle)
    .. "|>Threshold"
    .. "|" .. menu_check("24 Wins or Fewer", toggle25)
    .. "|" .. menu_check("25 to 199 Wins", toggle200)
    .. "|" .. menu_check("200 Wins or More", toggle201)
    .. "|<|-|Bring to Front|Send to Back"
end

-- GMCP info
local char_state = {3, 4, 8, 9, 11, 12}
local cached_status_level = tonumber(gmcp("char.status.level"))
local prior_level = tonumber(level)
local level = prior_level or cached_status_level or 1
local current_level_known = prior_level ~= nil or cached_status_level ~= nil
local gmcp_state = nil
local plugin_enabled = true
local connected = true
local lifecycle_epoch = 0
local window_should_be_visible = true

-- GQ list requests and their staged response. A partial response never
-- replaces the last complete table.
local gq_capture = nil
local gq_capture_serial = 0
local gq_request_pending = false

-- The server's current GQ-cycle schedule. Only the last fully validated
-- 50-row snapshot is published; in-flight and failed candidates stay private.
local ranges_snapshot = nil
local ranges_capture = nil
local ranges_capture_serial = 0
local ranges_timeout_generation = 0
local ranges_status = "idle"
local ranges_last_error = nil
local ranges_refresh_pending = nil
local ranges_seen_gq_ids = {}

-- Fenced commands are serialized. Preserve the user's original quiet-mode
-- settings across a back-to-back ranges/swho sequence even if GMCP has not yet
-- broadcast the restoration from the preceding command.
local fence_quiet_baseline = nil

-- Competition snapshots are intentionally memory-only. Each visible, level-
-- eligible GQ is scanned once while it remains in the list.
local competition_scans = {}
local swho_queue = {}
local swho_active = nil
local swho_serial = 0
local swho_pump_scheduled = false
local suppress_competition_scan = false
local draw_gq_window
local create_window
local request_gq_list
local request_gquest_ranges
local schedule_swho_pump
local finish_swho_capture
local finish_ranges_capture

local function gq_tier(type_text)
  local normalized = tostring(type_text or ""):lower():match("^%s*(.-)%s*$")
  if normalized:match("^less%s+than%s+25%s+wins") then return "under25" end
  if normalized:match("^25%s+to%s+199%s+wins") then return "25to199" end
  if normalized:match("^200%s+wins%s+or%s+more") then return "200plus" end
  return nil
end

local function parse_gq_row(text)
  -- Aardwolf can append "***" after Players on Preparing rows. It is a
  -- server-side GQ marker, not another column, so remove only that suffix.
  local row_text = tostring(text or ""):gsub("%s+%*%*%*%s*$", "")
  local id, type_text, from, to, status, timer, players = row_text:match(
    "^%s*(%d+)%s+(.-)%s+(%d+)%s+(%d+)%s+(.-)%s+(%d+)%s+(%d+)%s*$"
  )
  if not id then return nil end
  return {
    id = id,
    tier = gq_tier(type_text),
    type_text = type_text,
    from = tonumber(from),
    to = tonumber(to),
    status = status,
    timer = tonumber(timer),
    players = tonumber(players),
  }
end

local function compact_tier_label(gq)
  if gq.tier == "under25" then return "<25" end
  if gq.tier == "25to199" then return "25-199" end
  if gq.tier == "200plus" then return "200+" end
  return string.sub(tostring(gq.type_text or "Unknown"), 1, 6)
end

local table_left = 5
local table_columns = { "num", "tier", "levels", "status", "timer", "players", "cycle" }
local table_headers = {
  num = "Num",
  tier = "Tier",
  levels = "Levels",
  status = "Status",
  timer = "Tmr",
  players = "Plyrs",
  cycle = "Cycle",
}
local current_table_layout = nil
local cycle_display_colour
local table_font = "f1"
local cycle_boundary_font = "f1b"

local function content_right_edge()
  local resize_reserve = tonumber(Theme and Theme.RESIZER_SIZE) or 16
  local body_right = tonumber(my_window and my_window.bodyright)
                     or ((tonumber(WindowInfo(win, 3)) or 480) - 3)
  return math.max(table_left + #table_columns, body_right - resize_reserve)
end

local function measured_text_width(text, font)
  return math.max(0, tonumber(WindowTextWidth(
    win, font or table_font, tostring(text or "")
  )) or 0)
end

local function build_table_layout()
  local right = content_right_edge()
  -- Cell right edges are exclusive for centering; hotspots use the pixel just
  -- before the next cell. These samples define the tight 330-pixel layout.
  local unit = math.max(1, measured_text_width("0"))
  local base = {
    num = measured_text_width("0000"),
    tier = measured_text_width("25-199"),
    levels = measured_text_width("201-201"),
    status = measured_text_width("Active"),
    timer = measured_text_width("Tmr") + unit,
    players = measured_text_width("100(...)"),
    cycle = measured_text_width("00(-14,-14,-14)"),
  }

  local available = math.max(#table_columns, right - table_left)
  local base_total = 0
  for _, key in ipairs(table_columns) do base_total = base_total + base[key] end

  local widths = {}
  if available >= base_total then
    local extra = available - base_total
    local each = math.floor(extra / #table_columns)
    local remainder = extra % #table_columns
    for index, key in ipairs(table_columns) do
      widths[key] = base[key] + each + (index <= remainder and 1 or 0)
    end

    -- At wider sizes, make the requested one-character move by transferring up
    -- to one measured character of Cycle's expansion into the Tmr cell.
    local players_nudge = math.min(unit, math.max(0, widths.cycle - base.cycle))
    widths.timer = widths.timer + players_nudge
    widths.cycle = widths.cycle - players_nudge
  else
    -- Defensive fallback for an unexpectedly wide font: preserve nonoverlap
    -- even if some text must be clipped inside the configured minimum window.
    local remaining = available
    for index, key in ipairs(table_columns) do
      if index == #table_columns then
        widths[key] = remaining
      else
        widths[key] = math.max(1, math.floor(base[key] * available / base_total))
        remaining = remaining - widths[key]
      end
    end
  end

  local cells = {}
  local x = table_left
  for _, key in ipairs(table_columns) do
    cells[key] = { left = x, right = x + widths[key] }
    x = cells[key].right
  end
  cells.cycle.right = right

  return {
    left = table_left,
    right = right,
    cells = cells,
  }
end

local function draw_cell_text(layout, key, text, y, colour)
  local cell = layout.cells[key]
  text = tostring(text or "")
  local text_width = measured_text_width(text)
  local x = cell.left + math.max(0, math.floor(((cell.right - cell.left) - text_width) / 2))
  WindowText(win, table_font, text, x, y, cell.right, y + 12, colour, false)
  return x
end

local function draw_table_header(layout)
  local colour = ColourNameToRGB("white")
  for _, key in ipairs(table_columns) do
    draw_cell_text(layout, key, table_headers[key], 20, colour)
  end
  WindowLine(win, layout.left, 39, layout.right, 39,
             ColourNameToRGB("silver"), miniwin.pen_solid or 0, 1)
end

local function compact_status_label(status)
  local text = tostring(status or "")
  local normalized = text:lower():gsub("^%s+", ""):gsub("%s+$", "")
  if normalized == "preparing" then return "Prep" end
  if normalized == "extended" then return "Ext" end
  if normalized == "no active" then return "NA" end
  return string.sub(text, 1, 6)
end

local function draw_table_row(layout, row, players_text, y, row_colour)
  local values = {
    num = tostring(row.id or "-"),
    tier = compact_tier_label(row),
    levels = tostring(row.levels or "-"),
    status = compact_status_label(row.status),
    timer = tostring(row.timer or "-"),
    players = tostring(players_text or "-"),
  }
  for _, key in ipairs({ "num", "tier", "levels", "status", "timer", "players" }) do
    draw_cell_text(layout, key, values[key], y, row_colour)
  end
end

local function wins_match_tier(wins, tier)
  if tier == "under25" then return wins < 25 end
  if tier == "25to199" then return wins >= 25 and wins <= 199 end
  if tier == "200plus" then return wins >= 200 end
  return false
end

local function tier_description(tier)
  if tier == "under25" then return "fewer than 25 GQ wins" end
  if tier == "25to199" then return "25 to 199 GQ wins" end
  if tier == "200plus" then return "200 or more GQ wins" end
  return "the selected GQ tier"
end

local function tier_enabled(tier)
  if tier == "under25" then return toggle25 end
  if tier == "25to199" then return toggle200 end
  if tier == "200plus" then return toggle201 end
  return true
end

local tier_order = { "under25", "25to199", "200plus" }

local function parse_yes_no(value)
  local normalized = tostring(value or ""):lower()
  if normalized == "yes" then return true end
  if normalized == "no" then return false end
  return nil
end

local function parse_ranges_row(line)
  local from, to, under25, middle, plus200 = tostring(line or ""):match(
    "^%s*(%d+)%s+(%d+)%s+(%a+)%s+(%a+)%s+(%a+)%s*$"
  )
  if not from then return nil end
  local done_under25 = parse_yes_no(under25)
  local done_middle = parse_yes_no(middle)
  local done_plus200 = parse_yes_no(plus200)
  if done_under25 == nil or done_middle == nil or done_plus200 == nil then return nil end
  return {
    from = tonumber(from),
    to = tonumber(to),
    done = {
      under25 = done_under25,
      ["25to199"] = done_middle,
      ["200plus"] = done_plus200,
    },
  }
end

local function percent_hundredths(value)
  local whole, fraction = tostring(value or ""):match("^(%d+)%.(%d%d)$")
  if not whole then return nil end
  return tonumber(whole) * 100 + tonumber(fraction)
end

local function validate_ranges_candidate(candidate)
  if not candidate.saw_header_one or not candidate.saw_header_two then
    return nil, "missing ranges header"
  end
  if not candidate.saw_top_separator then return nil, "missing ranges top separator" end
  if (candidate.group_separator_count or 0) ~= 9 then
    return nil, "expected 9 range group separators"
  end
  if not candidate.saw_footer_separator then return nil, "missing ranges footer separator" end
  if candidate.invalid or candidate.stage ~= "done" then return nil, "ranges output was out of order" end
  if not candidate.saw_footer or not candidate.percent_hundredths then
    return nil, "missing Cycle Complete footer"
  end
  if #candidate.rows ~= 50 then
    return nil, "expected 50 range rows, received " .. tostring(#candidate.rows)
  end

  local yes_counts = { under25 = 0, ["25to199"] = 0, ["200plus"] = 0 }
  local previous_from = nil
  for index, row in ipairs(candidate.rows) do
    row.seq = index
    if not row.from or not row.to or row.from > row.to then
      return nil, "invalid level bounds on range row " .. tostring(index)
    end
    if previous_from and row.from < previous_from then
      return nil, "range rows are out of order"
    end
    previous_from = row.from
    for _, tier in ipairs(tier_order) do
      if type(row.done[tier]) ~= "boolean" then
        return nil, "invalid completion flag on range row " .. tostring(index)
      end
      if row.done[tier] then yes_counts[tier] = yes_counts[tier] + 1 end
    end
  end

  for _, tier in ipairs(tier_order) do
    local footer_value = candidate.percent_hundredths[tier]
    if not footer_value or footer_value * #candidate.rows ~= yes_counts[tier] * 10000 then
      return nil, "Cycle Complete percentage does not match range rows"
    end
  end

  return {
    rows = candidate.rows,
    percent_hundredths = candidate.percent_hundredths,
    yes_counts = yes_counts,
    total_rows = #candidate.rows,
  }
end

local function derive_cycle_stats(tier)
  if not ranges_snapshot or not ranges_snapshot.percent_hundredths[tier] then return nil end
  local stats = {
    completed = ranges_snapshot.yes_counts[tier],
    total = ranges_snapshot.total_rows,
    remaining = ranges_snapshot.total_rows - ranges_snapshot.yes_counts[tier],
    level_known = false,
    relevant = {},
  }

  local current_level = current_level_known and tonumber(level) or nil
  if not current_level or current_level % 1 ~= 0 then return stats end
  stats.level_known = true
  stats.level = current_level

  for _, row in ipairs(ranges_snapshot.rows) do
    if not row.done[tier] then
      if row.to >= current_level then table.insert(stats.relevant, row) end
    end
  end
  local third = stats.relevant[3]
  local following = third and ranges_snapshot.rows[(tonumber(third.seq) or 0) + 1] or nil
  if following and type(following.done[tier]) == "boolean" then
    stats.following_done = following.done[tier]
  end
  return stats
end

local function signed_offset(value)
  value = tonumber(value) or 0
  if value >= 0 then return "+" .. tostring(value) end
  return tostring(value)
end

local function cycle_segments(tier, max_width)
  if not connected then return { { text = "-" } } end
  if ranges_status == "idle" or ranges_status == "loading" then return { { text = "..." } } end
  local stats = derive_cycle_stats(tier)
  if not stats then return { { text = "?" } } end
  if stats.remaining == 0 then return { { text = "0" } } end

  if not stats.level_known then
    return { { text = tostring(stats.remaining) .. "(?)" } }
  end

  if #stats.relevant == 0 then
    return { { text = tostring(stats.remaining) .. "(-)" } }
  end

  local shown = math.min(3, #stats.relevant)
  while shown > 0 do
    local function build_parts(include_following)
      local parts = { { text = tostring(stats.remaining) .. "(" } }
      for index = 1, shown do
        local row = stats.relevant[index]
        if index > 1 then table.insert(parts, { text = "," }) end
        table.insert(parts, {
          text = signed_offset(row.from - stats.level),
          current = row.from <= stats.level and stats.level <= row.to,
          font = row.to == stats.level and cycle_boundary_font or table_font,
        })
      end
      table.insert(parts, { text = ")" })
      if include_following then
        table.insert(parts, { text = stats.following_done and "-" or "+" })
      end
      return parts
    end

    local include_following = shown == 3 and stats.following_done ~= nil
    local parts = build_parts(include_following)
    local width = 0
    for _, part in ipairs(parts) do
      width = width + measured_text_width(part.text, part.font)
    end
    if not max_width or width <= max_width then return parts end

    -- Preserve the three visible ranges before dropping one merely because the
    -- fourth-range marker does not fit at an unusually narrow/font-wide size.
    if include_following then
      parts = build_parts(false)
      width = 0
      for _, part in ipairs(parts) do
        width = width + measured_text_width(part.text, part.font)
      end
      if width <= max_width then return parts end
    end
    shown = shown - 1
  end
  return { { text = tostring(stats.remaining) } }
end

local function draw_cycle_cell(layout, tier, y)
  local cell = layout.cells.cycle
  local parts = cycle_segments(tier, cell.right - cell.left)
  local base_colour_name = cycle_display_colour and cycle_display_colour("white") or "white"
  local base_colour = ColourNameToRGB(base_colour_name)
  local allow_current_colour = ranges_status == "ready"
  local rendered = {}
  for _, part in ipairs(parts) do
    local font = part.font or table_font
    local colour = allow_current_colour and part.current and ColourNameToRGB("lime") or base_colour
    local previous = rendered[#rendered]
    if previous and previous.colour == colour and previous.font == font then
      previous.text = previous.text .. part.text
    else
      table.insert(rendered, { text = part.text, colour = colour, font = font })
    end
  end
  local width = 0
  for _, part in ipairs(rendered) do
    width = width + measured_text_width(part.text, part.font)
  end
  local x = cell.left + math.max(0, math.floor(((cell.right - cell.left) - width) / 2))
  for _, part in ipairs(rendered) do
    WindowText(win, part.font, part.text, x, y, cell.right, y + 12, part.colour, false)
    x = x + measured_text_width(part.text, part.font)
  end
end

local function read_gmcp(path)
  local ok, value = pcall(gmcp, path)
  return ok and value or nil
end

local function send_gmcp_config(packet)
  if type(Send_GMCP_Packet) == "function" then pcall(Send_GMCP_Packet, packet) end
end

local function begin_quiet_command_block(active)
  if not fence_quiet_baseline then
    fence_quiet_baseline = {
      compact = tostring(read_gmcp("config.compact") or ""):upper(),
      prompt = tostring(read_gmcp("config.prompt") or ""):upper(),
    }
  end
  local state = {
    compact = fence_quiet_baseline.compact,
    prompt = fence_quiet_baseline.prompt,
  }

  if state.compact == "NO" or state.compact == "OFF" then
    if blank_gag_available and type(GagBlankLine) == "function" then
      active.blank_gag_id = string.format("GQList_%s_%s_%d", load_nonce, active.kind, active.serial)
      pcall(GagBlankLine, active.blank_gag_id, 96)
    end
    send_gmcp_config("config compact YES")
  end
  if state.prompt == "YES" or state.prompt == "ON" then
    send_gmcp_config("config prompt OFF")
  end
  return state
end

local function end_quiet_command_block(state)
  if state.compact == "NO" or state.compact == "OFF" then
    send_gmcp_config("config compact " .. state.compact)
  end
  if state.prompt == "YES" or state.prompt == "ON" then
    send_gmcp_config("config prompt " .. state.prompt)
  end
end

local function fence_identity()
  local base_level = tonumber(read_gmcp("char.base.level"))
  if not base_level then return nil end
  if base_level < 202 then return { command = "echo ", prefix = "" } end

  local character_name = tostring(read_gmcp("char.base.name") or "")
  if character_name == "" then return nil end
  return {
    command = "echo self ",
    prefix = character_name .. " echo> ",
    name = character_name,
  }
end

local function delete_internal_echo_gags(active)
  if not active then return end
  if active.echo_triggers and type(DeleteTrigger) == "function" then
    for _, trigger_name in ipairs(active.echo_triggers) do DeleteTrigger(trigger_name) end
  end
  active.echo_triggers = {}
  if active.blank_gag_id and type(UngagBlankLine) == "function" then
    pcall(UngagBlankLine, active.blank_gag_id)
    active.blank_gag_id = nil
  end
end

local function add_internal_echo_gag(active, exact_line, index)
  if type(AddTriggerEx) ~= "function" or not trigger_flag or not sendto then return end
  local trigger_name = string.format(
    "GQ_Dashboard_internal_echo_%s_%s_%d_%d", load_nonce, active.kind, active.serial, index
  )
  local flags = trigger_flag.Enabled + trigger_flag.Temporary + trigger_flag.OneShot
    + trigger_flag.OmitFromOutput + trigger_flag.OmitFromLog
    + (trigger_flag.KeepEvaluating or 0)
  local result = AddTriggerEx(
    trigger_name, exact_line, "", flags, -1, 0, "", "", sendto.script, 97
  )
  if tonumber(result) == 0 then table.insert(active.echo_triggers, trigger_name) end
end

local function send_fenced_command(kind, active, command)
  local identity = fence_identity()
  if not identity then return false, "character identity is not available" end
  local serial = active.serial
  active.kind = tostring(kind):lower()
  local suffix = string.format("%s_%d_%d", load_nonce, lifecycle_epoch, serial)
  local begin_tag = "GQDASH_" .. kind .. "_BEGIN_" .. suffix
  local end_tag = "GQDASH_" .. kind .. "_END_" .. suffix
  local begin_command = identity.command .. begin_tag
  local end_command = identity.command .. end_tag
  active.expected_begin_line = identity.prefix .. begin_tag
  active.expected_end_line = identity.prefix .. end_tag
  active.echo_triggers = {}
  add_internal_echo_gag(active, "You entered: " .. begin_command, 1)
  add_internal_echo_gag(active, "You entered: " .. command, 2)
  add_internal_echo_gag(active, "You entered: " .. end_command, 3)

  local paging_disabled = false
  if type(TelnetOptionOff) == "function" and TELOPT_PAGING ~= nil then
    paging_disabled = pcall(TelnetOptionOff, TELOPT_PAGING)
  end
  local quiet_state = begin_quiet_command_block(active)
  local ok, error_message = pcall(function()
    SendNoEcho(begin_command)
    SendNoEcho(command)
    SendNoEcho(end_command)
  end)
  end_quiet_command_block(quiet_state)
  if paging_disabled and type(TelnetOptionOn) == "function" then
    pcall(TelnetOptionOn, TELOPT_PAGING)
  end
  if not ok then
    delete_internal_echo_gags(active)
    return false, error_message
  end
  return true
end

local function release_fence_quiet_baseline_if_idle()
  if not swho_active and not ranges_capture and not ranges_refresh_pending
     and #swho_queue == 0 then
    fence_quiet_baseline = nil
  end
end

local function prune_swho_queue()
  local retained_requests = {}
  for _, request in ipairs(swho_queue) do
    local retained_targets = {}
    for _, state in ipairs(request.targets) do
      if competition_scans[state.id] == state and state.status == "pending" then
        table.insert(retained_targets, state)
      end
    end
    if #retained_targets > 0 then
      request.targets = retained_targets
      table.insert(retained_requests, request)
    end
  end
  swho_queue = retained_requests
end

local function clear_competition_scans(tier)
  if not tier then
    competition_scans = {}
    swho_queue = {}
    if swho_active then swho_active.discard = true end
    return
  end

  for id, state in pairs(competition_scans) do
    if state.tier == tier then competition_scans[id] = nil end
  end

  prune_swho_queue()

  if swho_active then
    swho_active.invalidated_tiers[tier] = true
  end
end

local function ensure_competition_scan(gq)
  if not gq or not gq.tier then return nil end

  local state = competition_scans[gq.id]
  if state and (state.tier ~= gq.tier or state.from ~= gq.from or state.to ~= gq.to) then
    competition_scans[gq.id] = nil
    state = nil
  end

  if not state then
    state = {
      id = gq.id,
      tier = gq.tier,
      from = gq.from,
      to = gq.to,
      status = "pending",
      rows = {},
    }
    competition_scans[gq.id] = state

    -- One swho response can serve multiple visible GQs with the same range.
    if swho_active and not swho_active.discard
       and not swho_active.invalidated_tiers[state.tier]
       and swho_active.request.from == state.from
       and swho_active.request.to == state.to then
      state.status = "scanning"
      table.insert(swho_active.targets, state)
      return state
    end

    local request = nil
    for _, candidate in ipairs(swho_queue) do
      if candidate.from == state.from and candidate.to == state.to then
        request = candidate
        break
      end
    end
    if not request then
      request = { from = state.from, to = state.to, targets = {} }
      table.insert(swho_queue, request)
    end
    table.insert(request.targets, state)
  end

  return state
end

local function competition_label(state)
  if not state then return nil end
  if state.status == "ready" then return "(" .. tostring(#state.rows) .. ")" end
  if state.status == "error" then return "(?)" end
  return "(...)"
end

schedule_swho_pump = function(delay)
  if swho_pump_scheduled or not plugin_enabled or not connected then return end
  swho_pump_scheduled = true
  DoAfterSpecial(delay or 0.1, string.format(
    "swho_run_pump(%q,%d)", load_nonce, lifecycle_epoch
  ), 12)
end

local function start_next_swho()
  if not plugin_enabled or not connected or swho_active
     or ranges_capture or ranges_refresh_pending then return end

  while #swho_queue > 0 do
    local request = table.remove(swho_queue, 1)
    local targets = {}
    for _, state in ipairs(request.targets) do
      if competition_scans[state.id] == state and state.status == "pending" then
        state.status = "scanning"
        state.rows = {}
        table.insert(targets, state)
      end
    end

    if #targets > 0 then
      swho_serial = swho_serial + 1
      swho_active = {
        serial = swho_serial,
        epoch = lifecycle_epoch,
        request = request,
        targets = targets,
        rows = {},
        phase = "awaiting_identity",
        saw_header = false,
        saw_found = false,
        saw_footer = false,
        expected_rows = nil,
        discard = false,
        invalidated_tiers = {},
      }

      local result = try_start_swho_capture()
      if result == "waiting" then
        DoAfterSpecial(5, string.format(
          "swho_identity_timeout(%q,%d,%d)", load_nonce, lifecycle_epoch, swho_serial
        ), 12)
      end
      return
    end
  end
  release_fence_quiet_baseline_if_idle()
end

function try_start_swho_capture()
  local active = swho_active
  if not active or active.phase ~= "awaiting_identity" then return "ignored" end

  local sent, send_error = send_fenced_command(
    "SWHO", active,
    string.format("swho 11 %d %d", active.request.from - 1, active.request.to)
  )
  if not sent then
    if send_error == "character identity is not available" then return "waiting" end
    finish_swho_capture(false)
    return "failed"
  end

  active.phase = "awaiting_marker"
  DoAfterSpecial(20, string.format(
    "swho_capture_timeout(%q,%d,%d)", load_nonce, lifecycle_epoch, active.serial
  ), 12)
  return "sent"
end

function swho_run_pump(nonce, epoch)
  if tostring(nonce or "") ~= load_nonce or tonumber(epoch) ~= lifecycle_epoch then return end
  swho_pump_scheduled = false
  start_next_swho()
end

local function set_swho_capture_phase(phase)
  EnableTriggerGroup("GQ_SWHO_HEADER", phase == "awaiting_header")
  EnableTriggerGroup("GQ_SWHO_BODY", phase == "body")
  if swho_active then swho_active.phase = phase end
end

finish_swho_capture = function(success)
  local active = swho_active
  set_swho_capture_phase(nil)
  swho_active = nil
  if not active then return end
  delete_internal_echo_gags(active)

  if not active.discard then
    for _, state in ipairs(active.targets) do
      if competition_scans[state.id] == state then
        state.rows = {}
        if success then
          for _, player in ipairs(active.rows) do
            if wins_match_tier(player.wins, state.tier) then
              table.insert(state.rows, player.line)
            end
          end
        end
        state.status = success and "ready" or "error"
      end
    end
  end

  if draw_gq_window then draw_gq_window(false) end
  if ranges_refresh_pending and plugin_enabled and connected then
    DoAfterSpecial(0.1, string.format(
      "ranges_run_pending(%q,%d)", load_nonce, lifecycle_epoch
    ), 12)
  else
    schedule_swho_pump(0.1)
  end
  release_fence_quiet_baseline_if_idle()
end

local function marker_numbers(line, marker_name)
  local nonce, epoch, serial = tostring(line or ""):match(
    "GQDASH_SWHO_" .. marker_name .. "_(%d+)_(%d+)_(%d+)$"
  )
  return nonce, tonumber(epoch), tonumber(serial)
end

function swho_marker_start(name, line, wildcards, styles)
  local nonce, epoch, serial = marker_numbers(line, "BEGIN")
  if swho_active and nonce == load_nonce and epoch == lifecycle_epoch and serial == swho_active.serial
     and tostring(line or "") == swho_active.expected_begin_line
     and swho_active.phase == "awaiting_marker" then
    set_swho_capture_phase("awaiting_header")
  end
  if type(StopEvaluatingTriggers) == "function" then StopEvaluatingTriggers(true) end
end

function swho_marker_end(name, line, wildcards, styles)
  local nonce, epoch, serial = marker_numbers(line, "END")
  local active = swho_active
  if active and nonce == load_nonce and epoch == lifecycle_epoch and serial == active.serial
     and tostring(line or "") == active.expected_end_line then
    local complete_body = active.phase == "body"
      and active.saw_header
      and active.saw_found
      and active.saw_footer
      and active.expected_rows == #active.rows
    local complete_headerless_zero = active.phase == "awaiting_header"
      and active.saw_found
      and active.saw_footer
      and active.expected_rows == 0
      and #active.rows == 0
    finish_swho_capture(complete_body or complete_headerless_zero)
  end
  if type(StopEvaluatingTriggers) == "function" then StopEvaluatingTriggers(true) end
end

function swho_capture_line(name, line, wildcards, styles)
  if not swho_active
     or (swho_active.phase ~= "awaiting_header" and swho_active.phase ~= "body") then
    return
  end
  line = tostring(line or "")

  if line:match("^%s*Who list sorted by%s*:%s*Gquests Won%s*$") then
    if swho_active.phase == "awaiting_header" then
      swho_active.saw_header = true
      set_swho_capture_phase("body")
    end
    return
  end

  if swho_active.phase == "body" then
    local wins_text = line:match("^%s*%[[^%]]+%]%s+%[%s*([%d,]+)%s*%]")
    local wins = wins_text and tonumber((wins_text:gsub(",", ""))) or nil
    if wins then
      table.insert(swho_active.rows, { wins = wins, line = line })
      return
    end
  end

  local found_text = line:match("^Players found:%s*%[([%d,]+)%]")
  if found_text then
    swho_active.saw_found = true
    swho_active.expected_rows = tonumber((found_text:gsub(",", "")))
    return
  end

  if line:match("^Players invis:") then
    swho_active.saw_footer = true
  end
end

function swho_capture_timeout(nonce, epoch, serial)
  if tostring(nonce or "") ~= load_nonce or tonumber(epoch) ~= lifecycle_epoch then return end
  if swho_active and swho_active.serial == tonumber(serial) then
    finish_swho_capture(false)
  end
end

function swho_identity_timeout(nonce, epoch, serial)
  if tostring(nonce or "") ~= load_nonce or tonumber(epoch) ~= lifecycle_epoch then return end
  if swho_active and swho_active.serial == tonumber(serial)
     and swho_active.phase == "awaiting_identity" then
    finish_swho_capture(false)
  end
end

-- Compatibility no-ops for timer strings created by 2.2 before a reload.
function swho_outstanding_timeout(serial) end
function swho_start_after_observed_end() end
function swho_observe_end() end
function swho_capture_start() end
function swho_capture_found() end
function swho_capture_end() end

-- ===== Fenced GQ-cycle ranges capture =====
local function set_ranges_capture_enabled(enabled)
  EnableTriggerGroup("GQ_RANGES_CAPTURE", enabled == true)
end

local function ranges_marker_numbers(line, marker_name)
  local nonce, epoch, serial = tostring(line or ""):match(
    "GQDASH_RANGES_" .. marker_name .. "_(%d+)_(%d+)_(%d+)$"
  )
  return nonce, tonumber(epoch), tonumber(serial)
end

local function schedule_ranges_capture_timeout(active)
  ranges_timeout_generation = ranges_timeout_generation + 1
  active.timeout_generation = ranges_timeout_generation
  DoAfterSpecial(20, string.format(
    "ranges_capture_timeout(%q,%d,%d,%d)",
    load_nonce, lifecycle_epoch, active.serial, active.timeout_generation
  ), 12)
end

function try_start_ranges_capture()
  local active = ranges_capture
  if not active or active.phase ~= "awaiting_identity" then return "ignored" end

  local sent, send_error = send_fenced_command("RANGES", active, "gquest ranges")
  if not sent then
    if send_error == "character identity is not available" then return "waiting" end
    finish_ranges_capture(false, send_error or "could not send gquest ranges")
    return "failed"
  end

  active.phase = "awaiting_marker"
  schedule_ranges_capture_timeout(active)
  return "sent"
end

request_gquest_ranges = function(reason, covers_gq_capture)
  if not plugin_enabled or not connected then return false end
  if ranges_capture then
    if reason == "new_gq" and ranges_capture.covers_gq_capture ~= covers_gq_capture then
      ranges_refresh_pending = {
        reason = reason,
        covers_gq_capture = covers_gq_capture,
      }
    end
    return false
  end
  if swho_active then
    ranges_refresh_pending = {
      reason = reason,
      covers_gq_capture = covers_gq_capture,
    }
    return true
  end

  -- A click can arrive during the short timer gap after another capture has
  -- released the fence. One new snapshot satisfies both requests.
  ranges_refresh_pending = nil

  ranges_capture_serial = ranges_capture_serial + 1
  ranges_capture = {
    kind = "ranges",
    epoch = lifecycle_epoch,
    serial = ranges_capture_serial,
    phase = "awaiting_identity",
    stage = "header_one",
    rows = {},
    saw_header_one = false,
    saw_header_two = false,
    saw_top_separator = false,
    group_separator_count = 0,
    saw_footer_separator = false,
    saw_footer = false,
    percent_hundredths = nil,
    invalid = false,
    covers_gq_capture = covers_gq_capture,
    echo_triggers = {},
  }
  ranges_status = "loading"
  ranges_last_error = nil
  if draw_gq_window then draw_gq_window(false) end

  local result = try_start_ranges_capture()
  if result == "waiting" then
    DoAfterSpecial(5, string.format(
      "ranges_identity_timeout(%q,%d,%d)", load_nonce, lifecycle_epoch, ranges_capture.serial
    ), 12)
  end
  return true
end

finish_ranges_capture = function(success, value)
  local completed = ranges_capture
  set_ranges_capture_enabled(false)
  ranges_capture = nil
  if completed then delete_internal_echo_gags(completed) end

  if success then
    ranges_snapshot = value
    ranges_status = "ready"
    ranges_last_error = nil
  else
    ranges_status = ranges_snapshot and "stale" or "error"
    ranges_last_error = tostring(value or "ranges capture did not complete")
  end

  if draw_gq_window then draw_gq_window(false) end
  if ranges_refresh_pending and plugin_enabled and connected then
    DoAfterSpecial(0.1, string.format(
      "ranges_run_pending(%q,%d)", load_nonce, lifecycle_epoch
    ), 12)
  else
    schedule_swho_pump(0.1)
  end
  release_fence_quiet_baseline_if_idle()
end

function ranges_run_pending(nonce, epoch)
  if tostring(nonce or "") ~= load_nonce or tonumber(epoch) ~= lifecycle_epoch then return end
  if ranges_capture or swho_active then return end
  local pending = ranges_refresh_pending
  if not pending then
    release_fence_quiet_baseline_if_idle()
    return
  end
  ranges_refresh_pending = nil
  request_gquest_ranges(pending.reason or "pending", pending.covers_gq_capture)
end

function ranges_marker_start(name, line, wildcards, styles)
  local nonce, epoch, serial = ranges_marker_numbers(line, "BEGIN")
  if ranges_capture and nonce == load_nonce and epoch == lifecycle_epoch
     and serial == ranges_capture.serial
     and tostring(line or "") == ranges_capture.expected_begin_line
     and ranges_capture.phase == "awaiting_marker" then
    ranges_capture.phase = "capturing"
    schedule_ranges_capture_timeout(ranges_capture)
    set_ranges_capture_enabled(true)
  end
  if type(StopEvaluatingTriggers) == "function" then StopEvaluatingTriggers(true) end
end

function ranges_capture_line(name, line, wildcards, styles)
  local active = ranges_capture
  if not active or active.phase ~= "capturing" then return end
  line = tostring(line or "")

  if line:match("^%s*From%s+To%s+Less%s+Than%s+25%s+to%s+200%s+or%s*$") then
    if active.stage ~= "header_one" then active.invalid = true end
    active.saw_header_one = true
    active.stage = "header_two"
    return
  end
  if line:match("^%s*Level%s+Level%s+25%s+Wins%s+199%s+Wins%s+More%s+Wins%s*$") then
    if active.stage ~= "header_two" then active.invalid = true end
    active.saw_header_two = true
    active.stage = "top_separator"
    return
  end
  if line:match("^%s*%-+%s+%-+%s+%-+%s+%-+%s+%-+%s*$") then
    if active.stage ~= "top_separator" then active.invalid = true end
    active.saw_top_separator = true
    active.stage = "rows"
    return
  end
  if line:match("^%s*%-+%s*$") then
    local expected_rows = (active.group_separator_count + 1) * 5
    if active.stage ~= "rows" or #active.rows ~= expected_rows or #active.rows >= 50 then
      active.invalid = true
    else
      active.group_separator_count = active.group_separator_count + 1
    end
    return
  end
  if line:match("^%s*%-+%s+%-+%s+%-+%s*$") then
    if active.stage ~= "rows" or #active.rows ~= 50 then active.invalid = true end
    active.saw_footer_separator = true
    active.stage = "footer"
    return
  end

  local row = parse_ranges_row(line)
  if row then
    if active.stage ~= "rows" or #active.rows >= 50 then active.invalid = true end
    table.insert(active.rows, row)
    return
  end

  local under25, middle, plus200 = line:match(
    "^%s*Cycle%s+Complete:%s+([%d]+%.[%d][%d])%%%s+([%d]+%.[%d][%d])%%%s+([%d]+%.[%d][%d])%%%s*$"
  )
  if under25 then
    if active.stage ~= "footer" or active.saw_footer then active.invalid = true end
    active.percent_hundredths = {
      under25 = percent_hundredths(under25),
      ["25to199"] = percent_hundredths(middle),
      ["200plus"] = percent_hundredths(plus200),
    }
    active.saw_footer = true
    active.stage = "done"
  end
end

function ranges_marker_end(name, line, wildcards, styles)
  local nonce, epoch, serial = ranges_marker_numbers(line, "END")
  local active = ranges_capture
  if active and nonce == load_nonce and epoch == lifecycle_epoch and serial == active.serial
     and tostring(line or "") == active.expected_end_line then
    local snapshot, error_message = validate_ranges_candidate(active)
    finish_ranges_capture(snapshot ~= nil, snapshot or error_message)
  end
  if type(StopEvaluatingTriggers) == "function" then StopEvaluatingTriggers(true) end
end

function ranges_capture_timeout(nonce, epoch, serial, timeout_generation)
  if tostring(nonce or "") ~= load_nonce or tonumber(epoch) ~= lifecycle_epoch then return end
  if ranges_capture and ranges_capture.serial == tonumber(serial)
     and ranges_capture.timeout_generation == tonumber(timeout_generation) then
    finish_ranges_capture(false, "gquest ranges timed out")
  end
end

function ranges_identity_timeout(nonce, epoch, serial)
  if tostring(nonce or "") ~= load_nonce or tonumber(epoch) ~= lifecycle_epoch then return end
  if ranges_capture and ranges_capture.serial == tonumber(serial)
     and ranges_capture.phase == "awaiting_identity" then
    finish_ranges_capture(false, "character identity was unavailable")
  end
end

-- ===== Staged GQ-list capture =====
local function schedule_gq_capture_timeout(serial)
  DoAfterSpecial(20, string.format(
    "gq_capture_timeout(%q,%d,%d)", load_nonce, lifecycle_epoch, serial
  ), 12)
end

local function new_gq_capture(requested, start_watchdog)
  delete_internal_echo_gags(gq_capture)
  gq_capture_serial = gq_capture_serial + 1
  gq_capture = {
    kind = "gq",
    epoch = lifecycle_epoch,
    serial = gq_capture_serial,
    phase = requested and "awaiting_header" or "capturing",
    requested = requested == true,
    rows = {},
    saw_header = requested ~= true,
    saw_separator = false,
    malformed = false,
    echo_triggers = {},
  }
  if start_watchdog then schedule_gq_capture_timeout(gq_capture_serial) end
  return gq_capture
end

function gq_capture_start(name, line, wildcards, styles)
  local requested = gq_request_pending
  if not gq_capture or gq_capture.phase ~= "awaiting_header" then
    EnableTriggerGroup("GQ_CAPTURE", false)
    new_gq_capture(requested, false)
  end

  -- Give the response body its own full watchdog window. The earlier request
  -- timer becomes stale because it carries the previous serial.
  gq_capture_serial = gq_capture_serial + 1
  gq_capture.serial = gq_capture_serial
  schedule_gq_capture_timeout(gq_capture.serial)
  gq_capture.phase = "capturing"
  gq_capture.saw_header = true
  gq_capture.rows = {}
  gq_capture.saw_separator = false
  gq_capture.malformed = false
  EnableTriggerGroup("GQ_CAPTURE", true)
end

function gq_capture_line(name, line, wildcards, styles)
  if not gq_capture or gq_capture.phase ~= "capturing" then return end
  line = tostring(line or "")
  if line:match("^%s*%-+%s+%-+%s+%-+%s+%-+%s+%-+%s+%-+%s+%-+%s*$") then
    gq_capture.saw_separator = true
  elseif parse_gq_row(line) then
    table.insert(gq_capture.rows, line)
  else
    gq_capture.malformed = true
  end
end

function gq_capture_invalid_line(name, line, wildcards, styles)
  if gq_capture and gq_capture.phase == "capturing" then
    gq_capture.malformed = true
  end
end

local function reconcile_range_refresh(rows, completed_capture)
  local latest_ids = {}
  local saw_new_id = false
  for _, row_text in ipairs(rows) do
    local gq = parse_gq_row(row_text)
    if gq then
      latest_ids[gq.id] = true
      if not ranges_seen_gq_ids[gq.id] then saw_new_id = true end
    end
  end
  ranges_seen_gq_ids = latest_ids

  if saw_new_id or ranges_status == "idle" then
    request_gquest_ranges("new_gq", completed_capture)
  end
end

function gq_capture_end(name, line, wildcards, styles)
  local completed = gq_capture
  if not completed or completed.phase ~= "capturing" then return end

  EnableTriggerGroup("GQ_CAPTURE", false)
  delete_internal_echo_gags(completed)
  gq_capture = nil
  gq_request_pending = false
  if completed.saw_header and completed.saw_separator and not completed.malformed then
    GQ_table = completed.rows
    reconcile_range_refresh(GQ_table, completed)
    draw_gq_window(true)
  end
end

function gq_capture_timeout(nonce, epoch, serial)
  if tostring(nonce or "") ~= load_nonce or tonumber(epoch) ~= lifecycle_epoch then return end
  if gq_capture and gq_capture.serial == tonumber(serial) then
    delete_internal_echo_gags(gq_capture)
    gq_capture = nil
    gq_request_pending = false
    EnableTriggerGroup("GQ_CAPTURE", false)
  end
end

request_gq_list = function(show_command)
  if not plugin_enabled or not connected or gq_request_pending or gq_capture then return false end

  new_gq_capture(true, true)
  gq_request_pending = true
  if not show_command then
    add_internal_echo_gag(gq_capture, "You entered: gq list", 1)
  end
  if show_command then Send("gq list") else SendNoEcho("gq list") end
  return true
end

-- ===== Draw list (called by stopper) =====

draw_gq_window = function(allow_alerts, themed_helper_will_dress)
  if not my_window or not my_window.id or WindowInfo(win, 1) == nil then return end
  valid_range = false

  local active_ids = {}
  for _, text in ipairs(GQ_table) do
    local gq = parse_gq_row(text)
    if gq then active_ids[gq.id] = true end
  end

  for id in pairs(competition_scans) do
    if not active_ids[id] then competition_scans[id] = nil end
  end
  prune_swho_queue()
  for id in pairs(gqhistory) do
    if not active_ids[id] then gqhistory[id] = nil end
  end
  if swho_active then
    local has_active_target = false
    for _, state in ipairs(swho_active.targets) do
      if active_ids[state.id] and competition_scans[state.id] == state then
        has_active_target = true
        break
      end
    end
    if not has_active_target then swho_active.discard = true end
  end

  my_window:blank()

  -- clear hotspots
  local hotspots = WindowHotspotList(win)
  if hotspots then
    for _, id in pairs(hotspots) do
      if string.sub(id, 1, 8) == "hotspot_" or string.sub(id, 1, 8) == "players_"
         or string.sub(id, 1, 6) == "cycle_" or id == "titlemenu" then
        WindowDeleteHotspot (win, id)
      end
    end
  end

  -- title/drag area
  WindowAddHotspot(win, "titlemenu", 0, 0, tonumber(WindowInfo(win,3)) or 480, 20,
                   "", "", "mousedown_drag", "", "menu_mouseup",
                   "Drag to move window\nRight-click for menu", 0, 0)

  WindowFont(win, table_font, "Dina", 8, false, false, false, false, 0)
  WindowFont(win, cycle_boundary_font, "Dina", 8, true, false, false, false, 0)
  current_table_layout = build_table_layout()
  draw_table_header(current_table_layout)

  local visible_rows = 0
  local tiers_with_active_rows = {}
  for _, row_text in ipairs(GQ_table) do
    local gq = parse_gq_row(row_text)
    if gq and gq.tier and tier_enabled(gq.tier) then
      visible_rows = visible_rows + 1
      tiers_with_active_rows[gq.tier] = true
      add_text(row_text, visible_rows, allow_alerts)
    end
  end

  for _, tier in ipairs(tier_order) do
    if tier_enabled(tier) and not tiers_with_active_rows[tier] then
      visible_rows = visible_rows + 1
      add_cycle_summary(tier, visible_rows)
    end
  end

  if visible_rows == 0 then
    WindowText(win, "f1", "No GQ tiers selected.", 5, 42, 0, 0, ColourNameToRGB("white"), false)
  end

  WindowDragHandler(win, "titlemenu", "dragmove", "dragrelease", 0)
  if not themed_helper_will_dress then my_window:dress_window() end

  if auto_toggle and valid_range then my_window:show()
  elseif auto_toggle then my_window:hide() end

  schedule_swho_pump(0.1)
end

cycle_display_colour = function(default_colour)
  if not connected then return "silver" end
  if ranges_status == "stale" then return "yellow" end
  if ranges_status == "error" then return "red" end
  if ranges_status == "loading" or ranges_status == "idle" then return "silver" end
  return default_colour
end

local function cycle_tooltip(tier)
  local legend = "\nBold: the next level leaves that range"
    .. "\nTrailing +: next range has not run; -: it has run"
  if not connected then return "GQ cycle data is unavailable while disconnected" end
  if ranges_status == "loading" or ranges_status == "idle" then
    return "GQ cycle refresh in progress\nLeft-click for status\nRight-click to refresh"
  end
  if ranges_status == "error" then
    return "GQ cycle refresh failed\nLeft-click for details\nRight-click to retry"
  end
  if ranges_status == "stale" then
    return "Showing the last complete GQ cycle snapshot" .. legend
      .. "\nLeft-click for details\nRight-click to retry"
  end
  return tier_description(tier) .. " cycle details" .. legend
    .. "\nLeft-click for details\nRight-click to refresh"
end

local function add_cycle_hotspot(tier, key, left, y, right)
  WindowAddHotspot(win, "cycle_" .. tier .. "_" .. tostring(key),
                   left, y + 2, right, y + 12,
                   "", "", "", "", "cycle_mouseup",
                   cycle_tooltip(tier), miniwin.cursor_hand, 0)
end

function add_cycle_summary(tier, visible_row)
  local y = visible_row * 12 + 30
  local layout = current_table_layout or build_table_layout()
  local row = {
    id = "-",
    tier = tier,
    levels = "-",
    status = "No active",
    timer = "-",
  }
  draw_table_row(
    layout, row, "-", y, ColourNameToRGB("white")
  )
  draw_cycle_cell(layout, tier, y)
  add_cycle_hotspot(tier, "summary", layout.cells.cycle.left, y, layout.right)
end

-- Draw a row, color by eligibility, install row hotspot, gate alert
function add_text(text, visible_row, allow_alerts)
  local gq = parse_gq_row(text)
  local layout = current_table_layout or build_table_layout()
  local from = gq and gq.from or nil
  local to = gq and gq.to or nil
  local lvl  = tonumber(level) or 1
  local y = visible_row * 12 + 30

  local in_range = (to and from and (lvl >= from and lvl <= to))
  local scan = in_range and plugin_enabled and connected
               and not suppress_competition_scan and ensure_competition_scan(gq) or nil
  local label = competition_label(scan)
  local players_text = tostring(gq.players or 0) .. tostring(label or "")
  local row = {
    id = gq.id,
    tier = gq.tier,
    type_text = gq.type_text,
    levels = string.format("%d-%d", gq.from, gq.to),
    status = gq.status,
    timer = gq.timer,
  }
  local row_colour = "red"

  if in_range then
    row_colour = "lime"
    valid_range = true
  elseif from and (from == (lvl + 1)) then
    row_colour = "yellow"
    valid_range = true
  end

  draw_table_row(
    layout, row, players_text, y, ColourNameToRGB(row_colour)
  )
  draw_cycle_cell(layout, gq.tier, y)

  local players_left = layout.cells.players.left
  local cycle_left = layout.cells.cycle.left
  local row_right = cycle_left - 1
  if scan then
    local players_right = cycle_left - 1
    row_right = players_left - 1

    local tooltip
    if scan.status == "ready" then
      tooltip = string.format("%d visible players match this GQ tier\nLeft-click to show list\nRight-click to join", #scan.rows)
    elseif scan.status == "error" then
      tooltip = "Competition scan failed\nLeft-click to retry\nRight-click to join"
    else
      tooltip = "Competition scan in progress\nRight-click to join"
    end

    WindowAddHotspot(win, "players_" .. gq.id,
                     players_left, y + 2, players_right, y + 12,
                     "", "", "", "", "players_mouseup",
                     tooltip, miniwin.cursor_hand, 0)
  end

  add_cycle_hotspot(gq.tier, gq.id, cycle_left, y, layout.right)

  WindowAddHotspot(win, "hotspot_" .. gq.id,
                   layout.left, y + 2, row_right, y + 12,
                   "", "", "", "", "mouseup",
                   "Left-click to see GQ info\nRight-click to join", 1, 0)

  -- Alert only if you're eligible for the quest's level range
  if allow_alerts then gqsoundcheck(gq.id, in_range) end
end

-- Alert once per new eligible quest id; suppress when out-of-range
function gqsoundcheck(gqid, eligible)
  if not eligible then return end
  gqid = tostring(gqid or "")
  if gqhistory[gqid] then return end
  gqhistory[gqid] = true

  if sound_on then PlaySound(0, GetInfo(74) .. qgsound, false, 100, 0) end
  ColourNote("white","red","*****************************")
  ColourNote("white","red","* Global Quest Available!!! *")
  ColourNote("white","red","*****************************")
end

-- ===== Menu actions =====
function togglesound()
  sound_on = not sound_on
  Note("GQ Info Sound " .. (sound_on and "ON." or "OFF."))
  save_preferences()
  SaveState()
end

function togglewin()
  auto_toggle = not auto_toggle
  Note("GQ Info Auto Hide " .. (auto_toggle and "ON." or "OFF."))
  save_preferences()
  if draw_gq_window then draw_gq_window(false) end
  if not auto_toggle and my_window and my_window.id then
    if window_should_be_visible then my_window:show() else my_window:hide() end
  end
  SaveState()
end

function toggle_25()
  toggle25 = not toggle25
  Note((toggle25 and "ON: " or "OFF: ") .. "24 wins or fewer.")
  clear_competition_scans("under25")
  if draw_gq_window then draw_gq_window(false) end
  save_preferences()
  SaveState()
end

function toggle_200()
  toggle200 = not toggle200
  Note((toggle200 and "ON: " or "OFF: ") .. "25-199 wins.")
  clear_competition_scans("25to199")
  if draw_gq_window then draw_gq_window(false) end
  save_preferences()
  SaveState()
end

-- Correct 200+ toggle
function toggle_201()
  toggle201 = not toggle201
  Note((toggle201 and "ON: " or "OFF: ") .. "200+ wins.")
  clear_competition_scans("200plus")
  if draw_gq_window then draw_gq_window(false) end
  save_preferences()
  SaveState()
end

function bring_to_front()
  if IsPluginInstalled(plugin_id_z_order) and GetPluginInfo(plugin_id_z_order,17) then
    CallPlugin(plugin_id_z_order, "boostMe", win)
  end
  Note("GQ window to front")
  SaveState()
end

function send_to_back()
  if IsPluginInstalled(plugin_id_z_order) and GetPluginInfo(plugin_id_z_order,17) then
    CallPlugin(plugin_id_z_order, "dropMe", win)
  end
  Note("GQ window to back")
  SaveState()
end

-- ===== Mouse handling / menu =====
local function has_mouse_flag(flags, constant_name, fallback)
  local mask = tonumber(miniwin and miniwin[constant_name]) or fallback
  return bit.band(tonumber(flags) or 0, mask) ~= 0
end

function mousedown_drag(flags, hotspot_id)
  win_dragmove_start_x = WindowInfo(win, 14)
  win_dragmove_start_y = WindowInfo(win, 15)
end

function dragmove(flags, hotspot_id)
  if GetPluginVariable("c293f9e7f04dde889f65cb90", "lock_down_miniwindows") == "1" then
    return
  end
  if not has_mouse_flag(flags, "hotspot_got_rh_mouse", 32) then
    local win_pos_x = WindowInfo(win, 17)
    local win_pos_y = WindowInfo(win, 18)
    local delta_x = win_pos_x - win_dragmove_start_x
    local delta_y = win_pos_y - win_dragmove_start_y
    local actual_width = tonumber(WindowInfo(win, 3)) or tonumber(my_window and my_window.width) or min_window_width
    local actual_height = tonumber(WindowInfo(win, 4)) or tonumber(my_window and my_window.height) or min_window_height
    local max_x = math.max(1, GetInfo(281) - actual_width)
    local max_y = math.max(1, GetInfo(280) - actual_height)
    if (delta_x <= 1) then delta_x = 1 elseif (delta_x >= max_x) then delta_x = max_x end
    if (delta_y <= 1) then delta_y = 1 elseif (delta_y >= max_y) then delta_y = max_y end
    WindowPosition(win, delta_x, delta_y, miniwin.pos_stretch_to_view, miniwin.create_absolute_location)
    if my_window and my_window.windowinfo then
      my_window.windowinfo.window_left = delta_x
      my_window.windowinfo.window_top = delta_y
    end
  end
end

function dragrelease(flags, hotspot_id)
  movewindow.save_state(win)
  Repaint()
end

function menu_mouseup(flags, hotspotid)
  if has_mouse_flag(flags, "hotspot_got_rh_mouse", 32) then
    local result = WindowMenu(win, WindowInfo(win,14), WindowInfo(win,15), build_menu_string())
    if result ~= "" then
      local n = tonumber(result)
      if     n == 1 then togglesound()
      elseif n == 2 then togglewin()
      elseif n == 3 then toggle_25()
      elseif n == 4 then toggle_200()
      elseif n == 5 then toggle_201()
      elseif n == 6 then bring_to_front()
      elseif n == 7 then send_to_back()
      end
    end
  end
end

function mouseup(flags, hotspotid)
  local gqid = tostring(hotspotid or ""):match("^hotspot_(%d+)$")
  if not gqid then return end
  if has_mouse_flag(flags, "hotspot_got_lh_mouse", 16) then
    SendNoEcho("gq info " .. gqid)
  elseif has_mouse_flag(flags, "hotspot_got_rh_mouse", 32) then
    SendNoEcho("gq join " .. gqid)
  end
end

local function show_competition(gqid)
  local state = competition_scans[tostring(gqid or "")]
  if not state then
    Note("No competition snapshot is available for that GQ.")
    return
  end

  if state.status == "pending" or state.status == "scanning" then
    Note("The competition scan for GQ #" .. state.id .. " is still in progress.")
    return
  end

  if state.status == "error" then
    Note("The competition scan for GQ #" .. state.id .. " did not complete.")
    return
  end

  Note("")
  ColourNote("white", "", string.format(
    "GQ #%s: levels %d-%d, %s",
    state.id, state.from, state.to, tier_description(state.tier)
  ))
  ColourNote("silver", "", "Who list sorted by: Gquests Won")
  Note("")
  for _, player_line in ipairs(state.rows) do Note(player_line) end
  if #state.rows > 0 then Note("") end
  ColourNote("silver", "", "Matching players: [" .. tostring(#state.rows) .. "]")
end

local function retry_competition(gqid)
  local previous = competition_scans[tostring(gqid or "")]
  if not previous or previous.status ~= "error" then return false end

  competition_scans[previous.id] = nil
  ensure_competition_scan({
    id = previous.id,
    tier = previous.tier,
    from = previous.from,
    to = previous.to,
  })
  if draw_gq_window then draw_gq_window(false) end
  schedule_swho_pump(0.1)
  return true
end

function players_mouseup(flags, hotspotid)
  local gqid = tostring(hotspotid or ""):match("^players_(%d+)$")
  if not gqid then return end

  if has_mouse_flag(flags, "hotspot_got_lh_mouse", 16) then
    if retry_competition(gqid) then
      Note("Competition scan retry queued for GQ #" .. gqid .. ".")
    else
      show_competition(gqid)
    end
  elseif has_mouse_flag(flags, "hotspot_got_rh_mouse", 32) then
    SendNoEcho("gq join " .. gqid)
  end
end

local function show_cycle_details(tier)
  if not connected then
    Note("GQ cycle data is unavailable while disconnected.")
    return
  end
  if ranges_status == "loading" or ranges_status == "idle" then
    Note("The GQ cycle refresh is still in progress.")
    return
  end
  if not ranges_snapshot then
    Note("No complete GQ cycle snapshot is available."
      .. (ranges_last_error and (" Reason: " .. ranges_last_error) or ""))
    return
  end

  local stats = derive_cycle_stats(tier)
  if not stats then
    Note("No GQ cycle data is available for that tier.")
    return
  end

  Note("")
  ColourNote("white", "", "GQ cycle: " .. tier_description(tier))
  if ranges_status == "stale" then
    ColourNote("yellow", "", "The latest refresh failed; showing the last complete snapshot.")
    if ranges_last_error then Note("Reason: " .. ranges_last_error) end
  end
  ColourNote("silver", "", string.format(
    "%d ranges remain in this cycle.", stats.remaining
  ))

  if not stats.level_known then
    Note("Current character level is not available yet.")
    return
  end

  ColourNote("silver", "", string.format(
    "Remaining ranges at level %d or higher:", stats.level
  ))
  if #stats.relevant == 0 then
    Note("  None.")
  else
    for _, row in ipairs(stats.relevant) do
      local text = string.format("  %d-%d", row.from, row.to)
      if row.from <= stats.level and stats.level <= row.to then
        ColourNote("lime", "", text)
      else
        Note(text)
      end
    end
  end
end

function cycle_mouseup(flags, hotspotid)
  local tier = tostring(hotspotid or ""):match("^cycle_([%w]+)_")
  if not tier or not tier_enabled(tier) then return end

  if not connected then
    Note("GQ cycle data is unavailable while disconnected.")
    return
  end

  if has_mouse_flag(flags, "hotspot_got_lh_mouse", 16) then
    show_cycle_details(tier)
  elseif has_mouse_flag(flags, "hotspot_got_rh_mouse", 32) then
    if ranges_capture then
      Note("A GQ cycle refresh is already in progress.")
    elseif request_gquest_ranges("manual", nil) then
      Note("GQ cycle refresh requested.")
    end
  end
end

function redraw_gq_window_for_resize(window)
  if draw_gq_window then draw_gq_window(false, true) end
end

-- ===== Window & GMCP wiring =====
create_window = function()
  if my_window and my_window.id and WindowInfo(win, 1) ~= nil then return my_window end

  if my_window and type(my_window.delete) == "function" then
    pcall(function() my_window:delete(false) end)
  end
  my_window = nil

  my_window = ThemedBasicWindow(
     win, 0, 0, 480, 120,
     "GQ Dashboard", "center", false, 1,
     redraw_gq_window_for_resize, redraw_gq_window_for_resize,
     nil, nil, 8, false, false
  )

  my_window.min_drag_width = min_window_width
  my_window.min_drag_height = min_window_height
  local current_width = tonumber(WindowInfo(win, 3)) or min_window_width
  local current_height = tonumber(WindowInfo(win, 4)) or min_window_height
  if current_width < min_window_width or current_height < min_window_height then
    local corrected_width = math.max(current_width, min_window_width)
    local corrected_height = math.max(current_height, min_window_height)
    my_window:resize(corrected_width, corrected_height, false)
    SetVariable("themed_miniwindow_width" .. win, tostring(corrected_width))
    SetVariable("themed_miniwindow_height" .. win, tostring(corrected_height))
  end

  if IsPluginInstalled(plugin_id_z_order) and GetPluginInfo(plugin_id_z_order, 17) then
    CallPlugin(plugin_id_z_order, "registerMiniwindow", win)
  end
  return my_window
end

local function sync_window_size()
  if not my_window or not my_window.id or WindowInfo(win, 1) == nil then return end
  local width = tonumber(WindowInfo(win, 3))
  local height = tonumber(WindowInfo(win, 4))
  if not width or not height then return end
  local corrected_width = math.max(width, min_window_width)
  local corrected_height = math.max(height, min_window_height)
  if corrected_width ~= width or corrected_height ~= height then
    my_window:resize(corrected_width, corrected_height, false)
    width = corrected_width
    height = corrected_height
  end
  my_window.width = width
  my_window.height = height
  SetVariable("themed_miniwindow_width" .. win, tostring(width))
  SetVariable("themed_miniwindow_height" .. win, tostring(height))
end

local function reset_transient_state(clear_display)
  lifecycle_epoch = lifecycle_epoch + 1
  delete_internal_echo_gags(gq_capture)
  gq_capture = nil
  gq_request_pending = false
  delete_internal_echo_gags(ranges_capture)
  ranges_capture = nil
  ranges_snapshot = nil
  ranges_status = "idle"
  ranges_last_error = nil
  ranges_refresh_pending = nil
  ranges_seen_gq_ids = {}
  fence_quiet_baseline = nil
  competition_scans = {}
  swho_queue = {}
  delete_internal_echo_gags(swho_active)
  swho_active = nil
  swho_pump_scheduled = false
  suppress_competition_scan = false
  valid_range = false
  EnableTriggerGroup("GQ_CAPTURE", false)
  EnableTriggerGroup("GQ_RANGES_CAPTURE", false)
  EnableTriggerGroup("GQ_SWHO_HEADER", false)
  EnableTriggerGroup("GQ_SWHO_BODY", false)
  if clear_display then
    GQ_table = {}
    gqhistory = {}
  end
end

local function world_is_connected()
  if type(IsConnected) ~= "function" then return true end
  local ok, value = pcall(IsConnected)
  if not ok then return true end
  return value == true or tonumber(value) == 1
end

local function request_character_state()
  SendNoEcho("protocols gmcp sendchar")
  local reported_level = tonumber(gmcp("char.status.level"))
  if reported_level then
    level = reported_level
    current_level_known = true
  end
  gmcp_state = gmcp("char.status.state")
end

local function invalidate_level_transition(old_level, new_level)
  for _, text in ipairs(GQ_table) do
    local gq = parse_gq_row(text)
    if gq then
      local old_eligible = old_level >= gq.from and old_level <= gq.to
      local new_eligible = new_level >= gq.from and new_level <= gq.to
      if old_eligible ~= new_eligible then competition_scans[gq.id] = nil end
    end
  end
  prune_swho_queue()

  if swho_active then
    local has_current_target = false
    for _, state in ipairs(swho_active.targets) do
      if competition_scans[state.id] == state then
        has_current_target = true
        break
      end
    end
    if not has_current_target then swho_active.discard = true end
  end
end

local function state_allows_refresh(state)
  for _, allowed in ipairs(char_state) do
    if tonumber(state) == tonumber(allowed) then return true end
  end
  return false
end

create_window()

function OnPluginBroadcast(msg, id, name, text)
  if (id == '3e7dedbe37e44942dd46d264') then
    if (text=="char.status") then
      local old_level = tonumber(level) or 1
      local level_was_known = current_level_known
      local reported_level = tonumber(gmcp("char.status.level"))
      local new_level = reported_level or old_level
      level = new_level
      if reported_level then current_level_known = true end
      gmcp_state = gmcp("char.status.state")
      if new_level ~= old_level then
        invalidate_level_transition(old_level, new_level)
        if draw_gq_window then draw_gq_window(false) end
      elseif current_level_known ~= level_was_known then
        if draw_gq_window then draw_gq_window(false) end
      end
      if #swho_queue > 0 then schedule_swho_pump(0.1) end
    end
    if text == "char.base" and swho_active and swho_active.phase == "awaiting_identity" then
      try_start_swho_capture()
    end
    if text == "char.base" and ranges_capture and ranges_capture.phase == "awaiting_identity" then
      try_start_ranges_capture()
    end
    if text == "comm.tick" and state_allows_refresh(gmcp_state) then
      request_gq_list(false)
    end
  end
end

function OnPluginInstall()
  plugin_enabled = true
  connected = world_is_connected()
  create_window()
  reset_transient_state(true)
  save_preferences()
  if draw_gq_window then draw_gq_window(false) end
  if my_window and my_window.id and not auto_toggle and window_should_be_visible then
    my_window:show()
  end
  Note('GQ Dashboard installed. Type "gqshow" / "gqhide".')
  if connected then
    request_character_state()
    request_gq_list(false)
    request_gquest_ranges("lifecycle", gq_capture)
  end
end

function OnPluginEnable()
  plugin_enabled = true
  connected = world_is_connected()
  create_window()
  reset_transient_state(true)
  if draw_gq_window then draw_gq_window(false) end
  if my_window and my_window.id and not auto_toggle then
    if window_should_be_visible then my_window:show() else my_window:hide() end
  end
  if connected then
    request_character_state()
    request_gq_list(false)
    request_gquest_ranges("lifecycle", gq_capture)
  end
end

function OnPluginDisable()
  plugin_enabled = false
  sync_window_size()
  save_preferences()
  if my_window and my_window.id and WindowInfo(win, 1) ~= nil then
    movewindow.save_state(win)
    my_window:hide()
  end
  reset_transient_state(true)
  SaveState()
end

function OnPluginClose()
  plugin_enabled = false
  sync_window_size()
  save_preferences()
  if my_window and my_window.id and WindowInfo(win, 1) ~= nil then
    movewindow.save_state(win)
    my_window:hide()
  end
  reset_transient_state(true)
  SaveState()
end

function OnPluginConnect()
  connected = true
  reset_transient_state(true)
  create_window()
  if draw_gq_window then draw_gq_window(false) end
  request_character_state()
  request_gq_list(false)
  request_gquest_ranges("lifecycle", gq_capture)
end

function OnPluginDisconnect()
  connected = false
  current_level_known = false
  reset_transient_state(true)
  if draw_gq_window and my_window and my_window.id then draw_gq_window(false) end
end

function OnPluginThemeChange()
  sync_window_size()
  if draw_gq_window then draw_gq_window(false) end
end

function OnPluginSaveState()
  save_preferences()
  sync_window_size()
  if my_window and my_window.id then movewindow.save_state(win) end
end

-- convenience
function window_show()
  window_should_be_visible = true
  create_window()
  if draw_gq_window then draw_gq_window(false) end
  my_window:show()
end

function window_hide()
  window_should_be_visible = false
  if my_window and my_window.id then my_window:hide() end
end

function gq_list()
  request_gq_list(true)
end

function debug_gq()
  gqhistory = {}
  GQ_table = {
    " 9101 Less than 25 wins  145  160 Active        40       2",
    " 9102 25 to 199 wins      40   55 Active        60       0",
    " 9103 200 Wins or more   140  155 Active        80       1",
    " 9104 200 Wins or more   181  193 Preparing      4       0 ***",
  }
  suppress_competition_scan = true
  local ok, error_message = pcall(function() draw_gq_window(false) end)
  suppress_competition_scan = false
  if not ok then error(error_message) end
end
