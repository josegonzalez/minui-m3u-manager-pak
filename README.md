# minui-m3u-manager.pak

A MinUI pak that manages M3U files for your emulators

## Requirements

This pak is designed and tested on the following MinUI Platforms and devices:

- `miyoomini`: Miyoo Mini Plus and the Miyoo Mini
- `my282`: Miyoo A30
- `my355`: Miyoo Flip
- `rg35xxplus`: RG-35XX Plus, RG-34XX, RG-35XX H, RG-35XX SP
- `tg5040`: Trimui Brick (formerly `tg3040`), Trimui Smart Pro
- `trimuismart`: Trimui Smart

Use the correct platform for your device.

## Installation

1. Mount your MinUI SD card.
2. Download the latest release from Github. It will be named `M3U.Manager.pak.zip`.
3. Copy the zip file to `/Tools/$PLATFORM/M3U Manager.pak.zip`. Please ensure the new zip file name is `M3U Manager.pak.zip`, without a dot (`.`) between the words `M3U` and `Manager`.
4. Extract the zip in place, then delete the zip file.
5. Confirm that there is a `/Tools/$PLATFORM/M3U Manager.pak/launch.sh` file on your SD card.
6. Unmount your SD Card and insert it into your MinUI device.

## Usage

> [!IMPORTANT]
> If the zip file was not extracted correctly, the pak may show up under `Tools > M3U`. Rename the folder to `M3U Manager.pak` to fix this.

Browse to Tools > M3U Manager and press A to enter the Pak. This will display two options:

- Generate M3U files: Generates M3U files for `chd`, `cue`, `dsk`, `gdi`, `iso`, and `pbp`.
- Generate Missing CUE files: Generates missing `cue` files for any `bin` files.

Choosing any option will allow you to choose an emulator folder to process. Only emulators directly containing files `chd`, `cue`, `dsk`, `gdi`, `iso`, and `pbp` (and not in a subfolder) will be visible.

### Debug Logging

Debug logs will be written to the ~$SDCARD_PATH/.userdata/$PLATFORM/logs/~ folder.
