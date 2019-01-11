//
//  Request.swift
//  Pods
//
//  Created by Francesco Ceravolo on 27/12/2018.
//

import Foundation
import Alamofire

public protocol RequestProtocol {
    var headers: [String:String] { get set }
    var urlParameterEncoding: URLEncoding { get set }
    var method: HTTPMethod { get set }
    var service: Service { get set }
    var type: RequestType { get set }
    var multipartBodyParts: [MultipartBodyPart]? { get set }
    var urlRequest: URLRequest? { get }
    var useDifferentResponseForErrors: Bool { get set }
    var httpErrorStatusCodeRange: ClosedRange<Int> { get set }
    
    func encode(request: inout URLRequest) throws
    
    // Demo Mode Variables
    var useDemoMode: Bool { get set }
    var demoSuccessFileName: String? { get set }
    var demoFailureFileName: String? { get set }
    var demoFilesBundle: Bundle { get set }
    var demoWaitingTimeRange: ClosedRange<TimeInterval> { get set }
    var demoSuccessStatusCode: Int { get set }
    var demoFailureStatusCode: Int { get set }
    var demoFailureChance: Double { get set }
    
    func urlParameters() throws -> [String:Any]?
    func bodyParameters() throws -> Encodable?
    func pathParameters() throws -> [String:Any]?
    
    func suspend()
    func resume()
    func cancel()
}

open class Request: NSObject, RequestProtocol {
    open var service: Service
    open var multipartBodyParts: [MultipartBodyPart]?
    open var method: HTTPMethod
    open var headers: [String: String] = [:]
    open var urlParameterEncoding: URLEncoding
    open var type: RequestType
    internal var internalRequest: Alamofire.Request?
    open var urlRequest: URLRequest? {
        return internalRequest?.request
    }
    
    open var useDifferentResponseForErrors: Bool
    open var httpErrorStatusCodeRange: ClosedRange<Int>
    
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
        self.useDifferentResponseForErrors = false
        self.httpErrorStatusCodeRange = 400...499
        
        // Demo mode
        self.useDemoMode = false
        self.demoFilesBundle = Bundle.main
        self.demoWaitingTimeRange = 0.0...0.0
        self.demoSuccessStatusCode = 200
        self.demoFailureStatusCode = 400
        self.demoFailureChance = 0.0
        
        super.init()
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
        allHeaders.merge(headers, uniquingKeysWith: { (_, last) -> String in last})
        request.allHTTPHeaderFields = allHeaders
        
        // body encoding
        try encode(request: &request)
        
        // url encoding
        if let urlParameters = try self.urlParameters() {
            request = try request.encoded(parameters: urlParameters, parameterEncoding: urlParameterEncoding)
        }
        
        return request
    }
    
    open func encode(request: inout URLRequest) throws {
        if let body = try self.bodyParameters() {
            if let data = body as? Data {
                request.httpBody = data
            } else {
                throw DockerError.encoding(EncodingError.invalidValue(body, EncodingError.Context(codingPath: [], debugDescription: "")))
            }
        }
    }
    
    internal func buildURL() throws -> URL {
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

open class RequestJSON: Request {
    
    public override init() {
        super.init()
        headers["Accept"] = "application/json"
    }
    
    open var jsonEncoder: JSONEncoder {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = JSONEncoder.DateEncodingStrategy.secondsSince1970
        encoder.dataEncodingStrategy = JSONEncoder.DataEncodingStrategy.base64
        return encoder
    }
    
    override open func encode(request: inout URLRequest) throws {
        if let body = try self.bodyParameters() {
            request = try request.encoded(encodable: body, encoder: jsonEncoder)
        }
    }
}

open class RequestPList: Request {
    
    open var pListEncoder: PropertyListEncoder {
        let encoder = PropertyListEncoder()
        return encoder
    }
    
    override open func encode(request: inout URLRequest) throws {
        if let body = try self.bodyParameters() {
            request = try request.encoded(encodable: body, encoder: pListEncoder)
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
//MARK: Alamofire forwarding
extension Request {
    public func suspend() {
        internalRequest?.suspend()
    }
    
    public func resume() {
        internalRequest?.resume()
    }
    
    public func cancel() {
        internalRequest?.cancel()
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
