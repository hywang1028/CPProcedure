if OBJECT_ID(N'Proc_QueryMonthlyTransFeeCostTrend', N'P') is not null
begin
	drop procedure Proc_QueryMonthlyTransFeeCostTrend;
end
go

create procedure Proc_QueryMonthlyTransFeeCostTrend  
  @QueryYear char(4) = '2011',  
  @IndustryName char(20) = N'航空',
  @BizName char(20) = N'B2C' 
as  
begin 

--1. Prepare Source Data
--1.1 Prepare Query Date
--1.1.1 Prepare StartDate and EndDate
DECLARE @StartDate datetime;   
DECLARE @EndDate datetime; 
set @StartDate = @QueryYear + '-01-01';
set @EndDate = RTrim(Convert(char,@QueryYear+1))+ '-01-01';

--1.1.2 Prepare Month Period
CREATE TABLE #TimePeriod  
(  
	 PeriodStart datetime NOT NULL PRIMARY KEY,   
	 PeriodEnd datetime NOT NULL  
);
DECLARE @PeriodStart datetime;   
DECLARE @PeriodEnd datetime;  
SET @PeriodStart = @StartDate;  
SET @PeriodEnd = DATEADD(month, 1, @PeriodStart);

WHILE (@PeriodEnd < @EndDate)   
BEGIN   
	 INSERT INTO #TimePeriod  
	 (  
		  PeriodStart,   
		  PeriodEnd  
	 )  
	 VALUES   
	 (  
		  @PeriodStart,  
		  @PeriodEnd  
	 );  
	 
	 SET @PeriodStart = @PeriodEnd;  
	 SET @PeriodEnd = DATEADD(month, 1, @PeriodStart);  
END  
INSERT INTO #TimePeriod  
(  
	 PeriodStart,   
	 PeriodEnd  
)  
VALUES   
(  
	 @PeriodStart,   
	 @EndDate
); 

create table #GateMerCostResult
(
	GateNo char(4) not null,
	MerchantNo char(20) not null,
	FeeEndDate datetime not null,
	TransSumCount bigint not null,
	TransSumAmount bigint not null,
	Cost decimal(15,4) not null
);

insert into #GateMerCostResult
exec Proc_QuerySubFinancialCostCal @StartDate,@EndDate;

select 
	Period.PeriodStart,
	GateMerCost.GateNo,
	GateMerCost.MerchantNo,
	SUM(ISNULL(GateMerCost.TransSumCount,0)) TransSumCount,
	SUM(ISNULL(GateMerCost.TransSumAmount,0)) TransSumAmount,
	SUM(ISNULL(GateMerCost.Cost,0)) Cost
into
	#MonthlyGateMerCostResult
from
	#GateMerCostResult GateMerCost
	inner join
	#TimePeriod Period
	on
		GateMerCost.FeeEndDate >= Period.PeriodStart
		and
		GateMerCost.FeeEndDate <  Period.PeriodEnd
group by
	Period.PeriodStart,
	GateMerCost.GateNo,
	GateMerCost.MerchantNo;  
		
--1.2 Prepare Payment Data
--1.2.1 Prepare Cost Data
select
	PeriodStart,
	GateNo,
	MerchantNo,
	TransSumCount,
	CONVERT(decimal,TransSumAmount)/100 TransSumAmount,
	Cost/100 Cost
into
	#GateMerCost
from
	#MonthlyGateMerCostResult;
	
--1.2.2 Prepare Fee Data
select 
	TimePeriod.PeriodStart,
	Fee.MerchantNo,
	Fee.GateNo,
	SUM(FeeAmt) FeeAmt,
	SUM(InstuFeeAmt) InstuFeeAmt
into
	#GateMerFeeResult
from
	Table_FeeCalcResult Fee
	inner join
	#TimePeriod TimePeriod
	on
		Fee.FeeEndDate >= TimePeriod.PeriodStart
		and
		Fee.FeeEndDate <  TimePeriod.PeriodEnd
	left join
	Table_GateCategory Gate
	on
		Fee.GateNo = Gate.GateNo
	left join
	Table_SalesDeptConfiguration Sales
	on
		Fee.MerchantNo = Sales.MerchantNo
where
	Sales.IndustryName = @IndustryName
	and
	Gate.GateCategory1 = @BizName
group by
	TimePeriod.PeriodStart,
	Fee.MerchantNo,
	Fee.GateNo;
	
--1.2.3 Join All Payment Data
select
	Fee.PeriodStart,
	Fee.MerchantNo,
	Fee.GateNo,
	ISNULL(Fee.FeeAmt,0) FeeAmt,
	ISNULL(Fee.InstuFeeAmt,0) InstuFeeAmt,
	ISNULL(Cost.TransSumCount,0) TransSumCount,
	ISNULL(Cost.TransSumAmount,0) TransSumAmount,
	ISNULL(Cost.Cost,0) Cost
into
	#AllResult
from 
	#GateMerFeeResult Fee
	left join
	#GateMerCost Cost
	on
		Fee.PeriodStart = Cost.PeriodStart
		and
		Fee.GateNo = Cost.GateNo
		and
		Fee.MerchantNo = Cost.MerchantNo;
		
--1.3 Prepare ORA Data
--select
--	TimePeriod.PeriodStart,
--	N'ORA代收付' as GateCategory1,
--	ORA.MerchantNo,
--	OraMer.MerchantName,
--	SUM(ORA.FeeAmount) FeeAmt,
--	0 as InstuFeeAmt,
--	SUM(ORA.TransCount) TransSumCount,
--	SUM(ORA.TransAmount) TransSumAmount,
--	0 as Cost
--into
--	#ORAData
--from
--	Table_OraTransSum ORA
--	inner join
--	#TimePeriod TimePeriod
--	on
--		ORA.CPDate >= TimePeriod.PeriodStart
--		and
--		ORA.CPDate <  TimePeriod.PeriodEnd
--	inner join
--	Table_OraMerchants OraMer
--	on
--		ORA.MerchantNo = OraMer.MerchantNo
--group by
--	TimePeriod.PeriodStart,
--	N'ORA代收付',
--	ORA.MerchantNo,
--	OraMer.MerchantName;

--2. Config GateCategory Data
select
	Result.PeriodStart,
	--ISNULL(Sales.IndustryName,N'未配置行业') IndustryName,
	--ISNULL(Gate.GateCategory1,N'其他') GateCategory,
	Result.MerchantNo,
	SUM(Result.FeeAmt) FeeAmt,
	SUM(Result.InstuFeeAmt) InstuFeeAmt,
	SUM(Result.TransSumCount) TransSumCount,
	SUM(Result.TransSumAmount) TransSumAmount,
	SUM(Result.Cost) Cost
into
	#IndustryData
from
	#AllResult Result
	--left join
	--Table_GateCategory Gate
	--on
	--	Result.GateNo = Gate.GateNo
	--left join
	--Table_SalesDeptConfiguration Sales
	--on
	--	Result.MerchantNo = Sales.MerchantNo
group by
	Result.PeriodStart,
	--Gate.GateCategory1,
	--Sales.IndustryName,
	Result.MerchantNo;

--3. Get Result
select
	Left(Convert(char(10),Result.PeriodStart,120),7) PeriodStart,
	Result.MerchantNo,
	Mer.MerchantName,
	Convert(decimal,ISNULL(Result.TransSumAmount,0))/100000000 as N'交易金额_亿元',
	Convert(decimal,ISNULL(Result.TransSumCount,0))/10000 as N'交易笔数_万笔',
	case when ISNULL(Result.TransSumAmount,0) = 0 then 0 else 10000*ISNULL(Result.FeeAmt,0)/Result.TransSumAmount End as N'扣率_万分之',
	Convert(decimal,ISNULL(Result.FeeAmt,0))/10000 as N'收入_万元',
	case when ISNULL(Result.TransSumAmount,0) = 0 then 0 else 10000*ISNULL(Result.Cost,0)/Result.TransSumAmount End as N'银行成本率_万分之',
	Convert(decimal,ISNULL(Result.Cost,0))/10000 as N'银行成本_万元',
	case when ISNULL(Result.TransSumAmount,0) = 0 then 0 else 10000*ISNULL(Result.InstuFeeAmt,0)/Result.TransSumAmount End as N'分润成本率_万分之',
	Convert(decimal,ISNULL(Result.InstuFeeAmt,0))/10000 as N'分润成本_万元'
from
	#IndustryData Result
	left join
	Table_MerInfo Mer
	on
		Result.MerchantNo = Mer.MerchantNo;
--where
--	IndustryName = @IndustryName
--	and
--	GateCategory = @BizName;
	
--4. Drop Table 
Drop Table #TimePeriod;
Drop Table #MonthlyGateMerCostResult;	
Drop Table #GateMerCostResult;
Drop Table #GateMerFeeResult;
Drop Table #GateMerCost;
Drop Table #AllResult;
Drop Table #IndustryData;

End