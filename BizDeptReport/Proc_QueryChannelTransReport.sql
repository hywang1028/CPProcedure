if OBJECT_ID(N'Proc_QueryChannelTransReport', N'P') is not null
begin
	drop procedure Proc_QueryChannelTransReport;
end
go

create procedure Proc_QueryChannelTransReport
	@StartDate as datetime = '2011-02-01',
	@EndDate as datetime = '2011-02-28'
as
begin

--1. Check input
	if @StartDate is null or @EndDate is null
	begin
		raiserror(N'Input params cannot be empty in Proc_QueryChannelTransReport', 16, 1);
	end;

--2. Get DailyTrans during the period
--2.1 Get Payment Trans Data
select
	Trans.MerchantNo,
    SUM(Trans.SucceedTransCount) AS SucceedCount,
	Convert(Decimal,SUM(Trans.SucceedTransAmount))/100 AS SucceedAmount
into
	#PaymentSumValue
from
	FactDailyTrans Trans
where
	Trans.DailyTransDate >= @StartDate
	and
	Trans.DailyTransDate < DATEADD(day,1,@EndDate)
group by
	Trans.MerchantNo;
		
--2.2 Get ORA Trans Data
select	
	MerchantNo,
	SUM(TransCount) as SucceedCount,
	Convert(Decimal,SUM(TransAmount))/100 as SucceedAmount
into
	#ORASumValue
from
	Table_OraTransSum
where
	CPDate >= @StartDate
	and
	CPDate < DATEADD(day,1,@EndDate)
group by
	MerchantNo;
	
--2.3 Union the two table
select * into #PeriodSumValue from #PaymentSumValue
union all
select * from #ORASumValue

--3. Get Result
--3.1 Get duplicate Channel,Area,MerchantNo
select
	Channel,
	Area,
	MerchantNo
into
	#DuplicateValue
from
	Table_BizDeptBranchChannel
group by
	Channel,
	Area,
	MerchantNo
having
	COUNT(*) > 1

--3.2 Get final result
select
	BranchChannel.ID,
	BranchChannel.Channel,
	BranchChannel.Area							as SubChannel,
	BranchChannel.BranchOffice,
	BranchChannel.MerchantName,
	BranchChannel.MerchantNo,
	BranchChannel.MerchantStatus,
	isnull(PeriodSumValue.SucceedCount, 0)		as SucceedCount,
	ISNULL(PeriodSumValue.SucceedAmount, 0)		as SucceedAmount,
	case when DuplicateValue.MerchantNo is not null then N'÷ÿ∏¥' else N'' end  as Notes
from
	dbo.Table_BizDeptBranchChannel BranchChannel
	left join
	#PeriodSumValue PeriodSumValue
	on
		BranchChannel.MerchantNo = PeriodSumValue.MerchantNo
	left join
	#DuplicateValue DuplicateValue
	on
		BranchChannel.Channel = DuplicateValue.Channel
		and
		BranchChannel.Area = DuplicateValue.Area
		and
		BranchChannel.MerchantNo = DuplicateValue.MerchantNo
order by
	BranchChannel.ID;
	
		
--4. Clear temp table
drop table #PaymentSumValue;
drop table #ORASumValue;
drop table #PeriodSumValue;
drop table #DuplicateValue;

end