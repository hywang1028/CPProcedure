--[Created] At 20120308 By 叶博:每一个有交易的ORA商户一条记录，对应该商户的交易笔数、交易金额、生产库导入的收入、按规则自己计算的收入、当前收入计算规则
--Input:StartDate,EndDate
--OutPut:IndustryName,Ora.MerchantNo,TransCount,TransAmount,OriginFeeAmt,ActualFeeAmt,Mer.MerchantName,OraExp.FeeCalcExp
--1. Get Ora Actual Fee Amount By Procedure Proc_QueryOraActualFeeCal
declare @StartDate datetime;
declare @EndDate datetime;
set @StartDate = '2011-01-01';
set @EndDate = '2011-12-31';

create table #OraTransWithActualFee
(
	MerchantNo char(20) not null,
	BankSettingID char(8) not null,
	CPDate datetime not null,
	TransCount bigint not null,
	TransAmount bigint not null,
	FeeAmount bigint not null,
	ActualFeeAmt decimal(15,2) not null
	
	primary key(MerchantNo,CPDate,BankSettingID)
)

insert into
	#OraTransWithActualFee
exec
	Proc_CalOraFee @StartDate,@EndDate;
	
--2. Get IndustryName And MerchantName And FeeCalcExp By Aggregation
select
	ISNULL(Sales.IndustryName,N'未配置行业') IndustryName,
	Ora.MerchantNo,
	SUM(Ora.TransCount) TransCnt,
	1. * SUM(Ora.TransAmount)/100 TransAmt,
	1. * SUM(Ora.FeeAmount)/100 OriginFeeAmt,
	1. * SUM(Ora.ActualFeeAmt)/100 ActualFeeAmt
into
	#ActualOraWithIndust
from
	#OraTransWithActualFee Ora
	left join
	Table_SalesDeptConfiguration Sales
	on
		Ora.MerchantNo = Sales.MerchantNo
group by
	Sales.IndustryName,
	Ora.MerchantNo
order by
	Ora.MerchantNo;
	
--3. Get Ora Fee Calculate Expression
With DistinctMerNo as
(
	select
		MerchantNo
	from
		Table_OraOrdinaryMerRate
	union
	select
		MerchantNo
	from
		Table_OraBankMerRate
)
select
	MerchantNo,
	dbo.Fn_CurrOraFeeCalcExp(MerchantNo) as FeeCalcExp
into
	#OraMerCalcExp
from
	DistinctMerNo;
	
--4. Get Result
select
	OraIndust.*,
	Mer.MerchantName,
	OraExp.FeeCalcExp
from
	#ActualOraWithIndust OraIndust
	left join
	Table_OraMerchants Mer
	on
		OraIndust.MerchantNo = Mer.MerchantNo
	left join
	#OraMerCalcExp OraExp
	on
		OraIndust.MerchantNo = OraExp.MerchantNo
order by
	OraIndust.MerchantNo;


drop table #OraTransWithActualFee;
drop table #ActualOraWithIndust;
drop table #OraMerCalcExp;
