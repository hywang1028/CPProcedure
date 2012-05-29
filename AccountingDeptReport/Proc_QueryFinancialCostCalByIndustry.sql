--[Modified] At 20120308 By 叶博:修改调用的子存储过程名、统一单位
--[Modified] At 20120528 By 王红燕:配合调用的子存储过程做相应修改
if OBJECT_ID(N'Proc_QueryFinancialCostCalByIndustry',N'P') is not null
begin
	drop procedure Proc_QueryFinancialCostCalByIndustry;
end
go

create procedure Proc_QueryFinancialCostCalByIndustry
	@StartDate datetime = '2011-09-01',
	@PeriodUnit nChar(3) = N'自定义',
	@EndDate datetime = '2011-09-30'
as
begin


--1. Check Input
if(@StartDate is null or ISNULL(@PeriodUnit,N'') = N'' or (@PeriodUnit = N'自定义' and @EndDate is null))
begin
	raiserror(N'Input params be empty in Proc_QueryFinancialCostCalByIndustry',16,1);
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
	set @CurrEndDate = DATEADD(DAY,1,@EndDate);
	set @PrevStartDate = DATEADD(DAY,-1*DATEDIFF(DAY,@CurrStartDate,@CurrEndDate),@CurrStartDate);
	set @PrevEndDate = @CurrStartDate;
	set @LastYearStartDate = DATEADD(YEAR,-1,@CurrStartDate);
	set @LastYearEndDate = DATEADD(year,-1,@CurrEndDate);
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


--2.2 Get PreviousData
create table #Prev
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
	#Prev
exec
	Proc_CalPaymentCost @PrevStartDate,@PrevEndDate;


--2.3 Get LastYearData
create table #LastYear
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
	#LastYear
exec
	Proc_CalPaymentCost @LastYearStartDate,@LastYearEndDate	;
		
--3. Get IndustryName
with CurrSum as
(
	select
		MerchantNo,
		SUM(ISNULL(TransSumCount,0)) SumCount,
		SUM(ISNULL(TransSumAmount,0)) SumAmount,
		SUM(ISNULL(Cost,0)) Cost
	from	
		#Curr 
	group by
		MerchantNo
),
PrevSum as
(
	select
		MerchantNo,
		SUM(ISNULL(TransSumCount,0)) SumCount,
		SUM(ISNULL(TransSumAmount,0)) SumAmount,
		SUM(ISNULL(Cost,0)) Cost
	from	
		#Prev
	group by
		MerchantNo	
),
LastYearSum as
(
	select
		MerchantNo,
		SUM(ISNULL(TransSumCount,0)) SumCount,
		SUM(ISNULL(TransSumAmount,0)) SumAmount,
		SUM(ISNULL(Cost,0)) Cost
	from	
		#LastYear
	group by
		MerchantNo
)
select
	SalesDeptConfig.IndustryName,
	coalesce(Curr.MerchantNo,Prev.MerchantNo,LastYear.MerchantNo) MerchantNo,
	MerInfo.MerchantName,
	ISNULL(Curr.Cost,0) CurrCost,
	ISNULL(Prev.Cost,0) PrevCost,
	ISNULL(LastYear.Cost,0) LastYearCost
from
	CurrSum Curr
	full outer join 
	PrevSum Prev
	on
		Curr.MerchantNo = Prev.MerchantNo
	full outer join
	LastYearSum LastYear
	on
		coalesce(Curr.MerchantNo,Prev.MerchantNo) = LastYear.MerchantNo
	left join
	Table_SalesDeptConfiguration SalesDeptConfig
	on
		coalesce(Curr.MerchantNo,Prev.MerchantNo,LastYear.MerchantNo) = SalesDeptConfig.MerchantNo
	left join
	Table_MerInfo MerInfo
	on
		coalesce(Curr.MerchantNo,Prev.MerchantNo,LastYear.MerchantNo) = MerInfo.MerchantNo;
		

--5. drop temp table
drop table #Curr;
drop table #Prev;
drop table #LastYear;

end