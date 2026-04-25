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

// Combined fix for "Namespace not specified" and "package attribute" errors
subprojects {
    val project = this
    
    fun applyAgpFix() {
        if (project.hasProperty("android")) {
            val android = project.extensions.getByName("android") as? com.android.build.gradle.BaseExtension
            android?.let {
                // 1. Force a namespace if missing
                if (it.namespace == null) {
                    it.namespace = "com.shiv.yellow_leaf.${project.name.replace("-", "_").replace(".", "_")}"
                }
                
                // 2. Strip 'package' attribute from AndroidManifest.xml to satisfy AGP 8.0+
                try {
                    val manifestFile = it.sourceSets.getByName("main").manifest.srcFile
                    if (manifestFile.exists()) {
                        var content = manifestFile.readText()
                        if (content.contains("package=")) {
                            content = content.replace(Regex("""package="[^"]*""""), "")
                            manifestFile.writeText(content)
                        }
                    }
                } catch (e: Exception) {
                    // Ignore errors for projects that don't follow standard layout
                }
            }
        }
    }

    if (project.state.executed) {
        applyAgpFix()
    } else {
        project.afterEvaluate {
            applyAgpFix()
        }
    }
}

tasks.register<Delete>("clean") {
    delete(rootProject.layout.buildDirectory)
}
