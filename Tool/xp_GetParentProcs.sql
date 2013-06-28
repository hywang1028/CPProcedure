--[Modified] At 2013-05-29 By chen.wu
--Add support to 'FN', 'FS', 'FT', 'IF', 'TF' types

if OBJECT_ID(N'xp_GetParentProcs', N'P') is not null
begin
	drop procedure xp_GetParentProcs;
end
go

create procedure xp_GetParentProcs
	@object nvarchar(max)
as
begin

-- Check input
if not exists (
	select
		1
	from
		sys.objects
	where
		type in ('P', 'U', 'FN', 'FS', 'FT', 'IF', 'TF')
		and
		name = @object
)
begin
	raiserror(N'[Error] Input must be Table or Procedure Name.', 16, 1);
end

-- Get All procedure definition
select 
	name as ProcName,
	OBJECT_DEFINITION(object_id(name, N'P')) ProcText
into
	#ProcDefinition
from
	sys.objects
where
	type = 'P'
	and
	name != @object;
	
-- Get all procedure referenced @object
select
	Procs.ProcName
from
	#ProcDefinition Procs
where
	CHARINDEX(@object, Procs.ProcText) != 0
	
-- Clear temp table
drop table #ProcDefinition;

end
