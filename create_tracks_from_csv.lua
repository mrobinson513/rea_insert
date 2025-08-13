
-- ReaScript Lua to create tracks from template "PSX_SPU_Import" for each distinct Start_Addr in CSV

function IsTrackFolder(track)
  -- Returns true if the track is a folder parent (folder start)
  local folder_depth = reaper.GetMediaTrackInfo_Value(track, "I_FOLDERDEPTH")
  return folder_depth == 1
end

function FindTrackByName(track_name)
  local track_count = reaper.CountTracks(0)
  for i = 0, track_count - 1 do
    local track = reaper.GetTrack(0, i)
    if track and not IsTrackFolder(track) then
      local _, name = reaper.GetSetMediaTrackInfo_String(track, "P_NAME", "", false)
      if name == track_name then
        return track, i
      end
    end
  end
end

function FindFolderTrackByName(folder_name)
  local track_count = reaper.CountTracks(0)
  for i = 0, track_count - 1 do
    local track = reaper.GetTrack(0, i)
    if track and IsTrackFolder(track) then
      local _, name = reaper.GetSetMediaTrackInfo_String(track, "P_NAME", "", false)
      if name == folder_name then
        return track, i
      end
    end
  end
  return nil, -1 -- not found
end

function CreateFolderTrack(name)
  local track_count = reaper.CountTracks(0)
  reaper.InsertTrackAtIndex(track_count, true)
  local track = reaper.GetTrack(0, track_count)
  if not track then return nil end

  reaper.GetSetMediaTrackInfo_String(track, "P_NAME", name, true)
  reaper.SetMediaTrackInfo_Value(track, "I_FOLDERDEPTH", 1) -- folder start

  return track
end

function CreateChildTrack(parent_track, name)
  local parent_idx = reaper.GetMediaTrackInfo_Value(parent_track, "IP_TRACKNUMBER") - 1
  reaper.InsertTrackAtIndex(parent_idx + 1, true)
  local child_track = reaper.GetTrack(0, parent_idx + 1)
  reaper.GetSetMediaTrackInfo_String(child_track, "P_NAME", name, true)
  if not child_track then return nil end

  -- Set folder depth to 0 (normal track)
  reaper.SetMediaTrackInfo_Value(child_track, "I_FOLDERDEPTH", 0)

  return child_track
end

function split_csv_line(line)
  local fields = {}
  local pattern = '([^,]+)'
  for field in string.gmatch(line, pattern) do
    table.insert(fields, field)
  end
  return fields
end


function CreateTrackFromTemplate(template_name, track_name)
  local template_path = reaper.GetResourcePath() .. "/TrackTemplates/" .. template_name .. ".RTrackTemplate"
  -- InsertTrackFromTemplate is not a standard ReaScript API function, so we implement loading template by importing the track template file
  reaper.Main_openProject(template_path)

  -- Load the track template chunk from file
  local file = io.open(template_path, "r")
  if not file then
    reaper.ShowMessageBox("Failed to open track template: " .. template_path, "Error", 0)
    return track
  end
  local chunk = file:read("*a")
  file:close()

  return track
end

function ReadDistinctStartAddrs(csv_file)
  local file = io.open(csv_file, "r")
  if not file then
    reaper.ShowMessageBox("Failed to open CSV file: " .. csv_file, "Error", 0)
    return nil
  end

  local header = file:read("*l")
  if not header then
    reaper.ShowMessageBox("CSV file is empty", "Error", 0)
    file:close()
    return nil
  end

  local headers = split_csv_line(header)
  local col_indices = {}
  for i, col_name in ipairs(headers) do
    col_indices[col_name] = i
  end

  if not col_indices["Start_Addr"] then
    reaper.ShowMessageBox("CSV missing required column: Start_Addr", "Error", 0)
    file:close()
    return nil
  end

  local distinct_addrs = {}
  local addr_set = {}

  for line in file:lines() do
    local fields = split_csv_line(line)
    local addr = fields[col_indices["Start_Addr"]]
    if addr and not addr_set[addr] then
      addr_set[addr] = true
      table.insert(distinct_addrs, addr)
    end
  end

  file:close()
  return distinct_addrs
end

function Main()
  local retval, csv_file = reaper.GetUserInputs("CSV Path", 1, "CSV Path:", "")
  if not retval or csv_file == "" then
    reaper.ShowMessageBox("CSV Path is required", "Error", 0)
    return
  end

  reaper.Undo_BeginBlock()

  local default_csv_prefix = "/Users/unclmike/Music/psf_dumps"
  local distinct_addrs = ReadDistinctStartAddrs(default_csv_prefix .. "/" .. csv_file)
  if not distinct_addrs then
    reaper.Undo_EndBlock("Create tracks from CSV", -1)
    return
  end

  for _, addr in ipairs(distinct_addrs) do
    CreateTrackFromTemplate("PSX_SPU_Import", addr)
  end

  -- Rename tracks by iterating over Start_Addr values and using their index as track index
  for i, addr in ipairs(distinct_addrs) do
    idx = i-1
    local track = reaper.GetTrack(0, (idx + (idx * 24)))
    -- reaper.ShowMessageBox("Track value" .. (idx + (idx * 24)), "Value", 0)
    if track then
      reaper.GetSetMediaTrackInfo_String(track, "P_NAME", addr, true)
    end
  end

  -- create the Stereo Sums track group
  local folder = CreateFolderTrack("Stereo Sums")
  
  -- create the audio tracks for stereo sums and connect to the folder track
  for i, addr in ipairs(distinct_addrs) do
    local child = CreateChildTrack(folder, "Sum " .. addr)
    
    -- arm and configure channels for recording from routed signal
    local arm = reaper.SetTrackUIRecArm(child, 1, 3)
    local rec_input = reaper.SetMediaTrackInfo_Value(child, "I_RECINPUT", -1)
    local rec_mode = reaper.SetMediaTrackInfo_Value(child, "I_RECMODE", 1)

    local folder_track, folder_index = FindFolderTrackByName(addr)
    local sum_track, sum_index = FindTrackByName("Sum " .. addr)
    if not folder_track or not sum_track then
      reaper.ShowMessageBox("Folder track named '" .. addr .. "' not found", "Error", 0)
      return
    else
      local _, str_folder_track = reaper.GetSetMediaTrackInfo_String(folder_track, "P_NAME", "", false)
      local _, str_sum_track = reaper.GetSetMediaTrackInfo_String(sum_track, "P_NAME", "", false)
      -- reaper.ShowMessageBox(
      --   "Routing folder " .. str_folder_track .. " to 'Sum " .. str_sum_track .. "...", 
      --   "Info", 0
      -- )
      send_idx = reaper.CreateTrackSend(folder_track, sum_track)
      record_conf = {
        reaper.GetSetMediaTrackInfo_Value
      }
    end
  end

  reaper.Undo_EndBlock("Create tracks from CSV", -1)
end

reaper.defer(Main)
