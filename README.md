# Dot Pour

<img src="assets/brand/dot-pour-drops.png" alt="Dot Pour logo with two drops" width="80" />

Dot Pour connects to a Bluetooth LE coffee scale and tracks poured water, flow rate, and progress toward your target on a live brew graph. It is built with Flutter and currently supports the **TIMEMORE Black Mirror Dot (TES017)**.

## Getting started

1. On first launch, scroll the **Language** picker and confirm a language. You can change it later in **Settings**. Dot Pour supports English, Korean, Japanese, Simplified Chinese, Spanish, and Brazilian Portuguese.
2. Select **TIMEMORE Black Mirror Dot**. Dot Pour remembers your selection. You can change it under **Settings → Scale Model**.
3. Turn on the scale and close any other app connected to it. Tap **Connect** at the top of the screen and select your scale. Its battery level appears next to the connection button once the scale reports it.
4. On Android, allow the Nearby devices permission. Android 11 and earlier may require location permission and enabled location services.

Selecting a model and connecting over Bluetooth are separate actions. Selecting a model leaves scanning and permission requests until you connect. Model changes are disabled during a brew or while a connection is in progress. Switching models closes the previous connection and subscriptions and preserves your settings, recipes, and completed brew records.

## Scale mode

**Scale** is the default mode. It shows live weight, a small flow-rate readout based on recent weight changes, and a timer you can start, pause, resume, or reset manually. The timer keeps its state when you switch tabs or sections. **TARE** zeros the scale and leaves the timer as it was.

You can enable **Auto-detect pouring** to start the timer when weight rises on consecutive readings after staying near 0 g for 0.3 seconds. The option is off by default and your choice is saved. Use the resume button after pausing. Resetting the timer makes it wait for another pour from 0 g.

## Pour-over mode

1. **Set up your equipment.** Place the server and dripper on the scale, then tap **Start weighing coffee**. Dot Pour records their combined weight as the baseline. It shows only the added coffee weight in the next step. For example, if the reading goes from 380 g to 398 g, the dose is 18 g. The scale's zero point stays the same.
2. **Weigh the coffee.** Tap **Set up equipment again** if you need to start over. This clears the dose and baseline and prompts you to remove the coffee before weighing again. **Enter dose manually** is available at the top right of the card in either step. You can also use **TARE** in Scale mode while keeping your current dose and preparation step.
3. **Choose a ratio.** Use a preset, tap the ratio to type a value, or use **−** and **+** to adjust it in 0.5 increments. A 20 g dose at 1:16 gives a 320 g target. Pouring 160 g, 320 g, and 352 g shows 50%, 100%, and 110% progress, respectively.
4. **Start brewing.** The start button stays visible during both preparation steps and shows the dose, ratio, and water target. It becomes available when the dose is valid and the target is within the scale's capacity. Starting a brew fixes the dose and ratio, tares the scale, and opens the brew screen after a fresh reading near 0 g.
5. **Pour and finish.** The poured-water reading starts at 0 g. The app timer starts after two consecutive readings show at least 0.5 g of water. Measurements continue after you reach the target. Tap **Finish brew** to see the results, then tap **Save as recipe** if you want to keep the brew. The save dialog opens only when you request it.

### Equipment and dose detection

- When the equipment weight holds steady for 1.5 seconds, the app prompts you to start weighing coffee. While you're setting up, the card shows this guidance in place of the equipment's total weight.
- An increase of more than 40 g is treated as added equipment. The app waits for the new weight to settle before updating the baseline. This works when the server and dripper are placed in succession and when a dripper is added after dose weighing has begun. Brew start is temporarily disabled while the weight settles.
- An increase of up to 40 g that holds for 0.8 seconds is treated as a possible dose. Changes within 0.5 g are ignored as noise. In the equipment step, tap **Use detected dose** to confirm it. In the weighing step, the added weight appears as the dose. Detection alone leaves you in the current step, and a confirmed manual dose stays fixed.
- The thresholds can mistake a dripper weighing 40 g or less for coffee, or a dose added all at once above 40 g for equipment.

### While brewing

The brew screen hides the mode tabs to make room for the graph. It shows poured water, the target, and flow rate, with elapsed time to the left of progress. A small live weight reading sits beside the dose and ratio at the top right. An amber dot appears while the app waits for usable readings. The graph plots time on the horizontal axis and mass in grams on the vertical axis.

The clock keeps running if you lift the server or swirl the dripper. If there is a sudden weight change or an overload, the graph continues at the last confirmed poured-water value. Tracking resumes after the equipment is back and consecutive valid readings arrive. Weight changes during the wait are excluded from the poured-water estimate. With just the server on the scale, you can measure the collected beverage. Keep the total weight, including the vessel, within the scale's capacity.

### Navigation and Windows demo

The **Scale**, **Pour over**, and **Espresso** tabs return when you prepare a new brew. The bottom navigation opens **Brewing**, **Recipes**, or **Settings**. An active brew continues recording as you navigate.

On Windows, use **Try without a scale** to adjust the simulated weight with a slider or run an automatic pour. During a brew, **Lift equipment** and **Set equipment down** simulate a pause in tracking and its recovery. If a recipe is loaded, use **Follow recipe** to simulate its pours. Demo records are labeled as such.

### Display

The interface uses a cream background, white cards with warm-gray borders and subtle shadows, charcoal primary buttons, and beige secondary buttons. Terracotta (`#D96B43`) marks accents, with a darker shade for small accent text. Disabled start buttons have no dark outline. The app and preview use bundled Pretendard fonts with consistent weights, letter spacing, and tabular numerals. The two-drop logo and the Bluetooth and battery indicators sit at the top.

Compact spacing keeps the main Scale and preparation controls visible on a 320 × 740 screen. Scale mode uses smaller weight and timer readouts and centers the flow rate under the weight. The brew screen shows poured water in large type, the target in gray to its right, and flow rate underneath. The graph appears once brewing starts.

The ratio control centers **− / 1 : ratio / +**, uses outlined circular buttons, and separates the control from its presets with a divider. Brewing and the recipe editor group the presets under **ICE** (1:9, 1:10, 1:11) and **HOT** (1:15, 1:16.7, 1:17). Each preset has its own outline, with a charcoal fill for the selected preset.

## Espresso mode

1. Enter your dose manually, or weigh it in the espresso tab. To use a saved portafilter or dosing cup, register it empty first. Include the basket and any dosing ring you use when weighing coffee.
2. Select the saved vessel, tare the bare scale, and place the loaded vessel on it. Dot Pour subtracts the saved empty weight. Tap the displayed dose to confirm it. You can also tare an empty container and weigh the coffee directly.
3. Remove the dosing vessel and place the shot cup on the scale. Choose automatic or manual start. Both tare the cup. Automatic start waits for two consecutive readings at least 0.2 g above zero.
4. The chart shows yield in grams and flow in grams per second on the same time axis. The shot finishes after a pour lasting at least five seconds is followed by four seconds without a meaningful increase. You can finish manually at any time.

## Recipes

- **Save a brew.** The results stay on screen after you finish. Tap **Save as recipe** to name and save the record with time, water weight, and flow rate. You can add the coffee used, brew notes, and 1–5 star ratings for acidity, sweetness, and body. Tap the selected star again to clear it. Brew records are available in the recipe details, including recipes saved by earlier versions. Sessions with no water poured cannot be saved.
- **Brew a saved recipe.** Open **Recipes**, select a recipe, and tap **Brew this recipe**. The reference curve is dashed and the live brew is solid. The guide shows the current pour, cumulative target, average flow for that pour, time until the next pour, and the difference from the reference amount. You pour the water yourself.
- **Create a manual plan.** Tap **+** in your recipe list. Set a name, dose, ratio, and 1–20 pours. Each pour has a start time, duration, and amount in grams or percent. For a 300 g target, 20% / 40% / 40% adds 60 g / 120 g / 120 g, giving cumulative targets of 60 g / 180 g / 300 g.
- **Set timing and totals.** The first pour starts at 0 seconds. Later pours start at or after the end of the previous one. Pour amounts must add up to the water target or 100%. Total brew time can include a wait after the last pour. Switching between grams and percent converts the entered amounts. The editor can distribute water evenly and preview the curve.
- **Scale a recipe.** When you start a brew, Dot Pour adjusts a loaded recipe's water amounts and reference curve to match your measured dose and selected ratio. The timing and the saved recipe stay the same.
- **Review recorded pours.** The app estimates pour stages from weight changes. Pauses shorter than 5 seconds stay within the same stage. A pause of at least 5 seconds starts a new stage when pouring resumes. The reference graph keeps the original readings, including pauses. This rule applies to newly saved records. Existing stages and manual plans are preserved. You can also create a separate manual plan from a record.
- **Keep recipes on this device.** Saved recipes persist between launches. Clearing app data or uninstalling may remove them. Cloud sync and export are pending.

## Versioning

The espresso preview version is **0.9.0+39**. Releases with new capabilities, such as espresso mode, increment the minor version. Fixes and copy edits within existing features increment the patch version. Each distributed APK increments the Android build number, which Android uses to determine update order.

## Development setup

- Flutter 3.29.3 and Dart 3.7.2 or later.
- `bluetooth_low_energy` 6.1.0 for native BLE on Android, iOS, and Windows.
- `shared_preferences` for the last ratio, selected scale, and recipes.
- `wakelock_plus` to keep the screen awake during a brew.

```sh
flutter pub get
flutter analyze
flutter test
```

### Android

Install the Android SDK and NDK 27.0.12077973 and accept the SDK licenses. Use a full **JDK 17** with `jlink`. The lightweight Java runtime bundled with an IDE may lack build tools. Use a physical device to test BLE.

```sh
flutter run -d <android-device-id>
flutter build apk --debug
flutter build apk --release
```

If Windows picks a different Java version, set `JAVA_HOME` to your JDK 17 directory in the build terminal. Use a release APK for performance comparisons. Release APKs currently use the same development signing key as earlier test APKs, so they can update compatible test installs. Store distribution requires a separate signing setup.

### Windows

Install the Visual Studio C++ build tools.

```sh
flutter run -d windows
```

If Flutter cannot link plugins, enable Windows Developer Mode or run `powershell -File tool/windows-plugin-links.ps1` to create junctions within the project. Run **`flutter pub get` again** afterward to register the native plugins. When sharing a Windows build, include the entire `Release` folder.

### iOS

Use macOS with Xcode. Running on a physical iPhone requires signing. Build without signing with the following command on macOS.

```sh
flutter build ios --no-codesign
```

## Behavior and limitations

- The app timer runs independently of the scale's timer. On connection, Dot Pour checks the scale's response to the command to set the unit to grams.
- On the Dot, starting a brew confirms the dose, tares the scale, and establishes the baseline. **TARE** is available in Scale mode and disabled during brewing. An adapter without tare support uses an app-side baseline.
- A disconnection or a data gap of at least 2 seconds ends the session. Sudden weight changes and brief overloads instead pause weight tracking until normal readings return, with no reset to 0 g or additional tare. Use Dot Pour with the screen on. Background connection and automatic reconnection are pending.
- On a live connection, the next reading is used to check a sudden spike. Flow rate comes from the last 0.4 seconds of valid weight changes. The app does not use the Dot's separate flow reading on the brew screen. The graph samples about every 0.25 seconds and uses a longer interval for long recordings to limit stored data. Excluded segments remain marked after saving, replaying, or downsampling.
- Small fluctuations leave tracking active. A significant lift or spike is excluded, and tracking can resume while water is being poured once consecutive normal readings return. During recovery, the last confirmed water amount holds until the reading reaches its previous level or settles slightly below it. If it settles slightly lower, the baseline is adjusted so subsequent increases are counted from that weight. Intermediate readings while the weight is still rising do not increase the recorded amount. Large weight losses and sudden zero readings do not trigger a baseline adjustment.
- Measurements update on the next Flutter frame as notifications arrive. End-to-end response time also includes sensor and wireless latency.
- Dot Pour checks the Dot's primary BLE service and model information. Firmware differences may affect responses and pairing and require testing on the device.
- A zero CRC in the reserved field is accepted. Nonzero CRCs are validated.
- Windows checks pairing before connecting. Android requests permissions after initializing BLE and skips permissions already granted. Closing the device picker cancels an active scan.

On Android, Dot Pour requests a higher BLE connection priority when it subscribes to weight notifications and when the app returns to the foreground. It restores balanced priority after unsubscribing or disconnecting. The scale can still connect if the request is denied, and the actual interval depends on negotiation between the devices. Flutter engine shutdown cleans up native connections, notification queues, and event receivers. Late callbacks from an older connection are kept separate so they cannot close a newer one.

If Android notification delivery falls behind, the newest reading replaces an undelivered reading from the same run of normal weight packets. Command responses, fragmented packets, and overload readings retain their order. Normal delivery has no added wait timer.

## Project structure

| Path | Responsibility |
| --- | --- |
| `lib/scales/scale.dart` | Shared `CoffeeScale` interface for scanning, connecting, reading, taring, and disconnecting |
| `lib/scales/scale_models.dart` | Device information, capabilities, and readings in g and g/s |
| `lib/scales/scale_registry.dart` | Model list and adapter factories, currently containing the Dot |
| `lib/scales/timemore_dot/` | Dot BLE adapter, framing, CRC checks, and packet decoding |
| `lib/brew_session.dart` | Ratio and flow calculations, brew state, and time-series samples |
| `lib/pour_signal.dart` | Lift and swirl filtering and weight recovery |
| `lib/brew_controller.dart` | BLE, demo, weighing, brewing, and recipe state |
| `lib/manual_timer.dart`, `lib/scale_flow.dart`, `lib/ui/basic_scale.dart` | Scale mode, flow rate, manual timer, and optional pour detection |
| `lib/ui/save_recipe_dialog.dart` | Post-brew coffee details, notes, ratings, and record display |
| `lib/recipe.dart`, `lib/recipe_store.dart` | Pour plans, reference curves, brew guidance, and local storage |
| `lib/main.dart`, `lib/ui/` | Scale selection, brewing screens, graphs, settings, and recipe library and editor |
| `test/` | Protocol, calculation, and UI flow tests |
| `packages/bluetooth_low_energy_android/` | Local MIT-licensed Android plugin based on 6.1.0, with connection priority and notification queue changes. Windows and iOS use the upstream implementations. |

The [two-drop logo](assets/brand/dot-pour-drops.png) is the source artwork. Its generation tool and prompt are documented in [generation-drops.txt](assets/brand/generation-drops.txt). On Windows, run `powershell -File tool/export-app-icons.ps1` to export Android, iOS, and Windows launcher icons from the source.

### Adding a scale adapter

1. Implement `CoffeeScale` to handle discovery, connection, packets, commands, and cleanup for the model.
2. Expose `ScaleDevice` and `ScaleReading` from the adapter. Keep BLE library types and model-specific frames within the adapter. Normalize weight to g and flow to g/s. Set `flow: null` if the scale does not report flow, so the app can calculate it from weight changes.
3. Set `measurementsReady` after connecting and preparing the unit, then update `lastReading` with each fresh reading. A brew requires a recent valid reading.
4. Define capacity and support for tare, flow, and battery in `ScaleInfo`. Register the adapter factory in `ScaleRegistry`. Leave permission requests and device connections out of the constructor.

Scale selection, brewing, and recipes use the common interface. The selected model's capacity determines the maximum water target. The test adapter lives in `test/support/` and is excluded from the app's model list.

## Verification status

- `flutter analyze` reported no issues. The test suite covers protocol decoding, calculations, curves, storage, mobile UI, permissions and scan cancellation, weighing and tare, lifting and swirling, zero readings and overloads, response timing, stopped flow, and excluded segments.
- A Windows release build succeeded with the native BLE plugin DLL. A separate Windows BLE diagnostic confirmed pairing with a TES017, unit-setting responses, and weight notifications. Scale discovery was also confirmed in the app.
- Physical-device connection was confirmed on a Samsung Galaxy S23. Full brew testing on real hardware and iOS build and device verification remain pending.
- Mobile layouts were checked at 320 and 390 px for live and target weight, progress, timer, graph, and settings. Widget tests cover the fixed header, progress above the target, hiding demo controls on Android, bottom navigation, and spacing between the keyboard and ratio controls.

The app bundles Regular, Medium, SemiBold, and Bold from [Pretendard v1.3.9](https://github.com/orioncactus/pretendard/releases/tag/v1.3.9). The [font license](assets/fonts/OFL.txt) is included in the app.
