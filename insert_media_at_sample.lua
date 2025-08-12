-- ReaScript: Insert Media File at Sample Position
-- Description: Inserts a media file on a given track at a specified sample position
-- Author: Generated Script
-- Version: 1.0

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

function Main()
    -- Configuration - modify these values as needed
    local track_index = 0  -- Track index (0 = first track)
    local sample_position = 44100  -- Sample position (44100 = 1 second at 44.1kHz)
    local media_file_path = ""  -- Path to media file

    -- Get user input for media file path
    local retval, user_input = reaper.GetUserInputs("Insert Media at Sample Position", 3,
        "Track Index (0-based):,Sample Position:,Media File Path:",
        track_index .. "," .. sample_position .. "," .. media_file_path)

    if not retval then
        return -- User cancelled
    end

    -- Parse user input
    local inputs = {}
    for input in user_input:gmatch("([^,]+)") do
        table.insert(inputs, input)
    end

    if #inputs < 3 then
        reaper.ShowMessageBox("Please provide all required inputs", "Error", 0)
        return
    end

    track_index = tonumber(inputs[1]) or 0
    sample_position = tonumber(inputs[2]) or 0
    media_file_path = inputs[3]:gsub("^%s*(.-)%s*$", "%1") -- trim whitespace

    -- Validate inputs
    if track_index < 0 then
        reaper.ShowMessageBox("Track index must be 0 or greater", "Error", 0)
        return
    end

    if sample_position < 0 then
        reaper.ShowMessageBox("Sample position must be 0 or greater", "Error", 0)
        return
    end

    if media_file_path == "" then
        reaper.ShowMessageBox("Please provide a media file path", "Error", 0)
        return
    end

    -- Begin undo block
    reaper.Undo_BeginBlock()

    -- Insert media
    local success = InsertMediaAtSample(track_index, media_file_path, sample_position)

    -- End undo block
    if success then
        reaper.Undo_EndBlock("Insert media at sample position", -1)
        reaper.ShowMessageBox("Media inserted successfully", "Success", 0)
    else
        reaper.Undo_EndBlock("Insert media at sample position (failed)", -1)
    end
end

-- Run the script
reaper.defer(Main)
