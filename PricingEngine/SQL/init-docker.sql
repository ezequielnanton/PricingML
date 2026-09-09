-- Script de inicialización para SQL Server en Docker
-- Se ejecuta automáticamente al iniciar el contenedor

-- Esperar a que SQL Server esté listo
WAITFOR DELAY '00:00:05';

-- Crear base de datos si no existe
IF NOT EXISTS (SELECT * FROM sys.databases WHERE name = 'PRICES_DB')
BEGIN
    CREATE DATABASE PRICES_DB;
    PRINT 'Database PRICES_DB created successfully.';
END
ELSE
BEGIN
    PRINT 'Database PRICES_DB already exists.';
END

-- Usar la base de datos
USE PRICES_DB;
GO

-- Aquí irían las migraciones/scripts de creación de tablas
-- Por ahora, se ejecutarán desde la aplicación .NET o directamente si existen
PRINT 'PRICES_DB initialized.';
