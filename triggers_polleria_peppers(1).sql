
IF OBJECT_ID('Comprobante')            IS NOT NULL DROP TABLE Comprobante;
IF OBJECT_ID('Pago')                   IS NOT NULL DROP TABLE Pago;
IF OBJECT_ID('PagoEmpleado')           IS NOT NULL DROP TABLE PagoEmpleado;
IF OBJECT_ID('RegistroTurno')          IS NOT NULL DROP TABLE RegistroTurno;
IF OBJECT_ID('Turno')                  IS NOT NULL DROP TABLE Turno;
IF OBJECT_ID('DetallePedido')          IS NOT NULL DROP TABLE DetallePedido;
IF OBJECT_ID('Producto')               IS NOT NULL DROP TABLE Producto;
GO

/* =========================================================================
   1. TABLAS BASE 
   ========================================================================= */

IF OBJECT_ID('Pedido')                   IS NOT NULL DROP TABLE Pedido;
IF OBJECT_ID('Empleado')                 IS NOT NULL DROP TABLE Empleado;
IF OBJECT_ID('RegistroAuditoriaPedido')  IS NOT NULL DROP TABLE RegistroAuditoriaPedido;
IF OBJECT_ID('RegistroDemandaHoraria')   IS NOT NULL DROP TABLE RegistroDemandaHoraria;
GO

CREATE TABLE Empleado (
    ID_Empleado         INT IDENTITY(1,1) PRIMARY KEY,
    NumeroDocumento     VARCHAR(20)  NOT NULL,
    Nombre              VARCHAR(50)  NOT NULL,
    ApellidoPaterno     VARCHAR(50)  NOT NULL
);
GO

CREATE TABLE Pedido (
    ID_Pedido       INT IDENTITY(1,1) PRIMARY KEY,
    Fecha           DATE NOT NULL DEFAULT CAST(GETDATE() AS DATE),
    Hora            TIME NOT NULL DEFAULT CAST(GETDATE() AS TIME),
    Estado          VARCHAR(20) NOT NULL DEFAULT 'Pendiente',
    ID_Empleado     INT NOT NULL,
    CONSTRAINT FK_Pedido_Empleado FOREIGN KEY (ID_Empleado) REFERENCES Empleado(ID_Empleado)
);
GO


CREATE TABLE RegistroAuditoriaPedido (
    ID_Log          INT IDENTITY(1,1) PRIMARY KEY,
    ID_Pedido       INT NOT NULL,
    EstadoAnterior  VARCHAR(20) NOT NULL,
    EstadoNuevo     VARCHAR(20) NOT NULL,
    UsuarioSQL      VARCHAR(100) NOT NULL,
    FechaHoraCambio DATETIME2 NOT NULL DEFAULT SYSDATETIME()
);
GO


CREATE TABLE RegistroDemandaHoraria (
    ID_Registro     INT IDENTITY(1,1) PRIMARY KEY,
    ID_Pedido       INT NOT NULL,
    Fecha           DATE     NOT NULL,
    HoraPedido      TIME     NOT NULL,   -- hora exacta del pedido, ej. 20:47:22
    HoraEntera      TINYINT  NOT NULL,   -- solo la hora, 0-23, para agrupar fácil
    CONSTRAINT FK_Demanda_Pedido FOREIGN KEY (ID_Pedido) REFERENCES Pedido(ID_Pedido)
);
GO

/* =========================================================================
   2. TRIGGER DE AUDITORÍA - trg_Auditoria_EstadoPedido
   ---------------------------------------------------------------------
  */

CREATE OR ALTER TRIGGER trg_Auditoria_EstadoPedido
ON Pedido
AFTER UPDATE
AS
BEGIN
    SET NOCOUNT ON;

    IF UPDATE(Estado)
    BEGIN
        BEGIN TRY
            INSERT INTO RegistroAuditoriaPedido (ID_Pedido, EstadoAnterior, EstadoNuevo, UsuarioSQL)
            SELECT
                i.ID_Pedido,
                d.Estado,
                i.Estado,
                SUSER_SNAME()
            FROM inserted i
            INNER JOIN deleted d ON i.ID_Pedido = d.ID_Pedido
            WHERE i.Estado <> d.Estado;
        END TRY
        BEGIN CATCH
            PRINT 'Advertencia: no se pudo registrar auditoría. Error: ' + ERROR_MESSAGE();
        END CATCH
    END
END
GO

/* =========================================================================
   3. TRIGGER DE DEMANDA - trg_RegistrarDemandaHoraria
   ---------------------------------------------------------------------

 */

CREATE OR ALTER TRIGGER trg_RegistrarDemandaHoraria
ON Pedido
AFTER INSERT
AS
BEGIN
    SET NOCOUNT ON;

    BEGIN TRY
        INSERT INTO RegistroDemandaHoraria (ID_Pedido, Fecha, HoraPedido, HoraEntera)
        SELECT
            i.ID_Pedido,
            i.Fecha,
            i.Hora,
            DATEPART(HOUR, i.Hora)   -- extrae solo la hora (0-23)
        FROM inserted i;
    END TRY
    BEGIN CATCH
        PRINT 'Advertencia: no se pudo registrar la demanda horaria. Error: ' + ERROR_MESSAGE();
    END CATCH
END
GO

/* =========================================================================
   4. DATOS DE PRUEBA Y EJECUCIÓN
   ========================================================================= */

INSERT INTO Empleado (NumeroDocumento, Nombre, ApellidoPaterno) VALUES
('70112233', 'Kiara', 'Leon'),
('70223344', 'Christian', 'Loza');

--PRUEBA 1
INSERT INTO Pedido (ID_Empleado) VALUES (1);   -- Pedido #1
UPDATE Pedido SET Estado = 'En preparación' WHERE ID_Pedido = 1;
UPDATE Pedido SET Estado = 'Listo'          WHERE ID_Pedido = 1;
UPDATE Pedido SET Estado = 'Entregado'      WHERE ID_Pedido = 1;

SELECT * FROM RegistroAuditoriaPedido;

--PRUEBA 2
DECLARE @i             INT = 1;
DECLARE @totalPedidos  INT = 40;
DECLARE @empleadoId    INT;
DECLARE @hora          TIME;
DECLARE @franja        FLOAT;

WHILE @i <= @totalPedidos
BEGIN
    SET @franja = RAND(CHECKSUM(NEWID()));

    IF @franja < 0.55
        SET @hora = DATEADD(MINUTE, ABS(CHECKSUM(NEWID())) % 180, '19:00');  -- noche: 19:00-22:00
    ELSE IF @franja < 0.80
        SET @hora = DATEADD(MINUTE, ABS(CHECKSUM(NEWID())) % 120, '12:00');  -- almuerzo: 12:00-14:00
    ELSE
        SET @hora = DATEADD(MINUTE, ABS(CHECKSUM(NEWID())) % 600, '09:00');  -- resto: 09:00-19:00

    SET @empleadoId = (ABS(CHECKSUM(NEWID())) % 2) + 1;   -- empleado 1 o 2

    INSERT INTO Pedido (Hora, ID_Empleado) VALUES (@hora, @empleadoId);

    SET @i += 1;
END

SELECT * FROM RegistroDemandaHoraria;   -- 1 fila por cada pedido creado

-- ---- CONSULTA CLAVE: hora pico de mayor demanda ----
SELECT
    HoraEntera AS Hora,
    COUNT(*)   AS CantidadPedidos
FROM RegistroDemandaHoraria
GROUP BY HoraEntera
ORDER BY CantidadPedidos DESC;
