# Dot Pour Android BLE implementation

Based on `bluetooth_low_energy_android` **6.1.0**, published by zeekr.dev:
https://github.com/yanshouwang/bluetooth_low_energy

The original MIT license is retained in `LICENSE`. Dart API and generated
Pigeon messages are unchanged. Only the Android package is overridden; the
Windows and Apple implementations remain upstream dependencies.

Local changes:

- Request Android `CONNECTION_PRIORITY_HIGH` while the FFF1 measurement
  characteristic is subscribed; request balanced priority when unsubscribed or
  disconnecting. Rejection is nonfatal. A successful request is not proof of
  the interval negotiated by the phone and scale.
- Timestamp weight callbacks before posting to the Android main executor and
  retain bounded interval/dispatch statistics for the active connection.
- Expose those statistics through `dot_pour/ble_latency` for the app's optional
  diagnostic export. No device address or UUID is included in the exported map.
- Keep an immutable copy of notification bytes while crossing threads.
- Remove the upstream workspace-only pubspec setting for use as a path package.

Run native regression tests from the app's `android` directory using JDK 17:

```sh
gradlew :bluetooth_low_energy_android:testReleaseUnitTest
```

Runtime sources and the Pigeon source are retained. Generated build directories
and upstream example apps are not included.
