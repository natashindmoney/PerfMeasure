import XCTest
@testable import INDProfiler

final class DispatcherTests: XCTestCase {

    // MARK: - Helpers

    private func makeMockResult(name: String = "test") -> MeasurementResult {
        return MeasurementResult(
            name: name,
            category: "test",
            context: MeasurementContext(),
            metrics: MeasurementMetrics(
                duration: 0.1,
                memoryAtStart: 1000,
                memoryAtEnd: 2000
            )
        )
    }

    // MARK: - Tests

    func testAddAndDispatchToDestination() {
        let dispatcher = INDProfilerDispatcher()
        let mock = MockDestination(identifier: "d1")
        dispatcher.addDestination(mock)

        let result = makeMockResult()
        dispatcher.dispatch(result)

        // Give async dispatch time to complete
        let expectation = self.expectation(description: "dispatch")
        DispatchQueue.global().asyncAfter(deadline: .now() + 0.1) {
            expectation.fulfill()
        }
        wait(for: [expectation], timeout: 1.0)

        XCTAssertEqual(mock.count, 1)
        XCTAssertEqual(mock.lastResult?.name, "test")
    }

    func testDisabledDestinationNotCalled() {
        let dispatcher = INDProfilerDispatcher()
        let mock = MockDestination(identifier: "d2", isEnabled: false)
        dispatcher.addDestination(mock)

        dispatcher.dispatch(makeMockResult())

        let expectation = self.expectation(description: "dispatch")
        DispatchQueue.global().asyncAfter(deadline: .now() + 0.1) {
            expectation.fulfill()
        }
        wait(for: [expectation], timeout: 1.0)

        XCTAssertEqual(mock.count, 0)
    }

    func testSetDestinationEnabled() {
        let dispatcher = INDProfilerDispatcher()
        let mock = MockDestination(identifier: "d3", isEnabled: true)
        dispatcher.addDestination(mock)

        dispatcher.setDestinationEnabled("d3", enabled: false)

        // Allow barrier to complete
        let expectation = self.expectation(description: "barrier")
        DispatchQueue.global().asyncAfter(deadline: .now() + 0.1) {
            expectation.fulfill()
        }
        wait(for: [expectation], timeout: 1.0)

        dispatcher.dispatch(makeMockResult())

        let expectation2 = self.expectation(description: "dispatch")
        DispatchQueue.global().asyncAfter(deadline: .now() + 0.1) {
            expectation2.fulfill()
        }
        wait(for: [expectation2], timeout: 1.0)

        XCTAssertEqual(mock.count, 0)
    }

    func testRemoveDestination() {
        let dispatcher = INDProfilerDispatcher()
        let mock = MockDestination(identifier: "d4")
        dispatcher.addDestination(mock)

        dispatcher.removeDestination(identifier: "d4")

        // Allow barrier to complete
        let expectation = self.expectation(description: "remove")
        DispatchQueue.global().asyncAfter(deadline: .now() + 0.1) {
            expectation.fulfill()
        }
        wait(for: [expectation], timeout: 1.0)

        dispatcher.dispatch(makeMockResult())

        let expectation2 = self.expectation(description: "dispatch")
        DispatchQueue.global().asyncAfter(deadline: .now() + 0.1) {
            expectation2.fulfill()
        }
        wait(for: [expectation2], timeout: 1.0)

        XCTAssertEqual(mock.count, 0)
    }

    func testMultipleDestinationsReceiveDispatch() {
        let dispatcher = INDProfilerDispatcher()
        let mock1 = MockDestination(identifier: "m1")
        let mock2 = MockDestination(identifier: "m2")
        dispatcher.addDestination(mock1)
        dispatcher.addDestination(mock2)

        dispatcher.dispatch(makeMockResult())

        let expectation = self.expectation(description: "dispatch")
        DispatchQueue.global().asyncAfter(deadline: .now() + 0.1) {
            expectation.fulfill()
        }
        wait(for: [expectation], timeout: 1.0)

        XCTAssertEqual(mock1.count, 1)
        XCTAssertEqual(mock2.count, 1)
    }

    func testAllDestinations() {
        let dispatcher = INDProfilerDispatcher()
        let mock1 = MockDestination(identifier: "a1")
        let mock2 = MockDestination(identifier: "a2")
        dispatcher.addDestination(mock1)
        dispatcher.addDestination(mock2)

        // Allow barrier writes to complete
        let expectation = self.expectation(description: "add")
        DispatchQueue.global().asyncAfter(deadline: .now() + 0.1) {
            expectation.fulfill()
        }
        wait(for: [expectation], timeout: 1.0)

        let all = dispatcher.allDestinations()
        XCTAssertEqual(all.count, 2)
    }
}
