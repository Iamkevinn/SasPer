allprojects {
    repositories {
        google()
        mavenCentral()
    }
}

// Archivo: android/build.gradle.kts

plugins {
    // ... otros plugins que puedas tener ...
    id("com.android.application") version "8.7.3" apply false
    id("org.jetbrains.kotlin.android") version "2.1.0" apply false
    id("dev.flutter.flutter-gradle-plugin") apply false
    // DECLARA EL PLUGIN DE GOOGLE SERVICES AQUÍ
    id("com.google.gms.google-services") version "4.4.2" apply false // Usa una versión reciente y estable
}

val newBuildDir: Directory = rootProject.layout.buildDirectory.dir("../../build").get()
rootProject.layout.buildDirectory.value(newBuildDir)

subprojects {
    val newSubprojectBuildDir: Directory = newBuildDir.dir(project.name)
    project.layout.buildDirectory.value(newSubprojectBuildDir)
}
subprojects {
    project.evaluationDependsOn(":app")
}

tasks.register<Delete>("clean") {
    delete(rootProject.layout.buildDirectory)
}
