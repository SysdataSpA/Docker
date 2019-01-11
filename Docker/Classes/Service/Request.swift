//
//  Request.swift
//  Pods
//
//  Created by Francesco Ceravolo on 27/12/2018.
//

import Foundation
import Alamofire

open class Request: NSObject {
    
    public var service: Service = Service()
    
    public var method: HTTPMethod = .get
    public var type: RequestType = .data
    
    public var headers: [String: String] = [:]
    public var urlParameterEncoding: URLEncoding = URLEncoding.queryString
    
    // HTTP Request
    internal var internalRequest: Alamofire.Request?
    public var urlRequest: URLRequest? {
        return internalRequest?.request
    }
    
    public var multipartBodyParts: [MultipartBodyPart]?
    
    // Error & Status Codes
    public var useDifferentResponseForErrors: Bool = false
    public var httpErrorStatusCodeRange: ClosedRange<Int> = 400...499
    
    //Demo mode
    public var useDemoMode: Bool = false
    public var demoSuccessFileName: String?
    public var demoFailureFileName: String?
    public var demoFilesBundle: Bundle = Bundle.main
    public var demoWaitingTimeRange: ClosedRange<TimeInterval> = 0.0...0.0
    public var demoSuccessStatusCode: Int = 200
    public var demoFailureStatusCode: Int = 400
    public var demoFailureChance: Double = 0.0
    internal var sentInDemoMode: Bool = false
    
    // Parameters
    public var pathParameters: [String: Any] = [:]
    public var urlParameters: [String: Any] = [:]
    public var bodyParameters: Encodable?
    
    // Build Request
    internal func buildUrlRequest() throws -> URLRequest {
        let url = try buildURL()
        
        var request = URLRequest(url: url)
        request.httpMethod = method.rawValue
        var allHeaders: [String:String] = service.sessionManager.session.configuration.httpAdditionalHeaders as! [String:String]
        allHeaders.merge(headers, uniquingKeysWith: { (_, last) -> String in last})
        request.allHTTPHeaderFields = allHeaders
        
        // body encoding
        if let bodyParams = bodyParameters {
            try encodeBody(request: &request, parameters: bodyParams)
        }
        
        // url encoding
        request = try request.encoded(parameters: urlParameters, parameterEncoding: urlParameterEncoding)
        
        return request
    }
    
    open func encodeBody(request: inout URLRequest, parameters: Encodable) throws {
        if let data = parameters as? Data {
            request.httpBody = data
        } else {
            throw DockerError.encoding(EncodingError.invalidValue(parameters, EncodingError.Context(codingPath: [], debugDescription: "")))
        }
    }
}

// MARK: Utils
extension Request {
    
    internal func buildURL() throws -> URL {
        var composedUrl = service.path.isEmpty ? service.baseUrl : service.baseUrl.appending(service.path)
        
        // search for "/:" to find the start of a path parameter
        while let paramRange = findNextPathParamPlaceholderRange(in: composedUrl) {
            let paramName = composedUrl.substring(with: composedUrl.index(after: paramRange.lowerBound)..<paramRange.upperBound)
            let param = try findPathParam(with: paramName, in: pathParameters)
            composedUrl.replaceSubrange(paramRange, with: param)
        }
        guard let url = URL(string: composedUrl)
            else { throw DockerError.invalidURL(service) }
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
    
    private func findPathParam(with name:String, in parameters: [String:Any]) throws -> String {
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
    
    open override func encodeBody(request: inout URLRequest, parameters: Encodable) throws {
        request = try request.encoded(encodable: parameters, encoder: jsonEncoder)
    }
}

open class RequestPList: Request {
    
    open var pListEncoder: PropertyListEncoder {
        let encoder = PropertyListEncoder()
        return encoder
    }
    
    open override func encodeBody(request: inout URLRequest, parameters: Encodable) throws {
        request = try request.encoded(encodable: parameters, encoder: pListEncoder)
    }
}

//MARK: CustomStringConvertible
extension Request {
    
    open override var description: String {
        var string = "REQUEST URL: \(service.baseUrl)\(service.path)\nMETHOD:\(method.rawValue)\nHEADERS:\(headers ?? [:]))"
        if !urlParameters.isEmpty {
            string.append("\nPARAMETERS:\(urlParameters)")
        }
        if let httpBody = urlRequest?.httpBody, let body = String(data: httpBody, encoding: .utf8) {
            string.append("\nBODY:\n\(body)")
        }
        return string
    }
    
    open var shortDescription: String {
        var string = "REQUEST \(method.rawValue) at \(urlStringDescription)"
        return string
    }
    
    open var urlStringDescription: String {
        if let url = urlRequest?.url?.absoluteString {
            return url
        }
        return service.path
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
