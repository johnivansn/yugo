plugins {
  id("com.android.application")
  id("kotlin-android")
  id("kotlin-kapt")
  id("dev.flutter.flutter-gradle-plugin")
}

android {
  namespace = "io.github.johnivansn.yugo"
  compileSdk = flutter.compileSdkVersion
  ndkVersion = flutter.ndkVersion

  compileOptions {
    isCoreLibraryDesugaringEnabled = true
    sourceCompatibility = JavaVersion.VERSION_17
    targetCompatibility = JavaVersion.VERSION_17
  }

  kotlinOptions { jvmTarget = JavaVersion.VERSION_17.toString() }

  defaultConfig {
    applicationId = "io.github.johnivansn.yugo"
    minSdk = flutter.minSdkVersion
    targetSdk = flutter.targetSdkVersion
    versionCode = flutter.versionCode
    versionName = flutter.versionName
    multiDexEnabled = true
  }

  buildTypes {
    release {
      signingConfig = signingConfigs.getByName("debug")
      isMinifyEnabled = false
      isShrinkResources = false
    }
  }
}

dependencies {
  // Core
  coreLibraryDesugaring("com.android.tools:desugar_jdk_libs:2.0.4")
  implementation("androidx.constraintlayout:constraintlayout:2.1.4")

  // Room
  val roomVersion = "2.8.4"
  implementation("androidx.room:room-runtime:$roomVersion")
  implementation("androidx.room:room-ktx:$roomVersion")
  kapt("androidx.room:room-compiler:$roomVersion")

  // Coroutines
  implementation("org.jetbrains.kotlinx:kotlinx-coroutines-android:1.7.3")

  // Gson
  implementation("com.google.code.gson:gson:2.10.1")

  // Lifecycle
  implementation("androidx.lifecycle:lifecycle-runtime-ktx:2.7.0")
}

flutter { source = "../.." }

flutter {
    source = "../.."
}
