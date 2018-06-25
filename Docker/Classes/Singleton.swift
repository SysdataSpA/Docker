//
//  Singleton.swift
//  Docker
//
//  Created by Paolo Ardia on 25/06/18.
//

import Foundation

public protocol Initializable {
    init()
}

public protocol Singleton:Initializable {
    static var _shared: Singleton? { get set }
    static func shared() -> Self
}

extension Singleton {
    public static func shared() -> Self {
        if _shared == nil {
            _shared = Self.init()
        }
        return _shared as! Self
    }
}
