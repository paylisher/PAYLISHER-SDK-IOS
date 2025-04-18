//
//  PaylisherConsumerPayload.swift
//  Paylisher
//
//  Created by Manoel Aranda Neto on 13.10.23.
//

import Foundation

struct PaylisherConsumerPayload {
    let events: [PaylisherEvent]
    let completion: (Bool) -> Void
}
