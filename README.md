# Twist

A minimal iOS focus app. Twist an egg-timer dial to set a duration, and the whole phone locks down until the timer runs out: every app except a short allowlist is shielded (Screen Time API: FamilyControls, ManagedSettings, DeviceActivity), and the internet is cut by a local "blackhole" VPN (NEPacketTunnelProvider). In an emergency you unlock by holding to "unwind" the dial for 30–60 seconds.

## MVP scope

- One main screen: a twistable timer (15 min to 4 h). Release and confirm to start.
- During a session: all apps shielded except an allowlist chosen once at setup (Phone, Maps), blackhole VPN on, app removal denied, branded shield with time left and an "I need access" button. The session ends on its own via DeviceActivity even if the app is killed.
- Emergency unlock: hold to unwind the dial.
- Onboarding: Screen Time access, VPN permission, allowlist.
- Out of scope for now: profiles, schedules, NFC/QR, stats, widgets, per-site blocking, macOS.

Stack: SwiftUI, iOS 18. Targets: app, ShieldConfiguration, ShieldAction, DeviceActivityMonitor, PacketTunnel. Foqos (github.com/awaseem/foqos, MIT) is a useful reference for the Screen Time parts.

## Plan

1. Branding and screens (canvas)
2. App skeleton and app blocking on a timer
3. Blackhole VPN
4. Emergency unlock
5. Polish and install via sideshelf
