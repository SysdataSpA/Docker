//
//  ExampleService.swift
//  Example
//
//  Created by Paolo Ardia on 18/06/18.
//  Copyright © 2018 Paolo Ardia. All rights reserved.
//

import UIKit
import Docker

func getDocumentsDirectory() -> URL {
    let paths = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)
    let documentsDirectory = paths[0]
    return documentsDirectory
}

class ResourcesService: Service {
    var path: String = "/resources"
    var baseUrl: String = "https://go8pgqn.restletmocks.net"
    
    var sessionManager: SessionManager {
        return ExampleServiceManager.shared().defaultSessionManager
    }
}

class GetResourcesRequest: Request {

    func responseClass() -> Response.Type {
        return GetResourcesResponse.self
    }

    var multipartBodyParts: [MultipartBodyPart]?
    
    var service: Service = ResourcesService()
    
    var headers: [String : String]? {
        return ["Accept":"application/json"]
    }
    
    var demoSuccessFileName: String? {
        return "getResources.json"
    }
}

class GetResourcesResponse: Response {
    
    override func decode() -> Any? {
        result = Result<Any>(value: { () -> [Resource] in
            return try JSONDecoder().decode([Resource].self, from: data)
        })
        return result?.value
    }
}

class PostResourceRequest: Request {

    var resource: Resource
    
    init(resource: Resource) {
        self.resource = resource
    }
    
    func responseClass() -> Response.Type {
        return PostResourceResponse.self
    }
    
    var service: Service = ResourcesService()
    
    var multipartBodyParts: [MultipartBodyPart]?
    
    var headers: [String : String]? {
        return ["Content-Type":"application/json", "Accept":"application/json"]
    }
    
    var type: RequestType {
        return .jsonEncodableBody(resource, encoder: nil)
    }
    
    var method: HTTPMethod { return .post }
    
    var demoSuccessFileName: String? { return "addResource.json" }
}

class PostResourceResponse: Response {
    override func decode() -> Any? {
        result = Result<Any>(value: { () -> Resource in
            return try JSONDecoder().decode(Resource.self, from: data)
        })
        return result?.value
    }
}





class DownloadService: Service {
    var baseUrl: String = "https://st.ilfattoquotidiano.it/"
    var path: String = "/wp-content/uploads/2017/08/cane905-675x905.jpg"
    
    var sessionManager: SessionManager {
        return ExampleServiceManager.shared().defaultSessionManager
    }
}

class DownloadRequest: Request {
    func responseClass() -> Response.Type {
        return DownloadResponse.self
    }
    
    var service: Service = DownloadService()
    
    var multipartBodyParts: [MultipartBodyPart]?
    
    var type: RequestType { return .download({ temporaryURL, response in
        return (getDocumentsDirectory().appendingPathComponent("image.jpg"), [DownloadOptions.removePreviousFile] )
    })}
    
    var headers: [String : String]? {
        return ["Accept":"image/jpeg"]
    }
    
    var demoSuccessFileName: String? { return "dog.jpg" }
}

class DownloadResponse: Response {
    override func decode() -> Any? {
        result = Result<Any>(value: { () -> UIImage? in
            do {
                let data = try Data(contentsOf: getDocumentsDirectory().appendingPathComponent("image.jpg"))
                if let image = UIImage(data: data) {
                    return image
                }
                return nil
            } catch {
                print(error)
                return nil
            }
        })
        return result?.value
    }
}
