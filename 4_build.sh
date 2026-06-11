#!/bin/sh
cd ruscalinux
sudo lb build
sha256sum *.iso > SHA256SUMS
