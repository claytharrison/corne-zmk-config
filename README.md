# ZMK config — Corne Min

Wireless split, 42 keys, integrated nRF52840. **Not a nice!nano** — see
[GUIDE.md](GUIDE.md) before changing the board target.

```bash
$EDITOR config/corne_min.keymap
git commit -am "..." && git push     # Actions builds both halves
./flash.sh                           # flashes each half as you bootloader it
```

No reset button on this board. To reach the bootloader: hold both middle thumb
keys, then press the outermost key on row 3 — left end for the left half, right
end for the right half.

A keymap-only change needs the left half flashed; version or `.conf` changes
need both.

**[GUIDE.md](GUIDE.md)** covers the hardware details, bootloader access, version
pinning constraints, recovery, and troubleshooting.

## Layers

| Layer | Reached by | Contents |
|---|---|---|
| Base | — | Alphas, home-row mods on `ASDF`/`JKL;` |
| Lower | Left middle thumb | Numbers, Bluetooth, arrows |
| Raise | Right middle thumb | Numbers, symbols, volume |
| Mouse | Lower + right middle thumb | Mouse buttons, paging, `&bootloader` |

Home-row mods: tap for the letter, hold for the modifier (`hm`, tap-preferred,
200 ms). Adjust the timing at the top of the keymap if it misfires.
