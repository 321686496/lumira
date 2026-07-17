plugins {
    alias(libs.plugins.android.application)
}

android {
        namespace = "com.rh.ruhua"
    compileSdk = 36
    buildToolsVersion = "36.1.0"

    defaultConfig {
        applicationId = "com.rh.ruhua"
        minSdk = 21
        targetSdk = 33
        versionCode = 100
        versionName = "1.0.0"
        multiDexEnabled = true

        testInstrumentationRunner = "androidx.test.runner.AndroidJUnitRunner"

        ndk {
            abiFilters += listOf("x86", "armeabi-v7a", "arm64-v8a")
        }
    }

    buildTypes {
        release {
            isMinifyEnabled = false
            proguardFiles(
                getDefaultProguardFile("proguard-android-optimize.txt"),
                "proguard-rules.pro"
            )
        }
    }

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_1_8
        targetCompatibility = JavaVersion.VERSION_1_8
    }

    androidResources {
        additionalParameters += "--auto-add-overlay"
        ignoreAssetsPattern = "!.svn:!.git:.*:!CVS:!thumbs.db:!picasa.ini:!*.scc:*~"
    }

    packaging {
        jniLibs {
            useLegacyPackaging = true
        }
    }
}

dependencies {
    implementation(fileTree(mapOf("dir" to "libs", "include" to listOf("*.jar", "*.aar"))))

    implementation("androidx.appcompat:appcompat:1.1.0")
    implementation("androidx.localbroadcastmanager:localbroadcastmanager:1.0.0")
    implementation("androidx.core:core:1.6.0")
    implementation("androidx.fragment:fragment:1.1.0")
    implementation("androidx.recyclerview:recyclerview:1.1.0")
    implementation("com.facebook.fresco:fresco:3.4.0")
    implementation("com.facebook.fresco:middleware:3.4.0")
    implementation("com.facebook.fresco:animated-gif:3.4.0")
    implementation("com.facebook.fresco:webpsupport:3.4.0")
    implementation("com.facebook.fresco:animated-webp:3.4.0")
    implementation("com.github.bumptech.glide:glide:4.9.0")
    implementation("com.alibaba:fastjson:1.2.83")
    implementation("androidx.webkit:webkit:1.5.0")
    annotationProcessor("com.github.bumptech.glide:compiler:4.9.0")
    implementation("net.lingala.zip4j:zip4j:2.11.5")

    testImplementation(libs.junit)
    androidTestImplementation(libs.espresso.core)
    androidTestImplementation(libs.ext.junit)
}
