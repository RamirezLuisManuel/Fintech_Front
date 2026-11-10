# Ecosistema de Comercio Digital Fintech - GestoPago (Flutter Web & Android)

**Asignatura:** Desarrollo de Aplicaciones Móviles / Aplicaciones Web Progresivas  
**Unidad II:** Desarrollo de un ecosistema de comercio digital mediante integración de servicios REST  

---

## 1. Arquitectura de la Solución

Este repositorio (`Fintech front`) contiene la aplicación multiplataforma desarrollada en **Flutter y Dart** que compila tanto para **Aplicación Web (Navegador / PWA)** como para **Aplicación Móvil (Android)**, conectándose sin duplicar lógica de negocio a la infraestructura de servicios REST del backend (`Fintech`) e integrada en tiempo real con **GestoPago**.

### Estructura del Proyecto (`lib/`)
* [`lib/main.dart`](lib/main.dart): Punto de entrada, configuración de tema Material 3 e inicialización de sesión.
* [`lib/utils/security_validators.dart`](lib/utils/security_validators.dart): Validaciones de formularios, sanitización de entradas y detección activa contra inyecciones SQL (`SQLi`) y Cross-Site Scripting (`XSS`).
* [`lib/services/api_service.dart`](lib/services/api_service.dart): Cliente HTTP centralizado con gestión de tokens JWT, control de **Sesión Única Activa** (`X-Session-Token`), expiración por inactividad y consumo de endpoints REST sin `@PathVariable`.
* [`lib/models/`](lib/models/):
  * [`product_model.dart`](lib/models/product_model.dart): Modelo de catálogo GestoPago con categorización automática e identidad visual por marca.
  * [`account_model.dart`](lib/models/account_model.dart): Modelo de perfil de cliente y cuentas bancarias digitales.
  * [`transaction_model.dart`](lib/models/transaction_model.dart): Modelo de operaciones y comprobantes GestoPago.
* [`lib/screens/`](lib/screens/):
  * [`login_screen.dart`](lib/screens/login_screen.dart): Inicio de sesión compartido, detección de sesión activa previa en otro dispositivo y modal de **Autenticación de Doble Factor (2FA)** validado en el servidor.
  * [`register_screen.dart`](lib/screens/register_screen.dart): Apertura de cuenta digital con entrega única de PIN criptográfico de 4 dígitos.
  * [`home_shell_screen.dart`](lib/screens/home_shell_screen.dart): Interfaz adaptativa (`NavigationRail` en Web de escritorio y `NavigationBar` en Móvil Android) con los módulos de Resumen, Catálogo GestoPago, Historial de Compras Exitosas y Seguridad.
  * [`purchase_dialog.dart`](lib/screens/purchase_dialog.dart): Flujo guiado de compra con confirmación previa, autorización por PIN, clave de idempotencia y comprobante visual detallado.

---

## 2. Especificación de Integración REST (Endpoints Consumidos)

Todas las respuestas del servidor siguen el estándar `GenericResponse<T>`:
```json
{
  "codigo": 0,
  "mensaje": "Descripción del resultado",
  "data": { ... }
}
```
*(Donde `codigo: 0` = Éxito, `codigo: 1` = Error de validación de campos, `codigo: 2` = Error de negocio o rechazo de proveedor).*

| Módulo | Endpoint | Método | Parámetros / Body Requerido | Respuesta (`data`) | Códigos HTTP |
| :--- | :--- | :---: | :--- | :--- | :---: |
| **Pre-Login y Control de Sesión Única** | `/api/v1/auth/pre-login` | `POST` | `{"correo", "password", "forceClosePrevious", "platform"}` | `{"activeSessionDetected", "requires2fa", "mensaje2fa"}` | `200`, `401`, `410` |
| **Verificación 2FA en Servidor** | `/api/v1/auth/verify-2fa` | `POST` | `{"correo", "password", "codigo2fa", "platform"}` | `{"accessToken", "refreshToken", "numeroCuenta", "nombreCompleto"}` | `200`, `400`, `401` |
| **Cierre de Sesión Seguro** | `/api/v1/auth/logout` | `POST` | Header `Authorization: Bearer <JWT>`, Body `{"correo"}` | `{"mensaje": "Sesion cerrada exitosamente"}` | `200` |
| **Registro / Onboarding** | `/api/v1/clientes` | `POST` | Datos personales, `curp`, `rfc`, `correo`, `password`, `domicilio` | `{"numero_cuenta", "pin", "aviso_seguridad"}` | `201`, `400`, `409` |
| **Perfil y Saldo en Vivo** | `/api/v1/usuarios/perfil` | `POST` | Headers `Authorization` y `X-Session-Token` | Datos del titular y lista de `cuentas` con `saldoDisponible` | `200`, `401` |
| **Catálogo de Productos GestoPago** | `/api/v1/gestopago/products` | `GET` | — | Lista de 904 productos (`idProducto`, `servicio`, `producto`, `precio`, `tipoFront`, `legend`) | `200`, `502`, `503` |
| **Sincronizar Catálogo** | `/api/v1/gestopago/products/sync` | `POST` | — | `{"total_productos": 903}` | `200`, `502` |
| **Ejecutar Compra GestoPago** | `/api/v1/gestopago/transactions/pagar` | `POST` | `{"idempotencyKey", "numeroCuenta", "idProducto", "monto", "telefono", "referencia", "pin"}` | `operationId`, `upc`, `estado` (`SUCCEEDED`, `FAILED`, `UNKNOWN`), `providerAuthorization` | `200`, `400`, `403`, `404` |
| **Historial de Compras** | `/api/v1/gestopago/transactions/historial` | `POST` | Headers `Authorization` y `X-Session-Token` | Lista de operaciones del usuario ordenadas por fecha descendente | `200`, `401` |
| **Detalle de Compra** | `/api/v1/gestopago/transactions/detalle` | `POST` | `{"operationId": "<UUID>"}` | Objeto completo de la transacción y folios del proveedor | `200`, `404` |

---

## 3. Cómo Ejecutar Ambas Plataformas (Web y Móvil Android)

### Requisitos previos
Asegúrate de que el backend (`Fintech`) esté corriendo en el puerto `9090` junto con Docker (`prueba_postgres` y `prueba_redis`).

### A) Ejecutar la Aplicación Web (Navegador Chrome / Edge)
```powershell
cd "C:\Datos\UTNG\10mo\WEB progresivas\Fintech front"
flutter run -d chrome
```

### B) Ejecutar la Aplicación Móvil (Emulador o Dispositivo Android)
```powershell
cd "C:\Datos\UTNG\10mo\WEB progresivas\Fintech front"
flutter run -d android
```
> **Nota sobre la URL en Android:**  
> En emulador Android la app apunta automáticamente a `http://10.0.2.2:9090`. Si usas un teléfono físico por USB o Wi-Fi, toca el botón **"Móvil REST"** en la esquina superior derecha de la pantalla de Login para colocar la IP local de tu PC (ej. `http://192.168.1.XX:9090`).
