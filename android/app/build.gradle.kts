// android/app/build.gradle.kts

plugins {
    id("com.android.application")
    id("org.jetbrains.kotlin.android")
    id("com.google.gms.google-services")
    id("dev.flutter.flutter-gradle-plugin")
}

val kotlinVersion: String by rootProject.extra // Obtenemos la versión de kotlin del settings.gradle.kts o build.gradle.kts raíz

android {
    namespace = "com.example.sasper"
    compileSdk = 36

    compileOptions {
        isCoreLibraryDesugaringEnabled = true
        sourceCompatibility = JavaVersion.VERSION_1_8
        targetCompatibility = JavaVersion.VERSION_1_8
    }

    kotlinOptions {
        jvmTarget = "1.8"
    }

    defaultConfig {
        applicationId = "com.example.sasper"
        minSdk = 21
        targetSdk = 34
        versionCode = 1
        versionName = "1.0.0"
    }

    buildTypes {
        release {
            signingConfig = signingConfigs.getByName("debug")
        }
    }
}

flutter {
    source = "../.."
}

dependencies {
    // Tus dependencias existentes
    implementation("org.jetbrains.kotlin:kotlin-stdlib-jdk7:$kotlinVersion")
    coreLibraryDesugaring("com.android.tools:desugar_jdk_libs:2.1.5")
    implementation("com.google.code.gson:gson:2.13.1")

    // ===================================================================
    //  AÑADE ESTE BLOQUE COMPLETO PARA ARREGLAR FIREBASE
    // ===================================================================
    // Importa el Firebase BoM (Bill of Materials)
    // Esto asegura que todas tus dependencias de Firebase usen la misma versión compatible.
    implementation(platform("com.google.firebase:firebase-bom:33.2.0"))

    // Ahora, declara las dependencias para los productos de Firebase que usas.
    // El BoM se encargará de gestionar sus versiones automáticamente.
    implementation("com.google.firebase:firebase-analytics")
    implementation("com.google.firebase:firebase-messaging")
    // ===================================================================
}