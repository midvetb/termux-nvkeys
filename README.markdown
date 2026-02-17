# termux-nvkeys

Minimal Neovim wrapper that dynamically swaps Termux extra-keys on launch.

When `nvim` starts, the Termux keyboard layout switches automatically.  
When it exits, the layout is restored.

![demo](assets/demo.gif)

## Requirements

- Termux (Android)
- Neovim
- termux-api

## Installation

```bash
git clone https://github.com/midvetb/termux-nvkeys.git
cd termux-nvkeys
./install.sh
```
