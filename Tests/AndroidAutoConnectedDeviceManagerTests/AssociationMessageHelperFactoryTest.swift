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

private import AndroidAutoConnectedDeviceManagerMocks
private import AndroidAutoCoreBluetoothProtocols
private import AndroidAutoCoreBluetoothProtocolsMocks
private import CoreBluetooth
internal import XCTest

@testable private import AndroidAutoConnectedDeviceManager
@testable private import AndroidAutoMessageStream

/// Unit tests for AssociationMessageHelperV1.
class AssociationMessageHelperFactoryTest: XCTestCase {
  private var associatorMock: Associator!
  private var messageStreamMock: MessageStream!

  /// The factory to test.
  private var helperFactory: AssociationMessageHelperFactoryImpl!

  override func setUp() async throws {
    try await super.setUp()

    await setUpOnMain()
  }

  override func tearDown() {
    messageStreamMock = nil
    associatorMock = nil
    helperFactory = nil

    super.tearDown()
  }

  @MainActor private func setUpOnMain() {
    associatorMock = AssociatorMock()

    let peripheralMock = PeripheralMock(name: "Test")
    let readCharacteristic = CharacteristicMock(
      uuid: UUIDConfig.readCharacteristicUUID, value: nil)
    let writeCharacteristic = CharacteristicMock(
      uuid: UUIDConfig.writeCharacteristicUUID, value: nil)
    messageStreamMock = BLEMessageStreamPassthrough(
      peripheral: peripheralMock,
      readCharacteristic: readCharacteristic,
      writeCharacteristic: writeCharacteristic
    )

    helperFactory = AssociationMessageHelperFactoryImpl()
  }

  @MainActor func testFactoryMakesHelperV1ForSecurityVersionV1() async {
    let helper = helperFactory.makeHelper(
      associator: associatorMock,
      securityVersion: .v1,
      messageStream: messageStreamMock
    )

    XCTAssertTrue(helper is AssociationMessageHelperV1)
  }

  @MainActor func testFactoryMakesHelperV1ForSecurityVersionV2() async {
    let helper = helperFactory.makeHelper(
      associator: associatorMock,
      securityVersion: .v2,
      messageStream: messageStreamMock
    )

    XCTAssertTrue(helper is AssociationMessageHelperV2)
  }
}
