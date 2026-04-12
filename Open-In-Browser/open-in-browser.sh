#!/bin/bash

FILE_PATH="$1"

# 1. Check for .web2 (Port 6060) — must come before .web
if [[ "$FILE_PATH" == *"/media/mahdi/D-drive/.web2"* ]]; then
    RELATIVE_PATH="${FILE_PATH#*/media/mahdi/D-drive/.web2}"
    RELATIVE_PATH="${RELATIVE_PATH#/}"
    URL="http://192.168.1.32:6060/$RELATIVE_PATH"

# 2. Check for .web3 (Port 6061) — must come before .web
elif [[ "$FILE_PATH" == *"/media/mahdi/D-drive/.web3"* ]]; then
    RELATIVE_PATH="${FILE_PATH#*/media/mahdi/D-drive/.web3}"
    RELATIVE_PATH="${RELATIVE_PATH#/}"
    URL="https://192.168.1.32:6061/$RELATIVE_PATH"

# 3. Check for .web (Port 60) — most generic, goes last
elif [[ "$FILE_PATH" == *"/media/mahdi/D-drive/.web"* ]]; then
    RELATIVE_PATH="${FILE_PATH#*/media/mahdi/D-drive/.web}"
    RELATIVE_PATH="${RELATIVE_PATH#/}"
    URL="https://192.168.1.32:60/$RELATIVE_PATH"

else
    notify-send "Nemo Action" "Folder is not inside a recognized web directory."
    exit 1
fi

xdg-open "$URL"
