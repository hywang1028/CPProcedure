if OBJECT_ID(N'xp_SplitToTable', N'P') is not null
begin
	drop procedure xp_SplitToTable;
end
go

create procedure xp_SplitToTable
	@CommaString nvarchar(max)
as
begin
	declare @sqlscript nvarchar(max);
	set @sqlscript = REPLACE(@CommaString,N',',N''' as col union all select ''');
	set @sqlscript = 'select ''' + @sqlscript + '''';
	exec(@sqlscript);
end


