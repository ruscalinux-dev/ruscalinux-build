#!/bin/sh
mkdir ruscalinux
cd ruscalinux
lb config \
  --iso-application "ruscalinux" \
  --iso-preparer "Nunzio Curcuruto" \
  --iso-publisher "ruscalinux" \
  --iso-volume "ruscalinux 1.99 amd64" \
  --checksums sha256 \
  --image-name "ruscalinux-1.99" \
  --distribution "trixie" \
  --architectures "amd64" \
  --archive-areas "main non-free-firmware" \
  --firmware-chroot "true" \
  --mirror-bootstrap "http://ftp.fr.debian.org/debian/" \
  --mirror-binary "http://ftp.fr.debian.org/debian/" \
  --binary-images "iso-hybrid" \
  --bootappend-live "boot=live components quiet splash timezone=UTC locales=en_US.UTF-8 keyboard-layouts=us hostname=ruscalinux username=user autologin noeject" \
  --bootappend-install "file=/cdrom/preseed.cfg" \
  --debian-installer "live" \
  --debian-installer-gui "true" \
  --debian-installer-distribution "trixie" \
  --cache "true" \
  --cache-indices "true"
