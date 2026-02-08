plugins {
    id("com.android.application")
    id("org.jetbrains.kotlin.android")
    id("dev.flutter.flutter-gradle-plugin")
    id("com.google.gms.google-services")
}

android {
    namespace = "com.tobben.nutri_ia"

    // ✅ CORRECCIÓN 1: Forzar SDK 36 (Soluciona el error rojo de Build Failed)
    compileSdk = 36
    ndkVersion = "27.0.12077973"

    defaultConfig {
        applicationId = "com.tobben.nutri_ia"
        minSdk = flutter.minSdkVersion
        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName

        // ✅ CORRECCIÓN 2: Multidex activo para Firebase
        multiDexEnabled = true
    }

    buildTypes {
        release {
            signingConfig = signingConfigs.getByName("debug")
            isMinifyEnabled = false
            isShrinkResources = false
        }
    }

    compileOptions {
        // ✅ CORRECCIÓN 3: Habilitar Desugaring para notificaciones
        isCoreLibraryDesugaringEnabled = true

        // ✅ CORRECCIÓN 4: Usar Java 17 elimina warnings de versiones viejas
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
    // Librería para que las notificaciones funcionen en Android viejos
    coreLibraryDesugaring("com.android.tools:desugar_jdk_libs:2.0.4")

    implementation(platform("com.google.firebase:firebase-bom:32.7.2"))
    implementation("com.google.firebase:firebase-analytics")
    implementation("com.google.firebase:firebase-firestore")
    implementation("androidx.multidex:multidex:2.0.1")
}

// ✅ CORRECCIÓN 5: BLOQUE DE LIMPIEZA (ELIMINA LOS WARNINGS)
// Esto le dice al compilador: "No me avises de opciones obsoletas ni de APIs depreciadas"
tasks.withType<JavaCompile>().configureEach {
    options.compilerArgs.add("-Xlint:-options")
    options.compilerArgs.add("-Xlint:-deprecation")
}
