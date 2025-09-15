import com.android.build.gradle.LibraryExtension
import org.gradle.api.tasks.compile.JavaCompile
import org.jetbrains.kotlin.gradle.dsl.KotlinAndroidProjectExtension
import org.jetbrains.kotlin.gradle.dsl.JvmTarget

allprojects {
    repositories {
        google()
        mavenCentral()
    }
}

val newBuildDir: Directory =
    rootProject.layout.buildDirectory
        .dir("../../build")
        .get()
rootProject.layout.buildDirectory.value(newBuildDir)

subprojects {
    val newSubprojectBuildDir: Directory = newBuildDir.dir(project.name)
    project.layout.buildDirectory.value(newSubprojectBuildDir)
}
subprojects {
    project.evaluationDependsOn(":app")
}

tasks.register<Delete>("clean") {
    delete(rootProject.layout.buildDirectory)
}

/**
 * 顶层兜底（不再改库的 compileSdk，避免 "too late to set compileSdk"）：
 * - 对所有 com.android.library：
 *   * 如缺 namespace：按白名单或占位补齐；
 *   * 统一 Java/Kotlin 目标为 11（避开 1.8/21 混用）。
 */
subprojects {

    // 与库 Manifest package 对齐的白名单（避免 Incorrect package 报错）
    val wellKnownNamespace = mapOf(
        "isar_flutter_libs" to "dev.isar.isar_flutter_libs",
        "msal_flutter" to "uk.co.moodio.msal_flutter",
        "shared_preferences_android" to "io.flutter.plugins.sharedpreferences"
    )

    plugins.withId("com.android.library") {
        extensions.configure<LibraryExtension>("android") {
            // namespace 兜底（优先白名单，其次占位）
            val mapped = wellKnownNamespace[project.name]
            val current = this.namespace
            if (current.isNullOrBlank()) {
                val safe = project.name.replace(Regex("[^A-Za-z0-9_]"), "_")
                this.namespace = mapped ?: "fix.$safe"
            }

            // 统一 Java 版本
            compileOptions {
                sourceCompatibility = JavaVersion.VERSION_11
                targetCompatibility = JavaVersion.VERSION_11
            }
        }
    }

    // 所有启用 Kotlin 的 Android 模块统一 jvmTarget=11
    fun configureKotlinAndroid() {
        extensions.configure<KotlinAndroidProjectExtension> {
            compilerOptions { jvmTarget.set(JvmTarget.JVM_11) }
        }
    }
    plugins.withId("org.jetbrains.kotlin.android") { configureKotlinAndroid() }
    plugins.withId("kotlin-android") { configureKotlinAndroid() }

    // 纯 Java 任务兜底
    tasks.withType<JavaCompile>().configureEach {
        sourceCompatibility = "11"
        targetCompatibility = "11"
    }
}
