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

class Service: NSObject {
    var sessionManager: SessionManager?
    var path: String = ""
    var baseUrl: URL?
}

protocol ServiceRequestProtocol {
    var shouldRemoveNilParameters: Bool { get set }
    func parameters() throws -> [String:Any]?
    func removeNilParametersIfNeeded(parameters: [String:Any]?) -> [String:Any]?
    var additionalHeaders: [String:String]? { get set }
    var parameterEncoding: ParameterEncoding { get set }
    var method: HTTPMethod { get set }
    weak var service: Service { get set }
}

class ServiceRequest: ServiceRequestProtocol {
    var shouldRemoveNilParameters: Bool = false
    var additionalHeaders: [String : String]?
    var method: HTTPMethod = .get
    var parameterEncoding: ParameterEncoding = URLEncoding.default
    weak var service: Service
    
    init(weith service:Service) {
        self.service = service
        self.parameterEncoding = getParametersEncoding()
    }
    
    func removeNilParametersIfNeeded(parameters: [String:Any]?) -> [String:Any]? {
        guard let params = parameters
            else { return nil }
        if shouldRemoveNilParameters {
            // TODO: chiamare pruneNullValues sui parameters
        }
        return params
    }
    
    func parameters() throws -> [String : Any]? { return nil }
    
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

protocol ServiceResponseProtocol {
    var httpStatusCode: Int { get set }
    var headers: [String:String]? { get set }
    var propertyNameForArrayResponse: String? { get set }
    var classOfItemsInArrayResponse: AnyClass? { get set }
    var error: Error? { get set }
}
