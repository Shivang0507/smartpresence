plugins {
    id("com.google.gms.google-services") version "4.4.4" apply false
}

fun rootOf(file: File): String =
    file.canonicalFile.toPath().root?.toString()?.lowercase() ?: ""

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
    val projectRoot = rootOf(project.projectDir)
    val androidRoot = rootOf(rootProject.projectDir)

    if (projectRoot == androidRoot) {
        val newSubprojectBuildDir: Directory = newBuildDir.dir(project.name)
        project.layout.buildDirectory.value(newSubprojectBuildDir)
    } else {
        project.layout.buildDirectory.value(project.layout.projectDirectory.dir("build"))
    }
}
subprojects {
    project.evaluationDependsOn(":app")
}

tasks.register<Delete>("clean") {
    delete(rootProject.layout.buildDirectory)
}
