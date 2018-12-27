//
//  Response.swift
//  Docker
//
//  Created by Francesco Ceravolo on 27/12/2018.
//

import Foundation

open class Response: CustomStringConvertible {
    public var request: Request
    public var response: HTTPURLResponse?
    public var httpStatusCode: Int
    public var data: Data
    public var value: Any?
    public var errorValue: Any?
    public var error: Error?
    open var dateDecodingStrategy : JSONDecoder.DateDecodingStrategy {
        return JSONDecoder.DateDecodingStrategy.secondsSince1970
    }
    open var dataDecodingStrategy : JSONDecoder.DataDecodingStrategy {
        return JSONDecoder.DataDecodingStrategy.base64
    }
    
    public required init(statusCode: Int, data: Data, request: Request, response: HTTPURLResponse? = nil) {
        self.httpStatusCode = statusCode
        self.data = data
        self.request = request
        self.response = response
    }
    
    open func decode() { value = data }
    
    open func decodeError() { errorValue = data }
    
    public var description: String {
        var received = false
        var d = ""
        if let response = response {
            received = true
        } else if request.sentInDemoMode {
            received = true
        }
        
        if received {
            if let url = try? request.buildURL() {
                d.append("RESPONSE RECEIVED - URL= \(url)")
                if let resp = response{
                    d.append("\nSTATUS CODE: \(resp.statusCode)\nHEADERS: \(resp.allHeaderFields as? [String:String])")
                }
                if data.count > 0 {
                    if let body = String(data: data, encoding: .utf8) {
                        d.append("\nBODY=\n\(body)")
                    }
                }
            }
        } else {
            d.append("RESPONSE NOT RECEIVED - URL= \(try? request.buildURL().absoluteString)")
        }
        return d
    }
    
    public var shortDescription: String {
        if let resp = response, let url = resp.url?.absoluteString  {
            return "RESPONSE RECEIVED - URL= \(url) STATUS CODE:\(resp.statusCode)"
        }
        return "RESPONSE NOT RECEIVED - URL= \(try? request.buildURL().absoluteString)"
    }
    
    // MARK: JSON Decode
    open func decodeJSON<T:Decodable>(with type: T.Type) -> Any? {
        do {
            let decoder = JSONDecoder()
            decoder.dateDecodingStrategy = self.dateDecodingStrategy
            decoder.dataDecodingStrategy = self.dataDecodingStrategy
            return try decoder.decode(type, from: data)
        } catch let err {
            self.error = err
        }
        return nil
    }
}

//MARK: Download response
open class DownloadResponse: Response {
    public var localURL: URL?
    
    open func decodeImage() {
        do {
            if let localURL = localURL {
                let data = try Data(contentsOf: localURL)
                value = UIImage(data: data)
            } else {
                SDLogModuleWarning("🌍⚠️ localURL not defined", module: DockerServiceLogModuleName)
            }
        } catch let err  {
            self.error = err
            SDLogModuleError("🌍‼️ " + err.localizedDescription, module: DockerServiceLogModuleName)
        }
    }
    
    open func decodeString() {
        do {
            if let localURL = localURL {
                value = try String(contentsOf: localURL, encoding: .utf8)
            } else {
                SDLogModuleWarning("🌍⚠️ localURL not defined", module: DockerServiceLogModuleName)
            }
        } catch let err  {
            self.error = err
            SDLogModuleError("🌍‼️ " + err.localizedDescription, module: DockerServiceLogModuleName)
        }
    }
}
