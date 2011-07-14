if OBJECT_ID(N'Proc_QueryBizCategoryReport', N'P') is not null
begin
	drop procedure Proc_QueryBizCategoryReport;
end
go

create procedure Proc_QueryBizCategoryReport
	@StartDate datetime = '2011-01-01',
	@PeriodUnit nchar(2) = N'周',
	@BizCategory nchar(10) = N'基金（支付）'
as
begin

--1. Check input
if (@StartDate is null or ISNULL(@PeriodUnit, N'') = N'' or ISNULL(@BizCategory, N'') = N'')
begin
	raiserror(N'Input params cannot be empty in Proc_QueryBizCategoryReport', 16, 1);
end

--2. Prepare Task
--2.1 Prepare date period
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

set @ThisYearRunningStartDate = convert(char(4), YEAR(@CurrStartDate)) + '-01-01';
set @ThisYearRunningEndDate = @CurrEndDate;

--2.2 Prepare where conditions
declare @whereCondition nvarchar(max);
set @whereCondition = N'';

if @BizCategory = N'互联宝'
begin
	set @whereCondition = N'
	GateNo in (''0018'', ''0019'', ''8018'')
	and
	MerchantNo not in (select MerchantNo from Table_EposTakeoffMerchant)
	'
end
else if @BizCategory = N'基金（支付）'
begin
	set @whereCondition = N'
	GateNo in (''0044'', ''0045'')
	'
end
else if @BizCategory = N'代扣'
begin
	set @whereCondition = N'
	GateNo in (''7008'')
	'
end
else if @BizCategory = N'商城'
begin
	set @whereCondition = N'
	MerchantNo in (''808080290000007'')
	'
end
else if @BizCategory = N'商旅'
begin
	set @whereCondition = N'
	MerchantNo in (''808080510003188'')
	'
end
else if @BizCategory = N'公共事业缴费'
begin
	set @whereCondition = N'
	MerchantNo in (select MerchantNo from dbo.Table_InstuMerInfo where InstuNo = ''000020100816001'')
	'
end

declare @sqlScript nvarchar(max);
--3. Get Current period data
create table #CurrTransSum
(
	MerchantNo char(20) not null,
	SucceedCount int not null,
	SucceedAmount bigint not null
);

set @sqlScript = N'
select
	MerchantNo,
	sum(SucceedTransCount) as SucceedCount,
	sum(SucceedTransAmount) as SucceedAmount
from
	FactDailyTrans
where
	DailyTransDate >= ''' + convert(char(10), @CurrStartDate, 120) + ''' 
	and
	DailyTransDate < ''' + convert(char(10), @CurrEndDate, 120) + ''''
+ case when
		isnull(@whereCondition, N'') <> N''
	then
		N' and ' + @whereCondition
	else
		''
	end
+ N' group by MerchantNo'

insert into #CurrTransSum
(
	MerchantNo,
	SucceedCount,
	SucceedAmount
)
exec(@sqlScript);

--4. Get Previous period data
create table #PrevTransSum
(
	MerchantNo char(20) not null,
	SucceedCount int not null,
	SucceedAmount bigint not null
);

set @sqlScript = N'
select
	MerchantNo,
	sum(SucceedTransCount) as SucceedCount,
	sum(SucceedTransAmount) as SucceedAmount
from
	FactDailyTrans
where
	DailyTransDate >= ''' + convert(char(10), @PrevStartDate, 120) + ''' 
	and
	DailyTransDate < ''' + convert(char(10), @PrevEndDate, 120) + ''''
+ case when
		isnull(@whereCondition, N'') <> N''
	then
		N' and ' + @whereCondition
	else
		''
	end
+ N' group by MerchantNo'

insert into #PrevTransSum
(
	MerchantNo,
	SucceedCount,
	SucceedAmount
)
exec(@sqlScript);

--5. Get LastYear period data
create table #LastYearTransSum
(
	MerchantNo char(20) not null,
	SucceedCount int not null,
	SucceedAmount bigint not null
);

set @sqlScript = N'
select
	MerchantNo,
	sum(SucceedTransCount) as SucceedCount,
	sum(SucceedTransAmount) as SucceedAmount
from
	FactDailyTrans
where
	DailyTransDate >= ''' + convert(char(10), @LastYearStartDate, 120) + ''' 
	and
	DailyTransDate < ''' + convert(char(10), @LastYearEndDate, 120) + ''''
+ case when
		isnull(@whereCondition, N'') <> N''
	then
		N' and ' + @whereCondition
	else
		''
	end
+ N' group by MerchantNo'

insert into #LastYearTransSum
(
	MerchantNo,
	SucceedCount,
	SucceedAmount
)
exec(@sqlScript);

--6. Get ThisYearRunning period data
create table #ThisYearRunningTransSum
(
	MerchantNo char(20) not null,
	SucceedCount int not null,
	SucceedAmount bigint not null
);

set @sqlScript = N'
select
	MerchantNo,
	sum(SucceedTransCount) as SucceedCount,
	sum(SucceedTransAmount) as SucceedAmount
from
	FactDailyTrans
where
	DailyTransDate >= ''' + convert(char(10), @ThisYearRunningStartDate, 120) + ''' 
	and
	DailyTransDate < ''' + convert(char(10), @ThisYearRunningEndDate, 120) + ''''
+ case when
		isnull(@whereCondition, N'') <> N''
	then
		N' and ' + @whereCondition
	else
		''
	end
+ N' group by MerchantNo'

insert into #ThisYearRunningTransSum
(
	MerchantNo,
	SucceedCount,
	SucceedAmount
)
exec(@sqlScript);

--7. Get Result
declare @currTotalAmount bigint;
set @currTotalAmount = (select SUM(SucceedAmount) from #CurrTransSum);

select
	Coalesce(Curr.MerchantNo, Prev.MerchantNo, LastYear.MerchantNo, ThisYearRunning.MerchantNo) MerchantNo,
	(select MerchantName from DimMerchant where MerchantNo = Coalesce(Curr.MerchantNo, Prev.MerchantNo, LastYear.MerchantNo, ThisYearRunning.MerchantNo)) MerchantName,
	convert(decimal, ISNULL(Curr.SucceedAmount, 0))/1000000 SucceedAmount,
	Convert(decimal, ISNULL(Curr.SucceedCount, 0))/10000 SucceedCount,
	case when ISNULL(Curr.SucceedCount, 0) = 0 
		then null 
		else (convert(decimal, ISNULL(Curr.SucceedAmount, 0))/Curr.SucceedCount)/100
	end AvgAmount,
	case when ISNULL(Prev.SucceedAmount, 0) = 0
		then null
		else convert(decimal, ISNULL(Curr.SucceedAmount, 0) - ISNULL(Prev.SucceedAmount, 0))/Prev.SucceedAmount
	end SeqIncrementAmountRatio,
	case when ISNULL(Prev.SucceedCount, 0) = 0
		then null
		else CONVERT(decimal, ISNULL(Curr.SucceedCount, 0) - ISNULL(Prev.SucceedCount, 0))/Prev.SucceedCount
	end SeqIncrementCountRatio,
	case when ISNULL(LastYear.SucceedAmount, 0) = 0
		then null
		else CONVERT(decimal, ISNULL(Curr.SucceedAmount, 0) - ISNULL(LastYear.SucceedAmount, 0))/LastYear.SucceedAmount
	end YOYIncrementAmountRatio,
	case when ISNULL(LastYear.SucceedCount, 0) = 0
		then null
		else CONVERT(decimal, ISNULL(Curr.SucceedCount, 0) - ISNULL(LastYear.SucceedCount, 0))/LastYear.SucceedCount
	end YOYIncrementCountRatio,
	case when ISNULL(@currTotalAmount, 0) = 0
		then 0
		else CONVERT(decimal, ISNULL(Curr.SucceedAmount, 0))/@currTotalAmount
	end DutyRatio,
	convert(decimal, ISNULL(ThisYearRunning.SucceedAmount, 0))/1000000 ThisYearRunningSucceedAmount,
	convert(decimal, ISNULL(ThisYearRunning.SucceedCount, 0))/10000 ThisYearRunningSucceedCount,
	convert(decimal, ISNULL(Prev.SucceedAmount, 0))/1000000 PrevSucceedAmount,
	convert(decimal, ISNULL(Prev.SucceedCount, 0))/10000 PrevSucceedCount,
	convert(decimal, ISNULL(LastYear.SucceedAmount, 0))/1000000 LastYearSucceedAmount,
	convert(decimal, ISNULL(LastYear.SucceedCount, 0))/10000 LastYearSucceedCount
into
	#Result
from
	#CurrTransSum Curr
	full outer join
	#PrevTransSum Prev
	on
		Curr.MerchantNo = Prev.MerchantNo
	full outer join
	#LastYearTransSum LastYear
	on
		Coalesce(Curr.MerchantNo, Prev.MerchantNo) = LastYear.MerchantNo
	full outer join
	#ThisYearRunningTransSum ThisYearRunning
	on
		Coalesce(Curr.MerchantNo, Prev.MerchantNo, LastYear.MerchantNo) = ThisYearRunning.MerchantNo;

if @BizCategory = N'代扣'
begin
	create table #MerchantList
	(
		MerchantNo char(20) not null primary key
	);

	set @sqlScript = N'	
	select distinct
		MerchantNo	
	from
		FactDailyTrans
	where
		DailyTransDate >= ''' + convert(char(4), (Year(@CurrEndDate)-1)) + '-01-01' + ''' 
		and
		DailyTransDate < ''' + convert(char(10), @CurrEndDate, 120) + ''''
	+ case when
			isnull(@whereCondition, N'') <> N''
		then
			N' and ' + @whereCondition
		else
			''
		end
		
	insert into #MerchantList
	(
		MerchantNo
	)
	exec(@sqlScript);
	
	select
		MerchantList.MerchantNo,
		(select MerchantName from DimMerchant where MerchantNo = MerchantList.MerchantNo) MerchantName,
		ISNULL(Result.SucceedAmount, 0) SucceedAmount,
		ISNULL(Result.SucceedCount, 0) SucceedCount,
		Result.AvgAmount,
		Result.SeqIncrementAmountRatio,
		Result.SeqIncrementCountRatio,
		Result.YOYIncrementAmountRatio,
		Result.YOYIncrementCountRatio,
		ISNULL(Result.DutyRatio, 0) DutyRatio,
		ISNULL(Result.ThisYearRunningSucceedAmount, 0) ThisYearRunningSucceedAmount,
		ISNULL(Result.ThisYearRunningSucceedCount, 0) ThisYearRunningSucceedCount,
		ISNULL(Result.PrevSucceedAmount, 0) PrevSucceedAmount,
		ISNULL(Result.PrevSucceedCount, 0) PrevSucceedCount,
		ISNULL(Result.LastYearSucceedAmount, 0) LastYearSucceedAmount,
		ISNULL(Result.LastYearSucceedCount, 0) LastYearSucceedCount
	from
		#MerchantList MerchantList
		left join
		#Result Result
		on
			MerchantList.MerchantNo = Result.MerchantNo;
			
	drop table #MerchantList;
end
else
begin
	select * from #Result;
end

--8. Clear temp table
drop table #CurrTransSum;
drop table #PrevTransSum;
drop table #LastYearTransSum;
drop table #ThisYearRunningTransSum;
drop table #Result;

end 