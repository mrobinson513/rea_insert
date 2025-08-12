# ReaScript: Insert Media at Sample Position

This ReaScript allows you to insert a media file on a specified track at a precise sample position in REAPER.

## Features

- Insert media files at exact sample positions
- Automatic sample-to-time conversion based on project sample rate
- User-friendly input dialog
- Error handling and validation
- Undo support

## Usage

1. Load the script in REAPER (Actions → Load ReaScript)
2. Run the script
3. Enter the required information in the dialog:
   - **Track Index**: 0-based track number (0 = first track, 1 = second track, etc.)
   - **Sample Position**: The exact sample number where you want to insert the media
   - **Media File Path**: Full path to the media file you want to insert

## Example

- Track Index: `0` (first track)
- Sample Position: `44100` (1 second at 44.1kHz sample rate)
- Media File Path: `/path/to/your/audio/file.wav`

## Technical Details

- The script automatically converts sample positions to time based on the project's sample rate
- Supports all media formats that REAPER can handle
- Creates proper media items with takes and sources
- Updates the arrangement view after insertion

## Requirements

- REAPER v6.0 or later
- Valid media file path
- Existing track at the specified index
