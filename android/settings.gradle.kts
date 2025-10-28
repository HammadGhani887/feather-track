pluginManagement {
    repositories {
        google()
        mavenCentral()
        gradlePluginPortal()
        // Add Flutter repository
        val flutterSdkPath = File(rootProject.projectDir, "local.properties").let { file ->
            val properties = java.util.Properties()
            file.inputStream().use { properties.load(it) }
            properties.getProperty("flutter.sdk")
        }
        maven {
            url = uri("${flutterSdkPath}/packages/flutter_tools/gradle")
        }
    }
    plugins {
        id("com.android.application") version "8.2.0"
        id("org.jetbrains.kotlin.android") version "1.7.10"
        id("com.google.gms.google-services") version "4.4.1"
        id("dev.flutter.flutter-gradle-plugin")
    }
}

dependencyResolutionManagement {
    repositoriesMode.set(RepositoriesMode.PREFER_SETTINGS)
    repositories {
        google()
        mavenCentral()
    }
}

include(":app")

val localPropertiesFile = File(rootProject.projectDir, "local.properties")
val properties = java.util.Properties()

assert(localPropertiesFile.exists())
localPropertiesFile.inputStream().use { properties.load(it) }

val flutterSdkPath = properties.getProperty("flutter.sdk")
assert(flutterSdkPath != null) { "flutter.sdk not set in local.properties" }

// Include Flutter project
apply(from = "${flutterSdkPath}/packages/flutter_tools/gradle/app_plugin_loader.gradle")
