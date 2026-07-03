import AppKit
import Carbon.HIToolbox

/// Registers app-wide keyboard shortcuts via Carbon's RegisterEventHotKey,
/// which needs no extra permissions and works under App Sandbox.
@MainActor
final class HotKeyCenter {
    private struct Registration {
        let reference: EventHotKeyRef
        let action: () -> Void
    }

    private static let signature: OSType = 0x5352_5444 // 'SRTD'

    private var registrations: [UInt32: Registration] = [:]
    private var nextID: UInt32 = 1
    private var eventHandler: EventHandlerRef?

    func register(keyCode: Int, modifiers: Int, action: @escaping () -> Void) {
        installHandlerIfNeeded()

        var reference: EventHotKeyRef?
        let hotKeyID = EventHotKeyID(signature: Self.signature, id: nextID)
        let status = RegisterEventHotKey(
            UInt32(keyCode),
            UInt32(modifiers),
            hotKeyID,
            GetApplicationEventTarget(),
            0,
            &reference
        )
        guard status == noErr, let reference else { return }

        registrations[nextID] = Registration(reference: reference, action: action)
        nextID += 1
    }

    private func handle(id: UInt32) {
        registrations[id]?.action()
    }

    private func installHandlerIfNeeded() {
        guard eventHandler == nil else { return }

        var eventType = EventTypeSpec(
            eventClass: OSType(kEventClassKeyboard),
            eventKind: UInt32(kEventHotKeyPressed)
        )
        InstallEventHandler(
            GetApplicationEventTarget(),
            { _, event, userData in
                guard let event, let userData else { return noErr }

                var hotKeyID = EventHotKeyID()
                let status = GetEventParameter(
                    event,
                    EventParamName(kEventParamDirectObject),
                    EventParamType(typeEventHotKeyID),
                    nil,
                    MemoryLayout<EventHotKeyID>.size,
                    nil,
                    &hotKeyID
                )
                guard status == noErr else { return status }

                let center = Unmanaged<HotKeyCenter>.fromOpaque(userData).takeUnretainedValue()
                // Carbon dispatches application-target events on the main thread.
                MainActor.assumeIsolated {
                    center.handle(id: hotKeyID.id)
                }
                return noErr
            },
            1,
            &eventType,
            Unmanaged.passUnretained(self).toOpaque(),
            &eventHandler
        )
    }
}
