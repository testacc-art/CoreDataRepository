// BatchRepositoryTests.swift
// CoreDataRepository
//
//
// MIT License
//
// Copyright © 2022 Andrew Roan

import Combine
import CoreData
import CoreDataRepository
import CustomDump
import XCTest

final class BatchRepositoryTests: CoreDataXCTestCase {
    static var allTests = [
        ("testInsertSuccess", testInsertSuccess),
        ("testInsertFailure", testInsertFailure),
        ("testCreateSuccess", testCreateSuccess),
        ("testReadSuccess", testReadSuccess),
        ("testUpdateSuccess", testUpdateSuccess),
        ("testAltUpdateSuccess", testAltUpdateSuccess),
        ("testDeleteSuccess", testDeleteSuccess),
        ("testAltDeleteSuccess", testAltDeleteSuccess),
    ]

    let movies: [[String: Any]] = [
        ["id": UUID(), "title": "A", "releaseDate": Date()],
        ["id": UUID(), "title": "B", "releaseDate": Date()],
        ["id": UUID(), "title": "C", "releaseDate": Date()],
        ["id": UUID(), "title": "D", "releaseDate": Date()],
        ["id": UUID(), "title": "E", "releaseDate": Date()],
    ]
    let failureInsertMovies: [[String: Any]] = [
        ["id": "A", "title": 1, "releaseDate": "A"],
        ["id": "B", "title": 2, "releaseDate": "B"],
        ["id": "C", "title": 3, "releaseDate": "C"],
        ["id": "D", "title": 4, "releaseDate": "D"],
        ["id": "E", "title": 5, "releaseDate": "E"],
    ]
    let failureCreateMovies: [[String: Any]] = {
        let id = UUID()
        return [
            ["id": id, "title": "A", "releaseDate": Date()],
            ["id": id, "title": "B", "releaseDate": Date()],
            ["id": id, "title": "C", "releaseDate": Date()],
            ["id": id, "title": "D", "releaseDate": Date()],
            ["id": id, "title": "E", "releaseDate": Date()],
        ]
    }()

    var _repository: CoreDataRepository?
    var repository: CoreDataRepository { _repository! }

    override func setUp() {
        super.setUp()
        _repository = CoreDataRepository(context: viewContext)
    }

    override func tearDown() {
        super.tearDown()
        _repository = nil
    }

    func mapDictToRepoMovie(_ dict: [String: Any]) throws -> RepoMovie {
        try mapDictToMovie(dict)
            .asRepoManaged(in: viewContext)
    }

    func mapDictToMovie(_ dict: [String: Any]) throws -> Movie {
        let id = try XCTUnwrap(dict["id"] as? UUID)
        let title = try XCTUnwrap(dict["title"] as? String)
        let releaseDate = try XCTUnwrap(dict["releaseDate"] as? Date)
        return Movie(id: id, title: title, releaseDate: releaseDate)
    }

    func testInsertSuccess() throws {
        let fetchRequest = NSFetchRequest<RepoMovie>(entityName: "RepoMovie")
        let count = try viewContext.count(for: fetchRequest)
        XCTAssert(count == 0, "Count of objects in CoreData should be zero at the start of each test.")

        let exp = expectation(description: "Successfully batch insert movies.")
        let request = NSBatchInsertRequest(entityName: try XCTUnwrap(RepoMovie.entity().name), objects: movies)
        repository.insert(request)
            .subscribe(on: backgroundQueue)
            .receive(on: mainQueue)
            .sink(
                receiveCompletion: { completion in
                    switch completion {
                    case .finished:
                        break
                    case .failure:
                        XCTFail("Not expecting failure")
                        exp.fulfill()
                    }
                },
                receiveValue: { _ in
                    exp.fulfill()
                }
            )
            .store(in: &cancellables)
        wait(for: [exp], timeout: 5)

        let data = try viewContext.fetch(fetchRequest)
        XCTAssert(
            data.map { $0.title ?? "" }.sorted() == ["A", "B", "C", "D", "E"],
            "Inserted titles should match expectation"
        )
    }

    func testInsertAsyncSuccess() async throws {
        let fetchRequest = NSFetchRequest<RepoMovie>(entityName: "RepoMovie")
        try await viewContext.perform {
            let count = try self.viewContext.count(for: fetchRequest)
            XCTAssert(count == 0, "Count of objects in CoreData should be zero at the start of each test.")
        }

        let request = NSBatchInsertRequest(entityName: try XCTUnwrap(RepoMovie.entity().name), objects: movies)
        let result: Result<NSBatchInsertResult, CoreDataRepositoryError> = await repository.insert(request)

        switch result {
        case .success:
            XCTAssert(true)
        case .failure:
            XCTFail("Not expecting a failure result")
        }

        try await viewContext.perform {
            let data = try self.viewContext.fetch(fetchRequest)
            XCTAssert(
                data.map { $0.title ?? "" }.sorted() == ["A", "B", "C", "D", "E"],
                "Inserted titles should match expectation"
            )
        }
        
    }

    func testInsertFailure() throws {
        let fetchRequest = NSFetchRequest<RepoMovie>(entityName: "RepoMovie")
        let count = try viewContext.count(for: fetchRequest)
        XCTAssert(count == 0, "Count of objects in CoreData should be zero at the start of each test.")

        let exp = expectation(description: "Fail to batch insert movies.")
        let request = NSBatchInsertRequest(
            entityName: try XCTUnwrap(RepoMovie.entity().name),
            objects: failureInsertMovies
        )
        repository.insert(request)
            .subscribe(on: backgroundQueue)
            .receive(on: mainQueue)
            .sink(
                receiveCompletion: { completion in
                    switch completion {
                    case .failure:
                        exp.fulfill()
                    case .finished:
                        XCTFail("Not expecting success")
                        exp.fulfill()
                    }
                },
                receiveValue: { _ in }
            )
            .store(in: &cancellables)
        wait(for: [exp], timeout: 5)

        let data = try viewContext.fetch(fetchRequest)
        XCTAssert(data.map { $0.title ?? "" }.sorted() == [], "There should be no inserted values.")
    }

    func testInsertAsyncFailure() async throws {
        let fetchRequest = NSFetchRequest<RepoMovie>(entityName: "RepoMovie")
        try await viewContext.perform {
            let count = try self.viewContext.count(for: fetchRequest)
            XCTAssert(count == 0, "Count of objects in CoreData should be zero at the start of each test.")
        }

        let request = NSBatchInsertRequest(entityName: try XCTUnwrap(RepoMovie.entity().name), objects: failureInsertMovies)
        let result: Result<NSBatchInsertResult, CoreDataRepositoryError> = await repository.insert(request)

        switch result {
        case .success:
            XCTFail("Not expecting a success result")
        case .failure:
            XCTAssert(true)
        }

        try await viewContext.perform {
            let data = try self.viewContext.fetch(fetchRequest)
            XCTAssert(data.map { $0.title ?? "" }.sorted() == [], "There should be no inserted values.")
        }
        
    }

    func testCreateSuccess() throws {
        let fetchRequest = NSFetchRequest<RepoMovie>(entityName: "RepoMovie")
        let count = try viewContext.count(for: fetchRequest)
        XCTAssert(count == 0, "Count of objects in CoreData should be zero at the start of each test.")

        let exp = expectation(description: "Successfully batch insert movies.")
        let newMovies = try movies.map(mapDictToMovie(_:))
        let publisher: AnyPublisher<(success: [Movie], failed: [Movie]), Never> = repository.create(newMovies)
        publisher
            .subscribe(on: backgroundQueue)
            .receive(on: mainQueue)
            .sink(
                receiveCompletion: { completion in
                    switch completion {
                    case .finished:
                        break
                    case .failure:
                        XCTFail("Not expecting failure")
                        exp.fulfill()
                    }
                },
                receiveValue: { _ in
                    exp.fulfill()
                }
            )
            .store(in: &cancellables)
        wait(for: [exp], timeout: 5)

        let data = try viewContext.fetch(fetchRequest)
        XCTAssert(
            data.map { $0.title ?? "" }.sorted() == ["A", "B", "C", "D", "E"],
            "Inserted titles should match expectation"
        )
    }

    func testCreateAsyncSuccess() async throws {
        let fetchRequest = NSFetchRequest<RepoMovie>(entityName: "RepoMovie")
        try await viewContext.perform {
            let count = try self.viewContext.count(for: fetchRequest)
            XCTAssert(count == 0, "Count of objects in CoreData should be zero at the start of each test.")
        }
        
        let newMovies = try movies.map(mapDictToMovie(_:))
        let result: (success: [Movie], failed: [Movie]) = await repository.create(newMovies)
        
        XCTAssertEqual(result.success.count, newMovies.count)
        XCTAssertEqual(result.failed.count, 0)

        try await viewContext.perform {
            let data = try self.viewContext.fetch(fetchRequest)
            XCTAssert(
                data.map { $0.title ?? "" }.sorted() == ["A", "B", "C", "D", "E"],
                "Inserted titles should match expectation"
            )
        }
    }

    func testReadSuccess() throws {
        let fetchRequest = NSFetchRequest<RepoMovie>(entityName: "RepoMovie")
        let count = try viewContext.count(for: fetchRequest)
        XCTAssert(count == 0, "Count of objects in CoreData should be zero at the start of each test.")

        let repoMovies = try movies
            .map(mapDictToRepoMovie(_:))
        try viewContext.save()

        let exp = expectation(description: "Successfully batch update movies.")
        let urlsToRead = repoMovies.map(\.asUnmanaged).compactMap(\.url)
        var resultingMovies = [Movie]()
        let publisher: AnyPublisher<(success: [Movie], failed: [URL]), Never> = repository.read(urls: urlsToRead)
        publisher
            .subscribe(on: backgroundQueue)
            .receive(on: mainQueue)
            .sink(
                receiveCompletion: { completion in
                    switch completion {
                    case .finished:
                        break
                    case .failure:
                        XCTFail("Not expecting Failure")
                        exp.fulfill()
                    }
                },
                receiveValue: { result in
                    XCTAssert(result.failed.isEmpty, "None should fail")
                    resultingMovies = result.success
                    exp.fulfill()
                }
            )
            .store(in: &cancellables)
        wait(for: [exp], timeout: 5)

        XCTAssert(Set(resultingMovies) == Set(repoMovies.map(\.asUnmanaged)), "")
    }

    func testReadAsyncSuccess() async throws {
        let fetchRequest = NSFetchRequest<RepoMovie>(entityName: "RepoMovie")
        var movies = [Movie]()
        try await viewContext.perform {
            let count = try self.viewContext.count(for: fetchRequest)
            XCTAssert(count == 0, "Count of objects in CoreData should be zero at the start of each test.")

            let repoMovies = try self.movies
                .map(self.mapDictToRepoMovie(_:))
            try self.viewContext.save()
            movies = repoMovies.map(\.asUnmanaged)
        }
        
        let result: (success: [Movie], failed: [URL]) = await repository.read(urls: movies.compactMap(\.url))
        
        XCTAssertEqual(result.success.count, movies.count)
        XCTAssertEqual(result.failed.count, 0)

        XCTAssert(Set(movies) == Set(result.success))
    }

    func testUpdateSuccess() throws {
        let fetchRequest = NSFetchRequest<RepoMovie>(entityName: "RepoMovie")
        let count = try viewContext.count(for: fetchRequest)
        XCTAssert(count == 0, "Count of objects in CoreData should be zero at the start of each test.")

        _ = try movies
            .map(mapDictToRepoMovie(_:))
        try viewContext.save()

        let exp = expectation(description: "Successfully batch update movies.")
        let predicate = NSPredicate(value: true)
        let request = NSBatchUpdateRequest(entityName: try XCTUnwrap(RepoMovie.entity().name))
        request.predicate = predicate
        request.propertiesToUpdate = ["title": "Updated!", "boxOffice": 1]
        repository.update(request)
            .subscribe(on: backgroundQueue)
            .receive(on: mainQueue)
            .sink(
                receiveCompletion: { completion in
                    switch completion {
                    case .finished:
                        break
                    case .failure:
                        XCTFail("Not expecting Failure")
                        exp.fulfill()
                    }
                },
                receiveValue: { _ in
                    exp.fulfill()
                }
            )
            .store(in: &cancellables)
        wait(for: [exp], timeout: 5)

        let data = try viewContext.fetch(fetchRequest)
        XCTAssert(
            data.map { $0.title ?? "" }.sorted() == ["Updated!", "Updated!", "Updated!", "Updated!", "Updated!"],
            "Updated titles should match request"
        )
    }

    func testUpdateAsyncSuccess() async throws {
        let fetchRequest = NSFetchRequest<RepoMovie>(entityName: "RepoMovie")
        try await viewContext.perform {
            let count = try self.viewContext.count(for: fetchRequest)
            XCTAssert(count == 0, "Count of objects in CoreData should be zero at the start of each test.")

            let _ = try self.movies
                .map(self.mapDictToRepoMovie(_:))
            try self.viewContext.save()
        }
        
        let predicate = NSPredicate(value: true)
        let request = NSBatchUpdateRequest(entityName: try XCTUnwrap(RepoMovie.entity().name))
        request.predicate = predicate
        request.propertiesToUpdate = ["title": "Updated!", "boxOffice": 1]
        
        let _: Result<NSBatchUpdateResult, CoreDataRepositoryError> = await repository.update(request)
        
        try await viewContext.perform {
            let data = try self.viewContext.fetch(fetchRequest)
            XCTAssert(
                data.map { $0.title ?? "" }.sorted() == ["Updated!", "Updated!", "Updated!", "Updated!", "Updated!"],
                "Updated titles should match request"
            )
        }
    }

    func testAltUpdateSuccess() throws {
        let fetchRequest = NSFetchRequest<RepoMovie>(entityName: "RepoMovie")
        let count = try viewContext.count(for: fetchRequest)
        XCTAssert(count == 0, "Count of objects in CoreData should be zero at the start of each test.")

        let repoMovies = try movies
            .map(mapDictToRepoMovie(_:))
        try viewContext.save()

        let exp = expectation(description: "Successfully batch update movies.")
        var editedMovies = repoMovies.map(\.asUnmanaged)
        let newTitles = ["ZA", "ZB", "ZC", "ZD", "ZE"]
        var resultingMovies = [Movie]()
        newTitles.enumerated().forEach { index, title in editedMovies[index].title = title }
        repository.update(editedMovies)
            .subscribe(on: backgroundQueue)
            .receive(on: mainQueue)
            .sink(
                receiveCompletion: { completion in
                    switch completion {
                    case .finished:
                        break
                    case .failure:
                        XCTFail("Not expecting Failure")
                        exp.fulfill()
                    }
                },
                receiveValue: { result in
                    XCTAssert(result.failed.isEmpty, "None should fail")
                    resultingMovies = result.success
                    exp.fulfill()
                }
            )
            .store(in: &cancellables)
        wait(for: [exp], timeout: 5)

        XCTAssert(Set(editedMovies) == Set(resultingMovies), "")
    }

    func testAltUpdateAsyncSuccess() async throws {
        let fetchRequest = NSFetchRequest<RepoMovie>(entityName: "RepoMovie")
        var movies = [Movie]()
        try await viewContext.perform {
            let count = try self.viewContext.count(for: fetchRequest)
            XCTAssert(count == 0, "Count of objects in CoreData should be zero at the start of each test.")

            let repoMovies = try self.movies
                .map(self.mapDictToRepoMovie(_:))
            try self.viewContext.save()
            movies = repoMovies.map(\.asUnmanaged)
        }
        
        var editedMovies = movies
        let newTitles = ["ZA", "ZB", "ZC", "ZD", "ZE"]
        newTitles.enumerated().forEach { index, title in editedMovies[index].title = title }
        
        let result: (success: [Movie], failed: [Movie]) = await repository.update(editedMovies)
        
        XCTAssertEqual(result.success.count, movies.count)
        XCTAssertEqual(result.failed.count, 0)

        XCTAssert(Set(editedMovies) == Set(result.success))
    }

    func testDeleteSuccess() throws {
        let fetchRequest = NSFetchRequest<RepoMovie>(entityName: "RepoMovie")
        let count = try viewContext.count(for: fetchRequest)
        XCTAssert(count == 0, "Count of objects in CoreData should be zero at the start of each test.")

        _ = try movies
            .map(mapDictToRepoMovie(_:))
        try viewContext.save()

        let exp = expectation(description: "Successfully batch delete movies.")
        let request =
            NSBatchDeleteRequest(fetchRequest: NSFetchRequest<NSFetchRequestResult>(entityName: try XCTUnwrap(
                RepoMovie
                    .entity().name
            )))
        repository.delete(request)
            .subscribe(on: backgroundQueue)
            .receive(on: mainQueue)
            .sink(
                receiveCompletion: { completion in
                    switch completion {
                    case .finished:
                        break
                    case .failure:
                        XCTFail("Not expecting failure")
                        exp.fulfill()
                    }
                },
                receiveValue: { _ in
                    exp.fulfill()
                }
            )
            .store(in: &cancellables)
        wait(for: [exp], timeout: 5)
        viewContext.reset()

        let data = try viewContext.fetch(fetchRequest)
        XCTAssert(data.map { $0.title ?? "" }.sorted() == [], "There should be no remaining values.")
    }

    func testDeleteAsyncSuccess() async throws {
        let fetchRequest = NSFetchRequest<RepoMovie>(entityName: "RepoMovie")
        try await viewContext.perform {
            let count = try self.viewContext.count(for: fetchRequest)
            XCTAssert(count == 0, "Count of objects in CoreData should be zero at the start of each test.")

            let _ = try self.movies
                .map(self.mapDictToRepoMovie(_:))
            try self.viewContext.save()
        }

        let request =
            NSBatchDeleteRequest(fetchRequest: NSFetchRequest<NSFetchRequestResult>(entityName: try XCTUnwrap(
                RepoMovie
                    .entity().name
            )))
        
        let _: Result<NSBatchDeleteResult, CoreDataRepositoryError> = await repository.delete(request)
        
        try await viewContext.perform {
            let data = try self.viewContext.fetch(fetchRequest)
            XCTAssert(data.map { $0.title ?? "" }.sorted() == [], "There should be no remaining values.")
        }
    }

    func testAltDeleteSuccess() throws {
        let fetchRequest = NSFetchRequest<RepoMovie>(entityName: "RepoMovie")
        let count = try viewContext.count(for: fetchRequest)
        XCTAssert(count == 0, "Count of objects in CoreData should be zero at the start of each test.")

        let repoMovies = try movies
            .map(mapDictToRepoMovie(_:))
        try viewContext.save()

        let exp = expectation(description: "Successfully batch update movies.")
        let urlsToDelete = repoMovies.map(\.asUnmanaged).compactMap(\.url)
        repository.delete(urls: urlsToDelete)
            .subscribe(on: backgroundQueue)
            .receive(on: mainQueue)
            .sink(
                receiveCompletion: { completion in
                    switch completion {
                    case .finished:
                        break
                    case .failure:
                        XCTFail("Not expecting Failure")
                        exp.fulfill()
                    }
                },
                receiveValue: { result in
                    XCTAssert(result.failed.isEmpty, "None should fail")
                    exp.fulfill()
                }
            )
            .store(in: &cancellables)
        wait(for: [exp], timeout: 5)

        let data = try viewContext.fetch(fetchRequest)
        XCTAssert(data.map { $0.title ?? "" }.sorted() == [], "There should be no remaining values.")
    }

    func testAltDeleteAsyncSuccess() async throws {
        let fetchRequest = NSFetchRequest<RepoMovie>(entityName: "RepoMovie")
        var movies = [Movie]()
        try await viewContext.perform {
            let count = try self.viewContext.count(for: fetchRequest)
            XCTAssert(count == 0, "Count of objects in CoreData should be zero at the start of each test.")

            let repoMovies = try self.movies
                .map(self.mapDictToRepoMovie(_:))
            try self.viewContext.save()
            movies = repoMovies.map(\.asUnmanaged)
        }
        
        let result: (success: [URL], failed: [URL]) = await repository.delete(urls: movies.compactMap(\.url))
        
        XCTAssertEqual(result.success.count, movies.count)
        XCTAssertEqual(result.failed.count, 0)

        try await viewContext.perform {
            let data = try self.viewContext.fetch(fetchRequest)
            XCTAssert(data.map { $0.title ?? "" }.sorted() == [], "There should be no remaining values.")
        }
    }
}
