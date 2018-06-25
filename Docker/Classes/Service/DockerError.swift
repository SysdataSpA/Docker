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
    
    /// Indicates that the demo file in case of succeess is nil
    case nilSuccessDemoFile(ServiceCall)
    
    /// Indicates that the demo file in case of failure is nil
    case nilFailureDemoFile(ServiceCall)
    
    /// Indicates that the demo file does not exist
    case demoFileNotFound(ServiceCall, String)
}

public extension DockerError {
    var service: Service? {
        switch self {
        case .invalidURL(let service): return service
        case .encoding: return nil
        case .parameterEncoding: return nil
        case .underlying: return nil
        case .nilSuccessDemoFile(let serviceCall): return serviceCall.service
        case .nilFailureDemoFile(let serviceCall): return serviceCall.service
        case .demoFileNotFound(let serviceCall, _): return serviceCall.service
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
        case .nilSuccessDemoFile: return "The success demo file is nil"
        case .nilFailureDemoFile: return "The failure demo file is nil"
        case .demoFileNotFound(_, let filename): return "The demo file \(filename) does not exist"
        }
    }
}
