//
//  SwiftProtobufRequest.swift
//  Beloved
//
//  Created by 风起兮 on 2024/7/29.
//

import Foundation
import SwiftProtobuf


public protocol ProtobufResponseDataParser: ResponseDataParser {
    
    func parse<R: ProtobufRequest>(request: R, data: Data) throws -> R.Response
}



public protocol ProtobufRequest: Request where Response: SwiftProtobuf.Message {
    
}


public extension SwiftProtobufRequest {
    
    
    var baseURL: URL {
        fatalError()
    }
   
    

    var path: String {
        "api/"
    }
    
}

extension OSRequestHeader {
    
    static func generate() -> OSRequestHeader {
        .with {
            $0.appFlag = 4
            $0.version = 1
            $0.token = ""
            $0.context = 0
            $0.timestamp = Date().currentTimeMillis
            $0.device = .standard
            fatalError()
        }
    }
}

public struct SwiftProtobufRequest<T>: ProtobufRequest where T: SwiftProtobuf.Message & Sendable {
    

    public typealias Response = T
    public private(set) var method: HTTPMethod
    
    public private(set) var keyPath: KeyPath<OSApiResponse, T>
    public let httpBodyRequest: OSApiRequest
    
    
    public var allHTTPHeaderFields: [String : String]? {
        ["Content-Type": "application/x-protobuf; charset=UTF-8"]
    }
    
    public var parameters: Parameters? {
        return nil
    }
    
    public var httpBody: Data? {
        createHttpBody(httpBodyRequest, UInt32(Date().timeIntervalSince1970))
    }
    
    
    public var dataParser: ResponseDataParser {
        return SwiftProtobufParse()
    }
    
    
    public init(method: HTTPMethod, keyPath: KeyPath<OSApiResponse, T>, httpBodyRequest:  OSApiRequest) where T: Sendable {
        self.method = method
        self.keyPath = keyPath
        var request = httpBodyRequest
        request.header = OSRequestHeader.generate()
        #if DEBUG
        debugPrint("req::\(httpBodyRequest)")
        #endif
        self.httpBodyRequest = request
    }
    
    
    
    func createHttpBody(_ request: OSApiRequest, _ context: UInt32) -> Data {
        var data = Data(count: 16)
        let stride =  MemoryLayout<UInt16>.stride
        // 头长度
        data.storeBytes(of: UInt16(16), toByteOffset: 0)
        // 头版本
        data.storeBytes(of: UInt16(0), toByteOffset: 1 * stride)
        // 加密算法， 0 不加密， 1 AES加密， 2： RSA 加密
        data.storeBytes(of: UInt16(1), toByteOffset: 2 * stride)
        // 压缩算法
        data.storeBytes(of: UInt16(0), toByteOffset: 3 * stride)
        // 小程序预留
        data.storeBytes(of: UInt16(0), toByteOffset: 4 * stride)
        // 模块ID
        data.storeBytes(of:UInt16(request.moduleID), toByteOffset: 5 * stride)
        // 上下文ID
        data.storeBytes(of: UInt32(context), toByteOffset: 6 * stride)
        // 8字节预留
        let aesEncodeData = Crypto.encode(data: try! request.serializedData())!
        data.append(aesEncodeData)
        return data
    }
    
}




extension OSApiRequest {
    var moduleID: UInt16 {
        switch request {
        case .main: return 2
        case .user: return 3
        case .lobby: return 4
        case .moment: return 5
        case .some: return 6
        case .none: return 0
        }
    }
}


