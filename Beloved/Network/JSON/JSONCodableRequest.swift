//
//  HttpCodableRequest.swift
//  Beloved
//
//  Created by 风起兮 on 2024/7/29.
//

import Foundation


public protocol JSONResponseDataParser: ResponseDataParser {
    
    func parse<R: JSONRequest>(request: R, data: Data) throws -> R.Response
}



public protocol JSONRequest: Request where Response: Swift.Codable {
    
}


public struct JSONCodableRequest<T>: JSONRequest where T: Swift.Codable & Sendable {
   
    public typealias Response = T
    
    
    public var method: HTTPMethod
    
    public var baseURL: URL
    
    public var path: String
    
    public var allHTTPHeaderFields: [String : String]? {
        
        let argumentsSign = Crypto.sign(of: completeArguments)
        return [
            "sign": argumentsSign,
            "keyEn": Crypto.encrypt(data: encryptKey)!,
            "Content-Type": "application/json; charset=utf-8"
        ]
    }
    
    let encryptKey: [UInt8] = Crypto.createEncryptKey()
    
    fileprivate var pending: Parameters {
        [
            "token":  "",
            "timestamp":  Int64(Date().timeIntervalSince1970),
            "version" : 3,
            "os": 1,
            "appVersion": Bundle.main.infoDictionary?["CFBundleShortVersionString"] as! String ,
            "appFlag": 4
        ]
    }
    
    fileprivate var completeArguments: Parameters {
        let parameters = parameters ?? [:]
        
        return parameters.merging(pending) {$1}
    }
    
    public var parameters: Parameters?
    
    public var httpBody: Data? {
         try? JSONSerialization.data(withJSONObject: completeArguments)
    }
    
    public var dataParser: ResponseDataParser {
        JSONCodableParse(encryptKey: encryptKey)
    }
    


}
