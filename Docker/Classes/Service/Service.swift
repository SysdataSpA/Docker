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
    
    /// A request to send or receive data
    case data
    
    /// A file upload task.
    case upload(RequestType.UploadType)
    
    /// A file download task to a destination.
    case download(DownloadFileDestination)
    
    public enum UploadType {
        /// A file upload task.
        case file(URL)
        
        /// A "multipart/form-data" upload task.
        case multipart
    }
}

public enum BodyEncoding {
    
    /// The body will not be encoded, used if the body is a Data
    case none
    
    /// The body will be encoded with the given JSONEncoder
    case json(JSONEncoder)
    
    /// The body will be encoded with the given PropertyListEncoder
    case propertyList(PropertyListEncoder)
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
    var urlParameterEncoding: URLEncoding { get set }
    var bodyEncoding: BodyEncoding { get set }
    var method: HTTPMethod { get set }
    var service: Service { get set }
    var type: RequestType { get set }
    var multipartBodyParts: [MultipartBodyPart]? { get set }
    var urlRequest: URLRequest? { get set }
    
    
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
    func urlParameters() throws -> [String:Any]?
    func bodyParameters() throws -> Encodable?
    func pathParameters() throws -> [String:Any]?
}

open class Request: NSObject, RequestProtocol {
    open var service: Service
    open var multipartBodyParts: [MultipartBodyPart]?
    open var method: HTTPMethod
    open var headers: [String: String]?
    open var urlParameterEncoding: URLEncoding
    open var bodyEncoding: BodyEncoding
    open var type: RequestType
    open var urlRequest: URLRequest?
    
    
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
        self.type = .data
        self.urlParameterEncoding = URLEncoding.queryString
        self.bodyEncoding = .json( JSONEncoder() )
        
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
    
    open func urlParameters() throws -> [String: Any]? {
        return nil
    }
    
    open func bodyParameters() throws -> Encodable? {
        return nil
    }
    
    open func pathParameters() throws -> [String: Any]? {
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
        
        // body encoding
        if let body = try self.bodyParameters() {
            switch bodyEncoding {
            case .none:
                if let data = body as? Data {
                    request.httpBody = data
                } else {
                    throw DockerError.encoding(EncodingError.invalidValue(body, EncodingError.Context(codingPath: [], debugDescription: "")))
                }
            case .json(let jsonEncoder):
                request = try request.encoded(encodable: body, encoder: jsonEncoder)
            case .propertyList(let pListEncoder):
                request = try request.encoded(encodable: body, encoder: pListEncoder)
            }
        }
        
        // url encoding
        if let urlParameters = try self.urlParameters() {
            request = try request.encoded(parameters: urlParameters, parameterEncoding: urlParameterEncoding)
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
        if let httpBody = try? self.urlRequest?.httpBody {
            if let httpBody = httpBody {
                body = String(data: httpBody, encoding: .utf8)
            }
        }
        var string = "REQUEST URL: \(self.service.baseUrl)\(self.service.path)\nMETHOD:\(self.method.rawValue)\nHEADERS:\(self.headers ?? [:]))"
        if let params = try? self.urlParameters() {
            if let params = params {
                string.append("\nPARAMETERS:\(params)")
            }
        }
        if let body = body {
            string.append("\nBODY:\n\(body)")
        }
        return string
    }
    
    open var shortDescription: String {
        var string = "REQUEST \(self.method.rawValue)"
        if let url = try? self.urlRequest?.url?.absoluteString ?? "" {
            string.append(" at \(url)")
        }
        else{
            string.append(" at \(self.service.path)")
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
    open func decodeJSON<T:Decodable>(with type: T.Type) {
        do {
            let decoder = JSONDecoder()
            decoder.dateDecodingStrategy = self.dateDecodingStrategy
            decoder.dataDecodingStrategy = self.dataDecodingStrategy
            value = try decoder.decode(type, from: data)
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
