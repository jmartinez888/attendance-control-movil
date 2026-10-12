# Consideraciones Técnicas del Sistema de Control de Asistencias (IIAP)

Documento técnico que consolida las especificaciones, tecnologías, componentes y estándares de ingeniería de software implementados tanto en el **Backend** (`attendance-control` / `asistencia-iiap-api`) como en el **Frontend Móvil** (`Frrontend_asistencia_iiap` / `control_asistencia`) del Instituto de Investigaciones de la Amazonía Peruana (IIAP).

---

## 1. Tabla Resumen de Consideraciones Técnicas

A continuación se presenta la matriz general de consideraciones técnicas del proyecto integral (Frontend y Backend), estructurada bajo el formato estándar de documentación institucional y académica:

| Consideración técnica | Descripción |
| :--- | :--- |
| **Plataforma de Desarrollo** | Se utiliza un ecosistema moderno y desacoplado: en el **Backend**, el framework empresarial **NestJS 10** sobre el entorno de ejecución **Node.js** bajo una arquitectura de monolito modular; y en el **Frontend**, el framework multiplataforma **Flutter 3 (Google)** para la construcción de una aplicación móvil nativa y reactiva de alto rendimiento en Android e iOS. |
| **Lenguajes de Programación** | Se emplea **TypeScript 5.1** en el Backend para garantizar tipado estático riguroso, programación orientada a objetos basada en decoradores y robustez en tiempo de compilación; y **Dart 3.x** en el Frontend, aprovechando características de *null safety*, tipado estático sólido y compilación AOT (*Ahead-Of-Time*) para rendimiento nativo en dispositivos móviles. |
| **Base de Datos y Persistencia** | Se implementa el motor de base de datos relacional **PostgreSQL 15** gestionado a través del ORM **TypeORM 0.3**, empleando identificadores universales únicos (UUID v4) como claves primarias, relaciones normalizadas y archivado por borrado lógico (*soft delete*). A nivel de cliente móvil, se utiliza **SharedPreferences** para la persistencia local de tokens de sesión, credenciales biométricas y configuración de red. |
| **API de Acceso a Datos y Servicios** | Se desarrolla una **API RESTful** centralizada bajo el prefijo `/api`, estructurada mediante controladores, servicios y DTOs (*Data Transfer Objects*) con tuberías de validación estricta (`ValidationPipe`). Permite el consumo estructurado de recursos en formato JSON para autenticación, marcación de asistencia, control de usuarios, gestión de roles y eventos institucionales. |
| **Integración con Hardware y Servicios de Dispositivos** | Se integran módulos nativos de hardware móvil: cámara para escaneo de códigos QR en tiempo real (**Mobile Scanner**), renderizado visual dinámico de QR (**QR Flutter**), sensor de geolocalización satelital GPS (**Geolocator**), autenticación biométrica por huella dactilar/rostro (**Local Auth**), notificaciones push locales (**Flutter Local Notifications**) y motor de generación de reportes y exportación en PDF (**PDF/Printing**). |
| **Seguridad y Privacidad de Datos** | Se implementa autenticación sin estado mediante **JWT (JSON Web Tokens)** con firma criptográfica, hashing de contraseñas con **bcrypt** (10 rondas de sal), control de acceso basado en roles (**RBAC** con roles `ADMIN`, `SUPERVISOR` y `EMPLOYEE`), códigos de recuperación OTP de 6 dígitos criptográficamente seguros (`crypto.randomInt`), validación de identidad y DNI ante **RENIEC**, verificación binaria de imágenes subidas mediante *Magic Bytes* y protección configurable de orígenes cruzados (**CORS**). |
| **Escalabilidad y Arquitectura** | La arquitectura backend se basa en un monolito modular con separación estricta de responsabilidades (Capas: Controller, Service, Repository, DTO). El frontend utiliza un patrón por servicios y modelos desacoplados con inyección de estado. El despliegue de infraestructura está soportado por contenedores con **Docker** y orquestación con **Docker Compose**, permitiendo escalamiento vertical y horizontal continuo. |
| **Pruebas Automatizadas y Calidad de Código** | Se implementa aseguramiento de calidad con **ESLint 9** y **Prettier** con reglas estrictas de verificación de tipos, verificación estática de TypeScript (`tsc --noEmit`), pipeline automatizado de Integración Continua (**GitHub Actions CI**) en ramas principales, soporte para pruebas unitarias e integración en backend con **Jest** y pruebas de widgets en frontend con **Flutter Test**. |
| **Responsividad y Compatibilidad Multiplataforma** | El frontend móvil está diseñado con **Material 3 Design** y componentes adaptativos que garantizan compatibilidad completa entre diferentes densidades de pantalla, versiones de sistema operativo (Android y iOS), soporte para temas visuales dinámicos (modo oscuro y claro) y utilidades de renderizado responsivo. |
| **Documentación Técnica** | Se genera documentación interactiva en vivo de los endpoints mediante **Swagger / OpenAPI 3.0** disponible en `/api/docs`, junto con documentación técnica integral en archivos Markdown estructurados que detallan la arquitectura, diseño relacional de la base de datos, directrices de seguridad y catálogo de APIs. |

---

## 2. Detalle Exhaustivo de las Consideraciones Técnicas

### 2.1. Plataforma de Desarrollo y Frameworks

El proyecto está diseñado bajo una arquitectura cliente-servidor desacoplada para maximizar la mantenibilidad, escalabilidad e independencia de ciclos de despliegue:

*   **Backend (`attendance-control`):**
    *   **Framework:** NestJS 10 (`@nestjs/core`, `@nestjs/common`, `@nestjs/platform-express`).
    *   **Entorno:** Node.js (versión 20 LTS recomendada, compatible con gestor de versiones `.nvmrc`).
    *   **Paradigma:** Arquitectura modular orientada a objetos (POO), inyección de dependencias (DI), programación funcional y uso extensivo de decoradores de TypeScript.
    *   **Módulos Principales:**
        *   `AppModule`: Configuración global (`@nestjs/config`) y conexión a base de datos.
        *   `AuthModule`: Control de credenciales, tokens JWT, recuperación de contraseña y validación de DNI.
        *   `UsersModule`: Gestión de usuarios, perfiles, carga de fotos y asignación de supervisores.
        *   `AttendanceModule`: Generación y rotación de tokens QR dinámicos, registro de marcas, historial y archivado semanal.

*   **Frontend Móvil (`Frrontend_asistencia_iiap`):**
    *   **Framework:** Flutter SDK (versión `>=3.0.0 <4.0.0`).
    *   **Target Multiplataforma:** Configurado y compilado primariamente para plataformas móviles (**Android** e **iOS**), con compatibilidad estructural para entornos Desktop y Web.
    *   **Arquitectura de Cliente:** Estructura modular dividida en:
        *   `config/`: Configuración global y gestión dinámica de host backend (`ApiConfig`).
        *   `models/`: Serialización fuertemente tipada de respuestas (`UserModel`, `AttendanceModel`, `QrModel`, `EventModel`).
        *   `services/`: Clientes HTTP, almacenamiento seguro, geolocalización, biometría, temas y notificaciones.
        *   `screens/`: Vistas de autenticación, dashboard, escaneo, generación de QR, gestión de supervisores, eventos y perfil.
        *   `widgets/`: Componentes UI reutilizables (temporizadores dinámicos, tarjetas de marcación, diálogos de visualización).

---

### 2.2. Lenguajes de Programación

*   **TypeScript (Backend):**
    *   Versión: **5.1+**.
    *   Aporta verificación de tipos estáticos en tiempo de diseño y compilación, reduciendo drásticamente errores en tiempo de ejecución.
    *   Uso de decoradores nativos para mapeo de rutas REST (`@Controller`, `@Get`, `@Post`), inyección de dependencias (`@Injectable`), validación de datos (`@IsString`, `@IsEmail`, `@Length`) y definición de roles (`@Roles`).
    *   Definición estricta de interfaces (`AuthenticatedRequest`) y tipos personalizados.

*   **Dart (Frontend):**
    *   Versión: **3.x** con *Sound Null Safety* habilitado por defecto.
    *   Compilación Ahead-of-Time (AOT) para generar código máquina nativo y garantizar transiciones de interfaz a 60/120 FPS.
    *   Serialización/deserialización segura de JSON a objetos de dominio mediante constructores de fábrica (`factory Model.fromJson`).

---

### 2.3. Base de Datos y Persistencia

*   **Motor de Base de Datos:** **PostgreSQL 15** (desplegado en entorno aislado mediante `postgres:15-alpine` vía Docker).
*   **Mapeador Objeto-Relacional (ORM):** **TypeORM 0.3.17**.
*   **Esquema y Modelado Relacional:**
    *   **Claves Primarias:** Uso de UUID v4 (`uuid_generate_v4()`) en todas las entidades para mayor seguridad y evitar enumeraciones predecibles.
    *   **Entidades Centrales:**
        *   `users`: Datos personales, credenciales hasheadas, DNI validado, foto de perfil, área, cargo y rol institucional.
        *   `attendance`: Registro de marcaciones de entrada (`CHECK_IN`) y salida (`CHECK_OUT`), fecha/hora en formato UTC/zona horaria local, identificador del supervisor emisor del QR, coordenadas GPS y huella del dispositivo (`device_id`).
        *   `qr_code_tokens`: Tokens criptográficos efímeros de uso único con vigencia de 5 minutos para asistencia y asignación de supervisores.
    *   **Archivado y Trazabilidad:** Implementación de borrado lógico (*soft delete*) con la columna `deleted_at`. Los registros históricos de asistencia se archivan periódicamente sin pérdida física de datos.
    *   **Gestión de Esquemas:** Configuración automática mediante `synchronize: true` exclusivamente en entornos de desarrollo, desactivándose estrictamente en producción para salvaguardar la integridad de los datos.
*   **Persistencia Local en Cliente:** **`shared_preferences` (v2.2.2)** para almacenamiento seguro y persistente de tokens de autenticación Bearer JWT, datos del usuario activo, preferencias de interfaz y URL personalizada del host del servidor.

---

### 2.4. API de Acceso a Datos y Servicios

*   **Protocolo y Formato:** HTTP/1.1 y HTTPS sobre TLS, intercambiando datos exclusivamente mediante **JSON**.
*   **Estandarización de Rutas:** Prefijo global `/api`.
*   **Validación de Carga Útil (Payloads):** Tubería global `ValidationPipe` con las opciones:
    *   `whitelist: true`: Elimina propiedades no reconocidas en el DTO.
    *   `forbidNonWhitelisted: true`: Retorna error HTTP 400 si se envían parámetros no documentados.
    *   `transform: true`: Convierte tipos primitivos automáticamente a las instancias de clase correspondientes.
*   **Módulos de la API:**
    *   **Autenticación (`/api/auth`):** Registro con DNI, inicio de sesión (correo electrónico o DNI), perfil del usuario autenticado (`/auth/me`), solicitud y confirmación de restablecimiento de contraseña mediante OTP.
    *   **Usuarios (`/api/users`):** Perfil de usuario, actualización de datos, subida de foto de perfil (vía `multipart/form-data` o Base64), listado administrativo y asignación/revocación de supervisores.
    *   **Control de Asistencias (`/api/attendance`):** Generación de QR dinámico para entrada/salida, consulta de QR activo, generación de QR para promoción a supervisor, escaneo y registro de marca con coordenadas GPS, consulta de historial personal y reinicio programado semanal.
    *   **Eventos Institucionales (`/api/events`):** Creación y gestión de eventos públicos o internos, generación de QR para eventos y registro de asistentes externos vía interfaz web/móvil.

---

### 2.5. Integración con Hardware y Servicios Especializados

El sistema aprovecha al máximo las capacidades de los dispositivos móviles para garantizar un control de asistencia confiable, dinámico e inmutable:

*   **Generación de Códigos QR Dinámicos de Uso Único:**
    *   Cálculo de hash criptográfico único mediante **SHA-256** combinando el identificador del supervisor emisor, marca de tiempo y bytes aleatorios.
    *   Vigencia temporal estricta de **5 minutos (300 segundos)** con visualización de temporizador regresivo dinámico (`qr_countdown_timer.dart`).
    *   Invalidación y rotación automática inmediata tras la primera lectura exitosa, impidiendo la clonación o retransmisión de códigos QR entre empleados.
*   **Captura y Escaneo de Códigos QR (`mobile_scanner` 7.4):**
    *   Uso acelerado por hardware de la cámara del smartphone para lectura bidimensional de alta tasa de cuadros.
*   **Geolocalización Satelital GPS (`geolocator` 13.0):**
    *   Captura automática de latitud y longitud con alta precisión en el instante exacto de la marcación para auditoría de presencia geográfica en las instalaciones del IIAP.
*   **Autenticación Biométrica Nativa (`local_auth` 2.3):**
    *   Protección de acceso a la aplicación móvil mediante sensor de huella dactilar o reconocimiento facial del dispositivo.
*   **Sistema de Notificaciones Locales (`flutter_local_notifications` 17.2):**
    *   Recordatorios automáticos de fin de jornada laboral y alertas de salida pendiente (`pending_checkout_card.dart`).
*   **Generación y Exportación de Documentos PDF (`pdf` 3.11 y `printing` 5.13):**
    *   Construcción de reportes formales de asistencia directamente en el dispositivo móvil con capacidades de previsualización, exportación a archivo e impresión física inalámbrica.
*   **Monitoreo del Estado de Conectividad (`connectivity_plus` 6.1):**
    *   Detección reactiva del estado de conexión a Internet (Wi-Fi, datos móviles o desconexión).

---

### 2.6. Seguridad y Privacidad de Datos

*   **Autenticación Robusta:** Implementación de tokens JWT (`@nestjs/jwt`, `passport-jwt`) firmados con algoritmo HMAC-SHA256 y clave secreta obligatoria en variables de entorno (`JWT_SECRET`).
*   **Revalidación Continua de Usuario:** La estrategia `JwtStrategy` revalida la existencia y estado activo (`is_active = true`) del usuario en la base de datos en cada petición protegida, reflejando de inmediato cambios de rol o deshabilitaciones.
*   **Control de Acceso Basado en Roles (RBAC):**
    *   Roles definidos: `ADMIN` (administrador de sistema), `SUPERVISOR` (máximo 3 supervisores activos concurrentes) y `EMPLOYEE` (empleado estándar).
    *   Protección mediante el decorador `@Roles(...)` y el guardián global `RolesGuard`.
*   **Criptografía y Contraseñas:**
    *   Cifrado unidireccional de contraseñas con **bcrypt** empleando 10 rondas de sal.
    *   Políticas de longitud mínima de contraseña (mínimo 8 caracteres).
*   **Recuperación Segura de Contraseña:**
    *   Generación de códigos de un solo uso (OTP) de 6 dígitos con generación criptográfica (`crypto.randomInt`).
    *   Expiración automática a los 15 minutos y bloqueo de cuenta temporal tras 5 intentos fallidos consecutivos.
*   **Validación de Identidad con RENIEC:**
    *   Integración durante el registro con la API de RENIEC para DNI peruanos de 8 dígitos.
    *   Sobrescribe automáticamente el nombre provisto por el usuario con el nombre oficial registrado en el padrón nacional, evitando identidades apócrifas.
    *   Tolerancia a fallos: ante indisponibilidad del servicio externo, no se interrumpe el flujo de registro.
*   **Validación de Archivos Multimedia (Fotos de Perfil):**
    *   Límite de tamaño máximo estricto (10 MB).
    *   Inspección de firmas binarias (*Magic Bytes*) tanto en cargas multipart como en Base64, impidiendo la inyección de código ejecutable disfrazado de imágenes (soporte exclusivo para JPEG, PNG, WEBP, GIF, BMP, HEIC/HEIF).
*   **Políticas de CORS:**
    *   Control granular de orígenes permitidos mediante la variable `CORS_ORIGINS`.

---

### 2.7. Escalabilidad y Arquitectura del Sistema

*   **Separación de Capas (Patrón N-Capas):** Desacoplamiento total entre controladores de entrada (HTTP), lógica de negocio en servicios y persistencia de datos mediante repositorios TypeORM.
*   **Contenedorización con Docker:**
    *   Configuración formal de `docker-compose.yml` para el despliegue replicable del motor PostgreSQL.
    *   Alineación de credenciales entre variables de entorno `.env` y el contenedor de base de datos.
*   **Desacoplamiento de Host en Frontend:**
    *   Clase `ApiConfig` con soporte para conmutación dinámica de host de desarrollo (URL local, emulador Android `10.0.2.2`, IP local de red Wi-Fi y servidor de producción en la nube `https://dev-api-control.iiap.gob.pe/api`).

---

### 2.8. Pruebas Automatizadas y Calidad de Código

*   **Control Estático y Linter:**
    *   Configuración de **ESLint 9** con plugins `@typescript-eslint/recommended-type-checked` y `eslint-plugin-prettier`.
    *   Ejecución de linter con tolerancia cero a advertencias (`--max-warnings 0`).
    *   Formateador automático **Prettier** con configuración institucional estandarizada (`.prettierrc`).
*   **Pipeline de Integración Continua (CI):**
    *   Workflow en **GitHub Actions** (`.github/workflows/ci.yml`) que se ejecuta automáticamente en cada `push` o `pull request` hacia las ramas `main` y `development`.
    *   Fases del Pipeline de CI:
        1. Verificación de formato (`npm run format:check`).
        2. Análisis estático de código (`npm run lint`).
        3. Comprobación exhaustiva de tipos sin emisión (`npx tsc --noEmit`).
        4. Compilación del proyecto (`npm run build`).
*   **Infraestructura de Pruebas:**
    *   Backend: Configurado con el framework de pruebas **Jest** (`@nestjs/testing`).
    *   Frontend: Configurado con el runner de pruebas unitarias y de widgets **Flutter Test**.

---

### 2.9. Responsividad y Compatibilidad Multiplataforma

*   **Diseño Visual:** Implementación del sistema de diseño **Material 3**, complementado con componentes visuales de identidad regional del IIAP (logotipo de hoja `leaf_logo.dart`, fondos temáticos amazónicos en `wallpaper_screen.dart` y selector de temas dinámicos).
*   **Adaptabilidad Responsiva:**
    *   Uso de clase auxiliar `Responsive` (`responsive.dart`) para el cálculo adaptativo de tipografías, márgenes y áreas táctiles de acuerdo al ancho y alto de la pantalla.
    *   Compatibilidad verificada en teléfonos inteligentes Android (versiones de SDK modernas) y dispositivos Apple iOS.

---

### 2.10. Documentación Técnica

*   **Documentación Viva de la API:**
    *   Generación automática de especificación **OpenAPI 3.0** servida mediante **Swagger UI** en `/api/docs`.
    *   Esquema de autenticación Bearer JWT documentado interactivamente para pruebas de endpoints.
*   **Documentación de Ingeniería en Repositorio:**
    *   `README.md`: Guía de inicio rápido, configuración de variables de entorno y comandos de despliegue.
    *   `docs/ARCHITECTURE.md`: Arquitectura del sistema, flujos detallados de autenticación, generación/lectura de QR y ciclo de vida de peticiones.
    *   `docs/DATABASE.md`: Diccionario de datos, relaciones de entidades, llaves foráneas y especificación de columnas.
    *   `docs/SECURITY.md`: Auditoría de seguridad, mitigación de vulnerabilidades y buenas prácticas implementadas.
    *   `docs/API.md`: Catálogo completo de endpoints clasificados por módulo, métodos HTTP, requerimientos de roles y formatos de carga útil.
