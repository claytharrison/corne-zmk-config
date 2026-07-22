# Working on this keyboard

Everything specific to *this* hardware, so future-you doesn't have to re-derive it.

## What the hardware actually is

| | |
|---|---|
| Keyboard | Corne Min (wireless split, 42 keys: 3×12 + 6 thumbs) |
| Controller | Integrated nRF52840 — **not** a nice!nano |
| Bootloader ID | `nRF52840-corne-min` (Adafruit UF2, USB `239a:00b3`) |
| Drive labels | `CORNE-MIN-L` / `CORNE-MIN-R` |
| Running ZMK | USB `1d50:615e` |
| Reset button | **None.** See [Getting into the bootloader](#getting-into-the-bootloader) |

The single most important fact: **this is not a nice!nano.** Firmware built for
`nice_nano` copies across without any error — the UF2 family ID matches on any
nRF52840 — and then simply doesn't work, because the key matrix pins differ. If
the keyboard enumerates over USB but no keys register, this is why.

## Everyday loop

```bash
$EDITOR config/corne_min.keymap
git commit -am "..." && git push        # GitHub Actions builds both halves
./flash.sh                              # waits for each half, flashes it
```

`./flash.sh` grabs the latest **successful** build, backs up the firmware already
on each half to `~/.local/share/corne-firmware-backups/`, writes the new one, and
waits for the reboot. It warns if your `HEAD` is ahead of the build it found —
that means you forgot to push, or CI hasn't finished.

```bash
./flash.sh --run 29930345688   # a specific run
./flash.sh --dir ./some-dir    # .uf2 files you already have
./flash.sh --no-backup         # skip the backup read
```

Flash **both halves** whenever the keymap changes. Mismatched firmware between
halves causes confusing pairing and dropped-key behaviour.

### Doing it by hand

```bash
gh run download <run-id> -R claytharrison/corne-zmk-config -D fw
udisksctl mount -b /dev/sdX                       # drive appears as CORNE-MIN-L/R
cp fw/firmware/corne_min_left-zmk.uf2 /run/media/$USER/CORNE-MIN-L/
sync                                              # board reboots itself
```

The board unmounts and reboots on its own once the write lands. You do not
eject it, and you do not need to unmount first.

## Getting into the bootloader

There is no reset button on this PCB. In order of convenience:

1. **The bootloader keys** (added to the mouse layer, one per half):

   > Hold **left-middle thumb** (LOWER) + **right-middle thumb** (`&mo 3`),
   > then press the **outermost key on row 3**.
   > Left end → left half. Right end → right half.

2. **ZMK Studio** — assign `&bootloader` to a key at runtime, no rebuild needed.

3. **Short `RST` to `GND` twice, quickly** — tweezers or a paperclip across the
   two adjacent pads on the controller. This is the only route if a half won't
   pair, and the reason to keep tweezers in the drawer.

Why one key per half: reset behaviours are declared
`BEHAVIOR_LOCALITY_EVENT_SOURCE` in ZMK, so they execute on whichever half
physically sourced the keypress. A key can only ever bootloader its own side.
It does still require the halves to be paired, since the central relays it.

## Version pinning — read before bumping

`config/west.yml` pins two things, both deliberately:

- **ZMK at `v0.3`** (Zephyr 3.5 era). This is *forced*, not preferred. The
  `corne_min` board definition uses the pre-Zephyr-4.1 board layout, so ZMK
  `main` **cannot** build this keyboard. Mainline renamed board targets in
  the [Zephyr 4.1 migration](https://zmk.dev/blog/2025/12/09/zephyr-4-1)
  (`nice_nano_v2` → `nice_nano@2.0.0/nrf52840/zmk`, etc.).
- **The board definition** at a specific commit of
  [`kenta-sakai-0/zmk-config`](https://github.com/kenta-sakai-0/zmk-config),
  pulled in as a west module (its `zephyr/module.yml` sets `board_root: .`).

That board definition is one person's work, not a vendor release — but it is
now validated against this actual hardware. **Don't bump it casually.** If you
do, keep a firmware backup within reach and be ready to test typing on both
halves immediately.

To move to current ZMK, the board definition has to be ported to the new layout
first (`boards/<vendor>/<board>/` with `board.yml` and variants).

## Repo layout

```
build.yaml                  which targets to build (board-only, no shield)
config/west.yml             ZMK version + board-definition module
config/corne_min.keymap     the keymap
config/corne_min.conf       Kconfig overrides
.github/workflows/build.yml calls ZMK's reusable workflow @v0.3
flash.sh                    download + flash helper
```

Filenames must match the board name minus the `_left`/`_right` suffix — hence
`corne_min.keymap`, not `corne.keymap`. This board has **no shield**; targets in
`build.yaml` are `board:` only.

## Keymap notes

Four layers: Base (0), Lower (1), Raise (2), Mouse (3). Lower and Raise are held
with the thumbs; Mouse is reached from Lower.

Home-row mods use a `hold-tap` behaviour, `hm`, defined at the top of the keymap
(`tap-preferred`, 200 ms). Tap for the letter, hold for the modifier.

Mouse buttons are `&mkp`, not `&kp`, and require `CONFIG_ZMK_POINTING=y` in
`config/corne_min.conf`. On v0.3 this Kconfig lives in `app/src/pointing/Kconfig`;
`ZMK_MOUSE` is its deprecated alias.

## When something breaks

| Symptom | Cause |
|---|---|
| Enumerates, no keys register | Firmware built for the wrong board |
| Build job silently skipped | `build.yaml` malformed — needs a top-level `include:` list |
| `Invalid BOARD` | Board target doesn't exist in the pinned ZMK version |
| `Could not find Zephyr` package | Missing `west zephyr-export` (only affects hand-rolled workflows) |
| One half dead / halves won't pair | Mismatched firmware — reflash both |
| Bootloader key does nothing | Halves unpaired, so the reset can't be relayed → short `RST`/`GND` |

### Recovery

Backups from `flash.sh` are in `~/.local/share/corne-firmware-backups/`. To roll
back, get the half into the bootloader and copy the old `.uf2` across. `CURRENT.UF2`
on a mounted bootloader drive is always a readback of what's on that half right now.

Nothing here is brickable: the UF2 bootloader lives in a protected flash region
and survives any application firmware you write.

## Links

- [ZMK docs](https://zmk.dev/docs) · [behaviors](https://zmk.dev/docs/keymaps)
- [Board definition](https://github.com/kenta-sakai-0/zmk-config)
- [Actions](https://github.com/claytharrison/corne-zmk-config/actions)
