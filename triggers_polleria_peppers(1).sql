/* =========================================================================
   PROYECTO: Sistema BD - Pollería Peppers (sede Los Olivos)
   CURSO: Base de Datos Avanzadas y Big Data - CIIN1021P
   OBJETIVO: Triggers de automatización que atacan los problemas
             detectados en el diagnóstico:
             (1) Falta de coordinación caja-cocina  -> Trigger de AUDITORÍA
             (2) Falta ocasional de insumos/stock   -> Trigger de INTEGRIDAD
   MOTOR: SQL Server (Management Studio / Azure Data Studio)
   ========================================================================= */

-- Puedes correr esto contra una BD nueva de pruebas:
-- CREATE DATABASE PolleriaPeppers;
-- GO
-- USE PolleriaPeppers;
-- GO

/* =========================================================================
   1. TABLAS BASE (según tu diagrama ER / modelo físico)
   Solo incluyo los campos necesarios para que los triggers sean
   ejecutables y probables. Ajusta nombres si en tu diagrama final
   difieren ligeramente.
   ========================================================================= */

IF OBJECT_ID('DetallePedido') IS NOT NULL DROP TABLE DetallePedido;
IF OBJECT_ID('Pedido') IS NOT NULL DROP TABLE Pedido;
IF OBJECT_ID('Producto') IS NOT NULL DROP TABLE Producto;
IF OBJECT_ID('Empleado') IS NOT NULL DROP TABLE Empleado;
IF OBJECT_ID('RegistroAuditoriaPedido') IS NOT NULL DROP TABLE RegistroAuditoriaPedido;
GO

CREATE TABLE Empleado (
    ID_Empleado         INT IDENTITY(1,1) PRIMARY KEY,
    NumeroDocumento     VARCHAR(20)  NOT NULL,
    Nombre              VARCHAR(50)  NOT NULL,
    ApellidoPaterno     VARCHAR(50)  NOT NULL
);
GO

CREATE TABLE Producto (
    ID_Producto     INT IDENTITY(1,1) PRIMARY KEY,
    Nombre          VARCHAR(100) NOT NULL,
    Precio          DECIMAL(8,2) NOT NULL,
    Categoria       VARCHAR(50)  NOT NULL,
    Stock           INT          NOT NULL DEFAULT 0
);
GO

CREATE TABLE Pedido (
    ID_Pedido       INT IDENTITY(1,1) PRIMARY KEY,
    Fecha           DATE NOT NULL DEFAULT CAST(GETDATE() AS DATE),
    Hora            TIME NOT NULL DEFAULT CAST(GETDATE() AS TIME),
    Estado          VARCHAR(20) NOT NULL DEFAULT 'Pendiente',
        -- Estados esperados: Pendiente, En preparación, Listo, Entregado
    ID_Empleado     INT NOT NULL,
    CONSTRAINT FK_Pedido_Empleado FOREIGN KEY (ID_Empleado) REFERENCES Empleado(ID_Empleado)
);
GO

CREATE TABLE DetallePedido (
    ID_Detalle              INT IDENTITY(1,1) PRIMARY KEY,
    Cantidad                INT NOT NULL,
    PrecioUnitarioHistorico DECIMAL(8,2) NOT NULL,
    Subtotal                DECIMAL(8,2) NOT NULL,
    ID_Pedido               INT NOT NULL,
    ID_Producto             INT NOT NULL,
    CONSTRAINT FK_Detalle_Pedido   FOREIGN KEY (ID_Pedido)   REFERENCES Pedido(ID_Pedido),
    CONSTRAINT FK_Detalle_Producto FOREIGN KEY (ID_Producto) REFERENCES Producto(ID_Producto)
);
GO

-- Tabla de LOG donde caerán los registros de auditoría (evidencia para la EP)
CREATE TABLE RegistroAuditoriaPedido (
    ID_Log          INT IDENTITY(1,1) PRIMARY KEY,
    ID_Pedido       INT NOT NULL,
    EstadoAnterior  VARCHAR(20) NOT NULL,
    EstadoNuevo     VARCHAR(20) NOT NULL,
    UsuarioSQL      VARCHAR(100) NOT NULL,
    FechaHoraCambio DATETIME2 NOT NULL DEFAULT SYSDATETIME()
);
GO

/* =========================================================================
   2. TRIGGER DE AUDITORÍA (DML) - trg_Auditoria_EstadoPedido
   ---------------------------------------------------------------------
   PROBLEMA QUE RESUELVE: "falta de coordinación entre caja y cocina"
   Cada vez que alguien (caja o cocina) actualiza el Estado de un pedido,
   este trigger deja registro automático de: pedido, estado anterior,
   estado nuevo, quién lo hizo y cuándo. Así cocina tiene trazabilidad
   real del orden de llegada y de quién movió qué, sin depender de la
   comunicación verbal.
   ========================================================================= */

CREATE OR ALTER TRIGGER trg_Auditoria_EstadoPedido
ON Pedido
AFTER UPDATE
AS
BEGIN
    SET NOCOUNT ON;

    -- IF UPDATE(Estado): solo actúa si la columna Estado fue parte del UPDATE
    IF UPDATE(Estado)
    BEGIN
        BEGIN TRY
            INSERT INTO RegistroAuditoriaPedido (ID_Pedido, EstadoAnterior, EstadoNuevo, UsuarioSQL)
            SELECT
                i.ID_Pedido,
                d.Estado,        -- estado ANTES del update (tabla mágica "deleted")
                i.Estado,        -- estado DESPUÉS del update (tabla mágica "inserted")
                SUSER_SNAME()    -- usuario de SQL Server que ejecutó el cambio
            FROM inserted i
            INNER JOIN deleted d ON i.ID_Pedido = d.ID_Pedido
            WHERE i.Estado <> d.Estado;   -- solo si realmente cambió el estado
        END TRY
        BEGIN CATCH
            -- Si el log falla, no debe tumbar la actualización del pedido
            PRINT 'Advertencia: no se pudo registrar auditoría. Error: ' + ERROR_MESSAGE();
        END CATCH
    END
END
GO

/* =========================================================================
   3. TRIGGER DE INTEGRIDAD - trg_ValidarStock_DetallePedido
   ---------------------------------------------------------------------
   PROBLEMA QUE RESUELVE: "falta ocasional de insumos"
   Antes de aceptar una línea de pedido, valida que el producto tenga
   stock suficiente. Si no lo hay, RECHAZA el insert completo con un
   mensaje claro (en vez de que cocina descubra la falta después y
   tenga que modificar el pedido sobre la marcha). Si hay stock,
   inserta el detalle Y descuenta el stock automáticamente.
   ========================================================================= */

CREATE OR ALTER TRIGGER trg_ValidarStock_DetallePedido
ON DetallePedido
INSTEAD OF INSERT
AS
BEGIN
    SET NOCOUNT ON;

    BEGIN TRY
        BEGIN TRANSACTION;

        -- Si CUALQUIER producto del lote insertado no tiene stock suficiente,
        -- se rechaza toda la operación (evita ventas parciales inconsistentes)
        IF EXISTS (
            SELECT 1
            FROM inserted i
            INNER JOIN Producto p ON i.ID_Producto = p.ID_Producto
            WHERE p.Stock < i.Cantidad
        )
        BEGIN
            RAISERROR('Stock insuficiente para uno o más productos del pedido. Operación cancelada.', 16, 1);
        END

        -- Inserta el/los detalle(s) que sí pasaron la validación
        INSERT INTO DetallePedido (Cantidad, PrecioUnitarioHistorico, Subtotal, ID_Pedido, ID_Producto)
        SELECT Cantidad, PrecioUnitarioHistorico, Subtotal, ID_Pedido, ID_Producto
        FROM inserted;

        -- Descuenta el stock del producto vendido
        UPDATE p
        SET p.Stock = p.Stock - i.Cantidad
        FROM Producto p
        INNER JOIN inserted i ON p.ID_Producto = i.ID_Producto;

        COMMIT TRANSACTION;
    END TRY
    BEGIN CATCH
        IF @@TRANCOUNT > 0 ROLLBACK TRANSACTION;
        -- Relanza el error para que la aplicación/caja sepa que el pedido no se pudo registrar
        THROW;
    END CATCH
END
GO

/* =========================================================================
   4. DATOS DE PRUEBA Y EJECUCIÓN (evidencia para la EP)
   ========================================================================= */

INSERT INTO Empleado (NumeroDocumento, Nombre, ApellidoPaterno) VALUES
('70112233', 'Kiara', 'Leon'),
('70223344', 'Christian', 'Loza');

INSERT INTO Producto (Nombre, Precio, Categoria, Stock) VALUES
('Pollo a la brasa entero', 55.00, 'Plato principal', 10),
('1/4 Pollo + papas',       18.50, 'Plato principal', 3),   -- stock bajo a propósito
('Gaseosa 1.5L',             9.00, 'Bebida',           20);

INSERT INTO Pedido (ID_Empleado) VALUES (1);   -- Pedido #1 nace en estado 'Pendiente'

-- ---- PRUEBA 1: cambio de estado -> dispara el trigger de auditoría ----
UPDATE Pedido SET Estado = 'En preparación' WHERE ID_Pedido = 1;
UPDATE Pedido SET Estado = 'Listo'          WHERE ID_Pedido = 1;
UPDATE Pedido SET Estado = 'Entregado'      WHERE ID_Pedido = 1;

SELECT * FROM RegistroAuditoriaPedido;   -- debe mostrar 3 filas de trazabilidad

-- ---- PRUEBA 2: insert con stock suficiente -> se registra y descuenta stock ----
INSERT INTO DetallePedido (Cantidad, PrecioUnitarioHistorico, Subtotal, ID_Pedido, ID_Producto)
VALUES (2, 9.00, 18.00, 1, 3);   -- 2 gaseosas, hay 20 en stock

SELECT * FROM DetallePedido;
SELECT ID_Producto, Nombre, Stock FROM Producto WHERE ID_Producto = 3;  -- Stock debe bajar a 18

-- ---- PRUEBA 3: insert con stock insuficiente -> debe RECHAZAR el pedido ----
BEGIN TRY
    INSERT INTO DetallePedido (Cantidad, PrecioUnitarioHistorico, Subtotal, ID_Pedido, ID_Producto)
    VALUES (5, 18.50, 92.50, 1, 2);   -- pide 5, solo hay 3 en stock
END TRY
BEGIN CATCH
    PRINT 'Resultado esperado (rechazo controlado): ' + ERROR_MESSAGE();
END CATCH
