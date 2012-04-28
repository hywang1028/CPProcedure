--[Created]At 20120316 By 叶博:支付和Ora业务的投入产出分析
--Input:StartDate,PeriodUnit,EndDate
--Output:GateCategory,	R.GateCategory,MerchantNo,MerchantName,Cost,FeeAmt,InstuAmt,NetIncome,TransAmt,Invest,IncomeSum
if OBJECT_ID(N'Proc_QueryPaymentAndOraBizROI',N'P') is not null
begin
	drop procedure Proc_QueryPaymentAndOraBizROI;
end
go

create procedure Proc_QueryPaymentAndOraBizROI
	@StartDate datetime = '2011-01-01',
	@PeriodUnit nchar(3) = '月',
	@EndDate datetime = '2011-06-01'
as
begin

--1.Input Check
if(@StartDate is null or ISNULL(@PeriodUnit,N'') = N'' or (@PeriodUnit = N'自定义' and @EndDate is null))
begin
	raiserror(N'Input params can`t be empty in Proc_QueryPaymentAndOraBizROI',16,1);
end


--2.Prepare Time Period Parameters
declare @CurrStartDate datetime;
declare @CurrEndDate datetime;

if(@PeriodUnit = '月')
begin
	set @CurrStartDate = @StartDate;
	set @CurrEndDate = DATEADD(MONTH,1,@CurrStartDate);
end

else if(@PeriodUnit = N'季度')
begin
	set @CurrStartDate = @StartDate;
	set @CurrEndDate = DATEADD(QUARTER,1,@CurrStartDate);
end

else if(@PeriodUnit = N'半年')
begin
	set @CurrStartDate = @StartDate;
	set @CurrEndDate = DATEADD(QUARTER,2,@CurrStartDate);
end

else if(@PeriodUnit = N'年')
begin
	set @CurrStartDate = @StartDate;
	set @CurrEndDate = DATEADD(YEAR,1,@CurrStartDate);
end

else if(@PeriodUnit = N'自定义')
begin
	set @CurrStartDate = @StartDate;
	set @CurrEndDate = DATEADD(DAY,1,@EndDate);
end


--3.Get Payment Biz Data (Get Payment Cost、Fee、InstuFee And GateCategory)
create table #PaymentCostResult
(
	GateNo char(4) not null,
	MerchantNo char(20) not null,
	FeeEndDate datetime not null,
	TransCnt bigint not null,
	TransAmt bigint not null,
	Cost decimal(15,4) not null
);
insert into 
	#PaymentCostResult
exec
	Proc_CalPaymentCost @CurrStartDate,@CurrEndDate;
	
create table #PaymentFeeResult
(
	MerchantNo char(20) not null,
	GateNo char(4) not null,
	FeeEndDate char(400) not null,
	FeeAmt decimal(15,4) not null
);
insert into 
	#PaymentFeeResult
exec 
	Proc_CalPaymentFee @CurrStartDate,@CurrEndDate;  
	
create table #PaymentInstuFeeResult
(
	MerchantNo char(20) not null,
	GateNo char(4) not null,
	FeeEndDate datetime not null,
	InstuAmt decimal(15,5) not null
);
insert into
	#PaymentInstuFeeResult
exec
	Proc_CalPaymentInstuFee @CurrStartDate,@CurrEndDate;	

With #FeeResult as
(
	select
		MerchantNo,
		GateNo,
		SUM(ISNULL(PurAmt,0)) TransAmt
	from
		Table_FeeCalcResult
	where
		FeeEndDate >= @CurrStartDate
		and
		FeeEndDate < @CurrEndDate 
	group by
		MerchantNo,
		GateNo
),
#PaymentCost as
(
	select
		MerchantNo,
		GateNo,
		SUM(Cost) Cost
	from
		#PaymentCostResult
	group by
		MerchantNo,
		GateNo
),
#PaymentFee as
(
	select
		MerchantNo,
		GateNo,
		SUM(FeeAmt) FeeAmt
	from
		#PaymentFeeResult
	group by
		MerchantNo,
		GateNo
),
#PaymentInstuFee as
(
	select
		MerchantNo,
		GateNo,
		SUM(InstuAmt) InstuAmt
	from
		#PaymentInstuFeeResult
	group by
		MerchantNo,
		GateNo
)
select
	ISNULL(GateCate.GateCategory1,N'其它') GateCategory,
	Result.GateNo,
	Result.MerchantNo,
	ISNULL(Cost.Cost,0) Cost,
	ISNULL(Fee.FeeAmt,0) FeeAmt,
	ISNULL(Instu.InstuAmt,0) InstuAmt,
	Result.TransAmt
into
	#PaymentTransWithGateCategory
from
	#FeeResult Result
	left join
	#PaymentCost Cost
	on
		Result.MerchantNo = Cost.MerchantNo
		and
		Result.GateNo = Cost.GateNo
	left join
	#PaymentFee Fee
	on
		Result.MerchantNo = Fee.MerchantNo
		and
		Result.GateNo = Fee.GateNo
	left join
	#PaymentInstuFee Instu
	on
		Result.MerchantNo = Instu.MerchantNo
		and
		Result.GateNo = Instu.GateNo
	left join
	Table_GateCategory GateCate
	on
		Result.GateNo = GateCate.GateNo;
	--left join
	--Table_SalesCurrencyRate SalesCurrency
	--on
	--	Cost.MerchantNo = SalesCurrency.MerchantNo


--4.Get Ora Biz Data
create table #OraCostResult
(
	BankSettingID char(8) not null,
	MerchantNo char(20) not null,
	CPDate datetime not null,
	TransCnt int not null,
	TransAmt bigint not null,
	Cost bigint not null
)
insert into
	#OraCostResult
exec 
	Proc_CalOraCost @CurrStartDate,@CurrEndDate;

create table #OraFeeResult
(
	MerchantNo char(20) not null,
	BankSettingID char(8) not null,
	CPDate datetime not null,
	FeeAmt decimal(15,4) not null
)
insert into
	#OraFeeResult
exec 
	Proc_CalOraFee @CurrStartDate,@CurrEndDate;

With #OraTrans as
(
	select
		MerchantNo,
		SUM(TransAmount) TransAmt
	from
		Table_OraTransSum
	where
		CPDate >= @CurrStartDate
		and
		CPDate < @CurrEndDate
	group by
		MerchantNo
),
#OraCost as
(	
	select
		MerchantNo,
		SUM(Cost) Cost
	from
		#OraCostResult
	group by
		MerchantNo
),
#OraFee as
(
	select
		MerchantNo,
		SUM(FeeAmt) FeeAmt
	from
		#OraFeeResult
	group by
		MerchantNo
)
select
	'Ora' as GateCategory,
	Ora.MerchantNo,
	ISNULL(Cost.Cost,0) Cost,
	ISNULL(Fee.FeeAmt,0) FeeAmt,
	convert(decimal(15,5),0) InstuAmt,
	Ora.TransAmt
into
	#Ora
from
	#OraTrans Ora
	left join
	#OraCost Cost
	on
		Ora.MerchantNo = Cost.MerchantNo
	left join
	#OraFee Fee
	on
		Ora.MerchantNo = Fee.MerchantNo;


--5.Union All Biz Data Calculate Net Income
With #Payment as
(
	select
		GateCategory,
		MerchantNo,
		SUM(Cost) Cost,
		SUM(FeeAmt) FeeAmt,
		SUM(InstuAmt) InstuAmt,
		SUM(TransAmt) TransAmt
	from	
		#PaymentTransWithGateCategory
	group by
		MerchantNo,
		GateCategory
)
select
	*
into
	#AllBizData
from
	#Payment
union all
select
	*
from
	#Ora;

select
	AllBiz.GateCategory,
	AllBiz.MerchantNo,
	Mer.MerchantName,
	AllBiz.Cost as Cost,
	AllBiz.FeeAmt as FeeAmt,
	AllBiz.InstuAmt as InstuAmt,
	(AllBiz.FeeAmt - AllBiz.Cost - AllBiz.InstuAmt) as NetIncome,
	AllBiz.TransAmt as TransAmt
into
	#Result
from
	#AllBizData AllBiz
	left join
	Table_MerInfo Mer
	on
		AllBiz.MerchantNo = Mer.MerchantNo;

With #ResultSum as
(
	select
		(SUM(Cost) + SUM(InstuAmt)) as Invest,
		SUM(NetIncome) as NetIncome 
	from
		#Result
)
select
	R.GateCategory,
	R.MerchantNo,
	R.MerchantName,
	R.Cost/100.0 as Cost,
	R.FeeAmt/100.0 as FeeAmt,
	R.InstuAmt/100.0 as InstuAmt,
	R.NetIncome/100.0 as NetIncome,
	R.TransAmt/100.0 as TransAmt,
	RS.Invest/100.0 as Invest,
	RS.NetIncome/100.0 as IncomeSum
from
	#Result R,
	#ResultSum RS;
	


--6.Drop Temporary Tables
drop table #PaymentCostResult;
drop table #PaymentFeeResult;
drop table #PaymentInstuFeeResult;
drop table #PaymentTransWithGateCategory;
drop table #OraCostResult;
drop table #OraFeeResult;
drop table #Ora;
drop table #AllBizData;
drop table #Result;
end