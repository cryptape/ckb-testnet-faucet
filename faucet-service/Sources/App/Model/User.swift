//
//  UserModel.swift
//  App
//
//  Created by 翟泉 on 2019/3/12.
//

import Foundation
import SQLite

public struct User {
    public let accessToken: String
    public var authorizationDate: Date
    public var collectionDate: Date?

    public init(accessToken: String, authorizationDate: Date, collectionDate: Date?) {
        self.accessToken = accessToken
        self.authorizationDate = authorizationDate
        self.collectionDate = collectionDate
    }
}

extension User {
    public func save() {
    }
    public static func query(accessToken: String) -> User? {
        return nil
    }
}
