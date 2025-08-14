# GBA Aseprite Shader

Recreates the original Game Boy Advance screen look in digital pixelart.

## Installation

1. Download the `gba-aseprite-shader.aseprite-extension` file from the [latest release](https://github.com/davidegaspar/gba-aseprite-shader/releases/latest)
2. Double-click the file to install, or **Edit** → **Preferences** → **Extensions** → **Add Extension**

## Usage

**Edit** → **FX** → **GBA Shader**

## Shader pipeline

### Color Effects

- Desaturates based on Luminance
- Limits brightness range
- Matches screen color characteristics
  - `Red` shift to `Green`
  - `Blue` shift to `Green`
  - `Green` desaturation

_Note: The Blue in the real screen is more Cyan than the shader can achieve._

### Pixel simulation

- Simulates each pixel in a `6x6` grid
- `Blue`|`Green`|`Red` Layout
- Blends sub-pixels
- Simulates the dark lines between LCD pixel rows

### Output

- New 6x Scale sprite

## Development

### Deploy

```sh
./deploy.sh # and follow instructions
```
