--[Modified] on 2013-10-14 By 丁俊昊 Description:Add TraScreenSum Data
--对应前台:公司业务成功交易及收入周期报表
--Modified by chen wu on 2013-12-11 restructure code

if OBJECT_ID(N'Proc_QueryGateSucceedTransReportToSalesUse', N'P') is not null
begin
	drop procedure Proc_QueryGateSucceedTransReportToSalesUse;
end
go

create procedure Proc_QueryGateSucceedTransReportToSalesUse
	@StartDate datetime = '2011-09-01',
	@PeriodUnit nchar(4) = N'年',
	@EndDate datetime = '2011-10-01'
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

--Current Period Data
select
	N'Table_FeeCalcResult' as Plat,
	(select GateCategory1 from Table_GateCategory where GateNo = fcr.GateNo) as Category,
	fcr.GateNo,
	fcr.MerchantNo,
	fcr.PurCnt TransCnt,
	fcr.PurAmt TransAmt,
	fcr.FeeAmt FeeAmt
into
	#CurrTrans
from
	Table_FeeCalcResult fcr
where
	fcr.FeeEndDate >= @CurrStartDate
	and
	fcr.FeeEndDate < @CurrEndDate
union all	
select
	N'Table_TraScreenSum' as Plat,
	case when
		TransType in ('100001','100004')
	then
		N'代扣'
	when
		TransType in ('100002','100005')
	then
		N'代付'
	else
		N'无法确定'
	end as Category,			
	ChannelNo as GateNo,
	MerchantNo,
	SucceedCnt as TransCnt,
	SucceedAmt as TransAmt,
	FeeAmt
from
	Table_TraScreenSum
where
	CPDate >= @CurrStartDate
	and
	CPDate < @CurrEndDate
union all
select
	N'Table_OraTransSum' as Plat,
	N'代付' as Category,
	BankSettingID as GateNo,
	MerchantNo,
	TransCount TransCnt,
	TransAmount TransAmt,
	FeeAmount FeeAmt
from
	Table_OraTransSum
where
	CPDate >= @CurrStartDate
	and
	CPDate < @CurrEndDate
union all
select
	N'Table_UpopliqFeeLiqResult' as Plat,
	N'UPOP直连' as Category,
	upopliq.GateNo,
	MerchantNo,
	PurCnt TransCnt,
	PurAmt TransAmt,
	FeeAmt
from
	Table_UpopliqFeeLiqResult upopliq
where
	upopliq.TransDate >= @CurrStartDate
	and
	upopliq.TransDate < @CurrEndDate;
	
select
	Plat,
	Category,
	GateNo,
	MerchantNo,
	SUM(TransCnt) as TransCnt,
	SUM(TransAmt) as TransAmt,
	SUM(FeeAmt) as FeeAmt
into
	#CurrSum
from
	#CurrTrans
group by
	Plat,
	Category,
	GateNo,
	MerchantNo;

--Previous Period Data
select
	N'Table_FeeCalcResult' as Plat,
	(select GateCategory1 from Table_GateCategory where GateNo = fcr.GateNo) as Category,
	fcr.GateNo,
	fcr.MerchantNo,
	fcr.PurCnt TransCnt,
	fcr.PurAmt TransAmt,
	fcr.FeeAmt FeeAmt
into
	#PrevTrans
from
	Table_FeeCalcResult fcr
where
	fcr.FeeEndDate >= @PrevStartDate
	and
	fcr.FeeEndDate < @PrevEndDate
union all	
select
	N'Table_TraScreenSum' as Plat,
	case when
		TransType in ('100001','100004')
	then
		N'代扣'
	when
		TransType in ('100002','100005')
	then
		N'代付'
	else
		N'无法确定'
	end as Category,			
	ChannelNo as GateNo,
	MerchantNo,
	SucceedCnt as TransCnt,
	SucceedAmt as TransAmt,
	FeeAmt
from
	Table_TraScreenSum
where
	CPDate >= @PrevStartDate
	and
	CPDate < @PrevEndDate
union all
select
	N'Table_OraTransSum' as Plat,
	N'代付' as Category,
	BankSettingID as GateNo,
	MerchantNo,
	TransCount TransCnt,
	TransAmount TransAmt,
	FeeAmount FeeAmt
from
	Table_OraTransSum
where
	CPDate >= @PrevStartDate
	and
	CPDate < @PrevEndDate
union all
select
	N'Table_UpopliqFeeLiqResult' as Plat,
	N'UPOP直连' as Category,
	upopliq.GateNo,
	MerchantNo,
	PurCnt TransCnt,
	PurAmt TransAmt,
	FeeAmt
from
	Table_UpopliqFeeLiqResult upopliq
where
	upopliq.TransDate >= @PrevStartDate
	and
	upopliq.TransDate < @PrevEndDate;
	
select
	Plat,
	Category,
	GateNo,
	MerchantNo,
	SUM(TransCnt) as TransCnt,
	SUM(TransAmt) as TransAmt,
	SUM(FeeAmt) as FeeAmt
into
	#PrevSum
from
	#PrevTrans
group by
	Plat,
	Category,
	GateNo,
	MerchantNo;

--Last year period data
select
	N'Table_FeeCalcResult' as Plat,
	(select GateCategory1 from Table_GateCategory where GateNo = fcr.GateNo) as Category,
	fcr.GateNo,
	fcr.MerchantNo,
	fcr.PurCnt TransCnt,
	fcr.PurAmt TransAmt,
	fcr.FeeAmt FeeAmt
into
	#LastYearTrans
from
	Table_FeeCalcResult fcr
where
	fcr.FeeEndDate >= @LastYearStartDate
	and
	fcr.FeeEndDate < @LastYearEndDate
union all	
select
	N'Table_TraScreenSum' as Plat,
	case when
		TransType in ('100001','100004')
	then
		N'代扣'
	when
		TransType in ('100002','100005')
	then
		N'代付'
	else
		N'无法确定'
	end as Category,			
	ChannelNo as GateNo,
	MerchantNo,
	SucceedCnt as TransCnt,
	SucceedAmt as TransAmt,
	FeeAmt
from
	Table_TraScreenSum
where
	CPDate >= @LastYearStartDate
	and
	CPDate < @LastYearEndDate
union all
select
	N'Table_OraTransSum' as Plat,
	N'代付' as Category,
	BankSettingID as GateNo,
	MerchantNo,
	TransCount TransCnt,
	TransAmount TransAmt,
	FeeAmount FeeAmt
from
	Table_OraTransSum
where
	CPDate >= @LastYearStartDate
	and
	CPDate < @LastYearEndDate
union all
select
	N'Table_UpopliqFeeLiqResult' as Plat,
	N'UPOP直连' as Category,
	upopliq.GateNo,
	MerchantNo,
	PurCnt TransCnt,
	PurAmt TransAmt,
	FeeAmt
from
	Table_UpopliqFeeLiqResult upopliq
where
	upopliq.TransDate >= @LastYearStartDate
	and
	upopliq.TransDate < @LastYearEndDate;
	
select
	Plat,
	Category,
	GateNo,
	MerchantNo,
	SUM(TransCnt) as TransCnt,
	SUM(TransAmt) as TransAmt,
	SUM(FeeAmt) as FeeAmt
into
	#LastYearSum
from
	#LastYearTrans
group by
	Plat,
	Category,
	GateNo,
	MerchantNo;

--Join Current, Previous and Last year data
select
	coalesce(curr.Plat, prev.Plat, lastyear.Plat) as Plat,
	coalesce(curr.Category, prev.Category, lastyear.Category) as Category,
	coalesce(curr.GateNo, prev.GateNo, lastyear.GateNo) as GateNo,
	coalesce(curr.MerchantNo, prev.MerchantNo, lastyear.MerchantNo) as MerchantNo,
	
	isnull(curr.TransCnt, 0) as CurrTransCnt,
	isnull(curr.TransAmt, 0) as CurrTransAmt,
	isnull(curr.FeeAmt, 0) as CurrFeeAmt,
	
	isnull(prev.TransCnt, 0) as PrevTransCnt,
	isnull(prev.TransAmt, 0) as PrevTransAmt,
	isnull(prev.FeeAmt, 0) as PrevFeeAmt,
	
	isnull(lastyear.TransCnt, 0) as LastYearTransCnt,
	isnull(lastyear.TransAmt, 0) as LastYearTransAmt,
	isnull(lastyear.FeeAmt, 0) as LastYearFeeAmt
into
	#AllSum
from
	#CurrSum curr
	full outer join
	#PrevSum prev
	on
		curr.Plat = prev.Plat
		and
		curr.GateNo = prev.GateNo
		and
		curr.MerchantNo = prev.MerchantNo
	full outer join
	#LastYearSum lastyear
	on
		coalesce(curr.Plat, prev.Plat) = lastyear.Plat
		and
		coalesce(curr.GateNo, prev.GateNo) = lastyear.GateNo
		and
		coalesce(curr.MerchantNo, prev.MerchantNo) = lastyear.MerchantNo;
		
--update Ora Additional Fee
update
	allsum
set
	allsum.CurrFeeAmt = allsum.CurrTransCnt * additional.FeeValue,
	allsum.PrevFeeAmt = allsum.PrevTransCnt * additional.FeeValue,
	allsum.LastYearFeeAmt = allsum.LastYearTransCnt * additional.FeeValue
from
	#AllSum allsum
	inner join
	Table_OraAdditionalFeeRule additional
	on
		allsum.MerchantNo = additional.MerchantNo
where
	allsum.Plat = N'Table_OraTransSum';
	
--convert foreign currency
With CurrCury as (
	select
		CuryCode,
		AVG(CuryRate) as CuryRate
	from
		Table_CuryFullRate
	where
		CuryDate >= @CurrStartDate
		and
		CuryDate < @CurrEndDate
	group by
		CuryCode
),
PrevCury as (
	select
		CuryCode,
		AVG(CuryRate) as CuryRate
	from
		Table_CuryFullRate
	where
		CuryDate >= @PrevStartDate
		and
		CuryDate < @PrevEndDate
	group by
		CuryCode
),
LastYearCury as (
	select
		CuryCode,
		AVG(CuryRate) as CuryRate
	from
		Table_CuryFullRate
	where
		CuryDate >= @LastYearStartDate
		and
		CuryDate < @LastYearEndDate
	group by
		CuryCode
)	
update
	allsum
set
	allsum.CurrTransAmt = allsum.CurrTransAmt * isnull((select CuryRate from CurrCury where CuryCode = ext.CuryCode), 1),
	allsum.PrevTransAmt = allsum.PrevTransAmt * isnull((select CuryRate from PrevCury where CuryCode = ext.CuryCode), 1),
	allsum.LastYearTransAmt = allsum.LastYearTransAmt * isnull((select CuryRate from LastYearCury where CuryCode = ext.CuryCode), 1),
	
	allsum.CurrFeeAmt = allsum.CurrFeeAmt * isnull((select CuryRate from CurrCury where CuryCode = ext.CuryCode), 1),
	allsum.PrevFeeAmt = allsum.PrevFeeAmt * isnull((select CuryRate from PrevCury where CuryCode = ext.CuryCode), 1),
	allsum.LastYearFeeAmt = allsum.LastYearFeeAmt * isnull((select CuryRate from LastYearCury where CuryCode = ext.CuryCode), 1)
from
	#AllSum allsum
	inner join
	Table_MerInfoExt ext
	on
		allsum.MerchantNo = ext.MerchantNo
where
	allsum.Plat = N'Table_FeeCalcResult';
	

select
	Plat,
	Category,
	GateNo,
	case when
		Plat = N'Table_UpopliqFeeLiqResult'
	then
		(select CPMerchantNo from Table_UpopliqMerInfo where MerchantNo = a.MerchantNo)
	else
		MerchantNo
	end MerchantNo,
	case when
		Plat = N'Table_FeeCalcResult'
	then
		(select MerchantName from Table_MerInfo where MerchantNo = a.MerchantNo)
	when
		Plat = N'Table_TraScreenSum'
	then
		(select MerchantName from Table_TraMerchantInfo where MerchantNo = a.MerchantNo)
	when
		Plat = N'Table_UpopliqFeeLiqResult'
	then
		(select MerchantName from Table_UpopliqMerInfo where MerchantNo = a.MerchantNo)
	when
		Plat = N'Table_OraTransSum'
	then
		(select MerchantName from Table_OraMerchants where MerchantNo = a.MerchantNo)
	else
		N''
	end as MerchantName,	
	CurrTransAmt/1000000.0 as CurrTransAmt,
	CurrFeeAmt/1000000.0 as CurrFeeAmt,
	
	PrevTransAmt/1000000.0 as PrevTransAmt,
	PrevFeeAmt/1000000.0 as PrevFeeAmt,
	
	LastYearTransAmt/1000000.0 as LastYearTransAmt,
	LastYearFeeAmt/1000000.0 as LastYearFeeAmt,
	
	CurrTransCnt/10000.0 as CurrTransCnt,
	PrevTransCnt/10000.0 as PrevTransCnt,
	LastYearTransCnt/10000.0 as LastYearTransCnt
from
	#AllSum a;

		
--Clear all temp tables
drop table #AllSum;

drop table #LastYearSum;
drop table #PrevSum;
drop table #CurrSum;

drop table #LastYearTrans;
drop table #PrevTrans;
drop table #CurrTrans;

End