#include "ble_pairing.h"
#include <flutter/standard_method_codec.h>
#include <winrt/Windows.Devices.Bluetooth.h>
#include <winrt/Windows.Devices.Enumeration.h>
#include <winrt/Windows.Foundation.h>
#include <algorithm>
#include <string>

namespace {
winrt::fire_and_forget PairDevice(
    uint64_t address,
    std::unique_ptr<flutter::MethodResult<flutter::EncodableValue>> result) {
  using namespace winrt::Windows::Devices::Bluetooth;
  using namespace winrt::Windows::Devices::Enumeration;
  const winrt::apartment_context origin;
  std::string failure;
  try {
    auto device = co_await BluetoothLEDevice::FromBluetoothAddressAsync(address);
    if (!device) {
      failure = "저울을 찾지 못했습니다. 페어링 대기 상태에서 다시 연결해 주세요.";
    } else {
      auto pairing = device.DeviceInformation().Pairing();
      if (!pairing.IsPaired()) {
        auto custom = pairing.Custom();
        // DOT uses Just Works. Other pairing kinds are never auto-confirmed.
        auto token = custom.PairingRequested(winrt::auto_revoke,
            [](auto const&, DevicePairingRequestedEventArgs const& args) {
              if (args.PairingKind() == DevicePairingKinds::ConfirmOnly) args.Accept();
            });
        auto outcome = co_await custom.PairAsync(DevicePairingKinds::ConfirmOnly);
        if (outcome.Status() != DevicePairingResultStatus::Paired &&
            outcome.Status() != DevicePairingResultStatus::AlreadyPaired) {
          failure = "Windows 페어링 실패 (" +
              std::to_string(static_cast<int>(outcome.Status())) +
              "). 도트를 빠른 흰색 점멸 상태로 전환해 주세요.";
        }
      }
      device.Close();
    }
  } catch (winrt::hresult_error const& e) {
    failure = winrt::to_string(e.message());
  } catch (std::exception const& e) {
    failure = e.what();
  }
  co_await origin;
  if (failure.empty()) result->Success();
  else result->Error("pairing_failed", failure);
}
}  // namespace

std::unique_ptr<flutter::MethodChannel<flutter::EncodableValue>>
CreateBlePairingChannel(flutter::BinaryMessenger* messenger) {
  auto channel = std::make_unique<flutter::MethodChannel<flutter::EncodableValue>>(
      messenger, "dot_pour/ble_platform", &flutter::StandardMethodCodec::GetInstance());
  channel->SetMethodCallHandler([](const auto& call, auto result) {
    if (call.method_name() != "pair") {
      result->NotImplemented();
      return;
    }
    auto id = call.arguments() ? std::get_if<std::string>(call.arguments()) : nullptr;
    // bluetooth_low_energy represents a Windows MAC as a zero-padded UUID.
    if (!id || id->size() != 36 || id->substr(0, 24) != "00000000-0000-0000-0000-") {
      result->Error("invalid_device", "Invalid Windows peripheral identifier");
      return;
    }
    try {
      size_t parsed = 0;
      auto address = std::stoull(id->substr(24), &parsed, 16);
      if (parsed != 12) throw std::invalid_argument("Invalid address");
      PairDevice(address, std::move(result));
    } catch (std::exception const& e) {
      result->Error("invalid_device", e.what());
    }
  });
  return channel;
}
