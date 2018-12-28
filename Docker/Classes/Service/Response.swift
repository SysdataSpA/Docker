//
//  Response.swift
//  Docker
//
//  Created by Francesco Ceravolo on 27/12/2018.
//

import Foundation

public enum ResponseResult<Val, ErrVal, E: Error> {
    case success(Val)
    case failure(ErrVal?, E)
}

open class Response: CustomStringConvertible {
    public var request: Request
    public var response: HTTPURLResponse?
    public var httpStatusCode: Int
    public var data: Data
    public var result: ResponseResult<Any, Any, DockerError>?
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
    
    open func decode() { result = .success(data) }
    
    open func decodeError(with error: DockerError?) { result = .failure(data, error ?? .generic(nil)) }
}

//MARK: CustomStringConvertible
extension Response {
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
}

open class ResponseJSON<Val: Decodable>: Response {
    
    override open func decode() {
        do {
            let value = try decodeJSON(with: Val.self)
            result = .success(value)
            
        } catch let error {
            result = .failure(nil, .encoding(error))
        }
    }
    
    // MARK: JSON Decode
    open func decodeJSON<T:Decodable>(with type: T.Type) throws -> T {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = self.dateDecodingStrategy
        decoder.dataDecodingStrategy = self.dataDecodingStrategy
        return try decoder.decode(type, from: data)
    }
}

open class ResponseJSONFull<Val: Decodable, ErrVal: Decodable>: ResponseJSON<Val> {
    
    override open func decodeError(with error: DockerError?) {
        do {
            let value = try decodeJSON(with: ErrVal.self)
            result = .failure(value, error ?? .generic(nil))
            
        } catch let error {
            result = .failure(nil, .encoding(error))
        }
    }
}


//MARK: Download response
open class DownloadResponse: Response {
    public var localURL: URL?
    
    open func decodeImage() {
        do {
            if let localURL = localURL {
                let data = try Data(contentsOf: localURL)
                let value = UIImage(data: data)
                result = .success(value)
            } else {
                SDLogModuleWarning("🌍⚠️ localURL not defined", module: DockerServiceLogModuleName)
            }
        } catch let err  {
            SDLogModuleError("🌍‼️ " + err.localizedDescription, module: DockerServiceLogModuleName)
            result = .failure(nil, .encoding(err))
        }
    }
    
    open func decodeString() {
        do {
            if let localURL = localURL {
                let value = try String(contentsOf: localURL, encoding: .utf8)
                result = .success(value)
            } else {
                SDLogModuleWarning("🌍⚠️ localURL not defined", module: DockerServiceLogModuleName)
            }
        } catch let err  {
            SDLogModuleError("🌍‼️ " + err.localizedDescription, module: DockerServiceLogModuleName)
            result = .failure(nil, .encoding(err))
        }
    }
}
