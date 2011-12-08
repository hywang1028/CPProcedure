if OBJECT_ID(N'Proc_QueryIndustryProfitCalc',N'P') is not null
begin
	drop procedure Proc_QueryIndustryProfitCalc;
end
go

create procedure Proc_QueryIndustryProfitCalc
	@StartDate datetime = '2011-10-01',
	@PeriodUnit nChar(3) = N'月',
	@EndDate datetime = '2011-10-31'
as
begin


--1 Check
--1.1 CheckInput
if(@StartDate is null or ISNULL(@PeriodUnit,N'') = N'' or (@PeriodUnit = N'自定义' and @EndDate is null))
begin
	raiserror(N'Input params be empty in Proc_QueryIndustryProfitCalc',16,1);
end

----1.2 Check Unchanged Rule GateNo
----1.2.1 Find all grouped GateNo
--select
--	GateNo,
--	ApplyDate,
--	GateGroup
--into
--	#GroupGate
--from
--	Table_CostRuleByYear
--where
--	GateGroup <> 0;
	
----1.2.2 Get NextApplyDate for #GroupGate
--select
--	GroupGate.GateNo,
--	GroupGate.ApplyDate,
--	GroupGate.GateGroup,
--	MIN(isnull(GateCostRule.ApplyDate, '9999-01-01')) NextApplyDate
--into
--	#GroupGateWithNextApplyDate
--from
--	#GroupGate GroupGate
--	left join
--	Table_GateCostRule GateCostRule
--	on
--		GroupGate.GateNo = GateCostRule.GateNo
--		and
--		GroupGate.ApplyDate < GateCostRule.ApplyDate
--group by
--	GroupGate.GateNo,
--	GroupGate.ApplyDate,
--	GroupGate.GateGroup;
	

----1.2.3 Calc count by GateGroup,ApplyDate
--select
--	GateGroup,
--	ApplyDate,
--	COUNT(*) cnt
--into
--	#GateCnt1	
--from
--	#GroupGateWithNextApplyDate
--group by
--	GateGroup,
--	ApplyDate;

----1.2.4 Calc count by GateGroup,ApplyDate,NextApplyDate
--select
--	GateGroup,
--	ApplyDate,
--	NextApplyDate,
--	COUNT(*) cnt
--into
--	#GateCnt2	
--from
--	#GroupGateWithNextApplyDate
--group by
--	GateGroup,
--	ApplyDate,
--	NextApplyDate;

----1.2.5 Compare counts
--select distinct
--	GC1.GateGroup
--from
--	#GateCnt1 GC1
--	inner join
--	#GateCnt2 GC2
--	on
--		GC1.GateGroup = GC2.GateGroup
--		and
--		GC1.ApplyDate = GC2.ApplyDate
--where
--	GC1.cnt <> GC2.cnt;


--2.Prepare StartDate and EndDate
declare @CurrStartDate datetime;
declare @CurrEndDate datetime;

if(@PeriodUnit = N'周')
begin
	set @CurrStartDate = @StartDate;
	set @CurrEndDate = DATEADD(WEEK,1,@StartDate);
end
else if(@PeriodUnit = N'月')
begin
	set @CurrStartDate = @StartDate;
	set @CurrEndDate = DATEADD(MONTH,1,@StartDate);
end
else if(@PeriodUnit = N'季度')
begin
	set @CurrStartDate = @StartDate;
	set @CurrEndDate = DATEADD(QUARTER,1,@StartDate);
end
else if(@PeriodUnit = N'半年')
begin
	set @CurrStartDate = @StartDate;
	set @CurrEndDate = DATEADD(QUARTER,2,@StartDate);
end
else if(@PeriodUnit = N'年')
begin
	set @CurrStartDate = @StartDate;
	set @CurrEndDate = DATEADD(YEAR,1,@StartDate);
end
else if(@PeriodUnit = N'自定义')
begin
	set @CurrStartDate = @StartDate;
	set @CurrEndDate = DATEADD(DAY,1,@EndDate);
end


--2. Get Period Data

--2.1 Get CurrentData
create table #Curr
(
	GateNo char(4) not null,
	MerchantNo char(20) not null,
	TransSumCount bigint not null,
	TransSumAmount bigint not null,
	Cost decimal(15,4)
);

insert into 
	#Curr 
exec
	Proc_QuerySubFinancialCostCal @CurrStartDate,@CurrEndDate;
	

--3.Fetch SumAmt by All MerchantNo
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
)
select
	Curr.MerchantNo,
	SUM(Curr.TransSumCount) TransSumCount,
	SUM(convert(decimal,Curr.TransSumAmount)/100) TransSumAmount,
	SUM(FeeResult.FeeAmt) FeeAmt,
	SUM(Curr.Cost) Cost,
	SUM(FeeResult.InstuFeeAmt) InstuFeeAmt
into
	#MerWithAllAmt
from
	#Curr Curr
	left join
	FeeCalcResult FeeResult
	on
		Curr.GateNo = FeeResult.GateNo
		and
		Curr.MerchantNo = FeeResult.MerchantNo
group by
	Curr.MerchantNo;

--4.Get IndustryName and MerchantName of all MerchantNo
select
	ISNULL(Sales.IndustryName,N'未配置行业商户') IndustryName,
	MerWithAmt.MerchantNo,
	MerInfo.MerchantName,
	MerWithAmt.TransSumCount,
	MerWithAmt.TransSumAmount,
	MerWithAmt.FeeAmt,
	MerWithAmt.Cost/100 Cost,
	MerWithAmt.InstuFeeAmt
from	
	#MerWithAllAmt MerWithAmt
	left join
	Table_SalesDeptConfiguration Sales
	on
		MerWithAmt.MerchantNo = Sales.MerchantNo
	left join
	Table_MerInfo MerInfo
	on
		MerWithAmt.MerchantNo = MerInfo.MerchantNo
order by
	Sales.IndustryName,
	MerWithAmt.MerchantNo;

--5. Drop Temporary Tables
drop table #Curr;
drop table #MerWithAllAmt;

end