if OBJECT_ID(N'Proc_QueryBizStatisticsByYear', N'P') is not null
begin
	drop procedure Proc_QueryBizStatisticsByYear;
end
go

create procedure Proc_QueryBizStatisticsByYear
	@BizCategory nvarchar(10) = N'代扣',
	@Year datetime = '2011-05-31'
as
begin

--1. check input
if (ISNULL(@BizCategory, N'') = N'' 
	or @Year is null)
begin
	raiserror(N'Input params cannot be empty in Proc_QueryBizStatisticsByYear.',16, 1);	
end

--2. Prepare Tasks
--2.1 Prepare params
declare @StartDate datetime;
declare @EndDate datetime;
set @StartDate = convert(char(4), YEAR(@Year)) + '-01-01';
set @EndDate = DateAdd(day,1,@Year);

--2.2 Prepare Month List
if OBJECT_ID(N'Table_MonthSequence', N'U') is null
begin

	create table Table_MonthSequence
	(
		MonthNum tinyint not null primary key
	);
	
	insert into Table_MonthSequence
	(
		MonthNum
	)
	select
		rn
	from
		(select
			ROW_NUMBER() over(order by (select 1)) as rn
		from
			sys.tables) SeqTable
	where
		SeqTable.rn <= 12;
end

--3. get subset of FactDailyTrans
create table #MidResult
(
	MonthNum int not null primary key,
	SumCount int not null,
	SumAmount bigint not null
);

if @BizCategory = N'代扣'
begin
	insert into #MidResult
	(
		MonthNum,
		SumCount,
		SumAmount
	)
	select
		DimDate.[每年的某一月] as MonthNum,
		SUM(DailyTrans.SucceedTransCount) as SumCount,
		SUM(DailyTrans.SucceedTransAmount) as SumAmount
	from
		dbo.FactDailyTrans as DailyTrans
		inner join
		dbo.DimDate as DimDate
		on
			DailyTrans.DailyTransDate = DimDate.[PK_日期]
	where
		DailyTrans.GateNo = '7008'
		and
		DailyTrans.DailyTransDate >= @StartDate
		and
		DailyTrans.DailyTransDate < @EndDate
	group by
		DimDate.[每年的某一月];	
end
else if @BizCategory = N'互联宝'
begin
	insert into #MidResult
	(
		MonthNum,
		SumCount,
		SumAmount
	)
	select
		DimDate.[每年的某一月] as MonthNum,
		SUM(DailyTrans.SucceedTransCount) as SumCount,
		SUM(DailyTrans.SucceedTransAmount) as SumAmount
	from
		dbo.FactDailyTrans as DailyTrans
		inner join
		dbo.DimDate as DimDate
		on
			DailyTrans.DailyTransDate = DimDate.[PK_日期]
	where
		DailyTrans.GateNo in ('0018', '0019', '8018')
		and
		DailyTrans.MerchantNo not in (select MerchantNo from dbo.Table_EposTakeoffMerchant)
		and
		DailyTrans.DailyTransDate >= @StartDate
		and
		DailyTrans.DailyTransDate < @EndDate
	group by
		DimDate.[每年的某一月];	
end
else if @BizCategory = N'基金（支付）'
begin
	insert into #MidResult
	(
		MonthNum,
		SumCount,
		SumAmount
	)
	select
		DimDate.[每年的某一月] as MonthNum,
		SUM(DailyTrans.SucceedTransCount) as SumCount,
		SUM(DailyTrans.SucceedTransAmount) as SumAmount
	from
		dbo.FactDailyTrans as DailyTrans
		inner join
		dbo.DimDate as DimDate
		on
			DailyTrans.DailyTransDate = DimDate.[PK_日期]
	where
		DailyTrans.GateNo in ('0044', '0045')
		and
		DailyTrans.DailyTransDate >= @StartDate
		and
		DailyTrans.DailyTransDate < @EndDate
	group by
		DimDate.[每年的某一月];	
end
else if @BizCategory = N'商城'
begin
	insert into #MidResult
	(
		MonthNum,
		SumCount,
		SumAmount
	)
	select
		DimDate.[每年的某一月] as MonthNum,
		SUM(DailyTrans.SucceedTransCount) as SumCount,
		SUM(DailyTrans.SucceedTransAmount) as SumAmount
	from
		dbo.FactDailyTrans as DailyTrans
		inner join
		dbo.DimDate as DimDate
		on
			DailyTrans.DailyTransDate = DimDate.[PK_日期]
	where
		DailyTrans.MerchantNo = '808080290000007'
		and
		DailyTrans.DailyTransDate >= @StartDate
		and
		DailyTrans.DailyTransDate < @EndDate
	group by
		DimDate.[每年的某一月];	
end
else if @BizCategory = N'商旅'
begin
	insert into #MidResult
	(
		MonthNum,
		SumCount,
		SumAmount
	)
	select
		DimDate.[每年的某一月] as MonthNum,
		SUM(DailyTrans.SucceedTransCount) as SumCount,
		SUM(DailyTrans.SucceedTransAmount) as SumAmount
	from
		dbo.FactDailyTrans as DailyTrans
		inner join
		dbo.DimDate as DimDate
		on
			DailyTrans.DailyTransDate = DimDate.[PK_日期]
	where
		DailyTrans.MerchantNo = '808080510003188'
		and
		DailyTrans.DailyTransDate >= @StartDate
		and
		DailyTrans.DailyTransDate < @EndDate
	group by
		DimDate.[每年的某一月];	
end
else if @BizCategory = N'公共事业缴费'
begin
	insert into #MidResult
	(
		MonthNum,
		SumCount,
		SumAmount
	)
	select
		DimDate.[每年的某一月] as MonthNum,
		SUM(DailyTrans.SucceedTransCount) as SumCount,
		SUM(DailyTrans.SucceedTransAmount) as SumAmount
	from
		dbo.FactDailyTrans as DailyTrans
		inner join
		dbo.DimDate as DimDate
		on
			DailyTrans.DailyTransDate = DimDate.[PK_日期]
	where
		DailyTrans.MerchantNo in (select MerchantNo from Table_FacilityMerchantRelation where FacilityNo = '000020100816001')
		and
		DailyTrans.DailyTransDate >= @StartDate
		and
		DailyTrans.DailyTransDate < @EndDate
	group by
		DimDate.[每年的某一月];	
end
--4. output report
select
	MonthSequence.MonthNum,
	convert(decimal, isnull(MidResult.SumCount, 0))/10000 as SumCount,
	convert(decimal, isnull(MidResult.SumAmount, 0))/1000000 as SumAmount
from
	Table_MonthSequence as MonthSequence
	left join
	#MidResult as MidResult
	on
		MonthSequence.MonthNum = MidResult.MonthNum;
		
--5. Clear temp table
drop table #MidResult;

end
	
