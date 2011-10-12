if OBJECT_ID(N'xp_BackupTables', N'P') is not null
begin
	drop procedure xp_BackupTables;
end
go

if not exists(
	select * from sys.databases where name=N'BackupDB'
)
begin
	create database BackupDB;
end
go

create procedure xp_BackupTables
	@tables nvarchar(max)	
as
begin

--Seperate input string into #backuptables
create table #backuptables
(
	tablename nvarchar(100) not null
);

insert into #backuptables
(
	tablename
)
exec xp_SplitToTable
	@tables;
	
--Check if #backuptables is empty
if not exists(
	select 1 from #backuptables
)
begin
	raiserror(N'[Error] Can not identify any table in input or invalid input', 16, 1);  
end
	
--Check if all tables exist in current db
if exists(
select
	bakTables.tablename,
	existTables.object_id
from
	#backuptables bakTables
	left join
	sys.tables existTables
	on
		bakTables.tablename = existTables.name
where
	existTables.name is null
)
begin
	raiserror(N'[Error] Not all tables exist in current database or invalid input', 16, 1);  
end

--Put tablename and object_id into #needbaktables
select
	bakTables.tablename,
	existTables.object_id
into
	#needbaktables
from
	#backuptables bakTables
	inner join
	sys.tables existTables
	on
		bakTables.tablename = existTables.name;

--Backup tables by loop
declare @tablename nvarchar(100);
declare @tableid int;

declare baktable_cursor cursor for
select
	tablename,
	object_id
from
	#needbaktables;
	
open baktable_cursor;

fetch next from baktable_cursor
into @tablename,@tableid;

while @@FETCH_STATUS = 0
begin
	declare @sqlscript nvarchar(max);
	set @sqlscript = N'select 
						*
					into
						BackupDB.dbo.' + @tablename + N'_' + DATENAME(YYYY,GETDATE())+DATENAME(mm,getdate())+DATENAME(dd,getdate())+N'_' +DATENAME(HH,GETDATE())+DATENAME(N,GETDATE())+DATENAME(SS,GETDATE())
					+ N' from 
						' + @tablename;
						
	exec(@sqlscript);

	fetch next from baktable_cursor
	into @tablename,@tableid;
end
close baktable_cursor;
deallocate baktable_cursor;
		
--Clear temp table
drop table #backuptables;
drop table #needbaktables;
	
end