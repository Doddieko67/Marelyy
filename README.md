### Inicialización del Proyecto

Este documento describe los pasos para inicializar el proyecto, incluyendo la configuración de Firebase y la ejecución de la aplicación Flutter.

### Inicialización del Proyecto

Este documento describe los pasos para inicializar el proyecto, incluyendo la obtención del código fuente, la configuración de Firebase (si es necesaria) y la ejecución de la aplicación Flutter.

#### 0. Clonar el Repositorio (Si aún no lo has hecho)

Si aún no tienes el código fuente en tu máquina local, debes clonar el repositorio Git:

```bash
git clone https://github.com/Doddieko67/Marelyy
mv marelyy classroom_mejorado
cd classroom_mejorado
```

#### 1. Configuración de Firebase (Solo si tienes problemas de conexión a la base de datos Firestore)

Si encuentras problemas de conectividad con tu base de datos Firestore, ejecuta el siguiente comando para reconfigurar Firebase en tu proyecto:

```bash
flutterfire configure
```

**Importante:**

*   **No sobrescribas la configuración existente a menos que sea absolutamente necesario.**  Si se te pregunta si deseas sobrescribir archivos, responde **"No"**.  Sobrescribir la configuración podría reemplazar tus datos de Firebase con una configuración incorrecta, especialmente si estás usando la configuración proporcionada para fines de demostración o desarrollo.
*   La configuración correcta de Firebase (incluyendo las claves API y los nombres de proyecto) es esencial para que la aplicación se conecte y funcione con la base de datos.  Si tienes dudas sobre la configuración correcta, consulta la documentación de Firebase o contacta con el responsable de la cuenta del proyecto.
*   Tengo una cuenta con las funcionalidades de plan necesarias para este proyecto.

#### 2. Configuración y Ejecución de Flutter

Después de configurar Firebase (si fue necesario), ejecuta los siguientes comandos para obtener las dependencias y ejecutar la aplicación Flutter:

```bash
flutter pub get
flutter run --dart-define-from-file=env.json --release
```

**Explicación de los comandos:**

*   `flutter pub get`: Este comando descarga e instala todas las dependencias definidas en el archivo `pubspec.yaml` de tu proyecto.  Es esencial ejecutarlo después de cualquier cambio en las dependencias o después de clonar el proyecto por primera vez.
*   `flutter run --dart-define-from-file=env.json`: Este comando ejecuta la aplicación Flutter en modo de debug.
    *   `--dart-define-from-file=env.json`:  Esta opción permite pasar variables de entorno definidas en el archivo `env.json` a la aplicación durante la compilación.  Esto es útil para almacenar información sensible como claves API, URLs de bases de datos, etc., fuera del código fuente principal.  Asegúrate de que el archivo `env.json` contenga la configuración correcta para tu entorno.
