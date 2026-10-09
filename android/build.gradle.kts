import com.android.build.gradle.LibraryExtension

allprojects {
    repositories {
        google()
        mavenCentral()
    }
}

val newBuildDir: Directory =
    rootProject.layout.buildDirectory
        .dir("../../build")
        .get()
rootProject.layout.buildDirectory.value(newBuildDir)

subprojects {
    val newSubprojectBuildDir: Directory = newBuildDir.dir(project.name)
    project.layout.buildDirectory.value(newSubprojectBuildDir)
    // Plugin sources may live in the Pub cache on a different drive.
    // Keep native build staging files alongside this project instead.
    pluginManager.withPlugin("com.android.library") {
        extensions.configure<LibraryExtension> {
            externalNativeBuild.cmake.buildStagingDirectory =
                rootProject.file("../.native-build/${project.name}")
        }
    }
}
subprojects {
    project.evaluationDependsOn(":app")
}

tasks.register<Delete>("clean") {
    delete(rootProject.layout.buildDirectory)
}
