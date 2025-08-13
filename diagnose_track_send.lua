-- ReaScript Lua to create a send from one track to another and print send info for diagnosis

function PrintSendInfo(track, send_idx)
  local send_name = reaper.GetTrackSendName(track, send_idx, false) or "N/A"
  local send_vol = reaper.GetTrackSendInfo_Value(track, 0, send_idx, "D_VOL")
  local send_pan = reaper.GetTrackSendInfo_Value(track, 0, send_idx, "D_PAN")
  local send_mute = reaper.GetTrackSendInfo_Value(track, 0, send_idx, "B_MUTE")
  local send_phase = reaper.GetTrackSendInfo_Value(track, 0, send_idx, "B_PHASE")
  local send_src_track = reaper.GetTrackSendInfo_Value(track, 0, send_idx, "P_SRCTRACK")
  local send_dst_track = reaper.GetTrackSendInfo_Value(track, 0, send_idx, "P_DSTTRACK")

  reaper.ShowConsoleMsg(string.format("Send %d: Name=%s Vol=%.2f Pan=%.2f Mute=%d Phase=%d SrcTrack=%d DstTrack=%d\n",
    send_idx, send_name, send_vol, send_pan, send_mute, send_phase, send_src_track, send_dst_track))
end

function Main()
  local track_count = reaper.CountTracks(0)
  if track_count < 2 then
    reaper.ShowMessageBox("Need at least 2 tracks in project", "Error", 0)
    return
  end

  local src_track = reaper.GetTrack(0, 0) -- first track
  local dst_track = reaper.GetTrack(0, 1) -- second track

  -- Create send from src to dst
  local send_idx = reaper.CreateTrackSend(src_track, dst_track)
  if send_idx == -1 then
    reaper.ShowMessageBox("Failed to create send", "Error", 0)
    return
  end

  reaper.ShowConsoleMsg("Send created at index: " .. send_idx .. "\n")

  -- Print send info
  PrintSendInfo(src_track, send_idx)
end

reaper.Undo_BeginBlock()
Main()
reaper.Undo_EndBlock("Diagnose track send creation", -1)
