#  nes-emu-ios

An NES emulator written in Swift for iOS / iPadOS / macOS / tvOS.  The NES emulation code is heavily based off of fogleman's NES emulator in Go: https://github.com/fogleman/nes 

### Screenshots
![NesRomViewController](/screenshots/screenshot01.png?raw=true) ![UIDocumentBrowserViewController](/screenshots/screenshot02.png?raw=true) ![ConsoleStateViewController](/screenshots/screenshot03.png?raw=true) ![SettingsViewController](/screenshots/screenshot04.png?raw=true)

This app uses the `UIDocumentBrowserViewController` for easy NES ROM (`.nes`) file browsing using the native Files app interface.  During emulation, PPU output frames are converted to a `CIImage` and rendered to a Metal Texture (`MTLTexture`) within a MetalKit View (`MTKView`).  The app uses `AVAudioEngine` for sound, with buffers scheduled periodically from the APU output.  Save states are persisted using `CoreData`.  Everything is done using native iOS frameworks, and no third-party libraries.


## Current Features
- 6502 CPU emulation
- PPU emulation (picture processing unit)
- APU emulation (audio processing unit)
- Mapper emulation for several common mappers
- Touchscreen controls
- Save states with autosave on exit, and automatic loading of most recent save on game start.  Automatic saving and loading can be enabled or disabled in the settings. **The data structure of states may change slightly for future builds, so if you build from an updated source, you may need to erase existing save states or uninstall the previous version.**
- Gamepad controls using built-in `GameController` framework and `extendedGamepad` profile.  MFi controllers, Sony DualSense / DualShock 4, or Xbox Wireless controllers should all work.  Touchscreen controls auto-hide when a controller is paired for player 1, and auto-show when the player 1 controller disconnects.  Whenever a second controller is paired, it should be mapped automatically for player 2.
- Builds successfully for iOS 14.7+, iPadOS 14.7+, tvOS 14.7+, or Mac Catalyst (macOS 12.0 Monterey or newer).  The Mac Catalyst version of the app still needs some Mac-specific tweaks.  The tvOS version does not include the `UIDocumentBrowserViewController` for ROM browsing, because it is unavailable on the tvOS platform.  For now, ROMs must be included directly in the tvOS app bundle before building and installing onto a device (copied to `/nes-emu-tvos/Resources/`, and added to the `nes-emu-tvos` build target).


## Game Compatibility 
The following mappers have been implemented:

- 000 NROM
- 001 MMC1
- 002 UNROM
- 003 CNROM
- 004 MMC3
- 005 MMC5 (missing some features)
- 007 AxROM
- 009 MMC2
- 011 ColorDreams
- 023 VRC2b / VRC4e / VRC4f
- 025 VRC2c / VRC4b / VRC4d
- 040 NTDEC2722
- 066 GxROM
- 078 Mapper 78
- 085 VRC7 (missing expansion audio)
- 087 Mapper 87
- 118 TxSROM
- 206 Namcot 118 / Tengen Mimic 1

This accounts for a good portion of the NES library, but there are still some big gaps remaining for popular mapper support.


## Performance
For best performance, build the app for **release** mode instead of debug.  Or, if you want better performance for debug builds, change these debug build settings under Swift Compiler - Code Generation:
- Disable Safety Checks = YES
- Exclusive Access to Memory = Compile Time Enforcement Only
- Optimization level = Optimize for Speed [-O]


## Near Future Plans
- Performance improvements (look for low hanging fruit in areas of the app that are taking the longest).
- On-screen control improvements (bigger tap areas, better layout).
- Improvements to tvOS app target (full-screen layout, mechanism to load new ROMs after installation)
