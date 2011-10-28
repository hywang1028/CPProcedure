if OBJECT_ID(N'Proc_QueryBizCategoryEMALLReport', N'P') is not null
begin
	drop procedure Proc_QueryBizCategoryEMALLReport;
end
go

create procedure Proc_QueryBizCategoryEMALLReport
	@StartDate datetime = '2011-09-01',
	@PeriodUnit nchar(4) = N'ÔÂ',
	@BizCategory nchar(10) = N'ÉÌ³Ç',
	@EndDate datetime = '2011-05-30'
as
begin

end

select * from Table_BizDeptBranchChannel
where ISNULL(Channel,N'')<>N''

select * from DimGate;