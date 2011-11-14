if OBJECT_ID(N'Proc_QueryCPMerchantTransReport', N'P') is not null
begin
	drop procedure Proc_QueryCPMerchantTransReport;
end
go

create procedure Proc_QueryCPMerchantTransReport
	@StartDate as datetime = '2011-10-01',
	@EndDate as datetime = '2011-10-31',
	@BizCategory as nchar(10) = '代收类'
as
begin

--1. Check input
if (@StartDate is null or @EndDate is null or ISNULL(@BizCategory,N'') = N'')
begin
	raiserror(N'Input params cannot be empty in Proc_QueryCPMerchantTransReport', 16, 1);
end;
	
--2. Prepare task
--2.1 Prepare @EndDate
set @EndDate = DATEADD(day,1,@EndDate);

--2.2 Get DailyTrans during the period
--2.2.1 Create Table #PeriodSumValue
Create Table #PeriodSumValue
(
	MerchantNo char(20) not null,
	MerchantName char(40) not null,
	SucceedCount int not null,
	SucceedAmount Decimal(12,2) not null
);
 if(@BizCategory = N'消费类')
 begin
	insert into #PeriodSumValue
	(
		MerchantNo,
		MerchantName,
		SucceedCount,
		SucceedAmount
	)
	select
		Trans.MerchantNo,
		Merchant.MerchantName,
	    SUM(Trans.SucceedTransCount) AS SucceedCount,
		Convert(Decimal,SUM(Trans.SucceedTransAmount))/100 AS SucceedAmount
	from
		FactDailyTrans Trans
		inner join 
		Table_GateRoute Gate
		on 
			Trans.GateNo = Gate.GateNo				
		inner join
		Table_MerInfo Merchant
		on
			Trans.MerchantNo = Merchant.MerchantNo
	where
		Trans.DailyTransDate >= @StartDate
		and
		Trans.DailyTransDate < @EndDate
		and
		Gate.GateNo not in ('5003', '5005', '5009', '5022', '5026', '5015','5023', '5021', '7008','0044','0045')
	group by
		Trans.MerchantNo,
		Merchant.MerchantName;
 end
 else if (@BizCategory = N'订购类')
  begin
    insert into #PeriodSumValue
    (
		MerchantNo,
		MerchantName,
		SucceedCount,
		SucceedAmount
	)
	select
		Trans.MerchantNo,
		Merchant.MerchantName,
	    SUM(Trans.SucceedTransCount) AS SucceedCount,
		Convert(Decimal,SUM(Trans.SucceedTransAmount))/100 AS SucceedAmount
	from
		FactDailyTrans Trans
		inner join 
		Table_GateRoute Gate
		on 
			Trans.GateNo = Gate.GateNo
		inner join
		Table_MerInfo Merchant
		on
			Trans.MerchantNo = Merchant.MerchantNo
	where
		Trans.DailyTransDate >= @StartDate
		and
		Trans.DailyTransDate < @EndDate
		and
		Gate.GateNo in ('5003', '5005', '5009', '5022', '5026', '5015', '5021','5023')
	group by
		Trans.MerchantNo,
		Merchant.MerchantName;
 end	
else if(@BizCategory = N'代收类')
  begin
	insert into #PeriodSumValue
	(
		MerchantNo,
		MerchantName,
		SucceedCount,
		SucceedAmount
	)
	select
		Trans.MerchantNo,
		Merchant.MerchantName,
	    SUM(Trans.SucceedTransCount) AS SucceedCount,
		Convert(Decimal,SUM(Trans.SucceedTransAmount))/100 AS SucceedAmount
	from
		FactDailyTrans Trans
		inner join 
		Table_GateRoute Gate
		on 
			Trans.GateNo = Gate.GateNo
		inner join
		Table_MerInfo Merchant
		on
			Trans.MerchantNo = Merchant.MerchantNo
	where
		Trans.DailyTransDate >= @StartDate
		and
		Trans.DailyTransDate < @EndDate
		and
		Gate.GateNo in ('7008')
	group by
		Trans.MerchantNo,
		Merchant.MerchantName;
end
else if(@BizCategory = N'基金定投类')
  begin
	insert into #PeriodSumValue
	(
		MerchantNo,
		MerchantName,
		SucceedCount,
		SucceedAmount
	)
	select
		Trans.MerchantNo,
		Merchant.MerchantName,
	    SUM(Trans.SucceedTransCount) AS SucceedCount,
		Convert(Decimal,SUM(Trans.SucceedTransAmount))/100 AS SucceedAmount
	from
		FactDailyTrans Trans
		inner join 
		Table_GateRoute Gate
		on 
			Trans.GateNo = Gate.GateNo
		inner join
		Table_MerInfo Merchant
		on
			Trans.MerchantNo = Merchant.MerchantNo
	where
		Trans.DailyTransDate >= @StartDate
		and
		Trans.DailyTransDate < @EndDate
		and
		Gate.GateNo in ('0044','0045')
	group by
		Trans.MerchantNo,
		Merchant.MerchantName;
 end
else if(@BizCategory = N'代付类')
  begin
	insert into #PeriodSumValue
	(
		MerchantNo,
		MerchantName,
		SucceedCount,
		SucceedAmount
	)
	select
		Trans.MerchantNo,
		Merchant.MerchantName,
	    SUM(Trans.TransCount) AS SucceedCount,
		Convert(Decimal,SUM(Trans.TransAmount))/100 AS SucceedAmount
	from
		Table_OraTransSum Trans
		inner join
		Table_OraMerchants Merchant
		on
			Trans.MerchantNo = Merchant.MerchantNo
	where
		Trans.CPDate >= @StartDate
		and
		Trans.CPDate < @EndDate
	group by
		Trans.MerchantNo,
		Merchant.MerchantName;
 end
 else if(@BizCategory = N'基金数据')
  begin
	insert into #PeriodSumValue
	(
		MerchantNo,
		MerchantName,
		SucceedCount,
		SucceedAmount
	)
	select
		Trans.MerchantNo,
		Merchant.MerchantName,
	    SUM(ISNULL(Trans.PurchaseCount,0)+ISNULL(Trans.DividendCount,0)+ISNULL(Trans.RedemptoryCount,0)-ISNULL(Trans.RetractCount,0)) AS SucceedCount,
		Convert(Decimal,SUM(ISNULL(Trans.PurchaseAmount,0)+ISNULL(Trans.DividendAmount,0)+ISNULL(Trans.RedemptoryAmount,0)-ISNULL(Trans.RetractAmount,0)))/100 AS SucceedAmount
	from
		Table_FundTransSum Trans
		inner join
		Table_BizFundMerchant Merchant
		on
			Trans.MerchantNo = Merchant.MerchantNo
	where
		Trans.TransDate >= @StartDate
		and
		Trans.TransDate < @EndDate
	group by
		Trans.MerchantNo,
		Merchant.MerchantName;
 end
 else if(@BizCategory = N'信用卡还款')
  begin
	insert into #PeriodSumValue
	(
		MerchantNo,
		MerchantName,
		SucceedCount,
		SucceedAmount
	)
	select
		Trans.BankNo MerchantNo,
		Trans.BankName MerchantName,
	    SUM(Trans.RepaymentCount) AS SucceedCount,
		SUM(Trans.RepaymentAmount) AS SucceedAmount
	from
		Table_CreditCardPayment Trans
	where
		Trans.RepaymentDate >= @StartDate
		and
		Trans.RepaymentDate < @EndDate
	group by
		Trans.BankNo,
		Trans.BankName;
 end
--3. Get Result
select
	*
from
	#PeriodSumValue PeriodSumValue
where
	PeriodSumValue.SucceedCount > 0
order by
	PeriodSumValue.MerchantNo,
	PeriodSumValue.MerchantName;
	
--4. Clear temp table
drop table #PeriodSumValue;

end