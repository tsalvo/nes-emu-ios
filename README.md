#  nes-emu-ios

An NES emulator written in Swift for iOS, ported from fogleman's NES emulator in Go: https://github.com/fogleman/nes

[![NesRomViewController](/screenshot1png.?raw=true)]

This app uses the UIDocumentBrowserViewController for easy NES ROM (.nes) file browsing using the native Files app interface.  During emulation, each PPU output frame is rendered to a UIView as a CGImage.  The app uses AVAudioEngine for sound, with buffers scheduled periodically from the APU output.  Everything is done using native iOS frameworks, and no third-party libraries.


## Current Features
- 6502 CPU emulation
- PPU emulation (picture processing unit)
- APU emulation (audio processing unit)
- Mapper emulation for several common mappers
- Touchscreen controls
- Gamepad controls for Player 1 (using built-in GameController framework and extendedGamepad profile).  If a controller is already paired before playing a game, it will be available for Player 1.
- Builds successfully for iOS 13+, iPadOS 13+, or Mac Catalyst (macOS 10.15 Catalina), but the Catalyst build still needs some Mac-specific tweaks.


## Game Compatibility 
The following mappers have been implemented:

-  NROM (0)
-  MMC1 (1)
-  UNROM (2)
-  CNROM (3)
-  MMC3 (4)

This accounts for a good portion of the NES library, but there are still some big gaps remaining for popular mapper support.


## Performance
For best performance, build the app for **release** mode instead of debug.  Or, if you want better performance for debug builds, change these debug build settings under Swift Compiler - Code Generation:
- Disable Safety Checks = YES
- Exclusive Access to Memory = Compile Time Enforcement Only
- Optimization level = Optimize for Speed [-O]


## Near Future Plans
- Add support for more mappers, particularly remaining mappers already supported in fogleman's NES emulator.
- Add setting to adjust audio sample rate, giving the user some control over CPU usage vs. sound quality.
- Performance improvements (look for low hanging fruit in areas of the app that are taking the longest).
- On-screen control improvements (bigger tap areas, better layout, auto-hide when using bluetooth controller, etc).
- Gamepad control improvements (button remap, player 2, reassign controllers, check for disconnects / reconnects etc.)
- Save states
