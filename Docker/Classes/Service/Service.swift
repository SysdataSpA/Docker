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
