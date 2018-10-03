//
//  Docker+Alamofire.swift
//  Docker
//
//  Created by Paolo Ardia on 21/06/18.
//

import Foundation
import Alamofire

public typealias SessionManager = Alamofire.SessionManager
public typealias ServerTrustPolicy = Alamofire.ServerTrustPolicy
public typealias ServerTrustPolicyManager = Alamofire.ServerTrustPolicyManager
public typealias ParameterEncoding = Alamofire.ParameterEncoding
public typealias URLEncoding = Alamofire.URLEncoding
public typealias HTTPMethod = Alamofire.HTTPMethod
public typealias Result<Value> = Alamofire.Result<Value>
public typealias RequestCompletion = (HTTPURLResponse?, URLRequest?, Data?, Swift.Error?) -> Void
public typealias ProgressHandler = Alamofire.Request.ProgressHandler
public typealias DownloadFileDestination = DownloadRequest.DownloadFileDestination
public typealias DownloadOptions = DownloadRequest.DownloadOptions

internal protocol Requestable {
    func response(callbackQueue: DispatchQueue?, completionHandler: @escaping RequestCompletion) -> Self
}

extension DataRequest: Requestable {
    internal func response(callbackQueue: DispatchQueue?, completionHandler: @escaping RequestCompletion) -> Self {
        return response(queue: callbackQueue) { handler  in
            _ = completionHandler(handler.response, handler.request, handler.data, handler.error)
        }
    }
}

extension DownloadRequest: Requestable {
    internal func response(callbackQueue: DispatchQueue?, completionHandler: @escaping RequestCompletion) -> Self {
        return response(queue: callbackQueue, completionHandler: { handler in
            _ = completionHandler(handler.response, handler.request, nil, handler.error)
        })
    }
}

extension Alamofire.HTTPMethod {
    /// A Boolean value determining whether the request supports multipart.
    public var supportsMultipart: Bool {
        switch self {
        case .post, .put, .patch, .connect:
            return true
        case .get, .delete, .head, .options, .trace:
            return false
        }
    }
}
