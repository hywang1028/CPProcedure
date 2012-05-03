if OBJECT_ID(N'Proc_QueryCPSalesManagerTransReport', N'P') is not null
begin
	drop procedure Proc_QueryCPSalesManagerTransReport;
end
go

create procedure Proc_QueryCPSalesManagerTransReport
	@StartDate datetime = '2012-01-01',
	@PeriodUnit nchar(4) = N'月',
	@EndDate datetime = '2012-02-29'
as
begin

--1. Check input
if (@StartDate is null or ISNULL(@PeriodUnit, N'') = N'' or (@PeriodUnit = N'自定义' and @EndDate is null))
begin
	raiserror(N'Input params cannot be empty in Proc_QueryCPSalesManagerTransReport', 16, 1);
end

--2. Prepare StartDate and EndDate
declare @CurrStartDate datetime;
declare @CurrEndDate datetime;
declare @PrevStartDate datetime;
declare @PrevEndDate datetime;
declare @LastYearStartDate datetime;
declare @LastYearEndDate datetime;
declare @ThisYearRunningStartDate datetime;
declare @ThisYearRunningEndDate datetime;

if(@PeriodUnit = N'周')
begin
    set @CurrStartDate = @StartDate;
    set @CurrEndDate = DATEADD(week, 1, @StartDate);
    set @PrevStartDate = DATEADD(week, -1, @CurrStartDate);
    set @PrevEndDate = @CurrStartDate;
    set @LastYearStartDate = DATEADD(year, -1, @CurrStartDate); 
    set @LastYearEndDate = DATEADD(year, -1, @CurrEndDate);
end
else if(@PeriodUnit = N'月')
begin
    set @CurrStartDate = @StartDate;
    set @CurrEndDate = DATEADD(MONTH, 1, @StartDate);
    set @PrevStartDate = DATEADD(MONTH, -1, @CurrStartDate);
    set @PrevEndDate = @CurrStartDate;
    set @LastYearStartDate = DATEADD(year, -1, @CurrStartDate); 
    set @LastYearEndDate = DATEADD(year, -1, @CurrEndDate);
end
else if(@PeriodUnit = N'季度')
begin
    set @CurrStartDate = @StartDate;
    set @CurrEndDate = DATEADD(QUARTER, 1, @StartDate);
    set @PrevStartDate = DATEADD(QUARTER, -1, @CurrStartDate);
    set @PrevEndDate = @CurrStartDate;
    set @LastYearStartDate = DATEADD(year, -1, @CurrStartDate); 
    set @LastYearEndDate = DATEADD(year, -1, @CurrEndDate);
end
else if(@PeriodUnit = N'半年')
begin
    set @CurrStartDate = @StartDate;
    set @CurrEndDate = DATEADD(QUARTER, 2, @StartDate);
    set @PrevStartDate = DATEADD(QUARTER, -2, @CurrStartDate);
    set @PrevEndDate = @CurrStartDate;
    set @LastYearStartDate = DATEADD(year, -1, @CurrStartDate); 
    set @LastYearEndDate = DATEADD(year, -1, @CurrEndDate);
end
else if(@PeriodUnit = N'年')
begin
    set @CurrStartDate = @StartDate;
    set @CurrEndDate = DATEADD(YEAR, 1, @StartDate);
    set @PrevStartDate = DATEADD(YEAR, -1, @CurrStartDate);
    set @PrevEndDate = @CurrStartDate;
    set @LastYearStartDate = DATEADD(year, -1, @CurrStartDate); 
    set @LastYearEndDate = DATEADD(year, -1, @CurrEndDate);
end
else if(@PeriodUnit = N'自定义')
begin
    set @CurrStartDate = @StartDate;
    set @CurrEndDate = DateAdd(day,1,@EndDate);
    set @PrevStartDate = DATEADD(DAY, -1*datediff(day,@CurrStartDate,@CurrEndDate), @CurrStartDate);
    set @PrevEndDate = @CurrStartDate;
    set @LastYearStartDate = DATEADD(year, -1, @CurrStartDate); 
    set @LastYearEndDate = DATEADD(year, -1, @CurrEndDate);
end

set @ThisYearRunningStartDate = CONVERT(char(4), YEAR(@CurrStartDate)) + '-01-01';
set @ThisYearRunningEndDate = @CurrEndDate;

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
		SUM(Table_OraTransSum.TransCount) as CurrSucceedCount,
		SUM(Table_OraTransSum.TransAmount) as CurrSucceedAmount
	from
		dbo.Table_OraTransSum
	where
		Table_OraTransSum.CPDate >= @CurrStartDate
		and
		Table_OraTransSum.CPDate < @CurrEndDate
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
		SUM(Table_OraTransSum.TransCount) as PrevSucceedCount,
		SUM(Table_OraTransSum.TransAmount) as PrevSucceedAmount
	from
		dbo.Table_OraTransSum
	where
		Table_OraTransSum.CPDate >= @PrevStartDate
		and
		Table_OraTransSum.CPDate < @PrevEndDate
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

--5. Get This Year Running Data
With ThisYearCMCData as
(
	select
		MerchantNo,
		SUM(SucceedTransCount) as ThisYearSucceedCount,
		SUM(SucceedTransAmount) as ThisYearSucceedAmount
	from
		FactDailyTrans
	where
		DailyTransDate >= @ThisYearRunningStartDate
		and
		DailyTransDate < @ThisYearRunningEndDate
	group by
		MerchantNo
),
ThisYearORAData as
(
	select
		MerchantNo,
		SUM(Table_OraTransSum.TransCount) as ThisYearSucceedCount,
		SUM(Table_OraTransSum.TransAmount) as ThisYearSucceedAmount	
	from
		dbo.Table_OraTransSum
	where
		CPDate >= @ThisYearRunningStartDate
		and
		CPDate < @ThisYearRunningEndDate
	group by
		MerchantNo
)
select
	coalesce(ThisYearCMCData.MerchantNo, ThisYearORAData.MerchantNo) MerchantNo,
	ISNULL(ThisYearCMCData.ThisYearSucceedCount, 0) + ISNULL(ThisYearORAData.ThisYearSucceedCount, 0) ThisYearSucceedCount,
	ISNULL(ThisYearCMCData.ThisYearSucceedAmount, 0) + ISNULL(ThisYearORAData.ThisYearSucceedAmount, 0) ThisYearSucceedAmount
into
	#ThisYearData
from
	ThisYearCMCData
	full outer join
	ThisYearORAData
	on
		ThisYearCMCData.MerchantNo = ThisYearORAData.MerchantNo;
			
--6. Get Result
--6.1 Convert Currency Rate
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
	
update
	TYD
set
	TYD.ThisYearSucceedAmount = TYD.ThisYearSucceedAmount * CR.CurrencyRate
from
	#ThisYearData TYD
	inner join
	Table_SalesCurrencyRate CR
	on
		TYD.MerchantNo = CR.MerchantNo;
		
--6.2 Get Final Result
With SalesManagerTransData as
(
	select
		ISNULL(Sales.SalesManager,N'') SalesManager,
		ISNULL(SUM(Curr.CurrSucceedCount),0) CurrSucceedCount,
		Convert(decimal,ISNULL(SUM(Curr.CurrSucceedAmount),0))/100 CurrSucceedAmount,
		Convert(decimal,ISNULL(SUM(Prev.PrevSucceedAmount),0))/100 PrevSucceedAmount,
		Convert(decimal,ISNULL(SUM(LastYear.LastYearSucceedAmount),0))/100 LastYearSucceedAmount,
		Convert(decimal,ISNULL(SUM(ThisYear.ThisYearSucceedAmount),0))/100 ThisYearSucceedAmount,
		case when ISNULL(SUM(Prev.PrevSucceedAmount), 0) = 0
			then 0
			else CONVERT(decimal, ISNULL(SUM(Curr.CurrSucceedAmount), 0) - ISNULL(SUM(Prev.PrevSucceedAmount), 0))/SUM(Prev.PrevSucceedAmount)
		end SeqAmountIncrementRatio,
		case when ISNULL(SUM(LastYear.LastYearSucceedAmount), 0) = 0
			then 0
			else CONVERT(decimal, ISNULL(SUM(Curr.CurrSucceedAmount), 0) - ISNULL(SUM(LastYear.LastYearSucceedAmount), 0))/SUM(LastYear.LastYearSucceedAmount)
		end YOYAmountIncrementRatio
	from
		Table_SalesDeptConfiguration Sales
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
		#ThisYearData ThisYear
		on
			Sales.MerchantNo = ThisYear.MerchantNo
	group by
		Sales.SalesManager
)
select
	ISNULL(KPIData.BizUnit,N'其他') BizUnit,
	case when KPIData.BizUnit <> N'其他' then 0 else 1 End as OrderID,
	coalesce(KPIData.EmpName,Sales.SalesManager) SalesManager,
	ISNULL(KPIData.KPIValue,0)/100 KPIValue,
	case when ISNULL(KPIData.KPIValue,0) = 0 
		 then 0
		 else 100*ISNULL(Sales.ThisYearSucceedAmount,0)/KPIData.KPIValue
	end Achievement,
	ISNULL(Sales.CurrSucceedAmount,0) CurrSucceedAmount,
	ISNULL(Sales.CurrSucceedCount,0) CurrSucceedCount,
	ISNULL(Sales.PrevSucceedAmount,0) PrevSucceedAmount,
	ISNULL(Sales.LastYearSucceedAmount,0) LastYearSucceedAmount,
	ISNULL(Sales.ThisYearSucceedAmount,0) ThisYearSucceedAmount,
	ISNULL(Sales.SeqAmountIncrementRatio,0) SeqAmountIncrementRatio,
	ISNULL(Sales.YOYAmountIncrementRatio,0) YOYAmountIncrementRatio
from
	SalesManagerTransData Sales
	full outer join
	(select 
		*
	 from
		Table_EmployeeKPI 
	 where
		PeriodStartDate >= @ThisYearRunningStartDate
		and 
		PeriodStartDate <  DateAdd(day,1,@ThisYearRunningEndDate)
	)KPIData
	on
		Sales.SalesManager = KPIData.EmpName;

--7. Clear temp table
drop table #CurrData;
drop table #PrevData;
drop table #LastYearData;
drop table #ThisYearData;

end 