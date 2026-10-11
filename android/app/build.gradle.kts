plugins {
    alias(libs.plugins.android.application)
    alias(libs.plugins.kotlin.android)
    alias(libs.plugins.kotlin.compose)
    alias(libs.plugins.kotlin.serialization)
    alias(libs.plugins.ksp)
}

// Credenciales locales: mismo `.env` raíz que usa `scripts/generate-secrets.sh` en iOS.
// Nunca se imprimen; solo terminan en BuildConfig (bajo build/, ignorado por git).
// El token estático del resolutor NO entra en el APK: Android usa el JWT del usuario.
val secretNames = listOf("YOUTUBE_DATA_KEY", "AUDIO_RESOLVER_BASE_URL")
val secrets: Map<String, String> = run {
    val env = rootProject.file("../.env")
    val fromFile = if (env.exists()) {
        env.readLines()
            .map { it.trim().removePrefix("export ").trim() }
            .filter { it.isNotEmpty() && !it.startsWith("#") && it.contains("=") }
            .associate { line ->
                val key = line.substringBefore("=").trim()
                key to line.substringAfter("=").trim().trim('"', '\'')
            }
    } else {
        emptyMap()
    }
    secretNames.associateWith { name -> System.getenv(name) ?: fromFile[name] ?: "" }
}

fun String.asJavaLiteral() = "\"" + replace("\\", "\\\\").replace("\"", "\\\"") + "\""

android {
    namespace = "com.diegocainzos.diegomusic"
    compileSdk = 35

    defaultConfig {
        applicationId = "com.diegocainzos.diegomusic"
        minSdk = 26
        targetSdk = 35
        versionCode = 1
        versionName = "0.1.0"
        secretNames.forEach { buildConfigField("String", it, secrets.getValue(it).asJavaLiteral()) }
    }

    buildTypes {
        release {
            isMinifyEnabled = false
            signingConfig = signingConfigs.getByName("debug")
        }
    }

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }
    kotlinOptions {
        jvmTarget = "17"
    }
    buildFeatures {
        compose = true
        buildConfig = true
    }
    testOptions {
        unitTests.isReturnDefaultValues = true
    }
}

ksp {
    arg("room.generateKotlin", "true")
}

dependencies {
    implementation(libs.androidx.core.ktx)
    implementation(libs.androidx.activity.compose)
    implementation(platform(libs.compose.bom))
    implementation(libs.compose.ui)
    implementation(libs.compose.foundation)
    implementation(libs.compose.material3)
    implementation(libs.compose.icons)
    implementation(libs.media3.exoplayer)
    implementation(libs.media3.session)
    implementation(libs.room.runtime)
    ksp(libs.room.compiler)
    implementation(libs.okhttp)
    implementation(libs.coil.compose)
    implementation(libs.coil.okhttp)
    implementation(libs.serialization.json)
    implementation(libs.coroutines.android)

    testImplementation(libs.junit)
    testImplementation(libs.coroutines.test)
}
