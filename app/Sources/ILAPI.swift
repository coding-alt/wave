import Foundation
import CommonCrypto

// MARK: - AES (AES-128 / ECB / PKCS7)

enum ILAES {
    private static let keyBytes: [UInt8] = Array("ILOVERADIO666666".utf8)

    static func encrypt(_ plain: String) -> String {
        let input = plain.data(using: .utf8) ?? Data()
        var out = Data(count: input.count + kCCBlockSizeAES128)
        var moved = 0
        let status = out.withUnsafeMutableBytes { ob -> CCCryptorStatus in
            input.withUnsafeBytes { ib -> CCCryptorStatus in
                CCCrypt(CCOperation(kCCEncrypt),
                        CCAlgorithm(kCCAlgorithmAES),
                        CCOptions(kCCOptionECBMode | kCCOptionPKCS7Padding),
                        keyBytes, keyBytes.count, nil,
                        ib.baseAddress, input.count,
                        ob.baseAddress, ob.count, &moved)
            }
        }
        guard status == kCCSuccess else { return "" }
        return out.prefix(moved).base64EncodedString()
    }

    static func decrypt(_ base64: String) -> String? {
        guard let input = Data(base64Encoded: base64) else { return nil }
        var out = Data(count: input.count + kCCBlockSizeAES128)
        var moved = 0
        let status = out.withUnsafeMutableBytes { ob -> CCCryptorStatus in
            input.withUnsafeBytes { ib -> CCCryptorStatus in
                CCCrypt(CCOperation(kCCDecrypt),
                        CCAlgorithm(kCCAlgorithmAES),
                        CCOptions(kCCOptionECBMode),
                        keyBytes, keyBytes.count, nil,
                        ib.baseAddress, input.count,
                        ob.baseAddress, ob.count, &moved)
            }
        }
        guard status == kCCSuccess else { return nil }
        var bytes = [UInt8](out.prefix(moved))
        if let last = bytes.last, last > 0, last <= 16, Int(last) <= bytes.count,
           bytes.suffix(Int(last)).allSatisfy({ $0 == last }) {
            bytes.removeLast(Int(last))
        }
        return String(data: Data(bytes), encoding: .utf8)
    }
}

// MARK: - Models

struct ILProvince: Decodable, Identifiable, Hashable {
    let pid: Int
    let title: String
    var id: Int { pid }
}

struct ILCategory: Decodable, Identifiable, Hashable {
    let pid: Int
    let title: String
    var id: Int { pid }
}

struct ILRadio: Decodable, Identifiable, Hashable {
    let id: Int
    let name: String
    let imgUrl: String?
    let playUrl: String?
    let playUrl2: String?
    let playcount: Int?
    let province_id: String?
    let category_id: Int?
    let platform: String?
    let programme: String?
    let desc: String?
}

private struct ILCategoryPayload: Decodable {
    let provinces: [ILProvince]?
    let cates: [ILCategory]?
}

private struct ILRadiosPayload: Decodable {
    let radios: [ILRadio]?
}

private struct ILRadioPayload: Decodable {
    let radio: ILRadio?
}

// MARK: - API

enum ILError: LocalizedError {
    case server(String)
    case decode
    var errorDescription: String? {
        switch self {
        case .server(let m): return m.isEmpty ? "服务异常" : m
        case .decode: return "数据解析失败"
        }
    }
}

struct ILAPI {
    static let base = "http://49.232.234.212"

    private static var deviceID: String = {
        if let saved = UserDefaults.standard.string(forKey: "il.deviceID"), !saved.isEmpty { return saved }
        let v = UUID().uuidString
        UserDefaults.standard.set(v, forKey: "il.deviceID")
        return v
    }()

    @discardableResult
    static func post(_ path: String, _ extra: [String: String] = [:]) async throws -> Any {
        var params: [String: String] = [
            "imei": deviceID,
            "uid": deviceID,
            "device": "2",
            "qd": "2002",
            "version": "1.2.5",
            "model": "Andriod",
            "channelid": "Andriod",
        ]
        extra.forEach { params[$0.key] = $0.value }

        let jsonData = try JSONSerialization.data(withJSONObject: params, options: [])
        let json = String(data: jsonData, encoding: .utf8) ?? "{}"
        let sign = ILAES.encrypt(json)

        var comps = URLComponents(string: base + path)!
        comps.queryItems = nil
        var request = URLRequest(url: comps.url!)
        request.httpMethod = "POST"
        request.timeoutInterval = 15
        request.setValue("application/json;charset=UTF-8", forHTTPHeaderField: "Accept")
        request.setValue("application/x-www-form-urlencoded; charset=utf-8", forHTTPHeaderField: "Content-Type")
        var body = "sign=" + (sign.addingPercentEncoding(withAllowedCharacters: .alphanumerics) ?? sign)
        request.httpBody = body.data(using: .utf8)
        body = ""

        let (data, _) = try await URLSession.shared.data(for: request)
        guard let root = try JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            throw ILError.decode
        }
        let code = (root["code"] as? String) ?? ""
        let msg = (root["msg"] as? String) ?? ""

        var payload: Any = root["data"] ?? [:]
        if let cipher = payload as? String {
            if cipher.isEmpty { payload = [:] }
            else if let plain = ILAES.decrypt(cipher),
                    let decoded = try? JSONSerialization.jsonObject(with: Data(plain.utf8)) {
                payload = decoded
            } else {
                payload = [:]
            }
        }
        if code != "200" { throw ILError.server(msg) }
        return payload
    }

    static func categories() async throws -> ([ILProvince], [ILCategory]) {
        let obj = try await post("/radio/getAllCategory")
        let d = try JSONSerialization.data(withJSONObject: obj)
        let p = try JSONDecoder().decode(ILCategoryPayload.self, from: d)
        return (p.provinces ?? [], p.cates ?? [])
    }

    static func radios(provinceId: Int? = nil, cateId: Int? = nil) async throws -> [ILRadio] {
        var extra: [String: String] = [:]
        if let p = provinceId { extra["provinceId"] = String(p) }
        if let c = cateId { extra["cateId"] = String(c) }
        let obj = try await post("/radio/getRadios", extra)
        let d = try JSONSerialization.data(withJSONObject: obj)
        return try JSONDecoder().decode(ILRadiosPayload.self, from: d).radios ?? []
    }

    static func search(_ keyword: String) async throws -> [ILRadio] {
        let obj = try await post("/radio/getSearchRadio", ["content": keyword])
        let d = try JSONSerialization.data(withJSONObject: obj)
        return try JSONDecoder().decode(ILRadiosPayload.self, from: d).radios ?? []
    }

    static func radio(id: Int) async throws -> ILRadio? {
        let obj = try await post("/radio/getRadio", ["rid": String(id)])
        let d = try JSONSerialization.data(withJSONObject: obj)
        return try JSONDecoder().decode(ILRadioPayload.self, from: d).radio
    }
}

// MARK: - Programme

struct ILProgramme: Decodable {
    let title: String?
    let start_time: String?
    let end_time: String?
}

extension ILRadio {
    var currentProgramme: String? {
        guard let s = programme, let d = s.data(using: .utf8),
              let list = try? JSONDecoder().decode([ILProgramme].self, from: d) else { return nil }
        let f = DateFormatter()
        f.dateFormat = "HH:mm:ss"
        f.timeZone = TimeZone(identifier: "Asia/Shanghai")
        let now = f.string(from: Date())
        for p in list {
            if let a = p.start_time, let b = p.end_time, a <= now, now < b {
                return p.title
            }
        }
        return nil
    }
}
