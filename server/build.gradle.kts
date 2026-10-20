plugins {
    kotlin("jvm")
    kotlin("plugin.spring")
    id("org.springframework.boot")
    // nativeCompile builds the image; the jar build is unchanged (wasichai ADR-068)
    id("org.graalvm.buildtools.native")
}

// every module but the assistant: wasichai-agent is not supported in a native image (ADR-068)
val starters = listOf("", "-views", "-forms", "-pages", "-workflow", "-automation", "-documents", "-gis", "-notifications", "-files")

dependencies {
    // the composite build substitutes ../wasichai for these coordinates
    implementation(platform("wasichai:wasichai-bom:1.2.0"))
    starters.forEach { implementation("wasichai:wasichai-spring-boot-starter$it:1.2.0") }
}

kotlin {
    jvmToolchain(25)
}

graalvmNative {
    binaries.named("main") {
        imageName.set("full-sample")
    }
}
