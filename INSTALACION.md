# Instalación de PricingML

El sistema se distribuye como **dos ejecutables autocontenidos**. La PC de destino
**no necesita .NET ni Node.js instalados**, solo SQL Server.

| Ejecutable | Qué es | Puerto |
|---|---|---|
| `PricingMotor.exe` | API REST + Swagger | 5000 |
| `PricingCliente.exe` | Interfaz web (React embebido dentro del .exe) | 3000 |

---

## Generar los ejecutables

En la PC de desarrollo, con .NET 10 SDK y Node.js instalados:

```powershell
.\build-exe.ps1
```

Genera:

```
dist\PricingML\
  PricingMotor.exe
  PricingCliente.exe
  appsettings.json
  LEEME.txt
dist\PricingML-windows-x64.zip
```

Copiá la carpeta `dist\PricingML` (o el ZIP) a la otra PC.

---

## Instalar en la otra PC

### Requisito único
SQL Server con la base de datos ya creada. Los ejecutables **no** crean ni modifican
el esquema de la base.

### Paso 1 — Motor

Doble clic en `PricingMotor.exe`.

La primera vez pregunta por consola:

- **Servidor SQL** — por ejemplo `localhost\SQLEXPRESS` o `192.168.1.10`
- **Base de datos** — por defecto `PRICES_DB`
- **Autenticación de Windows** — `S` usa la sesión actual; `n` pide usuario y contraseña

Prueba la conexión antes de guardar y la escribe en `appsettings.json`.

Dejá la ventana abierta: **es el servidor**. Para verificar que funciona:
http://localhost:5000/swagger

### Paso 2 — Cliente

Doble clic en `PricingCliente.exe`.

La primera vez pregunta:

- **Puerto** — por defecto `3000`
- **Dirección del Motor** — dejalo **vacío** si el Motor corre en la misma PC

Abre el navegador solo en http://localhost:3000

---

## Configuración posterior

| Archivo | Controla |
|---|---|
| `appsettings.json` | Conexión SQL, puerto del Motor (`Urls`), credenciales de MercadoLibre |
| `PricingCliente.config.json` | Puerto del Cliente y dirección del Motor |

Borrando cualquiera de los dos, el programa vuelve a preguntar en el próximo arranque.

También aceptan argumentos:

```powershell
.\PricingCliente.exe --puerto 8080 --api http://192.168.1.50:5000 --sin-navegador
```

---

## Motor y Cliente en PCs distintas

1. En la PC del Motor, habilitá el **puerto 5000** en el Firewall de Windows.
2. En la PC del Cliente, cuando pregunte la dirección del Motor, poné la IP real:
   `http://192.168.1.50:5000`

El Motor ya acepta pedidos desde cualquier IP de red privada, no hay que tocar CORS.

---

## Problemas frecuentes

**"No se pudo conectar a SQL Server"**
El Motor muestra el error exacto y ofrece reconfigurar. Verificá que el servicio de
SQL Server esté iniciado y que la base exista.

**"El puerto 3000 ya está en uso"**
Otro programa lo ocupa. Corré `.\PricingCliente.exe --puerto 3001` o editá
`PricingCliente.config.json`.

**El Cliente carga pero no trae datos**
El Motor no está corriendo o está en otra dirección. Abrí
http://localhost:5000/swagger para confirmar que responde.

**Windows SmartScreen bloquea el .exe**
Los ejecutables no están firmados digitalmente. Clic en "Más información" →
"Ejecutar de todas formas".
