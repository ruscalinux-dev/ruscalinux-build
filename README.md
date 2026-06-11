# ruscalinux-build

Build recipes (the "ricette") used to produce the **RuscaLinux** live ISO.

RuscaLinux is a Debian-based desktop distribution with a GNOME desktop,
built on **Debian trixie**, **amd64**, using the Debian
[`live-build`](https://wiki.debian.org/DebianLive) toolchain (`lb`).

Website: <https://www.ruscalinux.org/>

## What's here

| File | Purpose |
|------|---------|
| `1_config.sh`   | Runs `lb config`: distribution (trixie), architecture (amd64), mirrors, ISO metadata, boot parameters, Debian Installer settings. |
| `2_packages.sh` | Appends the package list installed into the live system (GNOME, internet, office, graphics, audio, etc.). |
| `3_custom.sh`   | Customisations: local `.deb` packages, boot splash, `os-release`, branding and desktop tweaks. |
| `4_build.sh`    | Runs `sudo lb build` and writes `SHA256SUMS`. |
| `local/`        | Local assets pulled into the build: branding logos, boot/GRUB/isolinux splash images, and prebuilt `.deb` packages in `local/extra_debs/`. |

## Requirements

- A Debian system (trixie recommended)
- `live-build` and its dependencies:

  ```sh
  sudo apt update
  sudo apt install live-build
  ```

- Root privileges for the final build step
- Enough free disk space (several GB) and a working internet connection

## How to build

Run the scripts in order from this directory:

```sh
sh 1_config.sh      # creates the ./ruscalinux working dir and configures live-build
sh 2_packages.sh    # adds the package list
sh 3_custom.sh      # applies customisations and branding
sh 4_build.sh       # builds the ISO (uses sudo) and writes SHA256SUMS
```

The resulting image is named `ruscalinux-1.99.iso` (see `--image-name` in
`1_config.sh`). Adjust the version and other options there if needed.

## Notes

- `local/extra_debs/` contains prebuilt packages for branding (icon theme,
  backgrounds, fonts). Their sources live in the companion repository
  [`ruscalinux-assets`](https://github.com/ruscalinux-dev/ruscalinux-assets).
- `SHA256SUMS` files are provided so you can verify the local assets.

## License

The build scripts in this repository are released under the **GNU General
Public License v3.0** — see [`LICENSE`](LICENSE).

Note that this repository also bundles third-party material (e.g. Debian
packages, icon themes) which remain under their own respective licenses.

**Trademarks:** the name *RuscaLinux*, the RuscaLinux logo and emblem are not
covered by the GPL — see [`TRADEMARK.md`](TRADEMARK.md).
