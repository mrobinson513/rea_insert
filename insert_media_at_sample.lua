-- Combined script to find folder track by sound_name and insert WAV segments to child tracks based on CSV data

function IsTrackFolder(track)
  -- Returns true if the track is a folder parent (folder start)
  local folder_depth = reaper.GetMediaTrackInfo_Value(track, "I_FOLDERDEPTH")
  return folder_depth == 1
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

function InsertMediaAtSample(track_index, media_file_path, sample_position)
  -- Get the track (0-based index)
  local track = reaper.GetTrack(0, track_index)
  if not track then
    reaper.ShowMessageBox("Track " .. track_index .. " not found", "Error", 0)
    return false
  end

  -- Check if media file exists
  if not reaper.file_exists(media_file_path) then
    reaper.ShowMessageBox("Media file not found: " .. media_file_path, "Error", 0)
    return false
  end

  -- Get project sample rate
  local sample_rate = reaper.GetSetProjectInfo(0, "PROJECT_SRATE", 0, false)

  -- Convert sample position to time (seconds)
  local time_position = sample_position / sample_rate

  -- Insert media item
  local media_item = reaper.AddMediaItemToTrack(track)
  if not media_item then
    reaper.ShowMessageBox("Failed to create media item", "Error", 0)
    return false
  end

  -- Set media item position
  reaper.SetMediaItemInfo_Value(media_item, "D_POSITION", time_position)

  -- Add media source to the item
  local media_source = reaper.PCM_Source_CreateFromFile(media_file_path)
  if not media_source then
    reaper.ShowMessageBox("Failed to create media source from file", "Error", 0)
    reaper.DeleteTrackMediaItem(track, media_item)
    return false
  end

  -- Create take and set source
  local take = reaper.AddTakeToMediaItem(media_item)
  reaper.SetMediaItemTake_Source(take, media_source)

  -- Get source length and set item length
  local source_length = reaper.GetMediaSourceLength(media_source, false)
  reaper.SetMediaItemInfo_Value(media_item, "D_LENGTH", source_length)

  -- Update arrangement
  reaper.UpdateArrange()

  return true
end

function split_csv_line(line)
  local fields = {}
  local pattern = '([^,]+)'
  for field in string.gmatch(line, pattern) do
    table.insert(fields, field)
  end
  return fields
end

-- Read distinct Start_Addr values from CSV
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

function InsertMediaFromCSV()
  -- Get user inputs for CSV path and WAV path
  local retval, user_input = reaper.GetUserInputs("Insert Media from CSV", 2,
    "CSV Path:,WAV Path:",
    ",")
  if not retval then return end

  local inputs = {}
  for input in user_input:gmatch("([^,]+)") do
    table.insert(inputs, input)
  end
  if #inputs < 2 then
    reaper.ShowMessageBox("Please provide CSV Path and WAV Path", "Error", 0)
    return
  end

  local csv_path = inputs[1]:gsub("^%s*(.-)%s*$", "%1")
  local wav_path = inputs[2]:gsub("^%s*(.-)%s*$", "%1")
  if csv_path == "" or wav_path == "" then
    reaper.ShowMessageBox("CSV Path and WAV Path must be provided", "Error", 0)
    return
  end

  local distinct_addrs = ReadDistinctStartAddrs(csv_path)
  if not distinct_addrs then return end

  -- Prepare column indices
  local f0 = io.open(csv_path, "r")
  local header = f0:read("*l")
  local headers = split_csv_line(header)
  local col_indices = {}
  for i, col in ipairs(headers) do col_indices[col] = i end
  f0:close()

  reaper.Undo_BeginBlock()
  for _, sound_name in ipairs(distinct_addrs) do
    local folder_track, folder_index = FindFolderTrackByName(sound_name)
    if not folder_track then
      reaper.ShowMessageBox("Folder track named '" .. sound_name .. "' not found", "Error", 0)
    else
      local f = io.open(csv_path, "r")
      f:read("*l") -- skip header
      for line in f:lines() do
        local fields = split_csv_line(line)
        if fields[col_indices["Start_Addr"]] == sound_name then
          local voice_num = tonumber(fields[col_indices["Voice"]])
          local track_index = folder_index + 1 + voice_num
          local sample_position = tonumber(fields[col_indices["Timestamp"]])
          local file_name = string.format("%s_vox%02d_%d.wav", sound_name, voice_num, sample_position)
          local media_file_path = string.format("%s/%s/%s", wav_path, sound_name, file_name)
          InsertMediaAtSample(track_index, media_file_path, sample_position)
        end
      end
      f:close()
    end
  end
  reaper.Undo_EndBlock("Insert media from CSV", -1)
end

function Main()
  InsertMediaFromCSV()
end

reaper.defer(Main)
