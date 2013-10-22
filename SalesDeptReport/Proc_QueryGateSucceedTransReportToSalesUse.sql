--[Modified] on 2013-10-14 By 丁俊昊 Description:Add TraScreenSum Data
--对应前台:公司业务成功交易及收入周期报表
if OBJECT_ID(N'Proc_QueryGateSucceedTransReportToSalesUse', N'P') is not null
begin
	drop procedure Proc_QueryGateSucceedTransReportToSalesUse;
end
go

create procedure Proc_QueryGateSucceedTransReportToSalesUse
	@StartDate datetime = '2011-09-01',
	@PeriodUnit nchar(4) = N'年',
	@EndDate datetime = '2011-10-01',
	@MeasureCategory nchar(10) = N'成功金额'
as
begin
--0. Check input params
if (isnull(@PeriodUnit, N'') = N'')
begin
	raiserror('@PeriodUnit cannot be empty.',16,1);	
end

if (@StartDate is null)
begin
	raiserror('@StartDate cannot be empty.', 16, 1);
end

if (@PeriodUnit = N'自定义' and @EndDate is null)
begin
	raiserror('@EndDate cannot be empty.', 16, 1);
end

if (ISNULL(@MeasureCategory, N'') = N'')
begin
	raiserror('@MeasureCategory cannot be empty.', 16, 1);
end


--0.1 Prepare StartDate and EndDate
declare @CurrStartDate datetime;
declare @CurrEndDate datetime;
declare @PrevStartDate datetime;
declare @PrevEndDate datetime;
declare @LastYearStartDate datetime;
declare @LastYearEndDate datetime;

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


--1. Get this period trade count/amount/FeeAmt and Add TraScreen Data
select
	GateNo,
	MerchantNo,
	sum(PurCnt) SumSucceedCount,
	sum(PurAmt) SumSucceedAmount,
	SUM(FeeAmt) CurrFeeAmt
into
	#CurrPayTrans
from
	Table_FeeCalcResult
where
	FeeEndDate >= @CurrStartDate
	and
	FeeEndDate < @CurrEndDate
group by
	GateNo,
	MerchantNo
union all
select
	ChannelNo as GateNo,
	MerchantNo,
	SUM(CalFeeCnt) as SumSucceedCount,
	SUM(CalFeeAmt) as SumSucceedAmount,
	SUM(FeeAmt) as CurrFeeAmt
from
	Table_TraScreenSum
where
	CPDate >= @CurrStartDate
	and
	CPDate < @CurrEndDate
	and
	TransType in ('100004','100001')
group by
	ChannelNo,
	MerchantNo;


--1.2 Add CurrORA_TraScreen Data
with AllORAData as
(
	select
		BankSettingID,
		MerchantNo,
		SUM(TransCount) as SumSucceedCount,
		SUM(TransAmount) as SumSucceedAmount,
		SUM(FeeAmount) as CurrFeeAmt
	from
		Table_OraTransSum
	where
		CPDate >= @CurrStartDate
		and
		CPDate < @CurrEndDate
	group by
		BankSettingID,
		MerchantNo
	union all
	select
		ChannelNo as BankSettingID,
		MerchantNo,
		SUM(CalFeeCnt) as SumSucceedCount,
		SUM(CalFeeAmt) as SumSucceedAmount,
		SUM(FeeAmt) as CurrFeeAmt
	from
		Table_TraScreenSum
	where
		CPDate >= @CurrStartDate
		and
		CPDate < @CurrEndDate
		and
		TransType in ('100002','100005')
	group by
		ChannelNo,
		MerchantNo
)
	select
		BankSettingID as GateNo,
		AllORAData.MerchantNo,
		SUM(SumSucceedCount) as SumSucceedCount,
		SUM(SumSucceedAmount) as SumSucceedAmount,
		SUM(ISNULL(AllORAData.SumSucceedCount * Additional.FeeValue,AllORAData.CurrFeeAmt)) as CurrFeeAmt
	into
		#CurrOraTrans
	from
		AllORAData
		left join
		Table_OraAdditionalFeeRule Additional
		on
			AllORAData.MerchantNo = Additional.MerchantNo
	group by
		BankSettingID,
		AllORAData.MerchantNo;


select
	GateNo,
	MerchantNo,
	SUM(PurCnt) PurCnt,
	SUM(PurAmt) PurAmt,
	SUM(FeeAmt) CurrFeeAmt
into
	#CurrUPOPData
from
	Table_UpopliqFeeLiqResult
where
	TransDate >= @CurrStartDate
	and
	TransDate < @CurrEndDate
group by
	GateNo,
	MerchantNo;


--2. Get previous period trade count/amount/FeeAmt and Add TraSceen Data
select
	GateNo,
	MerchantNo,
	sum(PurCnt) SumSucceedCount,
	sum(PurAmt) SumSucceedAmount,
	SUM(FeeAmt) PrevFeeAmt
into
	#PrevPayTrans
from
	Table_FeeCalcResult
where
	FeeEndDate >= @PrevStartDate
	and
	FeeEndDate < @PrevEndDate
group by
	GateNo,
	MerchantNo
union all
select
	ChannelNo as GateNo,
	MerchantNo,
	SUM(CalFeeCnt) as SumSucceedCount,
	SUM(CalFeeAmt) as SumSucceedAmount,
	SUM(FeeAmt) as PrevFeeAmt
from
	Table_TraScreenSum
where
	CPDate >= @PrevStartDate
	and
	CPDate < @PrevEndDate
	and
	TransType in ('100004','100001')
group by
	ChannelNo,
	MerchantNo;


--2.2 Add PrevORA_TraScreen Data
with AllORAData as
(
	select
		BankSettingID,
		MerchantNo,
		SUM(TransCount) as SumSucceedCount,
		SUM(TransAmount) as SumSucceedAmount,
		SUM(FeeAmount) as PrevFeeAmt
	from
		Table_OraTransSum
	where
		CPDate >= @PrevStartDate
		and
		CPDate < @PrevEndDate
	group by
		BankSettingID,
		MerchantNo
	union all
	select
		ChannelNo as BankSettingID,
		MerchantNo,
		SUM(CalFeeCnt) as SumSucceedCount,
		SUM(CalFeeAmt) as SumSucceedAmount,
		SUM(FeeAmt) as PrevFeeAmt
	from
		Table_TraScreenSum
	where
		CPDate >= @PrevStartDate
		and
		CPDate < @PrevEndDate
		and
		TransType in ('100002','100005')
	group by
		ChannelNo,
		MerchantNo
)
	select
		BankSettingID as GateNo,
		AllORAData.MerchantNo,
		SUM(SumSucceedCount) as SumSucceedCount,
		SUM(SumSucceedAmount) as SumSucceedAmount,
		SUM(ISNULL(AllORAData.SumSucceedCount * Additional.FeeValue,AllORAData.PrevFeeAmt)) as PrevFeeAmt
	into
		#PrevOraTrans
	from
		AllORAData
		left join
		Table_OraAdditionalFeeRule Additional
		on
			AllORAData.MerchantNo = Additional.MerchantNo
	group by
		BankSettingID,
		AllORAData.MerchantNo;


select
	GateNo,
	MerchantNo,
	SUM(PurCnt) PurCnt,
	SUM(PurAmt) PurAmt,
	SUM(FeeAmt) PrevFeeAmt
into
	#PrevUPOPData
from
	Table_UpopliqFeeLiqResult
where
	TransDate >= @PrevStartDate
	and
	TransDate < @PrevEndDate
group by
	GateNo,
	MerchantNo;


--3. Get last year same period trade count/amount and Add TraScreen Data
select
	GateNo,
	MerchantNo,
	sum(PurCnt) SumSucceedCount,
	sum(PurAmt) SumSucceedAmount,
	SUM(FeeAmt) LastYearFeeAmt
into
	#LastYearPayTrans
from
	Table_FeeCalcResult
where
	FeeEndDate >= @LastYearStartDate
	and
	FeeEndDate < @LastYearEndDate
group by
	GateNo,
	MerchantNo
union all
select
	ChannelNo as GateNo,
	MerchantNo,
	SUM(CalFeeCnt) as SumSucceedCount,
	SUM(CalFeeAmt) as SumSucceedAmount,
	SUM(FeeAmt) as LastYearFeeAmt
from
	Table_TraScreenSum
where
	CPDate >= @LastYearStartDate
	and
	CPDate < @LastYearEndDate
	and
	TransType in ('100004','100001')
group by
	ChannelNo,
	MerchantNo;


--3.2 Add LastYearOld_TraScreen
with AllORAData as
(
	select
		BankSettingID,
		MerchantNo,
		SUM(TransCount) as SumSucceedCount,
		SUM(TransAmount) as SumSucceedAmount,
		SUM(FeeAmount) as LastYearFeeAmt
	from
		Table_OraTransSum
	where
		CPDate >= @LastYearStartDate
		and
		CPDate < @LastYearEndDate
	group by
		BankSettingID,
		MerchantNo
	union all
	select
		ChannelNo as BankSettingID,
		MerchantNo,
		SUM(CalFeeCnt) as SumSucceedCount,
		SUM(CalFeeAmt) as SumSucceedAmount,
		SUM(FeeAmt) as LastYearFeeAmt
	from
		Table_TraScreenSum
	where
		CPDate >= @LastYearStartDate
		and
		CPDate < @LastYearEndDate
		and
		TransType in ('100002','100005')
	group by
		ChannelNo,
		MerchantNo
)
	select
		BankSettingID as GateNo,
		AllORAData.MerchantNo,
		SUM(SumSucceedCount) as SumSucceedCount,
		SUM(SumSucceedAmount) as SumSucceedAmount,
		SUM(ISNULL(AllORAData.SumSucceedCount * Additional.FeeValue,AllORAData.LastYearFeeAmt)) as LastYearFeeAmt
	into
		#LastYearOraTrans
	from
		AllORAData
		left join
		Table_OraAdditionalFeeRule Additional
		on
			AllORAData.MerchantNo = Additional.MerchantNo
	group by
		BankSettingID,
		AllORAData.MerchantNo;


select
	GateNo,
	MerchantNo,
	SUM(PurCnt) PurCnt,
	SUM(PurAmt) PurAmt,
	SUM(FeeAmt) LastYearFeeAmt
into
	#LastYearUPOPData
from
	Table_UpopliqFeeLiqResult
where
	TransDate >= @LastYearStartDate
	and
	TransDate < @LastYearEndDate
group by
	GateNo,
	MerchantNo;


--4. Get all together
--4.1 Get Sum Value
if @MeasureCategory = N'成功金额'
begin
	create table #SumValue
	(
		TypeName char(16) not null,
		GateNo char(10) not null,
		MerchantNo nchar(20) not null,
		CurrSumValue Decimal(25,4) not null,
		PrevSumValue Decimal(25,4) not null,
		LastYearSumValue Decimal(25,4) not null,
		CurrFeeAmt Decimal(25,4) not null,
		PrevFeeAmt Decimal(25,4) not null,
		LastYearFeeAmt Decimal(25,4) not null
	);


	insert into #SumValue
	(
		TypeName,
		GateNo,
		MerchantNo,
		CurrSumValue,
		PrevSumValue,
		LastYearSumValue,
		CurrFeeAmt,
		PrevFeeAmt,
		LastYearFeeAmt
	)
	select
		N'Pay' as TypeName,
		coalesce(CurrTrans.GateNo, PrevTrans.GateNo, LastYearTrans.GateNo) GateNo,
		coalesce(CurrTrans.MerchantNo, PrevTrans.MerchantNo, LastYearTrans.MerchantNo) MerchantNo,
		Convert(Decimal,ISNULL(CurrTrans.SumSucceedAmount, 0)) CurrSumValue,
		Convert(Decimal,ISNULL(PrevTrans.SumSucceedAmount, 0)) PrevSumValue,
		Convert(Decimal,ISNULL(LastYearTrans.SumSucceedAmount, 0)) LastYearSumValue,
		Convert(Decimal,ISNULL(CurrTrans.CurrFeeAmt, 0)) CurrFeeAmt,
		Convert(Decimal,ISNULL(PrevTrans.PrevFeeAmt, 0)) PrevFeeAmt,
		Convert(Decimal,ISNULL(LastYearTrans.LastYearFeeAmt, 0)) LastYearFeeAmt
	from
		#CurrPayTrans CurrTrans
		full outer join
		#PrevPayTrans PrevTrans
		on
			CurrTrans.GateNo = PrevTrans.GateNo
			and
			CurrTrans.MerchantNo = PrevTrans.MerchantNo
		full outer join
		#LastYearPayTrans LastYearTrans
		on
			coalesce(CurrTrans.GateNo, PrevTrans.GateNo) = LastYearTrans.GateNo
			and
			coalesce(CurrTrans.MerchantNo, PrevTrans.MerchantNo) = LastYearTrans.MerchantNo
	union all
	select
		N'Ora' as TypeName,
		coalesce(CurrTrans.GateNo, PrevTrans.GateNo, LastYearTrans.GateNo) GateNo,
		coalesce(CurrTrans.MerchantNo, PrevTrans.MerchantNo, LastYearTrans.MerchantNo) MerchantNo,
		Convert(Decimal,ISNULL(CurrTrans.SumSucceedAmount, 0)) CurrSumValue,
		Convert(Decimal,ISNULL(PrevTrans.SumSucceedAmount, 0)) PrevSumValue,
		Convert(Decimal,ISNULL(LastYearTrans.SumSucceedAmount, 0)) LastYearSumValue,
		Convert(Decimal,ISNULL(CurrTrans.CurrFeeAmt, 0)) CurrFeeAmt,
		Convert(Decimal,ISNULL(PrevTrans.PrevFeeAmt, 0)) PrevFeeAmt,
		Convert(Decimal,ISNULL(LastYearTrans.LastYearFeeAmt, 0)) LastYearFeeAmt
	from
		#CurrOraTrans CurrTrans
		full outer join
		#PrevOraTrans PrevTrans
		on
			CurrTrans.GateNo = PrevTrans.GateNo
			and
			CurrTrans.MerchantNo = PrevTrans.MerchantNo
		full outer join
		#LastYearOraTrans LastYearTrans
		on
			coalesce(CurrTrans.GateNo, PrevTrans.GateNo) = LastYearTrans.GateNo
			and
			coalesce(CurrTrans.MerchantNo, PrevTrans.MerchantNo) = LastYearTrans.MerchantNo
	union all	
	select
		N'UPOPDConnection' as TypeName,
		coalesce(CurrTrans.GateNo, PrevTrans.GateNo, LastYearTrans.GateNo) GateNo,
		coalesce(CurrTrans.MerchantNo, PrevTrans.MerchantNo, LastYearTrans.MerchantNo) MerchantNo,
		Convert(Decimal,ISNULL(CurrTrans.PurAmt, 0)) CurrSumValue,
		Convert(Decimal,ISNULL(PrevTrans.PurAmt, 0)) PrevSumValue,
		Convert(Decimal,ISNULL(LastYearTrans.PurAmt, 0)) LastYearSumValue,
		Convert(Decimal,ISNULL(CurrTrans.CurrFeeAmt, 0)) CurrFeeAmt,
		Convert(Decimal,ISNULL(PrevTrans.PrevFeeAmt, 0)) PrevFeeAmt,
		Convert(Decimal,ISNULL(LastYearTrans.LastYearFeeAmt, 0)) LastYearFeeAmt
	from
		#CurrUPOPData CurrTrans
		full outer join
		#PrevUPOPData PrevTrans
		on
			CurrTrans.GateNo = PrevTrans.GateNo
			and
			CurrTrans.MerchantNo = PrevTrans.MerchantNo
		full outer join
		#LastYearUPOPData LastYearTrans
		on
			coalesce(CurrTrans.GateNo, PrevTrans.GateNo) = LastYearTrans.GateNo
			and
			coalesce(CurrTrans.MerchantNo, PrevTrans.MerchantNo) = LastYearTrans.MerchantNo;


--4.2 Transform Curr RMB	
With CuryRate as  
(  
	select  
		CuryCode,  
		AVG(CuryRate) AVGCuryRate   
	from  
		Table_CuryFullRate  
	where  
		CuryDate >= @CurrStartDate 
		and  
		CuryDate <  @CurrEndDate  
	group by  
		CuryCode    
)
update   
	SumValue  
set  
	SumValue.CurrSumValue = ISNULL(CuryRate.AVGCuryRate, 1.0)*SumValue.CurrSumValue,
	SumValue.CurrFeeAmt = ISNULL(CuryRate.AVGCuryRate, 1.0)*SumValue.CurrFeeAmt
from  
	#SumValue SumValue  
	inner join  
	Table_MerInfoExt MerInfo  
	on  
		SumValue.MerchantNo = MerInfo.MerchantNo  
		inner join  
		CuryRate  
	on  
		MerInfo.CuryCode = CuryRate.CuryCode;  

--4.3 Transform Prev RMB
With CuryRate as  
(  
	select  
		CuryCode,  
		AVG(CuryRate) AVGCuryRate   
	from  
		Table_CuryFullRate  
	where  
		CuryDate >= @PrevStartDate 
		and  
		CuryDate <  @PrevEndDate
	group by  
		CuryCode    
)
update   
	SumValue  
set  
	SumValue.PrevSumValue = ISNULL(CuryRate.AVGCuryRate, 1.0)*SumValue.PrevSumValue,
	SumValue.PrevFeeAmt = ISNULL(CuryRate.AVGCuryRate, 1.0)*SumValue.PrevFeeAmt
from  
	#SumValue SumValue
	inner join
	Table_MerInfoExt MerInfo
	on
		SumValue.MerchantNo = MerInfo.MerchantNo  
		inner join  
		CuryRate  
	on  
		MerInfo.CuryCode = CuryRate.CuryCode;  

--4.4 Transform LastYear RMB
With CuryRate as  
(  
	select  
		CuryCode,  
		AVG(CuryRate) AVGCuryRate   
	from  
		Table_CuryFullRate  
	where  
		CuryDate >= @LastYearStartDate 
		and  
		CuryDate <  @LastYearEndDate
	group by  
		CuryCode    
)
update   
	SumValue  
set  
	SumValue.LastYearSumValue = ISNULL(CuryRate.AVGCuryRate, 1.0)*SumValue.LastYearSumValue,
	SumValue.LastYearFeeAmt = ISNULL(CuryRate.AVGCuryRate, 1.0)*SumValue.LastYearFeeAmt   
from  
	#SumValue SumValue  
	inner join  
	Table_MerInfoExt MerInfo  
	on  
		SumValue.MerchantNo = MerInfo.MerchantNo  
		inner join  
		CuryRate  
	on  
		MerInfo.CuryCode = CuryRate.CuryCode;  


--Result AmtData
	select
		ISNULL(Mer.MerchantName,TraMer.MerchantName) as MerchantName,
		SumValue.MerchantNo,
		ISNULL(case when Gate.GateCategory1 = '#N/A' then NULL when SumValue.GateNo in (select ChannelNo from Table_TraScreenSum where TransType in ('100004','100001')) then '代扣' else Gate.GateCategory1 End,N'其他') GateCategory,
		SumValue.GateNo,
		SumValue.CurrSumValue/1000000 CurrSumValue,
		SumValue.PrevSumValue/1000000 PrevSumValue,
		SumValue.LastYearSumValue/1000000 LastYearSumValue,
		SumValue.CurrFeeAmt/1000000 CurrFeeAmt,
		SumValue.PrevFeeAmt/1000000 PrevFeeAmt,
		SumValue.LastYearFeeAmt/1000000 LastYearFeeAmt
	from
		#SumValue SumValue
		left join
		Table_GateCategory Gate
		on
			SumValue.GateNo = Gate.GateNo
		left join
		Table_MerInfo Mer
		on
			SumValue.MerchantNo = Mer.MerchantNo
		left join
		Table_TraMerchantInfo TraMer
		on
			SumValue.MerchantNo = TraMer.MerchantNo
	where
		TypeName = N'Pay' 
	union all
	select
		ISNULL(Mer.MerchantName,TraMer.MerchantName) as MerchantName,
		SumValue.MerchantNo,
		N'代付' as GateCategory,
		ISNULL(Gate.BankName,Channel.ChannelName) as BankName,
		ISNULL(SUM(SumValue.CurrSumValue),0)/1000000 CurrSumValue,
		ISNULL(SUM(SumValue.PrevSumValue),0)/1000000 PrevSumValue,
		ISNULL(SUM(SumValue.LastYearSumValue),0)/1000000 LastYearSumValue,
		ISNULL(SUM(SumValue.CurrFeeAmt),0)/1000000 CurrFeeAmt,
		ISNULL(SUM(SumValue.PrevFeeAmt),0)/1000000 PrevFeeAmt,
		ISNULL(SUM(SumValue.LastYearFeeAmt),0)/1000000 LastYearFeeAmt
	from
		#SumValue SumValue
		left join
		Table_OraBankSetting Gate
		on
			SumValue.GateNo = Gate.BankSettingID
		left join
		Table_OraMerchants Mer
		on
			SumValue.MerchantNo = Mer.MerchantNo
		left join
		Table_TraChannelConfig Channel
		on
			SumValue.GateNo = Channel.ChannelNo
		left join
		Table_TraMerchantInfo TraMer
		on
			SumValue.MerchantNo = TraMer.MerchantNo
	where
		TypeName = N'Ora'
	group by
		ISNULL(Mer.MerchantName,TraMer.MerchantName),
		ISNULL(Gate.BankName,Channel.ChannelName),
		SumValue.MerchantNo
	union all
	select
		Upop.MerchantName,
		Upop.CPMerchantNo,
		N'UPOP直连' as GateCategory,
		SumValue.GateNo,
		ISNULL(SUM(SumValue.CurrSumValue),0)/1000000 CurrSumValue,
		ISNULL(SUM(SumValue.PrevSumValue),0)/1000000 PrevSumValue,
		ISNULL(SUM(SumValue.LastYearSumValue),0)/1000000 LastYearSumValue,
		ISNULL(SUM(SumValue.CurrFeeAmt),0)/1000000 CurrFeeAmt,
		ISNULL(SUM(SumValue.PrevFeeAmt),0)/1000000 PrevFeeAmt,
		ISNULL(SUM(SumValue.LastYearFeeAmt),0)/1000000 LastYearFeeAmt
	from
		#SumValue SumValue
		left join
		Table_UpopliqMerInfo Upop
		on
			SumValue.MerchantNo = Upop.MerchantNo
	where
		TypeName = N'UPOPDConnection'
	group by
		Upop.MerchantName,
		Upop.CPMerchantNo,
		SumValue.GateNo;

	drop table #SumValue;
end
else
begin
	create table #SumCount
	(
		TypeName char(16) not null,
		GateNo char(10) not null,
		MerchantNo nchar(20) not null,
		CurrSumValue Decimal(15,4) not null,
		PrevSumValue Decimal(15,4) not null,
		LastYearSumValue Decimal(15,4) not null
	);
	insert into #SumCount
	(
		TypeName,
		GateNo,
		MerchantNo,
		CurrSumValue,
		PrevSumValue,
		LastYearSumValue
	)
	select
		N'Pay' as TypeName,
		coalesce(CurrTrans.GateNo, PrevTrans.GateNo, LastYearTrans.GateNo) GateNo,
		coalesce(CurrTrans.MerchantNo, PrevTrans.MerchantNo, LastYearTrans.MerchantNo) MerchantNo,
		(Convert(Decimal,isnull(CurrTrans.SumSucceedCount, 0))/10000) CurrSumValue,
		(Convert(Decimal,isnull(PrevTrans.SumSucceedCount, 0))/10000) PrevSumValue,
		(Convert(Decimal,ISNULL(LastYearTrans.SumSucceedCount, 0))/10000) LastYearSumValue
	from
		#CurrPayTrans CurrTrans
		full outer join
		#PrevPayTrans PrevTrans
		on
			CurrTrans.GateNo = PrevTrans.GateNo
			and
			CurrTrans.MerchantNo = PrevTrans.MerchantNo
		full outer join
		#LastYearPayTrans LastYearTrans
		on
			coalesce(CurrTrans.GateNo, PrevTrans.GateNo) = LastYearTrans.GateNo
			and
			coalesce(CurrTrans.MerchantNo, PrevTrans.MerchantNo) = LastYearTrans.MerchantNo
	union all
	select
		N'Ora' as TypeName,
		coalesce(CurrTrans.GateNo, PrevTrans.GateNo, LastYearTrans.GateNo) GateNo,
		coalesce(CurrTrans.MerchantNo, PrevTrans.MerchantNo, LastYearTrans.MerchantNo) MerchantNo,
		(Convert(Decimal,ISNULL(CurrTrans.SumSucceedCount, 0))/10000) CurrSumValue,
		(Convert(Decimal,ISNULL(PrevTrans.SumSucceedCount, 0))/10000) PrevSumValue,
		(Convert(Decimal,ISNULL(LastYearTrans.SumSucceedCount, 0))/10000) LastYearSumValue
	from
		#CurrOraTrans CurrTrans
		full outer join
		#PrevOraTrans PrevTrans
		on
			CurrTrans.GateNo = PrevTrans.GateNo
			and
			CurrTrans.MerchantNo = PrevTrans.MerchantNo
		full outer join
		#LastYearOraTrans LastYearTrans
		on
			coalesce(CurrTrans.GateNo, PrevTrans.GateNo) = LastYearTrans.GateNo
			and
			coalesce(CurrTrans.MerchantNo, PrevTrans.MerchantNo) = LastYearTrans.MerchantNo
	union all	
	select
		N'UPOPDConnection' as TypeName,
		coalesce(CurrTrans.GateNo, PrevTrans.GateNo, LastYearTrans.GateNo) GateNo,
		coalesce(CurrTrans.MerchantNo, PrevTrans.MerchantNo, LastYearTrans.MerchantNo) MerchantNo,
		(Convert(Decimal,ISNULL(CurrTrans.PurCnt, 0))/1000000) CurrCntValue,
		(Convert(Decimal,ISNULL(PrevTrans.PurCnt, 0))/1000000) PrevCntValue,
		(Convert(Decimal,ISNULL(LastYearTrans.PurCnt, 0))/1000000) LastYearCntValue
	from
		#CurrUPOPData CurrTrans
		full outer join
		#PrevUPOPData PrevTrans
		on
			CurrTrans.GateNo = PrevTrans.GateNo
			and
			CurrTrans.MerchantNo = PrevTrans.MerchantNo
		full outer join
		#LastYearUPOPData LastYearTrans
		on
			coalesce(CurrTrans.GateNo, PrevTrans.GateNo) = LastYearTrans.GateNo
			and
			coalesce(CurrTrans.MerchantNo, PrevTrans.MerchantNo) = LastYearTrans.MerchantNo;

--Result CntData
	select
		ISNULL(Mer.MerchantName,TraMer.MerchantName) as MerchantName,
		SumCount.MerchantNo,
		ISNULL(case when Gate.GateCategory1 = '#N/A' then NULL else Gate.GateCategory1 End,N'其他') GateCategory,
		SumCount.GateNo,
		SumCount.CurrSumValue,
		SumCount.PrevSumValue,
		SumCount.LastYearSumValue
	from
		#SumCount SumCount
		left join
		Table_GateCategory Gate
		on
			SumCount.GateNo = Gate.GateNo
		left join
		Table_MerInfo Mer
		on
			SumCount.MerchantNo = Mer.MerchantNo
		left join
		Table_TraMerchantInfo TraMer
		on
			SumCount.MerchantNo = TraMer.MerchantNo
	where
		TypeName = N'Pay'
	union all
	select
		ISNULL(Mer.MerchantName,TraMer.MerchantName) as MerchantName,
		SumCount.MerchantNo,
		N'代付' as GateCategory,
		ISNULL(Gate.BankName,Channel.ChannelName) as BankName,
		ISNULL(SUM(SumCount.CurrSumValue),0) CurrSumValue,
		ISNULL(SUM(SumCount.PrevSumValue),0) PrevSumValue,
		ISNULL(SUM(SumCount.LastYearSumValue),0) LastYearSumValue
	from
		#SumCount SumCount
		left join
		Table_OraBankSetting Gate
		on
			SumCount.GateNo = Gate.BankSettingID
		left join
		Table_OraMerchants Mer
		on
			SumCount.MerchantNo = Mer.MerchantNo
		left join
		Table_TraChannelConfig Channel
		on
			SumCount.GateNo = Channel.ChannelNo
		left join
		Table_TraMerchantInfo TraMer
		on
			SumCount.MerchantNo = TraMer.MerchantNo
	where
		TypeName = N'Ora'
	group by
		ISNULL(Mer.MerchantName,TraMer.MerchantName),
		ISNULL(Gate.BankName,Channel.ChannelName),
		SumCount.MerchantNo
	union all
	select
		Upop.MerchantName,
		Upop.CPMerchantNo,
		N'UPOP直连' as GateCategory,
		SumCount.GateNo,
		ISNULL(SUM(SumCount.CurrSumValue),0) CurrSumValue,
		ISNULL(SUM(SumCount.PrevSumValue),0) PrevSumValue,
		ISNULL(SUM(SumCount.LastYearSumValue),0) LastYearSumValue
	from
		#SumCount SumCount
		left join
		Table_UpopliqMerInfo Upop
		on
			SumCount.MerchantNo = Upop.MerchantNo
	where
		TypeName = N'UPOPDConnection'
	group by
		Upop.MerchantName,
		Upop.CPMerchantNo,
		SumCount.GateNo;

	drop table #SumCount;
end

--4.1 Add Dimension information to final result

		
--5 Clear all temp tables
drop table #LastYearPayTrans;
drop table #PrevPayTrans;
drop table #CurrPayTrans;
drop table #LastYearOraTrans;
drop table #PrevOraTrans;
drop table #CurrOraTrans;

End