#ifndef RUNNER_BLE_PAIRING_H_
#define RUNNER_BLE_PAIRING_H_
#include <flutter/binary_messenger.h>
#include <flutter/encodable_value.h>
#include <flutter/method_channel.h>
#include <memory>

std::unique_ptr<flutter::MethodChannel<flutter::EncodableValue>>
CreateBlePairingChannel(flutter::BinaryMessenger* messenger);
#endif
