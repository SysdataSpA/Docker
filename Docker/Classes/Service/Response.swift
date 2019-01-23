//
//  Response.swift
//  Docker
//
//  Created by Francesco Ceravolo on 27/12/2018.
//

import Foundation

/*
 /////////////////// RESPONSE PROTOCOL ///////////////////
 */
public protocol Responsable: CustomStringConvertible {
    associatedtype Val
    associatedtype ErrVal
    
    var request: Request { get }
    var response: HTTPURLResponse? { get }
    var httpStatusCode: Int { get }
    var data: Data { get }
    var result: ResponseResult<Val, ErrVal?, DockerError>? { get set }
    
    var shortDescription: String { get }
    
    init(statusCode: Int, data: Data, request: Request)
    init(statusCode: Int, data: Data, request: Request, response: HTTPURLResponse?)
    
    func decode()
    func decodeError(with error: DockerError)
}

/*
 /////////////////// RESPONSE CLASS ///////////////////
 */

public enum ResponseResult<Val, ErrVal, E: Error> {
    case success(Val)
    case failure(ErrVal, E)
}

open class Response<Val, ErrVal>: Responsable {
    
    public var request: Request
    public var response: HTTPURLResponse?
    public var httpStatusCode: Int
    public var data: Data
    
    public var result: ResponseResult<Val, ErrVal?, DockerError>?
    
    public required convenience init(statusCode: Int, data: Data, request: Request) {
        self.init(statusCode: statusCode, data: data, request: request, response: nil)
    }
    
    public required init(statusCode: Int, data: Data, request: Request, response: HTTPURLResponse? = nil) {
        self.httpStatusCode = statusCode
        self.data = data
        self.request = request
        self.response = response
    }
    
    open func decode() {}
    open func decodeError(with error: DockerError) {}
}

//MARK: CustomStringConvertible
extension Response {
    public var description: String {
        var received = response != nil || request.sentInDemoMode
        var d = ""
        if received {
            d.append("RESPONSE RECEIVED - URL= \(request.urlStringDescription)")
            if let resp = response{
                d.append("\nSTATUS CODE: \(resp.statusCode)\nHEADERS: \(resp.allHeaderFields as? [String:String])")
            }
            if !data.isEmpty, let body = String(data: data, encoding: .utf8) {
                d.append("\nBODY=\n\(body)")
            }
        } else {
            var urlString: String = ""
            d.append("RESPONSE NOT RECEIVED - URL= \(request.urlStringDescription)")
        }
        return d
    }
    
    public var shortDescription: String {
        if let resp = response, let url = resp.url?.absoluteString  {
            return "RESPONSE RECEIVED - URL= \(url) STATUS CODE:\(resp.statusCode)"
        }
        return "RESPONSE NOT RECEIVED - URL= \(request.urlStringDescription)"
    }
}

open class ResponseJSON<Val: Decodable, ErrVal: Decodable>: Response<Val, ErrVal> {
    
    open var jsonDecoder: JSONDecoder {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = JSONDecoder.DateDecodingStrategy.secondsSince1970
        decoder.dataDecodingStrategy = JSONDecoder.DataDecodingStrategy.base64
        return decoder
    }
    
    override open func decode() {
        do {
            let value = try decodeJSON(with: Val.self)
            result = .success(value)
        } catch let error {
            result = .failure(nil, .decoding(error))
        }
    }
    
    // MARK: JSON Decode
    open func decodeJSON<T:Decodable>(with type: T.Type) throws -> T {
        return try jsonDecoder.decode(type, from: data)
    }
    
    override open func decodeError(with error: DockerError) {
        
        switch error {
        case .underlying(_, _, _):
            do {
                let value = try decodeJSON(with: ErrVal.self)
                result = .failure(value, error)
                
            } catch let error {
                result = .failure(nil, .decoding(error))
            }
            
            break
        default:
            result = .failure(nil, error)
            break
        }
    }
}

//MARK: Download response
open class DownloadResponse: Response<Any, Any> {
    
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
            result = .failure(nil, .decoding(err))
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
            result = .failure(nil, .decoding(err))
        }
    }
}
