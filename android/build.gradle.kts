import com.android.build.gradle.BaseExtension

allprojects {
    repositories {
        google()
        mavenCentral()
    }
}

// Fixed Namespace Logic for old plugins like usb_serial
subprojects {
    plugins.withId("com.android.library") {
        extensions.findByType(BaseExtension::class.java)?.let { android ->
            if (android.namespace == null) {
                android.namespace = project.group.toString().ifEmpty { "com.example.${project.name}" }
            }
        }
    }
    plugins.withId("com.android.application") {
        extensions.findByType(BaseExtension::class.java)?.let { android ->
            if (android.namespace == null) {
                android.namespace = project.group.toString().ifEmpty { "com.example.${project.name}" }
            }
        }
    }
}

// Flutter Build Directory Logic
val newBuildDir: Directory = rootProject.layout.buildDirectory.dir("../../build").get()
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