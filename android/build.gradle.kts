import org.gradle.api.tasks.Delete
import org.gradle.api.file.Directory
import org.gradle.api.JavaVersion
import org.gradle.api.tasks.compile.JavaCompile
import org.jetbrains.kotlin.gradle.tasks.KotlinCompile

// ==========================
// REPOSITORIES
// ==========================
allprojects {
    repositories {
        google()
        mavenCentral()
    }
}

// ==========================
// 🔥 GLOBAL JVM FIX (CRITICAL)
// ==========================
subprojects {

    afterEvaluate {

        // ✅ Fix Android modules (VERY IMPORTANT)
        extensions.findByName("android")?.let { ext ->
            if (ext is com.android.build.gradle.BaseExtension) {
                ext.compileOptions.sourceCompatibility = JavaVersion.VERSION_17
                ext.compileOptions.targetCompatibility = JavaVersion.VERSION_17
            }
        }

        // ✅ Fix Java compile tasks
        tasks.withType<JavaCompile>().configureEach {
            sourceCompatibility = "17"
            targetCompatibility = "17"
        }

        // ✅ Fix Kotlin compile tasks
        tasks.withType<KotlinCompile>().configureEach {
            kotlinOptions {
                jvmTarget = "17"
            }
        }
    }
}

// ==========================
// OPTIONAL BUILD DIR FIX
// ==========================
val newBuildDir: Directory =
    rootProject.layout.buildDirectory.dir("../../build").get()

rootProject.layout.buildDirectory.value(newBuildDir)

subprojects {
    val newSubprojectBuildDir: Directory =
        newBuildDir.dir(project.name)

    project.layout.buildDirectory.value(newSubprojectBuildDir)
}

// ==========================
// CLEAN TASK
// ==========================
tasks.register<Delete>("clean") {
    delete(rootProject.layout.buildDirectory)
}