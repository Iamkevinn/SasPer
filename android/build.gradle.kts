// --- ESTE ES EL BLOQUE QUE FALTABA ---
buildscript {
    // Define una versión de Kotlin moderna y consistente para todo el proyecto
    val kotlinVersion by extra("2.2.21")
    
    repositories {
        google()
        mavenCentral()
    }
    dependencies {
        // Le decimos a Gradle cómo encontrar las herramientas para construir
        classpath("com.android.tools.build:gradle:8.13.0")
        classpath("org.jetbrains.kotlin:kotlin-gradle-plugin:$kotlinVersion")
        classpath("com.google.gms:google-services:4.4.4") // ¡La línea clave!
    }
}
// ------------------------------------

allprojects {
    repositories {
        google()
        mavenCentral()
    }
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
