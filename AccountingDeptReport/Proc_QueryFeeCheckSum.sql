--[Modified] At 20120312 By 叶博:统一单位
if OBJECT_ID(N'Proc_QueryFeeCheckSum',N'P') is not null
begin
	drop procedure Proc_QueryFeeCheckSum;
end
go

create procedure Proc_QueryFeeCheckSum
	@StartDate datetime = '2012-02-01',
	@EndDate datetime = '2012-03-01',
	@Type nvarchar(2) = N'周'
as 
begin

--1.Check Input
if(@StartDate is null or ISNULL(@Type,N'') = N'' or @EndDate is null)
begin
	raiserror(N'Input params can`t be empty in Proc_QueryFeeCheckSum',16,1);
end

--1.1 reset EndDate
set @EndDate = DATEADD(DAY, 1, @EndDate);

--2.Week CheckSum
if(@Type = N'周')
begin
--2.1 Get Week FeeSum Data From Table_FeeCheckSum
select
	PurAmt,
	PurCnt,
	FeeAmt,
	InstuFeeAmt,
	TransSumAmt/100.0 as TransSumAmt,
	TransSumCnt,
	CheckEndDate,
	PeriodUnit
into
	#FeeCheckSumWeek
from
	Table_FeeCheckSum
where
	CheckEndDate >= @StartDate
	and
	CheckEndDate < DATEADD(day,1,@EndDate)
	and
	PeriodUnit = 'Week';
	
--2.2 Get Week FeeSum Data From CP Table_FeeCalcResult 
select
	SUM(ISNULL(FeeResult.PurAmt,0))/100.0 as PurAmt,
	SUM(ISNULL(FeeResult.PurCnt,0)) PurCnt,
	SUM(ISNULL(FeeResult.FeeAmt,0))/100.0 as FeeAmt,
	SUM(ISNULL(FeeResult.InstuFeeAmt,0))/100.0 as InstuFeeAmt,
	FeeCheckSumWeek.CheckEndDate
into
	#FeeResultWeek
from
	Table_FeeCalcResult FeeResult
	inner join
	#FeeCheckSumWeek FeeCheckSumWeek
	on
		FeeResult.FeeEndDate >= DATEADD(WEEK,-1,FeeCheckSumWeek.CheckEndDate)
		and
		FeeResult.FeeEndDate < FeeCheckSumWeek.CheckEndDate
group by
	FeeCheckSumWeek.CheckEndDate;
	
--2.3 1005 1027 Week Check
select
	SUM(ISNULL(FeeResult.PurAmt,0))/100.0 as PurAmt,
	SUM(ISNULL(FeeResult.PurCnt,0)) PurCnt,
	FeeCheckSumWeek.CheckEndDate
into
	#FeeResultWeekDetailCheck
from
	Table_FeeCalcResult FeeResult
	inner join
	#FeeCheckSumWeek FeeCheckSumWeek
	on
		FeeResult.FeeEndDate >= DATEADD(WEEK,-1,FeeCheckSumWeek.CheckEndDate)
		and
		FeeResult.FeeEndDate < FeeCheckSumWeek.CheckEndDate
where
	FeeResult.GateNo in ('1005', '1027')
group by
	FeeCheckSumWeek.CheckEndDate;

--2.4 Get Week TransSum Data From CP Table_FeeTransLog
select
	FeeTransLog.TransAmt,
	BatchNoLog.CheckEndDate
into
	#LogWeek
from
	(
		select distinct
			FeeResult.FeeBatchNo,
			FeeCheckSumWeek.CheckEndDate
		from
			Table_FeeCalcResult FeeResult
			inner join
			#FeeCheckSumWeek FeeCheckSumWeek
			on 
				FeeResult.FeeEndDate >= DATEADD(week,-1,FeeCheckSumWeek.CheckEndDate)
				and
				FeeResult.FeeEndDate < FeeCheckSumWeek.CheckEndDate
	) BatchNoLog    --Get BatchNo By CheckEndDate    
	inner join
	Table_FeeTransLog FeeTransLog                        
	on
		BatchNoLog.FeeBatchNo = FeeTransLog.FeeBatchNo;
	
select
	SUM(TransAmt)/100.0 TransSumAmt,
	COUNT(1) TransSumCnt,
	CheckEndDate
into
	#TransLogWeek
from
	#LogWeek
group by
	CheckEndDate;

--2.5 Get Comparison Result
select
	FeeCheckSumWeek.CheckEndDate,
	FeeCheckSumWeek.PeriodUnit,
	
	FeeCheckSumWeek.PurAmt CPurAmt,
	FeeCheckSumWeek.PurCnt CPurCnt,
	FeeCheckSumWeek.FeeAmt CFeeAmt,
	FeeCheckSumWeek.InstuFeeAmt CInstuFeeAmt,
	FeeCheckSumWeek.TransSumAmt CTransSumAmt,
	FeeCheckSumWeek.TransSumCnt CTransSumCnt,
	
	FeeResultWeek.PurAmt,
	FeeResultWeek.PurCnt,
	FeeResultWeek.FeeAmt,
	FeeResultWeek.InstuFeeAmt,
	TransLogWeek.TransSumAmt,
	TransLogWeek.TransSumCnt,
	
	isnull(DetailCheck.PurAmt,0) DetailSumPurAmt,
	isnull(DetailCheck.PurCnt,0) DetailSumPurCnt,
		
	case when
		FeeCheckSumWeek.PurAmt = FeeResultWeek.PurAmt
		and
		FeeCheckSumWeek.PurCnt = FeeResultWeek.PurCnt
		and
		FeeCheckSumWeek.FeeAmt = FeeResultWeek.FeeAmt
		and
		FeeCheckSumWeek.InstuFeeAmt = FeeResultWeek.InstuFeeAmt
	then
		'Match'
	else
		'NotMatch'
	end as FeeCalcResultCompare,
	
	case when
		FeeCheckSumWeek.TransSumAmt = TransLogWeek.TransSumAmt
		and
		FeeCheckSumWeek.TransSumCnt = TransLogWeek.TransSumCnt
	then
		'Match'
	else
		'NotMatch'
	end as FeeTransLogCompare,
	
	case when
		isnull(DetailCheck.PurAmt, 0) = TransLogWeek.TransSumAmt
		and
		isnull(DetailCheck.PurCnt, 0) = TransLogWeek.TransSumCnt
	then
		'Match'
	else
		'NotMatch'
	end as ResultAndLogCompare		
from
	#FeeCheckSumWeek FeeCheckSumWeek
	inner join
	#FeeResultWeek FeeResultWeek
	on
		FeeCheckSumWeek.CheckEndDate = FeeResultWeek.CheckEndDate
	inner join
	#TransLogWeek TransLogWeek
	on
		FeeCheckSumWeek.CheckEndDate = TransLogWeek.CheckEndDate
	left join
	#FeeResultWeekDetailCheck DetailCheck
	on
		FeeCheckSumWeek.CheckEndDate = DetailCheck.CheckEndDate;
	
--2.6 Drop Temporary Table
drop table #FeeCheckSumWeek;
drop table #FeeResultWeek;
drop table #FeeResultWeekDetailCheck;
drop table #LogWeek;
drop table #TransLogWeek;

end


--3.Month CheckSum
if(@Type = N'月')
begin
--3.1 Get Month FeeSum Data From Table_FeeCheckSum
select
	PurAmt,
	PurCnt,
	FeeAmt,
	InstuFeeAmt,
	TransSumAmt/100.0 as TransSumAmt,
	TransSumCnt,
	CheckEndDate,
	PeriodUnit
into
	#FeeCheckSumMonth
from
	Table_FeeCheckSum
where
	CheckEndDate >= @StartDate
	and
	CheckEndDate < DATEADD(day,1,@EndDate)
	and
	PeriodUnit = 'Month';
	
--3.2 Get Month FeeSum Data From CP Table_FeeCalcResult 
select
	SUM(ISNULL(FeeResult.PurAmt,0))/100.0 as PurAmt,
	SUM(ISNULL(FeeResult.PurCnt,0)) PurCnt,
	SUM(ISNULL(FeeResult.FeeAmt,0))/100.0 as FeeAmt,
	SUM(ISNULL(FeeResult.InstuFeeAmt,0))/100.0 as InstuFeeAmt,
	FeeCheckSumMonth.CheckEndDate
into
	#FeeResultMonth
from
	Table_FeeCalcResult FeeResult
	inner join
	#FeeCheckSumMonth FeeCheckSumMonth
	on
		FeeResult.FeeEndDate >= DATEADD(MONTH,-1,FeeCheckSumMonth.CheckEndDate)
		and
		FeeResult.FeeEndDate < FeeCheckSumMonth.CheckEndDate
group by
	FeeCheckSumMonth.CheckEndDate;
	
--3.3 1005 1027 Month Check
select
	SUM(ISNULL(FeeResult.PurAmt,0))/100.0 as PurAmt,
	SUM(ISNULL(FeeResult.PurCnt,0)) PurCnt,
	FeeCheckSumMonth.CheckEndDate
into
	#FeeResultMonthDetailCheck
from
	Table_FeeCalcResult FeeResult
	inner join
	#FeeCheckSumMonth FeeCheckSumMonth
	on
		FeeResult.FeeEndDate >= DATEADD(MONTH,-1,FeeCheckSumMonth.CheckEndDate)
		and
		FeeResult.FeeEndDate < FeeCheckSumMonth.CheckEndDate
where
	FeeResult.GateNo in ('1005', '1027')
group by
	FeeCheckSumMonth.CheckEndDate;

--3.4 Get Month TransSum Data From CP Table_FeeTransLog
select
	FeeTransLog.TransAmt,
	BatchNoLog.CheckEndDate
into
	#LogMonth
from
	(
		select distinct
			FeeResult.FeeBatchNo,
			FeeCheckSumMonth.CheckEndDate
		from
			Table_FeeCalcResult FeeResult
			inner join
			#FeeCheckSumMonth FeeCheckSumMonth
		on 
			FeeResult.FeeEndDate >= DATEADD(MONTH,-1,FeeCheckSumMonth.CheckEndDate)
			and
			FeeResult.FeeEndDate < FeeCheckSumMonth.CheckEndDate
	) BatchNoLog    --Get BatchNo By CheckEndDate  
	inner join
	Table_FeeTransLog FeeTransLog                         
	on
		BatchNoLog.FeeBatchNo = FeeTransLog.FeeBatchNo;
		
select
	SUM(TransAmt)/100.0 as TransSumAmt,
	COUNT(1) TransSumCnt,
	CheckEndDate
into	
	#TransLogMonth
from
	#LogMonth
group by
	CheckEndDate;

--3.5 Get Comparison Result
select
	FeeCheckSumMonth.CheckEndDate,
	FeeCheckSumMonth.PeriodUnit,

	FeeCheckSumMonth.PurAmt CPurAmt,
	FeeCheckSumMonth.PurCnt CPurCnt,
	FeeCheckSumMonth.FeeAmt CFeeAmt,
	FeeCheckSumMonth.InstuFeeAmt CInstuFeeAmt,
	FeeCheckSumMonth.TransSumAmt CTransSumAmt,
	FeeCheckSumMonth.TransSumCnt CTransSumCnt,
	
	FeeResultMonth.PurAmt,
	FeeResultMonth.PurCnt,
	FeeResultMonth.FeeAmt,
	FeeResultMonth.InstuFeeAmt,
	TransLogMonth.TransSumAmt,
	TransLogMonth.TransSumCnt,
	
	isnull(DetailCheck.PurAmt,0) DetailSumPurAmt,
	isnull(DetailCheck.PurCnt,0) DetailSumPurCnt,
	
	case when
		FeeCheckSumMonth.PurAmt = FeeResultMonth.PurAmt
		and
		FeeCheckSumMonth.PurCnt = FeeResultMonth.PurCnt
		and
		FeeCheckSumMonth.FeeAmt = FeeResultMonth.FeeAmt
		and
		FeeCheckSumMonth.InstuFeeAmt = FeeResultMonth.InstuFeeAmt
	then
		'Match'
	else
		'NotMatch'
	end as FeeCalcResultCompare,
	
	case when
		FeeCheckSumMonth.TransSumAmt = TransLogMonth.TransSumAmt
		and
		FeeCheckSumMonth.TransSumCnt = TransLogMonth.TransSumCnt
	then
			'Match'
	else
			'NotMatch' 
	end as FeeTransLogCompare,
	
	case when
		isnull(DetailCheck.PurAmt, 0) = TransLogMonth.TransSumAmt
		and
		isnull(DetailCheck.PurCnt, 0) = TransLogMonth.TransSumCnt
	then
		'Match'
	else
		'NotMatch'
	end as ResultAndLogCompare		
from
	#FeeCheckSumMonth FeeCheckSumMonth
	inner join
	#FeeResultMonth FeeResultMonth
	on
		FeeCheckSumMonth.CheckEndDate = FeeResultMonth.CheckEndDate
	inner join
	#TransLogMonth TransLogMonth 
	on
		FeeCheckSumMonth.CheckEndDate = TransLogMonth.CheckEndDate
	left join
	#FeeResultMonthDetailCheck DetailCheck
	on
		FeeCheckSumMonth.CheckEndDate = DetailCheck.CheckEndDate;
	
--3.6 Drop Temporary Table
drop table #FeeCheckSumMonth;
drop table #FeeResultMonth;
drop table #FeeResultMonthDetailCheck;
drop table #LogMonth;
drop table #TransLogMonth;

end


end

