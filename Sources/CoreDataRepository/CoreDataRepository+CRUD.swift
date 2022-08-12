// CoreDataRepository+CRUD.swift
// CoreDataRepository
//
//
// MIT License
//
// Copyright © 2022 Andrew Roan

import Combine
import CoreData

extension CoreDataRepository {
    // MARK: Functions/Endpoints

    /// Create an instance of a NSManagedObject sub class from a corresponding value type.
    /// Supports specifying a transactionAuthor that is applied to the context before saving.
    /// - Types
    ///     - Model: UnmanagedModel
    /// - Parameters
    ///     -   _ item: Model
    ///     - transactionAuthor: String? = nil
    /// - Returns
    ///     - AnyPublisher<Model, CoreDataRepositoryError>
    ///
    public func create<Model: UnmanagedModel>(
        _ item: Model,
        transactionAuthor: String? = nil
    ) -> AnyPublisher<Model, CoreDataRepositoryError> {
        Future { [context] promise in
            context.performInScratchPad(promise: promise) { scratchPad in
                scratchPad.transactionAuthor = transactionAuthor
                let object = Model.RepoManaged(context: scratchPad)
                object.create(from: item)
                let result: Result<NSManagedObject, Error> = .success(object)
                return result
                    .map(to: Model.RepoManaged.self)
                    .save(context: scratchPad)
                    .map(\.asUnmanaged)
                    .mapToRepoError()
            }
        }.eraseToAnyPublisher()
    }

    public func create<Model: UnmanagedModel>(_ item: Model, transactionAuthor: String? = nil) async -> Result<Model, CoreDataRepositoryError> {
        await context.performInScratchPad { scratchPad in
            scratchPad.transactionAuthor = transactionAuthor
            let object = Model.RepoManaged(context: scratchPad)
            object.create(from: item)
            try scratchPad.save()
            return object.asUnmanaged
        }
    }

    /// Read an instance of a NSManagedObject sub class as a corresponding value type
    /// - Types
    ///     - Model: UnmanagedModel
    /// - Parameters
    ///     -   _ objectID: NSManagedObjectID
    /// - Returns
    ///     - AnyPublisher<Model, CoreDataRepositoryError>
    ///
    public func read<Model: UnmanagedModel>(_ url: URL) -> AnyPublisher<Model, CoreDataRepositoryError> {
        let readContext = context.childContext()
        return Future { promise in
            readContext.perform {
                promise(
                    readContext.objectId(from: url)
                        .mapToNSManagedObject(context: readContext)
                        .map(to: Model.RepoManaged.self)
                        .map(\.asUnmanaged)
                        .mapToRepoError()
                )
            }
        }.eraseToAnyPublisher()
    }

    public func read<Model: UnmanagedModel>(_ url: URL) async -> Result<Model, CoreDataRepositoryError> {
        await context.performInChild { readContext in
            let id = try readContext.tryObjectId(from: url)
            let object = try readContext.notDeletedObject(for: id)
            let repoManaged: Model.RepoManaged = try object.asRepoManaged()
            return repoManaged.asUnmanaged
        }
    }

    /// Update an instance of a NSManagedObject sub class from a corresponding value type.
    /// Supports specifying a transactionAuthor that is applied to the context before saving.
    /// - Types
    ///     - Model: UnmanagedModel
    /// - Parameters
    ///     - objectID: NSManagedObjectID
    ///     - with  item: Model
    ///     - transactionAuthor: String? = nil
    /// - Returns
    ///     - AnyPublisher<Model, CoreDataRepositoryError>
    ///
    public func update<Model: UnmanagedModel>(
        _ url: URL,
        with item: Model,
        transactionAuthor: String? = nil
    ) -> AnyPublisher<Model, CoreDataRepositoryError> {
        Future { [context] promise in
            context.performInScratchPad(promise: promise) { scratchPad in
                scratchPad.transactionAuthor = transactionAuthor
                return scratchPad.objectId(from: url)
                    .mapToNSManagedObject(context: scratchPad)
                    .map(to: Model.RepoManaged.self)
                    .map { repoManaged -> Model.RepoManaged in
                        repoManaged.update(from: item)
                        return repoManaged
                    }
                    .save(context: scratchPad)
                    .map(\.asUnmanaged)
                    .mapToRepoError()
            }
        }.eraseToAnyPublisher()
    }

    public func update<Model: UnmanagedModel>(
        _ url: URL,
        with item: Model,
        transactionAuthor: String? = nil
    ) async -> Result<Model, CoreDataRepositoryError> {
        await context.performInScratchPad { scratchPad in
            let id = try scratchPad.tryObjectId(from: url)
            let object = try scratchPad.notDeletedObject(for: id)
            let repoManaged: Model.RepoManaged = try object.asRepoManaged()
            repoManaged.update(from: item)
            try scratchPad.save()
            return repoManaged.asUnmanaged
        }
    }

    /// Delete an instance of a NSManagedObject sub class. Supports specifying a
    /// transactionAuthor that is applied to the context before saving.
    /// - Types
    ///     - Model: UnmanagedModel
    /// - Parameters
    ///     - objectID: NSManagedObjectID
    ///     - transactionAuthor: String? = nil
    /// - Returns
    ///     - AnyPublisher<Void, CoreDataRepositoryError>
    ///
    public func delete(
        _ url: URL,
        transactionAuthor: String? = nil
    ) -> AnyPublisher<Void, CoreDataRepositoryError> {
        Future { [context] promise in
            context.performInScratchPad(promise: promise) { scratchPad in
                scratchPad.transactionAuthor = transactionAuthor
                return scratchPad.objectId(from: url)
                    .mapToNSManagedObject(context: scratchPad)
                    .map { repoManaged in
                        repoManaged.prepareForDeletion()
                        scratchPad.delete(repoManaged)
                        return ()
                    }
                    .save(context: scratchPad)
                    .mapToRepoError()
            }
        }.eraseToAnyPublisher()
    }

    public func delete(
        _ url: URL,
        transactionAuthor: String? = nil
    ) async -> Result<Void, CoreDataRepositoryError> {
        await context.performInScratchPad { scratchPad in
            let id = try scratchPad.tryObjectId(from: url)
            let object = try scratchPad.notDeletedObject(for: id)
            object.prepareForDeletion()
            scratchPad.delete(object)
            try scratchPad.save()
            return ()
        }
    }

    /// Subscribe to updates for an instance of a NSManagedObject subclass.
    /// - Parameter publisher: Pub<Model, Error>
    /// - Returns: AnyPublisher<Model, CoreDataRepositoryError>
    public func readSubscription<Model: UnmanagedModel>(_ url: URL) -> AnyPublisher<Model, CoreDataRepositoryError> {
        let readContext = context.childContext()
        let readPublisher: AnyPublisher<Model.RepoManaged, CoreDataRepositoryError> = readContext.objectId(from: url)
            .mapToNSManagedObject(context: readContext)
            .map(to: Model.RepoManaged.self)
            .mapToRepoError()
            .publisher
            .eraseToAnyPublisher()
        var subjectCancellable: AnyCancellable?
        return Publishers.Create<Model, CoreDataRepositoryError> { [weak self] subscriber in
            let subject = PassthroughSubject<Model, CoreDataRepositoryError>()
            subjectCancellable = subject.sink(receiveCompletion: subscriber.send, receiveValue: subscriber.send)

            let id = UUID()
            var subscription: SubscriptionProvider?
            self?.cancellables.insert(readPublisher.sink(
                receiveCompletion: { completion in
                    if case .failure = completion {
                        subject.send(completion: completion)
                    }
                },
                receiveValue: { repoManaged in
                    let subscriptionProvider = ReadSubscription(
                        id: id,
                        objectId: repoManaged.objectID,
                        context: readContext,
                        subject: subject
                    )
                    subscription = subscriptionProvider
                    subscriptionProvider.start()
                    if let _self = self,
                       let _subjectCancellable = subjectCancellable
                    {
                        _self.subscriptions.append(subscriptionProvider)
                        _self.cancellables.insert(_subjectCancellable)
                    } else {
                        subjectCancellable?.cancel()
                        subscription?.cancel()
                    }
                    subscriptionProvider.manualFetch()
                }
            ))
            return AnyCancellable {
                subscription?.cancel()
                self?.subscriptions.removeAll(where: { $0.id == id as AnyHashable })
            }
        }.eraseToAnyPublisher()
    }
}
