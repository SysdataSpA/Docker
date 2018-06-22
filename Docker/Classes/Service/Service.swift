//
//  ServiceGeneric.swift
//  Pods-Docker
//
//  Created by Paolo Ardia on 14/06/18.
//

import UIKit
import Alamofire

/// Represents an HTTP task.
public enum RequestType {
    
    /// A request with no additional data.
    case simple
    
    /// A requests body set with data.
    case bodyData(Data)
    
    /// A request body set with `Encodable` type
    case jsonEncodableBody(Encodable, encoder: JSONEncoder?)
    
    /// A requests body set with encoded parameters.
    case parameters(parameters: [String: Any])
    
    /// A requests body set with data, combined with url parameters.
    case bodyDataAndParameters(bodyData: Data, urlParameters: [String: Any])
    
    /// A requests body set with encoded parameters combined with url parameters.
    case encodedBodyAndParameters(bodyParameters: [String: Any], urlParameters: [String: Any])
    
    /// A file upload task.
    case uploadFile(URL)
    
    /// A "multipart/form-data" upload task.
    case uploadMultipart([MultipartFormData])
    
    /// A "multipart/form-data" upload task  combined with url parameters.
    case uploadMultipartWithParameters([MultipartFormData], urlParameters: [String: Any])
    
    /// A file download task to a destination.
    case download(DownloadRequest.DownloadFileDestination)
    
    /// A file download task to a destination with extra parameters using the given encoding.
    case downloadWithParameters(parameters: [String: Any], destination: DownloadRequest.DownloadFileDestination)
}

public protocol Service {
    var sessionManager: SessionManager { get }
    var path: String { get }
    var baseUrl: String { get }
    func responseClass() -> Response.Type
}

extension Service {
    public var sessionManager: SessionManager {
        return SessionManager.default
    }
}

public protocol Request {
    func parameters() throws -> [String:Any]?
    var headers: [String:String]? { get }
    var parameterEncoding: ParameterEncoding { get }
    var method: HTTPMethod { get }
    var service: Service { get }
    var type: RequestType { get }  
    var description: String { get }
    var multipartBodyParts: [MultipartBodyPart]? { get set }
}

extension Request {
    public func parameters() throws -> [String : Any]? {
        return nil
    }
    
    public var method: HTTPMethod {
        return .get
    }
    
    public var headers: [String : String]? {
        return nil
    }
    
    public var parameterEncoding: ParameterEncoding {
            switch self.method {
            case .get,
                 .delete,
                 .head:
                return URLEncoding.default
            default:
                return JSONEncoding(options: .prettyPrinted)
        }
    }
    
    public var type: RequestType {
        return .simple
    }
    
    internal func asUrlRequest() throws -> URLRequest {
        let url = try buildURL()
        
        var request = URLRequest(url: url)
        request.httpMethod = method.rawValue
        var allHeaders: [String:String] = self.service.sessionManager.session.configuration.httpAdditionalHeaders as! [String:String]
        if let headers = headers {
            allHeaders.merge(headers, uniquingKeysWith: { (_, last) -> String in last})
        }
        request.allHTTPHeaderFields = allHeaders
        
        switch type {
        case .simple, .uploadFile, .uploadMultipart, .download:
            return request
        case .bodyData(let data):
            request.httpBody = data
        case let .jsonEncodableBody(encodable, encoder: encoder):
            if let encoder = encoder {
                request = try request.encoded(encodable: encodable, encoder: encoder)
            } else {
                request = try request.encoded(encodable: encodable)
            }
        case let .parameters(parameters):
            request = try request.encoded(parameters: parameters, parameterEncoding: self.parameterEncoding)
        case let .uploadMultipartWithParameters(_, urlParameters):
            request = try request.encoded(parameters: urlParameters, parameterEncoding: self.parameterEncoding)
        case let .downloadWithParameters(parameters, destination: _):
            request = try request.encoded(parameters: parameters, parameterEncoding: self.parameterEncoding)
        case let .bodyDataAndParameters(bodyData: bodyData, urlParameters: urlParameters):
            request.httpBody = bodyData
            if let encoding = self.parameterEncoding as? URLEncoding, encoding.destination == .httpBody {
                fatalError("With this type of request you cannot use httpBody destination for parameters, use .parameters type instead")
            }
            request = try request.encoded(parameters: urlParameters, parameterEncoding: self.parameterEncoding)
        case let .encodedBodyAndParameters(bodyParameters: bodyParameters, urlParameters: urlParameters):
            let bodyEncoding = URLEncoding.httpBody
            let bodyfulRequest = try request.encoded(parameters: bodyParameters, parameterEncoding: bodyEncoding)
            if let encoding = self.parameterEncoding as? URLEncoding, encoding.destination == .httpBody {
                fatalError("With this type of request you cannot use httpBody destination for parameters, use .parameters type instead")
            }
            request = try bodyfulRequest.encoded(parameters: urlParameters, parameterEncoding: self.parameterEncoding)
        }
        return request
    }
    
    fileprivate func buildURL() throws -> URL {
        var composedUrl = service.path.isEmpty ? service.baseUrl : service.baseUrl.appending(service.path)
        // TODO: sostituzione dei parametri nel path
        guard let url = URL(string: composedUrl)
            else { throw DockerError.invalidURL(self.service) }
        return url
    }
    
    public var description: String {
        return "REQUEST URL: \(self.service.baseUrl)\(self.service.path)\nMETHOD:\(self.method.rawValue)\nHEADERS:\(self.headers ?? [:])\nPARAMETERS:\(self.parameters)"
    }
}

open class Response {
    public var request: Request
    public var response: HTTPURLResponse?
    public var httpStatusCode: Int
    public var data: Data
    public var result: Result<Decodable>?
    public var value: Decodable? {
        return result?.value
    }
    
    public var error: Error?
    
    public required init(statusCode: Int, data: Data, request: Request, response: HTTPURLResponse? = nil) {
        self.httpStatusCode = statusCode
        self.data = data
        self.request = request
        self.response = response
    }
    
    open func decode() -> Decodable? {
        result = Result<Decodable>(value: { () -> Data in
            return data
        })
        return result?.value
    }
    
    public var description: String {
        var d = ""
        if let result = result, let response = response {
            d.append("RESPONSE RECEIVED - URL= \(response.url)\nBODY= \(response.debugDescription)")
        } else {
            
            d.append("RESPONSE NOT RECEIVED - URL= \(try? request.buildURL().absoluteString)")
        }
        return d
    }
}

public struct MultipartBodyPart {
    var data: Data
    var name: String
    var fileName: String?
    var mimeType: String?
    
    public init(with data:Data, name: String, fileName: String? = nil, mimeType: String? = nil) {
        self.data = data
        self.name = name
        self.fileName = fileName
        self.mimeType = mimeType
    }
}


