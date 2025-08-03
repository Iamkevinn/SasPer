// --- ESTE ES EL BLOQUE QUE FALTABA ---
buildscript {
    // Define una versión de Kotlin moderna y consistente para todo el proyecto
    val kotlinVersion by extra("1.8.20")
    
    repositories {
        google()
        mavenCentral()
    }
    dependencies {
        // Le decimos a Gradle cómo encontrar las herramientas para construir
        classpath("com.android.tools.build:gradle:8.12.0")
        classpath("org.jetbrains.kotlin:kotlin-gradle-plugin:$kotlinVersion")
        classpath("com.google.gms:google-services:4.4.3") // ¡La línea clave!
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
