# ZMK Configuration for Corne Keyboard

## Quick Start

### 1. Build Firmware via GitHub Actions
- Push this config to a GitHub repository
- GitHub Actions will automatically build the firmware
- Download the `.uf2` files from the Actions artifacts

### 2. Flash to Corne
1. Double-press the reset button on each half
2. The keyboard will appear as a USB drive
3. Copy the `.uf2` file to each half:
   - `corne_left.uf2` → left half
   - `corne_right.uf2` → right half

## Customizing Your Keymap

Edit `config/corne.keymap` to change key bindings.

### Key Codes Reference
- `&kp A` - Key press (letter A)
- `&kp N1` - Number 1
- `&kp SPACE` - Spacebar
- `&kp BSPC` - Backspace
- `&kp RET` - Return/Enter
- `&kp TAB` - Tab
- `&kp ESC` - Escape
- `&kp LSHIFT`, `&kp RSHIFT` - Shift keys
- `&kp LCTRL`, `&kp RCTRL` - Control keys
- `&kp LALT`, `&kp RALT` - Alt keys
- `&kp LGUI`, `&kp RGUI` - GUI/Command keys
- `&kp LEFT`, `&kp UP`, `&kp DOWN`, `&kp RIGHT` - Arrow keys
- `&kp F1` through `&kp F12` - Function keys
- `&trans` - Transparent (passes to lower layer)
- `&none` - No action (blocks lower layer)

### Layers
- **Base**: Default layer
- **Lower**: Activated by LOWER key on left thumb
- **Raise**: Activated by RAISE key on right thumb

## Local Build (Optional)

```bash
# Install dependencies
sudo apt install -y git wget flex bison gperf wget \
    ninja-build xz-utils zip cmake libusb-1.0-0-dev \
    python3-pip python3-setuptools python3-dev

# Clone ZMK
git clone https://github.com/zmkfirmware/zmk.git ~/zmk
cd ~/zmk

# Set up workspace
west init ~/zmk-config
west update

# Build
west build -b corne_left ~/zmk-config/config
west build -b corne_right ~/zmk-config/config
```

## Resources
- [ZMK Documentation](https://zmk.dev/docs)
- [ZMK Keymap Behaviors](https://zmk.dev/docs/keymaps)
- [Corne Keyboard Info](https://github.com/foostan/crkbd)
