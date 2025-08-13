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

function InsertMediaFromCSV()
  -- Get user inputs for CSV path, WAV path, and sound name
  local retval, user_input = reaper.GetUserInputs("Insert Media from CSV", 3,
    "CSV Path:,WAV Path:,Sound Name:",
    ",,")
  if not retval then
    return -- User cancelled
  end

  local inputs = {}
  for input in user_input:gmatch("([^,]+)") do
    table.insert(inputs, input)
  end

  if #inputs < 3 then
    reaper.ShowMessageBox("Please provide all required inputs", "Error", 0)
    return
  end

  local csv_path = inputs[1]:gsub("^%s*(.-)%s*$", "%1") -- trim whitespace
  local wav_path = inputs[2]:gsub("^%s*(.-)%s*$", "%1")
  local sound_name = inputs[3]:gsub("^%s*(.-)%s*$", "%1")

  if csv_path == "" or wav_path == "" or sound_name == "" then
    reaper.ShowMessageBox("CSV Path, WAV Path, and Sound Name must be provided", "Error", 0)
    return
  end

  -- Find folder track by sound_name
  local folder_track, folder_index = FindFolderTrackByName(sound_name)
  if not folder_track then
    reaper.ShowMessageBox("Folder track named '" .. sound_name .. "' not found", "Error", 0)
    return
  end

  -- Open CSV file
  local file = io.open(csv_path, "r")
  if not file then
    reaper.ShowMessageBox("Failed to open CSV file: " .. csv_path, "Error", 0)
    return
  end

  -- Read header line to get column indices
  local header = file:read("*l")
  if not header then
    reaper.ShowMessageBox("CSV file is empty", "Error", 0)
    file:close()
    return
  end

  local headers = split_csv_line(header)
  local col_indices = {}
  for i, col_name in ipairs(headers) do
    col_indices[col_name] = i
  end

  -- Check required columns
  local required_cols = {"SampleNum", "Voice", "Start_Addr"}
  for _, col in ipairs(required_cols) do
    if not col_indices[col] then
      reaper.ShowMessageBox("CSV missing required column: " .. col, "Error", 0)
      file:close()
      return
    end
  end

  -- Begin undo block
  reaper.Undo_BeginBlock()

  -- Process each line
  for line in file:lines() do
    local fields = split_csv_line(line)
    if fields[col_indices["Start_Addr"]] == sound_name then
      local voice_num = tonumber(fields[col_indices["Voice"]])
      local track_index = folder_index + 1 + voice_num -- child track index relative to folder
      local voice_str = string.format("%02d", voice_num)
      local sound_name_val = fields[col_indices["Start_Addr"]]
      local sample_position = tonumber(fields[col_indices["SampleNum"]])
      local file_name = string.format("%s_vox%s_%s.wav", sound_name_val, voice_str, sample_position)
      local media_file_path = string.format("%s/%s/%s", wav_path, sound_name_val, file_name)

      if track_index and media_file_path and sample_position then
        InsertMediaAtSample(track_index, media_file_path, sample_position)
      else
        reaper.ShowMessageBox("Invalid data in CSV row, skipping", "Warning", 0)
      end
    end
  end

  file:close()

  -- End undo block
  reaper.Undo_EndBlock("Insert media from CSV", -1)
end

function Main()
  InsertMediaFromCSV()
end

reaper.defer(Main)
