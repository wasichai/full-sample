rootProject.name = "full-sample"

dependencyResolutionManagement {
    repositories {
        mavenCentral()
    }
}

// wasichai cloned next to this repository: build against it, not a published version
includeBuild("../wasichai")

include("server")
