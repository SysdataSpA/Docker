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
    case uploadMultipart()
    
    /// A "multipart/form-data" upload task  combined with url parameters.
    case uploadMultipartWithParameters(urlParameters: [String: Any])
    
    /// A file download task to a destination.
    case download(DownloadFileDestination)
    
    /// A file download task to a destination with extra parameters using the given encoding.
    case downloadWithParameters(parameters: [String: Any], destination: DownloadRequest.DownloadFileDestination)
}

public protocol ServiceProtocol {
    var sessionManager: SessionManager { get }
    var path: String { get }
    var baseUrl: String { get }
}

open class Service: ServiceProtocol {
    open var path: String
    open var baseUrl: String
    open var sessionManager: SessionManager {
        return SessionManager.default
    }
    
    public required init() {
        self.path = ""
        self.baseUrl = ""
    }
}

public protocol RequestProtocol {
    var headers: [String:String]? { get set }
    var parameterEncoding: ParameterEncoding { get set }
    var method: HTTPMethod { get set }
    var service: Service { get set }
    var type: RequestType { get set }
    var multipartBodyParts: [MultipartBodyPart]? { get set }
    
    // Demo Mode Variables
    var useDemoMode: Bool { get set }
    var demoSuccessFileName: String? { get set }
    var demoFailureFileName: String? { get set }
    var demoFilesBundle: Bundle { get set }
    var demoWaitingTimeRange: ClosedRange<TimeInterval> { get set }
    var demoSuccessStatusCode: Int { get set }
    var demoFailureStatusCode: Int { get set }
    var demoFailureChance: Double { get set }
    
    func responseClass() -> Response.Type
    func parameters() throws -> [String:Any]?
    func pathParameters() throws -> [String:Any]?
}

open class Request: NSObject, RequestProtocol {
    open var service: Service
    open var multipartBodyParts: [MultipartBodyPart]?
    open var method: HTTPMethod
    open var headers: [String : String]?
    open var parameterEncoding: ParameterEncoding
    open var type: RequestType
    
    //Demo mode
    open var useDemoMode: Bool
    open var demoSuccessFileName: String?
    open var demoFailureFileName: String?
    open var demoFilesBundle: Bundle
    open var demoWaitingTimeRange: ClosedRange<TimeInterval>
    open var demoSuccessStatusCode: Int
    open var demoFailureStatusCode: Int
    open var demoFailureChance: Double
    internal var sentInDemoMode: Bool = false
    
    public override init(){
        self.service = Service()
        self.method = .get
        self.type = .simple
        
        switch self.method {
        case .get,
             .delete,
             .head:
            self.parameterEncoding = URLEncoding.default
        default:
            self.parameterEncoding = JSONEncoding(options: .prettyPrinted)
        }
        
        // Demo mode
        self.useDemoMode = false
        self.demoFilesBundle = Bundle.main
        self.demoWaitingTimeRange = 0.0...0.0
        self.demoSuccessStatusCode = 200
        self.demoFailureStatusCode = 400
        self.demoFailureChance = 0.0
    }
    
    open func responseClass() -> Response.Type {
        return Response.self
    }
    
    open func parameters() throws -> [String : Any]? {
        return nil
    }
    
    open func pathParameters() throws -> [String : Any]? {
        return nil
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
        case let .uploadMultipartWithParameters(urlParameters):
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
        let params = try self.pathParameters()
        // search for "/:" to find the start of a path parameter
        while let paramRange = findNextPathParamPlaceholderRange(in: composedUrl) {
            let paramName = composedUrl.substring(with: composedUrl.index(after: paramRange.lowerBound)..<paramRange.upperBound)
            let param = try findPathParam(with: paramName, in: params)
            composedUrl.replaceSubrange(paramRange, with: param)
        }
        guard let url = URL(string: composedUrl)
            else { throw DockerError.invalidURL(self.service) }
        return url
    }
    
    private func findNextPathParamPlaceholderRange(in string: String) -> Range<String.Index>? {
        if let startRange = string.range(of: "/:") {
            let semicolonIndex = string.index(after:startRange.lowerBound)
            let searchRange: Range<String.Index> = semicolonIndex..<string.endIndex
            if let endRange = string.range(of: "/", options: String.CompareOptions.caseInsensitive, range: searchRange, locale: nil) {
                return semicolonIndex..<endRange.lowerBound
            } else {
                return semicolonIndex..<string.endIndex
            }
        }
        return nil
    }

    private func findPathParam(with name:String, in parameters: [String:Any]?) throws -> String {
        guard let parameters = parameters else {
            throw DockerError.pathParameterNotFound(self, name)
        }
        if let param = parameters[name] {
            return "\(param)"
        } else {
            throw DockerError.pathParameterNotFound(self, name)
        }
    }
}
//MARK: CustomStringConvertible
extension Request {
    open override var description: String {
        var body: String? = nil
        if let httpBody = try? self.asUrlRequest().httpBody {
            if let httpBody = httpBody {
                body = String(data: httpBody, encoding: .utf8)
            }
        }
        var string = "REQUEST URL: \(self.service.baseUrl)\(self.service.path)\nMETHOD:\(self.method.rawValue)\nHEADERS:\(self.headers ?? [:]))"
        if let params = try? self.parameters() {
            if let params = params {
                string.append("\nPARAMETERS:\(params)")
            }
        }
        if let body = body {
            string.append("\nBODY:\n\(body)")
        }
        return string
    }
}

open class Response: CustomStringConvertible {
    public var request: Request
    public var response: HTTPURLResponse?
    public var httpStatusCode: Int
    public var data: Data
    public var value: Any?
    public var error: Error?
    
    public required init(statusCode: Int, data: Data, request: Request, response: HTTPURLResponse? = nil) {
        self.httpStatusCode = statusCode
        self.data = data
        self.request = request
        self.response = response
    }
    
    open func decode() { value = data }
    
    public var description: String {
        var received = false
        var d = ""
        if let value = value, let response = response {
            received = true
        } else if request.sentInDemoMode {
            received = true
        }
        
        if received {
            if let url = try? request.buildURL() {
                d.append("RESPONSE RECEIVED - URL= \(url)")
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
    
    // MARK: JSON Decode
    open func decodeJSON<T:Decodable>(with type: T.Type) {
        do {
            value = try JSONDecoder().decode(type, from: data)
        } catch let err {
            self.error = err
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
                value = UIImage(data: data)
            } else {
                SDLogModuleWarning("localURL not defined", module: DockerServiceLogModuleName)
            }
        } catch let err  {
            self.error = err
            SDLogModuleError(err.localizedDescription, module: DockerServiceLogModuleName)
        }
    }
    
    open func decodeString() {
        do {
            if let localURL = localURL {
                value = try String(contentsOf: localURL, encoding: .utf8)
            } else {
                SDLogModuleWarning("localURL not defined", module: DockerServiceLogModuleName)
            }
        } catch let err  {
            self.error = err
            SDLogModuleError(err.localizedDescription, module: DockerServiceLogModuleName)
        }
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
