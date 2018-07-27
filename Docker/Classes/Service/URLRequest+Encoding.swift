//
//  URLRequest+Encoding.swift
//  Docker
//
//  Created by Paolo Ardia on 21/06/18.
//

import Foundation

internal extension URLRequest {
    
    mutating func encoded(encodable: Encodable, encoder: PropertyListEncoder) throws -> URLRequest {
        do {
            let encodable = EncodableWrapper(encodable)
            httpBody = try encoder.encode(encodable)
            
            let contentTypeHeaderName = "Content-Type"
            if value(forHTTPHeaderField: contentTypeHeaderName) == nil {
                setValue("application/x-plist", forHTTPHeaderField: contentTypeHeaderName)
            }
            
            return self
        } catch {
            throw DockerError.encoding(error)
        }
    }
    
    mutating func encoded(encodable: Encodable, encoder: JSONEncoder) throws -> URLRequest {
        do {
            let encodable = EncodableWrapper(encodable)
            httpBody = try encoder.encode(encodable)
            
            let contentTypeHeaderName = "Content-Type"
            if value(forHTTPHeaderField: contentTypeHeaderName) == nil {
                setValue("application/json; charset=UTF-8", forHTTPHeaderField: contentTypeHeaderName)
            }
            
            return self
        } catch {
            throw DockerError.encoding(error)
        }
    }
    
    func encoded(parameters: [String: Any], parameterEncoding: ParameterEncoding) throws -> URLRequest {
        do {
            return try parameterEncoding.encode(self, with: parameters)
        } catch {
            throw DockerError.parameterEncoding(error)
        }
    }
}
