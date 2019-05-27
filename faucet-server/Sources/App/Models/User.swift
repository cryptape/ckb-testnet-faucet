//
//  UserModel.swift
//  App
//
//  Created by 翟泉 on 2019/3/12.
//

import Foundation
import Vapor
import Fluent
import FluentMySQL

public struct User: Content, MySQLModel {
    public var id: Int?

    public let userId: Int
    public let name: String?
    public let email: String?
    public var authorizationDate: Date
    public var recentlyReceivedDate: Date?

    public init(userId: Int, name: String? = nil, email: String? = nil, authorizationDate: Date = Date(), collectionDate: Date? = nil) {
        self.userId = userId
        self.name = name
        self.email = email
        self.authorizationDate = authorizationDate
        self.recentlyReceivedDate = collectionDate
    }
}

extension User: Migration {
    public static func prepare(on connection: MySQLConnection) -> Future<Void> {
        return Database.create(User.self, on: connection) {
            builder in
            try addProperties(to: builder)
        }
    }

    public static func revert(on connection: MySQLConnection) -> Future<Void> {
        return Database.delete(User.self, on: connection)
    }
}
