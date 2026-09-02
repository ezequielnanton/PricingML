# Login del Repositor con token en memoria, no JWT ni tabla de sesión

Se agregó una pantalla standalone (`/repositor`, sin el layout de admin) para que un
repositor cargue recuentos de stock sin pasar por el ABM completo, pensada para
clientes que no tienen ERP propio alimentando `StockEstado`. Requiere identificar
quién carga cada recuento, así que se sumó un login simple (Usuario + PIN numérico)
sobre una tabla `Repositores` nueva.

Para la sesión se evaluaron JWT (con `Microsoft.AspNetCore.Authentication.JwtBearer`)
y una tabla de sesiones persistida en `PRICES_DB`. Se optó por un token opaco
generado con `RandomNumberGenerator`, guardado en un diccionario en memoria
(`RepositorAuthService`, singleton) con expiración de 12 horas. Motivo: el resto de
la API es deliberadamente minimalista (ADO.NET crudo, sin frameworks de auth ni
ORM) y el propósito del login es solo trazabilidad de auditoría en `StockCargas`,
no proteger datos sensibles — no justifica sumar una dependencia nueva ni una tabla
de sesiones. El costo real es que las sesiones se pierden si la API reinicia (el
repositor simplemente vuelve a loguearse) y no escalan a múltiples instancias de la
API, ninguno de los cuales es un problema hoy con un solo proceso desplegado.

Si en el futuro este login se generaliza a otros roles (analista de pricing, admin)
o el despliegue pasa a múltiples instancias, ahí sí conviene migrar a JWT o a una
tabla de sesión — no antes.
