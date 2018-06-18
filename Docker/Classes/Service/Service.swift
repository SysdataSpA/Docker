//
//  ServiceGeneric.swift
//  Pods-Docker
//
//  Created by Paolo Ardia on 14/06/18.
//

import UIKit
import Alamofire

struct MultipartBodyInfo {
    var data: Data?
    var name: String?
    var filename: String?
    var mimeType: String?
}

open class Service: NSObject {
    open var sessionManager: SessionManager = SessionManager.default
    open var path: String = ""
    open var baseUrl: URL?
}

public protocol ServiceRequestProtocol {
    var shouldRemoveNilParameters: Bool { get set }
    func parameters() throws -> [String:Any]?
    func removeNilParametersIfNeeded(parameters: [String:Any]?) -> [String:Any]?
    var additionalHeaders: [String:String]? { get set }
    var parameterEncoding: ParameterEncoding { get set }
    var responseSerializer: DataResponseSerializer<Any>? { get set }
    var method: HTTPMethod { get set }
    var service: Service? { get set }
}

open class ServiceRequest: ServiceRequestProtocol {
    open var shouldRemoveNilParameters: Bool = false
    open var additionalHeaders: [String : String]?
    open var method: HTTPMethod = .get
    open var parameterEncoding: ParameterEncoding = URLEncoding.default
    open var service: Service?
    open var responseSerializer: DataResponseSerializer<Any>?
    internal var dataRequest: Request?
    
    public init(with service:Service, method:HTTPMethod = .get, shouldRemoveNilParameters:Bool = false) {
        self.service = service
        self.method = method
        self.shouldRemoveNilParameters = shouldRemoveNilParameters
        self.parameterEncoding = getParametersEncoding()
        self.responseSerializer = DataRequest.jsonResponseSerializer()
    }
    
    open func removeNilParametersIfNeeded(parameters: [String:Any]?) -> [String:Any]? {
        guard let params = parameters
            else { return nil }
        if shouldRemoveNilParameters {
            // TODO: chiamare pruneNullValues sui parameters
        }
        return params
    }
    
    open func parameters() throws -> [String : Any]? { return nil }
    
    private func getParametersEncoding() -> ParameterEncoding {
        switch self.method {
        case .get,
             .delete,
             .head:
            return URLEncoding.default
        default:
            return JSONEncoding(options: .prettyPrinted)
        }
    }
}

public protocol ServiceResponseProtocol {
    var resultClass: Decodable.Protocol? { get set }
    var request: ServiceRequestProtocol { get }
    var httpStatusCode: Int? { get }
    var error: Error? { get }
    var value: Any? { get }
    func decode(_ data: Data) throws -> Decodable.Protocol?
}

open class ServiceResponse: ServiceResponseProtocol {
    open var request: ServiceRequestProtocol
    open var resultClass: Decodable.Protocol?
    internal var dataResponse: Alamofire.DataResponse<Any>?
    
    public var httpStatusCode: Int? {
        get {
            return self.dataResponse?.response?.statusCode
        }
    }
    public var value: Any? {
        get {
            return self.dataResponse?.value
        }
    }
    public var error: Error? {
        get {
            return self.dataResponse?.error
        }
    }
    
    public init(_ request: ServiceRequestProtocol, response: Alamofire.DataResponse<Any>) {
        self.request = request
        self.dataResponse = response
    }
    
    open func decode(_ data: Data) throws -> Decodable.Protocol? {
        if let resultClass = self.resultClass {
            return try JSONDecoder().decode(resultClass, from: data)
        }
        return nil
    }
}
