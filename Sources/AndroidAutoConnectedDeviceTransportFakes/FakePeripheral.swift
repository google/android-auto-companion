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

public import XCTest

@testable public import AndroidAutoConnectedDeviceTransport

/// Fake peripheral for testing generic transport.
public final class FakePeripheral: TransportPeripheral {
  public let id = UUID()
  public var displayName = "abc"
  public var isConnected = false
  public var state: State = .disconnected

  public init() {}
}

extension FakePeripheral {
  public enum State: TransportPeripheralState {
    case disconnected
    case connecting
    case connected
    case disconnecting
  }
}
