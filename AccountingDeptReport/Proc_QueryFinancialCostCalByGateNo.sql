if OBJECT_ID(N'Proc_QueryFinancialCostCalByGateNo',N'P') is not null
begin
	drop procedure Proc_QueryFinancialCostCalByGateNo;
end
go

create procedure Proc_QueryFinancialCostCalByGateNo
	@StartDate datetime = '2011-10-01',
	@PeriodUnit nChar(3) = '�Զ���',
	@EndDate datetime = '2011-10-31'
as
begin

--1. Check Input 
if(@StartDate is null or ISNULL(@PeriodUnit,N'') = N'' or (@PeriodUnit = N'�Զ���' and @EndDate is null))
begin
	raiserror(N'Input Params can`t be empty in Proc_QueryFinancialCostCalByGateNo!',16,1);
end


--2. Prepare @StartDate and @EndDate
declare @CurrStartDate datetime;
declare @CurrEndDate  datetime;
declare @PrevStartDate datetime;
declare @PrevEndDate datetime;
declare @LastYearStartDate datetime;
declare @LastYearEndDate datetime;

if(@PeriodUnit = N'��')
begin
	set @CurrStartDate = @StartDate;
	set @CurrEndDate = DATEADD(WEEK,1,@StartDate);
	set @PrevStartDate = DATEADD(WEEK,-1,@CurrStartDate);
	set @PrevEndDate = @CurrStartDate;
	set @LastYearStartDate = DATEADD(YEAR,-1,@CurrStartDate);
	set @LastYearEndDate = DATEADD(YEAR,-1,@CurrEndDate);
end
else if(@PeriodUnit = N'��')
begin
	set @CurrStartDate = @StartDate;
	set @CurrEndDate = DATEADD(MONTH,1,@StartDate);
	set @PrevStartDate = DATEADD(MONTH,-1,@CurrStartDate);
	set @PrevEndDate = @CurrStartDate;
	set @LastYearStartDate = DATEADD(YEAR,-1,@CurrStartDate);
	set @LastYearEndDate = DATEADD(YEAR,-1,@CurrEndDate);	
end
else if(@PeriodUnit = N'����')
begin
	set @CurrStartDate = @StartDate;
	set @CurrEndDate = DATEADD(QUARTER,1,@StartDate);
	set @PrevStartDate = DATEADD(QUARTER,-1,@CurrStartDate);
	set @PrevEndDate = @CurrStartDate;
	set @LastYearStartDate = DATEADD(YEAR,-1,@CurrStartDate);
	set @LastYearEndDate = DATEADD(YEAR,-1,@CurrEndDate);
end
else if(@PeriodUnit = N'����')
begin
	set @CurrStartDate = @StartDate;
	set @CurrEndDate = DATEADD(QUARTER,2,@StartDate);
	set @PrevStartDate = DATEADD(QUARTER,-1,@CurrStartDate);
	set @PrevEndDate = @CurrStartDate;
	set @LastYearStartDate = DATEADD(YEAR,-1,@CurrStartDate);
	set @LastYearEndDate = DATEADD(YEAR,-1,@CurrEndDate);
end
else if(@PeriodUnit = N'��')
begin
	set @CurrStartDate = @StartDate;
	set @CurrEndDate = DATEADD(YEAR,1,@StartDate);
	set @PrevStartDate = DATEADD(YEAR,-1,@CurrStartDate);
	set @PrevEndDate = @CurrStartDate;
	set @LastYearStartDate = DATEADD(YEAR,-1,@CurrStartDate);
	set @LastYearEndDate = DATEADD(YEAR,-1,@CurrEndDate);
end
else if(@PeriodUnit = N'�Զ���')
begin
	set @CurrStartDate = @StartDate;
	set @CurrEndDate = DATEADD(day,1,@EndDate);
	set @PrevStartDate = DATEADD(day,-1*DATEDIFF(day,@CurrStartDate,@CurrEndDate),@CurrStartDate);
	set @PrevEndDate = @CurrStartDate;
	set @LastYearStartDate = DATEADD(YEAR,-1,@CurrStartDate);
	set @LastYearEndDate = DATEADD(YEAR,-1,@CurrEndDate);
end

--3. Get PeriodUnit TransData
create table #Curr
(
	GateNo char(4) not null,
	MerchantNo char(20) not null,
	TransSumCount bigint not null,
	TransSumAmount bigint not null,
	Cost decimal(15,4) not null
);

insert into 
	#Curr
exec 
	Proc_QuerySubFinancialCostCal @CurrStartDate,@CurrEndDate;
	
create table #Prev
(
	GateNo char(4) not null,
	MerchantNo char(20) not null,
	TransSumCount bigint not null,
	TransSumAmount bigint not null,
	Cost decimal(15,4) not null
);

insert into
	#Prev
exec
	Proc_QuerySubFinancialCostCal @PrevStartDate,@PrevEndDate;
	
create table #LastYear
(
	GateNo char(4) not null,
	MerchantNo char(20) not null,
	TransSumCount bigint not null,
	TransSumAmount bigint not null,
	Cost decimal(15,4) not null
);

insert into
	#LastYear
exec
	Proc_QuerySubFinancialCostCal @LastYearStartDate,@LastYearEndDate;
	

--4. Get GateNoCostRule
create table #GateNoCostRule
(
	GateNo char(4) not null,
	GateName nvarchar(80) not null,
	ApplyDate char(20),
	CostCalculateRule nChar(100)
);	

insert into
	#GateNoCostRule
exec
	Proc_QueryGateNoCostRule;
	
--5.Get TransSumCount&TransSumAmount
with CurrSum as
(
	select
		GateNo,
		SUM(ISNULL(TransSumCount,0)) SumCount,
		SUM(ISNULL(TransSumAmount,0)) SumAmount,
		SUM(ISNULL(Cost,0)) Cost
	from	
		#Curr 
	group by
		GateNo
),
PrevSum as
(
	select
		GateNo,
		SUM(ISNULL(TransSumCount,0)) SumCount,
		SUM(ISNULL(TransSumAmount,0)) SumAmount,
		SUM(ISNULL(Cost,0)) Cost
	from	
		#Prev
	group by
		GateNo	
),
LastYearSum as
(
	select
		GateNo,
		SUM(ISNULL(TransSumCount,0)) SumCount,
		SUM(ISNULL(TransSumAmount,0)) SumAmount,
		SUM(ISNULL(Cost,0)) Cost
	from	
		#LastYear
	group by
		GateNo
)


--6. Get Result
select
	coalesce(Curr.GateNo,Prev.GateNo,LastYear.GateNo) GateNo,
	coalesce(ISNULL(Curr.SumCount,0),ISNULL(Prev.SumCount,0),ISNULL(LastYear.SumCount,0)) SumCount,
	coalesce(ISNULL(Curr.SumAmount,0),ISNULL(Prev.SumAmount,0),ISNULL(LastYear.SumAmount,0)) SumAmount,
	ISNULL(Curr.Cost,0) CurrCost,
	ISNULL(Prev.Cost,0) PrevCost,
	ISNULL(LastYear.Cost,0) LastYearCost
into
	#Result	
from
	CurrSum Curr
	full outer join
	PrevSum Prev
	on
		Curr.GateNo = Prev.GateNo
	full outer join
	LastYearSum LastYear
	on
		coalesce(Curr.GateNo,Prev.GateNo) = LastYear.GateNo;

select
	case when
		GateCate.GateCategory1 is null	
	then
		 N'����'
	else
		GateCate.GateCategory1
	end GateCategory1,	
	Result.GateNo,
	GateNoCostRule.GateName,
	Result.SumCount,
	Result.SumAmount,
	Result.CurrCost,
	Result.PrevCost,
	Result.LastYearCost,
	GateNoCostRule.CostCalculateRule
from
	#Result Result
	left join
	#GateNoCostRule GateNoCostRule
	on
		Result.GateNo = GateNoCostRule.GateNo
	left join
	Table_GateCategory GateCate
	on
		Result.GateNo = GateCate.GateNo;

	
--7. drop temporary table
drop table #Curr;
drop table #Prev;
drop table #LastYear;
drop table #GateNoCostRule;

end
