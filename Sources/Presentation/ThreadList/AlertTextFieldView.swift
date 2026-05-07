//
// Copyright (c) 2021-2026. NICE Ltd. All rights reserved.
//
// Licensed under the NICE License;
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
//    https://github.com/nice-devone/nice-cxone-mobile-ui-ios/blob/main/LICENSE
//
// TO THE EXTENT PERMITTED BY APPLICABLE LAW, THE CXONE MOBILE SDK IS PROVIDED ON
// AN "AS IS" BASIS. NICE HEREBY DISCLAIMS ALL WARRANTIES AND CONDITIONS, EXPRESS
// OR IMPLIED, INCLUDING (WITHOUT LIMITATION) WARRANTIES OF MERCHANTABILITY,
// FITNESS FOR A PARTICULAR PURPOSE, NON-INFRINGEMENT, AND TITLE.
//

import SwiftUI

struct AlertTextFieldView: View {

    // MARK: - Properties

    @EnvironmentObject private var localization: ChatLocalization

    @State private var text = ""

    @Binding var isPresented: Bool

    let initialText: String

    let onConfirm: (String) -> Void

    // MARK: - Init

    init(isPresented: Binding<Bool>, initialText: String = "", onConfirm: @escaping (String) -> Void) {
        self._isPresented = isPresented
        self._text = State(initialValue: initialText)
        self.initialText = initialText
        self.onConfirm = onConfirm
    }

    // MARK: - Body

    @ViewBuilder
    var body: some View {
        TextField(localization.alertUpdateThreadNamePlaceholder, text: $text)

        Button(localization.commonConfirm) {
            onConfirm(text)
            text = ""
            isPresented = false
        }

        Button(localization.commonCancel, role: .cancel) {
            text = ""
            isPresented = false
        }
    }
}

// MARK: - Preview

@available(iOS 17.0, *)
#Preview("Alert Text Field") {
    @Previewable @State var text = ""
    @Previewable @State var isPresented = true
    
    let localization = ChatLocalization()
    
    VStack {
        Text(text)
        
        Button("Show") {
            isPresented = true
        }
    }
    .alert(localization.alertUpdateThreadNameTitle, isPresented: $isPresented) {
        AlertTextFieldView(isPresented: $isPresented) { newText in
            text = newText
        }
    }
    .environmentObject(localization)
}
