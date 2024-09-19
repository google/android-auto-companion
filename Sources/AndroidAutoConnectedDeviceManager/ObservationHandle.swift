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

/// A handle that uniquely identifies an observation subscription.
///
/// This handle can be used later on to cancel the observation.
@MainActor final public class ObservationHandle: Sendable {
  private let cancellation: @MainActor @Sendable () -> Void

  init(cancellation: @escaping @MainActor @Sendable () -> Void) {
    self.cancellation = cancellation
  }

  /// Cancel the observation associated with this token.
  public func cancel() {
    cancellation()
  }
}
