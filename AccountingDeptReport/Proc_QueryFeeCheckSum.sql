--[Modified] At 20120312 By 叶博:统一单位
if OBJECT_ID(N'Proc_QueryFeeCheckSum',N'P') is not null
begin
	drop procedure Proc_QueryFeeCheckSum;
end
go

create procedure Proc_QueryFeeCheckSum
	@StartDate datetime = '2012-03-01',
	@EndDate datetime = '2012-04-30',
	@Type nvarchar(2) = N'月'
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
--select
--	SUM(ISNULL(FeeResult.PurAmt,0))/100.0 as PurAmt,
--	SUM(ISNULL(FeeResult.PurCnt,0)) PurCnt,
--	SUM(ISNULL(FeeResult.FeeAmt,0))/100.0 as FeeAmt,
--	SUM(ISNULL(FeeResult.InstuFeeAmt,0))/100.0 as InstuFeeAmt,
--	FeeCheckSumWeek.CheckEndDate
--into
--	#FeeResultWeek
--from
--	Table_FeeCalcResult FeeResult
--	inner join
--	#FeeCheckSumWeek FeeCheckSumWeek
--	on
--		FeeResult.FeeEndDate >= DATEADD(WEEK,-1,FeeCheckSumWeek.CheckEndDate)
--		and
--		FeeResult.FeeEndDate < FeeCheckSumWeek.CheckEndDate
--group by
--	FeeCheckSumWeek.CheckEndDate;

create table #FeeResultWeek
(
	PurAmt decimal(14,2) not null,
	PurCnt int not null,
	FeeAmt decimal(12,2) not null,
	InstuFeeAmt decimal(12,2) not null,
	CheckEndDate datetime not null
)

declare @WeekMinDate datetime;
set @WeekMinDate = (
					select
						MIN(CheckEndDate) 
					from
						Table_FeeCheckSum
					where
						CheckEndDate >= @StartDate
						and
						CheckEndDate < @EndDate
						and
						PeriodUnit = 'Week'
				   );

while(DATEADD(WEEK,-1,@WeekMinDate) >= @StartDate)
begin
	set @WeekMinDate = DATEADD(WEEK,-1,@WeekMinDate);

	insert into 
		#FeeResultWeek
	select
		SUM(ISNULL(PurAmt,0))/100.0 as PurAmt,
		SUM(ISNULL(PurCnt,0)) PurCnt,
		SUM(ISNULL(FeeAmt,0))/100.0 as FeeAmt,
		SUM(ISNULL(InstuFeeAmt,0))/100.0 as InstuFeeAmt,
		@WeekMinDate as CheckEndDate
	from
		Table_FeeCalcResult 
	where
		FeeEndDate >= DATEADD(WEEK,-1,@WeekMinDate) 
		and
		FeeEndDate < @WeekMinDate;
end

set @WeekMinDate = (
					select
						MIN(CheckEndDate) 
					from
						Table_FeeCheckSum
					where
						CheckEndDate >= @StartDate
						and
						CheckEndDate < @EndDate
						and
						PeriodUnit = 'Week'
				   );

while(@WeekMinDate < @EndDate)
begin
	insert into 
		#FeeResultWeek
	select
		SUM(ISNULL(PurAmt,0))/100.0 as PurAmt,
		SUM(ISNULL(PurCnt,0)) PurCnt,
		SUM(ISNULL(FeeAmt,0))/100.0 as FeeAmt,
		SUM(ISNULL(InstuFeeAmt,0))/100.0 as InstuFeeAmt,
		@WeekMinDate as CheckEndDate
	from
		Table_FeeCalcResult 
	where
		FeeEndDate >= DATEADD(WEEK,-1,@WeekMinDate) 
		and
		FeeEndDate < @WeekMinDate;	
		
	set @WeekMinDate = DATEADD(WEEK,1,@WeekMinDate);		
end
	
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
	coalesce(FeeResultWeek.CheckEndDate,FeeCheckSumWeek.CheckEndDate),
	FeeCheckSumWeek.PeriodUnit,
	
	ISNULL(FeeCheckSumWeek.PurAmt,0) as CPurAmt,
	ISNULL(FeeCheckSumWeek.PurCnt,0) as CPurCnt,
	ISNULL(FeeCheckSumWeek.FeeAmt,0) as CFeeAmt,
	ISNULL(FeeCheckSumWeek.InstuFeeAmt,0) as CInstuFeeAmt,
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
	#FeeResultWeek FeeResultWeek
	full join
	#FeeCheckSumWeek FeeCheckSumWeek
	on
		FeeCheckSumWeek.CheckEndDate = FeeResultWeek.CheckEndDate
	full join
	#TransLogWeek TransLogWeek
	on
		FeeCheckSumWeek.CheckEndDate = TransLogWeek.CheckEndDate
	full join
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
--select
--	SUM(ISNULL(FeeResult.PurAmt,0))/100.0 as PurAmt,
--	SUM(ISNULL(FeeResult.PurCnt,0)) PurCnt,
--	SUM(ISNULL(FeeResult.FeeAmt,0))/100.0 as FeeAmt,
--	SUM(ISNULL(FeeResult.InstuFeeAmt,0))/100.0 as InstuFeeAmt,
--	FeeCheckSumMonth.CheckEndDate
--into
--	#FeeResultMonth
--from
--	Table_FeeCalcResult FeeResult
--	inner join
--	#FeeCheckSumMonth FeeCheckSumMonth
--	on
--		FeeResult.FeeEndDate >= DATEADD(MONTH,-1,FeeCheckSumMonth.CheckEndDate)
--		and
--		FeeResult.FeeEndDate < FeeCheckSumMonth.CheckEndDate
--group by
--	FeeCheckSumMonth.CheckEndDate;

create table #FeeResultMonth
(
	PurAmt decimal(14,2) not null,
	PurCnt int not null,
	FeeAmt decimal(12,2) not null,
	InstuFeeAmt decimal(12,2) not null,
	CheckEndDate datetime not null
)

declare @MonthMinDate datetime;
set @MonthMinDate = (
					select
						MIN(CheckEndDate) 
					from
						Table_FeeCheckSum
					where
						CheckEndDate >= @StartDate
						and
						CheckEndDate < @EndDate
						and
						PeriodUnit = 'Month'
				   );

while(DATEADD(MONTH,-1,@MonthMinDate) >= @StartDate)
begin
	set @MonthMinDate = DATEADD(MONTH,-1,@MonthMinDate);

	insert into 
		#FeeResultMonth
	select
		SUM(ISNULL(PurAmt,0))/100.0 as PurAmt,
		SUM(ISNULL(PurCnt,0)) PurCnt,
		SUM(ISNULL(FeeAmt,0))/100.0 as FeeAmt,
		SUM(ISNULL(InstuFeeAmt,0))/100.0 as InstuFeeAmt,
		@MonthMinDate as CheckEndDate
	from
		Table_FeeCalcResult 
	where
		FeeEndDate >= DATEADD(MONTH,-1,@MonthMinDate) 
		and
		FeeEndDate < @MonthMinDate;
end

set @MonthMinDate = (
					select
						MIN(CheckEndDate) 
					from
						Table_FeeCheckSum
					where
						CheckEndDate >= @StartDate
						and
						CheckEndDate < @EndDate
						and
						PeriodUnit = 'Month'
				   );

while(@MonthMinDate < @EndDate)
begin
	insert into 
		#FeeResultMonth
	select
		SUM(ISNULL(PurAmt,0))/100.0 as PurAmt,
		SUM(ISNULL(PurCnt,0)) PurCnt,
		SUM(ISNULL(FeeAmt,0))/100.0 as FeeAmt,
		SUM(ISNULL(InstuFeeAmt,0))/100.0 as InstuFeeAmt,
		@MonthMinDate as CheckEndDate
	from
		Table_FeeCalcResult 
	where
		FeeEndDate >= DATEADD(MONTH,-1,@MonthMinDate) 
		and
		FeeEndDate < @MonthMinDate;	
		
	set @MonthMinDate = DATEADD(MONTH,1,@MonthMinDate);		
end
	
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
	coalesce(FeeResultMonth.CheckEndDate,FeeResultMonth.CheckEndDate),
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
	#FeeResultMonth FeeResultMonth
	full join
	#FeeCheckSumMonth FeeCheckSumMonth
	on
		FeeCheckSumMonth.CheckEndDate = FeeResultMonth.CheckEndDate
	full join
	#TransLogMonth TransLogMonth 
	on
		FeeCheckSumMonth.CheckEndDate = TransLogMonth.CheckEndDate
	full join
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

