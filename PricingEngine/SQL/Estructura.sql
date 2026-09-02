-- ============================================================================
-- PROYECTO PRICES: INTELLIGENT PRICING & SALES DECISION ENGINE
-- DATABASE DDL CREATION SCRIPT
-- ============================================================================

USE master;
GO

IF NOT EXISTS (SELECT name FROM sys.databases WHERE name = N'PRICES_DB')
BEGIN
    CREATE DATABASE PRICES_DB;
END
GO

USE PRICES_DB;
GO

-- ----------------------------------------------------------------------------
-- 1. TABLAS DE ESTRUCTURA MULTIEMPRESA Y CONFIGURACIÓN
-- ----------------------------------------------------------------------------

CREATE TABLE Empresas (
    EmpresaID INT IDENTITY(1,1) NOT NULL,
    RazonSocial VARCHAR(150) NOT NULL,
    CUIT VARCHAR(20) NOT NULL,
    Activo BIT NOT NULL CONSTRAINT DF_Empresas_Activo DEFAULT (1),
    FechaCreacion DATETIME2(3) NOT NULL CONSTRAINT DF_Empresas_FechaCreacion DEFAULT (SYSDATETIME()),
    CONSTRAINT PK_Empresas PRIMARY KEY CLUSTERED (EmpresaID),
    CONSTRAINT UQ_Empresas_CUIT UNIQUE (CUIT)
);

CREATE TABLE Monedas (
    MonedaID INT IDENTITY(1,1) NOT NULL,
    CodigoISO VARCHAR(3) NOT NULL,
    Nombre VARCHAR(100) NOT NULL,
    Simbolo VARCHAR(10) NULL,
    Activa BIT NOT NULL CONSTRAINT DF_Monedas_Activa DEFAULT (1),
    CONSTRAINT PK_Monedas PRIMARY KEY CLUSTERED (MonedaID),
    CONSTRAINT UQ_Monedas_CodigoISO UNIQUE (CodigoISO)
);

CREATE TABLE Cotizaciones (
    CotizacionID BIGINT IDENTITY(1,1) NOT NULL,
    MonedaID INT NOT NULL,
    Cotizacion DECIMAL(18,6) NOT NULL,
    FechaCotizacion DATETIME2(3) NOT NULL CONSTRAINT DF_Cotizaciones_Fecha DEFAULT (SYSDATETIME()),
    CONSTRAINT PK_Cotizaciones PRIMARY KEY CLUSTERED (CotizacionID),
    CONSTRAINT FK_Cotizaciones_Monedas FOREIGN KEY (MonedaID) REFERENCES Monedas(MonedaID),
    CONSTRAINT UQ_Cotizaciones_Moneda_Fecha UNIQUE (MonedaID, FechaCotizacion),
    CONSTRAINT CK_Cotizaciones_ValorPositivo CHECK (Cotizacion > 0)
);

CREATE TABLE ParametrosGenerales (
    ParametroGeneralID INT IDENTITY(1,1) NOT NULL,
    EmpresaID INT NOT NULL,
    MonedaPrincipalID INT NOT NULL,
    MonedaSecundariaID INT NOT NULL,
    -- #aprobacionColaMl: si está activo, las publicaciones de CATÁLOGO suben el precio a
    -- ML sin pedir aprobación humana. Las que no son de catálogo SIEMPRE piden aprobación,
    -- sin importar este flag (no hay competencia confiable para validar automáticamente).
    SubidaAutomaticaCatalogoML BIT NOT NULL CONSTRAINT DF_ParametrosGenerales_SubidaAutoML DEFAULT (0),
    CONSTRAINT PK_ParametrosGenerales PRIMARY KEY CLUSTERED (ParametroGeneralID),
    CONSTRAINT FK_ParametrosGenerales_Empresas FOREIGN KEY (EmpresaID) REFERENCES Empresas(EmpresaID),
    CONSTRAINT FK_ParametrosGenerales_MonedaPrincipal FOREIGN KEY (MonedaPrincipalID) REFERENCES Monedas(MonedaID),
    CONSTRAINT FK_ParametrosGenerales_MonedaSecundaria FOREIGN KEY (MonedaSecundariaID) REFERENCES Monedas(MonedaID),
    CONSTRAINT UQ_ParametrosGenerales_Empresa UNIQUE (EmpresaID),
    CONSTRAINT CK_ParametrosGenerales_MonedasDistintas CHECK (MonedaPrincipalID <> MonedaSecundariaID)
);

CREATE TABLE CuentasML (
    CuentaMLID INT IDENTITY(1,1) NOT NULL,
    EmpresaID INT NOT NULL,
    UserIDML VARCHAR(50) NOT NULL,
    NicknameML VARCHAR(100) NOT NULL,
    AccessToken VARCHAR(MAX) NULL,
    RefreshToken VARCHAR(MAX) NULL,
    FechaVencimientoToken DATETIME2(3) NULL,
    Activo BIT NOT NULL CONSTRAINT DF_CuentasML_Activo DEFAULT (1),
    CONSTRAINT PK_CuentasML PRIMARY KEY CLUSTERED (CuentaMLID),
    CONSTRAINT FK_CuentasML_Empresas FOREIGN KEY (EmpresaID) REFERENCES Empresas(EmpresaID)
);

-- ----------------------------------------------------------------------------
-- 2. MODELO CORE DE PRODUCTOS, COSTOS Y PUBLICACIONES
-- ----------------------------------------------------------------------------

CREATE TABLE Productos (
    ProductoID INT IDENTITY(1,1) NOT NULL,
    EmpresaID INT NOT NULL,
    SKU VARCHAR(50) NOT NULL,
    Titulo VARCHAR(255) NOT NULL,
    CategoriaID VARCHAR(50) NULL,
    Marca VARCHAR(100) NULL,
    Modelo VARCHAR(100) NULL,
    Activo BIT NOT NULL CONSTRAINT DF_Productos_Activo DEFAULT (1),
    FechaCreacion DATETIME2(3) NOT NULL CONSTRAINT DF_Productos_FechaCreacion DEFAULT (SYSDATETIME()),
    CONSTRAINT PK_Productos PRIMARY KEY CLUSTERED (ProductoID),
    CONSTRAINT FK_Productos_Empresas FOREIGN KEY (EmpresaID) REFERENCES Empresas(EmpresaID),
    CONSTRAINT UQ_Productos_Empresa_SKU UNIQUE (EmpresaID, SKU)
);

CREATE TABLE CostosProducto (
    CostoID INT IDENTITY(1,1) NOT NULL,
    ProductoID INT NOT NULL,
    CostoCompra DECIMAL(18,4) NOT NULL,
    PorcentajeIVA DECIMAL(5,2) NOT NULL CONSTRAINT DF_Costos_IVA DEFAULT (21.00),
    ImpuestosInternos DECIMAL(18,4) NOT NULL CONSTRAINT DF_Costos_ImpInternos DEFAULT (0),
    CostoEnvioPromedio DECIMAL(18,4) NOT NULL CONSTRAINT DF_Costos_Envio DEFAULT (0),
    CostoLogisticoFijo DECIMAL(18,4) NOT NULL CONSTRAINT DF_Costos_Logistico DEFAULT (0),
    CostoFinancieroPorc DECIMAL(5,2) NOT NULL CONSTRAINT DF_Costos_Financiero DEFAULT (0),
    CostoPublicidadPorc DECIMAL(5,2) NOT NULL CONSTRAINT DF_Costos_Publicidad DEFAULT (0),
    OtrosCostosFijos DECIMAL(18,4) NOT NULL CONSTRAINT DF_Costos_Otros DEFAULT (0),
    FechaUltimaActualizacion DATETIME2(3) NOT NULL CONSTRAINT DF_Costos_Fecha DEFAULT (SYSDATETIME()),
    CONSTRAINT PK_CostosProducto PRIMARY KEY CLUSTERED (CostoID),
    CONSTRAINT FK_CostosProducto_Productos FOREIGN KEY (ProductoID) REFERENCES Productos(ProductoID),
    CONSTRAINT UQ_CostosProducto_Producto UNIQUE (ProductoID)
);

CREATE TABLE PublicacionesML (
    PublicacionID INT IDENTITY(1,1) NOT NULL,
    ProductoID INT NOT NULL,
    CuentaMLID INT NOT NULL,
    MeliItemID VARCHAR(50) NOT NULL,
    TipoPublicacion VARCHAR(30) NOT NULL, -- gold_pro, gold_special, etc.
    ComisionMLPorc DECIMAL(5,2) NOT NULL,
    Estado VARCHAR(20) NOT NULL, -- active, paused, closed
    EsCatalogo BIT NOT NULL CONSTRAINT DF_Publicaciones_Catalogo DEFAULT (0),
    PrecioActual DECIMAL(18,4) NOT NULL,
    PrecioMinimoPermitido DECIMAL(18,4) NOT NULL,
    PrecioMaximoPermitido DECIMAL(18,4) NOT NULL,
    PrecioObjetivo DECIMAL(18,4) NULL,
    FechaUltimoCambioPrecio DATETIME2(3) NULL,
    CONSTRAINT PK_PublicacionesML PRIMARY KEY CLUSTERED (PublicacionID),
    CONSTRAINT FK_PublicacionesML_Productos FOREIGN KEY (ProductoID) REFERENCES Productos(ProductoID),
    CONSTRAINT FK_PublicacionesML_CuentasML FOREIGN KEY (CuentaMLID) REFERENCES CuentasML(CuentaMLID),
    CONSTRAINT UQ_PublicacionesML_ItemID UNIQUE (MeliItemID)
);

-- ----------------------------------------------------------------------------
-- 3. STOCK Y VENTAS HISTÓRICAS
-- ----------------------------------------------------------------------------

CREATE TABLE StockEstado (
    StockID INT IDENTITY(1,1) NOT NULL,
    ProductoID INT NOT NULL,
    StockActual INT NOT NULL,
    StockReservado INT NOT NULL CONSTRAINT DF_Stock_Reservado DEFAULT (0),
    StockDisponible AS (StockActual - StockReservado),
    StockMinimo INT NOT NULL CONSTRAINT DF_Stock_Min DEFAULT (5),
    StockMaximo INT NOT NULL CONSTRAINT DF_Stock_Max DEFAULT (100),
    StockObjetivo INT NOT NULL CONSTRAINT DF_Stock_Obj DEFAULT (30),
    FechaActualizacion DATETIME2(3) NOT NULL CONSTRAINT DF_Stock_Fecha DEFAULT (SYSDATETIME()),
    CONSTRAINT PK_StockEstado PRIMARY KEY CLUSTERED (StockID),
    CONSTRAINT FK_StockEstado_Productos FOREIGN KEY (ProductoID) REFERENCES Productos(ProductoID),
    CONSTRAINT UQ_StockEstado_Producto UNIQUE (ProductoID)
);

-- #loginGeneralApp: usuario+contraseña para toda la superficie de la app que antes
-- era de acceso libre (AdminPanel, Cola ML, Integraciones, Reportes, Pricing). Alcance
-- global (no por Empresa, a diferencia de Repositor): ve todas las Empresas de la
-- instalación, igual que ya operan hoy esas pantallas sin filtrar. El Rol distingue
-- quién puede aprobar/vincular (ADMIN) de quién solo consulta (LECTURA).
CREATE TABLE Usuarios (
    UsuarioID INT IDENTITY(1,1) NOT NULL,
    NombreCompleto VARCHAR(150) NOT NULL,
    Usuario VARCHAR(50) NOT NULL,
    PasswordHash VARBINARY(64) NOT NULL,
    PasswordSalt VARBINARY(32) NOT NULL,
    Rol VARCHAR(20) NOT NULL CONSTRAINT DF_Usuarios_Rol DEFAULT ('ADMIN'),
    Email VARCHAR(200) NULL,
    Activo BIT NOT NULL CONSTRAINT DF_Usuarios_Activo DEFAULT (1),
    FechaCreacion DATETIME2(3) NOT NULL CONSTRAINT DF_Usuarios_FechaCreacion DEFAULT (SYSDATETIME()),
    CONSTRAINT PK_Usuarios PRIMARY KEY CLUSTERED (UsuarioID),
    CONSTRAINT UQ_Usuarios_Usuario UNIQUE (Usuario),
    CONSTRAINT CK_Usuarios_Rol CHECK (Rol IN ('ADMIN','LECTURA'))
);

-- Qué secciones de la app puede VER cada Usuario (Pricing, Formularios, Reportes,
-- etc.). Control de visibilidad en la UI — el límite real de escritura sigue siendo
-- el Rol de Usuarios, aplicado parejo a toda la API.
CREATE TABLE UsuarioSecciones (
    UsuarioID INT NOT NULL,
    Seccion VARCHAR(50) NOT NULL,
    CONSTRAINT PK_UsuarioSecciones PRIMARY KEY CLUSTERED (UsuarioID, Seccion),
    CONSTRAINT FK_UsuarioSecciones_Usuarios FOREIGN KEY (UsuarioID) REFERENCES Usuarios(UsuarioID) ON DELETE CASCADE
);

-- Credenciales del servidor SMTP, configurables desde la UI. Fila única: una app de
-- email por instalación, mismo patrón que ConfiguracionMercadoLibre.
CREATE TABLE ConfiguracionEmail (
    ConfiguracionEmailID INT IDENTITY(1,1) NOT NULL,
    SmtpHost VARCHAR(200) NULL,
    SmtpPort INT NULL,
    SmtpUsuario VARCHAR(200) NULL,
    SmtpPassword VARCHAR(200) NULL,
    UsarSsl BIT NOT NULL CONSTRAINT DF_ConfiguracionEmail_UsarSsl DEFAULT (1),
    EmailDesde VARCHAR(200) NULL,
    NombreDesde VARCHAR(150) NULL,
    FrontendBaseUrl VARCHAR(300) NULL,
    FechaActualizacion DATETIME2(3) NULL,
    CONSTRAINT PK_ConfiguracionEmail PRIMARY KEY CLUSTERED (ConfiguracionEmailID)
);

-- Token de un solo uso para el link de "olvidé mi contraseña" (ver ADR 0017).
CREATE TABLE PasswordResetTokens (
    TokenID INT IDENTITY(1,1) NOT NULL,
    UsuarioID INT NOT NULL,
    Token VARCHAR(100) NOT NULL,
    FechaCreacion DATETIME2(3) NOT NULL CONSTRAINT DF_PasswordResetTokens_Fecha DEFAULT (SYSDATETIME()),
    FechaExpiracion DATETIME2(3) NOT NULL,
    Usado BIT NOT NULL CONSTRAINT DF_PasswordResetTokens_Usado DEFAULT (0),
    CONSTRAINT PK_PasswordResetTokens PRIMARY KEY CLUSTERED (TokenID),
    CONSTRAINT UQ_PasswordResetTokens_Token UNIQUE (Token),
    CONSTRAINT FK_PasswordResetTokens_Usuarios FOREIGN KEY (UsuarioID) REFERENCES Usuarios(UsuarioID)
);

-- Sesiones de Usuario persistidas en la base (no solo en memoria) para que un reinicio
-- de la API no desloguee a todo el mundo. NombreCompleto/Rol/SeccionesCsv son una copia
-- tomada en el momento del login, no se releen de Usuarios/UsuarioSecciones en cada
-- request — cambios de permisos solo se ven en el próximo login (ver ADR 0018).
CREATE TABLE UsuarioSesiones (
    SesionID BIGINT IDENTITY(1,1) NOT NULL,
    Token VARCHAR(100) NOT NULL,
    UsuarioID INT NOT NULL,
    NombreCompleto VARCHAR(150) NOT NULL,
    Rol VARCHAR(20) NOT NULL,
    SeccionesCsv VARCHAR(500) NULL,
    FechaCreacion DATETIME2(3) NOT NULL CONSTRAINT DF_UsuarioSesiones_Fecha DEFAULT (SYSDATETIME()),
    FechaExpiracion DATETIME2(3) NOT NULL,
    CONSTRAINT PK_UsuarioSesiones PRIMARY KEY CLUSTERED (SesionID),
    CONSTRAINT UQ_UsuarioSesiones_Token UNIQUE (Token),
    CONSTRAINT FK_UsuarioSesiones_Usuarios FOREIGN KEY (UsuarioID) REFERENCES Usuarios(UsuarioID)
);

-- Configuración de la ejecución automática del ciclo completo (ERP -> evaluar todos
-- los productos -> procesar cola ML -> sincronizar ML). Fila única, mismo patrón que
-- ConfiguracionEmail/ConfiguracionMercadoLibre (ver ADR 0019).
CREATE TABLE ConfiguracionEjecucionAutomatica (
    ConfiguracionEjecucionAutomaticaID INT IDENTITY(1,1) NOT NULL,
    Activo BIT NOT NULL CONSTRAINT DF_ConfigEjecAuto_Activo DEFAULT (0),
    IntervaloMinutos INT NOT NULL CONSTRAINT DF_ConfigEjecAuto_Intervalo DEFAULT (30),
    UltimaEjecucion DATETIME2(3) NULL,
    UltimoResultadoOk BIT NULL,
    UltimoResultadoResumen VARCHAR(1000) NULL,
    FechaActualizacion DATETIME2(3) NULL,
    CONSTRAINT PK_ConfigEjecAuto PRIMARY KEY CLUSTERED (ConfiguracionEjecucionAutomaticaID)
);

-- #cargaOperativaRepositor: cuenta de un repositor (sin ERP) que carga recuentos de
-- stock a mano desde una pantalla dedicada (no el ABM completo). Login simple por
-- Usuario+PIN, solo para trazabilidad de quién cargó qué.
CREATE TABLE Repositores (
    RepositorID INT IDENTITY(1,1) NOT NULL,
    EmpresaID INT NOT NULL,
    NombreCompleto VARCHAR(150) NOT NULL,
    Usuario VARCHAR(50) NOT NULL,
    PinHash VARBINARY(64) NOT NULL,
    PinSalt VARBINARY(32) NOT NULL,
    Activo BIT NOT NULL CONSTRAINT DF_Repositores_Activo DEFAULT (1),
    FechaCreacion DATETIME2(3) NOT NULL CONSTRAINT DF_Repositores_FechaCreacion DEFAULT (SYSDATETIME()),
    CONSTRAINT PK_Repositores PRIMARY KEY CLUSTERED (RepositorID),
    CONSTRAINT FK_Repositores_Empresas FOREIGN KEY (EmpresaID) REFERENCES Empresas(EmpresaID),
    CONSTRAINT UQ_Repositores_Usuario UNIQUE (Usuario)
);

-- Recuento absoluto de stock cargado por un Repositor: registro inmutable de auditoría
-- (quién, cuándo, de cuánto a cuánto), separado de StockEstado que solo guarda el valor vigente.
CREATE TABLE StockCargas (
    StockCargaID BIGINT IDENTITY(1,1) NOT NULL,
    ProductoID INT NOT NULL,
    RepositorID INT NOT NULL,
    StockAnterior INT NOT NULL,
    StockNuevo INT NOT NULL,
    FechaCarga DATETIME2(3) NOT NULL CONSTRAINT DF_StockCargas_Fecha DEFAULT (SYSDATETIME()),
    CONSTRAINT PK_StockCargas PRIMARY KEY CLUSTERED (StockCargaID),
    CONSTRAINT FK_StockCargas_Productos FOREIGN KEY (ProductoID) REFERENCES Productos(ProductoID),
    CONSTRAINT FK_StockCargas_Repositores FOREIGN KEY (RepositorID) REFERENCES Repositores(RepositorID)
);

-- #integracionErp: el motor actúa como cliente activo contra el ERP del cliente (igual
-- que los conectores de marketplace): puede recibir un POST del ERP (si el ERP sabe
-- llamar afuera) y puede salir a buscar datos con GET contra la API del ERP (si el ERP
-- expone una para leer). Ambos caminos comparten el mismo contrato canónico de items.
CREATE TABLE ErpConexiones (
    ErpConexionID INT IDENTITY(1,1) NOT NULL,
    EmpresaID INT NOT NULL,
    ApiKeyEntrante VARCHAR(100) NOT NULL,
    UrlSalida VARCHAR(500) NULL,
    ApiKeySaliente VARCHAR(200) NULL,
    Activo BIT NOT NULL CONSTRAINT DF_ErpConexiones_Activo DEFAULT (1),
    FechaCreacion DATETIME2(3) NOT NULL CONSTRAINT DF_ErpConexiones_FechaCreacion DEFAULT (SYSDATETIME()),
    UltimaSincronizacion DATETIME2(3) NULL,
    CONSTRAINT PK_ErpConexiones PRIMARY KEY CLUSTERED (ErpConexionID),
    CONSTRAINT FK_ErpConexiones_Empresas FOREIGN KEY (EmpresaID) REFERENCES Empresas(EmpresaID),
    CONSTRAINT UQ_ErpConexiones_Empresa UNIQUE (EmpresaID),
    CONSTRAINT UQ_ErpConexiones_ApiKeyEntrante UNIQUE (ApiKeyEntrante)
);

-- Vínculo manual de competidores para publicaciones que NO son de catálogo. ML no
-- define esta relación automáticamente ahí; el usuario busca en ML y elige a quién
-- vincular, ningún vínculo se crea sin esa confirmación explícita.
CREATE TABLE PublicacionCompetidoresManual (
    VinculoID INT IDENTITY(1,1) NOT NULL,
    PublicacionID INT NOT NULL,
    CompetidorItemID VARCHAR(50) NOT NULL,
    CompetidorTitulo VARCHAR(255) NULL,
    Activo BIT NOT NULL CONSTRAINT DF_PubCompManual_Activo DEFAULT (1),
    FechaVinculo DATETIME2(3) NOT NULL CONSTRAINT DF_PubCompManual_Fecha DEFAULT (SYSDATETIME()),
    -- #loginGeneralApp: qué Usuario confirmó este vínculo (ver ADR 0012).
    UsuarioVinculoID INT NULL,
    CONSTRAINT PK_PublicacionCompetidoresManual PRIMARY KEY CLUSTERED (VinculoID),
    CONSTRAINT FK_PubCompManual_Publicacion FOREIGN KEY (PublicacionID) REFERENCES PublicacionesML(PublicacionID),
    CONSTRAINT FK_PubCompManual_Usuarios FOREIGN KEY (UsuarioVinculoID) REFERENCES Usuarios(UsuarioID),
    CONSTRAINT UQ_PubCompManual_Publicacion_Item UNIQUE (PublicacionID, CompetidorItemID)
);

-- Credenciales de la app de MercadoLibre, configurables desde la UI. Fila única: una
-- app de ML por instalación, autorizada por cada Cuenta ML vía OAuth.
CREATE TABLE ConfiguracionMercadoLibre (
    ConfiguracionMercadoLibreID INT IDENTITY(1,1) NOT NULL,
    ClientId VARCHAR(200) NULL,
    ClientSecret VARCHAR(200) NULL,
    ApiBaseUrl VARCHAR(300) NULL,
    -- #oauthConexionCuentaMl: a qué sitio de ML mandar al vendedor a loguearse
    -- (MLA/MLB/MLM/MLC...) y la redirect_uri que tiene que matchear EXACTO con lo
    -- registrado en la app de ML (si no, ML rechaza la autorización).
    SiteId VARCHAR(10) NULL,
    RedirectUri VARCHAR(500) NULL,
    FechaActualizacion DATETIME2(3) NOT NULL CONSTRAINT DF_ConfigML_Fecha DEFAULT (SYSDATETIME()),
    CONSTRAINT PK_ConfiguracionMercadoLibre PRIMARY KEY CLUSTERED (ConfiguracionMercadoLibreID)
);

-- Mapeo configurable de campos ERP -> contrato canónico, para adaptarse a CUALQUIER
-- ERP sin escribir código nuevo por cliente (cada instalación conecta a un solo ERP).
CREATE TABLE ErpCampoMapeos (
    ErpCampoMapeoID INT IDENTITY(1,1) NOT NULL,
    EmpresaID INT NOT NULL,
    CampoCanonico VARCHAR(50) NOT NULL,
    CampoOrigen VARCHAR(200) NOT NULL,
    CONSTRAINT PK_ErpCampoMapeos PRIMARY KEY CLUSTERED (ErpCampoMapeoID),
    CONSTRAINT FK_ErpCampoMapeos_Empresas FOREIGN KEY (EmpresaID) REFERENCES Empresas(EmpresaID),
    CONSTRAINT UQ_ErpCampoMapeos_Empresa_Campo UNIQUE (EmpresaID, CampoCanonico)
);

-- Auditoría de cada sincronización (entrante o saliente), para trazabilidad y para
-- mostrar en UI la última corrida (cantidad de items, errores).
CREATE TABLE ErpSincronizaciones (
    ErpSincronizacionID BIGINT IDENTITY(1,1) NOT NULL,
    EmpresaID INT NOT NULL,
    Direccion VARCHAR(10) NOT NULL,
    CantidadProcesados INT NOT NULL,
    CantidadErrores INT NOT NULL,
    DetalleErrores VARCHAR(MAX) NULL,
    FechaSincronizacion DATETIME2(3) NOT NULL CONSTRAINT DF_ErpSync_Fecha DEFAULT (SYSDATETIME()),
    CONSTRAINT PK_ErpSincronizaciones PRIMARY KEY CLUSTERED (ErpSincronizacionID),
    CONSTRAINT FK_ErpSincronizaciones_Empresas FOREIGN KEY (EmpresaID) REFERENCES Empresas(EmpresaID)
);

CREATE TABLE MetricasVentasHist (
    MetricaID INT IDENTITY(1,1) NOT NULL,
    PublicacionID INT NOT NULL,
    VentasHoy INT NOT NULL DEFAULT 0,
    Ventas7D INT NOT NULL DEFAULT 0,
    Ventas15D INT NOT NULL DEFAULT 0,
    Ventas30D INT NOT NULL DEFAULT 0,
    Ventas60D INT NOT NULL DEFAULT 0,
    Ventas90D INT NOT NULL DEFAULT 0,
    VelocidadVentaDiaria DECIMAL(10,4) NOT NULL DEFAULT 0, -- Ventas30D / 30.0
    TendenciaPorc DECIMAL(7,2) NOT NULL DEFAULT 0, -- Comparativa 15D vs periodo anterior
    DiasStockDisponibles AS (
        CASE WHEN VelocidadVentaDiaria > 0 THEN NULL -- Se calcula dinámicamente según stock
             ELSE 9999 END
    ),
    FechaCalculo DATETIME2(3) NOT NULL CONSTRAINT DF_Metricas_Fecha DEFAULT (SYSDATETIME()),
    CONSTRAINT PK_MetricasVentasHist PRIMARY KEY CLUSTERED (MetricaID),
    CONSTRAINT FK_MetricasVentasHist_Publicaciones FOREIGN KEY (PublicacionID) REFERENCES PublicacionesML(PublicacionID),
    CONSTRAINT UQ_MetricasVentas_Publicacion UNIQUE (PublicacionID)
);

-- ----------------------------------------------------------------------------
-- 4. SNAPSHOTS DE COMPETENCIA
-- ----------------------------------------------------------------------------

CREATE TABLE CompetenciaSnapshot (
    SnapshotID BIGINT IDENTITY(1,1) NOT NULL,
    PublicacionID INT NOT NULL,
    CompetidorItemID VARCHAR(50) NOT NULL,
    CompetidorVendedorID VARCHAR(50) NULL,
    PrecioCompetidor DECIMAL(18,4) NOT NULL,
    StockCompetidor INT NULL,
    TipoPublicacion VARCHAR(30) NULL,
    OfreceEnvioGratis BIT NOT NULL DEFAULT 0,
    EsCompetidorDirecto BIT NOT NULL DEFAULT 1,
    NivelRelevancia INT NOT NULL DEFAULT 1, -- 1: Alto (Ganador Catálogo), 2: Medio, 3: Bajo
    FechaCaptura DATETIME2(3) NOT NULL CONSTRAINT DF_CompSnap_Fecha DEFAULT (SYSDATETIME()),
    CONSTRAINT PK_CompetenciaSnapshot PRIMARY KEY CLUSTERED (SnapshotID),
    CONSTRAINT FK_CompetenciaSnapshot_Publicacion FOREIGN KEY (PublicacionID) REFERENCES PublicacionesML(PublicacionID)
);

-- ----------------------------------------------------------------------------
-- 5. MOTOR DE REGLAS, ESTRATEGIAS Y PARÁMETROS
-- ----------------------------------------------------------------------------

CREATE TABLE Estrategias (
    EstrategiaID INT IDENTITY(1,1) NOT NULL,
    EmpresaID INT NOT NULL,
    NombreEstrategia VARCHAR(100) NOT NULL, -- ESTRATEGIA_AGRESIVA, ESTRATEGIA_MARGEN, etc.
    Descripcion VARCHAR(255) NULL,
    Activa BIT NOT NULL CONSTRAINT DF_Estrategias_Activa DEFAULT (1),
    CONSTRAINT PK_Estrategias PRIMARY KEY CLUSTERED (EstrategiaID),
    CONSTRAINT FK_Estrategias_Empresas FOREIGN KEY (EmpresaID) REFERENCES Empresas(EmpresaID)
);

CREATE TABLE ReglasNegocio (
    ReglaID INT IDENTITY(1,1) NOT NULL,
    CodigoRegla VARCHAR(50) NOT NULL, -- REGLA_MARGEN_MINIMO, REGLA_STOCK_CRITICO, etc.
    Nombre VARCHAR(100) NOT NULL,
    TipoRegla VARCHAR(30) NOT NULL, -- HARD_RESTRICTION, OPERATIONAL, MARKET, OPPORTUNITY
    Descripcion VARCHAR(255) NULL,
    Activa BIT NOT NULL CONSTRAINT DF_Reglas_Activa DEFAULT (1),
    CONSTRAINT PK_ReglasNegocio PRIMARY KEY CLUSTERED (ReglaID),
    CONSTRAINT UQ_ReglasNegocio_Codigo UNIQUE (CodigoRegla)
);

CREATE TABLE EstrategiaReglas (
    EstrategiaReglaID INT IDENTITY(1,1) NOT NULL,
    EstrategiaID INT NOT NULL,
    ReglaID INT NOT NULL,
    Prioridad INT NOT NULL, -- Menor número = Mayor Prioridad (1 es máxima prioridad)
    ParametrosJSON VARCHAR(MAX) NULL, -- Guardará configuraciones locales por regla (ej: {"MargenMinimo": 15.0})
    Activa BIT NOT NULL CONSTRAINT DF_EstrategiaReglas_Activa DEFAULT (1),
    CONSTRAINT PK_EstrategiaReglas PRIMARY KEY CLUSTERED (EstrategiaReglaID),
    CONSTRAINT FK_EstrategiaReglas_Estrategia FOREIGN KEY (EstrategiaID) REFERENCES Estrategias(EstrategiaID),
    CONSTRAINT FK_EstrategiaReglas_Regla FOREIGN KEY (ReglaID) REFERENCES ReglasNegocio(ReglaID),
    CONSTRAINT UQ_Estrategia_Regla UNIQUE (EstrategiaID, ReglaID)
);

CREATE TABLE EstrategiaReglaParametros (
    ParametroID INT IDENTITY(1,1) NOT NULL,
    EstrategiaReglaID INT NOT NULL,
    Clave VARCHAR(100) NOT NULL,
    Valor DECIMAL(18,4) NOT NULL,
    Descripcion VARCHAR(255) NULL,
    FechaVigencia DATETIME2(3) NOT NULL CONSTRAINT DF_EstrategiaReglaParametros_FechaVigencia DEFAULT (SYSDATETIME()),
    FechaFin DATETIME2(3) NULL,
    Activo BIT NOT NULL CONSTRAINT DF_EstrategiaReglaParametros_Activo DEFAULT (1),
    FechaCreacion DATETIME2(3) NOT NULL CONSTRAINT DF_EstrategiaReglaParametros_FechaCreacion DEFAULT (SYSDATETIME()),
    CONSTRAINT PK_EstrategiaReglaParametros PRIMARY KEY CLUSTERED (ParametroID),
    CONSTRAINT FK_EstrategiaReglaParametros_EstrategiaRegla FOREIGN KEY (EstrategiaReglaID) REFERENCES EstrategiaReglas(EstrategiaReglaID),
    CONSTRAINT UQ_EstrategiaRegla_Clave_Vigente UNIQUE (EstrategiaReglaID, Clave, FechaFin)
);

CREATE TABLE EstrategiaReglaParametrosMensajes (
    MensajeID INT IDENTITY(1,1) NOT NULL,
    EstrategiaReglaID INT NOT NULL,
    Clave VARCHAR(100) NOT NULL,
    Idioma VARCHAR(5) NOT NULL CONSTRAINT DF_EstrategiaReglaParametrosMensajes_Idioma DEFAULT ('ES'),
    Valor NVARCHAR(MAX) NOT NULL,
    Descripcion VARCHAR(255) NULL,
    FechaVigencia DATETIME2(3) NOT NULL CONSTRAINT DF_EstrategiaReglaParametrosMensajes_FechaVigencia DEFAULT (SYSDATETIME()),
    FechaFin DATETIME2(3) NULL,
    Activo BIT NOT NULL CONSTRAINT DF_EstrategiaReglaParametrosMensajes_Activo DEFAULT (1),
    FechaCreacion DATETIME2(3) NOT NULL CONSTRAINT DF_EstrategiaReglaParametrosMensajes_FechaCreacion DEFAULT (SYSDATETIME()),
    CONSTRAINT PK_EstrategiaReglaParametrosMensajes PRIMARY KEY CLUSTERED (MensajeID),
    CONSTRAINT FK_EstrategiaReglaParametrosMensajes_EstrategiaRegla FOREIGN KEY (EstrategiaReglaID) REFERENCES EstrategiaReglas(EstrategiaReglaID),
    CONSTRAINT UQ_EstrategiaRegla_Clave_Mensaje_Vigente UNIQUE (EstrategiaReglaID, Clave, Idioma, FechaFin)
);

CREATE TABLE ConfiguracionParametros (
    ParametroID INT IDENTITY(1,1) NOT NULL,
    EmpresaID INT NOT NULL,
    ClaveParametro VARCHAR(100) NOT NULL,
    ValorParametro VARCHAR(255) NOT NULL,
    Descripcion VARCHAR(255) NULL,
    CONSTRAINT PK_ConfiguracionParametros PRIMARY KEY CLUSTERED (ParametroID),
    CONSTRAINT FK_ConfiguracionParametros_Empresa FOREIGN KEY (EmpresaID) REFERENCES Empresas(EmpresaID),
    CONSTRAINT UQ_Empresa_ClaveParametro UNIQUE (EmpresaID, ClaveParametro)
);

-- ----------------------------------------------------------------------------
-- 6. AUDITORÍA, HISTORIAL Y AUDIT TRAIL EXPLICABLE
-- ----------------------------------------------------------------------------

CREATE TABLE DecisionesHistorial (
    DecisionID BIGINT IDENTITY(1,1) NOT NULL,
    EmpresaID INT NOT NULL,
    PublicacionID INT NOT NULL,
    EstrategiaID INT NOT NULL,
    PrecioAnterior DECIMAL(18,4) NOT NULL,
    PrecioCalculado DECIMAL(18,4) NOT NULL,
    PrecioSugerido DECIMAL(18,4) NOT NULL,
    Accion VARCHAR(50) NOT NULL, -- MANTENER, AUMENTAR, DISMINUIR, PAUSAR, REACTIVAR
    Motivo VARCHAR(500) NOT NULL,
    ReglaGanadoraID INT NULL,
    PrioridadAplicada INT NOT NULL,
    MargenActualPorc DECIMAL(7,2) NOT NULL,
    MargenProyectadoPorc DECIMAL(7,2) NOT NULL,
    PosicionCompetitiva INT NULL,
    PrecioCompetenciaRef DECIMAL(18,4) NULL,
    CompetidorItemIDRef VARCHAR(50) NULL,
    StockDisponible INT NOT NULL,
    ClasificacionStock VARCHAR(20) NOT NULL, -- CRITICO, BAJO, NORMAL, ALTO, EXCESO
    ScoreConfianza DECIMAL(5,2) NOT NULL,
    EsSimulacion BIT NOT NULL DEFAULT 0,
    FechaDecision DATETIME2(3) NOT NULL CONSTRAINT DF_Decisiones_Fecha DEFAULT (SYSDATETIME()),
    CONSTRAINT PK_DecisionesHistorial PRIMARY KEY CLUSTERED (DecisionID),
    CONSTRAINT FK_DecisionesHistorial_Publicacion FOREIGN KEY (PublicacionID) REFERENCES PublicacionesML(PublicacionID),
    CONSTRAINT FK_DecisionesHistorial_Empresa FOREIGN KEY (EmpresaID) REFERENCES Empresas(EmpresaID)
);

CREATE TABLE DecisionesDetalleAuditoria (
    AuditoriaID BIGINT IDENTITY(1,1) NOT NULL,
    DecisionID BIGINT NOT NULL,
    ReglaID INT NOT NULL,
    Prioridad INT NOT NULL,
    EvaluacionResultado VARCHAR(30) NOT NULL, -- APLICADA, DESCARTADA_POR_BLOQUEO, NO_CUMPLE_CONDICION
    ValorPrecioPropuesto DECIMAL(18,4) NULL,
    DetalleJSON VARCHAR(MAX) NULL,
    CONSTRAINT PK_DecisionesDetalleAuditoria PRIMARY KEY CLUSTERED (AuditoriaID),
    CONSTRAINT FK_Auditoria_Decision FOREIGN KEY (DecisionID) REFERENCES DecisionesHistorial(DecisionID) ON DELETE CASCADE
);

CREATE TABLE ColaEjecucionML (
    ColaID BIGINT IDENTITY(1,1) NOT NULL,
    PublicacionID INT NOT NULL,
    MeliItemID VARCHAR(50) NOT NULL,
    PrecioNuevo DECIMAL(18,4) NOT NULL,
    AccionRequerida VARCHAR(30) NOT NULL,
    EstadoEjecucion VARCHAR(20) NOT NULL CONSTRAINT DF_Cola_Estado DEFAULT ('PENDIENTE'), -- PENDIENTE, PROCESADO, ERROR
    MensajeError VARCHAR(MAX) NULL,
    -- #aprobacionColaMl: fila autocontenida para la pantalla de aprobación, sin
    -- necesitar join a DecisionesHistorial. RequiereAprobacion=1 y Aprobado=NULL
    -- significa "esperando revisión humana"; el consumidor de la cola solo procesa
    -- filas con RequiereAprobacion=0 o Aprobado=1.
    Motivo VARCHAR(500) NULL,
    CompetidorItemIDRef VARCHAR(50) NULL,
    PrecioCompetidorRef DECIMAL(18,4) NULL,
    RequiereAprobacion BIT NOT NULL CONSTRAINT DF_ColaEjecucionML_RequiereAprobacion DEFAULT (0),
    Aprobado BIT NULL,
    FechaAprobacion DATETIME2(3) NULL,
    -- #loginGeneralApp: qué Usuario aprobó/rechazó esta fila (ver ADR 0012).
    UsuarioAprobacionID INT NULL,
    FechaCreacion DATETIME2(3) NOT NULL CONSTRAINT DF_Cola_Fecha DEFAULT (SYSDATETIME()),
    FechaProcesado DATETIME2(3) NULL,
    CONSTRAINT PK_ColaEjecucionML PRIMARY KEY CLUSTERED (ColaID),
    CONSTRAINT FK_ColaEjecucionML_Usuarios FOREIGN KEY (UsuarioAprobacionID) REFERENCES Usuarios(UsuarioID)
);

-- ----------------------------------------------------------------------------
-- ÍNDICES DE ALTO RENDIMIENTO (PERFORMANCE INDEXES)
-- ----------------------------------------------------------------------------

CREATE NONCLUSTERED INDEX IX_PublicacionesML_Producto_Cuenta 
ON PublicacionesML (ProductoID, CuentaMLID) INCLUDE (PrecioActual, Estado);

CREATE NONCLUSTERED INDEX IX_CompetenciaSnapshot_Publicacion_Fecha 
ON CompetenciaSnapshot (PublicacionID, FechaCaptura DESC) INCLUDE (PrecioCompetidor, EsCompetidorDirecto, NivelRelevancia);

CREATE NONCLUSTERED INDEX IX_DecisionesHistorial_Publicacion_Fecha 
ON DecisionesHistorial (PublicacionID, FechaDecision DESC);

CREATE NONCLUSTERED INDEX IX_ColaEjecucionML_Estado 
ON ColaEjecucionML (EstadoEjecucion) INCLUDE (MeliItemID, PrecioNuevo);

CREATE NONCLUSTERED INDEX IX_EstrategiaReglaParametrosMensajes_Vigentes
ON EstrategiaReglaParametrosMensajes (EstrategiaReglaID, Clave, Idioma, Activo, FechaVigencia)
INCLUDE (FechaFin, Valor);
GO
