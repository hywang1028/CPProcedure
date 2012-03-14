--[Created] At 20120307 By 叶博：支付分润子存储过程
--Input:StartDate,EndDate
--Output:MerchantNo,GateNo,FeeEndDate,InstuAmt
if OBJECT_ID('Proc_CalPaymentInstuFee') is not null
begin
	drop procedure Proc_CalPaymentInstuFee;
end
go

create procedure Proc_CalPaymentInstuFee
		@StartDate datetime = '2011-01-01',
		@EndDate datetime = '2012-01-01'
as
begin

--1. Get Source Data From Table_FeeCalcResult
select
	MerchantNo,
	GateNo,
	FeeEndDate,
	SUM(PurAmt)   PurAmt,
	SUM(PurCnt)   PurCnt,
	SUM(FeeAmt)   FeeAmt,
	SUM(TransAmt) TransAmt,
	convert(decimal(15,5),-1) InstuAmt
into
	#FeeSumByMerchantNoAndGateNo
from
	Table_FeeCalcResult
where
	FeeEndDate >= @StartDate
	and
	FeeEndDate <  @EndDate
group by
	MerchantNo,
	GateNo,
	FeeEndDate;


--2. Calculate Newly Instu Fee Amount
--2.1 Calculate Merchant InstuFeeAmount By Rule At Appointed Gate
update
	FeeSum
set
	FeeSum.InstuAmt = (case when InstuMerRate.CalcParam2 = ''       then FeeSum.FeeAmt * InstuMerRate.FeeValue
							when InstuMerRate.CalcParam2 = 'purCnt' then FeeSum.FeeAmt - FeeSum.PurCnt * InstuMerRate.FeeValue
								   end)
from
	#FeeSumByMerchantNoAndGateNo FeeSum
	inner join
	Table_InstuMerRate InstuMerRate
	on
		FeeSum.MerchantNo = InstuMerRate.MerchantNo
		and
		FeeSum.GateNo = InstuMerRate.GateNo
		and
		FeeSum.FeeEndDate >= InstuMerRate.StartDate
		and
		FeeSum.FeeEndDate < InstuMerRate.EndDate;

--2.2 Calculate Merchant InstuFeeAmount By Rule At Any Gate
With NormalInstuMerRate as
(
	select
		MerchantNo,
		CalcParam1,
		CalcParam2,
		FeeValue,
		StartDate,
		EndDate
	from
		Table_InstuMerRate
	where
		GateNo = ''
)
update
	FeeSum
set
	FeeSum.InstuAmt = (case when Normal.CalcParam2 = '' then
													case when Normal.CalcParam1 = 'FeeAmt' then FeeSum.FeeAmt * Normal.FeeValue
														 when Normal.CalcParam1 = 'purCnt' then FeeSum.PurCnt * Normal.FeeValue
														 when Normal.CalcParam1 = 'PurAmt' then FeeSum.PurAmt * Normal.FeeValue
													end
							when Normal.CalcParam2 = 'purCnt' then
													case when Normal.CalcParam1 = 'FeeAmt'   then FeeSum.FeeAmt   - FeeSum.PurCnt * Normal.FeeValue
														 when Normal.CalcParam1 = 'transAmt' then FeeSum.TransAmt - FeeSum.PurCnt * Normal.FeeValue
													end
					   end)
from
	#FeeSumByMerchantNoAndGateNo FeeSum
	inner join
	NormalInstuMerRate Normal
	on
		FeeSum.MerchantNo = Normal.MerchantNo
		and
		FeeSum.FeeEndDate >= Normal.StartDate
		and
		FeeSum.FeeEndDate < Normal.EndDate
where
	FeeSum.InstuAmt = -1;
	
--3. Get Merchant Without InstuFee Amount
update 
	#FeeSumByMerchantNoAndGateNo 
set
	InstuAmt = 0
where	
	InstuAmt = -1;
	
	
--4. Get Final Result
select
	MerchantNo,
	GateNo,
	FeeEndDate,
	InstuAmt
from
	#FeeSumByMerchantNoAndGateNo
	

--5. Drop Temporary Tables
drop table #FeeSumByMerchantNoAndGateNo;


end
