local commands = {}
local notes = {}
local colour_notes = {}
local colour_note_calls = {}
local drawn = {}
local draw_calls = {}
local font_calls = {}
local line_calls = {}
local hotspots = {}
local trigger_groups = {}
local saved_variables = {
  gq_sound_on = "0",
  gq_auto_hide = "0",
  gq_filter_under25 = "0",
  gq_filter_25to199 = "0",
  gq_filter_200plus = "1",
  ["mw_gqdashboard_test-plugin_windowx"] = "25",
  ["mw_gqdashboard_test-plugin_windowy"] = "35",
  ["themed_miniwindow_heightgqdashboard_test-plugin"] = "40",
}
local timers = {}
local gmcp_packets = {}
local telnet_events = {}
local internal_triggers = {}
local blank_gags = {}
local windows = {}
local window_create_count = 0
local window_delete_count = 0
local window_hide_count = 0
local save_state_count = 0
local unique_number = 7000
local gmcp_level = 150
local gmcp_base_level = 150
local gmcp_name = "RuntimeTester"
local gmcp_state_value = 3
local gmcp_config_compact = "NO"
local gmcp_config_prompt = "ON"
local connected_value = true
local last_window_menu = nil
local mouse_absolute_x = nil
local mouse_absolute_y = nil
local miniwindows_locked = false

local function window_record(id)
  return windows[id]
end

package.preload["themed_miniwindows"] = function() return true end
package.preload["movewindow"] = function() return movewindow end
package.preload["gmcphelper"] = function() return true end
package.preload["tprint"] = function() return true end
package.preload["gag_next_blank_line"] = function() return true end

local original_dofile = dofile
local telnet_options_loaded = false
function dofile(path)
  if tostring(path):match("telnet_options%.lua$") then
    telnet_options_loaded = true
    return true
  end
  if tostring(path):match("aardwolf_colors%.lua$") then return true end
  return original_dofile(path)
end

function GetPluginID() return "test-plugin" end
function GetPluginInfo() return false end
function GetUniqueNumber()
  unique_number = unique_number + 1
  return unique_number
end
function GetInfo(code)
  if code == 281 then return 1200 end
  if code == 280 then return 800 end
  if code == 74 or code == 60 then return "" end
  return ""
end
function GetVariable(name) return saved_variables[name] end
function SetVariable(name, value) saved_variables[name] = tostring(value) end
function GetPluginVariable(_, name)
  if name == "lock_down_miniwindows" then return miniwindows_locked and "1" or "0" end
  return "0"
end
function IsConnected() return connected_value end
function IsPluginInstalled() return false end
function CallPlugin() end
function SetOption() end
function SaveState() save_state_count = save_state_count + 1 end
function Repaint() end
function StopEvaluatingTriggers() end

trigger_flag = {
  Enabled = 1,
  Temporary = 2,
  OneShot = 4,
  OmitFromOutput = 8,
  OmitFromLog = 16,
  KeepEvaluating = 32,
}
sendto = { script = 12 }
function AddTriggerEx(name, match, send, flags, colour, wildcard, sound, script, destination, sequence)
  internal_triggers[name] = {
    match = match,
    send = send,
    flags = flags,
    colour = colour,
    wildcard = wildcard,
    sound = sound,
    script = script,
    destination = destination,
    sequence = sequence,
  }
  return 0
end
function DeleteTrigger(name)
  internal_triggers[name] = nil
  return 0
end
function GagBlankLine(id, sequence) blank_gags[tostring(id)] = sequence end
function UngagBlankLine(id) blank_gags[tostring(id)] = nil end

level = 150
function gmcp(path)
  if path == "char.status.level" then return gmcp_level end
  if path == "char.status.state" then return gmcp_state_value end
  if path == "char.base.level" then return gmcp_base_level end
  if path == "char.base.name" then return gmcp_name end
  if path == "config.compact" then return gmcp_config_compact end
  if path == "config.prompt" then return gmcp_config_prompt end
  return nil
end

function Send_GMCP_Packet(packet)
  packet = tostring(packet)
  table.insert(gmcp_packets, packet)
  local compact = packet:match("^config compact%s+(%S+)$")
  local prompt = packet:match("^config prompt%s+(%S+)$")
  if compact then gmcp_config_compact = compact end
  if prompt then gmcp_config_prompt = prompt end
end

TELOPT_PAGING = 42
function TelnetOptionOff(option)
  table.insert(telnet_events, { action = "off", option = option })
end
function TelnetOptionOn(option)
  table.insert(telnet_events, { action = "on", option = option })
end

function WindowCreate(id, left, top, width, height)
  window_create_count = window_create_count + 1
  windows[id] = {
    id = id,
    left = tonumber(left) or 0,
    top = tonumber(top) or 0,
    width = tonumber(width) or 0,
    height = tonumber(height) or 0,
    visible = true,
  }
  return 0
end

function WindowDelete(id)
  if windows[id] then window_delete_count = window_delete_count + 1 end
  windows[id] = nil
  for hotspot_id in pairs(hotspots) do
    if hotspot_id == id .. "_resize" or hotspot_id == "titlemenu"
       or hotspot_id:match("^hotspot_") or hotspot_id:match("^players_") then
      hotspots[hotspot_id] = nil
    end
  end
  return 0
end

function WindowShow(id, visible)
  local record = assert(windows[id], "WindowShow called for a deleted window")
  record.visible = visible == true
  if not record.visible then window_hide_count = window_hide_count + 1 end
  return 0
end

function WindowResize(id, width, height)
  local record = assert(windows[id], "WindowResize called for a deleted window")
  record.width = tonumber(width)
  record.height = tonumber(height)
  return 0
end

local resize_during_callback
local resize_after_callback
function ThemedBasicWindow(id, left, top, width, height, _, _, _, _, during_callback, after_callback)
  resize_during_callback = during_callback
  resize_after_callback = after_callback
  local saved_width = tonumber(saved_variables["themed_miniwindow_width" .. id]) or width
  local saved_height = tonumber(saved_variables["themed_miniwindow_height" .. id]) or height
  local saved_left = tonumber(saved_variables["mw_" .. id .. "_windowx"]) or left
  local saved_top = tonumber(saved_variables["mw_" .. id .. "_windowy"]) or top
  WindowCreate(id, saved_left, saved_top, saved_width, saved_height)

  local window = {
    id = id,
    width = saved_width,
    height = saved_height,
    bodyright = saved_width - 3,
    bodybottom = saved_height - 3,
    windowinfo = { window_left = saved_left, window_top = saved_top },
  }
  function window:blank()
    drawn = {}
    draw_calls = {}
    line_calls = {}
  end
  function window:dress_window()
    hotspots[self.id .. "_resize"] = { cursor = 6 }
  end
  function window:show() WindowShow(self.id, true) end
  function window:hide() WindowShow(self.id, false) end
  function window:resize(new_width, new_height, still_dragging)
    self.width = new_width
    self.height = new_height
    self.bodyright = new_width - 3
    self.bodybottom = new_height - 3
    WindowResize(self.id, new_width, new_height)
    if still_dragging and resize_during_callback then resize_during_callback(self) end
    if not still_dragging and resize_after_callback then resize_after_callback(self) end
  end
  function window:delete()
    local id_to_delete = self.id
    if id_to_delete then WindowDelete(id_to_delete) end
    for key in pairs(self) do self[key] = nil end
  end
  window:dress_window()
  return window
end

Theme = { RESIZER_SIZE = 16 }
miniwin = {
  pos_stretch_to_view = 0,
  create_absolute_location = 2,
  cursor_hand = 11,
  hotspot_got_lh_mouse = 16,
  hotspot_got_rh_mouse = 32,
}
bit = { band = function(a, b) return (tonumber(a) or 0) & (tonumber(b) or 0) end }
movewindow = {
  save_state = function(id)
    local record = windows[id]
    if not record then return end
    saved_variables["mw_" .. id .. "_windowx"] = tostring(record.left)
    saved_variables["mw_" .. id .. "_windowy"] = tostring(record.top)
  end,
}

function EnableTriggerGroup(name, enabled) trigger_groups[name] = enabled end
function SendNoEcho(command) table.insert(commands, tostring(command)) end
function Send(command) table.insert(commands, tostring(command)) end
function DoAfterSpecial(delay, code)
  table.insert(timers, { delay = tonumber(delay) or 0, code = tostring(code) })
end

function WindowHotspotList()
  local ids = {}
  for id in pairs(hotspots) do table.insert(ids, id) end
  return ids
end
function WindowDeleteHotspot(_, id) hotspots[id] = nil end
function WindowAddHotspot(_, id, left, top, right, bottom, _, _, _, _, callback, tooltip, cursor)
  hotspots[id] = {
    left = left,
    top = top,
    right = right,
    bottom = bottom,
    callback = callback,
    tooltip = tooltip,
    cursor = cursor,
  }
end
function WindowFont(_, id, name, size, bold, italic, underline, strikeout, charset)
  table.insert(font_calls, {
    id = tostring(id),
    name = tostring(name),
    size = tonumber(size),
    bold = bold == true,
    italic = italic == true,
    underline = underline == true,
    strikeout = strikeout == true,
    charset = charset,
  })
end
function WindowText(_, font, text, left, top, right, bottom, colour)
  text = tostring(text)
  table.insert(drawn, text)
  table.insert(draw_calls, {
    font = font,
    text = text,
    left = tonumber(left),
    top = tonumber(top),
    right = tonumber(right),
    bottom = tonumber(bottom),
    colour = colour,
  })
end
function WindowTextWidth(_, font, text)
  local glyph_width = font == "f1b" and 7 or 6
  return #tostring(text) * glyph_width
end
function WindowLine(_, left, top, right, bottom, colour, pen, width)
  table.insert(line_calls, {
    left = tonumber(left),
    top = tonumber(top),
    right = tonumber(right),
    bottom = tonumber(bottom),
    colour = colour,
    pen = pen,
    width = tonumber(width),
  })
end
function WindowInfo(id, code)
  local record = windows[id]
  if not record then return nil end
  if code == 1 then return record.left end
  if code == 2 then return record.top end
  if code == 3 then return record.width end
  if code == 4 then return record.height end
  if code == 5 then return record.visible end
  if code == 14 or code == 15 then return 10 end
  if code == 17 then return mouse_absolute_x or (record.left + 10) end
  if code == 18 then return mouse_absolute_y or (record.top + 10) end
  return 0
end
function WindowDragHandler() end
function WindowPosition(id, x, y)
  local record = assert(windows[id], "WindowPosition called for a deleted window")
  record.left = tonumber(x)
  record.top = tonumber(y)
end
function WindowMenu(_, _, _, menu)
  last_window_menu = menu
  return ""
end
local colours = { white = 1, silver = 2, lime = 3, yellow = 4, red = 5 }
function ColourNameToRGB(name) return colours[tostring(name):lower()] or 0 end
function Note(text) table.insert(notes, tostring(text or "")) end
function ColourNote(foreground, background, text)
  text = tostring(text or "")
  table.insert(colour_notes, text)
  table.insert(colour_note_calls, {
    foreground = tostring(foreground or ""),
    background = tostring(background or ""),
    text = text,
  })
end
function PlaySound() end
function Simulate() error("gqdebug should not depend on trigger simulation") end

local this_file = debug.getinfo(1, "S").source:sub(2):gsub("\\", "/")
local test_dir = assert(this_file:match("^(.*)/"))
local plugin_path = test_dir .. "/../GQ_Dashboard.lua"
assert(loadfile(plugin_path))()
assert(telnet_options_loaded, "plugin did not load the standard telnet paging helpers")

local function assert_equal(actual, expected, message)
  if actual ~= expected then
    error(string.format(
      "%s: expected %s, got %s", message, tostring(expected), tostring(actual)
    ))
  end
end

local function assert_true(value, message)
  if not value then error(message) end
end

local function drawn_contains(needle)
  for _, text in ipairs(drawn) do
    if text:find(needle, 1, true) then return true end
  end
  local rows = {}
  for _, call in ipairs(draw_calls) do
    rows[call.top] = rows[call.top] or {}
    table.insert(rows[call.top], call)
  end
  for _, calls in pairs(rows) do
    table.sort(calls, function(left, right) return left.left < right.left end)
    local text = {}
    for _, call in ipairs(calls) do table.insert(text, call.text) end
    if table.concat(text):find(needle, 1, true) then return true end
  end
  return false
end

local function find_draw_call(text, top)
  for _, call in ipairs(draw_calls) do
    if call.text == tostring(text) and (top == nil or call.top == top) then return call end
  end
  error(string.format("No miniwindow draw matched %q at y=%s", tostring(text), tostring(top)))
end

local function find_font_call(id)
  for _, call in ipairs(font_calls) do
    if call.id == tostring(id) then return call end
  end
  error(string.format("No miniwindow font registration matched %q", tostring(id)))
end

local function draw_call_center(call)
  return call.left + WindowTextWidth("", call.font or "f1", call.text) / 2
end

local function assert_same_draw_center(header_text, value_text, message)
  local header = find_draw_call(header_text, 20)
  local value = find_draw_call(value_text, 42)
  assert_true(math.abs(draw_call_center(header) - draw_call_center(value)) <= 1, message)
end

local function draw_group_calls(text, top)
  local calls = {}
  for _, call in ipairs(draw_calls) do
    if call.top == top then table.insert(calls, call) end
  end
  table.sort(calls, function(left, right) return left.left < right.left end)
  for first = 1, #calls do
    local combined = ""
    local group = {}
    for last = first, #calls do
      combined = combined .. calls[last].text
      table.insert(group, calls[last])
      if combined == text then return group end
      if #combined >= #text then break end
    end
  end
  error(string.format("No miniwindow draw group matched %q at y=%s", tostring(text), tostring(top)))
end


local function find_draw_group(text, top)
  local group = draw_group_calls(text, top)
  return group[1], group[#group]
end

local function assert_same_draw_group_center(header_text, value_text, message)
  local header = find_draw_call(header_text, 20)
  local first, last = find_draw_group(value_text, 42)
  local left = first.left
  local right = last.left + WindowTextWidth("", last.font or "f1", last.text)
  assert_true(math.abs(draw_call_center(header) - ((left + right) / 2)) <= 1, message)
end

local function note_output()
  return table.concat(notes, "\n")
end

local function colour_note_count_since(start_index, foreground)
  local count = 0
  for index = start_index + 1, #colour_note_calls do
    if colour_note_calls[index].foreground == foreground then count = count + 1 end
  end
  return count
end

local function note_count_since(start_index, expected)
  local count = 0
  for index = start_index + 1, #notes do
    if notes[index] == expected then count = count + 1 end
  end
  return count
end

local function execute_timer_code(code)
  assert(load(code, "fake timer"))()
end

local function take_timer(pattern, newest)
  if newest then
    for index = #timers, 1, -1 do
      if timers[index].code:match(pattern) then
        return table.remove(timers, index).code
      end
    end
  else
    for index, timer in ipairs(timers) do
      if timer.code:match(pattern) then
        return table.remove(timers, index).code
      end
    end
  end
  error("No queued timer matched " .. tostring(pattern))
end

local function run_timer(pattern)
  local code = take_timer(pattern, false)
  execute_timer_code(code)
  return code
end

local function wrong_nonce(code)
  local replaced, count = code:gsub('%("[^"]+"', '("wrong-load"', 1)
  assert_equal(count, 1, "timer did not contain a quoted load nonce")
  return replaced
end

local gq_header = "Num   Type              From  To  Status     Timer Players"
local gq_separator = "----- ----------------- ---- ---- ---------- ----- -------"

local function complete_gq_list(rows)
  gq_capture_start(nil, gq_header)
  gq_capture_line(nil, gq_separator)
  for _, row in ipairs(rows) do gq_capture_line(nil, row) end
  gq_capture_end(nil, "")
end

local function latest_swho_triplet()
  for index = #commands, 2, -1 do
    if commands[index]:match("^swho%s") then
      local begin_command = commands[index - 1]
      local end_command = commands[index + 1]
      assert_true(begin_command ~= nil and begin_command:find("GQDASH_SWHO_BEGIN_", 1, true),
        "missing automatic begin marker")
      assert_true(end_command ~= nil and end_command:find("GQDASH_SWHO_END_", 1, true),
        "missing automatic end marker")
      local begin_marker = begin_command:match("(GQDASH_SWHO_BEGIN_%d+_%d+_%d+)$")
      local end_marker = end_command:match("(GQDASH_SWHO_END_%d+_%d+_%d+)$")
      return begin_marker, commands[index], end_marker, begin_command, end_command
    end
  end
  error("automatic swho command triplet was not sent")
end

local function latest_ranges_triplet()
  for index = #commands, 2, -1 do
    if commands[index] == "gquest ranges" then
      local begin_command = commands[index - 1]
      local end_command = commands[index + 1]
      assert_true(begin_command ~= nil and begin_command:find("GQDASH_RANGES_BEGIN_", 1, true),
        "missing ranges begin marker")
      assert_true(end_command ~= nil and end_command:find("GQDASH_RANGES_END_", 1, true),
        "missing ranges end marker")
      local begin_marker = begin_command:match("(GQDASH_RANGES_BEGIN_%d+_%d+_%d+)$")
      local end_marker = end_command:match("(GQDASH_RANGES_END_%d+_%d+_%d+)$")
      local prefix = begin_command:match("^echo self ") and (gmcp_name .. " echo> ") or ""
      return prefix .. begin_marker, prefix .. end_marker
    end
  end
  error("automatic gquest ranges command triplet was not sent")
end

local ranges_fixture = {}
do
  local fixture_file = assert(io.open(test_dir .. "/../samples/gq-dashboard-ranges.txt", "rb"))
  for line in fixture_file:lines() do table.insert(ranges_fixture, line) end
  fixture_file:close()
end

local function complete_ranges(options)
  options = options or {}
  local begin_marker, end_marker = latest_ranges_triplet()
  ranges_marker_start(nil, begin_marker)
  assert_equal(trigger_groups.GQ_RANGES_CAPTURE, true, "ranges body capture did not start")
  local data_row = 0
  local group_separator = 0
  for _, line in ipairs(ranges_fixture) do
    if options.footer and line:match("^Cycle Complete:") then line = options.footer end
    if line:match("^%s*%d+%s+%d+%s+") then data_row = data_row + 1 end
    if line:match("^%s*%-+%s*$") then
      group_separator = group_separator + 1
      if group_separator ~= options.skip_group_separator then
        ranges_capture_line(nil, line)
      end
      if group_separator == options.duplicate_group_separator then
        ranges_capture_line(nil, line)
      end
    elseif data_row ~= options.skip_row or not line:match("^%s*%d+%s+%d+%s+") then
      ranges_capture_line(nil, line)
    end
  end
  ranges_marker_end(nil, end_marker)
  assert_equal(trigger_groups.GQ_RANGES_CAPTURE, false, "ranges body capture did not stop")
end

local function complete_swho(lines, prefix)
  local begin_marker, _, end_marker = latest_swho_triplet()
  swho_marker_start(nil, (prefix or "") .. begin_marker)
  assert_equal(trigger_groups.GQ_SWHO_HEADER, true, "owned header capture did not start")
  for _, line in ipairs(lines) do swho_capture_line(nil, line) end
  swho_marker_end(nil, (prefix or "") .. end_marker)
  assert_equal(trigger_groups.GQ_SWHO_HEADER, false, "owned header capture did not stop")
  assert_equal(trigger_groups.GQ_SWHO_BODY, false, "owned body capture did not stop")
end

local win = "gqdashboard_test-plugin"
assert_true(window_record(win) ~= nil, "initial themed window was not created")
assert_equal(window_create_count, 1, "initial window creation count")
assert_equal(my_window.min_drag_width, 330, "compact minimum width")
assert_equal(my_window.min_drag_height, 60, "compact minimum height")
assert_equal(WindowInfo(win, 4), 60, "minimum height correction")
assert_equal(saved_variables["themed_miniwindow_height" .. win], "60", "saved minimum height correction")
assert_equal(sound_on, false, "saved sound preference was not loaded")
assert_equal(toggle201, true, "saved 200+ filter preference was not loaded")
local boundary_font = find_font_call("f1b")
assert_equal(boundary_font.name, "Dina", "boundary font family")
assert_equal(boundary_font.size, 8, "boundary font size")
assert_equal(boundary_font.bold, true, "boundary font was not bold")
assert_equal(boundary_font.italic, false, "boundary font was unexpectedly italic")

local xml_file = assert(io.open(test_dir .. "/../GQ_Dashboard.xml", "rb"))
local xml = xml_file:read("*a")
xml_file:close()
assert_true(xml:find('name="GQ_Dashboard"', 1, true) ~= nil, "XML plugin name was not renamed")
assert_true(xml:find('id="300566e7f39f483cb01a2d6e"', 1, true) ~= nil, "XML plugin id was not replaced")
assert_true(xml:find('version="3.0"', 1, true) ~= nil, "XML version was not bumped to 3.0")
assert_true(xml:find('"GQ_Dashboard.lua"', 1, true) ~= nil, "XML does not load the renamed Lua file")
assert_true(xml:find('script="gq_capture_start"', 1, true) ~= nil, "missing staged GQ header callback")
assert_true(xml:find('script="gq_capture_invalid_line"', 1, true) ~= nil, "missing malformed GQ guard")
assert_true(xml:find('group="GQ_SWHO_HEADER"', 1, true) ~= nil, "missing staged swho header group")
assert_true(xml:find("You echo GQDASH_", 1, true) ~= nil, "missing immortal echo confirmation gag")
assert_true(xml:find("GQDASH_SWHO_BEGIN_", 1, true) ~= nil, "missing ordered begin marker trigger")
assert_true(xml:find("GQDASH_SWHO_END_", 1, true) ~= nil, "missing ordered end marker trigger")
assert_true(xml:find("GQDASH_RANGES_BEGIN_", 1, true) ~= nil, "missing ranges begin marker trigger")
assert_true(xml:find("GQDASH_RANGES_END_", 1, true) ~= nil, "missing ranges end marker trigger")
assert_true(xml:find("\\[[^\\]]+\\]", 1, true) ~= nil,
  "swho player trigger rejects custom or superhero WHO fields")
assert_true(xml:find('group="GQ_SWHO_BODY"%s+match="%^%.%*%$"') == nil,
  "catch-all swho gag would hide unrelated output")

-- A normal staged list produces one swho triplet, validates ownership, and
-- preserves the intentional minimum-minus-one lower bound.
complete_gq_list({
  " 9103 200 Wins or more   140  155 Active        80       1",
})
local commands_while_ranges_active = #commands
run_timer("^swho_run_pump")
assert_equal(#commands, commands_while_ranges_active,
  "swho overlapped the in-flight ranges fence")
assert_equal(#telnet_events, 2, "ranges capture did not bracket paging exactly once")
assert_equal(telnet_events[1].action, "off", "ranges capture did not disable paging first")
assert_equal(telnet_events[1].option, TELOPT_PAGING, "ranges capture disabled the wrong option")
assert_equal(telnet_events[2].action, "on", "ranges capture did not restore paging")
complete_ranges()
assert_true(drawn_contains("Plyrs"), "compact Plyrs header was not rendered")
assert_true(drawn_contains("Cycle"), "Cycle header was not rendered")
assert_true(drawn_contains("34(+1,+6,+16)+"), "initial 200+ cycle summary was wrong")
assert_true(hotspots.cycle_200plus_9103 ~= nil, "active-row Cycle hotspot missing")
assert_true(hotspots.cycle_200plus_9103.tooltip:find("Bold:", 1, true) ~= nil,
  "Cycle tooltip omitted the final-level legend")
assert_true(hotspots.cycle_200plus_9103.tooltip:find("Trailing +", 1, true) ~= nil,
  "Cycle tooltip omitted the fourth-range legend")
assert_true(hotspots.cycle_200plus_9103.tooltip:find("has not run", 1, true) ~= nil,
  "Cycle tooltip described the plus marker backward")
local notes_before_cycle = #notes
local colour_notes_before_cycle = #colour_notes
cycle_mouseup(16, "cycle_200plus_9103")
local cycle_details = table.concat(notes, "\n", notes_before_cycle + 1)
  .. "\n" .. table.concat(colour_notes, "\n", colour_notes_before_cycle + 1)
assert_true(cycle_details:find("34 ranges remain in this cycle.", 1, true) ~= nil,
  "Cycle details omitted the remaining count")
assert_true(cycle_details:find("  151-165", 1, true) ~= nil,
  "Cycle details omitted the first relevant future range")
assert_true(cycle_details:find("  201-201", 1, true) ~= nil,
  "Cycle details omitted the last relevant future range")
assert_true(cycle_details:find("  131-145", 1, true) == nil,
  "Cycle details included an already-outleveled range")
assert_equal(colour_note_count_since(colour_notes_before_cycle, "lime"), 0,
  "future-only Cycle details highlighted a range as immediately joinable")
local expected_future_ranges = {
  "  151-165", "  156-170", "  166-180", "  171-185", "  176-190",
  "  181-193", "  191-199", "  191-199", "  200-201", "  201-201",
}
local expected_counts = {}
for _, range_text in ipairs(expected_future_ranges) do
  expected_counts[range_text] = (expected_counts[range_text] or 0) + 1
end
for range_text, expected_count in pairs(expected_counts) do
  assert_equal(note_count_since(notes_before_cycle, range_text), expected_count,
    "Cycle details did not preserve every relevant range and duplicate")
end
local commands_before_pump = #commands
local gmcp_before_pump = #gmcp_packets
local telnet_before_pump = #telnet_events
local pump_code = take_timer("^swho_run_pump", false)
execute_timer_code(wrong_nonce(pump_code))
assert_equal(#commands, commands_before_pump, "wrong-nonce pump sent a command")
execute_timer_code(pump_code)
local begin_marker, swho_command = latest_swho_triplet()
assert_equal(swho_command, "swho 11 139 155", "intentional competition lower bound")
assert_equal(#commands - commands_before_pump, 3, "automatic swho was not one command triplet")
assert_equal(gmcp_packets[gmcp_before_pump + 1], "config compact YES", "compact mode was not enabled quietly")
assert_equal(gmcp_packets[gmcp_before_pump + 2], "config prompt OFF", "prompt was not disabled quietly")
assert_equal(gmcp_packets[gmcp_before_pump + 3], "config compact NO", "compact setting was not restored")
assert_equal(gmcp_packets[gmcp_before_pump + 4], "config prompt ON", "prompt setting was not restored")
assert_equal(#telnet_events, telnet_before_pump + 2, "swho did not bracket paging exactly once")
assert_equal(telnet_events[telnet_before_pump + 1].action, "off", "swho did not disable paging first")
assert_equal(telnet_events[telnet_before_pump + 2].action, "on", "swho did not restore paging")
local internal_echo_count = 0
for _, trigger in pairs(internal_triggers) do
  internal_echo_count = internal_echo_count + 1
  assert_true(trigger.match:match("^You entered: ") ~= nil, "internal command confirmation gag was too broad")
end
assert_equal(internal_echo_count, 3, "internal command confirmation gag count")

local swho_timeout_code = take_timer("^swho_capture_timeout", true)
execute_timer_code(wrong_nonce(swho_timeout_code))
swho_capture_line(nil, "[ 150  Half   War] [     999 ] BeforeBeginMarker")
swho_marker_start(nil, begin_marker)
assert_equal(trigger_groups.GQ_SWHO_HEADER, true, "swho did not enter header phase")
assert_true(trigger_groups.GQ_SWHO_BODY ~= true, "body capture started before the header")
swho_capture_line(nil, "[ 150  Half   War] [     999 ] BeforeHeader")
swho_capture_line(nil, "Who list sorted by : Gquests Won")
assert_equal(trigger_groups.GQ_SWHO_HEADER, false, "header phase remained enabled")
assert_equal(trigger_groups.GQ_SWHO_BODY, true, "body phase did not start after header")
swho_capture_line(nil, "[   SUPERHERO   ] [     450 ] QualifyingOne")
swho_capture_line(nil, "[ 149  Half   War] [     180 ] NotQualifying")
swho_capture_line(nil, "[ 151  Half   War] [     296 ] QualifyingTwo")
swho_capture_line(nil, "Players found: [3], Max this reboot: [238], Connections this reboot: [2749]")
swho_capture_line(nil, "Players invis: [0], Max on ever: [853]")
local commands_before_queued_ranges = #commands
cycle_mouseup(32, "cycle_200plus_9103")
assert_equal(#commands, commands_before_queued_ranges,
  "ranges refresh overlapped the in-flight swho fence")
local _, _, end_marker = latest_swho_triplet()
swho_marker_end(nil, end_marker)
local commands_before_pending_ranges = #commands
run_timer("^swho_run_pump")
assert_equal(#commands, commands_before_pending_ranges,
  "queued swho work bypassed a pending ranges refresh")
gmcp_config_compact = "YES"
gmcp_config_prompt = "OFF"
local gmcp_before_pending_ranges = #gmcp_packets
run_timer("^ranges_run_pending")
assert_equal(#commands, commands_before_pending_ranges + 3,
  "queued ranges refresh did not start after swho completed")
assert_equal(gmcp_packets[gmcp_before_pending_ranges + 1], "config compact YES",
  "queued ranges did not preserve the original compact baseline")
assert_equal(gmcp_packets[gmcp_before_pending_ranges + 2], "config prompt OFF",
  "queued ranges did not preserve the original prompt baseline")
assert_equal(gmcp_packets[gmcp_before_pending_ranges + 3], "config compact NO",
  "queued ranges did not restore the original compact baseline")
assert_equal(gmcp_packets[gmcp_before_pending_ranges + 4], "config prompt ON",
  "queued ranges did not restore the original prompt baseline")
complete_ranges()
run_timer("^swho_run_pump")
assert_true(drawn_contains("1(2)"), "validated competition count was not rendered")
assert_true(not drawn_contains("1(3)"), "pre-header row was incorrectly counted")
assert_true(hotspots.players_9103 ~= nil, "Players hotspot missing")
assert_true(hotspots.hotspot_9103.right < hotspots.players_9103.left,
  "row and Players hotspots overlap")
assert_true(hotspots.players_9103.right < hotspots.cycle_200plus_9103.left,
  "Players and Cycle hotspots overlap")
assert_equal(hotspots.hotspot_9103.right, 284, "wide row hotspot ended outside its cell")
assert_equal(hotspots.players_9103.left, 285, "wide Plyrs column did not receive its one-character nudge")
assert_equal(hotspots.players_9103.right, 354, "wide Plyrs hotspot ended outside its cell")
assert_equal(hotspots.cycle_200plus_9103.left, 355, "wide Cycle column started at the wrong boundary")
assert_equal(hotspots.cycle_200plus_9103.right, 461, "Cycle hotspot did not reserve resize-grip space")
local wide_cycle_left = hotspots.cycle_200plus_9103.left
assert_equal(hotspots.players_9103.cursor, 11, "Players hotspot did not use the hand cursor")
assert_equal(hotspots.cycle_200plus_9103.cursor, 11, "Cycle hotspot did not use the hand cursor")
assert_true(hotspots.players_9103.bottom <= my_window.min_drag_height,
  "minimum height clips the Players hotspot")
assert_equal(#line_calls, 1, "table redraw did not produce exactly one divider")
assert_equal(line_calls[1].left, 5, "divider did not start at the table edge")
assert_equal(line_calls[1].right, 461, "divider did not stop before the resize grip")
assert_equal(line_calls[1].top, 39, "divider used the wrong vertical position")
assert_equal(line_calls[1].width, 1, "divider was not one pixel thick")
assert_true(not drawn_contains("----"), "legacy dashed separator was still rendered")
assert_same_draw_center("Num", "9103", "Num value was not centered")
assert_same_draw_center("Tier", "200+", "Tier value was not centered")
assert_same_draw_center("Levels", "140-155", "Levels value was not centered")
assert_same_draw_center("Status", "Active", "Status value was not centered")
assert_same_draw_center("Tmr", "80", "Tmr value was not centered")
assert_same_draw_center("Plyrs", "1(2)", "Plyrs value was not centered")
assert_same_draw_center("Cycle", "34(+1,+6,+16)+", "Cycle value was not centered")
assert_equal(next(internal_triggers), nil, "internal command confirmation gags were not deleted")
assert_equal(next(blank_gags), nil, "compact transition blank gag was not deleted")

-- Dragging honors the lock and keeps the current full dimensions in the pane.
local left_before_locked_drag = WindowInfo(win, 1)
miniwindows_locked = true
mousedown_drag(16, "titlemenu")
mouse_absolute_x = 2000
mouse_absolute_y = 2000
dragmove(16, "titlemenu")
assert_equal(WindowInfo(win, 1), left_before_locked_drag, "locked miniwindow moved")
miniwindows_locked = false
dragmove(16, "titlemenu")
assert_equal(WindowInfo(win, 1), 1200 - WindowInfo(win, 3), "right-edge drag clipped current width")
assert_equal(WindowInfo(win, 2), 800 - WindowInfo(win, 4), "bottom-edge drag clipped current height")
assert_equal(my_window.windowinfo.window_left, WindowInfo(win, 1), "drag did not synchronize helper left")
assert_equal(my_window.windowinfo.window_top, WindowInfo(win, 2), "drag did not synchronize helper top")
dragrelease(16, "titlemenu")
mouse_absolute_x = nil
mouse_absolute_y = nil

local notes_before_details = #notes
players_mouseup(16, "players_9103")
local details = table.concat(notes, "\n", notes_before_details + 1)
assert_true(details:find("QualifyingOne", 1, true) ~= nil, "first qualifying row missing")
assert_true(details:find("QualifyingTwo", 1, true) ~= nil, "second qualifying row missing")
assert_true(details:find("BeforeHeader", 1, true) == nil, "pre-header row was displayed")
assert_true(details:find("NotQualifying", 1, true) == nil, "wrong tier row displayed")

-- A stable list does not rescan.
local stable_command_count = #commands
complete_gq_list({
  " 9103 200 Wins or more   140  155 Extended      79       1",
})
run_timer("^swho_run_pump")
assert_equal(#commands, stable_command_count, "stable GQ was scanned twice")
find_draw_call("Ext", 42)

-- Immortals use echo self; the XML hides its server confirmation line.
gmcp_level = 185
gmcp_base_level = 202
OnPluginBroadcast(0, "3e7dedbe37e44942dd46d264", "", "char.status")
complete_gq_list({
  " 9200 200 Wins or more   181  193 Preparing      4       0 ***",
})
local commands_while_new_gq_ranges_active = #commands
run_timer("^swho_run_pump")
assert_equal(#commands, commands_while_new_gq_ranges_active,
  "swho overlapped the new-GQ ranges refresh")
complete_ranges()
gmcp_base_level = nil
local commands_before_missing_base = #commands
run_timer("^swho_run_pump")
assert_equal(#commands, commands_before_missing_base,
  "missing char.base incorrectly used mortal echo syntax")
gmcp_base_level = 202
OnPluginBroadcast(0, "3e7dedbe37e44942dd46d264", "", "char.base")
local _, immortal_swho, _, immortal_begin, immortal_end = latest_swho_triplet()
assert_equal(immortal_swho, "swho 11 180 193", "immortal swho range")
assert_true(immortal_begin:match("^echo self GQDASH_SWHO_BEGIN_"), "immortal begin marker did not use echo self")
assert_true(immortal_end:match("^echo self GQDASH_SWHO_END_"), "immortal end marker did not use echo self")

-- A footer-count mismatch fails closed, and a Players click queues a retry.
complete_swho({
  "Who list sorted by : Gquests Won",
  "[ 185  Half   War] [     450 ] OnlyOneRow",
  "Players found: [2], Max this reboot: [238], Connections this reboot: [2749]",
  "Players invis: [0], Max on ever: [853]",
}, gmcp_name .. " echo> ")
assert_true(drawn_contains("34(-14,-9,-4)-"), "level-185 200+ cycle calculation was wrong")
find_draw_call("Prep", 42)
assert_equal(find_draw_call("-14", 42).colour, colours.lime,
  "current Cycle offset was not highlighted")
assert_equal(find_draw_call("-14", 42).font, "f1b",
  "final-level Cycle offset was not bold")
assert_equal(find_draw_call("-9", 42).font, "f1",
  "non-boundary Cycle offset used the bold font")
assert_equal(find_draw_call(")-", 42).colour, colours.white,
  "fourth-range marker inherited the row or eligibility colour")
assert_equal(find_draw_call(")-", 42).font, "f1",
  "fourth-range marker inherited the boundary font")
assert_same_draw_group_center("Cycle", "34(-14,-9,-4)-",
  "mixed-font Cycle value was not centered")
gmcp_level = 191
OnPluginBroadcast(0, "3e7dedbe37e44942dd46d264", "", "char.status")
assert_true(drawn_contains("34(-10,+0,+0)+"), "duplicate 191-199 ranges were not counted independently")
assert_equal(find_draw_call("-10", 42).font, "f1",
  "non-boundary level-191 offset was styled as a final-level warning")
gmcp_level = 185
OnPluginBroadcast(0, "3e7dedbe37e44942dd46d264", "", "char.status")
assert_true(drawn_contains("0(?)"), "incomplete response was not marked failed")
players_mouseup(16, "players_9200")
assert_true(drawn_contains("0(...)"), "failed Players click did not queue a retry")
assert_true(note_output():find("retry queued", 1, true) ~= nil, "retry feedback missing")
run_timer("^swho_run_pump")
complete_swho({
  "Players found: [0], Max this reboot: [238], Connections this reboot: [2749]",
  "Players invis: [0], Max on ever: [853]",
}, gmcp_name .. " echo> ")
assert_true(drawn_contains("0(0)"), "defensive headerless-zero response failed")
gmcp_base_level = 150

-- Malformed and timed-out staged GQ lists retain the last complete table.
local previous_row = GQ_table[1]
gq_capture_start(nil, gq_header)
gq_capture_line(nil, gq_separator)
gq_capture_line(nil, " 9300 200 Wins or more    25   36 Active        80       0")
  gq_capture_invalid_line(nil, "123 malformed numeric output")
gq_capture_end(nil, "")
assert_equal(GQ_table[1], previous_row, "malformed GQ response replaced complete data")

gq_capture_start(nil, gq_header)
gq_capture_line(nil, gq_separator)
gq_capture_line(nil, " 9301 200 Wins or more    25   36 Active        80       0")
local gq_timeout_code = take_timer("^gq_capture_timeout", true)
execute_timer_code(wrong_nonce(gq_timeout_code))
assert_equal(trigger_groups.GQ_CAPTURE, true, "wrong-nonce GQ timer ended capture")
execute_timer_code(gq_timeout_code)
assert_equal(trigger_groups.GQ_CAPTURE, false, "GQ watchdog left capture enabled")
assert_equal(GQ_table[1], previous_row, "timed-out GQ response replaced complete data")

-- Repeated ticks coalesce to one ordinary gq list command.
gmcp_level = 150
gmcp_state_value = 3
OnPluginBroadcast(0, "3e7dedbe37e44942dd46d264", "", "char.status")
local before_ticks = #commands
OnPluginBroadcast(0, "3e7dedbe37e44942dd46d264", "", "comm.tick")
OnPluginBroadcast(0, "3e7dedbe37e44942dd46d264", "", "comm.tick")
assert_equal(#commands, before_ticks + 1, "duplicate tick list request was not coalesced")
assert_equal(commands[#commands], "gq list", "tick sent the wrong refresh command")
local automatic_gq_echo_gags = 0
for _, trigger in pairs(internal_triggers) do
  if trigger.match == "You entered: gq list" then automatic_gq_echo_gags = automatic_gq_echo_gags + 1 end
end
assert_equal(automatic_gq_echo_gags, 1, "automatic gq list echocommand was not gagged exactly once")

-- Six stable eligible GQs alert once each, not again on the next list.
local six_rows = {}
for id = 9401, 9406 do
  table.insert(six_rows, string.format(
    " %d 200 Wins or more   140  160 Active        80       %d", id,
    id == 9401 and 100 or 0
  ))
end
local alerts_before = #colour_notes
complete_gq_list(six_rows)
assert_true(drawn_contains("100(...)"), "three-digit Players loading value was not rendered")
assert_equal(hotspots.cycle_200plus_9401.left, wide_cycle_left,
  "three-digit Players value changed the wide Cycle boundary")
my_window:resize(330, 60, false)
assert_true(drawn_contains("100(...)"),
  "three-digit Players loading value disappeared at minimum width")
assert_equal(hotspots.hotspot_9401.right, 171,
  "minimum-width row hotspot ended outside its cell")
assert_equal(hotspots.players_9401.left, 172,
  "minimum-width Plyrs column started at the wrong boundary")
assert_equal(hotspots.players_9401.right, 220,
  "minimum-width Plyrs hotspot ended outside its cell")
assert_equal(hotspots.cycle_200plus_9401.left, 221,
  "minimum-width Cycle column started at the wrong boundary")
assert_equal(hotspots.cycle_200plus_9401.right, 311,
  "minimum-width Cycle hotspot entered the resize grip")
assert_true(hotspots.players_9401.right < hotspots.cycle_200plus_9401.left,
  "minimum-width Players and Cycle hotspots overlap")
assert_true(hotspots.cycle_200plus_9401.right - hotspots.cycle_200plus_9401.left
  >= WindowTextWidth("", "f1", "00(-14,-14,-14)"),
  "minimum-width Cycle cell cannot fit its longest supported label")
assert_equal(#line_calls, 1, "minimum-width redraw duplicated the divider")
assert_equal(line_calls[1].right, 311, "minimum-width divider entered the resize grip")
assert_same_draw_center("Tmr", "80", "minimum-width Tmr value was not centered")
assert_same_draw_center("Plyrs", "100(...)", "minimum-width Plyrs value was not centered")
my_window:resize(480, 60, false)
assert_equal(hotspots.cycle_200plus_9401.left, wide_cycle_left,
  "wide redraw did not restore the responsive Cycle boundary")
assert_equal(#line_calls, 1, "wide redraw duplicated the divider")
assert_equal(line_calls[1].right, 461, "wide divider did not stop before the resize grip")
complete_ranges()
my_window:resize(330, 60, false)
assert_true(drawn_contains("34(+1,+6,+16)+"),
  "normal fourth-range marker disappeared at minimum width")
my_window:resize(480, 60, false)
local alerts_after_first = #colour_notes
complete_gq_list(six_rows)
local alerts_after_second = #colour_notes
assert_equal(alerts_after_first - alerts_before, 18, "six new GQ alerts")
assert_equal(alerts_after_second - alerts_after_first, 0, "stable six-GQ list alerted again")

-- Parsed row IDs and modifier clicks remain usable.
local command_count_before_click = #commands
mouseup(16 + 4, "hotspot_9401")
assert_equal(#commands, command_count_before_click + 1, "modified left click was ignored")
assert_equal(commands[#commands], "gq info 9401", "row click used the wrong parsed ID")

-- Debug draws its fixture directly and does not rely on capture triggers.
local commands_before_debug = #commands
debug_gq()
assert_equal(#GQ_table, 4, "debug fixture row count")
assert_true(drawn_contains("9104"), "debug fixture was not rendered")
assert_equal(#commands, commands_before_debug, "debug fixture sent a server command")

-- Every preference is stored as a normalized boolean and reflected in the menu.
togglesound()
togglewin()
toggle_25()
toggle_200()
toggle_201()
assert_equal(saved_variables.gq_sound_on, "1", "sound preference was not saved")
assert_equal(saved_variables.gq_auto_hide, "1", "auto-hide preference was not saved")
assert_equal(saved_variables.gq_filter_under25, "1", "under-25 preference was not saved")
assert_equal(saved_variables.gq_filter_25to199, "1", "25-199 preference was not saved")
assert_equal(saved_variables.gq_filter_200plus, "0", "200+ preference was not saved")
assert_true(drawn_contains("45(-14,-4,+1)+"), "under-25 Cycle calculation was wrong")
assert_true(drawn_contains("38(-14,-4,+6)-"), "25-199 Cycle calculation was wrong")
gmcp_level = 201
OnPluginBroadcast(0, "3e7dedbe37e44942dd46d264", "", "char.status")
assert_true(drawn_contains("45(-15,-1,+0)"), "under-25 level-201 calculation was wrong")
assert_true(drawn_contains("38(-15,-1)"), "25-199 level-201 calculation was wrong")
gmcp_level = 150
OnPluginBroadcast(0, "3e7dedbe37e44942dd46d264", "", "char.status")
menu_mouseup(32, "titlemenu")
assert_true(last_window_menu:find("|+Auto Hide", 1, true) ~= nil, "auto-hide menu check missing")
assert_true(last_window_menu:find("|+24 Wins or Fewer", 1, true) ~= nil, "under-25 menu check missing")
assert_true(last_window_menu:find("|200 Wins or More", 1, true) ~= nil, "disabled 200+ menu state wrong")
assert_true(save_state_count >= 5, "preference toggles did not persist plugin state")
for name, value in pairs(saved_variables) do
  assert_true(not tostring(value):find("Qualifying", 1, true), "snapshot leaked into saved variable " .. name)
end

-- Enabled tiers with no active GQ receive compact summary rows. Cycle clicks
-- never join a GQ: left shows details and right refreshes the ranges table.
complete_gq_list({})
assert_true(hotspots.cycle_under25_summary ~= nil, "under-25 Cycle summary row missing")
assert_true(hotspots.cycle_25to199_summary ~= nil, "25-199 Cycle summary row missing")
assert_equal(hotspots.cycle_under25_summary.left, wide_cycle_left,
  "summary and active Cycle columns were not aligned")
assert_equal(hotspots.cycle_under25_summary.right, 461,
  "summary Cycle hotspot entered the resize grip")
assert_same_draw_center("Status", "NA", "summary status was not centered")
assert_same_draw_group_center("Cycle", "45(-14,-4,+1)+", "summary Cycle value was not centered")
local notes_before_summary = #notes
local colour_notes_before_summary = #colour_notes
cycle_mouseup(16, "cycle_under25_summary")
local summary_details = table.concat(notes, "\n", notes_before_summary + 1)
  .. "\n" .. table.concat(colour_notes, "\n", colour_notes_before_summary + 1)
assert_true(summary_details:find("GQ cycle: fewer than 25 GQ wins", 1, true) ~= nil,
  "Cycle summary click did not show tier details")
assert_equal(colour_note_count_since(colour_notes_before_summary, "lime"), 2,
  "Cycle details did not highlight exactly the immediately joinable ranges")
assert_true(summary_details:find("  136-150", 1, true) ~= nil
  and summary_details:find("  146-160", 1, true) ~= nil,
  "Cycle details omitted an immediately joinable range")
assert_true(summary_details:find("  201-201", 1, true) ~= nil,
  "Cycle details omitted a future relevant range")
local commands_before_cycle_refresh = #commands
cycle_mouseup(32, "cycle_under25_summary")
assert_equal(#commands, commands_before_cycle_refresh + 3, "Cycle refresh was not one fenced triplet")
assert_equal(commands[#commands - 1], "gquest ranges", "Cycle right-click sent the wrong command")
local ranges_timeout_code = take_timer("^ranges_capture_timeout", true)
execute_timer_code(wrong_nonce(ranges_timeout_code))
complete_ranges({ footer = "Cycle Complete:     10.00%     24.00%     30.00%" })
assert_true(drawn_contains("45(-14,-4,+1)+"), "failed ranges refresh discarded the last good snapshot")
for _, call in ipairs(draw_group_calls("45(-14,-4,+1)+", 42)) do
  assert_equal(call.colour, colours.yellow,
    "stale Cycle value did not use the all-yellow warning state")
end
local notes_before_stale = #notes
local colour_notes_before_stale = #colour_notes
cycle_mouseup(16, "cycle_under25_summary")
local stale_details = table.concat(notes, "\n", notes_before_stale + 1)
  .. "\n" .. table.concat(colour_notes, "\n", colour_notes_before_stale + 1)
assert_true(stale_details:find("latest refresh failed", 1, true) ~= nil,
  "stale Cycle snapshot was not explained")
cycle_mouseup(32, "cycle_under25_summary")
complete_ranges()

-- Separators must occur after the exact five-row groups. A missing first
-- separator plus a duplicate second one still totals nine, but must fail.
cycle_mouseup(32, "cycle_under25_summary")
complete_ranges({ skip_group_separator = 1, duplicate_group_separator = 2 })
assert_true(drawn_contains("45(-14,-4,+1)+"),
  "malformed separator positions replaced the last good snapshot")

-- A real timeout also preserves the last complete snapshot and releases the
-- ranges trigger group so the Cycle cell can retry.
cycle_mouseup(32, "cycle_under25_summary")
local real_ranges_timeout = take_timer("^ranges_capture_timeout", true)
execute_timer_code(real_ranges_timeout)
assert_equal(trigger_groups.GQ_RANGES_CAPTURE, false,
  "ranges timeout left the body capture enabled")
assert_true(drawn_contains("45(-14,-4,+1)+"),
  "ranges timeout discarded the last good snapshot")
cycle_mouseup(32, "cycle_under25_summary")
complete_ranges()

-- Disconnect clears transient state and reconnect sends one char request plus
-- one ordinary gq list command.
OnPluginDisconnect()
assert_equal(#GQ_table, 0, "disconnect retained stale GQ rows")
assert_equal(trigger_groups.GQ_CAPTURE, false, "disconnect left GQ capture enabled")
assert_equal(trigger_groups.GQ_RANGES_CAPTURE, false, "disconnect left ranges capture enabled")
assert_equal(trigger_groups.GQ_SWHO_HEADER, false, "disconnect left swho header enabled")
assert_equal(trigger_groups.GQ_SWHO_BODY, false, "disconnect left swho body enabled")
assert_true(hotspots.cycle_under25_summary.tooltip:find("unavailable while disconnected", 1, true) ~= nil,
  "disconnected Cycle tooltip still claimed a refresh was running")
local commands_while_disconnected = #commands
local notes_while_disconnected = #notes
cycle_mouseup(32, "cycle_under25_summary")
assert_equal(#commands, commands_while_disconnected, "disconnected Cycle click sent a command")
assert_true(notes[#notes]:find("unavailable while disconnected", 1, true) ~= nil
  and #notes == notes_while_disconnected + 1,
  "disconnected Cycle click did not explain why refresh is unavailable")
gmcp_level = nil
local before_connect = #commands
OnPluginConnect()
assert_equal(#commands, before_connect + 5, "connect sent an unexpected number of refresh commands")
assert_equal(commands[before_connect + 1], "protocols gmcp sendchar", "connect did not request character state")
assert_equal(commands[before_connect + 2], "gq list", "connect did not request one fresh GQ list")
assert_equal(commands[#commands - 1], "gquest ranges", "connect did not request one ranges snapshot")
complete_gq_list({})
complete_ranges()
assert_true(drawn_contains("45(?)"), "unknown current level was not shown explicitly")
gmcp_level = 150
OnPluginBroadcast(0, "3e7dedbe37e44942dd46d264", "", "char.status")
assert_true(drawn_contains("45(-14,-4,+1)+"),
  "same-value unknown-to-known GMCP level transition did not redraw Cycle")

-- A theme reload can skip the helper's deletion. Re-enabling must show and
-- reuse that still-real window when auto-hide is off.
togglewin()
window_show()
local retained_window = my_window
OnPluginDisable()
local before_retained_enable = #commands
OnPluginEnable()
assert_equal(my_window, retained_window, "enable replaced a still-real themed window")
assert_equal(window_record(win).visible, true, "enable left a retained window hidden")
assert_equal(window_create_count, 1, "retained-window enable created a duplicate")
assert_equal(#commands, before_retained_enable + 5, "retained-window enable refresh count")
togglewin()

-- Disable hides the actual window before the helper deletes it. Re-enable also
-- recovers when the real window vanished but the old Lua object still has an ID.
WindowPosition(win, 123, 234)
my_window.windowinfo.window_left = 123
my_window.windowinfo.window_top = 234
my_window:resize(419, 63, false)
OnPluginSaveState()
window_show()
assert_equal(window_record(win).visible, true, "window_show did not show the window")
local old_window = my_window
local hides_before_disable = window_hide_count
local before_disable_commands = #commands
OnPluginDisable()
assert_true(window_record(win) ~= nil, "plugin callback deleted before helper cleanup")
assert_equal(window_record(win).visible, false, "disable did not hide the real window")
assert_equal(window_hide_count, hides_before_disable + 1, "disable hide count")
OnPluginBroadcast(0, "3e7dedbe37e44942dd46d264", "", "comm.tick")
assert_equal(#commands, before_disable_commands, "disabled plugin requested fresh data")

WindowDelete(win)
assert_equal(WindowInfo(win, 1), nil, "test did not remove the real window")
local before_enable = #commands
OnPluginEnable()
assert_true(my_window ~= old_window, "enable reused the stale themed object")
assert_true(window_record(win) ~= nil, "enable did not recreate the real window")
assert_equal(window_create_count, 2, "window was not recreated exactly once")
assert_equal(WindowInfo(win, 1), 123, "recreated window left position")
assert_equal(WindowInfo(win, 2), 234, "recreated window top position")
assert_equal(WindowInfo(win, 3), 419, "recreated window width")
assert_equal(WindowInfo(win, 4), 63, "recreated window height")
assert_true(hotspots[win .. "_resize"] ~= nil, "recreated resize hotspot missing")
assert_true(hotspots.titlemenu ~= nil, "recreated title hotspot missing")
assert_equal(#commands, before_enable + 5, "enable sent an unexpected number of refresh commands")
assert_equal(commands[before_enable + 1], "protocols gmcp sendchar", "enable did not request character state")
assert_equal(commands[before_enable + 2], "gq list", "enable did not request one fresh GQ list")
assert_equal(commands[#commands - 1], "gquest ranges", "enable did not request one ranges snapshot")

-- Close performs the same hide/save/reset work before the helper deletes the window.
window_show()
local close_window = my_window
local hides_before_close = window_hide_count
local commands_before_close = #commands
OnPluginClose()
assert_equal(window_record(win).visible, false, "close did not hide the real window")
assert_equal(window_hide_count, hides_before_close + 1, "close hide count")
assert_equal(#GQ_table, 0, "close retained transient GQ rows")
assert_equal(#commands, commands_before_close, "close sent a server command")
close_window:delete(false)
assert_equal(WindowInfo(win, 1), nil, "helper-style close did not delete the real window")
assert_equal(close_window.id, nil, "helper-style close did not clear the old object")
assert_true(window_delete_count >= 2, "real window deletions were not observed")

-- A fresh Lua load reads all persisted preferences and geometry. This also
-- proves the companion file can recreate after helper-style deletion.
sound_on = false
auto_toggle = false
toggle25 = false
toggle200 = false
toggle201 = true
assert(loadfile(plugin_path))()
assert_equal(sound_on, true, "sound preference did not survive reload")
assert_equal(auto_toggle, true, "auto-hide preference did not survive reload")
assert_equal(toggle25, true, "under-25 preference did not survive reload")
assert_equal(toggle200, true, "25-199 preference did not survive reload")
assert_equal(toggle201, false, "200+ preference did not survive reload")
assert_true(window_record(win) ~= nil, "fresh load did not recreate window")
assert_equal(WindowInfo(win, 1), 123, "fresh-load left position")
assert_equal(WindowInfo(win, 2), 234, "fresh-load top position")
assert_equal(WindowInfo(win, 3), 419, "fresh-load width")
assert_equal(WindowInfo(win, 4), 63, "fresh-load height")

print("gq_dashboard runtime test: OK")
