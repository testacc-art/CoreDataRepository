//
//  File.swift
//  
//
//  Created by andrew on 8/12/22.
//

import Foundation
import CoreData

extension NSManagedObject {
    func asRepoManaged<T>() throws -> T where T: RepositoryManagedModel {
        guard let repoManaged = self as? T else {
            throw CoreDataRepositoryError.fetchedObjectFailedToCastToExpectedType
        }
        return repoManaged
    }
}
