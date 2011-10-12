if OBJECT_ID(N'Proc_QueryCPPlateTransReport', N'P') is not null
begin
	drop procedure Proc_QueryCPPlateTransReport;
end
go

create procedure Proc_QueryCPPlateTransReport
	@StartDate datetime = '2011-05-01',
	@PeriodUnit nchar(5) = N'月',
	@EndDate datetime = '2011-05-31'
as
begin

--1. Check input
if (@StartDate is null or ISNULL(@PeriodUnit, N'') = N'' or (@PeriodUnit = N'自定义' and @EndDate is null))
begin
	raiserror(N'Input params cannot be empty in Proc_QueryCPPlateTransReport', 16, 1);
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

--3. Get Payment and ORA Data
--3.1 Get Current Payment and ORA Data
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
		
--3.2 Get Previous Payment and ORA Data
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

--3.3 Get LastYear Payment and ORA Data
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
		Table_OraTransSum.CPDate < @LastYearStartDate
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
		
--3.4 Get ThisYear Running Payment and ORA Data	
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
		Table_OraTransSum.CPDate >= @ThisYearRunningStartDate
		and
		Table_OraTransSum.CPDate < @ThisYearRunningEndDate
	group by
		MerchantNo
)
select
	coalesce(ThisYearCMCData.MerchantNo, ThisYearORAData.MerchantNo) MerchantNo,
	ISNULL(ThisYearCMCData.ThisYearSucceedAmount, 0) + ISNULL(ThisYearORAData.ThisYearSucceedAmount, 0) ThisYearRunningAmount,
	ISNULL(ThisYearCMCData.ThisYearSucceedCount, 0) + ISNULL(ThisYearORAData.ThisYearSucceedCount, 0) ThisYearRunningCount
into
	#ThisYearRunningData
from
	ThisYearCMCData
	full outer join
	ThisYearORAData
	on
		ThisYearCMCData.MerchantNo = ThisYearORAData.MerchantNo;

--4. Get Fund Data		
--4.1 Get Current Fund Data			
select
	SUM(TransLog.TransAmt) as CurrFundAmount,
	COUNT(TransLog.TransAmt) as CurrFundCount
into
	#CurrFundData
from
	dbo.Table_TrfTransLog TransLog
where
	TransLog.TransDate >= @CurrStartDate
	and
	TransLog.TransDate < @CurrEndDate
	and
	TransLog.TransType in ('3010','3020','3030','3040','3050');
		
--4.2 Get Previous Fund Data			
select
	SUM(TransLog.TransAmt) as PrevFundAmount,
	COUNT(TransLog.TransAmt) as PrevFundCount
into
	#PrevFundData
from
	dbo.Table_TrfTransLog TransLog
where
	TransLog.TransDate >= @PrevStartDate
	and
	TransLog.TransDate < @PrevEndDate
	and
	TransLog.TransType in ('3010','3020','3030','3040','3050');
		
--4.3 Get LastYear Fund Data
select
	SUM(TransLog.TransAmt) as LastYearFundAmount,
	COUNT(TransLog.TransAmt) as LastYearFundCount
into
	#LastYearFundData
from
	dbo.Table_TrfTransLog TransLog
where
	TransLog.TransDate >= @LastYearStartDate
	and
	TransLog.TransDate < @LastYearEndDate
	and
	TransLog.TransType in ('3010','3020','3030','3040','3050');
	
--4.4 Get ThisYearRunning Fund Data
select 
	SUM(TransAmt) ThisYearRunningFundAmount,
	count(TransAmt) ThisYearRunningFundCount
into
	#ThisYearRunningFundData
from 
	dbo.Table_TrfTransLog 	
where 
	TransDate >= @ThisYearRunningStartDate 
	and 
	TransDate < @ThisYearRunningEndDate
	and
	TransType in ('3010','3020','3030','3040','3050');

--5. Get Mall Data		
--5.1 Get Current Mall Data			
select
	SUM(SucceedTransAmount) as CurrMallAmount,
	SUM(SucceedTransCount) as CurrMallCount
into
	#CurrMallData
from
	dbo.FactDailyTrans
where
	DailyTransDate >= @CurrStartDate
	and
	DailyTransDate < @CurrEndDate
	and
	MerchantNo = '808080290000007';
		
--5.2 Get Previous Mall Data			
select
	SUM(SucceedTransAmount) as PrevMallAmount,
	SUM(SucceedTransCount) as PrevMallCount
into
	#PrevMallData
from
	dbo.FactDailyTrans
where
	DailyTransDate >= @PrevStartDate
	and
	DailyTransDate < @PrevEndDate
	and
	MerchantNo = '808080290000007';
		
--5.3 Get LastYear Mall Data
select
	SUM(SucceedTransAmount) as LastYearMallAmount,
	SUM(SucceedTransCount) as LastYearMallCount
into
	#LastYearMallData
from
	dbo.FactDailyTrans
where
	DailyTransDate >= @LastYearStartDate
	and
	DailyTransDate < @LastYearEndDate
	and
	MerchantNo = '808080290000007';
	
--5.4 Get ThisYearRunning Mall Data
select 
	SUM(SucceedTransAmount) ThisYearRunningMallAmount,
	SUM(SucceedTransCount) ThisYearRunningMallCount
into
	#ThisYearRunningMallData
from 
	dbo.FactDailyTrans	
where 
	DailyTransDate >= @ThisYearRunningStartDate 
	and 
	DailyTransDate < @ThisYearRunningEndDate
	and
	MerchantNo = '808080290000007';

--6. Get Trip Data		
--6.1 Get Current Trip Data			
select
	SUM(SucceedTransAmount) as CurrTripAmount,
	SUM(SucceedTransCount) as CurrTripCount
into
	#CurrTripData
from
	dbo.FactDailyTrans
where
	DailyTransDate >= @CurrStartDate
	and
	DailyTransDate < @CurrEndDate
	and
	MerchantNo = '808080510003188';
		
--6.2 Get Previous Trip Data			
select
	SUM(SucceedTransAmount) as PrevTripAmount,
	SUM(SucceedTransCount) as PrevTripCount
into
	#PrevTripData
from
	dbo.FactDailyTrans
where
	DailyTransDate >= @PrevStartDate
	and
	DailyTransDate < @PrevEndDate
	and
	MerchantNo = '808080510003188';
		
--6.3 Get LastYear Trip Data
select
	SUM(SucceedTransAmount) as LastYearTripAmount,
	SUM(SucceedTransCount) as LastYearTripCount
into
	#LastYearTripData
from
	dbo.FactDailyTrans
where
	DailyTransDate >= @LastYearStartDate
	and
	DailyTransDate < @LastYearEndDate
	and
	MerchantNo = '808080510003188';
	
--6.4 Get ThisYearRunning Trip Data
select 
	SUM(SucceedTransAmount) ThisYearRunningTripAmount,
	SUM(SucceedTransCount) ThisYearRunningTripCount
into
	#ThisYearRunningTripData
from 
	dbo.FactDailyTrans	
where 
	DailyTransDate >= @ThisYearRunningStartDate 
	and 
	DailyTransDate < @ThisYearRunningEndDate
	and
	MerchantNo = '808080510003188';
	
--7. Get Convenience Data		
--6.1 Get Current Conve Data			
select
	SUM(SucceedTransAmount) as CurrConveAmount,
	SUM(SucceedTransCount) as CurrConveCount
into
	#CurrConveData
from
	dbo.FactDailyTrans
where
	DailyTransDate >= @CurrStartDate
	and
	DailyTransDate < @CurrEndDate
	and
	MerchantNo in (select MerchantNo from dbo.Table_InstuMerInfo where InstuNo = '000020100816001');
		
--6.2 Get Previous Conve Data			
select
	SUM(SucceedTransAmount) as PrevConveAmount,
	SUM(SucceedTransCount) as PrevConveCount
into
	#PrevConveData
from
	dbo.FactDailyTrans
where
	DailyTransDate >= @PrevStartDate
	and
	DailyTransDate < @PrevEndDate
	and
	MerchantNo in (select MerchantNo from dbo.Table_InstuMerInfo where InstuNo = '000020100816001');
		
--6.3 Get LastYear Conve Data
select
	SUM(SucceedTransAmount) as LastYearConveAmount,
	SUM(SucceedTransCount) as LastYearConveCount
into
	#LastYearConveData
from
	dbo.FactDailyTrans
where
	DailyTransDate >= @LastYearStartDate
	and
	DailyTransDate < @LastYearEndDate
	and
	MerchantNo in (select MerchantNo from dbo.Table_InstuMerInfo where InstuNo = '000020100816001');
	
--6.4 Get ThisYearRunning Conve Data
select 
	SUM(SucceedTransAmount) ThisYearRunningConveAmount,
	SUM(SucceedTransCount) ThisYearRunningConveCount
into
	#ThisYearRunningConveData
from 
	dbo.FactDailyTrans	
where 
	DailyTransDate >= @ThisYearRunningStartDate 
	and 
	DailyTransDate < @ThisYearRunningEndDate
	and
	MerchantNo in (select MerchantNo from dbo.Table_InstuMerInfo where InstuNo = '000020100816001');
	
--8. Convert Payment and ORA Currency Rate
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
	TYRD
set
	TYRD.ThisYearRunningAmount = TYRD.ThisYearRunningAmount * CR.CurrencyRate
from
	#ThisYearRunningData TYRD
	inner join
	Table_SalesCurrencyRate CR
	on
		TYRD.MerchantNo = CR.MerchantNo;


--9 Get Final Result
--9.1 Get Industry
select
	N'重点行业' as GroupName, 
	Sales.IndustryName as ItemName,
	Convert(decimal,sum(ISNULL(Curr.CurrSucceedAmount,0)))/100 CurrSucceedAmount,
	sum(ISNULL(Curr.CurrSucceedCount,0)) CurrSucceedCount,	
	Convert(decimal,sum(ISNULL(Prev.PrevSucceedAmount,0)))/100 PrevSucceedAmount,
	Convert(decimal,sum(ISNULL(LastYear.LastYearSucceedAmount,0)))/100 LastYearSucceedAmount,
	
	case when SUM(ISNULL(Prev.PrevSucceedAmount, 0)) = 0
		then null
		else CONVERT(decimal, sum(ISNULL(Curr.CurrSucceedAmount, 0) - ISNULL(Prev.PrevSucceedAmount, 0)))/sum(isnull(Prev.PrevSucceedAmount,0))
	end SeqAmountIncrementRatio,
	case when SUM(ISNULL(LastYear.LastYearSucceedAmount, 0)) = 0
		then null
		else CONVERT(decimal, sum(ISNULL(Curr.CurrSucceedAmount, 0) - ISNULL(LastYear.LastYearSucceedAmount, 0)))/Sum(isnull(LastYear.LastYearSucceedAmount,0))
	end YOYAmountIncrementRatio,
	convert(decimal, sum(ISNULL(ThisYearRunning.ThisYearRunningAmount, 0)))/100 ThisYearRunningAmount
into
	#Industry
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
	#ThisYearRunningData ThisYearRunning
	on
		Sales.MerchantNo = ThisYearRunning.MerchantNo
group by
	Sales.IndustryName;

--9.1.2 Change Industry Name
update #Industry 
Set ItemName = N'国内航空'
where ItemName = N'航空';

update #Industry 
Set ItemName = N'第三方支付'
where ItemName = N'第三方';

--9.2 Get Fund	
select
	N'重点行业' as GroupName,
	N'基金直销' as ItemName,
	CONVERT(decimal, isnull(C.CurrFundAmount,0))/100 as CurrSucceedAmount,
	ISNULL(C.CurrFundCount,0) as CurrSucceedCount,
	CONVERT(decimal, isnull(P.PrevFundAmount,0))/100 as PrevSucceedAmount,
	CONVERT(decimal, ISNULL(L.LastYearFundAmount,0))/100 as LastYearSucceedAmount,
	
	case when ISNULL(P.PrevFundAmount, 0) = 0
		then null
		else CONVERT(decimal, ISNULL(C.CurrFundAmount, 0) - ISNULL(P.PrevFundAmount, 0))/P.PrevFundAmount
	end SeqAmountIncrementRatio,
	case when ISNULL(L.LastYearFundAmount, 0) = 0
		then null
		else CONVERT(decimal, ISNULL(C.CurrFundAmount, 0) - ISNULL(L.LastYearFundAmount, 0))/L.LastYearFundAmount
	end YOYAmountIncrementRatio,
	convert(decimal, ISNULL(T.ThisYearRunningFundAmount, 0))/100 ThisYearRunningAmount
into
	#Fund
from
	#CurrFundData C
	cross join
	#PrevFundData P
	cross join
	#LastYearFundData L
	cross join
	#ThisYearRunningFundData T;
	
--9.3 Get Mall	
select
	N'自有板块' as GroupName,
	N'银联商城' as ItemName,
	CONVERT(decimal, isnull(C.CurrMallAmount,0))/100 as CurrSucceedAmount,
	ISNULL(C.CurrMallCount,0) as CurrSucceedCount,
	CONVERT(decimal, isnull(P.PrevMallAmount,0))/100 as PrevSucceedAmount,
	CONVERT(decimal, ISNULL(L.LastYearMallAmount,0))/100 as LastYearSucceedAmount,
	
	case when ISNULL(P.PrevMallAmount, 0) = 0
		then null
		else CONVERT(decimal, ISNULL(C.CurrMallAmount, 0) - ISNULL(P.PrevMallAmount, 0))/P.PrevMallAmount
	end SeqAmountIncrementRatio,
	case when ISNULL(L.LastYearMallAmount, 0) = 0
		then null
		else CONVERT(decimal, ISNULL(C.CurrMallAmount, 0) - ISNULL(L.LastYearMallAmount, 0))/L.LastYearMallAmount
	end YOYAmountIncrementRatio,
	convert(decimal, ISNULL(T.ThisYearRunningMallAmount, 0))/100 ThisYearRunningAmount
into
	#Mall
from
	#CurrMallData C
	cross join
	#PrevMallData P
	cross join
	#LastYearMallData L
	cross join
	#ThisYearRunningMallData T;
	
--9.4 Get Conve	
select
	N'自有板块' as GroupName,
	N'便民服务' as ItemName,
	CONVERT(decimal, isnull(C.CurrConveAmount,0))/100 as CurrSucceedAmount,
	ISNULL(C.CurrConveCount,0) as CurrSucceedCount,
	CONVERT(decimal, isnull(P.PrevConveAmount,0))/100 as PrevSucceedAmount,
	CONVERT(decimal, ISNULL(L.LastYearConveAmount,0))/100 as LastYearSucceedAmount,
	
	case when ISNULL(P.PrevConveAmount, 0) = 0
		then null
		else CONVERT(decimal, ISNULL(C.CurrConveAmount, 0) - ISNULL(P.PrevConveAmount, 0))/P.PrevConveAmount
	end SeqAmountIncrementRatio,
	case when ISNULL(L.LastYearConveAmount, 0) = 0
		then null
		else CONVERT(decimal, ISNULL(C.CurrConveAmount, 0) - ISNULL(L.LastYearConveAmount, 0))/L.LastYearConveAmount
	end YOYAmountIncrementRatio,
	convert(decimal, ISNULL(T.ThisYearRunningConveAmount, 0))/100 ThisYearRunningAmount
into
	#Conve
from
	#CurrConveData C
	cross join
	#PrevConveData P
	cross join
	#LastYearConveData L
	cross join
	#ThisYearRunningConveData T;
	
--9.5 Get Trip	
select
	N'自有板块' as GroupName,
	N'商旅平台' as ItemName,
	CONVERT(decimal, isnull(C.CurrTripAmount,0))/100 as CurrSucceedAmount,
	ISNULL(C.CurrTripCount,0) as CurrSucceedCount,
	CONVERT(decimal, isnull(P.PrevTripAmount,0))/100 as PrevSucceedAmount,
	CONVERT(decimal, ISNULL(L.LastYearTripAmount,0))/100 as LastYearSucceedAmount,
	
	case when ISNULL(P.PrevTripAmount, 0) = 0
		then null
		else CONVERT(decimal, ISNULL(C.CurrTripAmount, 0) - ISNULL(P.PrevTripAmount, 0))/P.PrevTripAmount
	end SeqAmountIncrementRatio,
	case when ISNULL(L.LastYearTripAmount, 0) = 0
		then null
		else CONVERT(decimal, ISNULL(C.CurrTripAmount, 0) - ISNULL(L.LastYearTripAmount, 0))/L.LastYearTripAmount
	end YOYAmountIncrementRatio,
	convert(decimal, ISNULL(T.ThisYearRunningTripAmount, 0))/100 ThisYearRunningAmount
into
	#Trip
from
	#CurrTripData C
	cross join
	#PrevTripData P
	cross join
	#LastYearTripData L
	cross join
	#ThisYearRunningTripData T;
	
--9.6 Union All
select 1 as RowID, * from #Industry 
where ItemName not in (' ','#N/A','0','CP内部使用','基金','作废商户','金融','测试','直销','便民平台','银联分公司')
union all
select 2, * from #Fund
union all
select 3, * from #Mall
union all
select 4, * from #Conve
union all
select 5, * from #Trip;

--10. Clear temp table
drop table #CurrData;
drop table #PrevData;
drop table #LastYearData;
drop table #ThisYearRunningData;

drop table #CurrFundData;
drop table #PrevFundData;
drop table #LastYearFundData;
drop table #ThisYearRunningFundData;

drop table #CurrMallData;
drop table #PrevMallData;
drop table #LastYearMallData;
drop table #ThisYearRunningMallData;

drop table #CurrConveData;
drop table #PrevConveData;
drop table #LastYearConveData;
drop table #ThisYearRunningConveData;

drop table #CurrTripData;
drop table #PrevTripData;
drop table #LastYearTripData;
drop table #ThisYearRunningTripData;

drop table #Industry;
drop table #Fund;
drop table #Mall;
drop table #Conve;
drop table #Trip;

end 