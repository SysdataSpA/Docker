//
//  EncodableWrapper.swift
//  Docker
//
//  Created by Paolo Ardia on 21/06/18.
//

import Foundation

struct EncodableWrapper: Encodable {
    
    private let encodable: Encodable
    
    public init(_ encodable: Encodable) {
        self.encodable = encodable
    }
    
    func encode(to encoder: Encoder) throws {
        try encodable.encode(to: encoder)
    }
}
