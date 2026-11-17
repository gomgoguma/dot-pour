# Dot Pour Android BLE implementation

Based on `bluetooth_low_energy_android` **6.1.0**, published by zeekr.dev:
https://github.com/yanshouwang/bluetooth_low_energy

The original MIT license is retained in `LICENSE`. Dart API and generated
Pigeon messages are unchanged. Only the Android package is overridden; the
Windows and Apple implementations remain upstream dependencies.

Local changes:

- Request Android `CONNECTION_PRIORITY_HIGH` while the FFF1 measurement
  characteristic is subscribed; request balanced priority when unsubscribed or
  disconnecting, and reapply high priority on app resume while subscribed.
  Rejection is nonfatal. A successful request is not proof of
  the interval negotiated by the phone and scale.
- Serialize notification delivery through the main executor and Dart reply.
  When delivery stalls, adjacent complete, valid Dot weight frames are replaced
  by the newest pending weight. Commands, fragments, malformed packets and
  overload readings remain ordering barriers. Normal delivery has no added timer.
- Close GATT clients, notification queues and broadcast receivers on engine
  teardown. Ignore late callbacks from a previous GATT connection so they cannot
  remove its replacement. Activity recreation alone does not disconnect BLE.
- Keep an immutable copy of notification bytes while crossing threads.
- Remove the upstream workspace-only pubspec setting for use as a path package.

Run native regression tests from the app's `android` directory using JDK 17:

```sh
gradlew :bluetooth_low_energy_android:testReleaseUnitTest
```

Runtime sources and the Pigeon source are retained. Generated build directories
and upstream example apps are not included.
