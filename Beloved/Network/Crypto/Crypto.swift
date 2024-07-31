//
//  Crypto.swift
//  Beloved
//
//  Created by 风起兮 on 2024/7/29.
//

import Foundation
import CommonCrypto
import CryptoKit
import SwiftyRSA



public class Crypto {
    
    static private let key = [Int8]("hP3THpqtb7WGwcNl".cString(using: .utf8)!.dropLast())
    
    static let publicKey = Data(base64Encoded: "MIGfMA0GCSqGSIb3DQEBAQUAA4GNADCBiQKBgQCQ+ffan+Ll2aC8uLOfi5SbpX3qfj2QyDwMICon2i0OzF5QIP5DQiyTYGpe3esSXaFL8FczxVIqcMHv7L+JjT5iZK4cJwKtIGILYD1LITTlvStItZARpHIVknD+yYD/qzWsOscVdkUHJfMC4tpNp8S/9MlvcCGAY2kt7eTzH3z6YwIDAQAB")!
    
    static func encode(data: Data) -> Data? {
        guard key.count == kCCBlockSizeAES128 else {
            return nil
        }
        
        var buffer = Data(count: data.count + kCCBlockSizeAES128)
        let bufferSize = buffer.count
        var outBytesCount = 0
        let cryptStatus = data.withUnsafeBytes { rawData in
            buffer.withUnsafeMutableBytes { rawBuffer in
                CCCrypt(
                    CCOperation(kCCEncrypt),
                    CCAlgorithm(kCCAlgorithmAES128),
                    CCOptions(kCCOptionPKCS7Padding|kCCOptionECBMode),
                    key,
                    key.count,
                    nil,
                    rawData.baseAddress,
                    data.count,
                    rawBuffer.baseAddress,
                    bufferSize,
                    &outBytesCount)
            }
        }
        return cryptStatus == kCCSuccess ? buffer.subdata(in: 0 ..< outBytesCount) : nil
    }
    
    
    static func decode(data: Data) -> Data? {
        guard key.count == kCCBlockSizeAES128 else {
            return nil
        }
        
        var buffer = Data(count: data.count + kCCBlockSizeAES128)
        let bufferSize = buffer.count
        var outBytesCount = 0
        let cryptStatus = data.withUnsafeBytes { rawData in
            buffer.withUnsafeMutableBytes { rawBuffer in
                CCCrypt(
                    CCOperation(kCCDecrypt),
                    CCAlgorithm(kCCAlgorithmAES128),
                    CCOptions(kCCOptionPKCS7Padding|kCCOptionECBMode),
                    key,
                    key.count,
                    nil,
                    rawData.baseAddress,
                    data.count,
                    rawBuffer.baseAddress,
                    bufferSize,
                    &outBytesCount);
            }
        }
        return cryptStatus == kCCSuccess ? buffer.subdata(in: 0 ..< outBytesCount) : nil
    }
    
    static func createEncryptKey() -> [UInt8] {
        (0 ..< kCCBlockSizeAES128).map { _ in (UInt8(48) ... 122).randomElement()! }
    }
    
    static func encrypt(data: [UInt8])-> String? {
        guard let key = try? PublicKey(data: Crypto.publicKey) else {
            return nil
        }
        let clear = ClearMessage(data: .init(bytes: data, count: data.count))
        return (try? clear.encrypted(with: key, padding: .PKCS1))?.base64String
    }
    
    static func decrypt(data: Data, key: [UInt8]) -> Data? {
        guard data[0] != 123, let data = Data(base64Encoded: data, options: .ignoreUnknownCharacters), key.count == kCCBlockSizeAES128 else {
            return nil
        }
        
        var buffer = Data(count: data.count + kCCBlockSizeAES128)
        let bufferSize = buffer.count
        var outBytesCount = 0
        let cryptStatus = data.withUnsafeBytes { rawData in
            buffer.withUnsafeMutableBytes { rawBuffer in
                CCCrypt(
                    CCOperation(kCCDecrypt),
                    CCAlgorithm(kCCAlgorithmAES128),
                    CCOptions(kCCOptionPKCS7Padding|kCCOptionECBMode),
                    key,
                    key.count,
                    nil,
                    rawData.baseAddress,
                    data.count,
                    rawBuffer.baseAddress,
                    bufferSize,
                    &outBytesCount);
            }
        }
        return cryptStatus == kCCSuccess ? buffer.subdata(in: 0 ..< outBytesCount) : nil
    }
    
    
    static func sign(of parameters: Parameters) -> String {
        let reduced = parameters
            .sorted { $0.key < $1.key }
            .reduce(into: "") {
                $0 += $1.value != nil ? "\($1.key)=\($1.value!)&" : ""
            }
            .dropLast()
        
        let salting = String( reduced + "LEIDIAN_YULIAO")
        
        return salting.md5
    }
}

//  https://juejin.cn/post/6914147790197096456
//  https://juejin.cn/post/6844903854077640711
//  https://forums.swift.org/t/how-to-read-uint32-from-a-data/59431/11
extension Data {
    
    // 字节序
    // 在网络传输时，TCP/IP中规定必须采用网络字节顺，也就是大端字节序。
    enum ByteOrder { // e.g: 0x0025
        //  小端字节序 0x25 0x00
        case littleEndian
        //  大端字节序 0x00 0x25
        case bigEndian
    }
    
    
    // fix Fatal error: load from misaligned raw pointer
    // https://forums.swift.org/t/how-to-read-uint32-from-a-data/59431/11
    func load<T>(fromByteOffset offset: Int = 0, byteOrder order: ByteOrder = .bigEndian, as type: T.Type) -> T where T: FixedWidthInteger {
        let right = offset &+ MemoryLayout<T>.size
        assert(offset >= 0 && right > offset && right <= count)
        let bytes = self[offset ..< right]
        if order == .bigEndian {
            // return bytes.reduce(0) { T($0) << 8 + T($1) }
            
            //  Fatal error: load from misaligned raw pointer
            // bytes.withUnsafeBytes { $0.load(as: type) }.bigEndian
            // 有可能通过subscript获取到的Data和原始数据共享的相同内存。
            let data = Data(bytes)
            return data.withUnsafeBytes { $0.load(as: type) }.bigEndian
        } else {
            return bytes.reversed().reduce(0) { T($0) << 8 + T($1) }
        }
    }
    
    //  https://juejin.cn/post/6844903854077640711
    mutating func storeBytes<T>(of value: T, toByteOffset offset: Int = 0, byteOrder order: ByteOrder = .bigEndian) where T: FixedWidthInteger {
        assert(offset + MemoryLayout<T>.size <= self.count)
        self.withUnsafeMutableBytes {
            let value =  if order == .bigEndian { value.bigEndian } else { value.littleEndian}
            $0.storeBytes(of: value, toByteOffset: offset, as: T.self)
        }
    }
    
}

extension UInt8 {
    var hexString : String {
        let str = String(format:"0x%02x",self)
        return str
    }
}

extension Data {
    var bytes : [UInt8] {
        return [UInt8](self)
    }
    var hexString : String {
        var str = ""
        for byte in self.bytes {
            str += byte.hexString
            str += " "
        }
        return str
    }
}


extension String {
    var md5: String {
        if #available(iOS 13.0, *) {
            return Insecure.MD5
                .hash(data: data(using: .utf8)!)
                .map {String(format: "%02x", $0)}
                .joined()
        } else {
            guard let data = self.data(using: .utf8) else { return "" }
            var digest = [UInt8](repeating: 0, count: Int(CC_MD5_DIGEST_LENGTH))
            _ = data.withUnsafeBytes { (bytes: UnsafeRawBufferPointer) in
                return CC_MD5(bytes.baseAddress, CC_LONG(data.count), &digest)
            }
            return digest.map { String(format: "%02x", $0) }.joined()
        }
    }
}
