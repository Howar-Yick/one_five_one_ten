plugins {
    id("com.android.application")
    id("kotlin-android")
    // Flutter 插件必须在 Android/Kotlin 之后
    id("dev.flutter.flutter-gradle-plugin")
}

android {
    namespace = "com.example.one_five_one_ten"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = flutter.ndkVersion

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_11
        targetCompatibility = JavaVersion.VERSION_11
    }
    kotlinOptions {
        jvmTarget = JavaVersion.VERSION_11.toString()
    }

    defaultConfig {
        applicationId = "com.example.one_five_one_ten"
        minSdk = flutter.minSdkVersion
        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }

    buildTypes {
        release {
            // 先关闭混淆与资源收缩，直接出 APK
            isMinifyEnabled = false
            isShrinkResources = false

            // 仍然声明 proguard 配置，之后若开启混淆就会使用
            proguardFiles(
                getDefaultProguardFile("proguard-android-optimize.txt"),
                "proguard-rules.pro"
            )

            // 先用 debug 签名，能跑起来
            signingConfig = signingConfigs.getByName("debug")
        }
        debug {
            isMinifyEnabled = false
            isShrinkResources = false
        }
    }
}

flutter {
    source = "../.."
}
