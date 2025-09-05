# dockerized-signal-desktop

Containerized build for **Signal Desktop** Linux packages (AppImage by default). Everything happens inside Docker; only the finished packages are copied out.

## Features

- **Container-only build** based on `node:22-bookworm`.
- **pnpm via Corepack** (pinned version).
- **Flexible targets**: `appimage`, `deb`, `rpm` or any combo.
- **No accidental publishing**: `--publish=never` is used.
- **Artifacts exported** from a clean, separate stage.

## Prerequisites

- Docker (BuildKit recommended)

## Quick start

~~~bash
# Build AppImage for a stable tag
docker build --pull \
  --build-arg SIGNAL_REF=v7.69.0 \
  --build-arg LINUX_TARGETS=appimage \
  -t signal-desktop-builder .

# Copy artifacts out of the image
CID="$(docker create signal-desktop-builder)"
mkdir -p out
docker cp "$CID:/out/." ./out/
docker rm -f "$CID" >/dev/null

# Inspect results
ls -lh out
~~~

### Other targets

~~~bash
# Build DEB + AppImage
docker build -t signal-desktop:deb-appimage \
  --build-arg SIGNAL_REF=v7.69.0 \
  --build-arg LINUX_TARGETS="deb,appimage" .

# Build RPM only
docker build -t signal-desktop:rpm \
  --build-arg SIGNAL_REF=v7.69.0 \
  --build-arg LINUX_TARGETS=rpm .
~~~

## Build args

| Arg             | Default                                                | Notes                                      |
|-----------------|--------------------------------------------------------|--------------------------------------------|
| `SIGNAL_REPO`   | `https://github.com/signalapp/Signal-Desktop.git`      | Upstream repo                              |
| `SIGNAL_REF`    | `v7.69.0` (example stable)                             | Tag/branch to build                        |
| `PNPM_VERSION`  | `10.6.4`                                               | pnpm version used via Corepack             |
| `LINUX_TARGETS` | `appimage`                                             | Comma-separated targets for electron-builder |

## How it works

- Installs build deps & `git-lfs`.
- Enables Corepack & activates a pinned pnpm.
- Clones Signal (LFS included), `pnpm install`.
- Runs repo build scripts if present, then:

  ~~~bash
  ./node_modules/.bin/electron-builder --linux "${LINUX_TARGETS}" --publish=never
  ~~~

- Export stage copies `/opt/Signal-Desktop/dist` to `/out`.

## Tips

- Use a `.dockerignore`:

  ~~~
  node_modules
  dist
  out
  .git
  *.AppImage
  ~~~

- Keep `--publish=never` to avoid `GH_TOKEN` prompts.
- If artifact ownership matters, you can `chown` after `docker cp`:

  ~~~bash
  sudo chown -R "$(id -u)":"$(id -g)" out
  ~~~

## License & Credits

This repo only provides a Dockerized build wrapper for **Signal Desktop**. All code, licenses, and trademarks for Signal belong to their respective owners.
