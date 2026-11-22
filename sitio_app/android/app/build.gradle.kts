plugins {
    id("com.android.application")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
    id("com.google.gms.google-services")
}

android {
    namespace = "com.tocadoscoelhos.sitio.equipe"
    ndkVersion = flutter.ndkVersion
    compileSdk = 36


    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }


    defaultConfig {
        applicationId = "com.tocadoscoelhos.sitio.equipe"
        minSdk = 24
        targetSdk = 36
        versionCode = flutter.versionCode
        versionName = flutter.versionName

    }

    buildTypes {
        release {
            // TODO: Add your own signing config for the release build.
            // Signing with the debug keys for now, so `flutter run --release` works.
            signingConfig = signingConfigs.getByName("debug")

            // R8 desligado: ele ofuscava o ML Kit (OCR de cupom) e a leitura de
            // foto quebrava só no APK release (NullPointerException). App interno:
            // o APK maior é aceitável. Para religar, teste o OCR no release.
            isMinifyEnabled = false
            isShrinkResources = false

            // Regras do R8 (ver proguard-rules.pro: OCR de cupom / ML Kit)
            proguardFiles(
                getDefaultProguardFile("proguard-android-optimize.txt"),
                "proguard-rules.pro"
            )
        }
    }
}

kotlin {
    compilerOptions {
        jvmTarget = org.jetbrains.kotlin.gradle.dsl.JvmTarget.JVM_17
    }
}

flutter {
    source = "../.."
}
