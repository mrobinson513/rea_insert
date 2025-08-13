-- ReaScript Lua to create a folder track named "Stereo Sums" with one nested regular audio track

function CreateFolderTrack(name)
  local track_count = reaper.CountTracks(0)
  reaper.InsertTrackAtIndex(track_count, true)
  local folder_track = reaper.GetTrack(0, track_count)
  if not folder_track then return nil end

  reaper.GetSetMediaTrackInfo_String(folder_track, "P_NAME", name, true)
  reaper.SetMediaTrackInfo_Value(folder_track, "I_FOLDERDEPTH", 1) -- folder start

  return folder_track
end

function CreateChildTrack(parent_track)
  local parent_idx = reaper.GetMediaTrackInfo_Value(parent_track, "IP_TRACKNUMBER") - 1
  reaper.InsertTrackAtIndex(parent_idx + 1, true)
  local child_track = reaper.GetTrack(0, parent_idx + 1)
  if not child_track then return nil end

  -- Set folder depth to 0 (normal track)
  reaper.SetMediaTrackInfo_Value(child_track, "I_FOLDERDEPTH", 0)

  return child_track
end

function Main()
  reaper.Undo_BeginBlock()

  local folder_track = CreateFolderTrack("Stereo Sums")
  if folder_track then
    CreateChildTrack(folder_track)
  end

  reaper.Undo_EndBlock("Create folder track Stereo Sums with one child track", -1)
end

reaper.defer(Main)
