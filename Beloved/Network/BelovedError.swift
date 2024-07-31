//
//  HttpClient.swift
//  Beloved
//
//  Created by 风起兮 on 2024/7/29.
//

import Foundation


public enum BelovedError: Swift.Error, Sendable  {
    

//    case dataMissingError(Any.Type)
//
//    case dataParsingFailed(Any.Type, Data, Error)
//
//    /// An error not defined in the  response occurred.
//    case untypedError(error: Error)
    
    case responseFailed(code: Int, message: String)
    case generalError(reason: String)
    case networkError
    case invalidData
    case invalidRequest
    case badResponse
    case invalidToken
    case untypedError(error: Error)
    case invalidLogin
    case uploadFailed
}


extension BelovedError: LocalizedError {

    public var errorDescription: String? {
        switch self {
        case .responseFailed(_, let message):
            return message
        case .networkError:
            return "网络异常"
        case .invalidData:
            return "无效数据"
        case .invalidRequest:
            return "无效请求"
        case .badResponse:
            return "无效响应"
        case .untypedError(let error):
            return error.localizedDescription
        case .generalError(let reason):
            return reason
        case .invalidToken:
            return "无效令牌"
        case .invalidLogin:
            return "登录出错"
        case .uploadFailed:
            return "上传出错"
        }
    }
    
    var errorUserInfo: [String : Any] {
        var userInfo: [String: Any] = [:]
        userInfo[NSLocalizedDescriptionKey] = errorDescription
        return userInfo
    }
}
