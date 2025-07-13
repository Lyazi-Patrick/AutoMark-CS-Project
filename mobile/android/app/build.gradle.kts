
plugins {
    id("com.android.application") 
    id("org.jetbrains.kotlin.android") version "1.8.22" 
    id("dev.flutter.flutter-gradle-plugin") // Must come after Android + Kotlin
    id("com.google.gms.google-services") // For Firebase
}

android {
    namespace = "com.patrick.automark"
    compileSdk = 35
    ndkVersion = "27.0.12077973"

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_11
        targetCompatibility = JavaVersion.VERSION_11
    }

    defaultConfig {
        applicationId = "com.patrick.automark"
        minSdk = 23
        targetSdk = 35
        versionCode = 1
        versionName = "1.0.0"
        multiDexEnabled = true
    }

    buildTypes {
        release {
            isMinifyEnabled = false
            isShrinkResources = false
            signingConfig = signingConfigs.getByName("debug")
        }
    }
}

flutter {
    source = "../.."
}

dependencies {
    implementation("androidx.multidex:multidex:2.0.1")
    implementation("com.google.mlkit:text-recognition:16.0.0-beta3")
}

apply(plugin = "com.google.gms.google-services")

tasks.withType<org.jetbrains.kotlin.gradle.tasks.KotlinCompile>().configureEach {
    kotlinOptions {
        jvmTarget = "11"
    }
}
