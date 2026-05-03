if exists (select 1 from sys.databases where name ='F1_DW')
begin
alter database F1_DW set single_user with rollback immediate;
drop database F1_DW ;
end;

go
create database F1_DW
go

CREATE SCHEMA bronze;
go

CREATE SCHEMA silver;
go

CREATE SCHEMA gold;
go


