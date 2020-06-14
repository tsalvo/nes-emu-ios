#  nes-emu-ios

An NES emulator written in Swift for iOS, ported from fogleman's NES emulator in Go: https://github.com/fogleman/nes

This app uses the UIDocumentBrowserViewController for easy NES ROM (.nes) file browsing using the native Files app interface.  During emulation, each PPU output frame is rendered to a UIView as a CGImage.  The app uses AVAudioEngine for sound, with buffers scheduled periodically from the APU output.  Everything is done using native iOS frameworks, with no third-party libraries.

## Current Features
- 6502 CPU emulation
- PPU emulation (picture processing unit)
- APU emulation (audio processing unit)
- Touchscreen controls
- Builds successfully for iOS 13+, iPadOS 13+, or Mac Catalyst (macOS 10.15 Catalina), but the Catalyst build still needs some Mac-specific tweaks

## Compatibility 
The following mappers have been implemented, with more coming soon:

-  NROM (0)
-  MMC1 (1)

[NES Mapper List](http://tuxnes.sourceforge.net/nesmapper.txt)

## Performance
For best performance, build the app for **release** mode instead of debug.  Or, if you want better performance for debug builds, change these debug build settings under Swift Compiler - Code Generation:
- Disable Safety Checks = YES
- Exclusive Access to Memory = Compile Time Enforcement Only
- Optimization level = Optimize for Speed [-O]

Supported games should be able to run at full speed on recent iOS devices (such as iPhone 11 Pro) with these settings, or in release mode, but I haven't done any testing yet on older devices.

## Near Future Plans
- Add support for more mappers, particularly the ones already supported in fogleman's NES emulator.
- Add setting to adjust audio sample rate, which may help reduce CPU usage.
- Performance improvements (look for low hanging fruit in areas of the app that are taking the longest)
- On-screen control improvements
- Support for built-in iOS game controller framework
- Save states
