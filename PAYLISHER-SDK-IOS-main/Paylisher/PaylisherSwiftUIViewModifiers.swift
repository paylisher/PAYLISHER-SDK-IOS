//
//  PaylisherSwiftUIViewModifiers.swift
//  Paylisher
//
//  Created by Manoel Aranda Neto on 05.09.24.
//

#if canImport(SwiftUI)
    import Foundation
    import SwiftUI

    struct PaylisherSwiftUIViewModifier: ViewModifier {
        let viewEventName: String

        let screenEvent: Bool

        let properties: [String: Any]?

        func body(content: Content) -> some View {
            content.onAppear {
                if screenEvent {
                    PaylisherSDK.shared.screen(viewEventName, properties: properties)
                } else {
                    PaylisherSDK.shared.capture(viewEventName, properties: properties)
                }
            }
        }
    }

    public extension View {
        func paylisherScreenView(_ screenName: String? = nil,
                               _ properties: [String: Any]? = nil) -> some View
        {
            let viewEventName = screenName ?? "\(type(of: self))"
            return modifier(PaylisherSwiftUIViewModifier(viewEventName: viewEventName,
                                                       screenEvent: true,
                                                       properties: properties))
        }

        func paylisherViewSeen(_ event: String,
                             _ properties: [String: Any]? = nil) -> some View
        {
            modifier(PaylisherSwiftUIViewModifier(viewEventName: event,
                                                screenEvent: false,
                                                properties: properties))
        }
    }

#endif
