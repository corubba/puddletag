#!/bin/bash

systemctl --user restart ydotoold

cd "${HOME}/puddletag"

WORK_DIR="${HOME}/delete-segfault-test"

if [ ! -d "$WORK_DIR" ] ; then
  echo "Create work dir ${WORK_DIR}"
  mkdir -p "$WORK_DIR" || exit 10
fi

FILE_SRC="testfile.mp3"
FILE_DST="${WORK_DIR}/0000.mp3"
if [ ! -f "$FILE_DST" ] ; then
  echo "Copy file ${FILE_SRC} to ${FILE_DST}"
  cp "$FILE_SRC" "$FILE_DST" || exit 20
fi

echo "Creating hardlinks ..."
ROUNDS=1000
FILES_PER_ROUND=4
TARGET_COUNT="$(( ( $ROUNDS + 1 ) * $FILES_PER_ROUND ))"
LINK_COUNT=0
for I in $(seq -w 0001 "$TARGET_COUNT" ) ; do
  FILE_LINK="${WORK_DIR}/${I}.mp3"
  if [ ! -f "$FILE_LINK" ] ; then
    LINK_COUNT="$(( $LINK_COUNT + 1 ))"
    ln "$FILE_DST" "$FILE_LINK" || exit 30
  fi
done
echo "Created ${LINK_COUNT}" hardlinks

if [ "wayland" = "$XDG_SESSION_TYPE" ] ; then
  echo "Fixing env to allow starting with wayland"
  export QT_QPA_PLATFORM=wayland
fi

# echo "use xwayland"
# export XDG_SESSION_TYPE="x11"

export PYTHONUNBUFFERED=1

#gdb --batch \
#  --eval-command="set style enabled on" \
#  --eval-command="run puddletag ${WORK_DIR}" \
#  --eval-command="bt full" \
#  python3 \
#  &
python3 puddletag "$WORK_DIR" &
#.venv/bin/python puddletag "$WORK_DIR" &
PUDDLETAG_PID="$!"
echo "Started puddletag with pid ${PUDDLETAG_PID}"

#echo "Ready?"
#read -n 1 FOO

echo "Waiting for startup to finish"
sleep 10

echo "Running ${ROUNDS} test rounds ..."
ydotool key "108:1" "108:0" "108:1" "108:0" || exit 40  # 2x down
for I in $(seq 1 "$ROUNDS") ; do
  echo "  Round ${I}/${ROUNDS}"

  if ! kill -0 "$PUDDLETAG_PID" > /dev/null 2>&1 ; then
    echo "puddletag terminated, aborting."
    break
  fi

  if [ 0 -eq $(( $I % 100 )) ] ; then
    echo "Restarting ydotoold"
    systemctl --user restart ydotoold | exit 41
  fi

  if [ 1 -lt "$FILES_PER_ROUND" ] ; then
    ydotool key "42:1" || exit 42  # shift-down
    for J in $(seq 1 $(( $FILES_PER_ROUND - 1)) ) ; do
      ydotool key "108:1" "108:0" || exit 43  # down
    done
    ydotool key "42:0" || exit 44  # shift-up
  fi
  ydotool key "111:1" "111:0" || exit 45  # Delete
  ydotool key "56:1" "44:1" "44:0" "56:0" || exit 46  # alt+z

  sleep ".3s"
done

if kill -0 "$PUDDLETAG_PID" > /dev/null 2>&1 ; then
  echo "Terminate puddletag"
  kill "$PUDDLETAG_PID" || exit 50
fi

echo "Waiting for puddletag to exit ..."
wait "$PUDDLETAG_PID"

echo "Done".
