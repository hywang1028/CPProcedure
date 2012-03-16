--[Created] At 20120307 By 叶博：计算支付收入子存储过程
--Input:StartDate,EndDate
--Output:MerchantNo,GateNo,FeeEndDate,FeeAmt
if OBJECT_ID(N'Proc_CalPaymentFee', N'P') is not null
begin
	drop procedure Proc_CalPaymentFee;
end
go

create procedure Proc_CalPaymentFee  
  @StartDate datetime = '2011-01-01',  
  @EndDate datetime = '2011-05-01'  
as  
begin  
  
declare @MinRef decimal(15,2);  
declare @MaxRef decimal(15,2);  
set @MinRef = 0;  
set @MaxRef = 1000000000000;  
  
	   
--1.Get Source Data From Table_FeeCalcResult     
select
	MerchantNo,
	GateNo,
	FeeEndDate,
	SUM(PurAmt) PurAmt,
	SUM(PurCnt) PurCnt,
	CONVERT(decimal(15,4),0) FeeAmt
into
	#FeeResult
from
	Table_FeeCalcResult
where
	FeeEndDate >= @StartDate
	and
	FeeEndDate < @EndDate
group by
	MerchantNo,
	GateNo,
	FeeEndDate;

	
--2. Calculate Fee By FeeCalcResult
update
	Fee
set
	Fee.FeeAmt = (case when  
						PaymentRate.FeeType = 'Fixed'  
					  then  
						PaymentRate.FeeValue * Fee.PurCnt
					  when  
						PaymentRate.FeeType = 'Percent'  
					  then     
						case when 
								PaymentRate.BaseFeeAmt =  0 
								and 
								PaymentRate.PeakFeeAmt =  0 
							 then 
								PaymentRate.FeeValue * Fee.PurAmt   
							 when 
								PaymentRate.BaseFeeAmt <> 0 
								and 
								PaymentRate.PeakFeeAmt =  0 
							 then 
								case when 
										PaymentRate.FeeValue * Fee.PurAmt <= PaymentRate.BaseFeeAmt 
									then 
										PaymentRate.BaseFeeAmt 
									else 
										PaymentRate.FeeValue * Fee.PurAmt 
								end 
							when 
								PaymentRate.BaseFeeAmt =  0 
								and 
								PaymentRate.PeakFeeAmt <> 0 
							then 
								case when 
										PaymentRate.FeeValue * Fee.PurAmt >= PaymentRate.PeakFeeAmt 
									 then 
										PaymentRate.PeakFeeAmt 
									 else 
										PaymentRate.FeeValue * Fee.PurAmt 
								end 
							when 
								PaymentRate.BaseFeeAmt <> 0 
								and 
								PaymentRate.PeakFeeAmt <> 0 
							then 
								case when 
										PaymentRate.FeeValue * Fee.PurAmt <= PaymentRate.BaseFeeAmt 
									 then 
										PaymentRate.BaseFeeAmt   
									 when 
										PaymentRate.FeeValue * Fee.PurAmt >= PaymentRate.PeakFeeAmt
									 then
										PaymentRate.PeakFeeAmt
									 else
										PaymentRate.FeeValue * Fee.PurAmt
								end 
						end  
				 end)
from
	#FeeResult Fee
	inner join
	Table_PaymentMerRate PaymentRate
	on
		Fee.MerchantNo = PaymentRate.MerchantNo
		and
		Fee.GateNo = PaymentRate.GateNo
		and
		Fee.FeeEndDate >= PaymentRate.StartDate
		and
		Fee.FeeEndDate < PaymentRate.EndDate
		and
		Fee.PurAmt >= PaymentRate.RefMinAmt
		and
		Fee.PurAmt < PaymentRate.RefMaxAmt;
	     
	      
--3.Get Result Set  
select
	MerchantNo,
	GateNo,
	FeeEndDate,
	FeeAmt
from
	#FeeResult; 
  
  
--4. Drop Temporary Tables  
drop table #FeeResult;  
 
  
end