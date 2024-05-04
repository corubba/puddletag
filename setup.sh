#!/bin/sh

GROUP="input"
if ! getent group "$GROUP" > /dev/null ; then
  echo "Create group ${GROUP}"
  sudo groupadd --system "$GROUP"
fi
if id -nG "$USER" | grep -vqw "$GROUP" ; then
  echo "Add user ${USER} to group ${GROUP}"
  sudo gpasswd -a "$USER" "$GROUP"
fi

echo "Create and trigger udev rule"
echo "uinput" | sudo tee "/etc/modules-load.d/uinput.conf" > /dev/null
echo "KERNEL==\"uinput\", MODE=\"0660\", GROUP=\"$GROUP\"" | sudo tee "/etc/udev/rules.d/90-uinput.rules" > /dev/null
sudo udevadm control --reload
sudo udevadm trigger

echo "Install ydotool"
sudo apt install ydotool ydotoold

echo "Create and start ydotoold"
mkdir -p "${HOME}/.config/systemd/user"
echo "[Service]
Type=simple
ExecStart=ydotoold

[Install]
WantedBy=default.target" > "${HOME}/.config/systemd/user/ydotoold.service"
systemctl --user daemon-reload
systemctl --user restart "ydotoold"
systemctl --user enable "ydotoold"

echo "Install tools and dependencies"
sudo apt install vim git \
  python3 python3-mutagen python3-configobj python3-pyparsing python3-pyqt5 python3-pyqt5.qtsvg python3-unidecode \
  python3-pyqt6 python3-pyqt6.qtsvg \
  gdb \
  ;
echo "set debuginfod enabled" > "${HOME}/.gdbinit"

cd "${HOME}"
if [ ! -d "puddletag" ] ; then
  echo "Create git clone"
  git clone --origin "upstream" "https://github.com/puddletag/puddletag.git" "puddletag"
  cd "puddletag"
  git remote add "corubba" "https://github.com/corubba/puddletag.git"
  git fetch --all
  git checkout "corubba/debug/delete-segfault"
fi
