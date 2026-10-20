package io.wasichai.fullsample

import org.springframework.boot.runApplication
import wasichai.core.autoconfigure.WasichaiApplication

// outside package wasichai: the app's scan must not reach the library (ADR-024)
@WasichaiApplication
class FullSampleApp

fun main(args: Array<String>) {
    runApplication<FullSampleApp>(*args)
}
