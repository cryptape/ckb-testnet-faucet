//
//  CKB.swift
//  App
//
//  Created by 翟泉 on 2019/3/12.
//

import Foundation
import Vapor
import CKB

public struct CKBController: RouteCollection {
    let nodeUrl: URL
    let api: APIClient
    let systemScript: SystemScript

    public init(nodeUrl: URL) throws {
        self.nodeUrl = nodeUrl
        api = APIClient(url: nodeUrl)
        systemScript = try SystemScript.loadFromGenesisBlock(nodeUrl: nodeUrl)
    }

    public func boot(router: Router) throws {
        router.get("ckb/faucet", use: faucet)
        router.get("ckb/address", use: address)
        router.get("ckb/address/random", use: makeRandomAddress)
    }

    // MARK: - API

    func faucet(_ req: Request) -> Future<Response> {
        let urlParameters = req.http.urlString.urlParametersDecode
        let accessToken = req.http.cookies.all[accessTokenCookieName]?.string ?? ""
        let email = (try? GithubService.getUserInfo(for: accessToken).email) ?? ""
        var isSuccess = false
        var txHash = ""
        return Authentication().verify(email: email, on: req).map { status -> String in
            // Send capacity
            if status == .tokenIsVailable {
                do {
                    if let address = urlParameters["address"] {
                        txHash = try self.sendCapacity(address: address)
                        isSucceed = true
                        return ["status": 0, "txHash": txHash].toJson
                    } else {
                        return ["status": -3, "error": "No address"].toJson
                    }
                } catch {
                    return ["status": -4, "error": error.localizedDescription].toJson
                }
            } else {
                return ["status": status.rawValue, "error": "Verify failed"].toJson
            }
        }.map { json -> String in
            // Support jsonp
            if let callback = req.http.url.absoluteString.urlParametersDecode["callback"] {
                return "\(callback)(\(json))"
            } else {
                return json
            }
        }.encode(status: .ok, for: req).flatMap { res -> EventLoopFuture<Response> in
            // Record recently received date
            if isSucceed {
                return Authentication().recordReceivedDate(for: email, on: req).map { _ in res }
            } else {
                return req.sharedContainer.eventLoop.newSucceededFuture(result: res)
            }
        }.flatMap { res -> EventLoopFuture<Response> in
            // API logging
            return try Faucet(email: email, txHash: txHash).save(on: req).encode(for: req).map { _ in res }
        }
    }

    func address(_ req: Request) -> Response {
        let urlParameters = req.http.urlString.urlParametersDecode
        let result: [String: Any]
        do {
            if let privateKey = urlParameters["privateKey"] {
                let address = try CKBController.privateToAddress(privateKey)
                result = ["address": address, "status": 0]
            } else if let publicKey = urlParameters["publicKey"] {
                let address = try CKBController.publicToAddress(publicKey)
                result = ["address": address, "status": 0]
            } else {
                result = ["status": -1, "error": "No public or private key"]
            }
        } catch {
            result = ["status": -2, "error": error.localizedDescription]
        }
        let headers = HTTPHeaders([("Access-Control-Allow-Origin", "*")])
        return Response(http: HTTPResponse(headers: headers, body: HTTPBody(string: result.toJson)), using: req.sharedContainer)
    }

    func makeRandomAddress(_ req: Request) -> Response {
        let privateKey = CKBController.generatePrivateKey()
        let result: [String: Any] = [
            "privateKey": privateKey,
            "publicKey": try! CKBController.privateToPublic(privateKey),
            "address": try! CKBController.privateToAddress(privateKey)
        ]
        let headers = HTTPHeaders([("Access-Control-Allow-Origin", "*")])
        return Response(http: HTTPResponse(headers: headers, body: HTTPBody(string: result.toJson)), using: req.sharedContainer)
    }

    // MARK: - Utils

    public func sendCapacity(address: String) throws -> H256 {
        guard let publicKeyHash = AddressGenerator(network: .testnet).publicKeyHash(for: address) else { throw Error.invalidAddress }
        let targetLock = Script(args: [Utils.prefixHex(publicKeyHash)], codeHash: systemScript.codeHash)

        let wallet = Wallet(api: api, systemScript: systemScript, privateKey: Environment.Process.walletPrivateKey)
        return try wallet.sendCapacity(targetLock: targetLock, capacity: Environment.Process.sendCapacityCount)
    }

    public static func privateToAddress(_ privateKey: String) throws -> String {
        return try publicToAddress(try privateToPublic(privateKey))
    }

    public static func publicToAddress(_ publicKey: String) throws -> String {
        switch validatePublicKey(publicKey) {
        case .valid(let value):
            return AddressGenerator(network: .testnet).address(for: value)
        case .invalid(let error):
            throw error
        }
    }

    public static func privateToPublic(_ privateKey: String) throws -> String {
        switch validatePrivateKey(privateKey) {
        case .valid(let value):
            return Utils.privateToPublic(value)
        case .invalid(let error):
            throw error
        }
    }

    public static func generatePrivateKey() -> String {
        var data = Data(repeating: 0, count: 32)
        #if os(OSX)
            data.withUnsafeMutableBytes({ _ = SecRandomCopyBytes(kSecRandomDefault, 32, $0.baseAddress! ) })
        #else
            for idx in 0..<32 {
                data[idx] = UInt8.random(in: UInt8.min...UInt8.max)
            }
        #endif
        return data.toHexString()
    }

    public static func validatePrivateKey(_ privateKey: String) -> VerifyResult {
        if privateKey.hasPrefix("0x") {
            if privateKey.lengthOfBytes(using: .utf8) == 66 {
                return .valid(value: String(privateKey.dropFirst(2)))
            } else {
                return .invalid(error: .invalidPrivateKey)
            }
        } else if privateKey.lengthOfBytes(using: .utf8) == 64 {
            return .valid(value: privateKey)
        } else {
            return .invalid(error: .invalidPrivateKey)
        }
    }

    public static func validatePublicKey(_ publicKey: String) -> VerifyResult {
        if publicKey.hasPrefix("0x") {
            if publicKey.lengthOfBytes(using: .utf8) == 68 {
                return .valid(value: publicKey)
            } else {
                return .invalid(error: .invalidPublicKey)
            }
        } else if publicKey.lengthOfBytes(using: .utf8) == 66 {
            return .valid(value: publicKey)
        } else {
            return .invalid(error: .invalidPublicKey)
        }
    }
}

extension CKBController {
    public enum Error: String, Swift.Error {
        case invalidPrivateKey = "Invalid privateKey"
        case invalidPublicKey = "Invalid publicKey"
        case invalidAddress = "Invalid address"
    }

    public enum VerifyResult {
        case valid(value: String)
        case invalid(error: Error)
    }
}
