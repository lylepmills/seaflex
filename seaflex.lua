-- seaflex
-- companion app for earthsea
-- 
-- play grid notes correctly to 
-- advance chord. in light mode,
-- match brightly lit keys, in
-- dark mode any voicing with
-- correct notes is accepted.

local SCALE_BRIGHTNESS = 2
local OCTAVE_MARKER_BRIGHTNESS = 5
local BRIGHTNESS = 14
local OVERSIZE_CHORD_WIDTH = 5.5
local LIGHT_MODE_GAME_LENGTH = 50
local DARK_MODE_GAME_LENGTH = 10

local NOTES = { 'A', 'A#', 'B', 'C', 'C#', 'D', 'D#', 'E', 'F', 'F#', 'G', 'G#' }

local GUIDES_OPTIONS = { 'none', 'octave markers', 'full scale' }
local VOICING_OPTIONS = { 'closed only', 'basic', 'expanded' }

local CLOSED_VOICINGS = {
  closed = { 0, 0, 0, 0 }
}

local BASIC_VOICINGS = {
  closed = { 0, 0, 0, 0 },
  first_inversion = { 1, 0, 0, 0 },
  second_inversion = { 1, 1, 0, 0 },
  third_inversion = { 1, 1, 1, 0 }
}

local EXPANDED_VOICINGS = {
  closed = { 0, 0, 0, 0 },
  first_inversion = { 1, 0, 0, 0 },
  second_inversion = { 1, 1, 0, 0 },
  third_inversion = { 1, 1, 1, 0 },
  drop2 = { 0, -1, 0, 0 },
  drop3 = { 0, 0, -1, 0 },
  drop3_first_inversion = { 1, 0, -1, 0 },
  drop4_first_inversion = { 1, 0, 0, -1 },
  drop4_second_inversion = { 1, 1, 0, -1 },
  raise2 = { 0, 1, 0, 0 },
  raise2_3 = { 0, 1, 1, 0 },
  raise2_3_first_inversion = { 1, 0, 1, 0 },
  spread = { -1, 0, 0, 1 },
  spread_first_inversion = { 2, -1, 0, 0 },
  spread_second_inversion = { 1, 2, -1, 0 },
  spread_third_inversion = { 1, 1, 2, -1 },
}

local SCALE_OPTIONS = { 
  'chromatic', 
  'major', 
  'natural minor', 
  'harmonic minor', 
  'melodic minor', 
  'whole tone', 
  'octatonic', 
  'pentatonic',
  'blues' 
}

local SCALE_DEFINITIONS = {
  chromatic = { 0, 1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11 },
  major = { 0, 2, 4, 5, 7, 9, 11 },
  ['natural minor'] = { 0, 2, 3, 5, 7, 8, 10 },
  ['harmonic minor'] = { 0, 2, 3, 5, 7, 8, 11 },
  ['melodic minor'] = { 0, 2, 3, 5, 7, 9, 11 },
  ['whole tone'] = { 0, 2, 4, 6, 8, 10 },
  octatonic = { 0, 1, 3, 4, 6, 7, 9, 10 },
  pentatonic = { 0, 2, 5, 7, 9 },
  blues = { 0, 2, 3, 4, 7, 9 },
}

local CHORDS = {
  maj = { 0, 4, 7 },
  min = { 0, 3, 7 },
  dim = { 0, 3, 6 },
  aug = { 0, 4, 8 },
  sus2 = { 0, 2, 7 },
  sus4 = { 0, 5, 7 },
  maj7 = { 0, 4, 7, 11 },
  min7 = { 0, 3, 7, 10 },
  dom7 = { 0, 4, 7, 10 },
  dim7 = { 0, 3, 6, 9 },
  -- halfdim = { 0, 3, 6, 10 },
  -- sus2maj7 = { 0, 2, 7, 11 },
  -- sus4min7 = { 0, 5, 7, 10 },
  -- aug7 = { 0, 4, 8, 10 }
}

local polysub = include 'we/lib/polysub'

local g = grid.connect()

local rounds_finished = 0
local game_start_time = nil
local time_elapsed = 0
local game_errors = 0
local dark_mode = false
local chord_description = ''
local state = 'free'

engine.name = 'PolySub'

function fresh_grid(b)
  b = b or 0
  return {
    {b, b, b, b, b, b, b, b, b, b, b, b, b, b, b, b},
    {b, b, b, b, b, b, b, b, b, b, b, b, b, b, b, b},
    {b, b, b, b, b, b, b, b, b, b, b, b, b, b, b, b},
    {b, b, b, b, b, b, b, b, b, b, b, b, b, b, b, b},
    {b, b, b, b, b, b, b, b, b, b, b, b, b, b, b, b},
    {b, b, b, b, b, b, b, b, b, b, b, b, b, b, b, b},
    {b, b, b, b, b, b, b, b, b, b, b, b, b, b, b, b},
    {b, b, b, b, b, b, b, b, b, b, b, b, b, b, b, b},
  }
end

local held_keys = fresh_grid()
local enabled_coords = fresh_grid()

local function getHzET(note)
  return 55*2^(note/12)
end

function init()
  params:add{ type = 'option', id = 'scale_keys', name = 'scale key', options = NOTES }
  params:add{ type = 'option', id = 'scale_types', name = 'scale type', options = SCALE_OPTIONS }
  params:add{ type = 'option', id = 'guides', name = 'guides', options = GUIDES_OPTIONS, default = 2 }
  params:add{ type = 'option', id = 'voicings', name = 'voicings', options = VOICING_OPTIONS, default = 2 }
  params:add{ type = 'number', id = 'num_hands', name = 'number of hands', min = 1, max = 2, default = 1 }
  params:add_separator()
  polysub:params()
  
  engine.stopAll()
  
  local main_loop = metro.init(main_update_loop, 0.1)
  main_loop:start()
end

function key(n, z)
  if n == 2 and z == 1 then
    if state == 'free' then
      state = 'game_loading'
    elseif state == 'game_loading' then
      start_game()
    elseif state == 'game_in_progress' then
      end_game()
    else
      state = 'free'
    end
  end
  
  if n == 3 and z == 1 and (state == 'free' or state == 'game_loading') then
    dark_mode = not dark_mode
  end
  
  redraw_screen()
end

function enc(n, delta)
  if n == 1 then
    mix:delta('output', delta)
  elseif n == 2 then
    params:delta('shape', delta)
  elseif n == 3 then
    params:delta('timbre', delta)
  end
end

function norns.grid.key(id, x, y, s)
  held_keys[y][x] = s
  
  if s == 1 and state == 'game_in_progress' then
    check_for_error(x, y)
  end
  
  toggle_note(x, y, s)
end

function note_value(x, y)
  return ((7 - y) * 5) + x
end

function toggle_note(x, y, on)
  local note = note_value(x, y)
  
  if on > 0 then
    engine.start(coord_id(x, y), getHzET(note))
  else
    engine.stop(coord_id(x, y))
  end
end

function coords_to_note(x, y)
  local note = note_value(x, y)
  return NOTES[(note % 12) + 1]
end

function coord_id(x, y)
  return (x * 8) + y
end

function main_update_loop()
  activate_chords()
  redraw_lights()
  
  if correct_keys_held() then
    enabled_coords = fresh_grid()
    rounds_finished = rounds_finished + 1
  end
  
  if state == 'game_in_progress' then
    time_elapsed = os.time() - game_start_time
    redraw_screen()
    
    if rounds_finished == game_length() then
      end_game()
    end
  end
end

function activate_chords()
  if num_active(enabled_coords) > 0 then
    return
  end
  
  local potential_enabled_coords = fresh_grid()
  chord_description = ''

  local chords_generated = 0
  while chords_generated < params:get('num_hands') do
    local potential_enabled_coords = fresh_grid()
    local potential_chord = random_chord()
    local potential_voicing = random_voicing()
    local valid_chord = true
    
    -- we go slightly beyond the boundaries of the grid so that even with voicings
    -- we can get all chord shapes all throughout the grid
    local root = { x = math.random(-1, g.cols + 2), y = math.random(-1, g.rows + 2) }
    local shape = chord_shape(
      root,
      potential_chord.chord_def, 
      potential_voicing.voicing_def
    )
    
    if shape == nil then
      valid_chord = false
    else
      for _, coord in pairs(shape) do
        local x = coord.x
        local y = coord.y
        
        if (not in_scale(coords_to_note(x, y))) or (not in_grid(x, y)) then
          valid_chord = false
          break
        end
        
        potential_enabled_coords[y][x] = 1
      end
    end
    
    if valid_chord then
      chords_generated = chords_generated + 1
      enabled_coords = combine_grids(enabled_coords, potential_enabled_coords)
      
      if chord_description ~= '' then
        chord_description = chord_description .. ' / '
      end
      
      chord_description = chord_description .. (coords_to_note(root.x, root.y) .. potential_chord.chord_name)
    end
  end
  
  remove_doubled_notes(enabled_coords)
  redraw_screen()
end

function remove_doubled_notes(grid)
  local enabled_notes = {}
  
  for x = 1, g.cols do
    for y = 1, g.rows do
      if grid[y][x] > 0 then
        if enabled_notes[note_value(x, y)] then
          grid[y][x] = 0
        end
        
        enabled_notes[note_value(x, y)] = true
      end
    end
  end
end

function random_chord()
  local chord_number = math.random(table_length(CHORDS))
  local num = 0
  
  for name, def in pairs(CHORDS) do
    num = num + 1
    if num == chord_number then
      return { chord_name = name, chord_def = def }
    end
  end
end

function random_voicing()
  local voicings = CLOSED_VOICINGS
  if params:string('voicings') == 'expanded' then
    voicings = EXPANDED_VOICINGS
  elseif params:string('voicings') == 'basic' then
    voicings = BASIC_VOICINGS
  end
  
  local voicing_number = math.random(table_length(voicings))
  local num = 0
  
  for name, def in pairs(voicings) do
    num = num + 1
    if num == voicing_number then
      return { voicing_name = name, voicing_def = def }
    end
  end
end

function position_options(root, interval)
  local options = {}
  
  local option = { x = root.x + interval, y = root.y }
  while option.x <= g.cols do
    if in_grid(option.x, option.y) then
      table.insert(options, deep_copy(option))
    end
    
    option.x = option.x + 5
    option.y = option.y + 1
  end
  
  option = { x = root.x + interval - 5, y = root.y - 1 }
  while option.x >= 1 do
    if in_grid(option.x, option.y) then
      table.insert(options, deep_copy(option))
    end
    
    option.x = option.x - 5
    option.y = option.y - 1
  end
  
  return options
end

function voice_chord_def(chord_def, voicing_def)
  local voiced_chord_def = {}
  
  for idx, semitone_interval in pairs(chord_def) do
    table.insert(voiced_chord_def, semitone_interval + (voicing_def[idx] * 12))
  end
  table.sort(voiced_chord_def)
  
  return voiced_chord_def
end

-- TODO: this could maybe be improved by just generating all
-- the possibilities for a given voiced chord def and just comparing
-- them all at once instead of one at a time
-- could compare by max distance or could first constrain by RMS distance
-- from root, or some combination
function chord_shape(root, chord_def, voicing_def)
  local voiced_chord_def = voice_chord_def(chord_def, voicing_def)
  -- we artificially place the root in the shape to begin with so that we can
  -- start as close as possible, but will remove it later
  local shape = { root }
  local pass = 1

  for _, semitone_interval in pairs(voiced_chord_def) do
    -- see comment above
    if pass == 2 then
      table.remove(shape, 1)
    end
    pass = pass + 1
    
    local options = position_options(root, semitone_interval)
    local best_option = table.remove(options, 1)
    if best_option == nil then return nil end
    local best_shape = deep_copy(shape)
    table.insert(best_shape, best_option)
    
    while #options > 0 do
      local potential_option = table.remove(options, 1)
      local potential_shape = deep_copy(shape)
      table.insert(potential_shape, potential_option)
      
      local best_distance = max_distance(best_shape)
      local potential_distance = max_distance(potential_shape)
      
      if best_distance == potential_distance then
        local shapes = { best_shape, potential_shape }
        best_shape = shapes[math.random(2)]
      elseif best_distance < potential_distance then
        best_shape = best_shape
      else
        best_shape = potential_shape
      end
    end
    
    shape = best_shape
  end
  
  if max_distance(shape) > OVERSIZE_CHORD_WIDTH then
    return nil
  end
  
  return shape
end

function max_distance(chord_shape)
  local max_dist = 0
  
  for coord_idx1 = 1, #chord_shape - 1 do
    for coord_idx2 = coord_idx1 + 1, #chord_shape do
      local coord1 = chord_shape[coord_idx1]
      local coord2 = chord_shape[coord_idx2]
      max_dist = math.max(max_dist, coord_distance(coord1, coord2))
    end
  end
  
  return max_dist
end

function coord_distance(coord1, coord2)
  return (((coord1.x - coord2.x) ^ 2) + ((coord1.y - coord2.y) ^ 2)) ^ 0.5
end

function correct_keys_held()
  if num_active(enabled_coords) == 0 then
    return false
  end
  
  if dark_mode then
    return dark_mode_correct_keys_held()
  else
    return light_mode_correct_keys_held()
  end
end

function dark_mode_correct_keys_held()
  local held_notes = {}
  local enabled_notes = {}

  for x = 1, g.cols do
    for y = 1, g.rows do
      if held_keys[y][x] ~= 0 then
        held_notes[coords_to_note(x, y)] = true
      end
      
      if enabled_coords[y][x] ~= 0 then
        enabled_notes[coords_to_note(x, y)] = true
      end
    end
  end
  
  for held_note, _ in pairs(held_notes) do
    if not enabled_notes[held_note] then
      return false
    end
  end
  
  for enabled_note, _ in pairs(enabled_notes) do
    if not held_notes[enabled_note] then
      return false
    end
  end
  
  return true
end

function light_mode_correct_keys_held()
  for x = 1, g.cols do
    for y = 1, g.rows do
      if held_keys[y][x] ~= enabled_coords[y][x] then
        return false
      end
    end
  end
  
  return true
end

function check_for_error(x_check, y_check)
  if dark_mode then
    local enabled_notes = {}

    for x = 1, g.cols do
      for y = 1, g.rows do
        if enabled_coords[y][x] > 0 then
          enabled_notes[coords_to_note(x, y)] = true
        end
      end
    end
    
    if not enabled_notes[coords_to_note(x_check, y_check)] then
      game_errors = game_errors + 1
    end
  else
    if enabled_coords[y_check][x_check] == 0 then
      game_errors = game_errors + 1
    end
  end
end

function in_grid(x, y)
  return x >= 1 and x <= g.cols and y >= 1 and y <= g.rows
end

function redraw_lights()
  for x = 1, g.cols do
    for y = 1, g.rows do
      local brightness = not dark_mode and enabled_coords[y][x] * BRIGHTNESS or 0

      if params:string('guides') == 'octave markers' or params:string('guides') == 'full scale' then
        if params:string('scale_keys') == coords_to_note(x, y) then
          brightness = math.max(brightness, OCTAVE_MARKER_BRIGHTNESS)
        end
      end
      
      if params:string('guides') == 'full scale' then
        if in_scale(coords_to_note(x, y)) then
          brightness = math.max(brightness, SCALE_BRIGHTNESS)
        end
      end
      
      g:led(x, y, brightness)
    end
  end
  
  g:refresh()
end

function in_scale(note)
  local root_scale_index = value_index(NOTES, params:string('scale_keys'))
  for _, interval in pairs(scale_definition()) do
    local scale_index = ((root_scale_index + interval - 1) % 12) + 1
    
    local scale_note = NOTES[scale_index]
    if note == scale_note then
      return true
    end
  end
  
  return false
end

function high_score_key()
  local key = params:string('scale_types')
  key = key .. ',' .. params:string('voicings')
  key = key .. ',' .. (dark_mode and 'dark' or 'light')
  key = key .. ',' .. params:get('num_hands')
  key = key .. ',' .. game_length()
  return key
end

function high_score()
  return high_scores()[high_score_key()] or 0
end

function high_scores()
  return tab.load(high_score_filename()) or {}
end

function high_score_filename()
  return norns.state.data .. "high_scores.csv"
end

function update_high_score()
  local new_high_scores = high_scores()
  local new_high_score = math.max(high_score(), game_score())
  new_high_scores[high_score_key()] = new_high_score
  
  tab.save(new_high_scores, high_score_filename())
end

function start_game()
  state = 'game_in_progress'
  rounds_finished = 0
  game_errors = 0
  enabled_coords = fresh_grid()
  game_start_time = os.time()
end

function end_game()
  state = 'game_over'
  update_high_score()
end

function redraw_screen()
  screen.clear()
  screen.aa(1)
  screen.font_face(24)
  
  if state == 'free' then
    redraw_screen_free()
  elseif state == 'game_loading' then
    redraw_screen_game_loading()
  elseif state == 'game_in_progress' then
    redraw_screen_game_in_progress()
  elseif state == 'game_over' then
    redraw_screen_game_over()
  end
  
  screen.update()
  
  -- restore font defaults for compatibility with settings page
  screen.font_size(8)
  screen.font_face(1)
end

function redraw_screen_free()
  screen.level(15)
  screen.font_size(13)
  screen.move(64, 28)
  screen.text_center(chord_description)

  screen.level(5)
  screen.font_face(1)
  screen.font_size(8)
  screen.move(64, 54)
  screen.text_center('K2 to begin game')
  screen.move(64, 63)
  screen.text_center('K3 to ' .. (dark_mode and 'show' or 'hide') .. ' chords')
end

function redraw_screen_game_loading()
  screen.level(5)
  screen.font_face(1)
  screen.font_size(8)
  screen.move(64, 9)
  screen.text_center('press K2 again to begin game')
  screen.move(64, 18)
  screen.text_center('press K3 for ' .. (dark_mode and 'light mode' or 'DARK MODE'))
  
  screen.move(64, 36)
  screen.text_center('high score: ' .. high_score())

  screen.move(64, 54)
  screen.text_center(options_text1())
  screen.move(64, 63)
  screen.text_center(options_text2())
end

function redraw_screen_game_in_progress()
  if dark_mode then
    screen.level(10)
    screen.font_size(10)
    screen.move(64, 11)
    screen.text_center('DARK MODE - ' .. rounds_finished .. '/' .. game_length())
    
    screen.level(15)
    screen.font_size(13)
    screen.move(64, 35)
    screen.text_center(chord_description)
  else
    screen.level(15)
    screen.font_size(13)
    screen.move(64, 28)
    screen.text_center(rounds_finished .. '/' .. game_length())
  end

  screen.level(5)
  screen.font_face(1)
  screen.font_size(8)
  screen.move(64, 54)
  screen.text_center('score: ' .. game_score())
  screen.move(64, 63)
  screen.text_center(time_elapsed .. ' seconds')
end

function redraw_screen_game_over()
  screen.level(15)
  screen.font_size(13)
  screen.move(64, 13)
  local main_text = (game_score() == high_score() and 'HIGH SCORE' or 'GAME ENDED')
  screen.text_center(main_text)
  
  screen.level(5)
  screen.font_face(1)
  screen.font_size(8)
  
  screen.move(64, 30)
  screen.text_center('score: ' .. game_score())
  screen.move(64, 39)
  screen.text_center('time: ' .. time_elapsed)
  screen.move(64, 48)
  screen.text_center('errors: ' .. game_errors)
  
  screen.move(64, 63)
  screen.text_center('K2 to enter free mode')
end

function game_score()
  local per_round_score = dark_mode and 50 or 10
  return (rounds_finished * per_round_score) - (time_elapsed * 2) - (game_errors * 5)
end

function options_text1()
  local hands_text = params:get('num_hands') .. (params:get('num_hands') == 1 and ' hand' or' hands')
  local voicing_text = params:string('voicings') .. ' voicings'
  return hands_text .. ', ' .. voicing_text
end

function options_text2()
  local rounds_text = game_length() .. ' rounds, '
  return rounds_text .. params:string('scale_types')
end

function scale_definition()
  return SCALE_DEFINITIONS[params:string('scale_types')]
end

function game_length()
  return dark_mode and DARK_MODE_GAME_LENGTH or LIGHT_MODE_GAME_LENGTH
end

function round(num)
  return math.floor(num + 0.5)
end

function table_length(obj)
  local count = 0
  for _ in pairs(obj) do count = count + 1 end
  return count
end

function combine_grids(first_grid, second_grid)
  local result = fresh_grid()
  
  for x = 1, g.cols do
    for y = 1, g.rows do
      if first_grid[y][x] > 0 or second_grid[y][x] > 0 then
        result[y][x] = 1
      end
    end
  end
  
  return result
end

function value_index(tab, value)
  for k, v in pairs(tab) do
    if v == value then
      return k
    end
  end
  
  return nil
end

function num_active(grid)
  local count = 0
  for x = 1, g.cols do
    for y = 1, g.rows do
      if grid[y][x] ~= 0 then
        count = count + 1
      end
    end
  end
  
  return count
end

function deep_copy(obj)
  if type(obj) ~= 'table' then return obj end
  local res = {}
  for k, v in pairs(obj) do res[deep_copy(k)] = deep_copy(v) end
  return res
end
