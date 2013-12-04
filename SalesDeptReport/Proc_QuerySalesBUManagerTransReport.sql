--[Modified] on 2012-06-08 By 王红燕 Description:Add West Union Trans Data
--[Modified] on 2013-03-05 By 王红燕 Description:Modify Channel Info 
--[Modified] on 2013-05-06 By 丁俊昊 Description:Add FeeAmt Data and MerchantNo
--[Modified] on 2013-10-23 By 丁俊昊 Description:Add TraScreenSum Data
--对应前台:客户经理商户交易量统计表

if OBJECT_ID(N'Proc_QuerySalesBUManagerTransReport', N'P') is not null
begin
	drop procedure Proc_QuerySalesBUManagerTransReport;
end
go

create procedure Proc_QuerySalesBUManagerTransReport
	@StartDate datetime = '2012-01-01',
	@PeriodUnit nchar(4) = N'自定义',
	@EndDate datetime = '2012-02-01'
as
begin

--1. Check input
if (@StartDate is null or ISNULL(@PeriodUnit, N'') = N'' or (@PeriodUnit = N'自定义' and @EndDate is null))
begin
	raiserror(N'Input params cannot be empty in Proc_QuerySalesBUManagerTransReport', 16, 1);
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


--3. Get #CurrCMCData
with AllFeeCalcData as
(
	select
		MerchantNo,
		SUM(PurCnt) as CurrSucceedCount,
		SUM(PurAmt) as CurrSucceedAmount,
		SUM(FeeAmt) as CurrFeeAmt
	from
		Table_FeeCalcResult
	where
		FeeEndDate >= @CurrStartDate
		and
		FeeEndDate < @CurrEndDate
	group by
		MerchantNo
	union all
	select
		MerchantNo,
		SUM(CalFeeCnt) as CurrSucceedCount,
		SUM(CalFeeAmt) as CurrSucceedAmount,
		SUM(FeeAmt) as CurrFeeAmt		
	from
		Table_TraScreenSum
	where
		CPDate >= @CurrStartDate
		and
		CPDate <  @CurrEndDate
		and
		TransType in ('100004','100001')
	group by
		MerchantNo
)
	select
		MerchantNo,
		SUM(CurrSucceedCount) as CurrSucceedCount,
		SUM(CurrSucceedAmount) as CurrSucceedAmount,
		SUM(CurrFeeAmt) as CurrFeeAmt
	into
		#CurrCMCData
	from
		AllFeeCalcData
	group by
		MerchantNo;


--3.1 Get #CurrORAData
with AllOra as
(
	select
		MerchantNo,
		SUM(TransCount) as CurrSucceedCount,
		SUM(TransAmount) as CurrSucceedAmount,
		SUM(FeeAmount) as CurrFeeAmt
	from
		Table_OraTransSum
	where
		CPDate >= @CurrStartDate
		and
		CPDate < @CurrEndDate
	group by
		MerchantNo
	union all
	select
		MerchantNo,
		SUM(CalFeeCnt) as CurrSucceedCount,
		SUM(CalFeeAmt) as CurrSucceedAmount,
		SUM(FeeAmt) as CurrFeeAmt		
	from
		Table_TraScreenSum
	where
		CPDate >= @CurrStartDate
		and
		CPDate <  @CurrEndDate
		and
		TransType in ('100002','100005')
	group by
		MerchantNo
)
	select
		AllOra.MerchantNo,
		SUM(CurrSucceedCount) CurrSucceedCount,
		SUM(CurrSucceedAmount) CurrSucceedAmount,
		SUM(isnull(AllOra.CurrSucceedCount * Additional.FeeValue, AllOra.CurrFeeAmt)) as CurrFeeAmt
	into
		#CurrORAData
	from
		AllOra
		left join
		Table_OraAdditionalFeeRule Additional
		on
			AllOra.MerchantNo = Additional.MerchantNo
	group by
		AllOra.MerchantNo;


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
	ISNULL(CurrCMCData.CurrFeeAmt, 0) + ISNULL(CurrORAData.CurrFeeAmt, 0) + ISNULL(UPOPData.FeeAmt, 0) CurrFeeAmt
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
union all
select * from #CurrWUData;


--4. Get #PrevCMCData
with AllFeeCalcData as
(
	select
		MerchantNo,
		SUM(PurCnt) as PrevSucceedCount,
		SUM(PurAmt) as PrevSucceedAmount,
		SUM(FeeAmt) as PrevFeeAmt
	from
		Table_FeeCalcResult
	where
		FeeEndDate >= @PrevStartDate
		and
		FeeEndDate < @PrevEndDate
	group by
		MerchantNo
	union all
	select
		MerchantNo,
		SUM(CalFeeCnt) as PrevSucceedCount,
		SUM(CalFeeAmt) as PrevSucceedAmount,
		SUM(FeeAmt) as PrevFeeAmt		
	from
		Table_TraScreenSum
	where
		CPDate >= @PrevStartDate
		and
		CPDate <  @PrevEndDate
		and
		TransType in ('100004','100001')
	group by
		MerchantNo
)
	select
		MerchantNo,
		SUM(PrevSucceedCount) as PrevSucceedCount,
		SUM(PrevSucceedAmount) as PrevSucceedAmount,
		SUM(PrevFeeAmt) as PrevFeeAmt
	into
		#PrevCMCData
	from
		AllFeeCalcData
	group by
		MerchantNo;


--4.1 Get #PrevORAData
with AllORA as
(
	select
		MerchantNo,
		SUM(TransCount) as PrevSucceedCount,
		SUM(TransAmount) as PrevSucceedAmount,
		SUM(FeeAmount) as PrevFeeAmt
	from
		Table_OraTransSum
	where
		CPDate >= @PrevStartDate
		and
		CPDate < @PrevEndDate
	group by
		MerchantNo
	union all
	select
		MerchantNo,
		SUM(CalFeeCnt) as PrevSucceedCount,
		SUM(CalFeeAmt) as PrevSucceedAmount,
		SUM(FeeAmt) as PrevFeeAmt		
	from
		Table_TraScreenSum
	where
		CPDate >= @PrevStartDate
		and
		CPDate <  @PrevEndDate
		and
		TransType in ('100005','100002')
	group by
		MerchantNo
)
	select
		AllORA.MerchantNo,
		SUM(PrevSucceedCount) as PrevSucceedCount,
		SUM(PrevSucceedAmount) as PrevSucceedAmount,
		SUM(ISNULL(AllOra.PrevSucceedCount * Additional.FeeValue, AllOra.PrevFeeAmt)) as PrevFeeAmt
	into
		#PrevORAData
	from
		AllORA
		left join
		Table_OraAdditionalFeeRule Additional
		on
			AllOra.MerchantNo = Additional.MerchantNo
	group by
		AllOra.MerchantNo;



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
	ISNULL(PrevCMCData.PrevFeeAmt, 0) + ISNULL(PrevORAData.PrevFeeAmt, 0) + ISNULL(PervUPOPData.FeeAmt, 0) PrevFeeAmt
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
union all
select * from #PrevWUData;


--5. Get #LastYearCMCData
with AllFeeCalcData as
(
	select
		MerchantNo,
		SUM(PurCnt) as LastYearSucceedCount,
		SUM(PurAmt) as LastYearSucceedAmount,
		SUM(FeeAmt) as LastYearFeeAmt
	from
		Table_FeeCalcResult
	where
		FeeEndDate >= @LastYearStartDate
		and
		FeeEndDate < @LastYearEndDate
	group by
		MerchantNo
	union all
	select
		MerchantNo,
		SUM(CalFeeCnt) as LastYearSucceedCount,
		SUM(CalFeeAmt) as LastYearSucceedAmount,
		SUM(FeeAmt) as LastYearFeeAmt		
	from
		Table_TraScreenSum
	where
		CPDate >= @LastYearStartDate
		and
		CPDate <  @LastYearEndDate
		and
		TransType in ('100004','100001')
	group by
		MerchantNo
)
	select
		MerchantNo,
		SUM(LastYearSucceedCount) as LastYearSucceedCount,
		SUM(LastYearSucceedAmount) as LastYearSucceedAmount,
		SUM(LastYearFeeAmt) as LastYearFeeAmt
	into
		#LastYearCMCData
	from
		AllFeeCalcData
	group by
		MerchantNo;


--5.1 Get #LastYearORAData
with AllOra as
(
	select
		MerchantNo,
		SUM(TransCount) as TransCnt,
		SUM(TransAmount) as TransAmt,
		SUM(FeeAmount) as FeeAmt
	from
		Table_OraTransSum
	where
		CPDate >= @LastYearStartDate
		and
		CPDate < @LastYearEndDate
	group by
		MerchantNo
	union all
	select
		MerchantNo,
		SUM(CalFeeCnt) as TransCnt,
		SUM(CalFeeAmt) as TransAmt,
		SUM(FeeAmt) as FeeAmt		
	from
		Table_TraScreenSum
	where
		CPDate >= @LastYearStartDate
		and
		CPDate <  @LastYearEndDate
		and
		TransType in ('100002','100005')
	group by
		MerchantNo
)
	select
		AllOra.MerchantNo,
		SUM(TransCnt) LastYearSucceedCount,
		SUM(TransAmt) LastYearSucceedAmount,
		SUM(isnull(AllOra.TransCnt * Additional.FeeValue, AllOra.FeeAmt)) as LastYearFeeAmt
	into
		#LastYearORAData
	from
		AllOra
		left join 
		Table_OraAdditionalFeeRule Additional
		on
			AllOra.MerchantNo = Additional.MerchantNo
	group by
		AllOra.MerchantNo;


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
	ISNULL(LastYearCMCData.LastYearFeeAmt, 0) + ISNULL(LastYearORAData.LastYearFeeAmt, 0) + ISNULL(LastYearUPOPData.FeeAmt, 0) LastYearFeeAmt
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
union all
select * from #LastYearWUData;


--6. Get #ThisYearCMCData
with AllFeeCalcData as
(
	select
		MerchantNo,
		SUM(PurCnt) as ThisYearSucceedCount,
		SUM(PurAmt) as ThisYearSucceedAmount,
		SUM(FeeAmt) as ThisYearFeeAmt
	from
		Table_FeeCalcResult
	where
		FeeEndDate >= @ThisYearRunningStartDate
		and
		FeeEndDate < @ThisYearRunningEndDate
	group by
		MerchantNo
	union all
	select
		MerchantNo,
		SUM(CalFeeCnt) as ThisYearSucceedCount,
		SUM(CalFeeAmt) as ThisYearSucceedAmount,
		SUM(FeeAmt) as ThisYearFeeAmt		
	from
		Table_TraScreenSum
	where
		CPDate >= @ThisYearRunningStartDate
		and
		CPDate <  @ThisYearRunningEndDate
		and
		TransType in ('100004','100001')
	group by
		MerchantNo
)
	select
		MerchantNo,
		SUM(ThisYearSucceedCount) as ThisYearSucceedCount,
		SUM(ThisYearSucceedAmount) as ThisYearSucceedAmount,
		SUM(ThisYearFeeAmt) as ThisYearFeeAmt
	into
		#ThisYearCMCData
	from
		AllFeeCalcData
	group by
		MerchantNo;


--6.1 Get #ThisYearORAData
with AllOra as
(
	select
		MerchantNo,
		SUM(TransCount) as TransCnt,
		SUM(TransAmount) as TransAmt,
		SUM(FeeAmount) as FeeAmt
	from
		Table_OraTransSum
	where
		CPDate >= @ThisYearRunningStartDate
		and
		CPDate < @ThisYearRunningEndDate
	group by
		MerchantNo
	union all
	select
		MerchantNo,
		SUM(CalFeeCnt) as TransCnt,
		SUM(CalFeeAmt) as TransAmt,
		SUM(FeeAmt) as FeeAmt		
	from
		Table_TraScreenSum
	where
		CPDate >= @ThisYearRunningStartDate
		and
		CPDate <  @ThisYearRunningEndDate
		and
		TransType in ('100002','100005')
	group by
		MerchantNo
)
	select
		AllOra.MerchantNo,
		SUM(TransCnt) ThisYearSucceedCount,
		SUM(TransAmt) ThisYearSucceedAmount,
		SUM(isnull(AllOra.TransCnt * Additional.FeeValue, AllOra.FeeAmt)) as ThisYearFeeAmt
	into
		#ThisYearORAData
	from
		AllOra
		left join 
		Table_OraAdditionalFeeRule Additional
		on
			AllOra.MerchantNo = Additional.MerchantNo
	group by
		AllOra.MerchantNo;


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
	ISNULL(ThisYearCMCData.ThisYearFeeAmt, 0) + ISNULL(ThisYearORAData.ThisYearFeeAmt, 0) + ISNULL(ThisYearUPOPData.FeeAmt, 0) ThisYearFeeAmt
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
		ThisYearUPOPData.CPMerchantNo = coalesce(ThisYearCMCData.MerchantNo, ThisYearORAData.MerchantNo)
union all
select * from #ThisYearWUData;


--7. Convert Currency Rate
update
	CD
set
	CD.CurrSucceedAmount = CD.CurrSucceedAmount * CR.CurrencyRate,
	CD.CurrFeeAmt = CD.CurrFeeAmt * CR.CurrencyRate
from
	#CurrData CD
	inner join
	Table_SalesCurrencyRate CR
	on
		CD.MerchantNo = CR.MerchantNo;
		
update
	PD
set
	PD.PrevSucceedAmount = PD.PrevSucceedAmount * CR.CurrencyRate,
	PD.PrevFeeAmt = PD.PrevFeeAmt * CR.CurrencyRate
from
	#PrevData PD
	inner join
	Table_SalesCurrencyRate CR
	on
		PD.MerchantNo = CR.MerchantNo;
		
update
	LYD
set
	LYD.LastYearSucceedAmount = LYD.LastYearSucceedAmount * CR.CurrencyRate,
	LYD.LastYearFeeAmt = LYD.LastYearFeeAmt * CR.CurrencyRate
from
	#LastYearData LYD
	inner join
	Table_SalesCurrencyRate CR
	on
		LYD.MerchantNo = CR.MerchantNo;
	
update
	TYD
set
	TYD.ThisYearSucceedAmount = TYD.ThisYearSucceedAmount * CR.CurrencyRate,
	TYD.ThisYearFeeAmt = TYD.ThisYearFeeAmt * CR.CurrencyRate
from
	#ThisYearData TYD
	inner join
	Table_SalesCurrencyRate CR
	on
		TYD.MerchantNo = CR.MerchantNo;

	
--8. Get Final Result
select
	ISNULL(BUData.BizUnit,N'市场销售部') BizUnit,
	ISNULL(Sales.SalesManager,N'') SalesManager,
	ISNULL(Sales.MerchantClass,N'') Channel,
	ISNULL(Sales.BranchOffice,N'') BranchOffice,
	Sales.MerchantName,
	Sales.MerchantNo,
	Convert(decimal,ISNULL(SUM(Curr.CurrSucceedAmount),0))/100 CurrSucceedAmount,
	Convert(decimal,ISNULL(SUM(Prev.PrevSucceedAmount),0))/100 PrevSucceedAmount,
	Convert(decimal,ISNULL(SUM(LastYear.LastYearSucceedAmount),0))/100 LastYearSucceedAmount,
	ISNULL(SUM(Curr.CurrSucceedCount),0) CurrSucceedCount,
	Convert(decimal,ISNULL(SUM(ThisYear.ThisYearSucceedAmount),0))/100 ThisYearSucceedAmount,
	case when ISNULL(SUM(Prev.PrevSucceedAmount), 0) = 0
		then 0
		else CONVERT(decimal, ISNULL(SUM(Curr.CurrSucceedAmount), 0) - ISNULL(SUM(Prev.PrevSucceedAmount), 0))/SUM(Prev.PrevSucceedAmount)
	end SeqAmountIncrementRatio,
	case when ISNULL(SUM(LastYear.LastYearSucceedAmount), 0) = 0
		then 0
		else CONVERT(decimal, ISNULL(SUM(Curr.CurrSucceedAmount), 0) - ISNULL(SUM(LastYear.LastYearSucceedAmount), 0))/SUM(LastYear.LastYearSucceedAmount)
	end YOYAmountIncrementRatio,
	Convert(decimal,ISNULL(SUM(Curr.CurrSucceedAmount), 0) - ISNULL(SUM(LastYear.LastYearSucceedAmount), 0))/100 as YOYAmountIncrement,
	Convert(decimal,ISNULL(SUM(Curr.CurrFeeAmt),0))/100.0 as CurrFeeAmt,
	Convert(decimal,ISNULL(SUM(Prev.PrevFeeAmt),0))/100.0 as PrevFeeAmt,
	Convert(decimal,ISNULL(SUM(LastYear.LastYearFeeAmt),0))/100.0 as LastYearFeeAmt,
	Convert(decimal,ISNULL(SUM(ThisYear.ThisYearFeeAmt),0))/100.0 as ThisYearFeeAmt,
	case when ISNULL(SUM(Prev.PrevFeeAmt), 0) = 0
		then 0
		else CONVERT(decimal, ISNULL(SUM(Curr.CurrFeeAmt), 0) - ISNULL(SUM(Prev.PrevFeeAmt), 0))/SUM(Prev.PrevFeeAmt)
	end SeqFeeAmtIncrementRatio,
	case when ISNULL(SUM(LastYear.LastYearFeeAmt), 0) = 0
		then 0
		else CONVERT(decimal, ISNULL(SUM(Curr.CurrFeeAmt), 0) - ISNULL(SUM(LastYear.LastYearFeeAmt), 0))/SUM(LastYear.LastYearFeeAmt)
	end YOYFeeAmtIncrementRatio,
	Convert(decimal,ISNULL(SUM(Curr.CurrFeeAmt), 0) - ISNULL(SUM(LastYear.LastYearFeeAmt), 0))/100 as YOYFeeAmtIncrement
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
	left join
	(select 
		*
	 from
		Table_EmployeeKPI
	 where
		convert(char(4),PeriodStartDate) = CONVERT(char(4), YEAR(case when @PeriodUnit = N'自定义' then @EndDate else DATEADD(day,-1,@CurrEndDate) end))
		and
		DeptName = N'销售部'
	)BUData
	on
		Sales.SalesManager = BUData.EmpName
group by
	BUData.BizUnit,
	Sales.SalesManager,
	Sales.MerchantClass,
	Sales.BranchOffice,
	Sales.MerchantName,
	Sales.MerchantNo;



--9. Clear temp table

drop table #CurrData;
drop table #PrevData;
drop table #LastYearData;
drop table #ThisYearData;

end 

