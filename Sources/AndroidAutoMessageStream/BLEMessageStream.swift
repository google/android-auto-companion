// Copyright 2021 Google LLC
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
//      http://www.apache.org/licenses/LICENSE-2.0
//
// Unless required by applicable law or agreed to in writing, software
// distributed under the License is distributed on an "AS IS" BASIS,
// WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
// See the License for the specific language governing permissions and
// limitations under the License.

public import AndroidAutoConnectedDeviceTransport
public import AndroidAutoCoreBluetoothProtocols

/// Message stream which is specific for BLE transport.
@MainActor public protocol BLEMessageStream: MessageStream {
  /// The peripheral as a `BLEPeripheral`.
  var peripheral: any BLEPeripheral { get }
}

extension BLEMessageStream {
  public var peripheral: any TransportPeripheral {
    let blePeripheral: any BLEPeripheral = self.peripheral
    return blePeripheral as any TransportPeripheral
  }
}
