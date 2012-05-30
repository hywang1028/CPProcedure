--[Modified] At 20120308 By 叶博:修改调用的子存储过程名、统一单位
--[Modified] At 20120528 By 王红燕:配合调用的子存储过程做相应修改
if OBJECT_ID(N'Proc_QueryGateGroupProfitCalc',N'P') is not null
begin
	drop procedure Proc_QueryGateGroupProfitCalc;
end
go

create procedure Proc_QueryGateGroupProfitCalc
	@StartDate datetime = '2011-11-01',
	@PeriodUnit nChar(3) = N'月',
	@EndDate datetime = '2011-10-31'
as
begin

--1.Check Input
if(@StartDate is null or ISNULL(@PeriodUnit,N'') = N'' or (@PeriodUnit = N'自定义' and @EndDate is null))
begin
	raiserror(N'Input Params can`t be empty in Proc_QueryGateGroupProfitCalc!',16,1);
end


--2.Initial StartDate and EndDate
declare @CurrStartDate datetime;
declare @CurrEndDate  datetime;
declare @PrevStartDate datetime;
declare @PrevEndDate datetime;
declare @LastYearStartDate datetime;
declare @LastYearEndDate datetime;

if(@PeriodUnit = N'周')
begin
	set @CurrStartDate = @StartDate;
	set @CurrEndDate = DATEADD(WEEK,1,@StartDate);
	set @PrevStartDate = DATEADD(WEEK,-1,@CurrStartDate);
	set @PrevEndDate = @CurrStartDate;
	set @LastYearStartDate = DATEADD(YEAR,-1,@CurrStartDate);
	set @LastYearEndDate = DATEADD(YEAR,-1,@CurrEndDate);
end
else if(@PeriodUnit = N'月')
begin
	set @CurrStartDate = @StartDate;
	set @CurrEndDate = DATEADD(MONTH,1,@StartDate);
	set @PrevStartDate = DATEADD(MONTH,-1,@CurrStartDate);
	set @PrevEndDate = @CurrStartDate;
	set @LastYearStartDate = DATEADD(YEAR,-1,@CurrStartDate);
	set @LastYearEndDate = DATEADD(YEAR,-1,@CurrEndDate);	
end
else if(@PeriodUnit = N'季度')
begin
	set @CurrStartDate = @StartDate;
	set @CurrEndDate = DATEADD(QUARTER,1,@StartDate);
	set @PrevStartDate = DATEADD(QUARTER,-1,@CurrStartDate);
	set @PrevEndDate = @CurrStartDate;
	set @LastYearStartDate = DATEADD(YEAR,-1,@CurrStartDate);
	set @LastYearEndDate = DATEADD(YEAR,-1,@CurrEndDate);
end
else if(@PeriodUnit = N'半年')
begin
	set @CurrStartDate = @StartDate;
	set @CurrEndDate = DATEADD(QUARTER,2,@StartDate);
	set @PrevStartDate = DATEADD(QUARTER,-2,@CurrStartDate);
	set @PrevEndDate = @CurrStartDate;
	set @LastYearStartDate = DATEADD(YEAR,-1,@CurrStartDate);
	set @LastYearEndDate = DATEADD(YEAR,-1,@CurrEndDate);
end
else if(@PeriodUnit = N'年')
begin
	set @CurrStartDate = @StartDate;
	set @CurrEndDate = DATEADD(YEAR,1,@StartDate);
	set @PrevStartDate = DATEADD(YEAR,-1,@CurrStartDate);
	set @PrevEndDate = @CurrStartDate;
	set @LastYearStartDate = DATEADD(YEAR,-1,@CurrStartDate);
	set @LastYearEndDate = DATEADD(YEAR,-1,@CurrEndDate);
end
else if(@PeriodUnit = N'自定义')
begin
	set @CurrStartDate = @StartDate;
	set @CurrEndDate = DATEADD(day,1,@EndDate);
	set @PrevStartDate = DATEADD(day,-1*DATEDIFF(day,@CurrStartDate,@CurrEndDate),@CurrStartDate);
	set @PrevEndDate = @CurrStartDate;
	set @LastYearStartDate = DATEADD(YEAR,-1,@CurrStartDate);
	set @LastYearEndDate = DATEADD(YEAR,-1,@CurrEndDate);
end


--3. Get Curr TransData
create table #Curr
(
	GateNo char(4) not null,
	MerchantNo char(20) not null,
	FeeEndDate datetime not null,
	TransSumCount bigint not null,
	TransSumAmount bigint not null,
	Cost decimal(15,4) not null,
	FeeAmt decimal(15,2) not null,
	InstuFeeAmt decimal(15,2) not null
);

insert into
	#Curr
exec 
	Proc_CalPaymentCost @CurrStartDate,@CurrEndDate;


--4.Get CurrentSum Data And SumFeeAmt&InstuFeeAmt
with CurrSum as
(
	select
		GateNo,
		SUM(ISNULL(TransSumCount,0)) SumCount,
		SUM(ISNULL(TransSumAmount,0))SumAmount,
		SUM(ISNULL(Cost,0)) Cost,
		SUM(ISNULL(FeeAmt,0)) FeeAmt,
		SUM(ISNULL(InstuFeeAmt,0)) InstuFeeAmt
	from	
		#Curr 
	group by
		GateNo
)
--5.Get Result
select
	case when
		GateCate.GateCategory1 is null	
	then
		 N'其他'
	else
		GateCate.GateCategory1
	end GateCategory1,	
	Curr.GateNo,
	GateRoute.GateDesc,
	Curr.SumCount,
	Curr.SumAmount/100.0 as SumAmount,
	Curr.FeeAmt/100.0 as FeeAmt,
	Curr.InstuFeeAmt/100.0 as InstuFeeAmt,
	Curr.Cost/100.0 as Cost
from
	CurrSum Curr
	left join
	Table_GateCategory GateCate
	on
		Curr.GateNo = GateCate.GateNo
	inner join
	Table_GateRoute GateRoute
	on
		Curr.GateNo = GateRoute.GateNo;	

--6. Drop Temporary Tables
drop table #Curr;

end