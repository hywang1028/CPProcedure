--Input:StartDate and EndDate
--Output:按行业查看支付业务成本、新旧收入、新旧分润
if OBJECT_ID(N'Proc_QueryPaymentNewlyFeebyIndustry', N'P') is not null
begin
	drop procedure Proc_QueryPaymentNewlyFeebyIndustry;
end
go

create procedure Proc_QueryPaymentNewlyFeebyIndustry  
  @StartDate datetime = '2011-01-01',  
  @EndDate datetime = '2012-01-01'  
as  
begin  

--1. Prepare Basic Data
--1.1 Prepare Payment Data
--1.1.1 Prepare FeeCalcResult Data
select 
	GateNo,
	MerchantNo,
	SUM(FeeAmt) FeeAmt,
	SUM(InstuFeeAmt) InstuFeeAmt
into
	#GateMerFeeResult
from
	Table_FeeCalcResult
where
	FeeEndDate >= @StartDate
	and
	FeeEndDate <  @EndDate
group by
	GateNo,
	MerchantNo;
	
--1.1.2 Prepare Cost Data
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

select
	GateNo,
	MerchantNo,
	TransSumCount,
	CONVERT(decimal,TransSumAmount)/100 TransSumAmount,
	Cost/100 Cost
into
	#GateMerCost
from
	#GateMerCostResult;

--1.1.3 Prepare NewlyMerchantFee Data
create table #PaymentMerFeeNewlyCalc
(
	MerchantNo char(20) not null,
	GateNo char(4) not null,
	FeeCalcDesc char(400) not null,
	NewlyFeeAmount decimal(15,2) not null
);
insert into #PaymentMerFeeNewlyCalc
EXEC Proc_QueryPaymentMerFeeNewlyCalc @StartDate,@EndDate;

select distinct MerchantNo,FeeCalcDesc into #FeeCalcDesc from #PaymentMerFeeNewlyCalc;

SELECT    
	 MerchantNo,    
	 LEFT(UserList,LEN(UserList)-1) as FeeCalcDesc   
into  
	#FeeCalcExp 
FROM (    
	  SELECT   
			MerchantNo,  
			(SELECT   
				 RTRIM(FeeCalcDesc)+'；'   
			 FROM   
				 #FeeCalcDesc   
			 WHERE 
				 MerchantNo=A.MerchantNo  
			 ORDER BY   
				 MerchantNo FOR XML PATH('')  
		) AS UserList    
	  FROM   
		    #FeeCalcDesc A     
	  GROUP BY   
			MerchantNo    
)B ;  

--1.1.4 Prepare NewlyInstuFeeAmt Data
create table #InstuMerFeeNewlyCalc
(
	MerchantNo char(20) not null,
	MerchantName char(40),
	GateNo char(4),
	NewlyCalcInstuFeeAmt decimal(15,2),
	FeeCalcDesc char(40)
);
insert into #InstuMerFeeNewlyCalc
EXEC Proc_QueryInstuMerFeeNewlyCalc @StartDate,@EndDate;

select 
	MerchantNo,
	GateNo,
	NewlyCalcInstuFeeAmt
into
	#InstuMerFee
from
	#InstuMerFeeNewlyCalc
where
	GateNo is not null;

select distinct MerchantNo,FeeCalcDesc into #InstuFeeCalcDesc from #InstuMerFeeNewlyCalc;

SELECT    
	 MerchantNo,    
	 LEFT(UserList,LEN(UserList)-1) as FeeCalcDesc   
into  
	#InstuFeeCalcExp 
FROM (    
	  SELECT   
			MerchantNo,  
			(SELECT   
				 RTRIM(FeeCalcDesc)+'；'   
			 FROM   
				 #InstuFeeCalcDesc   
			 WHERE 
				 MerchantNo=A.MerchantNo  
			 ORDER BY   
				 MerchantNo FOR XML PATH('')  
		) AS UserList    
	  FROM   
		    #InstuFeeCalcDesc A     
	  GROUP BY   
			MerchantNo    
)B ;  

--1.1.5 Join All Payment Data 
select
	Fee.GateNo GateNo,
	Fee.MerchantNo MerchantNo,
	case when SalesCurrencyRate.CurrencyRate is not null then ISNULL(Fee.FeeAmt,0)*SalesCurrencyRate.CurrencyRate else ISNULL(Fee.FeeAmt,0) End as FeeAmt,
	case when SalesCurrencyRate.CurrencyRate is not null then ISNULL(Fee.InstuFeeAmt,0)*SalesCurrencyRate.CurrencyRate else ISNULL(Fee.InstuFeeAmt,0) End as InstuFeeAmt,
	ISNULL(Cost.TransSumCount,0) as TransSumCount,
	case when SalesCurrencyRate.CurrencyRate is not null then ISNULL(Cost.TransSumAmount,0)*SalesCurrencyRate.CurrencyRate else ISNULL(Cost.TransSumAmount,0) End as TransSumAmount,
	case when SalesCurrencyRate.CurrencyRate is not null then ISNULL(Cost.Cost,0)*SalesCurrencyRate.CurrencyRate else ISNULL(Cost.Cost,0) End as Cost,
	case when SalesCurrencyRate.CurrencyRate is not null then ISNULL(NewlyFee.NewlyFeeAmount,0)*SalesCurrencyRate.CurrencyRate else ISNULL(NewlyFee.NewlyFeeAmount,0) End as NewlyFee,
	case when SalesCurrencyRate.CurrencyRate is not null then ISNULL(InstuMerFee.NewlyCalcInstuFeeAmt,0)*SalesCurrencyRate.CurrencyRate else ISNULL(InstuMerFee.NewlyCalcInstuFeeAmt,0) End as NewlyInstuFee
into
	#AllResult
from 
	#GateMerFeeResult Fee
	left join
	#GateMerCost Cost
	on
		Fee.GateNo = Cost.GateNo
		and
		Fee.MerchantNo = Cost.MerchantNo
	left join
	#PaymentMerFeeNewlyCalc NewlyFee
	on
		Fee.GateNo = NewlyFee.GateNo
		and
		Fee.MerchantNo = NewlyFee.MerchantNo
	left join
	#InstuMerFee InstuMerFee
	on
		Fee.GateNo = InstuMerFee.GateNo
		and
		Fee.MerchantNo = InstuMerFee.MerchantNo
	left join
	Table_SalesCurrencyRate SalesCurrencyRate
	on
		Fee.MerchantNo = SalesCurrencyRate.MerchantNo;
		
--1.2 Prepare Ora Data
--1.2.1 Prepare Trans/Fee Data
--1.2.2 Prepare Newly Fee Data
--1.2.3 Join All Ora Data
--1.3 Join Payment Data And Ora Data

--2.Join Config Data
--2.1 Prepare Configured Detail Data
select
	ISNULL(Sales.IndustryName,N'未配置行业') IndustryName,
	ISNULL(Gate.GateCategory1,N'其他') GateCategory1,
	Result.MerchantNo,
	SUM(Result.FeeAmt) FeeAmt,
	SUM(Result.InstuFeeAmt) InstuFeeAmt,
	SUM(Result.TransSumCount) TransSumCount,
	SUM(Result.TransSumAmount) TransSumAmount,
	SUM(Result.Cost) Cost,
	SUM(Result.NewlyFee) NewlyFee,
	SUM(Result.NewlyInstuFee) NewlyInstuFee
into
	#IndustryData
from
	#AllResult Result
	left join
	Table_SalesDeptConfiguration Sales
	on
		Result.MerchantNo = Sales.MerchantNo
	left join
	Table_GateCategory Gate
	on
		Result.GateNo = Gate.GateNo
group by
	Sales.IndustryName,
	Gate.GateCategory1,
	Result.MerchantNo;

--2.2 Get TransSum Data
select
	IndustryName,
	MerchantNo,
	SUM(TransSumCount) TransSumCount,
	SUM(TransSumAmount) TransSumAmount
into
	#TransSumData
from
	#IndustryData
group by
	IndustryName,
	MerchantNo;
	
--2.3 Get B2C Data
select
	IndustryName,
	MerchantNo,
	FeeAmt,
	InstuFeeAmt,
	TransSumCount,
	TransSumAmount,
	Cost,
	NewlyFee,
	NewlyInstuFee
into
	#B2BData
from
	#IndustryData
where
	GateCategory1 = 'B2B';
	
--2.4 Get B2B Data
select
	IndustryName,
	MerchantNo,
	FeeAmt,
	InstuFeeAmt,
	TransSumCount,
	TransSumAmount,
	Cost,
	NewlyFee,
	NewlyInstuFee
into
	#B2CData
from
	#IndustryData
where
	GateCategory1 = 'B2C';
	
--2.5 Get Dedution Data
select
	IndustryName,
	MerchantNo,
	FeeAmt,
	InstuFeeAmt,
	TransSumCount,
	TransSumAmount,
	Cost,
	NewlyFee,
	NewlyInstuFee
into
	#DeDuctData
from
	#IndustryData
where
	GateCategory1 = N'代扣';
	
--2.6 Get Other PaymentData
select
	IndustryName,
	MerchantNo,
	SUM(FeeAmt) FeeAmt,
	SUM(InstuFeeAmt) InstuFeeAmt,
	SUM(TransSumCount) TransSumCount,
	SUM(TransSumAmount) TransSumAmount,
	SUM(Cost) Cost,
	SUM(NewlyFee) NewlyFee,
	SUM(NewlyInstuFee) NewlyInstuFee
into
	#OtherData
from
	#IndustryData
where
	GateCategory1 not in ('B2B','B2C',N'代扣')
group by
	IndustryName,
	MerchantNo;

--2.7 Get Ora Data

--3. Join All Data
select
	AllData.IndustryName,
	AllData.MerchantNo,
	Mer.MerchantName,
	Convert(decimal,ISNULL(AllData.TransSumAmount,0))/100000000 TransSumAmount,
	Convert(decimal,ISNULL(AllData.TransSumCount,0))/10000 TransSumCount,
	Convert(decimal,ISNULL(B2C.TransSumAmount,0))/100000000 B2CTransAmt,
	Convert(decimal,ISNULL(B2C.TransSumCount,0))/10000 B2CTransCnt,
	case when ISNULL(B2C.TransSumAmount,0) = 0 then 0 else 1000*ISNULL(B2C.FeeAmt,0)/B2C.TransSumAmount End as N'B2C扣率',
	Convert(decimal,ISNULL(B2C.FeeAmt,0))/10000 B2CFeeAmt,
	FeeCalcExp.FeeCalcDesc as N'B2C新扣率',
	Convert(decimal,ISNULL(B2C.NewlyFee,0))/10000 B2CNewlyFee,
	Convert(decimal,ISNULL(B2C.FeeAmt,0))/10000-Convert(decimal,ISNULL(B2C.NewlyFee,0))/10000 B2CFeeGap,
	case when ISNULL(B2C.TransSumAmount,0) = 0 then 0 else 1000*ISNULL(B2C.Cost,0)/B2C.TransSumAmount End as N'B2C银行成本率',
	Convert(decimal,ISNULL(B2C.Cost,0))/10000 B2CCost,
	case when ISNULL(B2C.TransSumAmount,0) = 0 then 0 else 1000*ISNULL(B2C.InstuFeeAmt,0)/B2C.TransSumAmount End as N'B2C分润成本率',
	Convert(decimal,ISNULL(B2C.InstuFeeAmt,0))/10000 B2CInstuFeeAmt,
	ISNULL(InstuFeeCalcExp.FeeCalcDesc,N'无分润') as N'B2C新分润成本率',
	Convert(decimal,ISNULL(B2C.NewlyInstuFee,0))/10000 B2CNewlyInstuFee,
	Convert(decimal,ISNULL(B2C.InstuFeeAmt,0))/10000-Convert(decimal,ISNULL(B2C.NewlyInstuFee,0))/10000 B2CInstuFeeGap,
	Convert(decimal,ISNULL(B2B.TransSumAmount,0))/100000000 B2BTransAmt,
	Convert(decimal,ISNULL(B2B.TransSumCount,0))/10000 B2BTransCnt,
	case when ISNULL(B2B.TransSumAmount,0) = 0 then 0 else 1000*ISNULL(B2B.FeeAmt,0)/B2B.TransSumAmount End as N'B2B扣率',
	Convert(decimal,ISNULL(B2B.FeeAmt,0))/10000 B2BFeeAmt,
	FeeCalcExp.FeeCalcDesc as N'B2B新扣率',
	Convert(decimal,ISNULL(B2B.NewlyFee,0))/10000 B2BNewlyFee,
	Convert(decimal,ISNULL(B2B.FeeAmt,0))/10000-Convert(decimal,ISNULL(B2B.NewlyFee,0))/10000 B2BFeeGap,
	case when ISNULL(B2B.TransSumAmount,0) = 0 then 0 else 1000*ISNULL(B2B.Cost,0)/B2B.TransSumAmount End as N'B2B银行成本率',
	Convert(decimal,ISNULL(B2B.Cost,0))/10000 B2BCost,
	case when ISNULL(B2B.TransSumAmount,0) = 0 then 0 else 1000*ISNULL(B2B.InstuFeeAmt,0)/B2B.TransSumAmount End as N'B2B分润成本率',
	Convert(decimal,ISNULL(B2B.InstuFeeAmt,0))/10000 B2BInstuFeeAmt,
	ISNULL(InstuFeeCalcExp.FeeCalcDesc,N'无分润') as N'B2B新分润成本率',
	Convert(decimal,ISNULL(B2B.NewlyInstuFee,0))/10000 B2BNewlyInstuFee,
	Convert(decimal,ISNULL(B2B.InstuFeeAmt,0))/10000-Convert(decimal,ISNULL(B2B.NewlyInstuFee,0))/10000 B2BInstuFeeGap,
	Convert(decimal,ISNULL(Deduct.TransSumAmount,0))/100000000 DeductTransAmt,
	Convert(decimal,ISNULL(Deduct.TransSumCount,0))/10000 DeductTransCnt,
	case when ISNULL(Deduct.TransSumAmount,0) = 0 then 0 else 1000*ISNULL(Deduct.FeeAmt,0)/Deduct.TransSumAmount End as N'Deduct扣率',
	Convert(decimal,ISNULL(Deduct.FeeAmt,0))/10000 DeductFeeAmt,
	FeeCalcExp.FeeCalcDesc as N'Deduct新扣率',
	Convert(decimal,ISNULL(Deduct.NewlyFee,0))/10000 DeductNewlyFee,
	Convert(decimal,ISNULL(Deduct.FeeAmt,0))/10000-Convert(decimal,ISNULL(Deduct.NewlyFee,0))/10000 DeductFeeGap,
	case when ISNULL(Deduct.TransSumAmount,0) = 0 then 0 else 1000*ISNULL(Deduct.Cost,0)/Deduct.TransSumAmount End as N'Deduct银行成本率',
	Convert(decimal,ISNULL(Deduct.Cost,0))/10000 DeductCost,
	case when ISNULL(Deduct.TransSumAmount,0) = 0 then 0 else 1000*ISNULL(Deduct.InstuFeeAmt,0)/Deduct.TransSumAmount End as N'Deduct分润成本率',
	Convert(decimal,ISNULL(Deduct.InstuFeeAmt,0))/10000 DeductInstuFeeAmt,
	ISNULL(InstuFeeCalcExp.FeeCalcDesc,N'无分润') as N'Deduct新分润成本率',
	Convert(decimal,ISNULL(Deduct.NewlyInstuFee,0))/10000 DeductNewlyInstuFee,
	Convert(decimal,ISNULL(Deduct.InstuFeeAmt,0))/10000-Convert(decimal,ISNULL(Deduct.NewlyInstuFee,0))/10000 DeductInstuFeeGap,
	Convert(decimal,ISNULL(Other.TransSumAmount,0))/100000000 OtherTransAmt,
	Convert(decimal,ISNULL(Other.TransSumCount,0))/10000 OtherTransCnt,
	case when ISNULL(Other.TransSumAmount,0) = 0 then 0 else 1000*ISNULL(Other.FeeAmt,0)/Other.TransSumAmount End as N'Other扣率',
	Convert(decimal,ISNULL(Other.FeeAmt,0))/10000 OtherFeeAmt,
	FeeCalcExp.FeeCalcDesc as N'Other新扣率',
	Convert(decimal,ISNULL(Other.NewlyFee,0))/10000 OtherNewlyFee,
	Convert(decimal,ISNULL(Other.FeeAmt,0))/10000-Convert(decimal,ISNULL(Other.NewlyFee,0))/10000 OtherFeeGap,
	case when ISNULL(Other.TransSumAmount,0) = 0 then 0 else 1000*ISNULL(Other.Cost,0)/Other.TransSumAmount End as N'Other银行成本率',
	Convert(decimal,ISNULL(Other.Cost,0))/10000 OtherCost,
	case when ISNULL(Other.TransSumAmount,0) = 0 then 0 else 1000*ISNULL(Other.InstuFeeAmt,0)/Other.TransSumAmount End as N'Other分润成本率',
	Convert(decimal,ISNULL(Other.InstuFeeAmt,0))/10000 OtherInstuFeeAmt,
	ISNULL(InstuFeeCalcExp.FeeCalcDesc,N'无分润') as N'Other新分润成本率',
	Convert(decimal,ISNULL(Other.NewlyInstuFee,0))/10000 OtherNewlyInstuFee,
	Convert(decimal,ISNULL(Other.InstuFeeAmt,0))/10000-Convert(decimal,ISNULL(Other.NewlyInstuFee,0))/10000 OtherInstuFeeGap
from
	#TransSumData AllData
	left join
	#B2BData B2B
	on
		AllData.MerchantNo = B2B.MerchantNo
	left join
	#B2CData B2C
	on
		AllData.MerchantNo = B2C.MerchantNo
	left join
	#DeDuctData Deduct
	on
		AllData.MerchantNo = Deduct.MerchantNo
	left join
	#OtherData Other
	on
		AllData.MerchantNo = Other.MerchantNo
	left join
	#FeeCalcExp FeeCalcExp
	on
		AllData.MerchantNo = FeeCalcExp.MerchantNo
	left join
	#InstuFeeCalcExp InstuFeeCalcExp
	on
		AllData.MerchantNo = InstuFeeCalcExp.MerchantNo
	left join
	Table_MerInfo Mer
	on
		AllData.MerchantNo = Mer.MerchantNo;
		
--4. Drop Table
Drop Table #GateMerFeeResult;
Drop Table #GateMerCostResult;
Drop Table #GateMerCost;
Drop Table #PaymentMerFeeNewlyCalc;
Drop Table #FeeCalcExp;
Drop Table #FeeCalcDesc;
Drop Table #InstuMerFeeNewlyCalc;
Drop Table #InstuMerFee;
Drop Table #InstuFeeCalcExp;
Drop Table #InstuFeeCalcDesc;
Drop Table #AllResult;
Drop Table #IndustryData;
Drop Table #TransSumData;
Drop Table #B2BData;
Drop Table #B2CData;
Drop Table #DeDuctData;
Drop Table #OtherData;

End