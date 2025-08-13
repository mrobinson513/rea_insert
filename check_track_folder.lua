-- This script finds folder tracks by name given by user input in REAPER using ReaScript Lua API

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

-- Example usage:
local retval, user_input = reaper.GetUserInputs("Find Folder Track", 1, "Folder Track Name:", "")
if retval then
  local folder_name = user_input
  local track, index = FindFolderTrackByName(folder_name)
  if track then
    reaper.ShowMessageBox("Found folder track '" .. folder_name .. "' at index " .. index, "Info", 0)
  else
    reaper.ShowMessageBox("Folder track '" .. folder_name .. "' not found", "Info", 0)
  end
else
  reaper.ShowMessageBox("User cancelled input", "Info", 0)
end
