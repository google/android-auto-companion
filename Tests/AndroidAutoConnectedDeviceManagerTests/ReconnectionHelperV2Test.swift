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

/// Fake authenticator we can configure for testing the helper.
private struct CarAuthenticatorFake: CarAuthenticator {
  @MainActor static var hmacWillMatchForChallenge: Bool = true
  @MainActor static var match: CarAdvertisementMatch? = nil
  @MainActor static var nextRandomSalt: Data?

  init(carId: String) {}

  /// Generate a random salt with the specified number of bytes plus optional zero padding.
  ///
  /// - Parameter size: The size of the salt in bytes.
  /// - Returns: The generated salt.
  @MainActor static func randomSalt(size: Int) -> Data {
    return nextRandomSalt ?? CarAuthenticatorImpl.randomSalt(size: size)
  }

  @MainActor static func first(
    among cars: Set<Car>,
    matchingData advertisementData: Data
  ) -> CarAdvertisementMatch? {
    return match
  }

  @MainActor func isMatch(challenge: Data, hmac: Data) -> Bool {
    return Self.hmacWillMatchForChallenge
  }
}

/// Unit tests for AssociationMessageHelperV1.
class ReconnectionHelperV2Test: XCTestCase {
  private var messageStreamMock: MessageStream!
  private var peripheralMock: PeripheralMock!
  private var testCar: Car!

  // The helper under test.
  private var reconnectionHelper: ReconnectionHelperV2!

  override func setUp() async throws {
    try await super.setUp()

    await setUpOnMain()
  }

  @MainActor private func setUpOnMain() {
    peripheralMock = PeripheralMock(name: "Test")

    let readCharacteristic = CharacteristicMock(
      uuid: UUIDConfig.readCharacteristicUUID, value: nil)
    let writeCharacteristic = CharacteristicMock(
      uuid: UUIDConfig.writeCharacteristicUUID, value: nil)
    messageStreamMock = BLEMessageStreamPassthrough(
      peripheral: peripheralMock,
      readCharacteristic: readCharacteristic,
      writeCharacteristic: writeCharacteristic
    )

    testCar = Car(id: "test", name: "test")
    CarAuthenticatorFake.match = (car: testCar, hmac: Data("hmac".utf8))
    reconnectionHelper = ReconnectionHelperV2(
      peripheral: peripheralMock,
      advertisementData: Data("advertisement".utf8),
      cars: [],
      authenticatorType: CarAuthenticatorFake.self
    )
  }

  override func tearDown() {
    peripheralMock = nil
    messageStreamMock = nil
    reconnectionHelper = nil
    testCar = nil

    super.tearDown()
  }

  @MainActor func testDiscoveryUUID() {
    let helper = ReconnectionHelperV2(
      peripheral: peripheralMock,
      cars: [],
      authenticatorType: CarAuthenticatorFake.self
    )

    let config = UUIDConfig(plistLoader: PListLoaderFake())
    XCTAssertEqual(helper.discoveryUUID(from: config), config.reconnectionUUID(for: .v2))
  }

  @MainActor func testAdMatch_Instantiated() {
    let car = Car(id: "test", name: "test")
    CarAuthenticatorFake.match = (car: car, hmac: Data("hmac".utf8))

    let helper = ReconnectionHelperV2(
      peripheral: peripheralMock,
      advertisementData: Data("advertisement".utf8),
      cars: [],
      authenticatorType: CarAuthenticatorFake.self
    )

    XCTAssertNotNil(helper)
    XCTAssertNotNil(helper?.carId)
    XCTAssertEqual(helper?.carId, car.id)
  }

  @MainActor func testAdMismatch_NilInstance() {
    CarAuthenticatorFake.match = nil

    let helper = ReconnectionHelperV2(
      peripheral: peripheralMock,
      advertisementData: Data("advertisement".utf8),
      cars: [],
      authenticatorType: CarAuthenticatorFake.self
    )

    XCTAssertNil(helper)
    XCTAssertNil(helper?.carId)
  }

  @MainActor func test_prepareForHandshake_readyForHandshake() {
    let helper = ReconnectionHelperV2(
      peripheral: peripheralMock,
      cars: [],
      authenticatorType: CarAuthenticatorFake.self
    )

    var onReadyForHandshakeCalled = false
    helper.onReadyForHandshake = {
      onReadyForHandshakeCalled = true
    }

    XCTAssertFalse(helper.isReadyForHandshake)

    try? helper.prepareForHandshake(withAdvertisementData: Data("advertisement".utf8))

    XCTAssertNotNil(helper.carId)
    XCTAssertTrue(helper.isReadyForHandshake)
    XCTAssertTrue(onReadyForHandshakeCalled)
  }

  @MainActor func testStartHandshakeBeforeReady_ThrowsError() {
    // Create helper without advertisement.
    let helper = ReconnectionHelperV2(
      peripheral: peripheralMock,
      cars: [],
      authenticatorType: CarAuthenticatorFake.self
    )

    XCTAssertFalse(helper.isReadyForHandshake)
    XCTAssertThrowsError(
      try helper.startHandshake(messageStream: messageStreamMock)
    )
  }

  @MainActor func testStartHandshake_SendsChallenge() throws {
    XCTAssertEqual(peripheralMock.writeValueCalledCount, 0)

    try reconnectionHelper.startHandshake(messageStream: messageStreamMock)

    XCTAssertEqual(peripheralMock.writeValueCalledCount, 1)
  }

  @MainActor func testHandleMessageAuthenticatesMessage_CompletesHandshake() throws {
    CarAuthenticatorFake.hmacWillMatchForChallenge = true

    try reconnectionHelper.startHandshake(messageStream: messageStreamMock)
    let completed = try reconnectionHelper.handleMessage(
      messageStream: messageStreamMock, message: Data("test".utf8))
    XCTAssertTrue(completed)
  }

  @MainActor func testHandleMessageBeforeReady_ThrowsError() {
    // Create helper without advertisement.
    let helper = ReconnectionHelperV2(
      peripheral: peripheralMock,
      cars: [],
      authenticatorType: CarAuthenticatorFake.self
    )

    XCTAssertFalse(helper.isReadyForHandshake)
    XCTAssertThrowsError(
      try helper.handleMessage(
        messageStream: messageStreamMock, message: Data("test".utf8))
    )
  }

  @MainActor func testHandleMessageWithoutCar_ThrowsError() throws {
    CarAuthenticatorFake.hmacWillMatchForChallenge = true

    try reconnectionHelper.startHandshake(messageStream: messageStreamMock)
    reconnectionHelper.car = nil
    XCTAssertThrowsError(
      try reconnectionHelper.handleMessage(
        messageStream: messageStreamMock, message: Data("test".utf8))
    )
  }

  @MainActor func testHandleMessageAuthenticationFails_Throws() throws {
    CarAuthenticatorFake.hmacWillMatchForChallenge = false

    try reconnectionHelper.startHandshake(messageStream: messageStreamMock)
    XCTAssertThrowsError(
      try reconnectionHelper.handleMessage(
        messageStream: messageStreamMock, message: Data("test".utf8))
    )
  }

  @MainActor func testDoesNotRequestSecuredChannelConfiguration_v2() throws {
    let connectionHandler = ConnectionHandleFake()
    let channel = SecuredCarChannelMock(id: "test", name: "test")

    var completionCalled = false
    var configurationSuccess = false

    try reconnectionHelper.onResolvedSecurityVersion(.v2)
    reconnectionHelper.configureSecureChannel(channel, using: connectionHandler) { success in
      completionCalled = true
      configurationSuccess = success
    }

    XCTAssertTrue(completionCalled)
    XCTAssertTrue(configurationSuccess)
    XCTAssertFalse(connectionHandler.requestConfigurationCalled)
  }

  @MainActor func testDoesNotRequestSecuredChannelConfiguration_v3() throws {
    let connectionHandler = ConnectionHandleFake()
    let channel = SecuredCarChannelMock(id: "test", name: "test")

    var completionCalled = false
    var configurationSuccess = false

    try reconnectionHelper.onResolvedSecurityVersion(.v3)
    reconnectionHelper.configureSecureChannel(channel, using: connectionHandler) { success in
      completionCalled = true
      configurationSuccess = success
    }

    XCTAssertTrue(completionCalled)
    XCTAssertTrue(configurationSuccess)
    XCTAssertFalse(connectionHandler.requestConfigurationCalled)
  }

  @MainActor func testRequestsSecuredChannelConfiguration_v4() throws {
    let connectionHandler = ConnectionHandleFake()
    let channel = SecuredCarChannelMock(id: "test", name: "test")

    var completionCalled = false
    var configurationSuccess = false

    try reconnectionHelper.onResolvedSecurityVersion(.v4)
    reconnectionHelper.configureSecureChannel(channel, using: connectionHandler) { success in
      completionCalled = true
      configurationSuccess = success
    }

    XCTAssertTrue(completionCalled)
    XCTAssertTrue(configurationSuccess)
    XCTAssertTrue(connectionHandler.requestConfigurationCalled)
  }
}
