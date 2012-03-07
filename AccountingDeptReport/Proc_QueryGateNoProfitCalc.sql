if OBJECT_ID(N'Proc_QueryGateNoProfitCalc',N'P') is not null
begin
	drop procedure Proc_QueryGateNoProfitCalc;
end
go

create procedure Proc_QueryGateNoProfitCalc
	@StartDate datetime = '2011-10-01',
	@PeriodUnit nchar(3) = N'月',
	@EndDate datetime = '2011-10-31'
as
begin

--1 Check Input
if(@StartDate is null or ISNULL(@PeriodUnit,N'') = N'' or (@PeriodUnit = N'自定义' and @EndDate is null))
begin
	raiserror(N'Input Params can`t be empty in Proc_QueryGateNoProfitCalc!',16,1);
end	
	
	
--2.Prepare Datetime parameter
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
	
	
--3. Get PeriodUnit TransData
create table #Curr
(
	GateNo char(4) not null,
	MerchantNo char(20) not null,
	FeeEndDate datetime not null,
	TransSumCount bigint not null,
	TransSumAmount bigint not null,
	Cost decimal(15,4) not null
);

insert into 
	#Curr
exec 
	Proc_QuerySubFinancialCostCal @CurrStartDate,@CurrEndDate;
	
--4.Calculate The Profit
With FeeCalcResult as
(
	select
		GateNo,
		MerchantNo,
		SUM(ISNULL(FeeAmt,0)) FeeAmt,
		SUM(ISNULL(InstuFeeAmt,0)) InstuFeeAmt
	from
		Table_FeeCalcResult
	where
		FeeEndDate >= @CurrStartDate
		and
		FeeEndDate < @CurrEndDate
	group by
		GateNo,
		MerchantNo
),
CurrSum as
(
	select
		GateNo,
		MerchantNo,
		SUM(ISNULL(TransSumCount,0)) TransSumCount,
		SUM(ISNULL(TransSumAmount,0)) TransSumAmount,
		SUM(ISNULL(Cost,0)) Cost
	from	
		#Curr 
	group by
		GateNo,
		MerchantNo
)
select
	Curr.GateNo,
	Curr.MerchantNo,
	Curr.TransSumCount,
	convert(decimal,Curr.TransSumAmount)/100 TransSumAmount,
	FeeCalcResult.FeeAmt,
	Curr.Cost/100 Cost,
	FeeCalcResult.InstuFeeAmt
into
	#ResultWithProfit
from
	CurrSum Curr
	left join
	FeeCalcResult FeeCalcResult
	on
		Curr.GateNo = FeeCalcResult.GateNo
		and
		Curr.MerchantNo = FeeCalcResult.MerchantNo;


--5.Get Gate&Merchant Description
select
	ResultProfit.GateNo,
	GateRoute.GateDesc,
	ResultProfit.MerchantNo,
	MerInfo.MerchantName,
	ResultProfit.TransSumCount,
	ResultProfit.TransSumAmount,
	ResultProfit.FeeAmt,
	ResultProfit.Cost,
	ResultProfit.InstuFeeAmt
from
	#ResultWithProfit ResultProfit
	inner join
	Table_GateRoute GateRoute
	on
		ResultProfit.GateNo = GateRoute.GateNo
	inner join
	Table_MerInfo MerInfo
	on
		ResultProfit.MerchantNo = MerInfo.MerchantNo
order by
	ResultProfit.GateNo,
	ResultProfit.MerchantNo; 


--6.Drop The Temporary Tables

drop table #Curr;
drop table #ResultWithProfit;

end