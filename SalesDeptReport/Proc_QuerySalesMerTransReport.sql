if OBJECT_ID(N'Proc_QuerySalesMerTransReport', N'P') is not null
begin
	drop procedure Proc_QuerySalesMerTransReport;
end
go

create procedure Proc_QuerySalesMerTransReport
	@StartDate datetime = '2011-08-01',
	@EndDate datetime = '2011-08-31'
as
begin

--1. Check input
if (@StartDate is null or @EndDate is null)
begin
	raiserror(N'Input params cannot be empty in Proc_QuerySalesMerTransReport', 16, 1);
end

--2. Prepare Actually EndDate
declare @CurrStartDate datetime;
declare @CurrEndDate datetime;
declare @PrevStartDate datetime;
declare @PrevEndDate datetime;
declare @LastYearStartDate datetime;
declare @LastYearEndDate datetime;
set @CurrStartDate = @StartDate;
set @CurrEndDate = DateAdd(day,1,@EndDate);
set @PrevStartDate = DATEADD(DAY, -1*datediff(day,@CurrStartDate,@CurrEndDate), @CurrStartDate);
set @PrevEndDate = @CurrStartDate;
set @LastYearStartDate = DATEADD(year, -1, @CurrStartDate); 
set @LastYearEndDate = DATEADD(year, -1, @CurrEndDate);

--3. Get Current Data
With CurrCMCData as
(
	select
		MerchantNo,
		SUM(SucceedTransCount) as CurrSucceedCount,
		SUM(SucceedTransAmount) as CurrSucceedAmount
	from
		FactDailyTrans
	where
		DailyTransDate >= @CurrStartDate
		and
		DailyTransDate < @CurrEndDate
	group by
		MerchantNo
),
CurrORAData as
(
	select
		MerchantNo,
		SUM(TransCount) as CurrSucceedCount,
		SUM(TransAmount) as CurrSucceedAmount
	from
		dbo.Table_OraTransSum
	where
		CPDate >= @CurrStartDate
		and
		CPDate < @CurrEndDate
	group by
		MerchantNo
)
select
	coalesce(CurrCMCData.MerchantNo, CurrORAData.MerchantNo) MerchantNo,
	ISNULL(CurrCMCData.CurrSucceedCount, 0) + ISNULL(CurrORAData.CurrSucceedCount, 0) CurrSucceedCount,
	ISNULL(CurrCMCData.CurrSucceedAmount, 0) + ISNULL(CurrORAData.CurrSucceedAmount, 0) CurrSucceedAmount
into
	#CurrData
from
	CurrCMCData
	full outer join
	CurrORAData
	on
		CurrCMCData.MerchantNo = CurrORAData.MerchantNo;
		
--4. Get Previous Data
With PrevCMCData as
(
	select
		MerchantNo,
		SUM(SucceedTransCount) as PrevSucceedCount,
		SUM(SucceedTransAmount) as PrevSucceedAmount
	from
		FactDailyTrans
	where
		DailyTransDate >= @PrevStartDate
		and
		DailyTransDate < @PrevEndDate
	group by
		MerchantNo
),
PrevORAData as
(
	select
		MerchantNo,
		SUM(TransCount) as PrevSucceedCount,
		SUM(TransAmount) as PrevSucceedAmount
	from
		dbo.Table_OraTransSum
	where
		CPDate >= @PrevStartDate
		and
		CPDate < @PrevEndDate
	group by
		MerchantNo
)
select
	coalesce(PrevCMCData.MerchantNo, PrevORAData.MerchantNo) MerchantNo,
	ISNULL(PrevCMCData.PrevSucceedCount, 0) + ISNULL(PrevORAData.PrevSucceedCount, 0) PrevSucceedCount,
	ISNULL(PrevCMCData.PrevSucceedAmount, 0) + ISNULL(PrevORAData.PrevSucceedAmount, 0) PrevSucceedAmount
into
	#PrevData
from
	PrevCMCData
	full outer join
	PrevORAData
	on
		PrevCMCData.MerchantNo = PrevORAData.MerchantNo;
		
--5. Get LastYear Data
With LastYearCMCData as
(
	select
		MerchantNo,
		SUM(SucceedTransCount) as LastYearSucceedCount,
		SUM(SucceedTransAmount) as LastYearSucceedAmount
	from
		FactDailyTrans
	where
		DailyTransDate >= @LastYearStartDate
		and
		DailyTransDate < @LastYearEndDate
	group by
		MerchantNo
),
LastYearORAData as
(
	select
		MerchantNo,
		SUM(Table_OraTransSum.TransCount) as LastYearSucceedCount,
		SUM(Table_OraTransSum.TransAmount) as LastYearSucceedAmount	
	from
		dbo.Table_OraTransSum
	where
		Table_OraTransSum.CPDate >= @LastYearStartDate
		and
		Table_OraTransSum.CPDate < @LastYearEndDate
	group by
		MerchantNo
)
select
	coalesce(LastYearCMCData.MerchantNo, LastYearORAData.MerchantNo) MerchantNo,
	ISNULL(LastYearCMCData.LastYearSucceedCount, 0) + ISNULL(LastYearORAData.LastYearSucceedCount, 0) LastYearSucceedCount,
	ISNULL(LastYearCMCData.LastYearSucceedAmount, 0) + ISNULL(LastYearORAData.LastYearSucceedAmount, 0) LastYearSucceedAmount
into
	#LastYearData
from
	LastYearCMCData
	full outer join
	LastYearORAData
	on
		LastYearCMCData.MerchantNo = LastYearORAData.MerchantNo;
	
--4. Get Result
--4.1 Convert Currency Rate
update
	CD
set
	CD.CurrSucceedAmount = CD.CurrSucceedAmount * CR.CurrencyRate
from
	#CurrData CD
	inner join
	Table_SalesCurrencyRate CR
	on
		CD.MerchantNo = CR.MerchantNo;
		
update
	PD
set
	PD.PrevSucceedAmount = PD.PrevSucceedAmount * CR.CurrencyRate
from
	#PrevData PD
	inner join
	Table_SalesCurrencyRate CR
	on
		PD.MerchantNo = CR.MerchantNo;
		
update
	LYD
set
	LYD.LastYearSucceedAmount = LYD.LastYearSucceedAmount * CR.CurrencyRate
from
	#LastYearData LYD
	inner join
	Table_SalesCurrencyRate CR
	on
		LYD.MerchantNo = CR.MerchantNo;

--6.2 Get Final Result
select 
	Sales.MerchantName,
	Sales.Area,
	Sales.SalesManager,
	Sales.MerchantNo,
	Sales.MerchantType,
	Sales.IndustryName,
	Sales.Channel,
	Sales.BranchOffice,
	Sales.SigningYear,
	Rate.CurrencyRate,
	KPI.BizUnit,
	ISNULL(Curr.CurrSucceedCount,0) CurrSucceedCount,
	Convert(decimal,ISNULL(Curr.CurrSucceedAmount,0))/100 CurrSucceedAmount,
	Convert(decimal,ISNULL(Prev.PrevSucceedAmount,0))/100 PrevSucceedAmount,
	Convert(decimal,ISNULL(LastYear.LastYearSucceedAmount,0))/100 LastYearSucceedAmount,
	
	Convert(decimal,(ISNULL(Curr.CurrSucceedAmount,0) - ISNULL(LastYear.LastYearSucceedAmount,0)))/100 YOYAmountIncreasement,
	
	case when ISNULL(Prev.PrevSucceedAmount, 0) = 0
		then 0
		else CONVERT(decimal, ISNULL(Curr.CurrSucceedAmount, 0) - ISNULL(Prev.PrevSucceedAmount, 0))/Prev.PrevSucceedAmount
	end SeqAmountIncrementRatio,
	case when ISNULL(LastYear.LastYearSucceedAmount, 0) = 0
		then 0
		else CONVERT(decimal, ISNULL(Curr.CurrSucceedAmount, 0) - ISNULL(LastYear.LastYearSucceedAmount, 0))/LastYear.LastYearSucceedAmount
	end YOYAmountIncrementRatio
from
	dbo.Table_SalesDeptConfiguration Sales
	left join
	#CurrData Curr
	on
		Sales.MerchantNo = Curr.MerchantNo
	left join
	#PrevData Prev
	on
		Sales.MerchantNo = Prev.MerchantNo
	left join
	#LastYearData LastYear
	on
		Sales.MerchantNo = LastYear.MerchantNo
	left join
	Table_SalesCurrencyRate Rate
	on
		Sales.MerchantNo = Rate.MerchantNo
	left join
	Table_EmployeeKPI KPI
	on
		Sales.SalesManager = KPI.EmpName
order by
	Sales.MerchantName;

--7. Clear temp table
drop table #CurrData;
drop table #PrevData;
drop table #LastYearData;
end 