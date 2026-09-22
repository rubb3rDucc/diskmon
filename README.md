# diskmon

A disk-usage watchdog for a self-hosted media server. It polls a filesystem and
pauses all qBittorrent torrents when usage crosses a threshold, resuming them
once there's room again, so an unattended download queue can't fill the disk and
take the rest of the stack down with it.

C++20, libcurl, no other runtime dependencies.

> **Status:** early. Currently reports disk usage; the qBittorrent control loop
> is in progress. See [Roadmap](#roadmap).

## Build

Requires CMake 3.25+, Ninja, and a C++20 compiler (GCC 14+ / Clang 17+).

```bash
cmake --preset debug
cmake --build --preset debug
./build/debug/diskmon
```

The `debug` preset enables AddressSanitizer and UndefinedBehaviorSanitizer.
Use `--preset release` for an optimised build.

## Configuration

Set via environment variables.

| Variable | Default | Description |
|---|---|---|
| `DISKMON_CHECK_PATH` | `/hostfs` | Filesystem to monitor |
| `DISKMON_THRESHOLD` | `85` | Percent usage that triggers a pause |
| `DISKMON_INTERVAL` | `5m` | Poll interval (`30s`, `5m`, `2h`) |
| `DISKMON_QB_URL` | `http://gluetun:8080` | qBittorrent WebUI |
| `DISKMON_QB_USERNAME` | — | Optional; omit if auth is disabled |
| `DISKMON_QB_PASSWORD` | — | |
| `DISKMON_NTFY_URL` | — | Optional [ntfy](https://ntfy.sh) topic for push alerts |

Usage is measured against blocks available to unprivileged processes
(`f_bavail`), not total free blocks — the ~5% root reserve on ext4 is not
usable space, and counting it makes an "85%" threshold fire closer to a real 90%.

## Docker

```bash
docker build -t diskmon .
docker run --rm \
  -v /:/hostfs:ro \
  -e DISKMON_THRESHOLD=85 \
  -e DISKMON_QB_URL=http://qbittorrent:8080 \
  diskmon
```

The container needs read-only access to the filesystem it watches and network
access to the qBittorrent WebUI. It runs as a non-root user.

## Roadmap

- [x] Read filesystem usage
- [ ] Poll on an interval
- [ ] Threshold crossing detection
- [ ] Configuration from the environment
- [ ] ntfy push notifications
- [ ] qBittorrent pause/resume
- [ ] Graceful SIGTERM shutdown

## Development

```bash
./scripts/watch.sh              # rebuild and rerun on save (needs watchexec)
clang-tidy -p build/debug src/main.cpp
```

`compile_commands.json` is symlinked at the repository root for clangd. Re-run
`cmake --preset debug` after adding a source file.

## Prior art

This replaces a Go implementation of the same service. The rewrite fixes a
free-space accounting bug (`f_bfree` vs `f_bavail`) and adds graceful shutdown
handling.
