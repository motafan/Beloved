//
//  OSDevice.Header.swift
//  Popular
//
//  Created by 风起兮 on 2023/6/8.
//

import UIKit
import Security


extension OSDevice {
    
    
    fileprivate static var identifier: String {
        getUniqueDeviceID()
    }
    
    static func getUniqueDeviceID() -> String {
        
        if let value = getUUIDFromKeychain() {
            return value
        }
        
        let uuidString = UUID().uuidString
        saveUUIDToKeychain(uuid: uuidString)
        return uuidString
    }
    
    private static var bundleID: String {
        Bundle.main.infoDictionary!["CFBundleIdentifier"] as! String
    }

    static func saveUUIDToKeychain(uuid: String) {
        
        let key = "\(bundleID).uniqueDeviceID"
        let uuidData = uuid.data(using: .utf8)!

        // 删除旧的UUID（如果存在）
        let deleteQuery: [String: Any] = [kSecClass as String: kSecClassGenericPassword,
                                          kSecAttrAccount as String: key]
        SecItemDelete(deleteQuery as CFDictionary)

        // 存储新的UUID
        let addQuery: [String: Any] = [kSecClass as String: kSecClassGenericPassword,
                                       kSecAttrAccount as String: key,
                                       kSecValueData as String: uuidData]
        SecItemAdd(addQuery as CFDictionary, nil)
    }

    static func getUUIDFromKeychain() -> String? {
        let key = "\(bundleID).uniqueDeviceID"
        let query: [String: Any] = [kSecClass as String: kSecClassGenericPassword,
                                    kSecAttrAccount as String: key,
                                    kSecReturnData as String: kCFBooleanTrue!,
                                    kSecMatchLimit as String: kSecMatchLimitOne]

        var item: CFTypeRef?
        let status = SecItemCopyMatching(query as CFDictionary, &item)

        if status == errSecSuccess, let data = item as? Data, let uuid = String(data: data, encoding: .utf8) {
            return uuid
        } else {
            return nil
        }
    }

    
    fileprivate static var platform: String {
        var systemInfo = utsname()
        uname(&systemInfo); // 获取系统设备信息
        return withUnsafePointer(to: &systemInfo.machine.0) { ptr in
            String(cString: ptr)
        }
    }
    
    static var standard: OSDevice {
        .with{
            $0.os = 1
            $0.model = platform
            $0.osVersion = ""
            $0.appVersion = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as! String
            $0.deviceID = identifier
            $0.openid = "520"
        }
    }
}
