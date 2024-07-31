//
//  HttpClient.swift
//  Beloved
//
//  Created by 风起兮 on 2024/7/29.
//

import Foundation

/// Represents a terminator pipeline with a SwiftProtobuf decoder to parse data.
public class SwiftProtobufParse: ProtobufResponseDataParser {
    
    public func parse<R>(request: R, data: Data) throws -> R.Response where R : Request {
        guard let r =  request as? (any ProtobufRequest) else {
            throw BelovedError.invalidRequest
        }
        
        return try parse(request: r, data: data) as! R.Response
    }
    
    
    public func parse<R>(request: R, data: Data) throws -> R.Response where R : ProtobufRequest {
        // Fatal error: load from misaligned raw pointer
        // 有可能通过subscript获取到的Data和原始数据共享的相同内存。
       // let data = Data(data)
       // _ = data.load(fromByteOffset: 6 * stride, as: UInt32.self) // 上下文

        guard data.count >= 16 else {
            throw BelovedError.invalidData
        }

        // Fatal error: load from misaligned raw pointer
        //  https://juejin.cn/post/6844903854077640711
        
         let stride = MemoryLayout<UInt16>.stride
        
        let length = data.load(fromByteOffset: 0, as: UInt16.self)
        let version = data.load(fromByteOffset: 1 * stride, as: UInt16.self)
        let encryptMethod = data.load(fromByteOffset: 2 * stride, as: UInt16.self)
        let compress = data.load(fromByteOffset: 3 * stride, as: UInt16.self)
        _ = data.load(fromByteOffset: 4 * stride, as: UInt16.self) // 小程序预留
        _ = data.load(fromByteOffset: 5 * stride, as: UInt16.self) // 模块ID
        _ = data.load(fromByteOffset: 6 * stride, as: UInt32.self) // 上下文
  
        guard length < data.count, version == 0, compress == 0 else { throw BelovedError.invalidData }
        
        guard let r = request as? SwiftProtobufRequest<R.Response> else {
            throw BelovedError.invalidRequest
        }
        
        switch encryptMethod {
            case 0: // 无加密
            let response = try OSApiResponse(serializedBytes: data.dropFirst(Int(length)))
                let header = response.header
                if header.code == 0 {
                    return response[keyPath: r.keyPath]
                } else {
                    throw BelovedError.responseFailed(code: Int(header.code), message: header.message)
                }
            case 1: // 有加密，需要解密
                if let decoded = Crypto.decode(data: data.dropFirst(Int(length))) {
                    let response = try OSApiResponse(serializedBytes: decoded)
                    let header = response.header
                    #if DEBUG
                    debugPrint(r.keyPath)
                    debugPrint(header)
                    debugPrint(response)
                    #endif
                    if header.code == 0 {
                        return response[keyPath: r.keyPath]
                    } else {
                        throw BelovedError.responseFailed(code: Int(header.code), message: header.message)
                    }
                }
                throw BelovedError.invalidData
            default:
                throw BelovedError.badResponse
        }


    }
    
}
