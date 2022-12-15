//
//  ConnectorProvider.swift
//  
//
//  Created by Francisco Gindre on 1/12/23.
//
import SQLite

protocol ConnectionProvider {
    func connection() throws -> Connection
    func close()
}
