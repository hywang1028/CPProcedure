--[Create] At 20130805 By 丁俊昊：虚拟账户交易统计报表
--Input:@StartDate,@PeriodUnit,@EndDate
--Output:MerchantNo,MerchantName,GateNo,CurrTransCnt,CurrTransAmt,TransCntTongBi,TransCntHuanBi,TransAmtTongBi,TransAmtHuanBi,PrevTransCnt,PrevTransAmt,LastYearTransCnt,LastYearTransAmt
if OBJECT_ID(N'Proc_QueryVirtualAccountTransReport') is not null
begin
	drop procedure Proc_QueryVirtualAccountTransReport;
end
go

create procedure Proc_QueryVirtualAccountTransReport
@StartDate DateTime = '2012-01-01',
@PeriodUnit nchar(4) = N'自定义',
@EndDate DateTime = '2012-05-01'
as
begin

--1. Check input
if (@StartDate is null or ISNULL(@PeriodUnit, N'') = N''  or (@PeriodUnit = N'自定义' and @EndDate is null))
begin
	raiserror(N'Input params cannot be empty in Proc_QueryVirtualAccountTransReport', 16, 1);
end


--2. Prepare StartDate and EndDate
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
end;


--3. Prepare #CurrFactData
select
	MerchantNo,
	GateNo as BankSettingID,
	SUM(SucceedTransCount) as CurrTransCnt,
	SUM(SucceedTransAmount) as CurrTransAmt
into
	#CurrFactData
from
	FactDailyTrans
where
	DailyTransDate >= @CurrStartDate
	and
	DailyTransDate < @CurrEndDate
group by
	MerchantNo,
	GateNo;


--3.1 Prepare #CurrOraData
select
	MerchantNo,
	BankSettingID,
	SUM(TransCount) CurrTransCnt,
	SUM(TransAmount) CurrTransAmt
into
	#CurrOraData
from
	Table_OraTransSum
where 
	CPDate >= @CurrStartDate
	and
	CPDate <  @CurrEndDate
group by
	MerchantNo,
	BankSettingID
union all
select
	MerchantNo,
	ChannelNo,
	SUM(CalFeeCnt) CurrTransCnt,
	SUM(CalFeeAmt) CurrTransAmt		
from
	Table_TraScreenSum
where
	CPDate >= @CurrStartDate
	and
	CPDate <  @CurrEndDate
	and
	TransType in ('100002','100005')
group by 
	MerchantNo,
	ChannelNo;


--3.2 Transform RMB
with CuryRate as  
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
UPDATE
	#CurrFactData
SET
	#CurrFactData.CurrTransAmt = ISNULL(CuryRate.AVGCuryRate,1.0) * #CurrFactData.CurrTransAmt
FROM
	#CurrFactData
	inner join
	Table_MerInfoExt
	on
		#CurrFactData.MerchantNo = Table_MerInfoExt.MerchantNo
	inner join
	CuryRate
	on
		Table_MerInfoExt.CuryCode = CuryRate.CuryCode;


--3.3 Prepare #CurrFinalyData
select * into #CurrFinalyData from #CurrFactData
union all
select * from #CurrOraData;


--4. Prepare #PrevFactData
select
	MerchantNo,
	GateNo as BankSettingID,
	SUM(SucceedTransCount) as PrevTransCnt,
	SUM(SucceedTransAmount) as PrevTransAmt
into
	#PrevFactData
from
	FactDailyTrans
where
	DailyTransDate >= @PrevStartDate
	and
	DailyTransDate < @PrevEndDate
group by
	MerchantNo,
	GateNo;


--4.1 Prepare #PrevOraData
select
	MerchantNo,
	BankSettingID,
	SUM(TransCount) PrevTransCnt,
	SUM(TransAmount) PrevTransAmt
into
	#PrevOraData
from
	Table_OraTransSum
where 
	CPDate >= @PrevStartDate
	and
	CPDate <  @PrevEndDate
group by
	MerchantNo,
	BankSettingID
union all
select
	MerchantNo,
	ChannelNo,
	SUM(CalFeeCnt) PrevTransCnt,
	SUM(CalFeeAmt) PrevTransAmt		
from
	Table_TraScreenSum
where
	CPDate >= @PrevStartDate
	and
	CPDate <  @PrevEndDate
	and
	TransType in ('100002','100005')
group by 
	MerchantNo,
	ChannelNo;


--4.2 Transform RMB
with CuryRate as  
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
UPDATE
	#PrevFactData
SET
	#PrevFactData.PrevTransAmt = ISNULL(CuryRate.AVGCuryRate,1.0) * #PrevFactData.PrevTransAmt
FROM
	#PrevFactData
	inner join
	Table_MerInfoExt
	on
		#PrevFactData.MerchantNo = Table_MerInfoExt.MerchantNo
	inner join
	CuryRate
	on
		Table_MerInfoExt.CuryCode = CuryRate.CuryCode;


--4.3 Prepare #PrevFinalyData
select * into #PrevFinalyData from #PrevFactData
union all
select * from #PrevOraData;


--5. Prepare #LastYearFactData
select
	MerchantNo,
	GateNo as BankSettingID,
	SUM(SucceedTransCount) as LastYearTransCnt,
	SUM(SucceedTransAmount) as LastYearTransAmt
into
	#LastYearFactData
from
	FactDailyTrans
where
	DailyTransDate >= @LastYearStartDate
	and
	DailyTransDate < @LastYearEndDate
group by
	MerchantNo,
	GateNo;


--5.1 Prepare #LastYearOraData
select
	MerchantNo,
	BankSettingID,
	SUM(TransCount) LastYearTransCnt,
	SUM(TransAmount) LastYearTransAmt
into
	#LastYearOraData
from
	Table_OraTransSum
where 
	CPDate >= @LastYearStartDate
	and
	CPDate <  @LastYearEndDate
group by
	MerchantNo,
	BankSettingID
union all
select
	MerchantNo,
	ChannelNo,
	SUM(CalFeeCnt) LastYearTransCnt,
	SUM(CalFeeAmt) LastYearTransAmt		
from
	Table_TraScreenSum
where
	CPDate >= @LastYearStartDate
	and
	CPDate <  @LastYearEndDate
	and
	TransType in ('100002','100005')
group by 
	MerchantNo,
	ChannelNo;


--5.2 Transform RMB
with CuryRate as  
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
UPDATE
	#LastYearFactData
SET
	#LastYearFactData.LastYearTransAmt = ISNULL(CuryRate.AVGCuryRate,1.0) * #LastYearFactData.LastYearTransAmt
FROM
	#LastYearFactData
	inner join
	Table_MerInfoExt
	on
		#LastYearFactData.MerchantNo = Table_MerInfoExt.MerchantNo
	inner join
	CuryRate
	on
		Table_MerInfoExt.CuryCode = CuryRate.CuryCode;


--5.3 Prepare #LastYearFinalyData
select * into #LastYearFinalyData from #LastYearFactData
union all
select * from #LastYearOraData;


--6. Get Finaly Data
with AllData as
(
	select 
		Coalesce(#CurrFinalyData.MerchantNo,#PrevFinalyData.MerchantNo,#LastYearFinalyData.MerchantNo) MerchantNo,
		Coalesce(#CurrFinalyData.BankSettingID,#PrevFinalyData.BankSettingID,#LastYearFinalyData.BankSettingID) BankSettingID,
		#CurrFinalyData.CurrTransCnt,
		#CurrFinalyData.CurrTransAmt,
		#PrevFinalyData.PrevTransAmt,
		#PrevFinalyData.PrevTransCnt,
		#LastYearFinalyData.LastYearTransCnt,
		#LastYearFinalyData.LastYearTransAmt
	from
		#CurrFinalyData 
		full join 
		#PrevFinalyData 
		on 
			#CurrFinalyData.MerchantNo = #PrevFinalyData.MerchantNo 
			and 
			#CurrFinalyData.BankSettingID = #PrevFinalyData.BankSettingID
		full join
		#LastYearFinalyData
		on
			coalesce(#CurrFinalyData.MerchantNo,#PrevFinalyData.MerchantNo) = #LastYearFinalyData.MerchantNo 
			and 
			coalesce(#CurrFinalyData.BankSettingID,#PrevFinalyData.BankSettingID) = #LastYearFinalyData.BankSettingID
)
	select
		ISNULL(AllData.MerchantNo,'') MerchantNo,
		coalesce(Table_MerInfo.MerchantName,Table_OraMerchants.MerchantName,Table_TraMerchantInfo.MerchantName) MerchantName,
		ISNULL(AllData.BankSettingID,'') BankSettingID,
		ISNULL(AllData.CurrTransCnt,0) CurrTransCnt,
		ISNULL(AllData.CurrTransAmt,0)/100.0 CurrTransAmt,
		case when ISNULL(AllData.LastYearTransCnt,0) = 0
		then 0
		else CONVERT(decimal, ISNULL(AllData.CurrTransCnt,0) - ISNULL(AllData.LastYearTransCnt,0))/AllData.LastYearTransCnt
		end TransCntTongBi,
		case when ISNULL(AllData.PrevTransCnt,0) = 0
		then 0
		else CONVERT(decimal, ISNULL(AllData.CurrTransCnt,0) - ISNULL(AllData.PrevTransCnt,0))/AllData.PrevTransCnt
		end TransCntHuanBi,
		case when ISNULL(AllData.LastYearTransAmt,0) = 0
		then 0
		else CONVERT(decimal, ISNULL(AllData.CurrTransAmt,0) - ISNULL(AllData.LastYearTransAmt,0))/AllData.LastYearTransAmt
		end TransAmtTongBi,
		case when ISNULL(AllData.PrevTransAmt,0) = 0
		then 0
		else CONVERT(decimal, ISNULL(AllData.CurrTransAmt,0) - ISNULL(AllData.PrevTransAmt,0))/AllData.PrevTransAmt
		end TransAmtHuanBi,
		ISNULL(AllData.PrevTransCnt,0) PrevTransCnt,
		ISNULL(AllData.PrevTransAmt,0)/100.0 PrevTransAmt,
		ISNULL(AllData.LastYearTransCnt,0) LastYearTransCnt,
		ISNULL(AllData.LastYearTransAmt,0)/100.0 LastYearTransAmt
	from 
		AllData
		left join
		Table_MerInfo
		on
			AllData.MerchantNo = Table_MerInfo.MerchantNo
		left join
		Table_OraMerchants
		on
			AllData.MerchantNo = Table_OraMerchants.MerchantNo
		left join
		Table_TraMerchantInfo
		on
			AllData.MerchantNo = Table_TraMerchantInfo.MerchantNo
	where
		AllData.MerchantNo in (select RuleObject from Table_VirtualAccountConfig)
		or
		AllData.BankSettingID in (select RuleObject from Table_VirtualAccountConfig);


end


drop table #CurrFactData;
drop table #CurrOraData;
drop table #CurrFinalyData;
drop table #PrevFactData;
drop table #PrevOraData;
drop table #PrevFinalyData;
drop table #LastYearFactData;
drop table #LastYearOraData;
drop table #LastYearFinalyData;



---------------测试
--insert Table_VirtualAccountConfig
--values
--	 ('Mer','808080450202922')


--delete from Table_VirtualAccountConfig
--where
--	Table_VirtualAccountConfig.RuleObject = '808080450202922'