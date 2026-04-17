import Foundation
import GhosttyKit
@testable import GhosttyTerminal
import Testing

struct TerminalHardwareKeyRouterTests {
    @Test
    func routesUIKitArrowKeysDirectlyForInMemoryBackends() {
        let session = InMemoryTerminalSession(write: { _ in }, resize: { _ in })
        #expect(
            TerminalHardwareKeyRouter.routeUIKit(
                usage: 0x50,
                backend: .inMemory(session)
            ) == .data(Data("\u{1B}[D".utf8))
        )
        #expect(
            TerminalHardwareKeyRouter.routeUIKit(
                usage: 0x52,
                backend: .inMemory(session)
            ) == .data(Data("\u{1B}[A".utf8))
        )
        #expect(
            TerminalHardwareKeyRouter.routeUIKit(
                usage: 0x2A,
                backend: .inMemory(session)
            ) == .data(Data([0x7F]))
        )
    }

    @Test
    func routesUIKitKeysToGhosttyForExecBackends() {
        #expect(
            TerminalHardwareKeyRouter.routeUIKit(
                usage: 0x50,
                backend: .exec
            ) == .ghostty(GHOSTTY_KEY_ARROW_LEFT)
        )
        #expect(
            TerminalHardwareKeyRouter.routeUIKit(
                usage: 0x04,
                backend: .exec
            ) == .ghostty(GHOSTTY_KEY_A)
        )
    }

    @Test
    func routesAppKitArrowKeysDirectlyForInMemoryBackends() {
        let session = InMemoryTerminalSession(write: { _ in }, resize: { _ in })
        #expect(
            TerminalHardwareKeyRouter.routeAppKit(
                keyCode: 0x7B,
                backend: .inMemory(session)
            ) == .data(Data("\u{1B}[D".utf8))
        )
        #expect(
            TerminalHardwareKeyRouter.routeAppKit(
                keyCode: 0x75,
                backend: .inMemory(session)
            ) == .data(Data("\u{1B}[3~".utf8))
        )
    }

    @Test
    func routesAppKitKeysToGhosttyForExecBackends() {
        #expect(
            TerminalHardwareKeyRouter.routeAppKit(
                keyCode: 0x7B,
                backend: .exec
            ) == .ghostty(GHOSTTY_KEY_ARROW_LEFT)
        )
        #expect(
            TerminalHardwareKeyRouter.routeAppKit(
                keyCode: 0x33,
                backend: .exec
            ) == .ghostty(GHOSTTY_KEY_BACKSPACE)
        )
    }

    /// Quote HID 0x34 must translate to AppKit keycode 0x27, not fall
    /// through to `0` (which is AppKit's keycode for the `A` key) nor to
    /// `GHOSTTY_KEY_QUOTE.rawValue` (which happens to equal AppKit's
    /// keycode for Tab — the original bug).
    @Test
    func appKitKeyCodeForUIKitTranslatesQuoteToMacKeycode() {
        #expect(
            TerminalHardwareKeyRouter.appKitKeyCodeForUIKit(usage: 0x34) == 0x27
        )
    }

    @Test
    func appKitKeyCodeForUIKitTranslatesCommonKeys() {
        // Letter A: HID 0x04 → AppKit 0x00
        #expect(
            TerminalHardwareKeyRouter.appKitKeyCodeForUIKit(usage: 0x04) == 0x00
        )
        // Tab: HID 0x2B → AppKit 0x30
        #expect(
            TerminalHardwareKeyRouter.appKitKeyCodeForUIKit(usage: 0x2B) == 0x30
        )
        // Enter: HID 0x28 → AppKit 0x24
        #expect(
            TerminalHardwareKeyRouter.appKitKeyCodeForUIKit(usage: 0x28) == 0x24
        )
        // ArrowUp: HID 0x52 → AppKit 0x7E
        #expect(
            TerminalHardwareKeyRouter.appKitKeyCodeForUIKit(usage: 0x52) == 0x7E
        )
    }

    @Test
    func appKitKeyCodeForGhosttyKeysTranslatesCommonKeys() {
        #expect(
            TerminalHardwareKeyRouter.appKitKeyCode(for: GHOSTTY_KEY_A) == 0x00
        )
        #expect(
            TerminalHardwareKeyRouter.appKitKeyCode(for: GHOSTTY_KEY_TAB) == 0x30
        )
        #expect(
            TerminalHardwareKeyRouter.appKitKeyCode(for: GHOSTTY_KEY_ESCAPE) == 0x35
        )
        #expect(
            TerminalHardwareKeyRouter.appKitKeyCode(for: GHOSTTY_KEY_ARROW_LEFT) == 0x7B
        )
    }

    @Test
    func appKitKeyCodeForGhosttyKeysReturnsSentinelForKeysAbsentFromMac() {
        let sentinel = TerminalHardwareKeyRouter.unidentifiedAppKitKeyCode
        #expect(
            TerminalHardwareKeyRouter.appKitKeyCode(for: GHOSTTY_KEY_CONTEXT_MENU) == sentinel
        )
        #expect(
            TerminalHardwareKeyRouter.appKitKeyCode(for: GHOSTTY_KEY_INSERT) == sentinel
        )
        #expect(
            TerminalHardwareKeyRouter.appKitKeyCode(for: GHOSTTY_KEY_CUT) == sentinel
        )
    }

    /// HID usages that have no AppKit counterpart must not collapse to `0`
    /// (AppKit's keycode for `A`). They must return the sentinel so
    /// libghostty's native-keycode lookup resolves them to `.unidentified`.
    @Test
    func appKitKeyCodeForUIKitReturnsSentinelForKeysAbsentFromMac() {
        let sentinel = TerminalHardwareKeyRouter.unidentifiedAppKitKeyCode
        // CUT, COPY, PASTE, CONTEXT_MENU, INSERT, PRINT_SCREEN, volume keys
        // are all in uiKitMap but absent from appKitMap.
        #expect(TerminalHardwareKeyRouter.appKitKeyCodeForUIKit(usage: 0x7B) == sentinel)
        #expect(TerminalHardwareKeyRouter.appKitKeyCodeForUIKit(usage: 0x7C) == sentinel)
        #expect(TerminalHardwareKeyRouter.appKitKeyCodeForUIKit(usage: 0x7D) == sentinel)
        #expect(TerminalHardwareKeyRouter.appKitKeyCodeForUIKit(usage: 0x65) == sentinel)
        #expect(TerminalHardwareKeyRouter.appKitKeyCodeForUIKit(usage: 0x49) == sentinel)
        #expect(TerminalHardwareKeyRouter.appKitKeyCodeForUIKit(usage: 0x46) == sentinel)
        #expect(TerminalHardwareKeyRouter.appKitKeyCodeForUIKit(usage: 0x7F) == sentinel)
    }

    /// ISO keyboards have a Section key that exists on both Mac
    /// (`kVK_ISO_Section = 0x0A`) and USB HID (`0x32`). The translation
    /// must not collapse to the unidentified sentinel.
    @Test
    func appKitKeyCodeForUIKitTranslatesIsoSectionKey() {
        // USB HID IntlBackslash (0x32) and its alias (0x64) both map to the
        // same AppKit keycode.
        #expect(
            TerminalHardwareKeyRouter.appKitKeyCodeForUIKit(usage: 0x32) == 0x0A
        )
        #expect(
            TerminalHardwareKeyRouter.appKitKeyCodeForUIKit(usage: 0x64) == 0x0A
        )
    }

    @Test
    func routeAppKitRecognizesIsoSectionKey() {
        #expect(
            TerminalHardwareKeyRouter.routeAppKit(
                keyCode: 0x0A,
                backend: .exec
            ) == .ghostty(GHOSTTY_KEY_INTL_BACKSLASH)
        )
    }

    @Test
    func appKitKeyCodeForUIKitReturnsSentinelForUnknownHID() {
        // HID usages not in uiKitMap at all.
        let sentinel = TerminalHardwareKeyRouter.unidentifiedAppKitKeyCode
        #expect(TerminalHardwareKeyRouter.appKitKeyCodeForUIKit(usage: 0xFFFE) == sentinel)
        #expect(TerminalHardwareKeyRouter.appKitKeyCodeForUIKit(usage: 0x0001) == sentinel)
    }
}
