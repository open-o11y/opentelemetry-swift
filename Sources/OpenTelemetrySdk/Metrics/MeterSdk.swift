/*
 * Copyright The OpenTelemetry Authors
 * SPDX-License-Identifier: Apache-2.0
 */

import Foundation
import OpenTelemetryApi

class MeterSdk: Meter {
    fileprivate let collectLock = Lock()
    let meterName: String
    var metricProcessor: MetricProcessor
    var instrumentationLibraryInfo : InstrumentationLibraryInfo
    var resource: Resource

    var intCounters = [String: CounterMetricSdk<Int>]()
    var doubleCounters = [String: CounterMetricSdk<Double>]()
    var intMeasures = [String: MeasureMetricSdk<Int>]()
    var doubleMeasures = [String: MeasureMetricSdk<Double>]()
    var intObservers = [String: IntObserverMetricSdk]()
    var doubleObservers = [String: DoubleObserverMetricSdk]()

    init(meterSharedState: MeterSharedState, instrumentationLibraryInfo: InstrumentationLibraryInfo) {
        self.meterName = instrumentationLibraryInfo.name
        self.resource = meterSharedState.resource
        self.metricProcessor = meterSharedState.metricProcessor
        self.instrumentationLibraryInfo  = instrumentationLibraryInfo
    }

    func getLabelSet(labels: [String: String]) -> LabelSet {
        return LabelSetSdk(labels: labels)
    }

    func collect() {
        collectLock.withLockVoid {
            var boundInstrumentsToRemove = [LabelSet]()

            intCounters.forEach { counter in
                let metricName = counter.key
                let counterInstrument = counter.value

                var metric = Metric(namespace: meterName, name: metricName, desc: meterName + metricName, type: AggregationType.intSum, resource: resource, instrumentationLibraryInfo: instrumentationLibraryInfo)

                counterInstrument.boundInstruments.forEach { boundInstrument in
                    let labelSet = boundInstrument.key
                    let aggregator = boundInstrument.value.getAggregator()
                    aggregator.checkpoint()

                    var metricData = aggregator.toMetricData()
                    metricData.labels = labelSet.labels
                    metric.data.append(metricData)
                    boundInstrument.value.statusLock.withLockVoid {
                        switch boundInstrument.value.status {
                        case .updatePending:
                            boundInstrument.value.status = .noPendingUpdate
                        case .noPendingUpdate:
                            boundInstrument.value.status = .candidateForRemoval
                        case .candidateForRemoval:
                            boundInstrumentsToRemove.append(labelSet)
                        case .bound:
                            break
                        }
                    }
                }

                metricProcessor.process(metric: metric)
                boundInstrumentsToRemove.forEach { boundInstrument in
                    counterInstrument.unBind(labelSet: boundInstrument)
                }
                boundInstrumentsToRemove.removeAll()
            }

            doubleCounters.forEach { counter in
                let metricName = counter.key
                let counterInstrument = counter.value

                var metric = Metric(namespace: meterName, name: metricName, desc: meterName + metricName, type: AggregationType.doubleSum, resource: resource, instrumentationLibraryInfo: instrumentationLibraryInfo)

                counterInstrument.boundInstruments.forEach { boundInstrument in
                    let labelSet = boundInstrument.key
                    let aggregator = boundInstrument.value.getAggregator()
                    aggregator.checkpoint()

                    var metricData = aggregator.toMetricData()
                    metricData.labels = labelSet.labels
                    metric.data.append(metricData)

                    boundInstrument.value.statusLock.withLockVoid {
                        switch boundInstrument.value.status {
                        case .updatePending:
                            boundInstrument.value.status = .noPendingUpdate
                        case .noPendingUpdate:
                            boundInstrument.value.status = .candidateForRemoval
                        case .candidateForRemoval:
                            boundInstrumentsToRemove.append(labelSet)
                        case .bound:
                            break
                        }
                    }
                }

                metricProcessor.process(metric: metric)
                boundInstrumentsToRemove.forEach { boundInstrument in
                    counterInstrument.unBind(labelSet: boundInstrument)
                }
                boundInstrumentsToRemove.removeAll()
            }

            intMeasures.forEach { measure in
                let metricName = measure.key
                let measureInstrument = measure.value
            var metric = Metric(namespace: meterName, name: metricName, desc: meterName + metricName, type: AggregationType.intSummary, resource: resource, instrumentationLibraryInfo: instrumentationLibraryInfo)
                measureInstrument.boundInstruments.forEach { boundInstrument in
                    let labelSet = boundInstrument.key
                    let aggregator = boundInstrument.value.getAggregator()
                    aggregator.checkpoint()
                    var metricData = aggregator.toMetricData()
                    metricData.labels = labelSet.labels
                    metric.data.append(metricData)
                }
                metricProcessor.process(metric: metric)
            }

            doubleMeasures.forEach { measure in
                let metricName = measure.key
                let measureInstrument = measure.value
                var metric = Metric(namespace: meterName, name: metricName, desc: meterName + metricName, type: AggregationType.doubleSummary, resource: resource, instrumentationLibraryInfo: instrumentationLibraryInfo)
                measureInstrument.boundInstruments.forEach { boundInstrument in
                    let labelSet = boundInstrument.key
                    let aggregator = boundInstrument.value.getAggregator()
                    aggregator.checkpoint()
                    var metricData = aggregator.toMetricData()
                    metricData.labels = labelSet.labels
                    metric.data.append(metricData)
                }
                metricProcessor.process(metric: metric)
            }

            intObservers.forEach { observer in
                let metricName = observer.key
                let observerInstrument = observer.value
                var metric = Metric(namespace: meterName, name: metricName, desc: meterName + metricName, type: AggregationType.intSum, resource: resource, instrumentationLibraryInfo: instrumentationLibraryInfo)
                observerInstrument.invokeCallback()

                observerInstrument.observerHandles.forEach { handle in
                    let labelSet = handle.key
                    let aggregator = handle.value.aggregator
                    aggregator.checkpoint()
                    var metricData = aggregator.toMetricData()
                    metricData.labels = labelSet.labels
                    metric.data.append(metricData)
                }
                metricProcessor.process(metric: metric)
            }

            doubleObservers.forEach { observer in
                let metricName = observer.key
                let observerInstrument = observer.value
                var metric = Metric(namespace: meterName, name: metricName, desc: meterName + metricName, type: AggregationType.doubleSum, resource: resource, instrumentationLibraryInfo: instrumentationLibraryInfo)
                observerInstrument.invokeCallback()

                observerInstrument.observerHandles.forEach { handle in
                    let labelSet = handle.key
                    let aggregator = handle.value.aggregator
                    aggregator.checkpoint()
                    var metricData = aggregator.toMetricData()
                    metricData.labels = labelSet.labels
                    metric.data.append(metricData)
                }

                metricProcessor.process(metric: metric)
            }
        }
    }

    func createIntCounter(name: String, monotonic: Bool) -> AnyCounterMetric<Int> {
        var counter = intCounters[name]
        if counter == nil {
            counter = CounterMetricSdk<Int>(name: name)
            collectLock.withLockVoid {
                intCounters[name] = counter!
            }
        }
        return AnyCounterMetric<Int>(counter!)
    }

    func createDoubleCounter(name: String, monotonic: Bool) -> AnyCounterMetric<Double> {
        var counter = doubleCounters[name]
        if counter == nil {
            counter = CounterMetricSdk<Double>(name: name)
            collectLock.withLockVoid {
                doubleCounters[name] = counter!
            }
        }
        return AnyCounterMetric<Double>(counter!)
    }

    func createIntMeasure(name: String, absolute: Bool) -> AnyMeasureMetric<Int> {
        var measure = intMeasures[name]
        if measure == nil {
            measure = MeasureMetricSdk<Int>(name: name)
            collectLock.withLockVoid {
                intMeasures[name] = measure!
            }
        }
        return AnyMeasureMetric<Int>(measure!)
    }

    func createDoubleMeasure(name: String, absolute: Bool) -> AnyMeasureMetric<Double> {
        var measure = doubleMeasures[name]
        if measure == nil {
            measure = MeasureMetricSdk<Double>(name: name)
            collectLock.withLockVoid {
                doubleMeasures[name] = measure
            }
        }
        return AnyMeasureMetric<Double>(measure!)
    }

    func createIntObserver(name: String, absolute: Bool, callback: @escaping (IntObserverMetric) -> Void) -> IntObserverMetric {
        var observer = intObservers[name]
        if observer == nil {
            observer = IntObserverMetricSdk(metricName: name, callback: callback)
            collectLock.withLockVoid {
                intObservers[name] = observer!
            }
        }
        return observer!
    }

    func createDoubleObserver(name: String, absolute: Bool, callback: @escaping (DoubleObserverMetric) -> Void) -> DoubleObserverMetric {
        var observer = doubleObservers[name]
        if observer == nil {
            observer = DoubleObserverMetricSdk(metricName: name, callback: callback)
            collectLock.withLockVoid {
                doubleObservers[name] = observer!
            }
        }
        return observer!
    }
}
