//
//  CodableParse.swift
//  Beloved
//
//  Created by 风起兮 on 2024/7/29.
//

import Foundation

/// Represents a terminator pipeline with a SwiftProtobuf decoder to parse data.
public class JSONCodableParse: JSONResponseDataParser {
    
    let encryptKey: [UInt8]
    
    init(encryptKey: [UInt8]) {
        self.encryptKey = encryptKey
    }
        
    public func parse<R>(request: R, data: Data) throws -> R.Response where R : Request {
        guard let r =  request as? (any JSONRequest) else {
            throw BelovedError.invalidRequest
        }
        
        return try parse(request: r, data: data) as! R.Response
    }
    
    public func parse<R>(request: R, data: Data) throws -> R.Response where R : JSONRequest {
        
        let decodedData = Crypto.decrypt(data: data, key: encryptKey) ?? data
        let decoder = JSONDecoder()
        return try decoder.decode(R.Response.self, from: decodedData)
        
    }
    
}
