plugins {
    id("com.android.application")
    id("kotlin-android")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
    // Add the dependency for the Google services Gradle plugin
    id("com.google.gms.google-services")
}

android {
    namespace = "com.example.sasper"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = "27.0.12077973"

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_11
        targetCompatibility = JavaVersion.VERSION_11
    }

    kotlinOptions {
        jvmTarget = JavaVersion.VERSION_11.toString()
    }

    defaultConfig {
        // TODO: Specify your own unique Application ID (https://developer.android.com/studio/build/application-id.html).
        applicationId = "com.example.sasper"
        // You can update the following values to match your application needs.
        // For more information, see: https://flutter.dev/to/review-gradle-config.
        minSdk = 23
        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }

    buildTypes {
        release {
            // TODO: Add your own signing config for the release build.
            // Signing with the debug keys for now, so `flutter run --release` works.
            signingConfig = signingConfigs.getByName("debug")
        }
    }
}

flutter {
    source = "../.."
}

dependencies {
    // This line was probably fine, but let's make it consistent.
    // The "$kotlin_version" might need to be accessed differently in .kts files
    // but flutterfire usually handles this. If it fails, we'll fix it.
    // LÍNEA CORRECTA
    implementation("org.jetbrains.kotlin:kotlin-stdlib-jdk7:2.1.0")

    // This line was already correct! It uses the function call syntax.
    implementation(platform("com.google.firebase:firebase-bom:33.1.2"))

    // CORRECTED: Add parentheses to each Firebase dependency
    implementation("com.google.firebase:firebase-analytics")
    implementation("com.google.firebase:firebase-auth")
    implementation("com.google.firebase:firebase-firestore")
    // ... add any other Firebase services you need using the same syntax
}