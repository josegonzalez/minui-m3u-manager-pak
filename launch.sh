#!/bin/sh
set -x
PAK_DIR="$(dirname "$0")"
PAK_NAME="$(basename "$PAK_DIR")"
PAK_NAME="${PAK_NAME%.*}"

rm -f "$LOGS_PATH/$PAK_NAME.txt"
exec >>"$LOGS_PATH/$PAK_NAME.txt"
exec 2>&1

echo "$0" "$@"
cd "$PAK_DIR" || exit 1
mkdir -p "$USERDATA_PATH/$PAK_NAME"

architecture=arm
if uname -m | grep -q '64'; then
    architecture=arm64
fi

export PATH="$PAK_DIR/bin/$architecture:$PAK_DIR/bin/$PLATFORM:$PAK_DIR/bin:$PATH"
export LD_LIBRARY_PATH="$PAK_DIR/lib/$architecture:$PAK_DIR/lib/$PLATFORM:$PAK_DIR/lib:$LD_LIBRARY_PATH"

main_screen() {
    minui_list_file="/tmp/minui-list-input"
    rm -f "$minui_list_file" "/tmp/minui-list-output"
    touch "$minui_list_file"

    cat >/tmp/minui-list-input <<EOF
Generate M3U files
Generate Missing CUE files
EOF

    killall minui-presenter >/dev/null 2>&1 || true
    minui-list --disable-auto-sleep --item-key "folders" --file "/tmp/minui-list-input" --format text --cancel-text "EXIT" --title "M3U Manager" --write-location /tmp/minui-list-output --write-value state
}

populate_emulator_list() {
    ls -A "$SDCARD_PATH/Roms" | sort >/tmp/emulators

    touch /tmp/emulators.list
    while read -r folder; do
        if [ ! -d "$SDCARD_PATH/Roms/$folder" ]; then
            continue
        fi

        cd "$SDCARD_PATH/Roms/$folder" || exit 1
        output="$(find . -type f \( -name "*.chd" -o -name "*.cue" -name "*.dsk" -o -name "*.gdi" -o -name "*.iso" -o -name "*.pbp" -o \))"
        if [ -n "$output" ]; then
            basename "$folder" >>/tmp/emulators.list
        fi
    done </tmp/emulators

    sed -i '/^[.]/d; /^APPS/d; /^PORTS/d' /tmp/emulators.list
    cd "$PAK_DIR" || exit 1
}

emulator_menu() {
    minui_list_file="/tmp/minui-list-input"
    rm -f "$minui_list_file" "/tmp/minui-list-output"
    touch "$minui_list_file"

    if [ ! -f "/tmp/emulators.list" ]; then
        show_message "Populating emulator list" forever
        populate_emulator_list
    fi

    killall minui-presenter >/dev/null 2>&1 || true
    minui-list --disable-auto-sleep --item-key "folders" --file "/tmp/emulators.list" --format text --cancel-text "EXIT" --title "Choose Emulator" --write-location /tmp/minui-list-output --write-value state
}

generate_cue_files() {
    emulator="$1"
    show_message "Generating Missing CUE files for $emulator" forever

    emulator_dir="$SDCARD_PATH/Roms/$emulator"
    find "$emulator_dir" -maxdepth 3 -name "*.bin" -type f | (
        # shellcheck disable=SC2030
        count=0

        while read -r target; do
            dir_path=$(dirname "$target")
            target_name=$(basename "$target")
            target_base="${target_name%.bin}"
            cue_path="$dir_path/$target_base.cue"

            if echo "$target_base" | grep -q ' (Track [0-9][^)]*)$'; then
                continue
            fi

            if [ -f "$cue_path" ]; then
                continue
            fi

            echo "FILE \"$target_name\" BINARY
  TRACK 01 MODE1/2352
    INDEX 01 00:00:00" >"$cue_path"

            count=$((count + 1))
        done

        show_message "Generated $count CUE $([ $count -eq 1 ] && (echo "file") || (echo "files"))." 2
    )
}

generate_m3u_file() {
    FILE_NAME="$1"
    M3U_PATH="$2"

    mkdir -p "$M3U_PATH"
    sync

    find . -maxdepth 1 ! -iname '*.m3u' -type f -iname "$FILE_NAME*.*[cue|gdi|chd|pbp|iso|dsk]" -exec mv -n -- '{}' "$M3U_PATH" \;
    sync

    cd "$M3U_PATH" || true
    find . ! -iname '*.m3u' -type f -iname "$FILE_NAME*.*[cue|gdi|chd|pbp|iso|dsk]" | sed -e 's|^./||' | sort >"$M3U_PATH/$FILE_NAME.m3u"
    sync
}

generate_m3u_files() {
    emulator="$1"
    show_message "Generating M3U files for $emulator" forever

    cd "$SDCARD_PATH/Roms/$emulator" || exit 1
    # Handle any of the following naming conventions:
    #
    # - TitleOfGame (USA) (Disc 1).chd
    # - TitleOfGame (USA) (Disc 1) (Rev 2).chd
    # - AmstradMSXTitleOfGame (19xx)(Developer)(Disc 1 of 3).dsk
    #
    # Note: the second pattern will potentially confuse moves where there are multiple revisions
    find . -maxdepth 1 ! -iname '*.m3u' -type f -iname "*([Dd][Ii][Ss][KkCc] 1*.*[cue|gdi|chd|pbp|iso|dsk]" | while read line; do
        game_name="$(echo "${line%.*}" | sed 's@./@@g' | sed 's@([Dd][Ii][Ss][KkCc] 1.*@@g')"
        game_name="${game_name%"${game_name##*[![:space:]]}"}" # remove spaces at the end
        m3u_folder="$SDCARD_PATH/Roms/$emulator/$game_name"
        cd "$SDCARD_PATH/Roms/$emulator" || exit 1
        generate_m3u_file "$game_name" "$m3u_folder"
    done
}

show_message() {
    message="$1"
    seconds="$2"

    if [ -z "$seconds" ]; then
        seconds="forever"
    fi

    killall minui-presenter >/dev/null 2>&1 || true
    echo "$message" 1>&2
    if [ "$seconds" = "forever" ]; then
        minui-presenter --message "$message" --timeout -1 &
    else
        minui-presenter --message "$message" --timeout "$seconds"
    fi
}

cleanup() {
    rm -f /tmp/stay_awake
    rm -f /tmp/minui-list-input /tmp/minui-list-output /tmp/emulators.list
    killall minui-presenter >/dev/null 2>&1 || true
}

main() {
    echo "1" >/tmp/stay_awake
    trap "cleanup" EXIT INT TERM HUP QUIT

    if [ "$PLATFORM" = "tg3040" ] && [ -z "$DEVICE" ]; then
        export DEVICE="brick"
        export PLATFORM="tg5040"
    fi

    allowed_platforms="miyoomini my282 my355 rg35xxplus tg5040 trimuismart"
    if ! echo "$allowed_platforms" | grep -q "$PLATFORM"; then
        show_message "$PLATFORM is not a supported platform" 2
        return 1
    fi

    if ! command -v minui-list >/dev/null 2>&1; then
        show_message "minui-list not found" 2
        return 1
    fi

    if ! command -v minui-presenter >/dev/null 2>&1; then
        show_message "minui-presenter not found" 2
        return 1
    fi

    chmod +x "$PAK_DIR/bin/$architecture/jq"
    chmod +x "$PAK_DIR/bin/$PLATFORM/minui-list"
    chmod +x "$PAK_DIR/bin/$PLATFORM/minui-presenter"

    while true; do
        main_screen
        exit_code=$?
        # exit codes: 2 = back button, 3 = menu button
        if [ "$exit_code" -ne 0 ]; then
            break
        fi

        output="$(cat /tmp/minui-list-output)"
        selected_index="$(echo "$output" | jq -r '.selected')"
        selection="$(echo "$output" | jq -r ".folders[$selected_index].name")"

        if [ -z "$selection" ]; then
            show_message "No selection made" forever
            continue
        fi

        # Show action menu
        emulator_menu "$selection"
        if [ $? -ne 0 ]; then
            continue
        fi

        output="$(cat /tmp/minui-list-output)"
        emulator_index="$(echo "$output" | jq -r '.selected')"
        emulator="$(echo "$output" | jq -r ".folders[$emulator_index].name")"
        if [ -z "$emulator" ]; then
            show_message "No emulator selected" forever
            continue
        fi

        if [ "$selection" = "Generate M3U files" ]; then
            show_message "Generating M3U files for $emulator" forever
            generate_m3u_files "$emulator"
        elif [ "$emulator" = "Generate Missing CUE files" ]; then
            generate_cue_files "$emulator"
        fi
    done
}

main "$@"
