--[Modified] on 2012-06-08 By ������ Description:Add West Union Trans Data
--[Modified] on 2013-05-16 By ����� Description:Add FeeAmt Data and UPOP Data
--[Modified] on 2013-06-09 By ����� Description:Modified Statistical Caliber and Limit OpenTime MerchantNo
if OBJECT_ID(N'Proc_QueryCPSalesManagerTransReport', N'P') is not null
begin
	drop procedure Proc_QueryCPSalesManagerTransReport;
end
go

create procedure Proc_QueryCPSalesManagerTransReport
	@StartDate datetime = '2012-01-01',
	@PeriodUnit nchar(4) = N'�Զ���',
	@EndDate datetime = '2012-02-29'
as
begin

--1. Check input
if (@StartDate is null or ISNULL(@PeriodUnit, N'') = N'' or (@PeriodUnit = N'�Զ���' and @EndDate is null))
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

if(@PeriodUnit = N'��')
begin
    set @CurrStartDate = @StartDate;
    set @CurrEndDate = DATEADD(week, 1, @StartDate);
    set @PrevStartDate = DATEADD(week, -1, @CurrStartDate);
    set @PrevEndDate = @CurrStartDate;
    set @LastYearStartDate = DATEADD(year, -1, @CurrStartDate); 
    set @LastYearEndDate = DATEADD(year, -1, @CurrEndDate);
end
else if(@PeriodUnit = N'��')
begin
    set @CurrStartDate = @StartDate;
    set @CurrEndDate = DATEADD(MONTH, 1, @StartDate);
    set @PrevStartDate = DATEADD(MONTH, -1, @CurrStartDate);
    set @PrevEndDate = @CurrStartDate;
    set @LastYearStartDate = DATEADD(year, -1, @CurrStartDate); 
    set @LastYearEndDate = DATEADD(year, -1, @CurrEndDate);
end
else if(@PeriodUnit = N'����')
begin
    set @CurrStartDate = @StartDate;
    set @CurrEndDate = DATEADD(QUARTER, 1, @StartDate);
    set @PrevStartDate = DATEADD(QUARTER, -1, @CurrStartDate);
    set @PrevEndDate = @CurrStartDate;
    set @LastYearStartDate = DATEADD(year, -1, @CurrStartDate); 
    set @LastYearEndDate = DATEADD(year, -1, @CurrEndDate);
end
else if(@PeriodUnit = N'����')
begin
    set @CurrStartDate = @StartDate;
    set @CurrEndDate = DATEADD(QUARTER, 2, @StartDate);
    set @PrevStartDate = DATEADD(QUARTER, -2, @CurrStartDate);
    set @PrevEndDate = @CurrStartDate;
    set @LastYearStartDate = DATEADD(year, -1, @CurrStartDate); 
    set @LastYearEndDate = DATEADD(year, -1, @CurrEndDate);
end
else if(@PeriodUnit = N'��')
begin
    set @CurrStartDate = @StartDate;
    set @CurrEndDate = DATEADD(YEAR, 1, @StartDate);
    set @PrevStartDate = DATEADD(YEAR, -1, @CurrStartDate);
    set @PrevEndDate = @CurrStartDate;
    set @LastYearStartDate = DATEADD(year, -1, @CurrStartDate); 
    set @LastYearEndDate = DATEADD(year, -1, @CurrEndDate);
end
else if(@PeriodUnit = N'�Զ���')
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

--3. Get #CurrCMCData
select
	MerchantNo,
	SUM(PurCnt) as CurrSucceedCount,
	SUM(PurAmt) as CurrSucceedAmount,
	SUM(FeeAmt) as CurrFeeAmt
into
	#CurrCMCData
from
	Table_FeeCalcResult
where
	FeeEndDate >= @CurrStartDate
	and
	FeeEndDate < @CurrEndDate
group by
	MerchantNo;


--3.1 Get #CurrORAData
select
	BankSettingID,
	MerchantNo,
	TransCount,
	FeeAmount
into
	#ORADataC
from
	Table_OraTransSum
where
	CPDate >= @CurrStartDate
	and
	CPDate < @CurrEndDate;

update
	ORAFee
set
	ORAFee.FeeAmount = ORAFee.TransCount * AdditionalRule.FeeValue
from
	#ORADataC ORAFee
	inner join
	Table_OraAdditionalFeeRule AdditionalRule
	on
		ORAFee.MerchantNo = AdditionalRule.MerchantNo;

select
	MerchantNo,
	SUM(TransCount) as CurrSucceedCount,
	SUM(TransAmount) as CurrSucceedAmount,
	(select SUM(#ORADataC.FeeAmount) from #ORADataC where MerchantNo = Table_OraTransSum.MerchantNo) CurrFeeAmt
into
	#CurrORAData
from
	Table_OraTransSum
where
	CPDate >= @CurrStartDate
	and
	CPDate < @CurrEndDate
group by
	MerchantNo;


--3.2 Get #CurrWUData
select
	MerchantNo,
	COUNT(DestTransAmount) as CurrSucceedCount,
	SUM(DestTransAmount) as CurrSucceedAmount,
	0 as CurrFeeAmt
into
	#CurrWUData
from
	dbo.Table_WUTransLog
where
	CPDate >= @CurrStartDate
	and
	CPDate < @CurrEndDate
group by
	MerchantNo;


--3.3 Get #UPOPData
select 
	Mer.CPMerchantNo,
	SUM(UPOP.PurCnt) PurCnt,
	SUM(UPOP.PurAmt) PurAmt,
	SUM(UPOP.FeeAmt) FeeAmt
into
	#UPOPData
from
	Table_UpopliqMerInfo Mer
	left join
	Table_UpopliqFeeLiqResult UPOP
	on
		Mer.MerchantNo = UPOP.MerchantNo
where
	TransDate >= @CurrStartDate
	and
	TransDate < @CurrEndDate
group by
	Mer.CPMerchantNo


--3.4 Curr All Data (#CurrData)
select
	coalesce(CurrCMCData.MerchantNo, CurrORAData.MerchantNo,UPOPData.CPMerchantNo) MerchantNo,
	ISNULL(CurrCMCData.CurrSucceedCount, 0) + ISNULL(CurrORAData.CurrSucceedCount, 0) + ISNULL(UPOPData.PurCnt, 0) CurrSucceedCount,
	ISNULL(CurrCMCData.CurrSucceedAmount, 0) + ISNULL(CurrORAData.CurrSucceedAmount, 0) + ISNULL(UPOPData.PurAmt, 0) CurrSucceedAmount,
	case when 
		Sales.MerchantClass in ('CP','CP-����','CP-����','EPOS')
	then
		ISNULL(CurrCMCData.CurrFeeAmt, 0) + ISNULL(CurrORAData.CurrFeeAmt, 0) + ISNULL(UPOPData.FeeAmt, 0)
	else
		0.0
	end
		CurrFeeAmt
into
	#CurrData
from
	#CurrCMCData CurrCMCData
	full outer join
	#CurrORAData CurrORAData
	on
		CurrCMCData.MerchantNo = CurrORAData.MerchantNo
	full outer join
	#UPOPData UPOPData
	on
		UPOPData.CPMerchantNo = coalesce(CurrCMCData.MerchantNo, CurrORAData.MerchantNo)
	right join
	Table_SalesDeptConfiguration Sales
	on
		Sales.MerchantNo = coalesce(UPOPData.CPMerchantNo,CurrCMCData.MerchantNo, CurrORAData.MerchantNo)
union all
select * from #CurrWUData;


--3.5 Get All TransAmt and LimitOpenTime FeeAmt
with LimitData as
(
select
	Table_MerInfo.MerchantNo,
	CurrData.CurrFeeAmt,
	Table_MerInfo.OpenTime
from 
	#CurrData CurrData
	left join 
	Table_MerInfo 
	on 
		CurrData.MerchantNo = Table_MerInfo.MerchantNo
where
	Table_MerInfo.OpenTime >= @CurrStartDate
	and
	Table_MerInfo.OpenTime < @CurrEndDate
)
select
	CurrData.MerchantNo,
	CurrData.CurrSucceedCount,
	CurrData.CurrSucceedAmount,
	LimitData.CurrFeeAmt
into
	#CurrLimitData
from
	#CurrData CurrData
	left join
	LimitData
	on
		CurrData.MerchantNo = LimitData.MerchantNo;


--4. Get #PrevCMCData
select
	MerchantNo,
	SUM(PurCnt) as PrevSucceedCount,
	SUM(PurAmt) as PrevSucceedAmount,
	SUM(FeeAmt) as PrevFeeAmt
into
	#PrevCMCData
from
	Table_FeeCalcResult
where
	FeeEndDate >= @PrevStartDate
	and
	FeeEndDate < @PrevEndDate
group by
	MerchantNo;


--4.1 Get #PrevORAData
select
	BankSettingID,
	MerchantNo,
	TransCount,
	FeeAmount
into
	#ORADataP
from
	Table_OraTransSum
where
	CPDate >= @PrevStartDate
	and
	CPDate < @PrevEndDate;

update
	ORAFee
set
	ORAFee.FeeAmount = ORAFee.TransCount * AdditionalRule.FeeValue
from
	#ORADataP ORAFee
	inner join
	Table_OraAdditionalFeeRule AdditionalRule
	on
		ORAFee.MerchantNo = AdditionalRule.MerchantNo;

select
	MerchantNo,
	SUM(TransCount) as PrevSucceedCount,
	SUM(TransAmount) as PrevSucceedAmount,
	(select SUM(#ORADataP.FeeAmount) from #ORADataP where MerchantNo = Table_OraTransSum.MerchantNo) PrevFeeAmt
into
	#PrevORAData
from
	Table_OraTransSum
where
	CPDate >= @PrevStartDate
	and
	CPDate < @PrevEndDate
group by
	MerchantNo;


--4.2 Get #PrevWUData
select
	MerchantNo,
	COUNT(DestTransAmount) as PrevSucceedCount,
	SUM(DestTransAmount) as PrevSucceedAmount,
	0 as PrevFeeAmt
into
	#PrevWUData
from
	dbo.Table_WUTransLog
where
	CPDate >= @PrevStartDate
	and
	CPDate < @PrevEndDate
group by
	MerchantNo;


--4.3 Get #PrevUPOPData
select 
	Mer.CPMerchantNo,
	SUM(UPOP.PurCnt) PurCnt,
	SUM(UPOP.PurAmt) PurAmt,
	SUM(UPOP.FeeAmt) FeeAmt
into
	#PrevUPOPData
from
	Table_UpopliqMerInfo Mer
	left join
	Table_UpopliqFeeLiqResult UPOP
	on
		Mer.MerchantNo = UPOP.MerchantNo
where
	TransDate >= @PrevStartDate
	and
	TransDate < @PrevEndDate
group by
	Mer.CPMerchantNo;


--4.4 Prev All Data
select
	coalesce(PrevCMCData.MerchantNo, PrevORAData.MerchantNo,PervUPOPData.CPMerchantNo) MerchantNo,
	ISNULL(PrevCMCData.PrevSucceedCount, 0) + ISNULL(PrevORAData.PrevSucceedCount, 0) + ISNULL(PervUPOPData.PurCnt, 0) PrevSucceedCount,
	ISNULL(PrevCMCData.PrevSucceedAmount, 0) + ISNULL(PrevORAData.PrevSucceedAmount, 0) + ISNULL(PervUPOPData.PurAmt, 0) PrevSucceedAmount,
	case when
		Sales.MerchantClass in ('CP','CP-����','CP-����','EPOS')
	then
		ISNULL(PrevCMCData.PrevFeeAmt, 0) + ISNULL(PrevORAData.PrevFeeAmt, 0) + ISNULL(PervUPOPData.FeeAmt, 0) 
	else
		0.0
	end
		PrevFeeAmt
into
	#PrevData
from
	#PrevCMCData PrevCMCData
	full outer join
	#PrevORAData PrevORAData
	on
		PrevCMCData.MerchantNo = PrevORAData.MerchantNo
	full outer join
	#PrevUPOPData PervUPOPData
	on
		PervUPOPData.CPMerchantNo = coalesce(PrevCMCData.MerchantNo, PrevORAData.MerchantNo)
	right join
	Table_SalesDeptConfiguration Sales
	on
		Sales.MerchantNo = coalesce(PervUPOPData.CPMerchantNo,PrevCMCData.MerchantNo,PrevORAData.MerchantNo)
union all
select * from #PrevWUData;
		

--5. Get #LastYearCMCData
select
	MerchantNo,
	SUM(PurCnt) as LastYearSucceedCount,
	SUM(PurAmt) as LastYearSucceedAmount,
	SUM(FeeAmt) as LastYearFeeAmt
into
	#LastYearCMCData
from
	Table_FeeCalcResult
where
	FeeEndDate >= @LastYearStartDate
	and
	FeeEndDate < @LastYearEndDate
group by
	MerchantNo;


--5.1 Get #LastYearORAData
select
	BankSettingID,
	MerchantNo,
	TransCount,
	FeeAmount
into
	#ORADataL
from
	Table_OraTransSum
where
	CPDate >= @LastYearStartDate
	and
	CPDate < @LastYearEndDate;

update
	ORAFee
set
	ORAFee.FeeAmount = ORAFee.TransCount * AdditionalRule.FeeValue
from
	#ORADataL ORAFee
	inner join
	Table_OraAdditionalFeeRule AdditionalRule
	on
		ORAFee.MerchantNo = AdditionalRule.MerchantNo;

select
	MerchantNo,
	SUM(TransCount) as LastYearSucceedCount,
	SUM(TransAmount) as LastYearSucceedAmount,
	(select SUM(#ORADataL.FeeAmount) from #ORADataL where MerchantNo = Table_OraTransSum.MerchantNo) LastYearFeeAmt
into
	#LastYearORAData
from
	Table_OraTransSum
where
	CPDate >= @LastYearStartDate
	and
	CPDate < @LastYearEndDate
group by
	MerchantNo;


--5.2 Get #LastYearWUData
select
	MerchantNo,
	COUNT(DestTransAmount) as LastYearSucceedCount,
	SUM(DestTransAmount) as LastYearSucceedAmount,
	0 as LastYearFeeAmt
into
	#LastYearWUData
from
	dbo.Table_WUTransLog
where
	CPDate >= @LastYearStartDate
	and
	CPDate < @LastYearEndDate
group by
	MerchantNo;


--5.3 Get #LastYearUPOPData
select 
	Mer.CPMerchantNo,
	SUM(UPOP.PurCnt) PurCnt,
	SUM(UPOP.PurAmt) PurAmt,
	SUM(UPOP.FeeAmt) FeeAmt
into
	#LastYearUPOPData
from
	Table_UpopliqMerInfo Mer
	left join
	Table_UpopliqFeeLiqResult UPOP
	on
		Mer.MerchantNo = UPOP.MerchantNo
where
	TransDate >= @LastYearStartDate
	and
	TransDate < @LastYearEndDate
group by
	Mer.CPMerchantNo


--5.4 LastYear All Data
select
	coalesce(LastYearCMCData.MerchantNo, LastYearORAData.MerchantNo,LastYearUPOPData.CPMerchantNo) MerchantNo,
	ISNULL(LastYearCMCData.LastYearSucceedCount, 0) + ISNULL(LastYearORAData.LastYearSucceedCount, 0) + ISNULL(LastYearUPOPData.PurCnt, 0) LastYearSucceedCount,
	ISNULL(LastYearCMCData.LastYearSucceedAmount, 0) + ISNULL(LastYearORAData.LastYearSucceedAmount, 0) + ISNULL(LastYearUPOPData.PurAmt, 0) LastYearSucceedAmount,
	case when
		Sales.MerchantClass in ('CP','CP-����','CP-����','EPOS')
	then
		ISNULL(LastYearCMCData.LastYearFeeAmt, 0) + ISNULL(LastYearORAData.LastYearFeeAmt, 0) + ISNULL(LastYearUPOPData.FeeAmt, 0) 
	else
		0.0
	end
		LastYearFeeAmt
into
	#LastYearData
from
	#LastYearCMCData LastYearCMCData
	full outer join
	#LastYearORAData LastYearORAData
	on
		LastYearCMCData.MerchantNo = LastYearORAData.MerchantNo
	full outer join
	#LastYearUPOPData LastYearUPOPData
	on
		LastYearUPOPData.CPMerchantNo = coalesce(LastYearCMCData.MerchantNo, LastYearORAData.MerchantNo)
	right join
	Table_SalesDeptConfiguration Sales
	on
		Sales.MerchantNo = coalesce(LastYearUPOPData.CPMerchantNo,LastYearCMCData.MerchantNo, LastYearORAData.MerchantNo)
union all
select * from #LastYearWUData;


with LimitData as
(
select
	Table_MerInfo.MerchantNo,
	LastYearData.LastYearFeeAmt,
	Table_MerInfo.OpenTime
from 
	#LastYearData LastYearData
	left join 
	Table_MerInfo 
	on 
		LastYearData.MerchantNo = Table_MerInfo.MerchantNo
where
	Table_MerInfo.OpenTime >= @LastYearStartDate
	and
	Table_MerInfo.OpenTime < @LastYearEndDate
)
select
	LastYearData.MerchantNo,
	LastYearData.LastYearSucceedCount,
	LastYearData.LastYearSucceedAmount,
	LimitData.LastYearFeeAmt
into
	#LastYearDataLimitData
from
	#LastYearData LastYearData
	left join
	LimitData
	on
		LastYearData.MerchantNo = LimitData.MerchantNo;



--6. Get #ThisYearCMCData
select
	MerchantNo,
	SUM(PurCnt) as ThisYearSucceedCount,
	SUM(PurAmt) as ThisYearSucceedAmount,
	SUM(FeeAmt) as ThisYearFeeAmt
into
	#ThisYearCMCData
from
	Table_FeeCalcResult
where
	FeeEndDate >= @ThisYearRunningStartDate
	and
	FeeEndDate < @ThisYearRunningEndDate
group by
	MerchantNo;


--6.1 Get #ThisYearORAData
select
	BankSettingID,
	MerchantNo,
	TransCount,
	FeeAmount
into
	#ORADataT
from
	Table_OraTransSum
where
	CPDate >= @ThisYearRunningStartDate
	and
	CPDate < @ThisYearRunningEndDate;

update
	ORAFee
set
	ORAFee.FeeAmount = ORAFee.TransCount * AdditionalRule.FeeValue
from
	#ORADataT ORAFee
	inner join
	Table_OraAdditionalFeeRule AdditionalRule
	on
		ORAFee.MerchantNo = AdditionalRule.MerchantNo;

select
	MerchantNo,
	SUM(TransCount) as ThisYearSucceedCount,
	SUM(TransAmount) as ThisYearSucceedAmount,
	(select SUM(#ORADataT.FeeAmount) from #ORADataT where MerchantNo = Table_OraTransSum.MerchantNo) ThisYearFeeAmt
into
	#ThisYearORAData
from
	Table_OraTransSum
where
	CPDate >= @ThisYearRunningStartDate
	and
	CPDate < @ThisYearRunningEndDate
group by
	MerchantNo;


--6.2 Get #ThisYearWUData
select
	MerchantNo,
	COUNT(DestTransAmount) as ThisYearSucceedCount,
	SUM(DestTransAmount) as ThisYearSucceedAmount,
	0 as PrevFeeAmt
into
	#ThisYearWUData
from
	dbo.Table_WUTransLog
where
	CPDate >= @ThisYearRunningStartDate
	and
	CPDate < @ThisYearRunningEndDate
group by
	MerchantNo;


--6.3 Get #ThisYearUPOPData
select 
	Mer.CPMerchantNo,
	SUM(UPOP.PurCnt) PurCnt,
	SUM(UPOP.PurAmt) PurAmt,
	SUM(UPOP.FeeAmt) FeeAmt
into
	#ThisYearUPOPData
from
	Table_UpopliqMerInfo Mer
	left join
	Table_UpopliqFeeLiqResult UPOP
	on
		Mer.MerchantNo = UPOP.MerchantNo
where
	TransDate >= @ThisYearRunningStartDate
	and
	TransDate < @ThisYearRunningEndDate
group by
	Mer.CPMerchantNo;


--6.4 ThisYear All Data
select
	coalesce(ThisYearCMCData.MerchantNo, ThisYearORAData.MerchantNo,ThisYearUPOPData.CPMerchantNo) MerchantNo,
	ISNULL(ThisYearCMCData.ThisYearSucceedCount, 0) + ISNULL(ThisYearORAData.ThisYearSucceedCount, 0) + ISNULL(ThisYearUPOPData.PurCnt, 0) ThisYearSucceedCount,
	ISNULL(ThisYearCMCData.ThisYearSucceedAmount, 0) + ISNULL(ThisYearORAData.ThisYearSucceedAmount, 0) + ISNULL(ThisYearUPOPData.PurAmt, 0) ThisYearSucceedAmount,
	case when
		Sales.MerchantClass in ('CP','CP-����','CP-����','EPOS')
	then
		ISNULL(ThisYearCMCData.ThisYearFeeAmt, 0) + ISNULL(ThisYearORAData.ThisYearFeeAmt, 0) + ISNULL(ThisYearUPOPData.FeeAmt, 0)
	else
		0.0
	end
		ThisYearFeeAmt
into
	#ThisYearData
from
	#ThisYearCMCData ThisYearCMCData
	full outer join
	#ThisYearORAData ThisYearORAData
	on
		ThisYearCMCData.MerchantNo = ThisYearORAData.MerchantNo
	full outer join
	#ThisYearUPOPData ThisYearUPOPData
	on
		ThisYearUPOPData.CPMerchantNo = coalesce(ThisYearCMCData.MerchantNo,ThisYearORAData.MerchantNo)
	right join
	Table_SalesDeptConfiguration Sales
	on
		Sales.MerchantNo = coalesce(ThisYearUPOPData.CPMerchantNo,ThisYearCMCData.MerchantNo,ThisYearORAData.MerchantNo)
union all
select * from #ThisYearWUData;


--7. Convert Currency Rate
update
	CD
set
	CD.CurrSucceedAmount = CD.CurrSucceedAmount * CR.CurrencyRate
from
	#CurrLimitData CD
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
	#LastYearDataLimitData LYD
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
		ISNULL(SUM(CurrLimit.CurrSucceedCount),0) CurrSucceedCount,
		Convert(decimal,ISNULL(SUM(CurrLimit.CurrSucceedAmount),0))/100 CurrSucceedAmount,
		Convert(decimal,ISNULL(SUM(Prev.PrevSucceedAmount),0))/100 PrevSucceedAmount,
		Convert(decimal,ISNULL(SUM(LastYearLimit.LastYearSucceedAmount),0))/100 LastYearSucceedAmount,
		Convert(decimal,ISNULL(SUM(ThisYear.ThisYearSucceedAmount),0))/100 ThisYearSucceedAmount,
		case when ISNULL(SUM(Prev.PrevSucceedAmount), 0) = 0
			then 0
			else CONVERT(decimal, ISNULL(SUM(CurrLimit.CurrSucceedAmount), 0) - ISNULL(SUM(Prev.PrevSucceedAmount), 0))/SUM(Prev.PrevSucceedAmount)
		end SeqAmountIncrementRatio,
		case when ISNULL(SUM(LastYearLimit.LastYearSucceedAmount), 0) = 0
			then 0
			else CONVERT(decimal, ISNULL(SUM(CurrLimit.CurrSucceedAmount), 0) - ISNULL(SUM(LastYearLimit.LastYearSucceedAmount), 0))/SUM(LastYearLimit.LastYearSucceedAmount)
		end YOYAmountIncrementRatio,
		Convert(decimal,ISNULL(SUM(CurrLimit.CurrFeeAmt),0))/100.0 as CurrFeeAmt,
		Convert(decimal,ISNULL(SUM(Prev.PrevFeeAmt),0))/100.0 as PrevFeeAmt,
		Convert(decimal,ISNULL(SUM(LastYearLimit.LastYearFeeAmt),0))/100.0 as LastYearFeeAmt,
		Convert(decimal,ISNULL(SUM(ThisYear.ThisYearFeeAmt),0))/100.0 as ThisYearFeeAmt,
		case when ISNULL(SUM(Prev.PrevFeeAmt), 0) = 0
			then 0
			else CONVERT(decimal, ISNULL(SUM(CurrLimit.CurrFeeAmt), 0) - ISNULL(SUM(Prev.PrevFeeAmt), 0))/SUM(Prev.PrevFeeAmt)
		end SeqFeeAmtIncrementRatio,
		case when ISNULL(SUM(LastYearLimit.LastYearFeeAmt), 0) = 0
			then 0
			else CONVERT(decimal, ISNULL(SUM(CurrLimit.CurrFeeAmt), 0) - ISNULL(SUM(LastYearLimit.LastYearFeeAmt), 0))/SUM(LastYearLimit.LastYearFeeAmt)
		end YOYFeeAmtIncrementRatio
	from
		Table_SalesDeptConfiguration Sales
		left join
		#CurrLimitData CurrLimit
		on
			Sales.MerchantNo = CurrLimit.MerchantNo
		left join
		#PrevData Prev
		on
			Sales.MerchantNo = Prev.MerchantNo
		left join
		#LastYearDataLimitData LastYearLimit
		on
			Sales.MerchantNo = LastYearLimit.MerchantNo
		left join
		#ThisYearData ThisYear
		on
			Sales.MerchantNo = ThisYear.MerchantNo
	group by
		Sales.SalesManager
),
SumFee as 
(
	select
		EmpName,
		SUM(FeeAmt) EarlyFeeAmt
	from
		Table_SalesProjectFee
	where
		TransDate >= @CurrStartDate
		and
		TransDate < @CurrEndDate
	group by
		EmpName
),
ThisYearSumFee as 
(
	select
		EmpName,
		SUM(FeeAmt) ThisYearEarlyFeeAmt
	from
		Table_SalesProjectFee
	where
		TransDate >= @ThisYearRunningStartDate
		and
		TransDate < @ThisYearRunningEndDate
	group by
		EmpName
)
select
	ISNULL(KPIData.BizUnit,N'����') BizUnit,
	case when 
		KPIData.BizUnit = '����' 
	then 1 
	when KPIData.BizUnit = 'ֱ��-�̻�ά��' 
	then 2 
	when KPIData.BizUnit = 'ֱ��-����' 
	then 3 
	when KPIData.BizUnit = 'ֱ��-����' 
	then 4 
	when KPIData.BizUnit = 'ƽ̨-����' 
	then 5 
	when KPIData.BizUnit = 'ƽ̨-����' 
	then 6  
	when KPIData.BizUnit = 'ƽ̨-�̳�' 
	then 7 
	when KPIData.BizUnit = '����-�г����۲�' 
	then 8 
	else 9 
	end as OrderID,
	coalesce(KPIData.EmpName,Sales.SalesManager) SalesManager,
	ISNULL(KPIData.KPIValue,0)/100 as KPIValue,
	case when ISNULL(KPIData.KPIValue,0) = 0 
		 then 0
		 else 100*ISNULL(Sales.ThisYearSucceedAmount,0)/KPIData.KPIValue
	end Achievement,
	ISNULL(KPIData.FeeKPI,0)/100 as FeeKPI,
	case when ISNULL(KPIData.FeeKPI,0) = 0
	     then 0 
	     else ISNULL((100*ISNULL(Sales.ThisYearFeeAmt,0) + ISNULL(ThisYearSumFee.ThisYearEarlyFeeAmt,0))/KPIData.FeeKPI,0)
	end AchievementFee,
	ISNULL(Sales.CurrSucceedAmount,0) CurrSucceedAmount,
	ISNULL(Sales.CurrSucceedCount,0) CurrSucceedCount,
	ISNULL(Sales.PrevSucceedAmount,0) PrevSucceedAmount,
	ISNULL(Sales.LastYearSucceedAmount,0) LastYearSucceedAmount,
	ISNULL(Sales.ThisYearSucceedAmount,0) ThisYearSucceedAmount,
	ISNULL(Sales.SeqAmountIncrementRatio,0) SeqAmountIncrementRatio,
	ISNULL(Sales.YOYAmountIncrementRatio,0) YOYAmountIncrementRatio,
	ISNULL(Sales.CurrFeeAmt,0) CurrFeeAmt,
	ISNULL(Sales.PrevFeeAmt,0) PrevFeeAmt,
	ISNULL(Sales.LastYearFeeAmt,0) LastYearFeeAmt,
	ISNULL(Sales.ThisYearFeeAmt,0) ThisYearFeeAmt,
	ISNULL(SumFee.EarlyFeeAmt,0)/100.0 as EarlyFeeAmt,
	ISNULL(ThisYearSumFee.ThisYearEarlyFeeAmt,0)/100.0 as ThisYearEarlyFeeAmt,
	ISNULL(Sales.SeqFeeAmtIncrementRatio,0) SeqFeeAmtIncrementRatio,
	ISNULL(Sales.YOYFeeAmtIncrementRatio,0) YOYFeeAmtIncrementRatio
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
		PeriodStartDate <  @ThisYearRunningEndDate
	)KPIData
	on
		Sales.SalesManager = KPIData.EmpName
	left join
	SumFee
	on
		Sales.SalesManager = SumFee.EmpName
	left join
	ThisYearSumFee
	on
		Sales.SalesManager = ThisYearSumFee.EmpName
order by 
	OrderID,
	BizUnit;


--7. Clear temp table
drop table #CurrData;
drop table #CurrLimitData;
drop table #PrevData;
drop table #LastYearData;
drop table #LastYearDataLimitData;
drop table #ThisYearData;

end 