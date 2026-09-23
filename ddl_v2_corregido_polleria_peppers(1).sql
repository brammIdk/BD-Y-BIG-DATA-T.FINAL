
-- CREATE DATABASE PolleriaPeppers;
-- GO
-- USE PolleriaPeppers;
-- GO

IF OBJECT_ID('Comprobante')       IS NOT NULL DROP TABLE Comprobante;
IF OBJECT_ID('Pago')              IS NOT NULL DROP TABLE Pago;
IF OBJECT_ID('DetallePedido')     IS NOT NULL DROP TABLE DetallePedido;
IF OBJECT_ID('RegistroTurno')     IS NOT NULL DROP TABLE RegistroTurno;
IF OBJECT_ID('Pedido')            IS NOT NULL DROP TABLE Pedido;
IF OBJECT_ID('PagoEmpleado')      IS NOT NULL DROP TABLE PagoEmpleado;
IF OBJECT_ID('Turno')             IS NOT NULL DROP TABLE Turno;
IF OBJECT_ID('Producto')          IS NOT NULL DROP TABLE Producto;
IF OBJECT_ID('Empleado')          IS NOT NULL DROP TABLE Empleado;
IF OBJECT_ID('Cliente')           IS NOT NULL DROP TABLE Cliente;
IF OBJECT_ID('Proveedor')         IS NOT NULL DROP TABLE Proveedor;
IF OBJECT_ID('TipoEntrega')       IS NOT NULL DROP TABLE TipoEntrega;
IF OBJECT_ID('Cargo')             IS NOT NULL DROP TABLE Cargo;
IF OBJECT_ID('ConceptoPago')      IS NOT NULL DROP TABLE ConceptoPago;
IF OBJECT_ID('MetodoPago')        IS NOT NULL DROP TABLE MetodoPago;
IF OBJECT_ID('TipoComprobante')   IS NOT NULL DROP TABLE TipoComprobante;
GO

/* ===================== 1. TABLAS SIN DEPENDENCIAS ======================= */

CREATE TABLE TipoEntrega (
    ID_TipoEntrega  TINYINT      IDENTITY(1,1) PRIMARY KEY,
    Nombre          VARCHAR(20)  NOT NULL
);
GO

CREATE TABLE Cargo (
    ID_Cargo    TINYINT     IDENTITY(1,1) PRIMARY KEY,
    Nombre      VARCHAR(50) NOT NULL            
);
GO

CREATE TABLE ConceptoPago (
    ID_ConceptoPago INT         IDENTITY(1,1) PRIMARY KEY,
    Nombre          VARCHAR(50) NOT NULL       
);
GO

CREATE TABLE MetodoPago (
    ID_MetodoPago TINYINT      IDENTITY(1,1) PRIMARY KEY,
    Nombre        VARCHAR(20)  NOT NULL           
);
GO

CREATE TABLE TipoComprobante (
    ID_TipoComprobante INT         IDENTITY(1,1) PRIMARY KEY,
    Nombre             VARCHAR(30) NOT NULL     
);
GO

CREATE TABLE Cliente (
    ID_Cliente  INT           IDENTITY(1,1) PRIMARY KEY,
    Nombre      VARCHAR(100)  NOT NULL,
    Direccion   VARCHAR(150)  NULL,
    DNI_RUC     VARCHAR(20)   NOT NULL
);
GO

CREATE TABLE Proveedor (
    ID_Proveedor INT          IDENTITY(1,1) PRIMARY KEY,
    Nombre       VARCHAR(100) NOT NULL,
    Contacto     VARCHAR(100) NULL,
    Telefono     VARCHAR(20)  NULL
);
GO


CREATE TABLE Empleado (
    ID_Empleado       INT          IDENTITY(1,1) PRIMARY KEY,
    NumeroDocumento   VARCHAR(20)  NOT NULL,
    Nombre            VARCHAR(50)  NOT NULL,
    ApellidoPaterno   VARCHAR(50)  NOT NULL,
    ApellidoMaterno   VARCHAR(50)  NULL,
    Telefono          VARCHAR(20)  NULL,
    ID_Cargo          TINYINT      NOT NULL,
    CONSTRAINT FK_Empleado_Cargo FOREIGN KEY (ID_Cargo) REFERENCES Cargo(ID_Cargo)
);
GO

CREATE TABLE Producto (
    ID_Producto   INT           IDENTITY(1,1) PRIMARY KEY,
    Nombre        VARCHAR(100)  NOT NULL,
    Precio        DECIMAL(8,2)  NOT NULL,
    Categoria     VARCHAR(50)   NOT NULL,
    Stock         INT           NOT NULL DEFAULT 0,
    ID_Proveedor  INT           NOT NULL,
    CONSTRAINT FK_Producto_Proveedor FOREIGN KEY (ID_Proveedor) REFERENCES Proveedor(ID_Proveedor)
);
GO

CREATE TABLE Turno (
    ID_Turno     SMALLINT     IDENTITY(1,1) PRIMARY KEY,
    NombreTurno  VARCHAR(30)  NOT NULL,       
    HoraInicio   TIME         NOT NULL,
    HoraFin      TIME         NOT NULL,
    ID_Empleado  INT          NOT NULL,
    CONSTRAINT FK_Turno_Empleado FOREIGN KEY (ID_Empleado) REFERENCES Empleado(ID_Empleado)
);
GO

CREATE TABLE Pedido (
    ID_Pedido        INT          IDENTITY(1,1) PRIMARY KEY,
    Fecha            DATE         NOT NULL DEFAULT CAST(GETDATE() AS DATE),
    Hora             TIME         NOT NULL DEFAULT CAST(GETDATE() AS TIME),
    Estado           VARCHAR(20)  NOT NULL DEFAULT 'Pendiente',
    ID_Cliente       INT          NOT NULL,
    ID_Empleado      INT          NOT NULL,
    ID_TipoEntrega   TINYINT      NOT NULL,
    CONSTRAINT FK_Pedido_Cliente     FOREIGN KEY (ID_Cliente)     REFERENCES Cliente(ID_Cliente),
    CONSTRAINT FK_Pedido_Empleado    FOREIGN KEY (ID_Empleado)    REFERENCES Empleado(ID_Empleado),
    CONSTRAINT FK_Pedido_TipoEntrega FOREIGN KEY (ID_TipoEntrega) REFERENCES TipoEntrega(ID_TipoEntrega)
);
GO

CREATE TABLE RegistroTurno (
    ID_Registro   INT              IDENTITY(1,1) PRIMARY KEY,
    Estado        CHAR(1)          NOT NULL,
    Fecha         DATE             NOT NULL DEFAULT CAST(GETDATE() AS DATE),
    HoraEntrada   DATETIMEOFFSET   NULL,
    HoraSalida    DATETIMEOFFSET   NULL,
    ID_Empleado   INT              NOT NULL,
    ID_Turno      SMALLINT         NOT NULL,
    CONSTRAINT FK_RegTurno_Empleado FOREIGN KEY (ID_Empleado) REFERENCES Empleado(ID_Empleado),
    CONSTRAINT FK_RegTurno_Turno    FOREIGN KEY (ID_Turno)    REFERENCES Turno(ID_Turno)
);
GO

CREATE TABLE DetallePedido (
    ID_Detalle              INT           IDENTITY(1,1) PRIMARY KEY,
    Cantidad                INT           NOT NULL,
    PrecioUnitarioHist      DECIMAL(8,2)  NOT NULL,
    Subtotal                DECIMAL(8,2)  NOT NULL,
    ID_Pedido               INT           NOT NULL,
    ID_Producto              INT          NOT NULL,
    CONSTRAINT FK_Detalle_Pedido   FOREIGN KEY (ID_Pedido)   REFERENCES Pedido(ID_Pedido),
    CONSTRAINT FK_Detalle_Producto FOREIGN KEY (ID_Producto) REFERENCES Producto(ID_Producto)
);
GO

CREATE TABLE Pago (
    ID_Pago        INT           IDENTITY(1,1) PRIMARY KEY,
    Monto          DECIMAL(8,2)  NOT NULL,
    Fecha          DATE          NOT NULL DEFAULT CAST(GETDATE() AS DATE),
    ID_Pedido      INT           NOT NULL,
    ID_MetodoPago  TINYINT       NOT NULL,
    CONSTRAINT FK_Pago_Pedido FOREIGN KEY (ID_Pedido)     REFERENCES Pedido(ID_Pedido),
    CONSTRAINT FK_Pago_Metodo FOREIGN KEY (ID_MetodoPago) REFERENCES MetodoPago(ID_MetodoPago)
);
GO

CREATE TABLE Comprobante (
    ID_Comprobante     INT      IDENTITY(1,1) PRIMARY KEY,
    Fecha              DATE     NOT NULL DEFAULT CAST(GETDATE() AS DATE),
    ID_TipoComprobante INT      NOT NULL,
    ID_Pago            INT      NOT NULL UNIQUE,   
    CONSTRAINT FK_Comprobante_Tipo FOREIGN KEY (ID_TipoComprobante) REFERENCES TipoComprobante(ID_TipoComprobante),
    CONSTRAINT FK_Comprobante_Pago FOREIGN KEY (ID_Pago)            REFERENCES Pago(ID_Pago)
);
GO

CREATE TABLE PagoEmpleado (
    ID_PagoEmpleado  INT           IDENTITY(1,1) PRIMARY KEY,
    Monto            DECIMAL(8,2)  NOT NULL,
    Fecha            DATE          NOT NULL DEFAULT CAST(GETDATE() AS DATE),
    ID_ConceptoPago  INT           NOT NULL,
    ID_Empleado      INT           NOT NULL,
    CONSTRAINT FK_PagoEmp_Concepto FOREIGN KEY (ID_ConceptoPago) REFERENCES ConceptoPago(ID_ConceptoPago),
    CONSTRAINT FK_PagoEmp_Empleado FOREIGN KEY (ID_Empleado)     REFERENCES Empleado(ID_Empleado)
);
GO
