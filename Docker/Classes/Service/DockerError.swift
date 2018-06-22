//
//  DockerError.swift
//  Docker
//
//  Created by Paolo Ardia on 21/06/18.
//

import Foundation

public enum DockerError: Error {
    
    /// Indicates an invalid URL
    case invalidURL(Service)
    
    /// Indicates that Encodable couldn't be encoded into Data
    case encoding(Swift.Error)
    
    /// Indicates that a `Request` failed to encode the parameters for the `URLRequest`.
    case parameterEncoding(Swift.Error)
    
    /// Indicates a response failed due to an underlying `Error`.
    case underlying(Swift.Error, HTTPURLResponse?)
}

public extension DockerError {
    var service: Service? {
        switch self {
        case .invalidURL(let service): return service
        case .encoding: return nil
        case .parameterEncoding: return nil
        case .underlying: return nil
        }
    }
}

extension DockerError: LocalizedError {
    public var errorDescription: String? {
        switch self {
        case .invalidURL: return "The URL of the service is invalid.\n\tBase URL: \(self.service?.baseUrl ?? "unknown")\n\tPath: \(self.service?.path ?? "unknown")"
        case .encoding: return "Failed to encode Encodable object into data."
        case .parameterEncoding(let error): return "Failed to encode parameters for URLRequest. \(error.localizedDescription)"
        case .underlying(let error, _): return error.localizedDescription
        }
    }
}
