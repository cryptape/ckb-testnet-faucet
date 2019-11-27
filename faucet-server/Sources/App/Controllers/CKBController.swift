//
//  CKB.swift
//  App
//
//  Created by 翟泉 on 2019/3/12.
//

import Foundation
import Vapor
import CKB

public class CKBController: RouteCollection {
    private var faucetSending = [String]()
    private let authService = AuthenticationService()

    public func boot(router: Router) throws {
        router.get("ckb/faucet", use: faucet)
    }

    func faucet(_ req: Request) throws -> Future<Response> {
        return try FaucetRequestContent.decode(from: req).flatMap { (content) -> EventLoopFuture<Response> in
            guard let accessToken = content.accessToken else { throw APIError(code: .unauthenticated) }
            guard self.faucetSending.firstIndex(of: accessToken) == nil else {
                throw Abort(HTTPStatus.badRequest)
            }
            self.faucetSending.append(accessToken)

            return GithubService.userInfo(for: accessToken, on: req).unwrap(or: APIError(code: .unauthenticated)).flatMap { (user) -> EventLoopFuture<Response> in
                return self.authService.verify(userId: user.id, on: req).map { status -> Void in
                    if status == .ok {
                        return
                    } else {
                        throw APIError(code: status)
                    }
                }.map { _ in
                    return try self.sendCapacity(address: content.address, req: req)
                }.map { (txHash: H256) -> H256 in
                    _ = Faucet(userId: user.id, txHash: txHash).save(on: req)
                    _ = self.authService.recordReceivedDate(for: user.id, on: req)
                    return txHash
                }.flatMap { txHash -> EventLoopFuture<Response> in
                    return try FaucetResponseContent(txHash: txHash).makeJson(for: req)
                }
            }.always {
                self.faucetSending.remove(at: accessToken)
            }
        }.supportJsonp(on: req)
    }

    private func sendCapacity(address: String, req: Request) throws -> H256 {
        do {
            let wallet = try Wallet(nodeUrl: URL(string: Environment.CKB.nodeURL)!, privateKey: Environment.CKB.walletPrivateKey)
            return try wallet.sendTestTokens(to: address, amount: Environment.CKB.sendCapacityCount)
        } catch {
            let logger = try? req.sharedContainer.make(Logger.self)
            logger?.log(req.description + "\n\t" + error.localizedDescription, at: .verbose, file: #file, function: #function, line: #line, column: #column)

            throw APIError(code: .sendTransactionFailed)
        }
    }
}
