tracks = {}
track_count = reaper.CountTracks(0)

for i=1, track_count do
  tracks[i] = reaper.GetTrack(0, i-1)
end


for i,track in ipairs(tracks) do
  status = {
  reaper.GetMediaTrackInfo_Value(track, "I_RECARM"),
  reaper.GetMediaTrackInfo_Value(track, "I_RECINPUT"),
  reaper.GetMediaTrackInfo_Value(track, "I_RECMODE")
  }
  reaper.ShowConsoleMsg(
    string.format(
      "Track: %d \n Record Armed: %d \n Record Input: %d \n Record Mode: %d \n\n",
      i, status[1], status[2], status[3]
    )
  )
end
