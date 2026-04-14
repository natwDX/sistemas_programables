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

// Corrige plugins Android antiguos que no declaran `namespace` (AGP 8+ lo exige).
subprojects {
    pluginManager.withPlugin("com.android.library") {
        val androidExtension =
            extensions.findByName("android")
                ?: error("Android extension no encontrada en ${project.path}")

        val getNamespace =
            androidExtension.javaClass.methods.firstOrNull {
                it.name == "getNamespace" && it.parameterCount == 0
            } ?: error("No se encontró getNamespace() para ${project.path}")

        val setNamespace =
            androidExtension.javaClass.methods.firstOrNull {
                it.name == "setNamespace" && it.parameterCount == 1
            } ?: error("No se encontró setNamespace(String) para ${project.path}")

        val currentNamespace = getNamespace.invoke(androidExtension) as String?
        if (currentNamespace.isNullOrBlank()) {
            val namespace =
                when (project.name) {
                    "flutter_bluetooth_serial" -> "io.github.edufolly.flutterbluetoothserial"
                    else -> "com.autogen.${project.name.replace("-", "_")}"
                }
            setNamespace.invoke(androidExtension, namespace)
        }
    }
}

tasks.register<Delete>("clean") {
    delete(rootProject.layout.buildDirectory)
}
