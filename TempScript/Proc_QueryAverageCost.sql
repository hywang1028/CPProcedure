--Input：StartDate and EndDate
--Output:TypeName,TransCount,TransAmount,TransCost,AvgCost
if OBJECT_ID(N'Proc_QueryAverageCost', N'P') is not null
begin
	drop procedure Proc_QueryAverageCost;
end
go

create procedure Proc_QueryAverageCost  
  @StartDate datetime = '2011-12-01',  
  @EndDate datetime = '2012-01-01'  
as  
begin  

--1. Prepare Basic Data
--1.1 Prepare Payment Data
create table #GateMerCostResult
(
	GateNo char(4) not null,
	MerchantNo char(20) not null,
	TransSumCount bigint not null,
	TransSumAmount bigint not null,
	Cost decimal(15,4) not null
);
insert into #GateMerCostResult
exec Proc_QuerySubFinancialCostCal @StartDate,@EndDate;

With ConvertCurrency as
(
	select
		Result.GateNo,
		Result.MerchantNo,
		Result.TransSumCount,
		case when Rate.CurrencyRate is not null then Rate.CurrencyRate*Result.TransSumAmount
			 else Result.TransSumAmount End as TransSumAmount,
		case when Rate.CurrencyRate is not null then Rate.CurrencyRate*Result.Cost
			 else Result.Cost End as Cost
	from	
		#GateMerCostResult Result
		left join
		Table_SalesCurrencyRate Rate
		on
			Result.MerchantNo = Rate.MerchantNo
),
SelectedGate as
(
	select
		GateNo,
		GateCategory1
	from 
		Table_GateCategory
	where
		GateCategory1 in ('B2B','B2C',N'代扣')
)
select
	ISNULL(Gate.GateCategory1,N'其他') as TypeName,
	SUM(TransSumCount) TransCount,
	SUM(TransSumAmount) TransAmount,
	SUM(Cost) TransCost
into
	#PaymentData
from
	ConvertCurrency 
	left join
	SelectedGate Gate
	on
		ConvertCurrency.GateNo = Gate.GateNo
group by
	Gate.GateCategory1;

--1.2 Prepare Ora Data
create table #OraTransCost
(
	BankSettingID char(10) not null,
	MerchantNo char(20) not null,
	CPDate datetime not null,
	TransCount bigint not null,
	TransAmount bigint not null,
	TransCost decimal(15,4) not null
);
insert into #OraTransCost
EXEC Proc_QueryOraBankCostCalc @StartDate,@EndDate;

select
	N'代付' as TypeName,
	SUM(TransCount) TransCount,
	SUM(TransAmount) TransAmount,
	SUM(TransCost) TransCost
into
	#OraTransData
from
	#OraTransCost;

--2. Join All Ora Data
select * into #AllData from #PaymentData
union all
select * from #OraTransData;

--3.Get Result
select
	TypeName,
	TransCount,
	CONVERT(decimal,TransAmount)/100 TransAmount,
	TransCost/100 TransCost,
	case when TypeName='B2C' then TransCost/TransAmount 
		 else TransCost/(100*TransCount) End as AvgCost
from	
	#AllData;		
	
--4. Drop Table
Drop Table #GateMerCostResult;
Drop Table #PaymentData;
Drop Table #OraTransCost;
Drop Table #OraTransData;
Drop Table #AllData;
End