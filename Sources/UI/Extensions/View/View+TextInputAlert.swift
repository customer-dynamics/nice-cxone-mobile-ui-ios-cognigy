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
import UIKit

// MARK: - TextInputAlertConfiguration

/// Bundles the text strings required by a `textInputAlert` presentation.
struct TextInputAlertConfiguration {

    // MARK: - Properties

    let title: String
    let placeholder: String
    let confirmTitle: String
    let cancelTitle: String
    let initialText: String

    // MARK: - Init

    init(title: String, placeholder: String, confirmTitle: String, cancelTitle: String, initialText: String = "") {
        self.title = title
        self.placeholder = placeholder
        self.confirmTitle = confirmTitle
        self.cancelTitle = cancelTitle
        self.initialText = initialText
    }
}

// MARK: - View extension

extension View {

    /// Presents a text-input alert using `UIAlertController`.
    ///
    /// Use this modifier instead of the native SwiftUI `.alert(_:isPresented:actions:)` with `TextField`
    /// on iOS 15. On iOS 15, SwiftUI's alert silently drops text fields because `UIAlertController`
    /// requires text fields to be added before `present(_:animated:completion:)` is called, but
    /// SwiftUI 15 adds them after. This modifier drives `UIAlertController` directly, bypassing that
    /// limitation.
    ///
    /// On iOS 16 and later, use `.alert(_:isPresented:actions:)` with `AlertTextFieldView` instead.
    ///
    /// - Parameters:
    ///   - configuration: The alert's title, placeholder, and button titles.
    ///   - isPresented: A binding that controls whether the alert is presented.
    ///   - onConfirm: A closure called with the entered text when the user taps the confirm button.
    ///
    /// - Returns: A view that presents a text-input alert when `isPresented` becomes `true`.
    @available(iOS, introduced: 15.0, obsoleted: 16.0, message: "Use .alert(_:isPresented:actions:) with AlertTextFieldView on iOS 16 and later.")
    func textInputAlert(
        _ configuration: TextInputAlertConfiguration,
        isPresented: Binding<Bool>,
        onConfirm: @escaping (String) -> Void
    ) -> some View {
        background(
            TextInputAlertPresenter(
                isPresented: isPresented,
                configuration: configuration,
                onConfirm: onConfirm
            )
        )
    }
}

// MARK: - UIViewControllerRepresentable

/// A hidden view controller that drives a `UIAlertController` text-input prompt.
///
/// Attaches an invisible `UIViewController` to the view hierarchy via `.background`,
/// which serves as the presenter for the `UIAlertController`. The `Coordinator` retains
/// a weak reference to the presented alert so it can be dismissed programmatically when
/// `isPresented` is set to `false` from outside the alert.
private struct TextInputAlertPresenter: UIViewControllerRepresentable {

    // MARK: - Properties

    @Binding var isPresented: Bool

    let configuration: TextInputAlertConfiguration
    let onConfirm: (String) -> Void

    // MARK: - Methods

    func makeCoordinator() -> Coordinator { Coordinator() }

    func makeUIViewController(context: Context) -> UIViewController { UIViewController() }

    static func dismantleUIViewController(_ uiViewController: UIViewController, coordinator: Coordinator) {
        coordinator.presentedAlert?.dismiss(animated: false)
        coordinator.presentedAlert = nil
    }

    func updateUIViewController(_ uiViewController: UIViewController, context: Context) {
        guard isPresented else {
            if let alert = context.coordinator.presentedAlert {
                LogManager.trace("TextInputAlert dismissing alert because isPresented became false.")
                
                alert.dismiss(animated: true)
                context.coordinator.presentedAlert = nil
            }

            return
        }
        guard context.coordinator.presentedAlert == nil else {
            LogManager.trace("TextInputAlert already presented, skipping duplicate presentation.")
            return
        }

        let alert = UIAlertController(title: configuration.title, message: nil, preferredStyle: .alert)

        alert.addTextField { textField in
            textField.placeholder = configuration.placeholder
            textField.text = configuration.initialText
        }

        alert.addAction(UIAlertAction(title: configuration.cancelTitle, style: .cancel) { _ in
            context.coordinator.presentedAlert = nil
            isPresented = false
        })

        alert.addAction(UIAlertAction(title: configuration.confirmTitle, style: .default) { [weak alert] _ in
            let text = alert?.textFields?.first?.text ?? ""
            context.coordinator.presentedAlert = nil
            onConfirm(text)
            isPresented = false
        })

        context.coordinator.presentedAlert = alert

        DispatchQueue.main.async {
            guard isPresented, context.coordinator.presentedAlert === alert else {
                LogManager.warning("TextInputAlert presentation skipped: isPresented changed or alert reference mismatch.")
                
                if context.coordinator.presentedAlert === alert {
                    context.coordinator.presentedAlert = nil
                }
                
                return
            }
            guard uiViewController.view.window != nil, uiViewController.presentedViewController == nil else {
                LogManager.warning("TextInputAlert presentation skipped: view controller not in window hierarchy or already presenting.")
                
                context.coordinator.presentedAlert = nil
                return
            }

            uiViewController.present(alert, animated: true)
        }
    }

    // MARK: - Coordinator

    /// Retains a weak reference to the active `UIAlertController` so it can be dismissed
    /// if `isPresented` is set to `false` externally before the user dismisses the alert.
    class Coordinator {

        // MARK: - Properties

        weak var presentedAlert: UIAlertController?
    }
}
