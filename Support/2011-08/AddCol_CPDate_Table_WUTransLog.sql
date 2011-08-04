--[2011-08-04 Support]Created by chen wu 
--Add column CPDate in Table_WUTransLog

if not exists
(
select
	1
from 
	sys.columns cols
	inner join
	sys.tables tbls
	on
		cols.object_id = tbls.object_id
where
	cols.name = N'CPDate'
	and
	tbls.name = N'Table_WUTransLog'
)
begin
	alter table dbo.Table_WUTransLog
	add CPDate datetime;
end

