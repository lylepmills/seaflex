-- seaflex
-- first commit

RUN = true
SCALE_BRIGHTNESS = 2
OCTAVE_MARKER_BRIGHTNESS = 5
BRIGHTNESS = 14

NOTES = { 'A', 'A#', 'B', 'C', 'C#', 'D', 'D#', 'E', 'F', 'F#', 'G', 'G#' }

GUIDES_OPTIONS = { 'none', 'octave markers', 'full scale' }

INVERSIONS = {
  none = { 0, 0, 0, 0 },
  first = { 1, 0, 0, 0 },
  second = { 1, 1, 0, 0 },
  third = { 1, 1, 1, 0 }
}

SCALE_OPTIONS = { 
  'chromatic', 
  'major', 
  'natural minor', 
  'harmonic minor', 
  'melodic minor', 
  'whole tone', 
  'octatonic', 
  'blues' 
}

SCALE_DEFINITIONS = {
  chromatic = { 0, 1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11 },
  major = { 0, 2, 4, 5, 7, 9, 11 },
  ['natural minor'] = { 0, 2, 3, 5, 7, 8, 10 },
  ['harmonic minor'] = { 0, 2, 3, 5, 7, 8, 11 },
  ['melodic minor'] = { 0, 2, 3, 5, 7, 9, 11 },
  ['whole tone'] = { 0, 2, 4, 6, 8, 10 },
  octatonic = { 0, 1, 3, 4, 6, 7, 9, 10 },
  blues = { 0, 2, 3, 4, 7, 9 }
}

CHORDS = {
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
}

local polysub = include 'we/lib/polysub'

engine.name = 'PolySub'

local function getHz(deg,oct)
  return base * ratios[deg] * (2^oct)
end

local function getHzET(note)
  return 55*2^(note/12)
end

function init()
  g = grid.connect()
  
  params = paramset.new()
  
  params:add{ type = "option", id = "scale_keys", name = "scale key", options = NOTES }
  params:add{ type = "option", id = "scale_types", name = "scale type", options = SCALE_OPTIONS }
  params:add{ type = "option", id = "guides", name = "guides", options = GUIDES_OPTIONS }
  params:add{ type = "number", id = "num_hands", name = "number of hands", min = 1, max = 2, default = 1 }
  -- TODO - inversion setting (simple, expanded)
  params:add_separator()
  
  polysub:params()
  
  engine.stopAll()
  
  held_keys = fresh_grid()
  enabled_lights = fresh_grid()
  show_chords = true

  if RUN then
    main_loop = metro.init(update_grid, 0.1)
    main_loop:start()
  end
end

function update_grid()
  activate_chords()
  redraw_lights()
  
  if correct_keys_held() then
    enabled_lights = fresh_grid()
  end
end

function key(n, z)
  if n == 3 and z == 1 then
    show_chords = not show_chords
  end
end

function norns.grid.key(id, x, y, s)
  held_keys[y][x] = s
  toggle_note(x, y, s)
end

function toggle_note(x, y, on)
  local note = ((7 - y) * 5) + x
  
  if on > 0 then
    engine.start(coord_id(x, y), getHzET(note))
  else
    engine.stop(coord_id(x, y))
  end
end

function coords_to_note(x, y)
  local note = ((7 - y) * 5) + x
  return NOTES[(note % 12) + 1]
end

function coord_id(x, y)
  return (x * 8) + y
end

-- TODO - inversions
function activate_chords()
  if num_active(enabled_lights) > 0 then
    return
  end
  
  potential_enabled_lights = fresh_grid()
  chord_description = ''
  
  number_of_hands = params:get('num_hands')
  chords_generated = 0
  
  while chords_generated < number_of_hands do
    potential_enabled_lights = fresh_grid()
    potential_chord = random_chord()
    chord_in_scale = true
    
    shape = chord_shape(potential_chord.chord_def)
    -- TODO - choose these bounds more intentionally
    start_x = math.random(4, g.cols - 3)
    start_y = math.random(g.rows - 3)
    
    for _, coord in pairs(shape) do
      x = start_x + coord.x
      y = start_y + coord.y
      
      potential_enabled_lights[y][x] = 1
      
      if not in_scale(coords_to_note(x, y)) then
        chord_in_scale = false
        break
      end
    end
    
    if chord_in_scale then
      chords_generated = chords_generated + 1
      enabled_lights = combine_grids(enabled_lights, potential_enabled_lights)
      
      if chord_description ~= '' then
        chord_description = chord_description .. ' / '
      end
      
      chord_description = chord_description .. (coords_to_note(start_x, start_y) .. potential_chord.chord_name)
    end
  end
  
  redraw_screen(chord_description)
end

function random_chord()
  chord_number = math.random(table_length(CHORDS))
  num = 0
  
  for name, def in pairs(CHORDS) do
    num = num + 1
    if num == chord_number then
      return { chord_name = name, chord_def = def }
    end
  end
end

-- TODO - improve chord shape algorithm
-- could just generate all possible positions
function chord_shape(chord_def)
  shape = { { x = 0, y = 0 } }
  
  last_interval = 0

  for _, semitone_interval in pairs(chord_def) do
    if semitone_interval > 0 then
      interval_delta = semitone_interval - last_interval
      last_interval = semitone_interval
      last_position = shape[#shape]
      option1 = { 
        x = last_position.x + (interval_delta % 5),
        y = last_position.y + (interval_delta // 5)
      }
      option2 = {
        x = option1.x - 5,
        y = option1.y + 1
      }
      shape1 = deep_copy(shape)
      shape2 = deep_copy(shape)
      table.insert(shape1, option1)
      table.insert(shape2, option2)
      
      if max_distance(shape1) == max_distance(shape2) then
        shapes = { shape1, shape2 }
        shape = shapes[math.random(2)]
      elseif max_distance(shape1) < max_distance(shape2) then
        shape = shape1
      else
        shape = shape2
      end
    end
  end
  
  return shape
end

function max_distance(chord_shape)
  max_dist = 0
  
  for coord_idx1 = 1, #chord_shape - 1 do
    for coord_idx2 = coord_idx1 + 1, #chord_shape do
      coord1 = chord_shape[coord_idx1]
      coord2 = chord_shape[coord_idx2]
      max_dist = math.max(max_dist, coord_distance(coord1, coord2))
    end
  end
  
  return max_dist
end

function coord_distance(coord1, coord2)
  return (((coord1.x - coord2.x) ^ 2) + ((coord1.y - coord2.y) ^ 2)) ^ 0.5
end

function correct_keys_held()
  if num_active(enabled_lights) == 0 then
    return false
  end
  
  for x = 1, g.cols do
    for y = 1, g.rows do
      if held_keys[y][x] ~= enabled_lights[y][x] then
        return false
      end
    end
  end
  
  return true
end

function find_in_grid(x, y, grid, default)
  if x < 1 or x > g.cols or y < 1 or y > g.rows then
    return default
  end
  
  return grid[y][x]
end

function redraw_lights()
  for x = 1, g.cols do
    for y = 1, g.rows do
      brightness = show_chords and enabled_lights[y][x] * BRIGHTNESS or 0
      
      guide_option = GUIDES_OPTIONS[params:get("guides")]
      key_option = NOTES[params:get("scale_keys")]
      
      if guide_option == 'octave markers' or guide_option == 'full scale' then
        if key_option == coords_to_note(x, y) then
          brightness = math.max(brightness, OCTAVE_MARKER_BRIGHTNESS)
        end
      end
      
      if guide_option == 'full scale' then
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
  key_option = NOTES[params:get("scale_keys")]
  scale_option = SCALE_OPTIONS[params:get("scale_types")]
  scale_definition = SCALE_DEFINITIONS[scale_option]
  
  root_scale_index = value_index(NOTES, key_option)
  for _, interval in pairs(scale_definition) do
    scale_index = ((root_scale_index + interval - 1) % 12) + 1
    
    scale_note = NOTES[scale_index]
    if note == scale_note then
      return true
    end
  end
  
  return false
end

function redraw_screen(text)
  screen.clear()
  screen.aa(1)
  screen.level(15)
  screen.font_size(15)
  screen.font_face(24)
  screen.move(64, 32)
  screen.text_center(text)
  screen.update()
  -- restore font defaults for compatibility with settings page
  screen.font_size(8)
  screen.font_face(1)
end

function round(num)
  return math.floor(num + 0.5)
end

function table_length(obj)
  local count = 0
  for _ in pairs(obj) do count = count + 1 end
  return count
end

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

function combine_grids(first_grid, second_grid)
  result = fresh_grid()
  
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
  count = 0
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
