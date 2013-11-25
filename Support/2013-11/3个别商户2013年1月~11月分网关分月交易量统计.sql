declare @StartDate date;
declare @EndDate date;

set @StartDate = '2013-01-01';
set @EndDate = '2013-11-21';

--1 FeeCalcResult×ÜÊý¾Ý
create table #PaymentCost
(
	GateNo char(4),
	MerchantNo Char(20),
	FeeEndDate date,
	TransCnt int,
	TransAmt decimal(20,2),
	CostAmt decimal(20,2),
	FeeAmt decimal(20,2),
	InstuFeeAmt decimal(20,2)
);

if not exists(select 1 from #PaymentCost)
begin
	insert into #PaymentCost
	(
		GateNo,
		MerchantNo,
		FeeEndDate,
		TransCnt,
		TransAmt,
		CostAmt,
		FeeAmt,
		InstuFeeAmt
	)
	exec Proc_CalPaymentCost @StartDate,@EndDate,null,'on'
end;

select
	pc.GateNo,
	(select GateDesc from Table_GateRoute where GateNo = pc.GateNo) as GateName,
	left(convert(varchar, pc.FeeEndDate),7) as YearMonth,
	SUM(pc.TransCnt) as SucceedCnt,
	SUM(pc.TransAmt)/100.0 as SucceedAmt,
	SUM(pc.FeeAmt)/100.0 as FeeAmt,
	SUM(pc.CostAmt)/100.0 as CostAmt
from
	#PaymentCost pc
where
	pc.MerchantNo = '808080450103703'
group by
	pc.GateNo,
	left(convert(varchar, pc.FeeEndDate),7);