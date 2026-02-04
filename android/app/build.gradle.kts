plugins {
    id("com.android.application")
    id("org.jetbrains.kotlin.android")
    id("dev.flutter.flutter-gradle-plugin")
    // El plugin de Google Services es vital para Firebase
    id("com.google.gms.google-services")
}

android {
    // 1. ESTO DEBE COINCIDIR CON TU ESTRUCTURA DE CARPETAS
    namespace = "com.tobben.nutri_ia"
    compileSdk = flutter.compileSdkVersion

    defaultConfig {
        // 2. ESTO DEBE COINCIDIR CON TU PROYECTO EN FIREBASE
        applicationId = "com.tobben.nutri_ia"
        minSdk = flutter.minSdkVersion
        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    kotlinOptions {
        jvmTarget = "17"
    }
}


flutter {
    source = "../.."
}

dependencies {
    implementation(platform("com.google.firebase:firebase-bom:33.8.0"))
    implementation("com.google.firebase:firebase-analytics")
    implementation("com.google.firebase:firebase-firestore")
    implementation("androidx.multidex:multidex:2.0.1")
}
