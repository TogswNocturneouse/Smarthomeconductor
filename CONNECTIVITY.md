# Connectivity Matrix

Conductor does not treat network detection, Apple Home import, or reachability as
physical command confirmation. A device becomes controllable only after a compatible
adapter is authenticated, capability-mapped, real-device tested, and able to confirm
the command result.

## Implemented Foundations

| Route | Current behavior |
| --- | --- |
| Manual inventory | Add and delete persistent device records |
| Bluetooth | Scan nearby BLE advertisements with Core Bluetooth |
| Local network | Browse `_hap._tcp`, `_matter._tcp`, `_shelly._tcp`, `_http._tcp`, `_rtsp._tcp`, and `_mqtt._tcp` with Network |
| Apple Home | Import authorized homes, rooms, accessories, reachability, model, and manufacturer with HomeKit; command dispatch still requires validation |
| Matter | Detect advertisements; system commissioning and cluster control remain the next transport layer |
| Adapter contract | Discovery, authentication, reads, typed execution, updates, reconnect, health, and disconnect |
| Assistant | Starts nearby scanning, applies compiled command policy, and audits rejected attempts |

## Device Routes

| Device | Preferred route | Notes |
| --- | --- | --- |
| Tapo L530, L510, L930 | Local Tapo | Provision in Tapo first; firmware may require Third-Party Compatibility |
| Tapo P100 x2 | Local Tapo | Authenticated local control is preferred |
| Tapo C220, TC71 | Local Tapo plus camera account | Streaming credentials are separate from the TP-Link account |
| Tapo H100, T310 | Local Tapo hub route | T310 is hub-attached |
| Xiaomi Air Purifier 4 Compact | Matter when exposed, otherwise Home Assistant/MiOT bridge | Keep provisioned in Xiaomi Home |
| Electrolux Wellbeing A5 | Authorized vendor or Home Assistant bridge | No public consumer OAuth flow is assumed |
| MDV split AC | Matter, compatible Midea bridge, then IR fallback | Identify the installed Wi-Fi module before implementing commands |
| Samsung Smart TV | SmartThings OAuth, local TV route, then IR fallback | SmartThings can import authorized devices and capabilities |

## Recommended Expansion Order

1. Validate Apple Home reads and typed writes on physical accessories.
2. Add and validate local MQTT/Shelly state and command transports.
3. Select one documented, properly licensed vendor API and obtain production approval.
4. Add Home Assistant REST/WebSocket import as an optional vendor-neutral bridge.
5. Add Matter commissioning and cluster control.
6. Add encrypted RF/IR bridge provisioning, learning, replay limits, and device fingerprints.

## Primary References

- Apple AccessorySetupKit: https://developer.apple.com/documentation/accessorysetupkit
- Apple HomeKit: https://developer.apple.com/documentation/homekit
- Apple Matter: https://developer.apple.com/documentation/matter
- Apple Network `NWBrowser`: https://developer.apple.com/documentation/network/nwbrowser
- Apple Core Bluetooth: https://developer.apple.com/documentation/corebluetooth
- SmartThings service integrations: https://developer.smartthings.com/docs/getting-started/what-you-can-build
- SmartThings device listing: https://developer.smartthings.com/docs/service-integrations/query-and-list-devices
- Home Assistant TP-Link/Tapo: https://www.home-assistant.io/integrations/tplink/
- Home Assistant Xiaomi Home: https://www.home-assistant.io/integrations/xiaomi_miio/
