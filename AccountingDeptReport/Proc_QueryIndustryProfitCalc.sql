--[Modified] At 20120308 By 叶博:修改调用的子存储过程名、统一单位
--[Modified] At 20120528 By 王红燕:配合调用的子存储过程做相应修改
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


--1 Check Input
if(@StartDate is null or ISNULL(@PeriodUnit,N'') = N'' or (@PeriodUnit = N'自定义' and @EndDate is null))
begin
	raiserror(N'Input params be empty in Proc_QueryIndustryProfitCalc',16,1);
end


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
	FeeEndDate datetime not null,
	TransSumCount bigint not null,
	TransSumAmount bigint not null,
	Cost decimal(15,4),
	FeeAmt decimal(15,2) not null,
	InstuFeeAmt decimal(15,2) not null
);

insert into 
	#Curr 
exec
	Proc_CalPaymentCost @CurrStartDate,@CurrEndDate;
	

--3.Fetch SumAmt by All MerchantNo
With FeeCalcResult as
(
	select
		MerchantNo,
		SUM(TransSumCount) TransSumCount,
		SUM(TransSumAmount) TransSumAmount,
		SUM(FeeAmt) FeeAmt,
		SUM(Cost) Cost,
		SUM(InstuFeeAmt) InstuFeeAmt
	from
		#Curr
	group by
		MerchantNo
)
--4.Get IndustryName and MerchantName of all MerchantNo
select
	ISNULL(Sales.IndustryName,N'未配置行业商户') IndustryName,
	FeeCalcResult.MerchantNo,
	MerInfo.MerchantName,
	FeeCalcResult.TransSumCount,
	FeeCalcResult.TransSumAmount/100.0 as TransSumAmount,
	FeeCalcResult.FeeAmt/100.0 as FeeAmt,
	FeeCalcResult.Cost/100.0 as Cost,
	FeeCalcResult.InstuFeeAmt/100.0 as InstuFeeAmt
from	
	FeeCalcResult
	left join
	Table_SalesDeptConfiguration Sales
	on
		FeeCalcResult.MerchantNo = Sales.MerchantNo
	left join
	Table_MerInfo MerInfo
	on
		FeeCalcResult.MerchantNo = MerInfo.MerchantNo
order by
	Sales.IndustryName,
	FeeCalcResult.MerchantNo;

--5. Drop Temporary Tables
drop table #Curr;

end