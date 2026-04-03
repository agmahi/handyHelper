import Combine
/*
 * Copyright (c) Meta Platforms, Inc. and affiliates.
 * All rights reserved.
 *
 * This source code is licensed under the license found in the
 * LICENSE file in the root directory of this source tree.
 */

//
// MainAppView.swift
//
// Central navigation hub that displays different views based on DAT SDK registration and device states.
// When unregistered, shows the registration flow. When registered, shows the device selection screen
// for choosing which Meta wearable device to stream from.
//

import MWDATCore
import SwiftUI

struct MainAppView: View {
  let wearables: WearablesInterface
  @ObservedObject private var viewModel: WearablesViewModel
  @StateObject private var cardMaxViewModel: CardMaxViewModel

  init(wearables: WearablesInterface, viewModel: WearablesViewModel) {
    self.wearables = wearables
    self.viewModel = viewModel
    self._cardMaxViewModel = StateObject(wrappedValue: CardMaxViewModel(wearables: wearables))
  }

  var body: some View {
    NavigationStack {
      if viewModel.registrationState == .registered {
        CardMaxView(viewModel: cardMaxViewModel, wearablesVM: viewModel)
      } else {
        HomeScreenView(viewModel: viewModel)
      }
    }
  }
}
