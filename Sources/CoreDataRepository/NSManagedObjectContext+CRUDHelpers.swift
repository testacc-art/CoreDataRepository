//
//  File.swift
//  
//
//  Created by andrew on 8/12/22.
//

import Foundation
import CoreData

extension NSManagedObjectContext {
    func tryObjectId(from url: URL) throws -> NSManagedObjectID {
        guard let objectId = persistentStoreCoordinator?.managedObjectID(forURIRepresentation: url) else {
            throw CoreDataRepositoryError.failedToGetObjectIdFromUrl(url)
        }
        return objectId
    }

    func objectId(from url: URL) -> Result<NSManagedObjectID, Error> {
        Result {
            try tryObjectId(from: url)
        }
    }

    func notDeletedObject(for id: NSManagedObjectID) throws -> NSManagedObject {
        let object: NSManagedObject = try existingObject(with: id)
        guard !object.isDeleted else {
            throw CoreDataRepositoryError.fetchedObjectIsFlaggedAsDeleted
        }
        return object
    }
}
