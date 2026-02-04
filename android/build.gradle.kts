buildscript {
    repositories {
        google()
        mavenCentral()
    }
    dependencies {
        // Estas líneas cargan los plugins "a la antigua", lo que evita los conflictos de versiones que tienes
        classpath("com.android.tools.build:gradle:8.10.1")
        classpath("org.jetbrains.kotlin:kotlin-gradle-plugin:2.2.20")
        classpath("com.google.gms:google-services:4.4.1")
    }
}

allprojects {
    repositories {
        google()
        mavenCentral()
    }
}

rootProject.buildDir = layout.buildDirectory.asFile.get()

subprojects {
    project.buildDir = layout.buildDirectory.asFile.get().resolve(project.name)
}
subprojects {
    project.evaluationDependsOn(":app")
}

tasks.register<Delete>("clean") {
    delete(rootProject.buildDir)
}