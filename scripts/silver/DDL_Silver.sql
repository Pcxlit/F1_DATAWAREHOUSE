DROP TABLE IF EXISTS silver.dim_drivers;
GO
 
CREATE TABLE silver.dim_drivers (
    driver_id       INT             NOT NULL PRIMARY KEY,
    driver_ref      VARCHAR(50)     NULL,
    full_name       VARCHAR(100)    NOT NULL,
    forename        VARCHAR(50)     NULL,
    surname         VARCHAR(50)     NULL,
    nationality     VARCHAR(50)     NULL,
    dob             DATE            NULL,
    code            CHAR(3)         NULL,
    number          VARCHAR(5)      NULL
);
GO


DROP TABLE IF EXISTS silver.dim_circuits;
GO
 
CREATE TABLE silver.dim_circuits (
    circuit_id      INT             NOT NULL PRIMARY KEY,
    circuit_ref     VARCHAR(50)     NULL,
    circuit_name    VARCHAR(100)    NULL,
    city            VARCHAR(100)    NULL,
    country         VARCHAR(100)    NULL,
    latitude        FLOAT           NULL,
    longitude       FLOAT           NULL,
    altitude        INT             NULL
);
GO

DROP TABLE IF EXISTS silver.dim_races;
GO
 
CREATE TABLE silver.dim_races (
    race_id         INT             NOT NULL PRIMARY KEY,
    season_year     SMALLINT        NOT NULL,
    round_number    INT         NOT NULL,
    circuit_id      INT             NOT NULL,
    race_name       VARCHAR(100)    NULL,
    race_date       DATE            NULL
);
GO


DROP TABLE IF EXISTS silver.dim_constructors;
GO
 
CREATE TABLE silver.dim_constructors (
    constructor_id      INT             NOT NULL PRIMARY KEY,
    constructor_ref     VARCHAR(50)     NULL,
    constructor_name    VARCHAR(100)    NULL,
    nationality         VARCHAR(50)     NULL
);
GO



DROP TABLE IF EXISTS silver.fct_race_results;
GO
 
CREATE TABLE silver.fct_race_results (
    result_id               INT             NOT NULL PRIMARY KEY,
    race_id                 INT             NOT NULL,
    driver_id               INT             NOT NULL,
    constructor_id          INT             NOT NULL,
    grid_position           INT         NULL,
    finish_position         INT         NULL,    
    position_order          INT         NULL,
    points                  INT          NULL,
    laps_completed          INT         NULL,
    race_time_ms            INT          NULL,
    fastest_lap_number      INT        NULL,
    fastest_lap_time        VARCHAR(15)     NULL,
    fastest_lap_speed       FLOAT           NULL,
    is_dnf                  BIT             NOT NULL DEFAULT 0,
    status_id               INT             NULL
);
GO


DROP TABLE IF EXISTS silver.fct_pit_stops;
GO
 
CREATE TABLE silver.fct_pit_stops (
    race_id             INT             NOT NULL,
    driver_id           INT             NOT NULL,
    stop_number         INT         NOT NULL,
    lap                 INT        NULL,
    stop_time_of_day    TIME            NULL,
    duration_seconds    FLOAT           NULL,
    duration_ms         INT             NULL,
    CONSTRAINT PK_fct_pit_stops PRIMARY KEY (race_id, driver_id, stop_number)
);
GO



DROP TABLE IF EXISTS silver.fct_lap_times;
GO
 
CREATE TABLE silver.fct_lap_times (
    race_id         INT         NOT NULL,
    driver_id       INT         NOT NULL,
    lap_number      INT    NOT NULL,
    track_position  INT     NULL,
    lap_time        VARCHAR(15) NULL,
    lap_time_ms     INT         NULL,
    CONSTRAINT PK_fct_lap_times PRIMARY KEY (race_id, driver_id, lap_number)
);
GO



DROP TABLE IF EXISTS silver.fct_qualifying;
GO
 
CREATE TABLE silver.fct_qualifying (
    qualify_id          INT         NOT NULL PRIMARY KEY,
    race_id             INT         NOT NULL,
    driver_id           INT         NOT NULL,
    constructor_id      INT         NOT NULL,
    qualify_position    INT     NULL,
    q1_time             VARCHAR(15) NULL,
    q2_time             VARCHAR(15) NULL,
    q3_time             VARCHAR(15) NULL,
    best_session        CHAR(2)     NOT NULL  
);
GO