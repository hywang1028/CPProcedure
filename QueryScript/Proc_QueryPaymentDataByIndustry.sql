--[Created]At 20120315 By 叶博：支付数据(行业视角)
--Input:StartDate and EndDate
--Output:按行业查看支付业务成本、新旧收入、新旧分润
if OBJECT_ID(N'Proc_QueryPaymentDataByIndustry', N'P') is not null
begin
	drop procedure Proc_QueryPaymentDataByIndustry;
end
go

create procedure Proc_QueryPaymentDataByIndustry  
  @StartDate datetime = '2011-01-01',  
  @EndDate datetime = '2011-05-01'  
as  
begin  

--1. Prepare Source Data
--1.1 Get Payment Related Data
--1.1.1 Get Data From Table FeeCalcResult 
select 
	GateNo,
	MerchantNo,
	SUM(FeeAmt) FeeAmt,
	SUM(InstuFeeAmt) InstuFeeAmt
into
	#FeeResultWithFeeAndInstuFee
from
	Table_FeeCalcResult
where
	FeeEndDate >= @StartDate
	and
	FeeEndDate <  @EndDate
group by
	GateNo,
	MerchantNo;
	
--1.1.2 Get Cost、Fee、InstuFee Data By Proc_CalPaymentCost、Proc_CalPaymentFee、Proc_CalPaymentFee
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
	Proc_CalPaymentCost @StartDate,@EndDate;
	
create table #PaymentFeeResult
(
	MerchantNo char(20) not null,
	GateNo char(4) not null,
	FeeEndDate datetime not null,
	FeeAmt decimal(15,4) not null
);
insert into 
	#PaymentFeeResult
exec 
	Proc_CalPaymentFee @StartDate,@EndDate;  
	
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
	Proc_CalPaymentInstuFee @StartDate,@EndDate;	

With #PaymentCost as
(
	select
		GateNo,
		MerchantNo,
		SUM(TransCnt) TransCnt,
		SUM(TransAmt) TransAmt,
		SUM(Cost) Cost
	from
		#PaymentCostResult
	group by 
		GateNo,
		MerchantNo
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

--1.1.3 Join All Payment Related Data 
select
	FeeResult.GateNo,
	FeeResult.MerchantNo,
	case when 
			SalesCurrencyRate.CurrencyRate is not null 
		 then 
			FeeResult.FeeAmt * SalesCurrencyRate.CurrencyRate 
		 else 
			FeeResult.FeeAmt 
	end as FeeAmt,
	case when 
			SalesCurrencyRate.CurrencyRate is not null 
		 then 
			FeeResult.InstuFeeAmt * SalesCurrencyRate.CurrencyRate 
		 else 
			FeeResult.InstuFeeAmt 
	end as InstuFeeAmt,
	ISNULL(Cost.TransCnt,0) as TransCnt,
	case when 
			SalesCurrencyRate.CurrencyRate is not null 
		 then 
			ISNULL(Cost.TransAmt,0) * SalesCurrencyRate.CurrencyRate 
		 else 
			ISNULL(Cost.TransAmt,0) 
	end as TransAmt,
	case when 
			SalesCurrencyRate.CurrencyRate is not null 
		 then 
			ISNULL(Cost.Cost,0) * SalesCurrencyRate.CurrencyRate 
		 else
			ISNULL(Cost.Cost,0) 
		 end as Cost,
	case when 
			SalesCurrencyRate.CurrencyRate is not null 
		 then 
			ISNULL(Fee.FeeAmt,0) * SalesCurrencyRate.CurrencyRate 
		 else 
			ISNULL(Fee.FeeAmt,0) 
		 end as NewlyFee,
	case when 
			SalesCurrencyRate.CurrencyRate is not null 
		 then 
			ISNULL(InstuFee.InstuAmt,0) * SalesCurrencyRate.CurrencyRate 
		 else 
			ISNULL(InstuFee.InstuAmt,0) 
		 end as NewlyInstuFee
into
	#PaymentResult
from 
	#FeeResultWithFeeAndInstuFee FeeResult
	left join
	#PaymentCost Cost
	on
		FeeResult.GateNo = Cost.GateNo
		and
		FeeResult.MerchantNo = Cost.MerchantNo
	left join
	#PaymentFee Fee
	on
		FeeResult.GateNo = Fee.GateNo
		and
		FeeResult.MerchantNo = Fee.MerchantNo
	left join
	#PaymentInstuFee InstuFee
	on
		FeeResult.GateNo = InstuFee.GateNo
		and
		FeeResult.MerchantNo = InstuFee.MerchantNo
	left join
	Table_SalesCurrencyRate SalesCurrencyRate
	on
		FeeResult.MerchantNo = SalesCurrencyRate.MerchantNo;
		
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
	SUM(Result.TransCnt) TransCnt,
	SUM(Result.TransAmt) TransAmt,
	SUM(Result.Cost) Cost,
	SUM(Result.NewlyFee) NewlyFee,
	SUM(Result.NewlyInstuFee) NewlyInstuFee
into
	#PaymentDataByInsdustry
from
	#PaymentResult Result
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
with #TransDataByIndustry as
(
	select
		IndustryName,
		MerchantNo,
		SUM(TransCnt) TransCnt,
		SUM(TransAmt) TransAmt
	from
		#PaymentDataByInsdustry
	group by
		IndustryName,
		MerchantNo
),
	
--2.3 Get B2C Data
#B2BData as
(
	select
		IndustryName,
		MerchantNo,
		FeeAmt,
		InstuFeeAmt,
		TransCnt,
		TransAmt,
		Cost,
		NewlyFee,
		NewlyInstuFee
	from
		#PaymentDataByInsdustry
	where
		GateCategory1 = 'B2B'
),
--2.4 Get B2B Data
#B2CData as
(
	select
		IndustryName,
		MerchantNo,
		FeeAmt,
		InstuFeeAmt,
		TransCnt,
		TransAmt,
		Cost,
		NewlyFee,
		NewlyInstuFee
	from
		#PaymentDataByInsdustry
	where
		GateCategory1 = 'B2C'
),
--2.5 Get Dedution Data
#DeDuctData as
(
	select
		IndustryName,
		MerchantNo,
		FeeAmt,
		InstuFeeAmt,
		TransCnt,
		TransAmt,
		Cost,
		NewlyFee,
		NewlyInstuFee
	from
		#PaymentDataByInsdustry
	where
		GateCategory1 = N'代扣'
),
--2.6 Get Other PaymentData
#OtherData as
(
	select
		IndustryName,
		MerchantNo,
		SUM(FeeAmt) FeeAmt,
		SUM(InstuFeeAmt) InstuFeeAmt,
		SUM(TransCnt) TransCnt,
		SUM(TransAmt) TransAmt,
		SUM(Cost) Cost,
		SUM(NewlyFee) NewlyFee,
		SUM(NewlyInstuFee) NewlyInstuFee
	from
		#PaymentDataByInsdustry
	where
		GateCategory1 not in ('B2B','B2C',N'代扣')
	group by
		IndustryName,
		MerchantNo
),
--2.7 Get Ora Data


--3.Get PaymentFeeCalExp And PaymentInstuFeeCalExp
#PaymentMerRate as
(
	select distinct
		MerchantNo,
		dbo.Fn_CurrPaymentFeeCalcExp(MerchantNo,GateNo) as FeeCalExp
	from
		Table_PaymentMerRate
),
#PaymentFeeCalExp as
(
	select
		MerchantNo,
		LEFT(ExpList,LEN(ExpList) - 1) as FeeCalExp
	from
	(
		select
			MerchantNo,
			(
				select
					FeeCalExp + '；'
				from
					#PaymentMerRate
				where
					MerchantNo = A.MerchantNo
				order by
					MerchantNo
				for xml path('')
			)as ExpList
		from
			#PaymentMerRate A
		group by
			MerchantNo
	)B
),
#PaymentInstuFeeCalExp as
(
	select
		MerchantNo,
		LEFT(ExpList,LEN(ExpList) - 1) as FeeCalExp
	from
	(
		select
			MerchantNo,
			(
				select
					(case when 
							GateNo <> ''
						 then
							N'在' + convert(varchar,GateNo) + N'网关' + RTRIM(FeeCalcDesc)
						 else
							N'在指定网关之外' + RTRIM(FeeCalcDesc)
						 end  
					 ) + '；'
				from
					Table_InstuMerRate
				where
					MerchantNo = A.MerchantNo
				order by
					MerchantNo
				for xml path('')
			)as ExpList
		from
			Table_InstuMerRate A
		group by
			MerchantNo
	)B
)


--4. Join All Data
select
	AllData.IndustryName,
	AllData.MerchantNo,
	Mer.MerchantName,
	AllData.TransAmt/10000000000.0 TransAmt,
	AllData.TransCnt/10000.0 TransCnt,
	ISNULL(B2C.TransAmt,0)/10000000000.0 B2CTransAmt,
	ISNULL(B2C.TransCnt,0)/10000.0 B2CTransCnt,
	case when 
			ISNULL(B2C.TransAmt,0) = 0 
		 then 
			0 
		 else 
			1000.0 * ISNULL(B2C.FeeAmt,0)/B2C.TransAmt 
	end as N'B2C扣率',
	ISNULL(B2C.FeeAmt,0)/1000000.0 B2CFeeAmt,
	FeeExp.FeeCalExp as N'B2C新扣率',
	ISNULL(B2C.NewlyFee,0)/1000000.0 B2CNewlyFee,
	ISNULL(B2C.FeeAmt,0)/1000000.0 - ISNULL(B2C.NewlyFee,0)/1000000.0 B2CFeeGap,
	case when 
			ISNULL(B2C.TransAmt,0) = 0 
		 then 
			0 
		 else
			1000.0 * ISNULL(B2C.Cost,0)/B2C.TransAmt 
	end as N'B2C银行成本率',
	ISNULL(B2C.Cost,0)/1000000.0 B2CCost,
	case when 
			ISNULL(B2C.TransAmt,0) = 0 
		 then 
			0 
		 else 
			1000.0 * ISNULL(B2C.InstuFeeAmt,0)/B2C.TransAmt 
		end as N'B2C分润成本率',
	ISNULL(B2C.InstuFeeAmt,0)/1000000.0 B2CInstuFeeAmt,
	ISNULL(InstuFeeExp.FeeCalExp,N'无分润') as N'B2C新分润成本率',
	ISNULL(B2C.NewlyInstuFee,0)/1000000.0 B2CNewlyInstuFee,
	ISNULL(B2C.InstuFeeAmt,0)/1000000.0 - ISNULL(B2C.NewlyInstuFee,0)/1000000.0 B2CInstuFeeGap,
	ISNULL(B2B.TransAmt,0)/10000000000.0 B2BTransAmt,
	ISNULL(B2B.TransCnt,0)/10000.0 B2BTransCnt,
	case when 
			ISNULL(B2B.TransAmt,0) = 0 
		 then 
			0 
		 else 
			1000.0 * ISNULL(B2B.FeeAmt,0)/B2B.TransAmt 
		end as N'B2B扣率',
	ISNULL(B2B.FeeAmt,0)/1000000.0 B2BFeeAmt,
	FeeExp.FeeCalExp as N'B2B新扣率',
	ISNULL(B2B.NewlyFee,0)/1000000.0 B2BNewlyFee,
	ISNULL(B2B.FeeAmt,0)/1000000.0 - ISNULL(B2B.NewlyFee,0)/1000000.0 B2BFeeGap,
	case when 
			ISNULL(B2B.TransAmt,0) = 0 
		 then 
			0 
		else 
			1000.0 * ISNULL(B2B.Cost,0)/B2B.TransAmt 
		end as N'B2B银行成本率',
	ISNULL(B2B.Cost,0)/1000000.0 B2BCost,
	case when 
			ISNULL(B2B.TransAmt,0) = 0 
		 then 
			0 
		 else 
			1000.0 * ISNULL(B2B.InstuFeeAmt,0)/B2B.TransAmt 
		 end as N'B2B分润成本率',
	ISNULL(B2B.InstuFeeAmt,0)/1000000.0 B2BInstuFeeAmt,
	ISNULL(InstuFeeExp.FeeCalExp,N'无分润') as N'B2B新分润成本率',
	ISNULL(B2B.NewlyInstuFee,0)/1000000.0 B2BNewlyInstuFee,
	ISNULL(B2B.InstuFeeAmt,0)/1000000.0 - ISNULL(B2B.NewlyInstuFee,0)/1000000.0 B2BInstuFeeGap,
	ISNULL(Deduct.TransAmt,0)/10000000000.0 DeductTransAmt,
	ISNULL(Deduct.TransCnt,0)/10000.0 DeductTransCnt,
	case when 
			ISNULL(Deduct.TransAmt,0) = 0 
		 then 
			0 
		 else 
			1000.0 * ISNULL(Deduct.FeeAmt,0)/Deduct.TransAmt 
		 end as N'Deduct扣率',
	ISNULL(Deduct.FeeAmt,0)/1000000.0 DeductFeeAmt,
	FeeExp.FeeCalExp as N'Deduct新扣率',
	ISNULL(Deduct.NewlyFee,0)/1000000.0 DeductNewlyFee,
	ISNULL(Deduct.FeeAmt,0)/1000000.0 - ISNULL(Deduct.NewlyFee,0)/1000000.0 DeductFeeGap,
	case when 
			ISNULL(Deduct.TransAmt,0) = 0 
		 then 
			0 
		 else 
			1000.0 * ISNULL(Deduct.Cost,0)/Deduct.TransAmt 
		 end as N'Deduct银行成本率',
	ISNULL(Deduct.Cost,0)/1000000.0 DeductCost,
	case when 
			ISNULL(Deduct.TransAmt,0) = 0 
		 then
			0 
		 else 
			1000.0 * ISNULL(Deduct.InstuFeeAmt,0)/Deduct.TransAmt 
		 end as N'Deduct分润成本率',
	ISNULL(Deduct.InstuFeeAmt,0)/1000000.0 DeductInstuFeeAmt,
	ISNULL(InstuFeeExp.FeeCalExp,N'无分润') as N'Deduct新分润成本率',
	ISNULL(Deduct.NewlyInstuFee,0)/1000000.0 DeductNewlyInstuFee,
	ISNULL(Deduct.InstuFeeAmt,0)/1000000.0 - ISNULL(Deduct.NewlyInstuFee,0)/1000000.0 DeductInstuFeeGap,
	ISNULL(Other.TransAmt,0)/10000000000.0 OtherTransAmt,
	ISNULL(Other.TransCnt,0)/10000.0 OtherTransCnt,
	case when 
			ISNULL(Other.TransAmt,0) = 0 
		 then 
			0 
		 else 
			1000.0 * ISNULL(Other.FeeAmt,0)/Other.TransAmt 
		 end as N'Other扣率',
	ISNULL(Other.FeeAmt,0)/1000000.0 OtherFeeAmt,
	FeeExp.FeeCalExp as N'Other新扣率',
	ISNULL(Other.NewlyFee,0)/1000000.0 OtherNewlyFee,
	ISNULL(Other.FeeAmt,0)/1000000.0 - ISNULL(Other.NewlyFee,0)/1000000.0 OtherFeeGap,
	case when 
			ISNULL(Other.TransAmt,0) = 0 
		 then 
			0 
		 else 
			1000.0 * ISNULL(Other.Cost,0)/Other.TransAmt 
		 end as N'Other银行成本率',
	ISNULL(Other.Cost,0)/1000000.0 OtherCost,
	case when 
			ISNULL(Other.TransAmt,0) = 0 
		 then 
			0 
		 else 
			1000.0 * ISNULL(Other.InstuFeeAmt,0)/Other.TransAmt 
		 end as N'Other分润成本率',
	ISNULL(Other.InstuFeeAmt,0)/1000000.0 OtherInstuFeeAmt,
	ISNULL(InstuFeeExp.FeeCalExp,N'无分润') as N'Other新分润成本率',
	ISNULL(Other.NewlyInstuFee,0)/1000000.0 OtherNewlyInstuFee,
	ISNULL(Other.InstuFeeAmt,0)/1000000.0 - ISNULL(Other.NewlyInstuFee,0)/1000000.0 OtherInstuFeeGap
from
	#TransDataByIndustry AllData
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
	#PaymentFeeCalExp FeeExp
	on
		AllData.MerchantNo = FeeExp.MerchantNo
	left join
	#PaymentInstuFeeCalExp InstuFeeExp
	on
		AllData.MerchantNo = InstuFeeExp.MerchantNo
	left join
	Table_MerInfo Mer
	on
		AllData.MerchantNo = Mer.MerchantNo;
		
--4. Drop Table
Drop Table #FeeResultWithFeeAndInstuFee;
Drop Table #PaymentCostResult;
Drop Table #PaymentFeeResult;
Drop Table #PaymentInstuFeeResult;
Drop Table #PaymentResult;
Drop Table #PaymentDataByInsdustry;

End